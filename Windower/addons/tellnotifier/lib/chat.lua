--[[
* TellNotifier Chat Module
* Handles chat event processing and deduplication
--]]

local Chat = {}

-- State for deduplication and cooldowns
Chat.state = {
    last_message_times = {},
    last_outgoing_message = "",
    last_outgoing_time = 0,
}

function Chat.check_cooldown(chat_type, cooldown_period, enable_batching)
    local current_time = os.time()
    local last_time = Chat.state.last_message_times[chat_type] or 0

    -- Use shorter cooldown for batched chat types
    if enable_batching and (chat_type == 'Yell' or chat_type == 'Shout' or chat_type == 'Say') then
        cooldown_period = 0.5
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

return Chat
