--[[
    Kotoba in-panel text input for Windower 4

    Isolation (from https://docs.windower.net/commands/input/):

      1. keyboard_blockinput 1  — official global block of keyboard → game
         (used by Trade addon while automating menus)
      2. bind %<key> …          — % = valid only while chat is CLOSED; steals
         the key from FFXI movement/macros (same layer as Windower macros)
      3. keyboard event         — still capture DIK into our buffer when it fires

    Do NOT rely on return-true alone (Windower/Issues#788: only works with
    chat open). Do NOT spam setkey enter/escape to hold chat open.
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

local BACKSPACE = 14
local ENTER = 28
local NUMPAD_ENTER = 156
local ESCAPE = 1
local LSHIFT = 42
local RSHIFT = 54

-- Keys we steal via % binds while editing (chat-closed state)
local BIND_LETTERS = 'abcdefghijklmnopqrstuvwxyz'
local BIND_EXTRAS = {
    'space', 'backspace', 'enter', 'escape',
    'numpadenter', 'numpad0', 'numpad1', 'numpad2', 'numpad3', 'numpad4',
    'numpad5', 'numpad6', 'numpad7', 'numpad8', 'numpad9',
    'up', 'down', 'left', 'right',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
    'comma', 'period', 'minus',
}

local shift_down = false
local active = false
local buffer = ''
local mode = nil
local max_len = 200
local on_change = nil
local on_confirm = nil
local on_cancel = nil
local isolation_on = false
local bound_keys = {}

local function notify_change()
    if on_change then
        on_change(mode, buffer)
    end
end

local function append_char(ch)
    if not active then
        return
    end
    if #buffer < max_len then
        buffer = buffer .. ch
        notify_change()
    end
end

local function backspace()
    if not active then
        return
    end
    if #buffer > 0 then
        buffer = buffer:sub(1, -2)
        notify_change()
    end
end

local function arm_isolation()
    if isolation_on then
        return
    end
    isolation_on = true
    bound_keys = {}

    -- Official Windower input block (docs.windower.net/commands/input/)
    windower.send_command('keyboard_blockinput 1')

    -- % = bind only while chat is CLOSED — steals key from FFXI movement layer
    for i = 1, #BIND_LETTERS do
        local ch = BIND_LETTERS:sub(i, i)
        local cmd = string.format('bind %%%s lua c kotoba _k %s', ch, ch)
        windower.send_command(cmd)
        table.insert(bound_keys, '%' .. ch)
        -- Shift+letter
        windower.send_command(string.format('bind ~%%%s lua c kotoba _k %s', ch, ch:upper()))
        table.insert(bound_keys, '~%' .. ch)
    end

    for _, key in ipairs(BIND_EXTRAS) do
        windower.send_command(string.format('bind %%%s lua c kotoba _k %s', key, key))
        table.insert(bound_keys, '%' .. key)
    end
end

local function disarm_isolation()
    if not isolation_on then
        return
    end
    isolation_on = false
    windower.send_command('keyboard_blockinput 0')
    for _, key in ipairs(bound_keys) do
        windower.send_command('unbind ' .. key)
    end
    bound_keys = {}
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
    active = true
    arm_isolation()
    notify_change()
end

function input.stop(close_chat)
    active = false
    mode = nil
    disarm_isolation()
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

-- No chat reopen loop — isolation is blockinput + % binds
function input.tick()
end

-- Called from //kotoba _k <token> (bind path) and keyboard event
function input.ingest_token(token)
    if not active or not token then
        return
    end
    local raw = token
    local low = token:lower()
    if low == 'backspace' then
        backspace()
    elseif low == 'enter' or low == 'numpadenter' then
        input.confirm()
    elseif low == 'escape' then
        input.cancel()
    elseif low == 'space' then
        append_char(' ')
    elseif low == 'comma' then
        append_char(',')
    elseif low == 'period' then
        append_char('.')
    elseif low == 'minus' then
        append_char('-')
    elseif #raw == 1 then
        append_char(raw) -- keep case from ~% shift binds
    elseif low:match('^numpad%d$') then
        append_char(low:sub(-1))
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

    if dik == ESCAPE then
        input.cancel()
        return true
    end

    if dik == ENTER or dik == NUMPAD_ENTER then
        input.confirm()
        return true
    end

    if dik == BACKSPACE then
        backspace()
        return true
    end

    local pair = KEYMAP[dik]
    if pair then
        append_char(shift_down and pair[2] or pair[1])
        return true
    end

    return true
end

function input.force_unblock()
    disarm_isolation()
    active = false
    mode = nil
end

return input
