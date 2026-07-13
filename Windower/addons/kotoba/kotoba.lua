--[[
    Kotoba - Multi-language Chat Translator for Windower 4 (Wave 2)

    LLM-backed multi-language translation via file IPC (queue/results/heartbeat).
    On-screen panel (texts) with ruptchat-inspired click/drag maps.

    Ported from Ashita Kotoba by Zodiarchy @ Asura
]]

_addon.name = 'kotoba'
_addon.author = 'Zodiarchy @ Asura'
_addon.version = '2.0.7'
_addon.commands = {'kotoba', 'kb'}

require('chat')
local config = require('config')

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

-- In-panel typing: DIK → string buffer (Windower 4 has no ui.edit)
local input_ok, kb_input = pcall(require, 'ui/input')
if not input_ok then
    kb_input = {
        is_active = function() return false end,
        start = function() end,
        stop = function() end,
        confirm = function() end,
        handle_key = function() return false end,
        ingest_token = function() end,
        force_unblock = function() end,
        get_buffer = function() return '' end,
        set_buffer = function() end,
        tick = function() end,
    }
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
    fast_poll_until = 0,
    heartbeat_interval = 5.0,
    last_heartbeat = 0,

    recent_messages = {},
    duplicate_timeout = 2,

    compose_buffer = '',
    clipboard_buffer = '',
    tell_target = '',
    status_message = '',
    input_mode = nil, -- nil | 'compose' | 'tell'
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

local function ensure_file(absolute_path)
    local f = io.open(absolute_path, 'a+')
    if f then
        f:close()
        return true
    end
    return false
end

local function init_paths()
    local addon_path = windower.addon_path
    kotoba.queue_file = addon_path .. 'translation_queue.txt'
    kotoba.results_file = addon_path .. 'translation_results.txt'
    kotoba.heartbeat_file = addon_path .. 'heartbeat.txt'

    -- Do NOT use files.new() with absolute paths: Windower's files lib always
    -- prefixes windower.addon_path again (libs/files.lua:24), which doubles the
    -- path and makes io.open return nil → "attempt to index local 'fh'".
    if not ensure_file(kotoba.queue_file) then
        chat('ERROR: Could not create translation_queue.txt', 167)
    end
    if not ensure_file(kotoba.results_file) then
        chat('ERROR: Could not create translation_results.txt', 167)
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
    -- Kill zombie kotoba pythonw processes (they steal queue jobs and never reply)
    os.execute(
        'powershell -NoLogo -NoProfile -WindowStyle Hidden -Command '
        .. '"Get-CimInstance Win32_Process | Where-Object { '
        .. '($_.Name -match \'pythonw?\.exe\') -and ($_.CommandLine -match \'kotoba.+translator\.py\') } '
        .. '| ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"'
    )
    -- /B = no new window; pythonw = no console
    local cmd = 'start "KotobaTranslator" /B pythonw "' .. translator_py .. '"'
    local success = os.execute(cmd)

    if not (success == 0 or success == true) then
        local fallback =
            'start "KotobaTranslator" /MIN powershell -NoLogo -NoProfile -WindowStyle Hidden '
            .. '-Command "python \'' .. translator_py .. '\'"'
        success = os.execute(fallback)
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

-- FFXI chat expects Shift-JIS. LLM results are UTF-8 — without this, Japanese shows as mojibake.
local function to_game_text(utf8)
    if not utf8 or utf8 == '' then
        return utf8
    end
    if windower.to_shift_jis then
        local ok, sjis = pcall(windower.to_shift_jis, utf8)
        if ok and sjis and sjis ~= '' then
            return sjis
        end
    end
    return utf8
end

local function send_translation(channel, translation, target)
    local game_text = to_game_text(translation)
    local cmd = build_send_command(channel, game_text, target)
    if cmd then
        -- send_command('input …') is more reliable than chat.input after we close chat
        windower.send_command(cmd)
        debug('Sent: ' .. cmd:sub(1, 80))
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
    Returns: 'sent' | 'queued' | 'error'
]]
local function QueueTranslation(text, target_lang, source_lang, context, options)
    if not text or text == '' then
        return 'error'
    end

    options = options or {}

    local cache_key = string.format('%s_%s_%s', source_lang, target_lang, text)
    if kotoba.translation_cache[cache_key] then
        local translation = kotoba.translation_cache[cache_key]
        chat(context .. ': ' .. translation)

        if options.auto_send and options.channel then
            send_translation(options.channel, translation, options.target)
            set_status('Sent → ' .. tostring(options.channel))
            return 'sent'
        end
        set_status('Translated')
        return 'sent'
    end

    -- Already waiting on the same outbound text — don't stack duplicate queues
    if options.auto_send then
        for id, pending in pairs(kotoba.pending_translations) do
            if pending.cache_key == cache_key and pending.auto_send then
                local age = os.time() - (pending.timestamp or os.time())
                if age < 20 then
                    set_status('Still translating… (' .. age .. 's)')
                    return 'queued'
                end
                -- Stale pending — drop and re-queue
                kotoba.pending_translations[id] = nil
                chat('Previous translate timed out — retrying.', 167)
            end
        end
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
        if options.auto_send then
            set_status('Translating… (sending when ready)')
            -- Poll results hard for a few seconds so we don't sit on "queued"
            kotoba.fast_poll_until = os.clock() + 8
        else
            set_status('Queued (' .. source_lang .. '→' .. target_lang .. ')')
        end
        return 'queued'
    end

    chat('ERROR: Could not write to queue file!', 167)
    set_status('Queue write failed')
    return 'error'
end

local function CheckTranslationResults()
    -- Drop zombie pendings so UI cannot stick on "Still translating…"
    local now_t = os.time()
    for id, pending in pairs(kotoba.pending_translations) do
        if pending.timestamp and (now_t - pending.timestamp) > 25 then
            kotoba.pending_translations[id] = nil
            set_status('Translate timed out')
            chat('Translation timed out. Click Translate & Send again.', 167)
        end
    end

    local file = io.open(kotoba.results_file, 'rb')
    if not file then
        return
    end

    local content = file:read('*all')
    file:close()

    if not content or content == '' then
        return
    end

    -- Strip UTF-8 BOM if present
    if content:sub(1, 3) == '\239\187\191' then
        content = content:sub(4)
    end

    local results = {}
    local matched_ids = {}
    for line in content:gmatch('[^\r\n]+') do
        if line and line ~= '' then
            local id, translation = line:match('^([^|]+)|(.+)$')
            if id and translation and kotoba.pending_translations[id] then
                translation = translation:gsub('\\|', '|'):gsub('\\n', '\n'):gsub('\\r', '\r')
                table.insert(results, {
                    id = id,
                    translation = translation,
                })
                matched_ids[id] = true
            end
        end
    end

    for _, result in ipairs(results) do
        local pending = kotoba.pending_translations[result.id]
        if pending then
            local translation = result.translation
            if translation:match('^__ERROR__') then
                chat('Translation failed — try again (or //kb status).', 167)
                set_status('Translate failed')
                kotoba.pending_translations[result.id] = nil
            else
                kotoba.translation_cache[pending.cache_key] = translation
                chat(pending.context .. ': ' .. translation)

                if pending.auto_send and pending.send_channel then
                    send_translation(pending.send_channel, translation, pending.send_target)
                    set_status('Sent → ' .. tostring(pending.send_channel))
                else
                    set_status('Translated')
                end

                kotoba.pending_translations[result.id] = nil
            end
        end
    end

    if #results > 0 then
        -- Rewrite results file keeping only unmatched leftover lines (if any)
        local keep = {}
        for line in content:gmatch('[^\r\n]+') do
            local id = line:match('^([^|]+)|')
            if id and not matched_ids[id] and line ~= '' then
                table.insert(keep, line)
            end
        end
        local clear_file = io.open(kotoba.results_file, 'wb')
        if clear_file then
            if #keep > 0 then
                clear_file:write(table.concat(keep, '\n') .. '\n')
            end
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
-- In-panel typing (Windower 4)
-- texts cannot take focus; ui.edit is Windower 5 only.
-- Pattern (xivcrossbar env_chooser, Issues#788): open chat so return-true
-- blocks keys, capture DIK into our own buffer, draw it on the panel.
-- Do NOT mirror get_input() — that path only kept the last letter for tell.
--------------------------------------------------------------------------

local function end_input_mode(keep_chat)
    kotoba.input_mode = nil
    if kb_input.is_active and kb_input.is_active() then
        kb_input.stop(not keep_chat)
    elseif not keep_chat and windower.chat and windower.chat.is_open and windower.chat.is_open() then
        windower.send_command('setkey escape down; wait 0.05; setkey escape up')
    end
    panel.refresh(settings, kotoba)
end

local function on_kb_change(mode, buffer)
    if mode == 'compose' then
        kotoba.compose_buffer = buffer or ''
    elseif mode == 'tell' then
        local name = (buffer or ''):gsub('^/', ''):match('^(%S+)') or (buffer or '')
        kotoba.tell_target = name
    end
    panel.refresh(settings, kotoba)
end

local function on_kb_confirm(mode, buffer)
    kotoba.input_mode = nil
    if mode == 'compose' then
        kotoba.compose_buffer = buffer or ''
        set_status('Compose ready')
        chat('Compose set (' .. #(kotoba.compose_buffer or '') .. ' chars). Click Translate & Send.')
    elseif mode == 'tell' then
        local name = (buffer or ''):gsub('^/', ''):match('^(%S+)') or (buffer or '')
        kotoba.tell_target = name
        set_status('Tell → ' .. (name ~= '' and name or '?'))
        chat('Tell target: ' .. (name ~= '' and name or '(empty)'))
    end
    panel.refresh(settings, kotoba)
end

local function on_kb_cancel()
    kotoba.input_mode = nil
    set_status('Edit cancelled')
    panel.refresh(settings, kotoba)
end

local function begin_compose_input()
    if kotoba.input_mode == 'compose' and kb_input.is_active() then
        kb_input.confirm()
        return
    end
    kotoba.input_mode = 'compose'
    kb_input.start('compose', kotoba.compose_buffer or '', {
        on_change = on_kb_change,
        on_confirm = on_kb_confirm,
        on_cancel = on_kb_cancel,
    })
    set_status('Type here — Enter locks, Esc cancels')
    chat('Compose: type into Kotoba (keys go to the panel). Enter = lock, Esc = cancel.')
    panel.refresh(settings, kotoba)
end

local function begin_tell_input()
    if (settings.send_channel or ''):lower() ~= 'tell' then
        settings.send_channel = 'tell'
        config.save(settings)
    end
    if kotoba.input_mode == 'tell' and kb_input.is_active() then
        kb_input.confirm()
        return
    end
    kotoba.input_mode = 'tell'
    kb_input.start('tell', kotoba.tell_target or '', {
        on_change = on_kb_change,
        on_confirm = on_kb_confirm,
        on_cancel = on_kb_cancel,
    })
    set_status('Type name — Enter locks, Esc cancels')
    chat('Tell: type the player name into Kotoba. Enter = lock, Esc = cancel.')
    panel.refresh(settings, kotoba)
end

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
    if (settings.send_channel or ''):lower() == 'tell' and (not kotoba.tell_target or kotoba.tell_target == '') then
        begin_tell_input()
    else
        panel.refresh(settings, kotoba)
    end
end

local function action_translate_send()
    -- Flush live keyboard buffer into compose if still editing
    if kotoba.input_mode == 'compose' and kb_input.is_active() then
        kotoba.compose_buffer = kb_input.get_buffer() or kotoba.compose_buffer
    end
    local text = kotoba.compose_buffer or ''
    if text == '' then
        chat('Compose is empty. Click Compose, type into the panel, then Translate & Send.', 167)
        set_status('Compose empty')
        begin_compose_input()
        return
    end

    local target_lang = (settings.language or 'ja'):lower()
    local source_lang = controls.source_lang_for(target_lang)
    local channel = normalize_channel(settings.send_channel) or 'Say'
    local target = nil
    if channel == 'Tell' then
        if kotoba.input_mode == 'tell' and kb_input.is_active() then
            local name = (kb_input.get_buffer() or ''):gsub('^/', ''):match('^(%S+)') or ''
            if name ~= '' then
                kotoba.tell_target = name
            end
        end
        target = kotoba.tell_target
        if not target or target == '' then
            chat('Tell requires a name. Click Tell target and type it into the panel.', 167)
            set_status('Need tell target')
            begin_tell_input()
            return
        end
    end

    end_input_mode(false)

    local result = QueueTranslation(text, target_lang, source_lang, 'Translate & Send', {
        auto_send = true,
        channel = channel,
        target = target,
    })
    -- Status is set inside QueueTranslation (Sent / Translating… / error).
    -- Do NOT overwrite with "Queued" — that made every send look unfinished.
    if result == 'sent' then
        chat('Sent to ' .. channel)
    elseif result == 'queued' then
        chat('Translating for ' .. channel .. ' — will send automatically (one click is enough).')
    end
end

local function action_copy()
    local text = kotoba.compose_buffer or ''
    if text == '' then
        chat('Nothing to copy.', 167)
        set_status('Copy empty')
        return
    end
    kotoba.clipboard_buffer = text
    -- Hidden window — plain os.execute(powershell) flashes a blank cmd on Windows
    local escaped = text:gsub("'", "''")
    os.execute(
        'powershell -NoLogo -NoProfile -WindowStyle Hidden -Command '
        .. '"Set-Clipboard -Value \'' .. escaped .. '\'"'
    )
    chat('Copied compose buffer (' .. #text .. ' chars)')
    set_status('Copied')
end

local function read_os_clipboard()
    local tmp = windower.addon_path .. 'clipboard_tmp.txt'
    os.execute(
        'powershell -NoLogo -NoProfile -WindowStyle Hidden -Command '
        .. '"Get-Clipboard -Raw | Set-Content -Encoding utf8 -Path \'' .. tmp .. '\'"'
    )
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
    end_input_mode(false)
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
        focus_compose = begin_compose_input,
        focus_tell = begin_tell_input,
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
    chat('  //kb compose <text> — Set compose buffer (optional; prefer click Compose)')
    chat('  //kb channel <name> — Set default send channel')
    chat('  //kb cyclechannel — Cycle send channel')
    chat('  //kb lang <ja|en|es|fr|de|ko|zh> — Set target language')
    chat('  //kb cyclelang — Cycle target language')
    chat('  //kb tell <name> — Set tell target (or click Tell target on panel)')
    chat('  //kb clear — Clear in-memory cache')
    chat('  //kb debug — Toggle debug mode')
    chat('  //kb help — Show this help')
    chat('Panel typing: click Compose → type into Kotoba → Enter to lock → Translate & Send.')
    chat('Tell: cycle Send to Tell → click Tell target → type name → Enter to lock.')
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

    local interval = kotoba.check_interval
    if kotoba.fast_poll_until and now < kotoba.fast_poll_until then
        interval = 0.1
    end

    if now - kotoba.last_check >= interval then
        kotoba.last_check = now
        CheckTranslationResults()
    end

    if now - kotoba.last_heartbeat >= kotoba.heartbeat_interval then
        kotoba.last_heartbeat = now
        touch_heartbeat()
    end

    -- Soft chat maintain while editing (never force-reopen — that fights door menus)
    if kb_input.tick then
        kb_input.tick()
    end
end)

-- Capture keys into Kotoba while compose/tell edit is active
windower.register_event('keyboard', function(dik, down, flags, blocked)
    if blocked then
        return
    end
    if not kotoba.input_mode or not kb_input.is_active() then
        return
    end
    if kb_input.handle_key(dik, down) then
        return true
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

windower.register_event('unload', function()
    if kb_input.force_unblock then
        kb_input.force_unblock()
    end
    windower.send_command('keyboard_blockinput 0')
end)

windower.register_event('addon command', function(command, ...)
    local args = {...}
    command = command and command:lower() or nil

    -- Internal: % binds route here while editing (lua c kotoba _k <token>)
    if command == '_k' then
        if kb_input.ingest_token then
            kb_input.ingest_token(args[1])
        end
        return
    end

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
