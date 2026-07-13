--[[
    Kotoba in-panel text input for Windower 4

    Capture DIK → buffer → panel caret; return true to consume keys.
    Key-blocking via return-true only works while chat is open (Issues#788).

    Also temporarily bind movement/letter keys to a no-op while editing, so
    WASD cannot move the character even if chat briefly closes.
]]

local input = {}

local KEYMAP = {
    [2] = { '1', '!' }, [3] = { '2', '@' }, [4] = { '3', '#' }, [5] = { '4', '$' },
    [6] = { '5', '%' }, [7] = { '6', '^' }, [8] = { '7', '&' }, [9] = { '8', '*' },
    [10] = { '9', '(' }, [11] = { '0', ')' },
    [12] = { '-', '_' }, [13] = { '=', '+' },
    [16] = { 'q', 'Q' }, [17] = { 'w', 'W' }, [18] = { 'e', 'E' }, [19] = { 'r', 'R' },
    [20] = { 't', 'T' }, [21] = { 'y', 'Y' }, [22] = { 'u', 'U' }, [23] = { 'i', 'I' },
    [24] = { 'o', 'O' }, [25] = { 'p', 'P' },
    [26] = { '[', '{' }, [27] = { ']', '}' }, [39] = { ';', ':' }, [40] = { "'", '"' },
    [41] = { '`', '~' }, [43] = { '\\', '|' },
    [30] = { 'a', 'A' }, [31] = { 's', 'S' }, [32] = { 'd', 'D' }, [33] = { 'f', 'F' },
    [34] = { 'g', 'G' }, [35] = { 'h', 'H' }, [36] = { 'j', 'J' }, [37] = { 'k', 'K' },
    [38] = { 'l', 'L' },
    [44] = { 'z', 'Z' }, [45] = { 'x', 'X' }, [46] = { 'c', 'C' }, [47] = { 'v', 'V' },
    [48] = { 'b', 'B' }, [49] = { 'n', 'N' }, [50] = { 'm', 'M' },
    [51] = { ',', '<' }, [52] = { '.', '>' }, [53] = { '/', '?' },
    [57] = { ' ', ' ' },
}

-- Keys that must not reach the game while typing (movement + letters)
local SUPPRESS_KEYS = {
    'w', 'a', 's', 'd', 'q', 'e', 'z', 'x', 'c', 'v', 'f', 'r', 't', 'g', 'b', 'n',
    'h', 'j', 'k', 'l', 'y', 'u', 'i', 'o', 'p', 'm',
    'numpad2', 'numpad4', 'numpad6', 'numpad8',
    'up', 'down', 'left', 'right',
}

local BACKSPACE = 14
local ENTER = 28
local NUMPAD_ENTER = 156
local ESCAPE = 1
local LSHIFT = 42
local RSHIFT = 54

local shift_down = false
local active = false
local buffer = ''
local mode = nil
local max_len = 200
local on_change = nil
local on_confirm = nil
local on_cancel = nil
local ignore_keys_until = 0
local we_opened_chat = false
local keys_suppressed = false
local last_reopen = 0

local function chat_open()
    if windower.chat and windower.chat.is_open then
        return windower.chat.is_open()
    end
    local info = windower.ffxi.get_info()
    return info and info.chat_open
end

local function clear_chat_input()
    if windower.chat and windower.chat.set_input then
        pcall(windower.chat.set_input, '')
    end
end

local function suppress_game_keys(enable)
    if enable and not keys_suppressed then
        for _, key in ipairs(SUPPRESS_KEYS) do
            -- wait = no-op; prevents default game bind for this key while editing
            windower.send_command('bind ' .. key .. ' wait')
        end
        keys_suppressed = true
    elseif (not enable) and keys_suppressed then
        for _, key in ipairs(SUPPRESS_KEYS) do
            windower.send_command('unbind ' .. key)
        end
        keys_suppressed = false
    end
end

local function open_chat_for_typing()
    if chat_open() then
        clear_chat_input()
        return false
    end
    ignore_keys_until = os.clock() + 0.70
    last_reopen = os.clock()
    -- Escape clears menus first; Enter opens chat (Issues#788 needs chat open)
    windower.send_command(
        'setkey escape down; wait 0.06; setkey escape up; wait 0.10; '
        .. 'setkey enter down; wait 0.05; setkey enter up'
    )
    return true
end

local function reopen_chat_soft()
    local now = os.clock()
    if now - last_reopen < 0.9 then
        return
    end
    last_reopen = now
    ignore_keys_until = now + 0.35
    -- Enter only — do not Esc-spam (that fought door menus)
    windower.send_command('setkey enter down; wait 0.05; setkey enter up')
    we_opened_chat = true
end

local function close_chat_gently()
    if not chat_open() then
        return
    end
    ignore_keys_until = os.clock() + 0.35
    windower.send_command('setkey escape down; wait 0.05; setkey escape up')
end

local function notify_change()
    if on_change then
        on_change(mode, buffer)
    end
end

function input.is_active()
    return active
end

function input.get_mode()
    return mode
end

function input.get_buffer()
    return buffer
end

function input.set_buffer(text)
    buffer = text or ''
    notify_change()
end

function input.start(new_mode, initial, callbacks)
    mode = new_mode
    buffer = initial or ''
    on_change = callbacks and callbacks.on_change or nil
    on_confirm = callbacks and callbacks.on_confirm or nil
    on_cancel = callbacks and callbacks.on_cancel or nil

    suppress_game_keys(true)
    we_opened_chat = open_chat_for_typing()
    active = true
    clear_chat_input()
    notify_change()
end

function input.stop(close_chat)
    active = false
    mode = nil
    suppress_game_keys(false)
    if close_chat and we_opened_chat then
        close_chat_gently()
    end
    we_opened_chat = false
end

function input.confirm()
    local m, b = mode, buffer
    input.stop(true)
    if on_confirm then
        on_confirm(m, b)
    end
end

function input.cancel()
    local m = mode
    input.stop(true)
    if on_cancel then
        on_cancel(m)
    end
end

function input.tick()
    if not active then
        return
    end
    -- Keep chat open so return-true blocks; binds cover movement if it flaps
    if not chat_open() then
        reopen_chat_soft()
        return
    end
    if windower.chat and windower.chat.get_input then
        local ok, text = pcall(function()
            local t = windower.chat.get_input()
            return type(t) == 'string' and t or ''
        end)
        if ok and text and text ~= '' then
            clear_chat_input()
        end
    end
end

function input.handle_key(dik, down)
    if not active then
        return false
    end

    if dik == LSHIFT or dik == RSHIFT then
        shift_down = down and true or false
        return true
    end

    if not down then
        return true
    end

    if os.clock() < ignore_keys_until then
        return true
    end

    if dik == ESCAPE then
        input.cancel()
        return true
    end

    if dik == ENTER or dik == NUMPAD_ENTER then
        input.confirm()
        return true
    end

    if dik == BACKSPACE then
        if #buffer > 0 then
            buffer = buffer:sub(1, -2)
            notify_change()
        end
        return true
    end

    local pair = KEYMAP[dik]
    if pair then
        if #buffer < max_len then
            buffer = buffer .. (shift_down and pair[2] or pair[1])
            notify_change()
        end
        return true
    end

    return true
end

return input
