--[[
    Kotoba - Multi-language Chat Translator for Windower 4 (Wave 2)

    LLM-backed multi-language translation via file IPC (queue/results/heartbeat).
    On-screen panel (texts) with ruptchat-inspired click/drag maps.

    Ported from Ashita Kotoba by Zodiarchy @ Asura
]]

_addon.name = 'kotoba'
_addon.author = 'Zodiarchy @ Asura'
_addon.version = '2.0.0'
_addon.commands = {'kotoba', 'kb'}

require('chat')
local config = require('config')
local files = require('files')

local controls = require('ui/controls')
local panel_ok, panel = pcall(require, 'ui/panel')
if not panel_ok then
    panel = {
        show = function() end,
        hide = function() end,
        refresh = function() end,
        bind_actions = function() end,
        is_visible = function() return false end,
    }
end

local mouse_ok, mouse = pcall(require, 'ui/mouse')
if not mouse_ok then
    mouse = { register = function() end }
end

local defaults = {
    auto_translate = true,
    debug_mode = false,
    send_channel = 'say',
    language = 'ja',
    window_visible = true,
    pos_x = 80,
    pos_y = 120,
}

local settings = config.load(defaults)

local kotoba = {
    queue_file = nil,
    results_file = nil,
    heartbeat_file = nil,

    pending_translations = {},
    translation_cache = {},

    check_interval = 0.5,
    last_check = 0,
    heartbeat_interval = 5.0,
    last_heartbeat = 0,

    recent_messages = {},
    duplicate_timeout = 2,

    compose_buffer = '',
    clipboard_buffer = '',
    tell_target = '',
    status_message = '',
    player_name = nil,
}

local chat_modes = {
    [9]   = 'Say',
    [10]  = 'Shout',
    [11]  = 'Yell',
    [12]  = 'Tell',
    [13]  = 'Party',
    [14]  = 'Linkshell',
    [26]  = 'Party',
    [27]  = 'Alliance',
    [150] = 'NPC',
    [151] = 'NPC',
    [212] = 'Unity',
    [214] = 'Linkshell2',
}

local translate_channels = {
    Say = true,
    Shout = true,
    Yell = true,
    Tell = true,
    Party = true,
    Linkshell = true,
    Linkshell2 = true,
    Alliance = true,
}

local channel_aliases = {
    say = 'Say',
    s = 'Say',
    party = 'Party',
    p = 'Party',
    ls = 'Linkshell',
    l = 'Linkshell',
    linkshell = 'Linkshell',
    ls2 = 'Linkshell2',
    l2 = 'Linkshell2',
    linkshell2 = 'Linkshell2',
    shout = 'Shout',
    sh = 'Shout',
    yell = 'Yell',
    y = 'Yell',
    tell = 'Tell',
    t = 'Tell',
}

local function chat(msg, color)
    windower.add_to_chat(color or 207, '[Kotoba] ' .. msg)
end

local function debug(msg)
    if settings.debug_mode then
        chat(msg, 207)
    end
end

local function set_status(msg)
    kotoba.status_message = msg or ''
    panel.refresh(settings, kotoba)
end

local function table_count(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

local function init_paths()
    local addon_path = windower.addon_path
    kotoba.queue_file = addon_path .. 'translation_queue.txt'
    kotoba.results_file = addon_path .. 'translation_results.txt'
    kotoba.heartbeat_file = addon_path .. 'heartbeat.txt'

    local queue = files.new(kotoba.queue_file)
    if not queue:exists() then
        queue:create()
    end

    local results = files.new(kotoba.results_file)
    if not results:exists() then
        results:create()
    end
end

local function touch_heartbeat()
    local hb = io.open(kotoba.heartbeat_file, 'w')
    if hb then
        hb:write(tostring(os.time()))
        hb:close()
    end
end

local function spawn_translator()
    local translator_py = windower.addon_path .. 'translator.py'
    local cmd = 'start "Kotoba" /B pythonw "' .. translator_py .. '"'
    local success = os.execute(cmd .. ' >nul 2>&1')

    if not (success == 0 or success == true) then
        local fallback = 'start "Kotoba" /min cmd /c python "' .. translator_py .. '"'
        success = os.execute(fallback .. ' >nul 2>&1')
    end

    if success == 0 or success == true then
        chat('Translator running headlessly in background.')
    else
        chat('Could not auto-start translator. Run start_translator.bat manually if needed.', 167)
    end
end

--[[
    Detect Hiragana / Katakana / Kanji in UTF-8 text.
]]
local function has_japanese(text)
    if not text or text == '' then
        return false
    end

    local i = 1
    while i <= #text do
        local byte = text:byte(i)

        if byte >= 0xE0 and byte <= 0xEF and i + 2 <= #text then
            local byte2 = text:byte(i + 1)
            local byte3 = text:byte(i + 2)

            if byte2 >= 0x80 and byte2 <= 0xBF and byte3 >= 0x80 and byte3 <= 0xBF then
                local codepoint = ((byte - 0xE0) * 0x1000) + ((byte2 - 0x80) * 0x40) + (byte3 - 0x80)
                if (codepoint >= 0x3040 and codepoint <= 0x309F)
                    or (codepoint >= 0x30A0 and codepoint <= 0x30FF)
                    or (codepoint >= 0x4E00 and codepoint <= 0x9FFF) then
                    return true
                end
            end
            i = i + 3
        elseif byte >= 0xC0 and byte <= 0xDF then
            i = i + 2
        elseif byte >= 0xF0 and byte <= 0xF7 then
            i = i + 4
        else
            i = i + 1
        end
    end

    return false
end

local function parse_message(text)
    local sender = ''
    local message = text

    local matched_name, matched_text = text:match('^%[%d+%]%s*<([^>]+)>%s*(.+)$')
    if matched_name and matched_text then
        return matched_name:trim(), matched_text
    end

    matched_name, matched_text = text:match('^<([^>]+)>%s*(.+)$')
    if matched_name and matched_text then
        return matched_name:trim(), matched_text
    end

    matched_name, matched_text = text:match('^%(([^)]+)%)%s*(.+)$')
    if matched_name and matched_text then
        return matched_name:trim(), matched_text
    end

    matched_name, matched_text = text:match('^([^:]+):%s*(.+)$')
    if matched_name and matched_text and not matched_name:match('%s') then
        return matched_name:trim(), matched_text
    end

    matched_name, matched_text = text:match('^>>([^:]+)%s*:%s*(.+)$')
    if matched_name and matched_text then
        return matched_name:trim(), matched_text
    end

    return sender, message
end

local function build_send_command(channel, translation, target)
    if channel == 'Say' then
        return 'input /say ' .. translation
    elseif channel == 'Party' then
        return 'input /p ' .. translation
    elseif channel == 'Linkshell' then
        return 'input /l ' .. translation
    elseif channel == 'Linkshell2' then
        return 'input /l2 ' .. translation
    elseif channel == 'Shout' then
        return 'input /sh ' .. translation
    elseif channel == 'Yell' then
        return 'input /yell ' .. translation
    elseif channel == 'Tell' and target and target ~= '' then
        return 'input /tell ' .. target .. ' ' .. translation
    end
    return nil
end

local function send_translation(channel, translation, target)
    local cmd = build_send_command(channel, translation, target)
    if cmd then
        windower.send_command(cmd)
    elseif channel == 'Tell' then
        chat('Tell requires a target name.', 167)
    end
end

local function normalize_channel(name)
    if not name or name == '' then
        return nil
    end
    return channel_aliases[name:lower()]
end

--[[
    Queue a translation request: id|src|tgt|escaped_text
]]
local function QueueTranslation(text, target_lang, source_lang, context, options)
    if not text or text == '' then
        return
    end

    options = options or {}

    local cache_key = string.format('%s_%s_%s', source_lang, target_lang, text)
    if kotoba.translation_cache[cache_key] then
        local translation = kotoba.translation_cache[cache_key]
        chat(context .. ': ' .. translation)

        if options.auto_send and options.channel then
            send_translation(options.channel, translation, options.target)
        end
        return
    end

    local translation_id = os.time() .. '_' .. math.random(1000, 9999)

    kotoba.pending_translations[translation_id] = {
        text = text,
        context = context,
        cache_key = cache_key,
        timestamp = os.time(),
        auto_send = options.auto_send or false,
        send_channel = options.channel,
        send_target = options.target,
    }

    local escaped_text = text:gsub('|', '\\|'):gsub('\n', '\\n'):gsub('\r', '\\r')

    local file = io.open(kotoba.queue_file, 'ab')
    if file then
        local line = translation_id .. '|' .. source_lang .. '|' .. target_lang .. '|' .. escaped_text .. '\n'
        file:write(line)
        file:close()
        debug('Queued: ' .. text:sub(1, 50))
        set_status('Queued (' .. source_lang .. '→' .. target_lang .. ')')
    else
        chat('ERROR: Could not write to queue file!', 167)
        set_status('Queue write failed')
    end
end

local function CheckTranslationResults()
    local file = io.open(kotoba.results_file, 'rb')
    if not file then
        return
    end

    local content = file:read('*all')
    file:close()

    if not content or content == '' then
        return
    end

    local results = {}
    for line in content:gmatch('[^\r\n]+') do
        if line and line ~= '' then
            local id, translation = line:match('^([^|]+)|(.+)$')
            if id and translation and kotoba.pending_translations[id] then
                translation = translation:gsub('\\|', '|'):gsub('\\n', '\n'):gsub('\\r', '\r')
                table.insert(results, {
                    id = id,
                    translation = translation,
                })
            end
        end
    end

    for _, result in ipairs(results) do
        local pending = kotoba.pending_translations[result.id]
        if pending then
            kotoba.translation_cache[pending.cache_key] = result.translation
            chat(pending.context .. ': ' .. result.translation)

            if pending.auto_send and pending.send_channel then
                send_translation(pending.send_channel, result.translation, pending.send_target)
            end

            kotoba.pending_translations[result.id] = nil
            set_status('Translated')
        end
    end

    if #results > 0 then
        local clear_file = io.open(kotoba.results_file, 'wb')
        if clear_file then
            clear_file:close()
        end
        panel.refresh(settings, kotoba)
    end
end

local function is_duplicate(text, channel, sender)
    local hash = string.format('%s_%s_%s', channel, sender or '', text)
    local current_time = os.time()

    if kotoba.recent_messages[hash] then
        local time_diff = current_time - kotoba.recent_messages[hash]
        if time_diff < kotoba.duplicate_timeout then
            return true
        end
    end

    kotoba.recent_messages[hash] = current_time

    for h, timestamp in pairs(kotoba.recent_messages) do
        if current_time - timestamp > kotoba.duplicate_timeout then
            kotoba.recent_messages[h] = nil
        end
    end

    return false
end

local function clean_incoming_text(text)
    if not text or text == '' then
        return ''
    end

    local cleaned = text
    if windower.convert_auto_trans then
        cleaned = windower.convert_auto_trans(cleaned)
    end

    local ok, stripped = pcall(function()
        return cleaned:strip_format()
    end)
    if ok and stripped then
        cleaned = stripped
    end

    cleaned = cleaned:gsub('%[%d+:%d+:%d+%]%s*', '')
    cleaned = cleaned:gsub('%[%d+:%d+%]%s*', '')
    cleaned = cleaned:gsub('[\x00-\x1F]', '')
    cleaned = cleaned:gsub('^%s*(.-)%s*$', '%1')
    return cleaned
end

--------------------------------------------------------------------------
-- Panel actions
--------------------------------------------------------------------------

local function action_toggle_auto()
    settings.auto_translate = not settings.auto_translate
    config.save(settings)
    chat('Auto-translate: ' .. (settings.auto_translate and 'ON' or 'OFF'))
    set_status('Auto-translate ' .. (settings.auto_translate and 'ON' or 'OFF'))
end

local function action_cycle_lang()
    settings.language = controls.cycle_lang(settings.language)
    config.save(settings)
    chat('Language: ' .. controls.lang_name(settings.language) .. ' (' .. settings.language .. ')')
    set_status('Lang → ' .. settings.language)
end

local function action_cycle_channel()
    settings.send_channel = controls.cycle_channel(settings.send_channel)
    config.save(settings)
    chat('Send channel: ' .. settings.send_channel)
    set_status('Channel → ' .. settings.send_channel)
end

local function action_translate_send()
    local text = kotoba.compose_buffer or ''
    if text == '' then
        chat('Compose is empty. Use //kb compose <text> first.', 167)
        set_status('Compose empty')
        return
    end

    local target_lang = (settings.language or 'ja'):lower()
    local source_lang = controls.source_lang_for(target_lang)
    local channel = normalize_channel(settings.send_channel) or 'Say'
    local target = nil
    if channel == 'Tell' then
        target = kotoba.tell_target
        if not target or target == '' then
            chat('Tell requires a target. Use //kb tell <name>.', 167)
            set_status('Need tell target')
            return
        end
    end

    QueueTranslation(text, target_lang, source_lang, 'Translate & Send', {
        auto_send = true,
        channel = channel,
        target = target,
    })
end

local function action_copy()
    local text = kotoba.compose_buffer or ''
    if text == '' then
        chat('Nothing to copy.', 167)
        set_status('Copy empty')
        return
    end
    kotoba.clipboard_buffer = text
    -- Best-effort OS clipboard via PowerShell (Windower has no clipboard API)
    local escaped = text:gsub("'", "''")
    os.execute('powershell -NoProfile -Command "Set-Clipboard -Value \'' .. escaped .. '\'" >nul 2>&1')
    chat('Copied compose buffer (' .. #text .. ' chars)')
    set_status('Copied')
end

local function read_os_clipboard()
    -- Windower has no clipboard API; read via PowerShell into a temp file.
    local tmp = windower.addon_path .. 'clipboard_tmp.txt'
    os.execute('powershell -NoProfile -Command "Get-Clipboard -Raw | Set-Content -Encoding utf8 -Path \'' .. tmp .. '\'" >nul 2>&1')
    local f = io.open(tmp, 'r')
    if not f then
        return nil
    end
    local content = f:read('*a')
    f:close()
    pcall(os.remove, tmp)
    if not content then
        return nil
    end
    content = content:gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n+$', '')
    if content == '' then
        return nil
    end
    return content
end

local function action_paste()
    local os_clip = read_os_clipboard()
    if os_clip and os_clip ~= '' then
        kotoba.compose_buffer = os_clip
        kotoba.clipboard_buffer = os_clip
        chat('Pasted from OS clipboard (' .. #os_clip .. ' chars)')
        set_status('Pasted')
        panel.refresh(settings, kotoba)
        return
    end
    if kotoba.clipboard_buffer and kotoba.clipboard_buffer ~= '' then
        kotoba.compose_buffer = kotoba.clipboard_buffer
        chat('Pasted from Kotoba buffer')
        set_status('Pasted')
        panel.refresh(settings, kotoba)
        return
    end
    chat('Clipboard empty. Copy text elsewhere or use //kb compose <text>.', 167)
    set_status('Paste empty')
end

local function action_clear()
    kotoba.compose_buffer = ''
    chat('Compose cleared')
    set_status('Cleared')
end

local function save_panel_pos()
    config.save(settings)
end

local function bind_panel()
    panel.bind_actions({
        toggle_auto = action_toggle_auto,
        cycle_lang = action_cycle_lang,
        cycle_channel = action_cycle_channel,
        translate_send = action_translate_send,
        copy = action_copy,
        paste = action_paste,
        clear = action_clear,
    })
    mouse.register(panel, save_panel_pos)
end

local function set_window_visible(visible)
    settings.window_visible = visible and true or false
    config.save(settings)
    if settings.window_visible then
        panel.show(settings, kotoba)
        chat('Window: visible')
    else
        panel.hide()
        chat('Window: hidden')
    end
end

local function toggle_window_visible()
    set_window_visible(not settings.window_visible)
end

local function print_help()
    chat('Commands:')
    chat('  //kb — Toggle window visibility')
    chat('  //kb toggle — Toggle window visibility')
    chat('  //kb on|off — Enable/disable auto-translate')
    chat('  //kb auto — Toggle auto-translate')
    chat('  //kb status — Show status')
    chat('  //kb t <text> — Translate to settings.language')
    chat('  //kb te <text> — Translate JA→EN')
    chat('  //kb send <channel> <text> — Translate to settings.language and send')
    chat('    Channels: say, party, tell, ls, ls2, shout, yell')
    chat('  //kb compose <text> — Set compose buffer (shown on panel)')
    chat('  //kb channel <name> — Set default send channel')
    chat('  //kb cyclechannel — Cycle send channel')
    chat('  //kb lang <ja|en|es|fr|de|ko|zh> — Set target language')
    chat('  //kb cyclelang — Cycle target language')
    chat('  //kb tell <name> — Set tell target')
    chat('  //kb clear — Clear in-memory cache')
    chat('  //kb debug — Toggle debug mode')
    chat('  //kb help — Show this help')
    chat('Panel: click Auto / Language / buttons / Send to; drag title to move.')
end

local function print_status()
    chat('Status:')
    chat('  Auto-translate: ' .. (settings.auto_translate and 'ON' or 'OFF'))
    chat('  Window visible: ' .. (settings.window_visible and 'YES' or 'NO'))
    chat('  Send channel: ' .. tostring(settings.send_channel))
    chat('  Language: ' .. tostring(settings.language) .. ' (' .. controls.lang_name(settings.language) .. ')')
    chat('  Tell target: ' .. (kotoba.tell_target ~= '' and kotoba.tell_target or '(none)'))
    chat('  Debug mode: ' .. (settings.debug_mode and 'ON' or 'OFF'))
    chat('  Cached: ' .. tostring(table_count(kotoba.translation_cache)))
    chat('  Pending: ' .. tostring(table_count(kotoba.pending_translations)))
    if kotoba.compose_buffer ~= '' then
        chat('  Compose: ' .. kotoba.compose_buffer:sub(1, 80))
    end
end

--------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------

windower.register_event('incoming text', function(original, modified, mode, gm)
    if not settings.auto_translate then
        return
    end

    local text = modified or original
    if not text or text == '' then
        return
    end

    local channel = chat_modes[mode]
    if not channel or not translate_channels[channel] then
        return
    end

    if text:match('%[Kotoba%]') then
        return
    end

    local clean_text = clean_incoming_text(text)
    if clean_text == '' then
        return
    end

    local sender, message = parse_message(clean_text)
    if is_duplicate(message, channel, sender) then
        return
    end

    if has_japanese(message) then
        local context = sender ~= '' and sender or channel
        QueueTranslation(message, 'en', 'ja', context)
    end
end)

windower.register_event('prerender', function()
    local now = os.clock()

    if now - kotoba.last_check >= kotoba.check_interval then
        kotoba.last_check = now
        CheckTranslationResults()
    end

    if now - kotoba.last_heartbeat >= kotoba.heartbeat_interval then
        kotoba.last_heartbeat = now
        touch_heartbeat()
    end
end)

windower.register_event('load', function()
    init_paths()
    bind_panel()

    local player = windower.ffxi.get_player()
    if player then
        kotoba.player_name = player.name
    end

    spawn_translator()
    touch_heartbeat()

    if settings.window_visible then
        panel.show(settings, kotoba)
    else
        panel.hide()
    end

    chat('v' .. _addon.version .. ' loaded. Multi-language translation ready.')
    chat('Use //kotoba or //kb for commands. Auto-translate: ' .. (settings.auto_translate and 'ON' or 'OFF'))
end)

windower.register_event('login', function(name)
    kotoba.player_name = name
    chat('Welcome, ' .. name .. '! Auto-translate is ' .. (settings.auto_translate and 'ON' or 'OFF'))
end)

windower.register_event('addon command', function(command, ...)
    local args = {...}
    command = command and command:lower() or nil

    if command == nil or command == '' then
        toggle_window_visible()
        return
    end

    if command == 'help' or command == 'h' or command == '?' then
        print_help()
        return
    end

    if command == 'clear' then
        if args[1] and args[1]:lower() == 'compose' then
            action_clear()
            return
        end
        kotoba.translation_cache = {}
        chat('Translation cache cleared')
        return
    end

    if command == 'debug' then
        settings.debug_mode = not settings.debug_mode
        config.save(settings)
        chat('Debug mode: ' .. (settings.debug_mode and 'ON' or 'OFF'))
        return
    end

    if command == 'on' then
        settings.auto_translate = true
        config.save(settings)
        chat('Auto-translate ENABLED')
        panel.refresh(settings, kotoba)
        return
    end

    if command == 'off' then
        settings.auto_translate = false
        config.save(settings)
        chat('Auto-translate DISABLED')
        panel.refresh(settings, kotoba)
        return
    end

    if command == 'toggle' then
        toggle_window_visible()
        return
    end

    if command == 'auto' then
        action_toggle_auto()
        return
    end

    if command == 'status' then
        print_status()
        return
    end

    if command == 't' or command == 'translate' then
        local text = table.concat(args, ' ')
        if text ~= '' then
            local target_lang = (settings.language or 'ja'):lower()
            local source_lang = controls.source_lang_for(target_lang)
            QueueTranslation(text, target_lang, source_lang, 'You')
        else
            chat('Usage: //kb t <text>  (translates to ' .. tostring(settings.language) .. ')', 167)
        end
        return
    end

    if command == 'te' then
        local text = table.concat(args, ' ')
        if text ~= '' then
            QueueTranslation(text, 'en', 'ja', 'Manual')
        else
            chat('Usage: //kb te <japanese text>', 167)
        end
        return
    end

    if command == 'send' then
        if #args < 2 then
            chat('Usage: //kb send <channel> <text>', 167)
            chat('  Channels: say, party, ls, ls2, shout, yell, tell <name>', 167)
            return
        end

        local channel = normalize_channel(args[1])
        if not channel then
            chat('Unknown channel: ' .. tostring(args[1]), 167)
            return
        end

        local text_start = 2
        local target = nil
        if channel == 'Tell' then
            if #args < 3 then
                chat('Usage: //kb send tell <name> <text>', 167)
                return
            end
            target = args[2]
            text_start = 3
        end

        local text_parts = {}
        for i = text_start, #args do
            table.insert(text_parts, args[i])
        end
        local text = table.concat(text_parts, ' ')

        if text ~= '' then
            local target_lang = (settings.language or 'ja'):lower()
            local source_lang = controls.source_lang_for(target_lang)
            QueueTranslation(text, target_lang, source_lang, 'Send', {
                auto_send = true,
                channel = channel,
                target = target,
            })
        else
            chat('No text to translate', 167)
        end
        return
    end

    if command == 'compose' then
        local text = table.concat(args, ' ')
        kotoba.compose_buffer = text or ''
        if kotoba.compose_buffer ~= '' then
            chat('Compose buffer set (' .. #kotoba.compose_buffer .. ' chars)')
            set_status('Compose set')
        else
            chat('Compose buffer cleared')
            set_status('Compose cleared')
        end
        return
    end

    if command == 'channel' then
        if #args < 1 then
            chat('Current send channel: ' .. tostring(settings.send_channel))
            chat('Usage: //kb channel <say|party|tell|ls|ls2|shout|yell>', 167)
            return
        end
        local channel = normalize_channel(args[1])
        if not channel then
            chat('Unknown channel: ' .. tostring(args[1]), 167)
            return
        end
        settings.send_channel = args[1]:lower()
        -- Normalize aliases to canonical keys
        for _, key in ipairs(controls.CHANNELS) do
            if normalize_channel(key) == channel then
                settings.send_channel = key
                break
            end
        end
        config.save(settings)
        chat('Send channel set to: ' .. settings.send_channel)
        panel.refresh(settings, kotoba)
        return
    end

    if command == 'cyclechannel' then
        action_cycle_channel()
        return
    end

    if command == 'lang' or command == 'language' then
        if #args < 1 then
            chat('Current language: ' .. tostring(settings.language) .. ' (' .. controls.lang_name(settings.language) .. ')')
            chat('Usage: //kb lang <ja|en|es|fr|de|ko|zh>', 167)
            return
        end
        local lang = args[1]:lower()
        if not controls.is_valid_lang(lang) then
            chat('Invalid language. Use: ja, en, es, fr, de, ko, zh', 167)
            return
        end
        settings.language = lang
        config.save(settings)
        chat('Language set to: ' .. settings.language .. ' (' .. controls.lang_name(lang) .. ')')
        panel.refresh(settings, kotoba)
        return
    end

    if command == 'cyclelang' then
        action_cycle_lang()
        return
    end

    if command == 'tell' then
        if #args < 1 then
            chat('Tell target: ' .. (kotoba.tell_target ~= '' and kotoba.tell_target or '(none)'))
            chat('Usage: //kb tell <name>', 167)
            return
        end
        kotoba.tell_target = args[1]
        chat('Tell target set to: ' .. kotoba.tell_target)
        panel.refresh(settings, kotoba)
        return
    end

    if command == 'window' or command == 'show' or command == 'hide' then
        if command == 'show' then
            set_window_visible(true)
        elseif command == 'hide' then
            set_window_visible(false)
        else
            toggle_window_visible()
        end
        return
    end

    chat('Unknown command: ' .. command, 167)
    chat('Use //kb help for available commands')
end)
