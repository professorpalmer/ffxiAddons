--[[
* Sendoria - Bidirectional Discord Chat Relay for Windower
* Author: Palmer (Zodiarchy @ Asura)
* Version: 2.0 - Bidirectional Relay
--]]

_addon.name     = 'Sendoria'
_addon.author   = 'Palmer (Zodiarchy @ Asura)'
_addon.version  = '2.0'
_addon.desc     = 'Bidirectional Discord chat relay for FFXI.'
_addon.commands = { 'sendoria', 'send' }

require('tables')
require('strings')

-- Load modules
local Config = require('lib/config')
local Chat = require('lib/chat')
local Commands = require('lib/commands')

-- Load settings
local settings = Config.load()

-- Relay timer for checking Discord responses
local relay_timer = 0

--[[
* Main notification handler
--]]
local function send_notification(sender, message, chat_type)
    -- Check if addon is enabled (keep this for backward compatibility)
    if not settings.enabled then
        return
    end

    -- Discord communication now handled by external bot

    -- Write to relay file (Bot reads this for Discord) - always write if relay enabled
    -- But skip if this message originated from Discord (prevents feedback loop)
    if settings.relay_enabled and settings.relay_log_all_chat then
        if not Chat.is_discord_originated_message(chat_type, message) then
            Chat.write_to_relay_file(chat_type, sender, message, 'IN')
        elseif settings.debug_mode then
            windower.add_to_chat(123, string.format('Sendoria: Skipping Discord-originated message: %s', message))
        end
    end

    -- Debug output removed for cleaner operation
end

--[[
* Chat message event handler
--]]
windower.register_event('chat message', function(message, sender, mode, is_gm)
    if settings.debug_mode then
        windower.add_to_chat(123,
            string.format('Sendoria DEBUG: Mode=%d, Sender=%s, Message=%s', mode or -1, sender or 'nil',
                message or 'nil'))
    end

    -- Skip our own messages if outgoing monitoring is enabled (handled by outgoing chunk event)
    local player = windower.ffxi.get_player()
    if player and sender == player.name and settings.monitor_outgoing then
        if settings.debug_mode then
            windower.add_to_chat(123,
                'Sendoria DEBUG: Skipping own message in chat event (handled by outgoing chunk)')
        end
        return
    end

    local chat_info = Config.chat_modes[mode]
    if not chat_info or not settings[chat_info.setting] then
        return
    end

    -- Check cooldown
    if not Chat.check_cooldown(chat_info.name, settings) then
        if settings.debug_mode then
            windower.add_to_chat(123, string.format('Sendoria: %s blocked due to cooldown', chat_info.name))
        end
        return
    end

    -- Convert auto-translate and send notification
    local clean_message = windower.convert_auto_trans(message) or message
    -- Send notification asynchronously to prevent any potential freezing
    coroutine.schedule(function()
        send_notification(sender, clean_message, chat_info.name)
    end, 0.1)

    if settings.debug_mode then
        windower.add_to_chat(123, string.format('Sendoria: %s notification sent from %s', chat_info.name, sender))
    end
end)

--[[
* Outgoing chunk event handler for outgoing messages
--]]
windower.register_event('outgoing chunk', function(id, data, modified, injected, blocked)
    -- Skip if not monitoring outgoing or addon disabled
    if not (settings.monitor_outgoing and settings.enabled) then
        return
    end

    -- Skip blocked or injected packets
    if blocked or injected then
        return
    end

    -- Only process modified packets (contain resolved chat mode)
    if not modified then
        return
    end

    if settings.debug_mode and (id == 0x0B5 or id == 0x0B6) then
        windower.add_to_chat(123,
            string.format('Sendoria DEBUG: Outgoing packet 0x%03X - modified=%s, size=%d', id, tostring(modified),
                #data))
    end

    local player_name = windower.ffxi.get_player().name or 'Unknown'

    if id == 0x0B5 then
        -- Speech packet
        local mode, message, chat_type = Chat.parse_outgoing_speech_packet(data)

        if not mode then
            if settings.debug_mode and chat_type then
                windower.add_to_chat(123, 'Sendoria DEBUG: ' .. chat_type)
            end
            return
        end

        -- Check for duplicates
        local is_duplicate, time_diff = Chat.is_duplicate_outgoing(mode, message)
        if is_duplicate then
            if settings.debug_mode then
                windower.add_to_chat(123,
                    string.format('Sendoria DEBUG: Duplicate outgoing message detected - skipping (time_diff=%.3f)',
                        time_diff))
            end
            return
        end

        if settings.debug_mode then
            windower.add_to_chat(123, string.format('Sendoria DEBUG: Outgoing %s - Message=%s', chat_type, message))
        end

        -- Check cooldown and send
        if Chat.check_cooldown(chat_type, settings) then
            local final_message = windower.convert_auto_trans(message) or message
            -- Send notification asynchronously to prevent game freeze
            coroutine.schedule(function()
                send_notification(player_name, final_message, chat_type)
            end, 0.1)
        end
    elseif id == 0x0B6 then
        -- Tell packet
        local target, message = Chat.parse_outgoing_tell_packet(data)

        if settings.debug_mode then
            windower.add_to_chat(123, string.format('Sendoria DEBUG: Outgoing Tell to %s: %s', target, message))
        end

        -- Check cooldown and send
        if Chat.check_cooldown('Tell', settings) then
            local final_message = windower.convert_auto_trans(message) or message
            -- Send notification asynchronously to prevent game freeze
            coroutine.schedule(function()
                send_notification(player_name, final_message, 'Tell')
            end, 0.1)
        end
    end
end)

--[[
* Timer event handler for checking Discord responses
--]]
windower.register_event('prerender', function()
    if not settings.relay_enabled then
        return
    end

    relay_timer = relay_timer + 1
    if relay_timer >= (settings.relay_interval * 60) then -- Convert seconds to frames (60 FPS)
        relay_timer = 0

        -- Check for Discord responses
        local responses = Chat.read_discord_responses(settings)
        for i, response in ipairs(responses) do
            if settings.debug_mode then
                windower.add_to_chat(123, string.format('Sendoria RELAY: Processing %s response: %s',
                    response.chat_type, response.message))
            end

            -- Add a small delay between messages to prevent flooding
            coroutine.schedule(function()
                local success, error_msg = Chat.inject_message_to_game(response.chat_type, response.message,
                response.target)
                if not success and settings.debug_mode then
                    windower.add_to_chat(123, string.format('Sendoria RELAY ERROR: %s', error_msg))
                end
            end, (i - 1) * 0.5) -- 0.5 second delay between each message
        end
    end
end)

--[[
* Command handler
--]]
windower.register_event('addon command', function(command, ...)
    local args = { ... }
    command = command and command:lower() or ''

    -- Show status if no command
    if command == '' then
        Commands.show_status(settings)
        return
    end

    -- Direct chat type commands: //tn <type> <on/off>
    local Config = require('lib/config')
    if Config.chat_type_map[command] and #args >= 1 then
        Commands.toggle_chat_monitoring(settings, command, args[1]:lower(), function() Config.save(settings) end)
        return
    end

    -- Other commands
    if command == 'test' then
        -- Send test notification asynchronously (now goes to relay file for bot to process)
        coroutine.schedule(function()
            send_notification('TestUser', 'This is a test notification from Sendoria addon.', 'Test')
        end, 0.1)
        windower.add_to_chat(123, 'Sendoria: Test notification sent to relay file for Discord bot.')
    elseif command == 'toggle' then
        settings.enabled = not settings.enabled
        Config.save(settings)
        windower.add_to_chat(123,
            string.format('Sendoria: Notifications %s', settings.enabled and 'enabled' or 'disabled'))
    elseif command == 'debug' then
        settings.debug_mode = not settings.debug_mode
        Config.save(settings)
        windower.add_to_chat(123,
            string.format('Sendoria: Debug mode %s', settings.debug_mode and 'enabled' or 'disabled'))
    elseif command == 'reload' then
        Config.reload(settings)
        windower.add_to_chat(123, 'Sendoria: Settings reloaded.')
    elseif command == 'status' then
        Commands.show_monitoring_status(settings)
    elseif command == 'ping' then
        windower.add_to_chat(123, 'Sendoria: Testing Discord bot connection...')
        windower.add_to_chat(123, 'Make sure the Discord bot (discord_bot.py) is running!')
    elseif command == 'help' then
        Commands.show_help()
    elseif command == 'multichar' then
        Commands.show_multichar_help()
    elseif command == 'relay' then
        if #args >= 1 then
            Commands.toggle_relay(settings, args[1]:lower(), function() Config.save(settings) end)
        else
            Commands.show_relay_status(settings)
        end
    elseif command == 'clean' then
        Commands.clean_relay_files(settings)
    else
        windower.add_to_chat(123, 'Sendoria: Unknown command. Use //send help for available commands')
    end
end)

-- Print startup message
windower.add_to_chat(123, 'Sendoria: Loaded successfully. Use //send help for commands.')
