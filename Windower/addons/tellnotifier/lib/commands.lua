--[[
* TellNotifier Commands Module
* Handles all addon commands and user interaction
--]]

local Commands = {}

function Commands.show_status(settings)
    windower.add_to_chat(123, 'TellNotifier: Status - ' .. (settings.enabled and 'ENABLED' or 'DISABLED'))
    windower.add_to_chat(123, 'TellNotifier: Discord - ' .. (settings.discord_enabled and 'ENABLED' or 'DISABLED'))
    windower.add_to_chat(123, 'TellNotifier: Debug - ' .. (settings.debug_mode and 'ON' or 'OFF'))
    windower.add_to_chat(123,
        'TellNotifier: Webhook - ' .. (settings.webhook_url ~= '' and 'CONFIGURED' or 'NOT CONFIGURED'))
    windower.add_to_chat(123, 'TellNotifier: Cooldown - ' .. settings.cooldown .. ' seconds')
    windower.add_to_chat(123, 'TellNotifier: Use //tn help for commands')
end

function Commands.show_monitoring_status(settings)
    windower.add_to_chat(123, 'TellNotifier Monitoring Status:')
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
    windower.add_to_chat(123, 'TellNotifier Webhook Configuration:')
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
    windower.add_to_chat(123, 'TellNotifier Commands:')
    windower.add_to_chat(123, '//tn <type> <on/off> - Enable/disable chat types:')
    windower.add_to_chat(123, '  Examples: //tn tell on, //tn party off, //tn yell on')
    windower.add_to_chat(123, '  Types: tell, party, say, shout, yell, unity, ls1, ls2, outgoing')
    windower.add_to_chat(123, '//tn test - Send a test notification')
    windower.add_to_chat(123, '//tn testunity - Test Unity message parsing (for Domain Invasion issues)')
    windower.add_to_chat(123, '//tn toggle - Toggle all notifications on/off')
    windower.add_to_chat(123, '//tn status - Show monitoring status for all chat types')
    windower.add_to_chat(123, '//tn webhooks - Show webhook configuration status')
    windower.add_to_chat(123, '//tn debug - Toggle debug mode')
    windower.add_to_chat(123, '//tn reload - Reload settings')
    windower.add_to_chat(123, '//tn ping - Test webhook connection')
    windower.add_to_chat(123, '//tn help - Show this help')
    windower.add_to_chat(123, '//tn multichar - Show multi-character setup instructions')
    windower.add_to_chat(123, 'Configure webhooks in: /windower/addons/tellnotifier/data/settings.xml')
end

function Commands.show_multichar_help()
    windower.add_to_chat(123, 'TellNotifier Multi-Character Setup:')
    windower.add_to_chat(123, '1. Load addon on each character: //lua load tellnotifier')
    windower.add_to_chat(123, '2. Each character gets their own settings file automatically')
    windower.add_to_chat(123, '3. Set webhooks per character in settings.xml')
    windower.add_to_chat(123, '4. For shared server, use same webhook URLs')
    windower.add_to_chat(123, '5. For separate channels, use per-chat-type webhooks')
    windower.add_to_chat(123, '6. Messages show [CharacterName] prefix for identification')
    windower.add_to_chat(123, 'Example: [Palmer] FFXI Tell from Smacksterr: Hello!')
end

function Commands.toggle_chat_monitoring(settings, chat_type, state, save_func)
    local Config = require('lib/config')
    local setting_name = Config.chat_type_map[chat_type]

    if not setting_name then
        windower.add_to_chat(123,
            'TellNotifier: Valid types: tells, party, linkshell1/ls1, linkshell2/ls2, say, shout, yell, unity, outgoing')
        return false
    end

    if state == 'on' or state == 'true' or state == '1' then
        settings[setting_name] = true
        save_func()
        windower.add_to_chat(123, string.format('TellNotifier: %s monitoring enabled', chat_type:upper()))
        return true
    elseif state == 'off' or state == 'false' or state == '0' then
        settings[setting_name] = false
        save_func()
        windower.add_to_chat(123, string.format('TellNotifier: %s monitoring disabled', chat_type:upper()))
        return true
    else
        windower.add_to_chat(123, string.format('TellNotifier: Usage: //tn %s <on/off>', chat_type))
        return false
    end
end

return Commands
