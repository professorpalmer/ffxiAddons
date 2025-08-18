--[[
* Addons - Copyright (c) 2024 Windower Development Team
* Contact: https://www.windower.net/
* Contact: https://discord.gg/windower
*
* This file is part of Windower.
*
* Windower is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Windower is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with Windower.  If not, see <https://www.gnu.org/licenses/>.
--]]

_addon.name      = 'TellNotifier'
_addon.author    = 'Palmer (Zodiarchy @ Asura)'
_addon.version   = '1.0'
_addon.desc      = 'Sends Discord notifications when you receive chat messages.'
_addon.commands  = {'tellnotifier', 'tn'}

require('tables')
require('strings')
local config = require('config')
local https = require('ssl.https')
local ssl = require('ssl')
local ltn12 = require('ltn12')

-- Default Settings
local default_settings = T{
    webhook_url = '',
    enabled = true,
    discord_enabled = true,
    cooldown = 1,
    debug_mode = false,
    -- Chat modes to monitor (add/remove as needed)
    monitor_tells = true,         -- mode 3 = tells
    monitor_party = false,        -- mode 4 = party chat
    monitor_linkshell1 = false,   -- mode 2 = linkshell 1 chat
    monitor_linkshell2 = false,   -- mode 27 = linkshell 2 chat
    monitor_say = false,          -- mode 0 = say chat
    monitor_shout = false,        -- mode 1 = shout chat
    monitor_yell = false,         -- mode 26 = yell chat
    monitor_unity = false,        -- mode 33 = unity chat
}

-- Load settings using Windower's config system
local settings = config.load(default_settings)

-- TellNotifier Variables
local tellnotifier = T{
    settings = settings,
    last_tell_time = 0,
}

--[[
* Saves settings
--]]
local function SaveSettings()
    config.save(settings)
end

--[[
* Sends Discord notification via webhook
*
* @param {string} sender - The name of the person who sent the message
* @param {string} message - The message content
* @param {string} chat_type - The type of chat (Tell, Party, etc.)
--]]
local function SendDiscordNotification(sender, message, chat_type)
    if not settings.discord_enabled or not settings.enabled then
        return
    end
    
    if settings.webhook_url == '' then
        if settings.debug_mode then
            windower.add_to_chat(123, 'TellNotifier: Discord webhook URL not configured.')
        end
        return
    end
    
    -- Create the notification content with chat type
    local notification_text = string.format('FFXI %s from %s: %s', chat_type or 'Message', sender, message)
    
    -- Escape text for JSON
    local json_safe_text = notification_text:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
    
    -- Create JSON payload manually
    local payload = string.format('{"content":"%s"}', json_safe_text)
    
    -- Prepare request with SSL options
    local response_body = {}
    local request_result, response_code, response_headers, status = https.request{
        url = settings.webhook_url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#payload)
        },
        source = ltn12.source.string(payload),
        sink = ltn12.sink.table(response_body),
        protocol = "tlsv1_2",
        verify = "none",  -- Disable SSL verification for Discord
        options = "all"
    }
    
    -- Check if request succeeded
    if not request_result then
        -- HTTPS failed, try curl as fallback (silently unless debug mode)
        if settings.debug_mode then
            windower.add_to_chat(123, string.format('TellNotifier: HTTPS failed (%s), trying curl fallback...', tostring(response_code)))
        end
        
        -- Escape for curl command
        local curl_text = notification_text:gsub('"', '\\"')
        local command = string.format('curl -s -X POST -H "Content-Type: application/json" -d "{\\"content\\":\\"%s\\"}" "%s"',
            curl_text,
            settings.webhook_url
        )
        
        -- Use io.popen to avoid CMD window
        local handle = io.popen(command)
        if handle then
            handle:read("*a")
            handle:close()
            if settings.debug_mode then
                windower.add_to_chat(123, string.format('TellNotifier: Sent via curl fallback for %s from %s', chat_type or 'message', sender))
            end
        end
    elseif response_code ~= 204 then
        if settings.debug_mode then
            windower.add_to_chat(123, string.format('TellNotifier: Discord returned code %s (expected 204)', tostring(response_code)))
            windower.add_to_chat(123, string.format('TellNotifier: Response: %s', table.concat(response_body)))
        end
    elseif settings.debug_mode then
        windower.add_to_chat(123, string.format('TellNotifier: Discord notification sent via HTTPS for %s from %s', chat_type or 'message', sender))
    end
end

-- Auto-translate lookup table (basic common phrases)
local auto_translate = {
    -- Format: [type_id] = "text"
    ['2_2'] = 'Hello!',
    ['2_3'] = 'Good morning.',
    ['2_4'] = 'Good afternoon.',
    ['2_5'] = 'Good evening.',
    ['2_6'] = 'Good night.',
    ['2_7'] = 'Thank you.',
    ['2_8'] = 'You\'re welcome.',
    ['2_9'] = 'Excuse me.',
    ['2_10'] = 'I\'m sorry.',
    ['2_11'] = 'Goodbye.',
    ['2_12'] = 'See you later.',
    ['2_13'] = 'Nice to meet you.',
    ['2_14'] = 'Take care.',
    ['2_15'] = 'Good luck.',
    ['2_16'] = 'Congratulations!',
    
    -- Numbers (common gil amounts)
    ['32_100'] = '100k',
    ['32_101'] = '1M',
    ['32_102'] = '10M',
    ['32_1'] = '1k',
    ['32_10'] = '10k',
    ['32_50'] = '50k',
    ['32_500'] = '500k',
    
    -- Common game terms
    ['3_1'] = 'Yes',
    ['3_2'] = 'No',
    ['3_3'] = 'Please',
    ['3_4'] = 'Thanks',
    ['3_5'] = 'Party',
    ['3_6'] = 'Alliance',
    ['3_7'] = 'Linkshell',
    ['3_8'] = 'Tell',
    ['3_9'] = 'Say',
    ['3_10'] = 'Shout',
}

-- Chat mode lookup table (based on actual testing)
local chat_modes = {
    [0] = {name = 'Say', setting = 'monitor_say'},                -- Confirmed: mode 0
    [1] = {name = 'Shout', setting = 'monitor_shout'},            -- Confirmed: mode 1  
    [2] = {name = 'Linkshell1', setting = 'monitor_linkshell1'},  -- Confirmed
    [3] = {name = 'Tell', setting = 'monitor_tells'},             -- Confirmed
    [4] = {name = 'Party', setting = 'monitor_party'},            -- Confirmed
    [5] = {name = 'Linkshell1', setting = 'monitor_linkshell1'},  -- Confirmed: mode 5 is LS
    [26] = {name = 'Yell', setting = 'monitor_yell'},             -- Confirmed
    [27] = {name = 'Linkshell2', setting = 'monitor_linkshell2'}, -- Confirmed
    [33] = {name = 'Unity', setting = 'monitor_unity'},           -- Confirmed
}

--[[
* Event: chat message
* desc : Event called when the addon is processing chat messages.
--]]
windower.register_event('chat message', function(message, sender, mode, is_gm)
    -- Enhanced debug output to see ALL chat messages
    if settings.debug_mode then
        windower.add_to_chat(123, string.format('TellNotifier DEBUG: Mode=%d, Sender=%s, Message=%s', mode, sender or 'nil', message))
    end
    
    local chat_info = chat_modes[mode]
    
    -- Check if we should monitor this chat mode
    if chat_info and settings[chat_info.setting] then
        if settings.debug_mode then
            windower.add_to_chat(123, string.format('TellNotifier: Found matching chat type %s (mode %d), checking settings...', chat_info.name, mode))
            windower.add_to_chat(123, string.format('TellNotifier: Setting %s = %s', chat_info.setting, tostring(settings[chat_info.setting])))
        end
        
        local current_time = os.time()
        
        -- Check cooldown to prevent spam
        if current_time - tellnotifier.last_tell_time < settings.cooldown then
            if settings.debug_mode then
                windower.add_to_chat(123, string.format('TellNotifier: %s blocked due to cooldown', chat_info.name))
            end
            return
        end
        
        tellnotifier.last_tell_time = current_time
        
        -- Send notification with chat type
        SendDiscordNotification(sender, message, chat_info.name)
        
        if settings.debug_mode then
            windower.add_to_chat(123, string.format('TellNotifier: %s notification sent from %s: %s', chat_info.name, sender, message))
        end
    elseif settings.debug_mode then
        windower.add_to_chat(123, string.format('TellNotifier: Chat mode %d (%s) from %s: %s', mode, chat_info and chat_info.name or 'Unknown', sender or 'Unknown', message))
    end
end)

--[[
* Event: addon command
* desc : Event called when the addon is processing a command.
--]]
windower.register_event('addon command', function(command, ...)
    local args = T{...}
    command = command and command:lower() or ''
    
    -- Handle: //tn (no args) - Shows status
    if command == '' then
        windower.add_to_chat(123, 'TellNotifier: Status - ' .. (settings.enabled and 'ENABLED' or 'DISABLED'))
        windower.add_to_chat(123, 'TellNotifier: Discord - ' .. (settings.discord_enabled and 'ENABLED' or 'DISABLED'))
        windower.add_to_chat(123, 'TellNotifier: Debug - ' .. (settings.debug_mode and 'ON' or 'OFF'))
        windower.add_to_chat(123, 'TellNotifier: Webhook - ' .. (settings.webhook_url ~= '' and 'CONFIGURED' or 'NOT CONFIGURED'))
        windower.add_to_chat(123, 'TellNotifier: Cooldown - ' .. settings.cooldown .. ' seconds')
        windower.add_to_chat(123, 'TellNotifier: Use //tn help for commands')
        return
    end

    -- Handle: //tn test
    if command == 'test' then
        SendDiscordNotification('TestUser', 'This is a test notification from TellNotifier addon.', 'Test')
        windower.add_to_chat(123, 'TellNotifier: Test notification sent to Discord.')
        return
    end

    -- Handle: //tn toggle
    if command == 'toggle' then
        settings.enabled = not settings.enabled
        SaveSettings()
        windower.add_to_chat(123, string.format('TellNotifier: Notifications %s', settings.enabled and 'enabled' or 'disabled'))
        return
    end

    -- Handle: //tn debug
    if command == 'debug' then
        settings.debug_mode = not settings.debug_mode
        SaveSettings()
        windower.add_to_chat(123, string.format('TellNotifier: Debug mode %s', settings.debug_mode and 'enabled' or 'disabled'))
        return
    end

    -- Handle: //tn seturl <url>
    if command == 'seturl' then
        if #args > 0 then
            settings.webhook_url = table.concat(args, ' ')
            SaveSettings()
            windower.add_to_chat(123, 'TellNotifier: Webhook URL set successfully.')
        else
            windower.add_to_chat(123, 'TellNotifier: Please provide a webhook URL.')
        end
        return
    end

    -- Handle: //tn reload
    if command == 'reload' then
        config.reload(settings)
        windower.add_to_chat(123, 'TellNotifier: Settings reloaded.')
        return
    end

    -- Handle: //tn ping
    if command == 'ping' then
        if settings.webhook_url == '' then
            windower.add_to_chat(123, 'TellNotifier: No webhook URL configured.')
        else
            windower.add_to_chat(123, 'TellNotifier: Testing webhook connection...')
            
            -- Create JSON payload manually
            local payload = '{"content":"Ping test from TellNotifier addon"}'
            
            -- Prepare request with SSL options
            local response_body = {}
            local request_result, response_code, response_headers, status = https.request{
                url = settings.webhook_url,
                method = "POST",
                headers = {
                    ["Content-Type"] = "application/json",
                    ["Content-Length"] = tostring(#payload)
                },
                source = ltn12.source.string(payload),
                sink = ltn12.sink.table(response_body),
                protocol = "tlsv1_2",
                verify = "none",  -- Disable SSL verification for Discord
                options = "all"
            }
            
            if not request_result then
                windower.add_to_chat(123, string.format('TellNotifier: Ping ERROR - %s', tostring(response_code)))
                windower.add_to_chat(123, string.format('TellNotifier: Webhook URL: %s', settings.webhook_url))
            elseif response_code == 204 then
                windower.add_to_chat(123, 'TellNotifier: Ping test sent successfully. Check Discord for the message!')
            else
                windower.add_to_chat(123, string.format('TellNotifier: Ping test failed. Response code: %s', tostring(response_code)))
                windower.add_to_chat(123, string.format('TellNotifier: Response: %s', table.concat(response_body)))
            end
        end
        return
    end

    -- Handle: //tn monitor <type> <on/off>
    if command == 'monitor' then
        if #args >= 2 then
            local chat_type = args[1]:lower()
            local state = args[2]:lower()
            local setting_map = {
                tells = 'monitor_tells',
                tell = 'monitor_tells',
                party = 'monitor_party',
                linkshell1 = 'monitor_linkshell1',
                ls1 = 'monitor_linkshell1',
                ls = 'monitor_linkshell1',  -- default to LS1 for backwards compatibility
                linkshell = 'monitor_linkshell1',
                linkshell2 = 'monitor_linkshell2',
                ls2 = 'monitor_linkshell2',
                say = 'monitor_say',
                shout = 'monitor_shout',
                yell = 'monitor_yell',
                unity = 'monitor_unity',
            }
            
            local setting_name = setting_map[chat_type]
            if setting_name then
                if state == 'on' or state == 'true' or state == '1' then
                    settings[setting_name] = true
                    SaveSettings()
                    windower.add_to_chat(123, string.format('TellNotifier: %s monitoring enabled', chat_type:upper()))
                elseif state == 'off' or state == 'false' or state == '0' then
                    settings[setting_name] = false
                    SaveSettings()
                    windower.add_to_chat(123, string.format('TellNotifier: %s monitoring disabled', chat_type:upper()))
                else
                    windower.add_to_chat(123, 'TellNotifier: Use on/off, true/false, or 1/0')
                end
            else
                windower.add_to_chat(123, 'TellNotifier: Valid types: tells, party, linkshell1/ls1, linkshell2/ls2, say, shout, yell, unity')
            end
        else
            windower.add_to_chat(123, 'TellNotifier: Usage: //tn monitor <type> <on/off>')
        end
        return
    end

    -- Handle: //tn status
    if command == 'status' then
        windower.add_to_chat(123, 'TellNotifier Monitoring Status:')
        windower.add_to_chat(123, 'Tells: ' .. (settings.monitor_tells and 'ON' or 'OFF'))
        windower.add_to_chat(123, 'Party: ' .. (settings.monitor_party and 'ON' or 'OFF'))
        windower.add_to_chat(123, 'Linkshell1: ' .. (settings.monitor_linkshell1 and 'ON' or 'OFF'))
        windower.add_to_chat(123, 'Linkshell2: ' .. (settings.monitor_linkshell2 and 'ON' or 'OFF'))
        windower.add_to_chat(123, 'Say: ' .. (settings.monitor_say and 'ON' or 'OFF'))
        windower.add_to_chat(123, 'Shout: ' .. (settings.monitor_shout and 'ON' or 'OFF'))
        windower.add_to_chat(123, 'Yell: ' .. (settings.monitor_yell and 'ON' or 'OFF'))
        windower.add_to_chat(123, 'Unity: ' .. (settings.monitor_unity and 'ON' or 'OFF'))
        return
    end

    -- Handle: //tn help
    if command == 'help' then
        windower.add_to_chat(123, 'TellNotifier Commands:')
        windower.add_to_chat(123, '//tn test - Send a test notification')
        windower.add_to_chat(123, '//tn toggle - Toggle notifications on/off')
        windower.add_to_chat(123, '//tn debug - Toggle debug mode')
        windower.add_to_chat(123, '//tn monitor <type> <on/off> - Enable/disable chat type')
        windower.add_to_chat(123, '//tn status - Show monitoring status for all chat types')
        windower.add_to_chat(123, '//tn seturl <url> - Set Discord webhook URL')
        windower.add_to_chat(123, '//tn reload - Reload settings')
        windower.add_to_chat(123, '//tn ping - Test webhook connection')
        windower.add_to_chat(123, '//tn help - Show this help')
        return
    end

    -- Unknown command
    windower.add_to_chat(123, 'TellNotifier: Unknown command. Use //tn help for available commands')
end)

-- Print startup message
windower.add_to_chat(123, 'TellNotifier: Loaded successfully. Use //tn help for commands.')
