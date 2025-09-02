--[[
* Sendoria - Bidirectional Discord Chat Relay for Windower
* Author: Palmer (Zodiarchy @ Asura)
* Version: 2.0 - Bidirectional Relay
--]]

_addon.name     = 'Sendoria'
_addon.author   = 'Palmer (Zodiarchy @ Asura)'
_addon.version  = '2.0'
_addon.desc     = 'Bidirectional Discord chat relay for FFXI.'
_addon.commands = { 'sendoria', 'sn' }

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
        end
    end

    -- Debug output removed for cleaner operation
end

--[[
* Chat message event handler
--]]
windower.register_event('chat message', function(message, sender, mode, is_gm)
    -- Skip our own messages if outgoing monitoring is enabled (handled by outgoing chunk event)
    local player = windower.ffxi.get_player()
    if player and sender == player.name and settings.monitor_outgoing then
        return
    end

    local chat_info = Config.chat_modes[mode]
    if not chat_info or not settings[chat_info.setting] then
        return
    end

    -- Check cooldown
    if not Chat.check_cooldown(chat_info.name, settings) then
        return
    end

    -- Convert auto-translate and send notification
    local clean_message = windower.convert_auto_trans(message) or message
    -- Send notification asynchronously to prevent any potential freezing
    coroutine.schedule(function()
        send_notification(sender, clean_message, chat_info.name)
    end, 0.1)
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



    local player_name = windower.ffxi.get_player().name or 'Unknown'

    if id == 0x0B5 then
        -- Speech packet
        local mode, message, chat_type = Chat.parse_outgoing_speech_packet(data)

        if not mode then
            return
        end

        -- Check for duplicates
        local is_duplicate, time_diff = Chat.is_duplicate_outgoing(mode, message)
        if is_duplicate then
            return
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
            -- Add a small delay between messages to prevent flooding
            coroutine.schedule(function()
                local success, error_msg = Chat.inject_message_to_game(response.chat_type, response.message,
                    response.target)
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
    if command == 'toggle' then
        settings.enabled = not settings.enabled
        Config.save(settings)
        windower.add_to_chat(123,
            string.format('Sendoria: Notifications %s', settings.enabled and 'enabled' or 'disabled'))
    elseif command == 'reload' then
        Config.reload(settings)
        windower.add_to_chat(123, 'Sendoria: Settings reloaded.')
    elseif command == 'status' then
        Commands.show_monitoring_status(settings)
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
    elseif command == 'autostart' then
        if #args >= 1 then
            Commands.toggle_autostart(settings, args[1]:lower(), function() Config.save(settings) end)
        else
            windower.add_to_chat(123, 'Sendoria: Auto-start is ' .. (settings.auto_start_bot and 'ENABLED' or 'DISABLED'))
            windower.add_to_chat(123, 'Usage: //sn autostart <on/off>')
        end
    elseif command == 'clean' then
        Commands.clean_relay_files(settings)
    elseif command == 'stop' then
        -- Create shutdown signal file for Discord bot
        local shutdown_file = windower.addon_path .. 'bot_shutdown.txt'
        local file = io.open(shutdown_file, 'w')
        if file then
            file:write('SHUTDOWN')
            file:close()
            windower.add_to_chat(123, 'Sendoria: Shutdown signal sent to Discord bot.')
        else
            windower.add_to_chat(123, 'Sendoria: Failed to create shutdown signal file.')
        end
    else
        windower.add_to_chat(123, 'Sendoria: Unknown command. Use //sn help for available commands')
    end
end)

--[[
* Auto-start Discord bot when addon loads
--]]
local function auto_start_discord_bot()
    if settings.auto_start_bot then
        local addon_path = windower.addon_path or ''

        -- Try multiple approaches to start the bot
        local bot_paths = {
            addon_path .. 'SendoriaBot_Silent.exe', -- Silent version (no console window)
            addon_path .. 'SendoriaBot.exe'         -- Console version as fallback
        }

        windower.add_to_chat(123, 'Sendoria: Auto-starting Discord bot...')

        local bot_started = false
        for i, bot_path in ipairs(bot_paths) do
            local file = io.open(bot_path, "r")
            if file then
                file:close()

                -- Start the bot using the working method
                os.execute('cd /d "' .. addon_path .. '" && start "" "' .. bot_path .. '"')
                bot_started = true
                windower.add_to_chat(123, 'Sendoria: Discord bot started')
                break
            end
        end

        if not bot_started then
            windower.add_to_chat(123, 'Sendoria: Auto-start enabled but no bot executable found.')
            windower.add_to_chat(123,
                'Sendoria: Please ensure SendoriaBot.exe or SendoriaBot_Silent.exe is in the addon folder.')
        end
    end
end

--[[
* Auto-stop Discord bot when addon unloads
--]]
local function auto_stop_discord_bot()
    if settings.auto_start_bot then
        windower.add_to_chat(123, 'Sendoria: Auto-stopping Discord bot...')

        -- Stop both versions of the bot
        os.execute('taskkill /F /IM "SendoriaBot_Silent.exe" >nul 2>&1')
        os.execute('taskkill /F /IM "SendoriaBot.exe" >nul 2>&1')

        windower.add_to_chat(123, 'Sendoria: Discord bot stopped')
    end
end

--[[
* Addon unload event handler
--]]
windower.register_event('unload', function()
    auto_stop_discord_bot()
end)

-- Auto-start the Discord bot on addon load
coroutine.schedule(auto_start_discord_bot, 2.0) -- Delay 2 seconds to let addon fully initialize

-- Print startup message
windower.add_to_chat(123, 'Sendoria: Loaded successfully. Use //sn help for commands.')
