--[[
* Sendoria Commands Module
* Handles all addon commands and user interaction
--]]

local Commands = {}

function Commands.show_status(settings)
    windower.add_to_chat(123, 'Sendoria: Status - ' .. (settings.enabled and 'ENABLED' or 'DISABLED'))
    windower.add_to_chat(123, 'Sendoria: Discord - ' .. (settings.discord_enabled and 'ENABLED' or 'DISABLED'))
    windower.add_to_chat(123, 'Sendoria: Debug - ' .. (settings.debug_mode and 'ON' or 'OFF'))
    windower.add_to_chat(123,
        'Sendoria: Webhook - ' .. (settings.webhook_url ~= '' and 'CONFIGURED' or 'NOT CONFIGURED'))
    windower.add_to_chat(123, 'Sendoria: Cooldown - ' .. settings.cooldown .. ' seconds')
    windower.add_to_chat(123, 'Sendoria: Use //send help for commands')
end

function Commands.show_monitoring_status(settings)
    windower.add_to_chat(123, 'Sendoria Monitoring Status:')
    windower.add_to_chat(123, 'Tells: ' .. (settings.monitor_tells and 'ON' or 'OFF'))
    windower.add_to_chat(123, 'Party: ' .. (settings.monitor_party and 'ON' or 'OFF'))
    windower.add_to_chat(123, 'Linkshell1: ' .. (settings.monitor_linkshell1 and 'ON' or 'OFF'))
    windower.add_to_chat(123, 'Linkshell2: ' .. (settings.monitor_linkshell2 and 'ON' or 'OFF'))
    windower.add_to_chat(123, 'Say: ' .. (settings.monitor_say and 'ON' or 'OFF'))
    windower.add_to_chat(123, 'Shout: ' .. (settings.monitor_shout and 'ON' or 'OFF'))
    windower.add_to_chat(123, 'Yell: ' .. (settings.monitor_yell and 'ON' or 'OFF'))
    windower.add_to_chat(123, 'Unity: ' .. (settings.monitor_unity and 'ON' or 'OFF'))
    windower.add_to_chat(123, 'Outgoing: ' .. (settings.monitor_outgoing and 'ON' or 'OFF'))
    windower.add_to_chat(123,
        'Batching: ' .. (settings.enable_batching and 'ON' or 'OFF') .. ' (interval: ' .. settings.batch_interval .. 's)')
end

function Commands.show_webhook_status(settings)
    windower.add_to_chat(123, 'Sendoria Webhook Configuration:')
    windower.add_to_chat(123, 'Main/Fallback: ' .. (settings.webhook_url ~= '' and 'CONFIGURED' or 'NOT SET'))
    windower.add_to_chat(123, 'Tell: ' .. (settings.webhook_tell ~= '' and 'CONFIGURED' or 'Using Main'))
    windower.add_to_chat(123, 'Party: ' .. (settings.webhook_party ~= '' and 'CONFIGURED' or 'Using Main'))
    windower.add_to_chat(123, 'Linkshell1: ' .. (settings.webhook_linkshell1 ~= '' and 'CONFIGURED' or 'Using Main'))
    windower.add_to_chat(123, 'Linkshell2: ' .. (settings.webhook_linkshell2 ~= '' and 'CONFIGURED' or 'Using Main'))
    windower.add_to_chat(123, 'Say: ' .. (settings.webhook_say ~= '' and 'CONFIGURED' or 'Using Main'))
    windower.add_to_chat(123, 'Shout: ' .. (settings.webhook_shout ~= '' and 'CONFIGURED' or 'Using Main'))
    windower.add_to_chat(123, 'Yell: ' .. (settings.webhook_yell ~= '' and 'CONFIGURED' or 'Using Main'))
    windower.add_to_chat(123, 'Unity: ' .. (settings.webhook_unity ~= '' and 'CONFIGURED' or 'Using Main'))
    windower.add_to_chat(123, 'Configure webhooks in: /windower/addons/tellnotifier/data/settings.xml')
end

function Commands.show_help()
    windower.add_to_chat(123, 'Sendoria Commands:')
    windower.add_to_chat(123, '//send <type> <on/off> - Enable/disable chat types:')
    windower.add_to_chat(123, '  Examples: //send tell on, //send party off, //send yell on')
    windower.add_to_chat(123, '  Types: tell, party, say, shout, yell, unity, ls1, ls2, outgoing')
    windower.add_to_chat(123, '//send test - Send a test message to Discord')
    windower.add_to_chat(123, '//send toggle - Toggle all relay on/off')
    windower.add_to_chat(123, '//send status - Show monitoring status for all chat types')
    windower.add_to_chat(123, '//send debug - Toggle debug mode')
    windower.add_to_chat(123, '//send reload - Reload settings')
    windower.add_to_chat(123, '//send ping - Check Discord bot status')
    windower.add_to_chat(123, '//send help - Show this help')
    windower.add_to_chat(123, '//send relay <on/off> - Enable/disable Discord relay mode')
    windower.add_to_chat(123, '//send relay - Show relay configuration status')
    windower.add_to_chat(123, '//send clean - Clean old chat logs')
    windower.add_to_chat(123, 'Discord: Type in Discord channels to send to game')
    windower.add_to_chat(123, 'Tells: Use "/tell PlayerName message" or "/t PlayerName message" in #tells channel')
end

function Commands.show_multichar_help()
    windower.add_to_chat(123, 'Sendoria Multi-Character Setup:')
    windower.add_to_chat(123, '1. Load addon on each character: //lua load tellnotifier')
    windower.add_to_chat(123, '2. Each character gets their own settings file automatically')
    windower.add_to_chat(123, '3. Set webhooks per character in settings.xml')
    windower.add_to_chat(123, '4. For shared server, use same webhook URLs')
    windower.add_to_chat(123, '5. For separate channels, use per-chat-type webhooks')
    windower.add_to_chat(123, '6. Messages show [CharacterName] prefix for identification')
    windower.add_to_chat(123, 'Example: [Palmer] FFXI Tell from Smacksterr: Hello!')
end

function Commands.show_relay_status(settings)
    windower.add_to_chat(123, 'Sendoria Relay Status:')
    windower.add_to_chat(123, 'Relay Mode: ' .. (settings.relay_enabled and 'ENABLED' or 'DISABLED'))
    if settings.relay_enabled then
        windower.add_to_chat(123, 'Chat Logging: ' .. (settings.relay_log_all_chat and 'ON' or 'OFF'))
        windower.add_to_chat(123, 'Check Interval: ' .. settings.relay_interval .. ' seconds')
        windower.add_to_chat(123, 'Relay File: ' .. settings.relay_file_path)
        windower.add_to_chat(123, 'Response File: ' .. settings.response_file_path)
        windower.add_to_chat(123, 'Use //send relay off to disable relay mode')
    else
        windower.add_to_chat(123, 'Use //send relay on to enable relay mode')
    end
end

function Commands.toggle_relay(settings, state, save_func)
    if state == 'on' or state == 'true' or state == '1' then
        settings.relay_enabled = true
        save_func()
        windower.add_to_chat(123, 'Sendoria: Relay mode enabled')
        windower.add_to_chat(123, 'Chat will be logged to: ' .. settings.relay_file_path)
        windower.add_to_chat(123, 'Discord responses read from: ' .. settings.response_file_path)
    elseif state == 'off' or state == 'false' or state == '0' then
        settings.relay_enabled = false
        save_func()
        windower.add_to_chat(123, 'Sendoria: Relay mode disabled')
    else
        windower.add_to_chat(123, 'Sendoria: Usage: //send relay <on/off>')
        return false
    end
    return true
end

function Commands.clean_relay_files(settings)
    local file_path = windower.addon_path .. settings.relay_file_path
    local file = io.open(file_path, 'w')
    if file then
        file:close()
        windower.add_to_chat(123, 'Sendoria: Chat relay file cleaned')
    else
        windower.add_to_chat(123, 'Sendoria: Failed to clean relay file')
    end
end

function Commands.toggle_chat_monitoring(settings, chat_type, state, save_func)
    local Config = require('lib/config')
    local setting_name = Config.chat_type_map[chat_type]

    if not setting_name then
        windower.add_to_chat(123,
            'Sendoria: Valid types: tells, party, linkshell1/ls1, linkshell2/ls2, say, shout, yell, unity, outgoing')
        return false
    end

    if state == 'on' or state == 'true' or state == '1' then
        settings[setting_name] = true
        save_func()
        windower.add_to_chat(123, string.format('Sendoria: %s monitoring enabled', chat_type:upper()))
        return true
    elseif state == 'off' or state == 'false' or state == '0' then
        settings[setting_name] = false
        save_func()
        windower.add_to_chat(123, string.format('Sendoria: %s monitoring disabled', chat_type:upper()))
        return true
    else
        windower.add_to_chat(123, string.format('Sendoria: Usage: //send %s <on/off>', chat_type))
        return false
    end
end

return Commands
