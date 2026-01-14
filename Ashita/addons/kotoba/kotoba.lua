
--[[
* Addons - Copyright (c) 2024 Ashita Development Team
* Contact: https://www.ashitaxi.com/
* Contact: https://discord.gg/Ashita
*
* This file is part of Ashita.
*
* Kotoba - Multi-language chat assistant for FFXI
* Displays chat in a separate ImGui window with translation helpers
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

addon.name      = 'kotoba';
addon.author    = 'Zodiarchy @ Asura';
addon.version   = '1.1';
addon.desc      = 'Multi-language chat assistant with translation helpers';

require('common');
local ffi = require('ffi');
local imgui = require('imgui');

-- Define Windows clipboard and conversion API functions
ffi.cdef[[
    typedef void* HANDLE;
    typedef HANDLE HWND;
    typedef unsigned int UINT;
    typedef int BOOL;
    
    bool OpenClipboard(HWND hWndNewOwner);
    bool CloseClipboard(void);
    HANDLE GetClipboardData(UINT uFormat);
    void* GlobalLock(HANDLE hMem);
    bool GlobalUnlock(HANDLE hMem);
    size_t GlobalSize(HANDLE hMem);
    HANDLE SetClipboardData(UINT uFormat, HANDLE hMem);
    bool EmptyClipboard(void);
    HANDLE GlobalAlloc(UINT uFlags, size_t dwBytes);
    void* GlobalFree(HANDLE hMem);
    
    // For UTF-16 to Shift-JIS conversion
    int WideCharToMultiByte(
        UINT CodePage,
        unsigned long dwFlags,
        const wchar_t* lpWideCharStr,
        int cchWideChar,
        char* lpMultiByteStr,
        int cbMultiByte,
        const char* lpDefaultChar,
        BOOL* lpUsedDefaultChar
    );
    
    // For Shift-JIS to UTF-16 conversion
    int MultiByteToWideChar(
        UINT CodePage,
        unsigned long dwFlags,
        const char* lpMultiByteStr,
        int cbMultiByte,
        wchar_t* lpWideCharStr,
        int cchWideChar
    );
]];

-- Windows clipboard format constants
local CF_TEXT = 1;          -- ANSI text
local CF_UNICODETEXT = 13;  -- Unicode text

-- Windows code page constants
local CP_SHIFTJIS = 932;    -- Shift-JIS (Japanese) - used for game commands
local CP_UTF8 = 65001;      -- UTF-8 - used for internal storage

-- Windows memory allocation flags
local GMEM_MOVEABLE = 0x0002;
local GMEM_ZEROINIT = 0x0040;

-- Settings
local kotoba = {
    -- Window settings
    is_open = { true },
    
    -- Chat storage
    messages = {},
    max_messages = 500,
    
    -- Duplicate detection (prevent same message from showing multiple times)
    recent_messages = {},
    duplicate_timeout = 2, -- seconds
    
    -- Translation settings
    translate_to = 'ja', -- Default target language (ja = Japanese)
    translate_from = 'auto', -- Auto-detect source language
    translating = false,
    translation_cache = {}, -- Cache translations to avoid repeated API calls
    auto_translate_incoming = { true }, -- Auto-translate incoming messages (ImGui needs table) - default ON
    
    -- File-based translation (Sendoria-style)
    translation_queue_file = AshitaCore:GetInstallPath() .. '\\addons\\kotoba\\translation_queue.txt',
    translation_results_file = AshitaCore:GetInstallPath() .. '\\addons\\kotoba\\translation_results.txt',
    translation_pending = {}, -- Track pending translations
    translation_check_timer = 0,
    translation_check_interval = 30, -- Check every 30 frames (0.5 seconds at 60 FPS)
    
    -- Input (ImGui needs Lua tables, not FFI buffers for InputTextMultiline)
    input_text = { '' },
    
    -- Channel filter
    filter_channel = 'All',
    channels = { 'All', 'Say', 'Party', 'Tell', 'Linkshell', 'Shout', 'Yell' },
    
    -- Send channel
    send_channel = 'Say',
    send_channels = { 'Say', 'Party', 'Tell', 'Linkshell', 'Linkshell2', 'Shout', 'Yell' },
    tell_target = { '' }, -- ImGui needs Lua table, not FFI buffer
    
    -- Window size
    window_size = { 650, 450 },
    
    -- Status messages
    status_message = '',
    status_time = 0,
    status_duration = 3, -- seconds to show status
    
    -- Debug
    debug_mode = false,
};

-- Chat mode to channel name mapping (from text_in event)
local chat_modes = {
    [1] = 'Say',
    [4] = 'Say',
    [5] = 'Party',       -- Party (self)
    [9] = 'Say',
    [10] = 'Shout',
    [11] = 'Yell',
    [12] = 'Tell',
    [13] = 'Party',      -- Party (others)
    [14] = 'Linkshell',
    [26] = 'Party',      -- Party (additional)
    [27] = 'Alliance',   -- Alliance
    [150] = 'NPC',       -- NPC dialogue
    [151] = 'NPC',       -- NPC dialogue (variant)
    [212] = 'Unity',
    [214] = 'Linkshell2',
};

--[[
* Gets text from the Windows clipboard (converts to UTF-8)
* @return {string|nil} - The clipboard text in UTF-8, or nil if failed
--]]
local function GetClipboardText()
    if not ffi.C.OpenClipboard(nil) then
        return nil;
    end
    
    local clipboard_text = nil;
    
    -- Try Unicode text first and convert to UTF-8
    local hData = ffi.C.GetClipboardData(CF_UNICODETEXT);
    
    if hData ~= nil then
        local pData = ffi.C.GlobalLock(hData);
        
        if pData ~= nil then
            local size = ffi.C.GlobalSize(hData);
            
            if size > 0 then
                local wstr = ffi.cast('const wchar_t*', pData);
                
                -- Convert Unicode to UTF-8 (code page 65001)
                local bytesNeeded = ffi.C.WideCharToMultiByte(
                    65001, 0, wstr, -1, nil, 0, nil, nil
                );
                
                if bytesNeeded > 0 then
                    local buffer = ffi.new('char[?]', bytesNeeded);
                    local result = ffi.C.WideCharToMultiByte(
                        65001, 0, wstr, -1, buffer, bytesNeeded, nil, nil
                    );
                    
                    if result > 0 then
                        clipboard_text = ffi.string(buffer);
                    end
                end
            end
            
            ffi.C.GlobalUnlock(hData);
        end
    end
    
    -- Fallback to ANSI text
    if not clipboard_text or clipboard_text == '' then
        hData = ffi.C.GetClipboardData(CF_TEXT);
        
        if hData ~= nil then
            local pData = ffi.C.GlobalLock(hData);
            
            if pData ~= nil then
                clipboard_text = ffi.string(ffi.cast('const char*', pData));
                ffi.C.GlobalUnlock(hData);
            end
        end
    end
    
    ffi.C.CloseClipboard();
    
    return clipboard_text;
end

--[[
* Sets text to the Windows clipboard (UTF-8 to Unicode)
* @param {string} text - The text to copy to clipboard (UTF-8)
* @return {boolean} - True if successful
--]]
local function SetClipboardText(text)
    if not text or text == '' then
        return false;
    end
    
    if not ffi.C.OpenClipboard(nil) then
        return false;
    end
    
    ffi.C.EmptyClipboard();
    
    -- Convert UTF-8 to Unicode (code page 65001)
    local charsNeeded = ffi.C.MultiByteToWideChar(
        65001, 0, text, -1, nil, 0
    );
    
    if charsNeeded > 0 then
        local hMem = ffi.C.GlobalAlloc(bit.bor(GMEM_MOVEABLE, GMEM_ZEROINIT), charsNeeded * 2);
        
        if hMem ~= nil then
            local pMem = ffi.C.GlobalLock(hMem);
            
            if pMem ~= nil then
                local wstr = ffi.cast('wchar_t*', pMem);
                ffi.C.MultiByteToWideChar(65001, 0, text, -1, wstr, charsNeeded);
                ffi.C.GlobalUnlock(hMem);
                ffi.C.SetClipboardData(CF_UNICODETEXT, hMem);
            else
                ffi.C.GlobalFree(hMem);
            end
        end
    end
    
    ffi.C.CloseClipboard();
    
    return true;
end

--[[
* Converts UTF-8 string to Shift-JIS (for sending to game)
* @param {string} utf8_str - UTF-8 encoded string
* @return {string} - Shift-JIS encoded string
--]]
local function UTF8ToShiftJIS(utf8_str)
    if not utf8_str or utf8_str == '' then
        return '';
    end
    
    local buffer = ffi.new('char[4096]');
    local wBuffer = ffi.new('wchar_t[4096]');
    
    -- Copy input to buffer
    ffi.copy(buffer, utf8_str);
    
    -- UTF-8 to Wide Char
    local wchars = ffi.C.MultiByteToWideChar(65001, 0, buffer, -1, wBuffer, 4096);
    if wchars == 0 then
        return utf8_str; -- Return original on failure
    end
    
    -- Wide Char to Shift-JIS
    local bytes = ffi.C.WideCharToMultiByte(932, 0, wBuffer, -1, buffer, 4096, nil, nil);
    if bytes == 0 then
        return utf8_str; -- Return original on failure
    end
    
    return ffi.string(buffer);
end

--[[
* Converts Shift-JIS string to UTF-8 (for displaying game messages)
* @param {string} sjis_str - Shift-JIS encoded string
* @return {string} - UTF-8 encoded string
--]]
local function ShiftJISToUTF8(sjis_str)
    if not sjis_str or sjis_str == '' then
        return '';
    end
    
    local buffer = ffi.new('char[4096]');
    local wBuffer = ffi.new('wchar_t[4096]');
    
    -- Copy input to buffer
    local len = math.min(#sjis_str + 1, 4095);
    ffi.copy(buffer, sjis_str, len);
    
    -- Shift-JIS to Wide Char
    local wchars = ffi.C.MultiByteToWideChar(932, 0, buffer, len, wBuffer, 4096);
    if wchars == 0 then
        return sjis_str; -- Return original on failure
    end
    
    -- Wide Char to UTF-8
    local bytes = ffi.C.WideCharToMultiByte(65001, 0, wBuffer, wchars, buffer, 4096, nil, nil);
    if bytes == 0 then
        return sjis_str; -- Return original on failure
    end
    
    return ffi.string(buffer, bytes - 1); -- Exclude null terminator
end

--[[
* Writes a translation request to file for external processor
* @param {string} text - Text to translate
* @param {string} target_lang - Target language
* @param {string} source_lang - Source language
* @param {string} context - Context info (sender, channel)
* @param {table} options - Optional: {auto_send = true, channel = 'linkshell', target = 'name'}
--]]
local function QueueTranslation(text, target_lang, source_lang, context, options)
    if not text or text == '' then
        return;
    end
    
    options = options or {};
    
    -- Check cache first
    local cache_key = string.format('%s_%s_%s', source_lang, target_lang, text);
    if kotoba.translation_cache[cache_key] then
        -- Print cached result immediately
        local translation = kotoba.translation_cache[cache_key];
        print('[Kotoba] ' .. context .. ': ' .. translation);
        
        -- If auto-send is enabled, send it now (use direct command execution)
        if options.auto_send then
            local sjis_text = UTF8ToShiftJIS(translation);
            local command = '';
            local channel = options.channel or 'Say';
            
            if channel == 'Say' then
                command = '/say ' .. sjis_text;
            elseif channel == 'Party' then
                command = '/p ' .. sjis_text;
            elseif channel == 'Tell' then
                if options.target and options.target ~= '' then
                    command = '/tell ' .. options.target .. ' ' .. sjis_text;
                else
                    print('[Kotoba] Tell requires a target name.');
                    return;
                end
            elseif channel == 'Linkshell' then
                command = '/l ' .. sjis_text;
            elseif channel == 'Linkshell2' then
                command = '/l2 ' .. sjis_text;
            elseif channel == 'Shout' then
                command = '/sh ' .. sjis_text;
            elseif channel == 'Yell' then
                command = '/yell ' .. sjis_text;
            else
                command = '/say ' .. sjis_text;
            end
            
            AshitaCore:GetChatManager():QueueCommand(1, command);
        end
        
        return;
    end
    
    -- Generate unique ID for this translation
    local translation_id = os.time() .. '_' .. math.random(1000, 9999);
    
    -- Store in pending translations
    kotoba.translation_pending[translation_id] = {
        text = text,
        context = context,
        cache_key = cache_key,
        timestamp = os.time(),
        auto_send = options.auto_send or false,
        send_channel = options.channel,
        send_target = options.target,
    };
    
    -- Escape special characters in text (prevent pipe confusion)
    local escaped_text = text:gsub('|', '\\|'):gsub('\n', '\\n'):gsub('\r', '\\r');
    
    -- Write to queue file with binary mode to preserve UTF-8
    local file = io.open(kotoba.translation_queue_file, 'ab');
    if file then
        -- Format: ID|SOURCE_LANG|TARGET_LANG|TEXT
        local line = translation_id .. '|' .. source_lang .. '|' .. target_lang .. '|' .. escaped_text .. '\n';
        file:write(line);
        file:close();
        
        if kotoba.debug_mode then
            print('[Kotoba] Queued translation: ' .. text:sub(1, 50));
        end
    else
        print('[Kotoba] ERROR: Could not write to translation queue!');
    end
end

--[[
* Reads translation results from file
--]]
local function CheckTranslationResults()
    local file = io.open(kotoba.translation_results_file, 'rb');
    if not file then
        return;
    end
    
    local content = file:read('*all');
    file:close();
    
    if not content or content == '' then
        return;
    end
    
    local results = {};
    for line in content:gmatch('[^\r\n]+') do
        if line and line ~= '' then
            -- Format: ID|TRANSLATED_TEXT
            local id, translation = line:match('^([^|]+)|(.+)$');
            if id and translation and kotoba.translation_pending[id] then
                -- Unescape special characters
                translation = translation:gsub('\\|', '|'):gsub('\\n', '\n'):gsub('\\r', '\r');
                
                table.insert(results, {
                    id = id,
                    translation = translation
                });
            end
        end
    end
    
    -- Process results
    for _, result in ipairs(results) do
        local pending = kotoba.translation_pending[result.id];
        if pending then
            -- Cache the translation
            kotoba.translation_cache[pending.cache_key] = result.translation;
            
            -- Print to game chat
            print('[Kotoba] ' .. pending.context .. ': ' .. result.translation);
            
            -- Auto-send if requested
            if pending.auto_send then
                -- Use direct command execution instead of calling SendMessage
                -- Convert UTF-8 to Shift-JIS
                local sjis_text = UTF8ToShiftJIS(result.translation);
                
                -- Build command
                local command = '';
                local channel = pending.send_channel or 'Say';
                
                if channel == 'Say' then
                    command = '/say ' .. sjis_text;
                elseif channel == 'Party' then
                    command = '/p ' .. sjis_text;
                elseif channel == 'Tell' then
                    if pending.send_target and pending.send_target ~= '' then
                        command = '/tell ' .. pending.send_target .. ' ' .. sjis_text;
                    else
                        print('[Kotoba] Tell requires a target name.');
                        command = nil;
                    end
                elseif channel == 'Linkshell' then
                    command = '/l ' .. sjis_text;
                elseif channel == 'Linkshell2' then
                    command = '/l2 ' .. sjis_text;
                elseif channel == 'Shout' then
                    command = '/sh ' .. sjis_text;
                elseif channel == 'Yell' then
                    command = '/yell ' .. sjis_text;
                else
                    command = '/say ' .. sjis_text;
                end
                
                -- Execute command
                if command then
                    AshitaCore:GetChatManager():QueueCommand(1, command);
                end
            end
            
            -- Remove from pending
            kotoba.translation_pending[result.id] = nil;
        end
    end
    
    -- Clear results file after processing
    if #results > 0 then
        local clear_file = io.open(kotoba.translation_results_file, 'wb');
        if clear_file then
            clear_file:close();
        end
    end
end

--[[
* Adds a message to the chat history
* @param {string} text - The message text
* @param {string} channel - The channel name
* @param {string} sender - The sender name (optional)
--]]
local function AddMessage(text, channel, sender)
    -- Create a hash to detect duplicates
    local message_hash = string.format('%s_%s_%s', channel, sender or '', text);
    local current_time = os.time();
    
    -- Check if this is a duplicate message within the timeout window
    if kotoba.recent_messages[message_hash] then
        local time_diff = current_time - kotoba.recent_messages[message_hash];
        if time_diff < kotoba.duplicate_timeout then
            -- This is a duplicate, skip it
            return;
        end
    end
    
    -- Store this message hash with current timestamp
    kotoba.recent_messages[message_hash] = current_time;
    
    -- Clean up old entries from recent_messages cache
    for hash, timestamp in pairs(kotoba.recent_messages) do
        if current_time - timestamp > kotoba.duplicate_timeout then
            kotoba.recent_messages[hash] = nil;
        end
    end
    
    -- Add message to history (for reference)
    table.insert(kotoba.messages, {
        text = text,
        channel = channel or 'Unknown',
        sender = sender or '',
        timestamp = current_time,
    });
    
    -- Keep only the last N messages
    while #kotoba.messages > kotoba.max_messages do
        table.remove(kotoba.messages, 1);
    end
    
    -- Auto-translate if enabled
    if kotoba.auto_translate_incoming[1] and text and text ~= '' then
        -- Skip if this is our own addon output (prevents feedback loop)
        if text:match('^%[Kotoba%]') then
            return;
        end
        
        -- Detect if message contains actual Japanese characters
        -- Check for Hiragana (U+3040-U+309F), Katakana (U+30A0-U+30FF), or Kanji (U+4E00-U+9FFF)
        local has_japanese = false;
        local i = 1;
        while i <= #text do
            local byte = text:byte(i);
            
            -- Check for 3-byte UTF-8 sequences (most Japanese characters)
            if byte >= 0xE0 and byte <= 0xEF and i + 2 <= #text then
                local byte2 = text:byte(i + 1);
                local byte3 = text:byte(i + 2);
                
                -- Calculate Unicode codepoint from UTF-8 bytes
                local codepoint = ((byte - 0xE0) * 0x1000) + ((byte2 - 0x80) * 0x40) + (byte3 - 0x80);
                
                -- Check if it's in Japanese ranges
                -- Hiragana: 0x3040-0x309F
                -- Katakana: 0x30A0-0x30FF  
                -- CJK Ideographs: 0x4E00-0x9FFF
                if (codepoint >= 0x3040 and codepoint <= 0x309F) or    -- Hiragana
                   (codepoint >= 0x30A0 and codepoint <= 0x30FF) or    -- Katakana
                   (codepoint >= 0x4E00 and codepoint <= 0x9FFF) then  -- Kanji
                    has_japanese = true;
                    break;
                end
                
                i = i + 3;
            elseif byte >= 0xC0 and byte <= 0xDF then
                i = i + 2;  -- 2-byte sequence
            elseif byte >= 0xF0 and byte <= 0xF7 then
                i = i + 4;  -- 4-byte sequence
            else
                i = i + 1;  -- ASCII or single byte
            end
        end
        
        if has_japanese then
            -- Queue translation via file system
            local context = sender ~= '' and sender or channel;
            QueueTranslation(text, 'en', 'ja', context);
        end
    end
end

--[[
* Converts Unicode codepoint to UTF-8 bytes (for ImGui display)
* @param {number} codepoint - Unicode codepoint value
* @return {string} - UTF-8 encoded bytes
--]]
local function UnicodeToUTF8(codepoint)
    -- Validate codepoint range
    if not codepoint or codepoint < 0 or codepoint > 0x10FFFF then
        if kotoba.debug_mode then
            print(string.format('[Kotoba] Invalid codepoint: %s', tostring(codepoint)));
        end
        return '?';
    end
    
    -- Handle ASCII range directly (optimization)
    if codepoint < 0x80 then
        return string.char(codepoint);
    end
    
    -- 2-byte UTF-8
    if codepoint < 0x800 then
        return string.char(
            bit.bor(0xC0, bit.rshift(codepoint, 6)),
            bit.bor(0x80, bit.band(codepoint, 0x3F))
        );
    end
    
    -- 3-byte UTF-8
    if codepoint < 0x10000 then
        return string.char(
            bit.bor(0xE0, bit.rshift(codepoint, 12)),
            bit.bor(0x80, bit.band(bit.rshift(codepoint, 6), 0x3F)),
            bit.bor(0x80, bit.band(codepoint, 0x3F))
        );
    end
    
    -- 4-byte UTF-8
    if codepoint < 0x110000 then
        return string.char(
            bit.bor(0xF0, bit.rshift(codepoint, 18)),
            bit.bor(0x80, bit.band(bit.rshift(codepoint, 12), 0x3F)),
            bit.bor(0x80, bit.band(bit.rshift(codepoint, 6), 0x3F)),
            bit.bor(0x80, bit.band(codepoint, 0x3F))
        );
    end
    
    return '?';
end

--[[
* Decodes Unicode escape sequences (\uXXXX) to UTF-8 for ImGui display
* @param {string} str - String with Unicode escapes like \u3061
* @return {string} - UTF-8 encoded string
--]]
DecodeUnicodeEscapes = function(str)
    if not str or str == '' then
        return '';
    end
    
    if kotoba.debug_mode then
        print(string.format('[Kotoba] Decoding Unicode escapes from: %s', str:sub(1, 100)));
        -- Count how many escape sequences we have
        local count = 0;
        for _ in str:gmatch('\\u%x%x%x%x') do
            count = count + 1;
        end
        print(string.format('[Kotoba] Found %d Unicode escape sequences', count));
    end
    
    -- Process Unicode escape sequences and convert to UTF-8
    local result = str:gsub('\\u(%x%x%x%x)', function(hex)
        local codepoint = tonumber(hex, 16);
        if codepoint then
            local converted = UnicodeToUTF8(codepoint);
            if kotoba.debug_mode and converted == '?' then
                print(string.format('[Kotoba] Warning: Codepoint U+%s converted to ?', hex));
            end
            return converted;
        end
        if kotoba.debug_mode then
            print(string.format('[Kotoba] Warning: Failed to parse hex value: %s', hex));
        end
        return '?';
    end);
    
    if kotoba.debug_mode then
        local result_preview = result:sub(1, 100);
        if #result > 100 then
            result_preview = result_preview .. '...';
        end
        print(string.format('[Kotoba] Result after decoding (UTF-8): %s', result_preview));
        print(string.format('[Kotoba] Original length: %d, Result length: %d', #str, #result));
    end
    
    return result;
end

--[[
* Sets a temporary status message
* @param {string} message - The status message to display
* @param {boolean} is_error - Whether this is an error message
--]]
local function SetStatus(message, is_error)
    kotoba.status_message = message;
    kotoba.status_time = os.clock();
    kotoba.status_is_error = is_error or false;
    print('[Kotoba] ' .. message);
end

--[[
* Sends a message to the specified channel
* @param {string} text - The message to send (UTF-8 encoded)
* @param {string} channel - The channel to send to
* @param {string} target - The target name (for tells)
--]]
local function SendMessage(text, channel, target)
    if not text or text == '' then
        return;
    end
    
    -- Convert UTF-8 to Shift-JIS for the game
    local sjis_text = UTF8ToShiftJIS(text);
    
    local command = '';
    
    if channel == 'Say' then
        command = '/say ' .. sjis_text;
    elseif channel == 'Party' then
        command = '/p ' .. sjis_text;
    elseif channel == 'Tell' then
        if not target or target == '' then
            print('[Kotoba] Tell requires a target name.');
            return;
        end
        command = '/tell ' .. target .. ' ' .. sjis_text;
    elseif channel == 'Linkshell' then
        command = '/l ' .. sjis_text;
    elseif channel == 'Linkshell2' then
        command = '/l2 ' .. sjis_text;
    elseif channel == 'Shout' then
        command = '/sh ' .. sjis_text;
    elseif channel == 'Yell' then
        command = '/yell ' .. sjis_text;
    else
        command = '/say ' .. sjis_text;
    end
    
    if kotoba.debug_mode then
        print(string.format('[Kotoba] Sending command: %s', command:sub(1, 100)));
    end
    
    AshitaCore:GetChatManager():QueueCommand(1, command);
end

--[[
* Renders the ImGui window (simplified - input/translation only)
--]]
local function RenderWindow()
    if not kotoba.is_open[1] then
        return;
    end
    
    imgui.SetNextWindowSize({ 500, 280 }, ImGuiCond_FirstUseEver);
    
    if imgui.Begin('Kotoba v1.1 - Translation Assistant', kotoba.is_open, ImGuiWindowFlags_None) then
        -- Auto-translate toggle
        imgui.Text('Auto-Translate Incoming:');
        imgui.SameLine();
        if imgui.Checkbox('##autotrans', kotoba.auto_translate_incoming) then
            -- Checkbox value is automatically updated by ImGui, just show status
            if kotoba.auto_translate_incoming[1] then
                print('[Kotoba] Auto-translation enabled. Japanese messages will be translated to English in game chat.');
            else
                print('[Kotoba] Auto-translation disabled.');
            end
        end
        
        imgui.SameLine();
        imgui.Dummy({ 10, 0 });
        imgui.SameLine();
        
        -- Status message display
        if kotoba.status_message ~= '' then
            local time_since = os.clock() - kotoba.status_time;
            if time_since < kotoba.status_duration then
                imgui.SameLine();
                imgui.Dummy({ 10, 0 });
                imgui.SameLine();
                local status_color = kotoba.status_is_error and { 1.0, 0.3, 0.3, 1.0 } or { 0.3, 1.0, 0.3, 1.0 };
                imgui.PushStyleColor(ImGuiCol_Text, status_color);
                imgui.Text(kotoba.status_message);
                imgui.PopStyleColor();
            else
                kotoba.status_message = '';
            end
        end
        
        imgui.Separator();
        
        -- Compose section
        imgui.Text('Compose & Translate:');
        imgui.SameLine();
        imgui.Dummy({ 10, 0 });
        imgui.SameLine();
        imgui.Text('Language:');
        imgui.SameLine();
        imgui.SetNextItemWidth(120);
        local lang_options = { 'ja', 'en', 'es', 'fr', 'de', 'ko', 'zh' };
        local lang_names = { 'Japanese', 'English', 'Spanish', 'French', 'German', 'Korean', 'Chinese' };
        local current_lang_index = 1;
        for i, lang in ipairs(lang_options) do
            if lang == kotoba.translate_to then
                current_lang_index = i;
                break;
            end
        end
        if imgui.BeginCombo('##translang', lang_names[current_lang_index]) then
            for i, lang in ipairs(lang_options) do
                local is_selected = (kotoba.translate_to == lang);
                if imgui.Selectable(lang_names[i], is_selected) then
                    kotoba.translate_to = lang;
                end
                if is_selected then
                    imgui.SetItemDefaultFocus();
                end
            end
            imgui.EndCombo();
        end
        
        -- Input text box (size: width=-1 for full width, height=80)
        local input_size = { -1, 80 };
        imgui.InputTextMultiline('##input', kotoba.input_text, 2048, input_size);
        
        -- Button row: Translate & Send
        imgui.PushStyleColor(ImGuiCol_Button, { 0.2, 0.6, 0.2, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.3, 0.7, 0.3, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.15, 0.5, 0.15, 1.0 });
        if imgui.Button('Translate & Send') then
            local text = kotoba.input_text[1] or '';
            if text ~= '' then
                local source_lang = 'en';
                if kotoba.translate_to == 'en' then
                    source_lang = 'ja';
                elseif kotoba.translate_to == 'ja' then
                    source_lang = 'en';
                end
                
                -- Get send target
                    local target = kotoba.send_channel == 'Tell' and kotoba.tell_target[1] or nil;
                
                -- Queue translation with auto-send
                QueueTranslation(text, kotoba.translate_to, source_lang, 'Translate & Send', {
                    auto_send = true,
                    channel = kotoba.send_channel,
                    target = target
                });
            else
                SetStatus('Input is empty', true);
            end
        end
        imgui.PopStyleColor(3);
        
        imgui.SameLine();
        
        if imgui.Button('Copy') then
            local text = kotoba.input_text[1] or '';
            if text ~= '' then
                SetClipboardText(text);
                SetStatus('Copied to clipboard');
            end
        end
        
        imgui.SameLine();
        
        if imgui.Button('Paste') then
            local text = GetClipboardText();
            if text then
                kotoba.input_text[1] = text;
                SetStatus('Pasted from clipboard');
            else
                SetStatus('Clipboard is empty', true);
            end
        end
        
        imgui.SameLine();
        
        if imgui.Button('Clear') then
            kotoba.input_text[1] = '';
        end
        -- Send controls row
        imgui.Text('Send to:');
        imgui.SameLine();
        imgui.SetNextItemWidth(120);
        if imgui.BeginCombo('##sendchannel', kotoba.send_channel) then
            for _, channel in ipairs(kotoba.send_channels) do
                local is_selected = (kotoba.send_channel == channel);
                if imgui.Selectable(channel, is_selected) then
                    kotoba.send_channel = channel;
                end
                if is_selected then
                    imgui.SetItemDefaultFocus();
                end
            end
            imgui.EndCombo();
        end
        
        -- Tell target input
        if kotoba.send_channel == 'Tell' then
            imgui.SameLine();
            imgui.Text('Target:');
            imgui.SameLine();
            imgui.SetNextItemWidth(150);
            imgui.InputText('##telltarget', kotoba.tell_target, 256);
        end
        
        imgui.End();
    end
end

--[[
* event: text_in
* desc : Event called when the game client receives text.
--]]
ashita.events.register('text_in', 'kotoba_text_in', function (e)
    -- Get the chat mode using bit masking (like tellnotifier)
    local mode = bit.band(e.mode_modified, 0x000000FF);
    local message = e.message_modified or e.message;
    
    -- Skip Unity chat (mode 212) - has weird packet formatting
    if mode == 212 then
        return;
    end
    
    -- Skip empty messages
    if not message or message == '' then
        return;
    end
    
    -- Debug: Show raw message
    if kotoba.debug_mode then
        local hex_preview = '';
        for i = 1, math.min(20, #message) do
            hex_preview = hex_preview .. string.format('%02X ', string.byte(message, i));
        end
        print(string.format('[Kotoba] RAW message (first 20 bytes): %s', hex_preview));
        print(string.format('[Kotoba] RAW message text: "%s"', message:sub(1, 100)));
    end
    
    -- Clean the message using Ashita's string methods
    local clean_message = message;
    
    -- Strip auto-translate tags and colors BEFORE conversion (they work on Shift-JIS)
    local success, parsed = pcall(function()
        return clean_message:strip_translate(true);
    end);
    if success and parsed then
        clean_message = parsed;
    end
    
    success, parsed = pcall(function()
        return clean_message:strip_colors();
    end);
    if success and parsed then
        clean_message = parsed;
    end
    
    -- NOW convert from Shift-JIS to UTF-8 (after stripping tags/colors)
    clean_message = ShiftJISToUTF8(clean_message);
    
    -- Now safe to do string operations on UTF-8
    -- Remove timestamps in format [HH:MM:SS] or [HH:MM]
    clean_message = clean_message:gsub('%[%d+:%d+:%d+%]%s*', '');
    clean_message = clean_message:gsub('%[%d+:%d+%]%s*', '');
    
    -- Remove only ASCII control characters (0x00-0x1F), NOT 0x7F-0x9F which are UTF-8 continuation bytes!
    clean_message = clean_message:gsub('[\x00-\x1F]', '');
    
    -- Trim whitespace
    clean_message = clean_message:gsub('^%s*(.-)%s*$', '%1');
    
    -- Skip if message is empty after cleaning
    if clean_message == '' then
        return;
    end
    
    -- Determine channel
    local channel = chat_modes[mode] or 'Unknown';
    
    -- Try to extract sender name (handles multiple formats)
    local sender = '';
    local text = clean_message;
    
    -- Pattern 1: "[X] <Name> message" (linkshell with number)
    local matched_name, matched_text = clean_message:match('^%[%d+%]%s*<([^>]+)>%s*(.+)$');
    if matched_name and matched_text then
        sender = matched_name:gsub('^%s*', ''):gsub('%s*$', '');
        text = matched_text;
    else
        -- Pattern 2: "<Name> message" (linkshell without number)
        matched_name, matched_text = clean_message:match('^<([^>]+)>%s*(.+)$');
        if matched_name and matched_text then
            sender = matched_name:gsub('^%s*', ''):gsub('%s*$', '');
            text = matched_text;
        else
            -- Pattern 3: ">>Name : message" (party)
            matched_name, matched_text = clean_message:match('^>>([^:]+)%s*:%s*(.+)$');
            if matched_name and matched_text then
                sender = matched_name:gsub('^%s*', ''):gsub('%s*$', '');
                text = matched_text;
            else
                -- Pattern 4: "Name: message" (tell/say)
                matched_name, matched_text = clean_message:match('^([^:>><%[]+):%s*(.+)$');
                if matched_name and matched_text and not matched_name:match('%s') then
                    sender = matched_name:gsub('^%s*', ''):gsub('%s*$', '');
                    text = matched_text;
                else
                    -- Pattern 5: "(Name) message" (trust/npc)
            matched_name, matched_text = clean_message:match('^%(([^)]+)%)%s*(.+)$');
                    if matched_name and matched_text then
                sender = matched_name:gsub('^%s*', ''):gsub('%s*$', '');
                text = matched_text;
                    end
                end
            end
        end
    end
    
    -- Add to chat history (now in UTF-8 format)
    AddMessage(text, channel, sender);
end);

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'kotoba_present', function ()
    RenderWindow();
    
    -- Check for translation results periodically
    kotoba.translation_check_timer = kotoba.translation_check_timer + 1;
    if kotoba.translation_check_timer >= kotoba.translation_check_interval then
        kotoba.translation_check_timer = 0;
        CheckTranslationResults();
    end
end);

--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command', 'kotoba_command', function (e)
    local args = e.command:args();
    
    if #args == 0 or not args[1]:any('/kotoba', '/kb') then
        return;
    end
    
    e.blocked = true;
    
    -- /kotoba (no args) - toggle window
    if #args == 1 then
        kotoba.is_open[1] = not kotoba.is_open[1];
        return;
    end
    
    -- /kotoba help
    if args[2]:any('help', 'h', '?') then
        print('[Kotoba] Commands:');
        print('  /kotoba - Toggle window');
        print('  /kotoba clear - Clear chat history');
        print('  /kotoba debug - Toggle debug mode');
        print('  /kotoba help - Show this help');
        print('');
        print('Aliases: /kb');
        return;
    end
    
    -- /kotoba clear
    if args[2]:any('clear') then
        kotoba.messages = {};
        print('[Kotoba] Chat history cleared.');
        return;
    end
    
    -- /kotoba debug
    if args[2]:any('debug') then
        kotoba.debug_mode = not kotoba.debug_mode;
        local status = kotoba.debug_mode and 'enabled' or 'disabled';
        print('[Kotoba] Debug mode ' .. status);
        return;
    end
end);

-- Print loaded message
print('[Kotoba v1.1] Loaded! Multi-language chat assistant ready.');
print('[Kotoba] Use /kotoba or /kb to toggle window.');
print('[Kotoba] Translations appear in GAME CHAT with perfect Japanese rendering!');
print('[Kotoba] Enable "Auto-Translate Incoming" to translate Japanese messages to English automatically.');


