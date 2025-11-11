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

function Chat.is_unity_system_message(message, sender)
    -- Unity system messages from NPCs have specific characteristics:
    -- 1. Often have empty or system-generated sender names
    -- 2. Contain hex-like patterns (comma-separated hex values)
    -- 3. Start with specific patterns for Domain Invasion announcements
    
    if not message or not sender then
        return false
    end
    
    -- Check for hex pattern typical of encoded Unity messages
    local hex_pattern = message:match("^[%s]*:?[%s]*[0-9a-fA-F,]+[%s]*$")
    if hex_pattern then
        return true
    end
    
    -- Check for other system message patterns
    local system_patterns = {
        "^%s*:%s*[0-9a-fA-F]+,",  -- Starts with colon and hex
        "^[0-9a-fA-F]+,[0-9a-fA-F]+,", -- Starts with hex values
    }
    
    for _, pattern in ipairs(system_patterns) do
        if message:match(pattern) then
            return true
        end
    end
    
    return false
end

function Chat.parse_unity_system_message(message)
    -- Parse Unity system messages that come in encoded format
    -- These are typically Domain Invasion announcements and other system messages
    
    if not message then
        return nil
    end
    
    -- Remove leading colon and whitespace
    local cleaned = message:gsub("^%s*:?%s*", "")
    
    -- Check if this looks like a hex-encoded message
    if not cleaned:match("^[0-9a-fA-F,]+") then
        return message -- Return original if not hex-encoded
    end
    
    -- Split by commas to get hex values
    local hex_values = {}
    for hex in cleaned:gmatch("([0-9a-fA-F]+)") do
        if #hex > 0 then
            table.insert(hex_values, hex)
        end
    end
    
    -- If we have hex values, try to decode them
    if #hex_values > 0 then
        -- For Domain Invasion messages, we can provide a generic message
        -- since the exact parsing would require Unity-specific data
        local first_hex = hex_values[1]
        
        -- Common Domain Invasion message identifiers
        local domain_invasion_ids = {
            ["0a"] = true,
            ["0A"] = true,
        }
        
        if domain_invasion_ids[first_hex] then
            return "Domain Invasion notification (location data encoded)"
        end
        
        -- For other system messages, provide a generic description
        return string.format("Unity system message (encoded: %s...)", 
                           table.concat(hex_values, ","):sub(1, 20))
    end
    
    -- If we can't decode, return a cleaned version
    return "Unity system message (encoded data)"
end

return Chat
