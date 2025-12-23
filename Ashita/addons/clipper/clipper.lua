--[[
* Addons - Copyright (c) 2024 Ashita Development Team
* Contact: https://www.ashitaxi.com/
* Contact: https://discord.gg/Ashita
*
* This file is part of Ashita.
*
* Clipper - Clipboard paste addon for FFXI
* Allows pasting clipboard content directly to game chat
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

addon.name      = 'clipper';
addon.author    = 'Ashita Development Team';
addon.version   = '1.0';
addon.desc      = 'Allows pasting clipboard content to game chat';
addon.link      = 'https://ashitaxi.com/';

require('common');
local ffi = require('ffi');

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
]];

-- Windows clipboard format constants
local CF_TEXT = 1;          -- ANSI text
local CF_UNICODETEXT = 13;  -- Unicode text

-- Windows code page constants
local CP_ACP = 0;           -- System default ANSI code page
local CP_SHIFTJIS = 932;    -- Shift-JIS (Japanese)

-- Settings
local clipper = {
    debug_mode = false,
    max_length = 200, -- FFXI chat message limit
    auto_send = false, -- If true, automatically sends; if false, just types into chat input
    unicode_mode = true, -- If true, converts Unicode to Shift-JIS (Japanese); if false, ASCII only
};

--[[
* Gets text from the Windows clipboard
* @return {string|nil} - The clipboard text, or nil if failed
--]]
local function GetClipboardText()
    -- Try to open the clipboard
    if not ffi.C.OpenClipboard(nil) then
        if clipper.debug_mode then
            print('[Clipper] Failed to open clipboard (is another application using it?)');
        end
        return nil;
    end
    
    local clipboard_text = nil;
    
    -- Try Unicode text first and convert to Shift-JIS (Japanese FFXI encoding)
    local hData = ffi.C.GetClipboardData(CF_UNICODETEXT);
    
    if hData ~= nil then
        local pData = ffi.C.GlobalLock(hData);
        
        if pData ~= nil then
            local size = ffi.C.GlobalSize(hData);
            
            if size > 0 then
                local wstr = ffi.cast('const wchar_t*', pData);
                
                -- First, determine how many bytes we need for the Shift-JIS conversion
                local bytesNeeded = ffi.C.WideCharToMultiByte(
                    CP_SHIFTJIS,  -- Use Shift-JIS encoding (Japanese)
                    0,            -- No special flags
                    wstr,         -- Source wide string
                    -1,           -- Null-terminated
                    nil,          -- Don't write yet, just get size
                    0,            -- Buffer size is 0
                    nil,          -- No default char
                    nil           -- Don't care if default char used
                );
                
                if bytesNeeded > 0 then
                    -- Allocate buffer for the converted string
                    local buffer = ffi.new('char[?]', bytesNeeded);
                    
                    -- Actually convert to Shift-JIS
                    local result = ffi.C.WideCharToMultiByte(
                        CP_SHIFTJIS,
                        0,
                        wstr,
                        -1,
                        buffer,
                        bytesNeeded,
                        nil,
                        nil
                    );
                    
                    if result > 0 then
                        -- Convert to Lua string (preserves Shift-JIS encoding)
                        clipboard_text = ffi.string(buffer);
                        
                        if clipper.debug_mode then
                            print(string.format('[Clipper] Converted %d wide chars to %d bytes (Shift-JIS)', 
                                size / 2, bytesNeeded));
                        end
                    end
                end
            end
            
            ffi.C.GlobalUnlock(hData);
        end
    end
    
    -- If Unicode conversion failed, try ANSI text as fallback
    if not clipboard_text or clipboard_text == '' then
        hData = ffi.C.GetClipboardData(CF_TEXT);
        
        if hData ~= nil then
            local pData = ffi.C.GlobalLock(hData);
            
            if pData ~= nil then
                clipboard_text = ffi.string(ffi.cast('const char*', pData));
                ffi.C.GlobalUnlock(hData);
                
                if clipper.debug_mode then
                    print('[Clipper] Using ANSI text format (fallback)');
                end
            end
        end
    end
    
    -- Close the clipboard
    ffi.C.CloseClipboard();
    
    if clipper.debug_mode and clipboard_text then
        print(string.format('[Clipper] Got clipboard text: "%s" (length: %d)', 
            clipboard_text:sub(1, 50), #clipboard_text));
    end
    
    return clipboard_text;
end

--[[
* Pastes clipboard content to the game chat
* @param {string|nil} prefix - Optional prefix (like /say, /tell, etc.)
--]]
local function PasteToChat(prefix)
    -- Get clipboard text
    local text = GetClipboardText();
    
    if not text or text == '' then
        print('[Clipper] Clipboard is empty or contains no text.');
        return;
    end
    
    -- Clean up the text
    text = text:gsub('[\r\n\t]', ' ');  -- Replace newlines/tabs with spaces
    text = text:gsub('%s+', ' ');       -- Collapse multiple spaces
    text = text:gsub('^%s*(.-)%s*$', '%1'); -- Trim leading/trailing spaces
    
    -- Check if text is still valid after cleaning
    if text == '' then
        print('[Clipper] Clipboard text is empty after cleaning.');
        return;
    end
    
    -- Truncate to max length if necessary
    if #text > clipper.max_length then
        text = text:sub(1, clipper.max_length);
        print(string.format('[Clipper] Text truncated to %d characters.', clipper.max_length));
    end
    
    -- Add prefix if provided
    if prefix and prefix ~= '' then
        text = prefix .. ' ' .. text;
    end
    
    -- Send to chat using Ashita's chat manager
    AshitaCore:GetChatManager():QueueCommand(1, text);
    
    if clipper.debug_mode then
        print(string.format('[Clipper] Pasted to chat: "%s"', text));
    else
        print('[Clipper] Clipboard text pasted to chat.');
    end
end

--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command', 'clipper_command_cb', function (e)
    -- Parse the command arguments
    local args = e.command:args();
    
    -- Check if it's our command
    if #args == 0 or not args[1]:any('/paste', '/clipper', '/clip') then
        return;
    end
    
    -- Block the command from being processed further
    e.blocked = true;
    
    -- Handle: /paste (no args) - paste clipboard as-is
    if #args == 1 then
        PasteToChat(nil);
        return;
    end
    
    -- Handle: /paste help
    if args[2]:any('help', 'h', '?') then
        print('[Clipper] Commands:');
        print('  /paste - Paste clipboard text to chat');
        print('  /paste say - Paste with /say prefix');
        print('  /paste party - Paste with /p prefix');
        print('  /paste tell <name> - Paste with /tell <name> prefix');
        print('  /paste shout - Paste with /sh prefix');
        print('  /paste yell - Paste with /yell prefix');
        print('  /paste debug - Toggle debug mode');
        print('  /paste unicode - Toggle Unicode/Japanese support (ON by default)');
        print('  /paste length <num> - Set max paste length (default: 200)');
        print('');
        print('Aliases: /clipper, /clip');
        print('Note: Unicode mode supports Japanese and other multi-byte characters!');
        return;
    end
    
    -- Handle: /paste debug
    if args[2]:any('debug') then
        clipper.debug_mode = not clipper.debug_mode;
        print(string.format('[Clipper] Debug mode: %s', clipper.debug_mode and 'ON' or 'OFF'));
        return;
    end
    
    -- Handle: /paste unicode
    if args[2]:any('unicode', 'utf8', 'jp') then
        clipper.unicode_mode = not clipper.unicode_mode;
        print(string.format('[Clipper] Unicode mode: %s', clipper.unicode_mode and 'ON (supports Japanese/multi-byte)' or 'OFF (ASCII only)'));
        return;
    end
    
    -- Handle: /paste length <num>
    if args[2]:any('length', 'len', 'max') and #args >= 3 then
        local length = tonumber(args[3]);
        if length and length > 0 and length <= 1000 then
            clipper.max_length = length;
            print(string.format('[Clipper] Max paste length set to: %d', clipper.max_length));
        else
            print('[Clipper] Invalid length. Must be between 1 and 1000.');
        end
        return;
    end
    
    -- Handle: /paste say - paste with /say prefix
    if args[2]:any('say', 's') then
        PasteToChat('/say');
        return;
    end
    
    -- Handle: /paste party - paste with /p prefix
    if args[2]:any('party', 'p') then
        PasteToChat('/p');
        return;
    end
    
    -- Handle: /paste linkshell - paste with /l prefix
    if args[2]:any('linkshell', 'ls', 'l') then
        PasteToChat('/l');
        return;
    end
    
    -- Handle: /paste shout - paste with /sh prefix
    if args[2]:any('shout', 'sh') then
        PasteToChat('/sh');
        return;
    end
    
    -- Handle: /paste yell - paste with /yell prefix
    if args[2]:any('yell', 'y') then
        PasteToChat('/yell');
        return;
    end
    
    -- Handle: /paste tell <name> - paste with /tell <name> prefix
    if args[2]:any('tell', 't') and #args >= 3 then
        local target = args[3];
        PasteToChat('/tell ' .. target);
        return;
    end
    
    -- Default: just paste
    PasteToChat(nil);
end);

-- Print loaded message
print('[Clipper] Loaded! Japanese/Unicode support enabled (Shift-JIS encoding).');
print('[Clipper] Use /paste or /clip to paste clipboard. Type /paste help for info.');


