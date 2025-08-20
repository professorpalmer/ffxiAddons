--[[
* Addons - Copyright (c) 2024 Ashita Development Team
* Contact: https://www.ashitaxi.com/
* Contact: https://discord.gg/Ashita
*
* This file is part of Ashita.
*
* Ashita is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Ashita is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with Ashita.  If not, see <https://www.gnu.org/licenses/>.
--]]

addon.name      = 'tellnotifier';
addon.author    = 'Palmer (Zodiarchy @ Asura)';
addon.version   = '1.2';
addon.desc      = 'Sends Discord notifications when you receive chat messages.';
addon.link      = 'https://ashitaxi.com/';

require('common');
local imgui = require('imgui');
local ffi = require('ffi');
local settings = require('settings');

-- Try to load socket libraries for HTTP requests
local http_available = false;
local http, ltn12;

-- Try socket.http first (standard LuaSocket)
local status, socket_http = pcall(require, 'socket.http');
if status then
    http = socket_http;
    status, ltn12 = pcall(require, 'ltn12');
    if status then
        http_available = true;
        print('TellNotifier: Using socket.http for Discord notifications');
    end
end

-- Default Settings
local default_settings = T{
    webhook_url = '',
    enabled = true,
    discord_enabled = true,
    cooldown = 1,
    debug_mode = false,
    -- Chat modes to monitor
    monitor_tells = true,         -- mode 3 = tells
    monitor_party = false,        -- mode 4 = party chat
    monitor_linkshell1 = false,   -- mode 5 = linkshell chat
    monitor_linkshell2 = false,   -- mode 27 = linkshell 2 chat
    monitor_say = false,          -- mode 0 = say chat
    monitor_shout = false,        -- mode 1 = shout chat
    monitor_yell = false,         -- mode 26 = yell chat
    monitor_unity = false,        -- mode 33 = unity chat
    monitor_emotes = false,       -- mode 7 = emotes
};

-- TellNotifier Discord Variables
local tellnotifier = T{
    is_open = { true, },
    settings = settings.load(default_settings),
    last_tell_time = 0,
};

--[[
* Saves settings
--]]
local function SaveSettings()
    settings.save();
end

--[[
* Sends Discord notification via webhook
*
* @param {string} sender - The name of the person who sent the message
* @param {string} message - The message content
* @param {string} chat_type - The type of chat (Tell, Party, etc.)
--]]
local function SendDiscordNotification(sender, message, chat_type)
    if not tellnotifier.settings.discord_enabled or not tellnotifier.settings.enabled then
        return;
    end
    
    if tellnotifier.settings.webhook_url == '' then
        if tellnotifier.settings.debug_mode then
            print('TellNotifier: Discord webhook URL not configured.');
        end
        return;
    end
    
    -- Ensure all parameters have valid values
    sender = sender or 'Unknown';
    message = message or 'Empty message';
    chat_type = chat_type or 'Message';
    
    -- Final cleanup of message to remove any auto-translate artifacts
    message = message:gsub('%[AT:%d+_%d+%]', ''):gsub('{%?AT:%d+_%d+%?}', ''):gsub('^%s*(.-)%s*$', '%1');
    
    -- Create the notification content with chat type
    local notification_text = string.format('FFXI %s from %s: %s', chat_type, sender, message);
    
    -- Escape text for JSON
    local json_safe_text = notification_text:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t');
    
    -- Create JSON payload
    local payload = string.format('{"content":"%s"}', json_safe_text);
    
    -- Try socket.http first if available
    if http_available then
        local response_body = {};
        local request_result, response_code, response_headers, status = http.request{
            url = tellnotifier.settings.webhook_url,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(#payload)
            },
            source = ltn12.source.string(payload),
            sink = ltn12.sink.table(response_body)
        };
        
        if response_code == 204 then
            if tellnotifier.settings.debug_mode then
                print(string.format('TellNotifier: Discord notification sent for %s from %s', chat_type or 'message', sender));
            end
        else
            if tellnotifier.settings.debug_mode then
                print(string.format('TellNotifier: Discord returned code %s', tostring(response_code)));
                if response_body and #response_body > 0 then
                    print(string.format('TellNotifier: Response: %s', table.concat(response_body)));
                end
            end
        end
    else
        -- Fallback to curl if socket.http is not available
        if tellnotifier.settings.debug_mode then
            print('TellNotifier: socket.http not available, using curl fallback');
        end
        
        local curl_text = notification_text:gsub('"', '\\"');
        local command = string.format('curl -s -X POST -H "Content-Type: application/json" -d "{\\"content\\":\\"%s\\"}" "%s"',
            curl_text,
            tellnotifier.settings.webhook_url
        );
        
        -- Use io.popen to avoid CMD window
        local handle = io.popen(command .. ' 2>&1');
        if handle then
            local result = handle:read("*a");
            handle:close();
            if tellnotifier.settings.debug_mode then
                print(string.format('TellNotifier: Sent via curl for %s from %s', chat_type or 'message', sender));
                if result and result ~= '' then
                    print(string.format('TellNotifier: Curl result: %s', result));
                end
            end
        end
    end
end



-- Auto-translate lookup table (basic common phrases)
-- NOTE: These mappings may be incorrect for different servers
-- Comment out or modify if translations are wrong
local auto_translate = {
    -- Format: [type_id] = "text"
    -- DISABLED DUE TO INCORRECT MAPPINGS
    -- ['2_2'] = 'Hello!',
    -- ['2_3'] = 'Good morning.',
    -- ['2_4'] = 'Good afternoon.',
    -- ['2_5'] = 'Good evening.',
    -- ['2_6'] = 'Good night.',
    -- ['2_7'] = 'Thank you.',
    -- ['2_8'] = 'You\'re welcome.',
    -- ['2_9'] = 'Excuse me.',
    -- ['2_10'] = 'I\'m sorry.',
    -- ['2_11'] = 'Goodbye.',
    -- ['2_12'] = 'See you later.',
    -- ['2_13'] = 'Nice to meet you.',
    -- ['2_14'] = 'Take care.',
    -- ['2_15'] = 'Good luck.',
    -- ['2_16'] = 'Congratulations!',
    
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
};

-- Chat mode lookup table (TO BE CONFIRMED through testing)
-- Run with debug mode enabled to discover the correct values for your server
local chat_modes = {
    [0] = {name = 'Say', setting = 'monitor_say'},
    [1] = {name = 'Shout', setting = 'monitor_shout'},
    [2] = {name = 'Party', setting = 'monitor_party'},  -- UNCONFIRMED
    [3] = {name = 'Tell', setting = 'monitor_tells'},   -- CONFIRMED from existing code
    [4] = {name = 'Linkshell1', setting = 'monitor_linkshell1'},  -- UNCONFIRMED
    [5] = {name = 'Unity', setting = 'monitor_unity'},  -- UNCONFIRMED
    [6] = {name = 'Linkshell2', setting = 'monitor_linkshell2'},  -- UNCONFIRMED
    [7] = {name = 'Emote', setting = 'monitor_emotes'},  -- UNCONFIRMED
    [26] = {name = 'Yell', setting = 'monitor_yell'},  -- UNCONFIRMED
    -- Add more as discovered through debug mode
};

-- Settings are automatically loaded by the settings.load() call above
print('TellNotifier: Settings loaded successfully');  
print('TellNotifier: Enable debug mode with /tn debug to discover chat type values');

--[[
* event: packet_in
* desc : Event called when the addon is processing incoming packets.
--]]
ashita.events.register('packet_in', 'packet_in_cb', function (e)
    -- Packet: Chat Message (0x0017)
    if (e.id == 0x0017) then
        local chat_type = struct.unpack('B', e.data_modified, 0x04 + 0x01);
        
        -- For tells, the message format is different
        -- Extract the raw message starting from the appropriate offset
        local message_text = '';
        local sender = '';
        
        if chat_type == 3 then  -- Tell message
            -- For tells, extract the full message from the packet
            -- The message typically starts around byte 0x18 (24)
            message_text = e.data_modified:sub(0x18 + 1):gsub('%z', ''); -- Remove null bytes
            
            -- Debug output
            if tellnotifier.settings.debug_mode then
                print(string.format('TellNotifier: Raw tell message: %s', message_text));
            end
            
            -- Parse tell format: "Sender>> Message" or variations
            -- Look for >> pattern which separates sender from message
            local arrow_pos = message_text:find('>>')
            if arrow_pos then
                sender = message_text:sub(1, arrow_pos - 1):gsub('^%s*(.-)%s*$', '%1');
                message_text = message_text:sub(arrow_pos + 2):gsub('^%s*(.-)%s*$', '%1');
            else
                -- Fallback: try to find the first capitalized word
                local first_word = message_text:match('^%s*([A-Z][a-z]+)')
                if first_word then
                    sender = first_word;
                    local _, name_end = message_text:find(sender);
                    if name_end then
                        message_text = message_text:sub(name_end + 1):gsub('^%s*(.-)%s*$', '%1');
                    end
                else
                    sender = 'Unknown';
                end
            end
        else
            -- For other chat types, use simpler extraction
            message_text = e.data_modified:sub(0x18 + 1):gsub('%z', '');
            
            -- Try to extract sender from the beginning of the message
            local first_word = message_text:match('^%s*([A-Z][a-z]+)')
            if first_word then
                sender = first_word;
                local _, name_end = message_text:find(sender);
                if name_end then
                    message_text = message_text:sub(name_end + 1):gsub('^%s*(.-)%s*$', '%1');
                end
            else
                sender = 'Unknown';
            end
        end
        
        
        -- Debug output
        if tellnotifier.settings.debug_mode then
            print(string.format('TellNotifier DEBUG: Chat type %d from %s: %s', chat_type, sender, message_text));
            print('TellNotifier DEBUG: Add this to chat_modes table if needed');
        end
        
        -- Look up chat type in our mapping
        local chat_info = chat_modes[chat_type];
        
        -- Check if we should monitor this chat mode
        if chat_info and tellnotifier.settings[chat_info.setting] then
            if tellnotifier.settings.debug_mode then
                print(string.format('TellNotifier: Found matching chat type %s (mode %d), checking settings...', chat_info.name, chat_type));
                print(string.format('TellNotifier: Setting %s = %s', chat_info.setting, tostring(tellnotifier.settings[chat_info.setting])));
            end
            
            local current_time = os.time();
            
            -- Check cooldown to prevent spam
            if current_time - tellnotifier.last_tell_time < tellnotifier.settings.cooldown then
                if tellnotifier.settings.debug_mode then
                    print(string.format('TellNotifier: %s blocked due to cooldown', chat_info.name));
                end
                return;
            end
            
            tellnotifier.last_tell_time = current_time;
            
            -- Send notification with chat type
            SendDiscordNotification(sender, message_text, chat_info.name);
            
            if tellnotifier.settings.debug_mode then
                print(string.format('TellNotifier: %s notification sent from %s', chat_info.name, sender));
            end
        elseif not chat_info and tellnotifier.settings.debug_mode then
            print(string.format('TellNotifier: Unknown chat type %d - consider adding to chat_modes table', chat_type));
        end
    end
end);

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'present_cb', function ()
    if not tellnotifier.is_open[1] then
        return;
    end
    
    imgui.SetNextWindowBgAlpha(0.8);
    imgui.SetNextWindowSize({ 400, 700 }, ImGuiCond_FirstUseEver);
    
    if (imgui.Begin('TellNotifier Discord', tellnotifier.is_open, ImGuiWindowFlags_None)) then
        imgui.Text('Tell Notifier Discord Configuration');
        imgui.Separator();
        
        -- Enable/Disable
        local enabled_bool = { tellnotifier.settings.enabled };
        if imgui.Checkbox('Enable Notifications', enabled_bool) then
            tellnotifier.settings.enabled = enabled_bool[1];
            SaveSettings();
        end
        
        local discord_enabled_bool = { tellnotifier.settings.discord_enabled };
        if imgui.Checkbox('Enable Discord Notifications', discord_enabled_bool) then
            tellnotifier.settings.discord_enabled = discord_enabled_bool[1];
            SaveSettings();
        end
        
        local debug_bool = { tellnotifier.settings.debug_mode };
        if imgui.Checkbox('Debug Mode (shows chat types)', debug_bool) then
            tellnotifier.settings.debug_mode = debug_bool[1];
            SaveSettings();
        end
        
        imgui.Separator();
        imgui.Text('Discord Setup Instructions:');
        imgui.Text('1. Create Discord server or use existing one');
        imgui.Text('2. Create a channel for notifications');
        imgui.Text('3. Channel Settings → Integrations → Webhooks');
        imgui.Text('4. Create webhook, copy URL');
        imgui.Text('5. Edit tellnotifier.lua OR use /tn seturl');
        imgui.Text('6. Install Discord mobile app for notifications');
        
        imgui.Separator();
        imgui.Text('Discord Webhook URL:');
        imgui.Text(tellnotifier.settings.webhook_url ~= '' and 'Configured ✓' or 'Not configured');
        
        imgui.Separator();
        imgui.Text('Notification Settings');
        imgui.Text(string.format('Cooldown: %d seconds', tellnotifier.settings.cooldown));
        
        imgui.Separator();
        imgui.Text('Chat Types to Monitor:');
        
        local tells_bool = { tellnotifier.settings.monitor_tells };
        if imgui.Checkbox('Tells', tells_bool) then
            tellnotifier.settings.monitor_tells = tells_bool[1];
            SaveSettings();
        end
        
        local party_bool = { tellnotifier.settings.monitor_party };
        if imgui.Checkbox('Party', party_bool) then
            tellnotifier.settings.monitor_party = party_bool[1];
            SaveSettings();
        end
        
        local ls1_bool = { tellnotifier.settings.monitor_linkshell1 };
        if imgui.Checkbox('Linkshell 1', ls1_bool) then
            tellnotifier.settings.monitor_linkshell1 = ls1_bool[1];
            SaveSettings();
        end
        
        local ls2_bool = { tellnotifier.settings.monitor_linkshell2 };
        if imgui.Checkbox('Linkshell 2', ls2_bool) then
            tellnotifier.settings.monitor_linkshell2 = ls2_bool[1];
            SaveSettings();
        end
        
        local say_bool = { tellnotifier.settings.monitor_say };
        if imgui.Checkbox('Say', say_bool) then
            tellnotifier.settings.monitor_say = say_bool[1];
            SaveSettings();
        end
        
        local shout_bool = { tellnotifier.settings.monitor_shout };
        if imgui.Checkbox('Shout', shout_bool) then
            tellnotifier.settings.monitor_shout = shout_bool[1];
            SaveSettings();
        end
        
        local yell_bool = { tellnotifier.settings.monitor_yell };
        if imgui.Checkbox('Yell', yell_bool) then
            tellnotifier.settings.monitor_yell = yell_bool[1];
            SaveSettings();
        end
        
        local unity_bool = { tellnotifier.settings.monitor_unity };
        if imgui.Checkbox('Unity', unity_bool) then
            tellnotifier.settings.monitor_unity = unity_bool[1];
            SaveSettings();
        end
        
        local emotes_bool = { tellnotifier.settings.monitor_emotes };
        if imgui.Checkbox('Emotes', emotes_bool) then
            tellnotifier.settings.monitor_emotes = emotes_bool[1];
            SaveSettings();
        end
        
        imgui.Separator();
        imgui.Text('Benefits of Discord:');
        imgui.Text('✓ Completely FREE forever');
        imgui.Text('✓ Works on all devices');
        imgui.Text('✓ No API limits');
        imgui.Text('✓ Easy to set up');
        imgui.Text('✓ Can share with friends');
    end
    imgui.End();
end);

--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command', 'command_cb', function (e)
    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/tellnotifier', '/tn')) then
        return;
    end

    -- Block all related commands..
    e.blocked = true;

    -- Handle: /tn (no args) - Shows status
    if (#args == 1) then
        print('TellNotifier: Status - ' .. (tellnotifier.settings.enabled and 'ENABLED' or 'DISABLED'));
        print('TellNotifier: Webhook - ' .. (tellnotifier.settings.webhook_url ~= '' and 'CONFIGURED' or 'NOT CONFIGURED'));
        print('TellNotifier: Use /tn help for commands');
        return;
    end

    -- Handle: /tn test
    if (#args == 2 and args[2]:any('test')) then
        SendDiscordNotification('TestUser', 'This is a test notification from TellNotifier addon.', 'Test');
        print('TellNotifier: Test notification sent to Discord.');
        return;
    end

    -- Handle: /tn toggle
    if (#args == 2 and args[2]:any('toggle')) then
        tellnotifier.settings.enabled = not tellnotifier.settings.enabled;
        SaveSettings();
        print(string.format('TellNotifier: Notifications %s', tellnotifier.settings.enabled and 'enabled' or 'disabled'));
        return;
    end

    -- Handle: /tn debug
    if (#args == 2 and args[2]:any('debug')) then
        tellnotifier.settings.debug_mode = not tellnotifier.settings.debug_mode;
        SaveSettings();
        print(string.format('TellNotifier: Debug mode %s', tellnotifier.settings.debug_mode and 'enabled' or 'disabled'));
        return;
    end

    -- Handle: /tn seturl <url>
    if (#args == 3 and args[2]:any('seturl')) then
        tellnotifier.settings.webhook_url = args[3];
        SaveSettings();
        print('TellNotifier: Webhook URL set successfully.');
        return;
    end

    -- Handle: /tn reload
    if (#args == 2 and args[2]:any('reload')) then
        tellnotifier.settings = settings.load(default_settings);
        print('TellNotifier: Settings reloaded.');
        return;
    end

    -- Handle: /tn ping
    if (#args == 2 and args[2]:any('ping')) then
        if tellnotifier.settings.webhook_url == '' then
            print('TellNotifier: No webhook URL configured.');
        else
            print('TellNotifier: Testing webhook connection...');
            
            -- Create JSON payload
            local payload = '{"content":"Ping test from TellNotifier addon"}';
            
            -- Try socket.http first if available
            if http_available then
                local response_body = {};
                local request_result, response_code, response_headers, status = http.request{
                    url = tellnotifier.settings.webhook_url,
                    method = "POST",
                    headers = {
                        ["Content-Type"] = "application/json",
                        ["Content-Length"] = tostring(#payload)
                    },
                    source = ltn12.source.string(payload),
                    sink = ltn12.sink.table(response_body)
                };
                
                if response_code == 204 then
                    print('TellNotifier: Ping test sent successfully. Check Discord for the message!');
                else
                    print(string.format('TellNotifier: Ping test failed. Response code: %s', tostring(response_code)));
                    if response_body and #response_body > 0 then
                        print(string.format('TellNotifier: Response: %s', table.concat(response_body)));
                    end
                end
            else
                -- Fallback to curl
                local command = string.format('curl -s -X POST -H "Content-Type: application/json" -d "{\\"content\\":\\"Ping test from TellNotifier addon\\"}" "%s"',
                    tellnotifier.settings.webhook_url
                );
                os.execute(command);
                print('TellNotifier: Ping test sent via curl. Check Discord for the message!');
            end
        end
        return;
    end

    -- Handle: /tn monitor <type> <on/off>
    if (#args == 4 and args[2]:any('monitor')) then
        local chat_type = args[3]:lower();
        local state = args[4]:lower();
        local setting_map = {
            tells = 'monitor_tells',
            tell = 'monitor_tells',
            party = 'monitor_party',
            linkshell1 = 'monitor_linkshell1',
            ls1 = 'monitor_linkshell1',
            ls = 'monitor_linkshell1',
            linkshell = 'monitor_linkshell1',
            linkshell2 = 'monitor_linkshell2',
            ls2 = 'monitor_linkshell2',
            say = 'monitor_say',
            shout = 'monitor_shout',
            yell = 'monitor_yell',
            unity = 'monitor_unity',
            emotes = 'monitor_emotes',
            emote = 'monitor_emotes',
        };
        
        local setting_name = setting_map[chat_type];
        if setting_name then
            if state == 'on' or state == 'true' or state == '1' then
                tellnotifier.settings[setting_name] = true;
                SaveSettings();
                print(string.format('TellNotifier: %s monitoring enabled', chat_type:upper()));
            elseif state == 'off' or state == 'false' or state == '0' then
                tellnotifier.settings[setting_name] = false;
                SaveSettings();
                print(string.format('TellNotifier: %s monitoring disabled', chat_type:upper()));
            else
                print('TellNotifier: Use on/off, true/false, or 1/0');
            end
        else
            print('TellNotifier: Valid types: tells, party, linkshell1/ls1, linkshell2/ls2, say, shout, yell, unity, emotes');
        end
        return;
    end

    -- Handle: /tn status
    if (#args == 2 and args[2]:any('status')) then
        print('TellNotifier Monitoring Status:');
        print('Tells: ' .. (tellnotifier.settings.monitor_tells and 'ON' or 'OFF'));
        print('Party: ' .. (tellnotifier.settings.monitor_party and 'ON' or 'OFF'));
        print('Linkshell1: ' .. (tellnotifier.settings.monitor_linkshell1 and 'ON' or 'OFF'));
        print('Linkshell2: ' .. (tellnotifier.settings.monitor_linkshell2 and 'ON' or 'OFF'));
        print('Say: ' .. (tellnotifier.settings.monitor_say and 'ON' or 'OFF'));
        print('Shout: ' .. (tellnotifier.settings.monitor_shout and 'ON' or 'OFF'));
        print('Yell: ' .. (tellnotifier.settings.monitor_yell and 'ON' or 'OFF'));
        print('Unity: ' .. (tellnotifier.settings.monitor_unity and 'ON' or 'OFF'));
        print('Emotes: ' .. (tellnotifier.settings.monitor_emotes and 'ON' or 'OFF'));
        return;
    end

    -- Handle: /tn help
    if (#args == 2 and args[2]:any('help')) then
        print('TellNotifier Commands:');
        print('/tn test - Send a test notification');
        print('/tn toggle - Toggle notifications on/off');
        print('/tn debug - Toggle debug mode (shows chat types)');
        print('/tn monitor <type> <on/off> - Enable/disable chat type');
        print('/tn status - Show monitoring status for all chat types');
        print('/tn seturl <url> - Set Discord webhook URL');
        print('/tn reload - Reload settings');
        print('/tn ping - Test webhook connection');
        print('/tn help - Show this help');
        return;
    end

    -- Unknown command
    print('TellNotifier: Unknown command. Use /tn help for available commands');
end); 