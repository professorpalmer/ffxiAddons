--[[
* TellNotifier - Discord Chat Notifications for Windower
* Author: Palmer (Zodiarchy @ Asura)
* Version: 1.4 - Refactored
--]]

_addon.name     = 'TellNotifier'
_addon.author   = 'Palmer (Zodiarchy @ Asura)'
_addon.version  = '1.4'
_addon.desc     = 'Sends Discord notifications when you receive chat messages.'
_addon.commands = { 'tellnotifier', 'tn' }

require('tables')
require('strings')

-- Load modules
local Config = require('lib/config')
local Discord = require('lib/discord')
local Chat = require('lib/chat')
local Commands = require('lib/commands')

-- Load settings
local settings = Config.load()

--[[
* Main notification handler
--]]
local function send_notification(sender, message, chat_type)
    if not settings.discord_enabled or not settings.enabled then
        return
    end

    local webhook_url = Config.get_webhook_for_chat_type(settings, chat_type)
    local player = windower.ffxi.get_player()
    local char_name = player and player.name or 'Unknown'
    Discord.send_notification(webhook_url, sender, message, chat_type, settings.debug_mode, char_name)
end

--[[
* Chat message event handler
--]]
windower.register_event('chat message', function(message, sender, mode, is_gm)
    if settings.debug_mode then
        windower.add_to_chat(123,
            string.format('TellNotifier DEBUG: Mode=%d, Sender=%s, Message=%s', mode or -1, sender or 'nil',
                message or 'nil'))
    end

    -- Skip our own messages if outgoing monitoring is enabled (handled by outgoing chunk event)
    local player = windower.ffxi.get_player()
    if player and sender == player.name and settings.monitor_outgoing then
        if settings.debug_mode then
            windower.add_to_chat(123,
                'TellNotifier DEBUG: Skipping own message in chat event (handled by outgoing chunk)')
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
            windower.add_to_chat(123, string.format('TellNotifier: %s blocked due to cooldown', chat_info.name))
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
        windower.add_to_chat(123, string.format('TellNotifier: %s notification sent from %s', chat_info.name, sender))
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
            string.format('TellNotifier DEBUG: Outgoing packet 0x%03X - modified=%s, size=%d', id, tostring(modified),
                #data))
    end

    local player_name = windower.ffxi.get_player().name or 'Unknown'

    if id == 0x0B5 then
        -- Speech packet
        local mode, message, chat_type = Chat.parse_outgoing_speech_packet(data)

        if not mode then
            if settings.debug_mode and chat_type then
                windower.add_to_chat(123, 'TellNotifier DEBUG: ' .. chat_type)
            end
            return
        end

        -- Check for duplicates
        local is_duplicate, time_diff = Chat.is_duplicate_outgoing(mode, message)
        if is_duplicate then
            if settings.debug_mode then
                windower.add_to_chat(123,
                    string.format('TellNotifier DEBUG: Duplicate outgoing message detected - skipping (time_diff=%.3f)',
                        time_diff))
            end
            return
        end

        if settings.debug_mode then
            windower.add_to_chat(123, string.format('TellNotifier DEBUG: Outgoing %s - Message=%s', chat_type, message))
        end

        -- Check cooldown and send
        if Chat.check_cooldown(chat_type, settings.cooldown, settings.enable_batching) then
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
            windower.add_to_chat(123, string.format('TellNotifier DEBUG: Outgoing Tell to %s: %s', target, message))
        end

        -- Check cooldown and send
        if Chat.check_cooldown('Tell', settings.cooldown, settings.enable_batching) then
            local final_message = windower.convert_auto_trans(message) or message
            -- Send notification asynchronously to prevent game freeze
            coroutine.schedule(function()
                send_notification(player_name, final_message, 'Tell')
            end, 0.1)
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
        -- Send test notification asynchronously
        coroutine.schedule(function()
            send_notification('TestUser', 'This is a test notification from TellNotifier addon.', 'Test')
        end, 0.1)
        windower.add_to_chat(123, 'TellNotifier: Test notification sent to Discord.')
    elseif command == 'toggle' then
        settings.enabled = not settings.enabled
        Config.save(settings)
        windower.add_to_chat(123,
            string.format('TellNotifier: Notifications %s', settings.enabled and 'enabled' or 'disabled'))
    elseif command == 'debug' then
        settings.debug_mode = not settings.debug_mode
        Config.save(settings)
        windower.add_to_chat(123,
            string.format('TellNotifier: Debug mode %s', settings.debug_mode and 'enabled' or 'disabled'))
    elseif command == 'reload' then
        Config.reload(settings)
        windower.add_to_chat(123, 'TellNotifier: Settings reloaded.')
    elseif command == 'status' then
        Commands.show_monitoring_status(settings)
    elseif command == 'webhooks' then
        Commands.show_webhook_status(settings)
    elseif command == 'ping' then
        windower.add_to_chat(123, 'TellNotifier: Testing webhook connection...')
        -- Test webhook asynchronously to prevent freezing
        coroutine.schedule(function()
            local player = windower.ffxi.get_player()
            local char_name = player and player.name or 'Unknown'
            local success, msg = Discord.test_webhook(settings.webhook_url, char_name)
            if success then
                windower.add_to_chat(123, 'TellNotifier: Ping test sent successfully. Check Discord for the message!')
            else
                windower.add_to_chat(123, string.format('TellNotifier: Ping test failed. %s', msg))
            end
        end, 0.1)
    elseif command == 'help' then
        Commands.show_help()
    elseif command == 'multichar' then
        Commands.show_multichar_help()
    else
        windower.add_to_chat(123, 'TellNotifier: Unknown command. Use //tn help for available commands')
    end
end)

-- Print startup message
windower.add_to_chat(123, 'TellNotifier: Loaded successfully. Use //tn help for commands.')
