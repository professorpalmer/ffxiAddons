--[[
* Sendoria Chat Module
* Handles chat event processing and deduplication
--]]

local Chat = {}

-- State for deduplication and cooldowns
Chat.state = {
    last_message_times = {},
    last_outgoing_message = "",
    last_outgoing_time = 0,
}

function Chat.check_cooldown(chat_type, settings)
    local Config = require('lib/config')
    local current_time = os.time()
    local last_time = Chat.state.last_message_times[chat_type] or 0

    -- Get the cooldown period for this specific chat type
    local cooldown_period = Config.get_cooldown_for_chat_type(settings, chat_type)

    -- Use shorter cooldown for batched chat types if enabled
    if settings.enable_batching and (chat_type == 'Yell' or chat_type == 'Shout' or chat_type == 'Say') then
        -- Only override if no specific cooldown is set for this chat type
        if not settings['cooldown_' .. chat_type:lower()] then
            cooldown_period = 0.5
        end
    end

    if current_time - last_time < cooldown_period then
        return false -- Still in cooldown
    end

    Chat.state.last_message_times[chat_type] = current_time
    return true -- Cooldown expired
end

function Chat.is_duplicate_outgoing(mode, message)
    local current_time = os.clock()
    local message_key = string.format("%d:%s", mode, message)

    if Chat.state.last_outgoing_message == message_key and
        (current_time - Chat.state.last_outgoing_time) < 1.0 then
        return true, current_time - Chat.state.last_outgoing_time
    end

    -- Store this message for deduplication
    Chat.state.last_outgoing_message = message_key
    Chat.state.last_outgoing_time = current_time
    return false, 0
end

function Chat.parse_outgoing_speech_packet(data)
    local mode = data:byte(5)                    -- Mode is at offset 4 (0-indexed)
    local message = data:sub(7):gsub('%z.*', '') -- Message starts at offset 6, remove null terminator

    -- Map packet mode to chat type
    local chat_type_map = {
        [0] = 'Say',
        [1] = 'Shout',
        [4] = 'Party',
        [5] = 'Linkshell1',
        [26] = 'Yell',
        [27] = 'Linkshell2',
        [33] = 'Unity',
    }

    local chat_type = chat_type_map[mode] or 'Unknown'

    -- Skip Tell mode 3 - handled by 0x0B6 packet
    if mode == 3 then
        return nil, nil, "Tell handled by 0x0B6"
    end

    return mode, message, chat_type
end

function Chat.parse_outgoing_tell_packet(data)
    local target = data:sub(7, 21):gsub('%z.*', '') -- Target name at offset 6, max 15 chars
    local message = data:sub(22):gsub('%z.*', '')   -- Message starts at offset 21

    return target, message
end

--[[
* Relay file I/O functions for bidirectional Discord communication
--]]

function Chat.write_to_relay_file(chat_type, sender, message, direction)
    local Config = require('lib/config')
    local settings = Config.load()

    if not settings.relay_enabled then
        return
    end

    local file_path = windower.addon_path .. settings.relay_file_path


    -- Use async file writing to prevent I/O blocking during yell spam
    coroutine.schedule(function()
        local file = io.open(file_path, 'a')
        if file then
            local timestamp = os.date('%Y-%m-%d %H:%M:%S')
            local entry = string.format('[%s] %s | %s | %s | %s\n',
                timestamp, direction, chat_type, sender, message)
            file:write(entry)
            file:flush() -- Force immediate write to disk
            file:close()
        end
    end, 0.001) -- Tiny delay to make it non-blocking
end

function Chat.read_discord_responses(settings)
    if not settings.relay_enabled then
        return {}
    end

    local file_path = windower.addon_path .. settings.response_file_path
    local file = io.open(file_path, 'r')
    if not file then
        return {}
    end

    local content = file:read('*a')
    file:close()

    if not content or content == '' then
        return {}
    end

    -- Clear file after reading
    io.open(file_path, 'w'):close()

    -- Parse responses (format: chat_type|message OR Tell|target|message)
    local responses = {}
    for line in content:gmatch('[^\r\n]+') do
        -- Split line by pipes
        local parts = {}
        for part in line:gmatch('[^|]+') do
            local trimmed = part:gsub('^%s*(.-)%s*$', '%1') -- Trim whitespace
            parts[#parts + 1] = trimmed                     -- Use # operator instead of table.insert for safety
        end

        if #parts >= 2 then
            local chat_type = parts[1]
            local message, target = nil, nil

            if chat_type == 'Tell' and #parts >= 3 then
                -- Tell format: Tell|target|message
                target = parts[2]
                message = parts[3]
            else
                -- Regular format: chat_type|message
                message = parts[2]
            end

            if message and message ~= '' then
                responses[#responses + 1] = { -- Use # operator instead of table.insert
                    chat_type = chat_type,
                    message = message,
                    target = target
                }
            end
        end
    end

    return responses
end

-- State to track Discord-originated messages
Chat.discord_messages = {}

function Chat.inject_message_to_game(chat_type, message, target)
    -- Safety checks
    if not message or #message > 200 then
        return false, "Message too long or empty"
    end

    -- Sanitize message (remove potentially dangerous characters)
    local clean_message = message:gsub('[<>]', ''):gsub('^%s*(.-)%s*$', '%1')
    if clean_message == '' then
        return false, "Message empty after sanitization"
    end

    -- Mark this message as Discord-originated to prevent relay loop
    local message_key = string.format("%s:%s", chat_type, clean_message)
    Chat.discord_messages[message_key] = os.clock() + 5.0 -- Mark for 5 seconds

    -- Use windower.send_command instead of packet injection (much more reliable)
    local command = nil
    if chat_type == 'Tell' then
        if not target or target == '' then
            return false, "Tell requires target name"
        end
        -- Sanitize target name
        local clean_target = target:gsub('[<>]', ''):gsub('^%s*(.-)%s*$', '%1')
        command = 'input /tell ' .. clean_target .. ' ' .. clean_message
    elseif chat_type == 'Party' then
        command = 'input /p ' .. clean_message
    elseif chat_type == 'Linkshell1' then
        command = 'input /l ' .. clean_message
    elseif chat_type == 'Linkshell2' then
        command = 'input /l2 ' .. clean_message
    elseif chat_type == 'Say' then
        command = 'input /say ' .. clean_message
    elseif chat_type == 'Shout' then
        command = 'input /sh ' .. clean_message
    elseif chat_type == 'Yell' then
        command = 'input /yell ' .. clean_message
    elseif chat_type == 'Unity' then
        command = 'input /unity ' .. clean_message
    else
        return false, "Unknown chat type: " .. tostring(chat_type)
    end

    -- Send the command
    windower.send_command('@' .. command)
    return true
end

function Chat.is_discord_originated_message(chat_type, message)
    local message_key = string.format("%s:%s", chat_type, message)
    local current_time = os.clock()

    -- Check if this message was recently sent from Discord
    if Chat.discord_messages[message_key] and Chat.discord_messages[message_key] > current_time then
        return true
    end

    -- Clean up old entries
    for key, expire_time in pairs(Chat.discord_messages) do
        if expire_time <= current_time then
            Chat.discord_messages[key] = nil
        end
    end

    return false
end

return Chat
