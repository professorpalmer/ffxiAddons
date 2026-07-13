--[[
    Kotoba UI panel (Wave 2) — ruptchat-inspired texts chrome

    Layout (approximate Ashita ImGui):
      Title: Kotoba v2.0 - Translation Assistant
      [x] Auto-Translate Incoming
      Language: <name>
      Compose preview
      [Translate & Send] [Copy] [Paste] [Clear]
      Send to: <channel>
      Tell target (when tell)
      Status line

    Click maps + title-bar drag via ui/mouse.lua (ruptchat patterns).
]]

local controls = require('ui/controls')

local texts_ok, texts = pcall(require, 'texts')
if not texts_ok then
    texts = nil
end

local panel = {}

local LINE_H = 18
local PAD = 6
local PANEL_W = 420

local visible = false
local created = false
local actions = {}
local settings_ref = nil
local state_ref = nil

local elements = {}
local click_map = {}

local default_text_settings = {
    pos = { x = 80, y = 120 },
    bg = { alpha = 180, red = 20, green = 20, blue = 30, visible = true },
    flags = { bold = false, italic = false, draggable = false },
    padding = 2,
    text = { size = 11, font = 'Consolas', alpha = 255, red = 230, green = 230, blue = 230 },
}

local function make_text(label, opts)
    opts = opts or {}
    local cfg = {
        pos = { x = opts.x or 0, y = opts.y or 0 },
        bg = {
            alpha = opts.bg_alpha or 0,
            red = opts.bg_r or 20,
            green = opts.bg_g or 20,
            blue = opts.bg_b or 30,
            visible = opts.bg_visible ~= false and (opts.bg_alpha or 0) > 0,
        },
        flags = { bold = opts.bold or false, italic = false, draggable = false },
        padding = opts.padding or 2,
        text = {
            size = opts.size or 11,
            font = 'Consolas',
            alpha = 255,
            red = opts.r or 230,
            green = opts.g or 230,
            blue = opts.b or 230,
        },
    }
    local t = texts.new(label or '', cfg)
    if t.left_draggable then
        t:left_draggable(false)
    end
    if t.right_draggable then
        t:right_draggable(false)
    end
    return t
end

local function destroy_elements()
    for _, el in pairs(elements) do
        if el and el.destroy then
            pcall(function() el:destroy() end)
        elseif el and el.hide then
            pcall(function() el:hide() end)
        end
    end
    elements = {}
    click_map = {}
    created = false
end

local function base_pos()
    local s = settings_ref
    local x = (s and s.pos_x) or default_text_settings.pos.x
    local y = (s and s.pos_y) or default_text_settings.pos.y
    return x, y
end

local function rebuild_click_map()
    click_map = {}
    -- Relative to panel root (background) top-left
    -- Row 0: title (drag only — no action)
    -- Row 1: auto-translate
    table.insert(click_map, {
        id = 'auto',
        x_start = PAD,
        x_end = PANEL_W - PAD,
        y_start = LINE_H * 1,
        y_end = LINE_H * 2,
        action = function()
            if actions.toggle_auto then
                actions.toggle_auto()
            end
        end,
    })
    -- Row 2: language
    table.insert(click_map, {
        id = 'lang',
        x_start = PAD,
        x_end = PANEL_W - PAD,
        y_start = LINE_H * 2,
        y_end = LINE_H * 3,
        action = function()
            if actions.cycle_lang then
                actions.cycle_lang()
            end
        end,
    })
    -- Row 4: buttons — approximate column hitboxes
    local btn_y0 = LINE_H * 4
    local btn_y1 = LINE_H * 5
    local btn_w = (PANEL_W - PAD * 2) / 4
    local btn_actions = {
        { id = 'translate_send', fn = 'translate_send' },
        { id = 'copy', fn = 'copy' },
        { id = 'paste', fn = 'paste' },
        { id = 'clear', fn = 'clear' },
    }
    for i, btn in ipairs(btn_actions) do
        local x0 = PAD + (i - 1) * btn_w
        table.insert(click_map, {
            id = btn.id,
            x_start = x0,
            x_end = x0 + btn_w,
            y_start = btn_y0,
            y_end = btn_y1,
            action = function()
                if actions[btn.fn] then
                    actions[btn.fn]()
                end
            end,
        })
    end
    -- Row 5: send channel
    table.insert(click_map, {
        id = 'channel',
        x_start = PAD,
        x_end = PANEL_W - PAD,
        y_start = LINE_H * 5,
        y_end = LINE_H * 6,
        action = function()
            if actions.cycle_channel then
                actions.cycle_channel()
            end
        end,
    })
end

local function ensure_created()
    if created or not texts then
        return
    end

    local x, y = base_pos()

    -- Background / root (drag target + hover bounds)
    elements.root = make_text(
        string.rep(' ', 52) .. '\n'
            .. string.rep(' ', 52) .. '\n'
            .. string.rep(' ', 52) .. '\n'
            .. string.rep(' ', 52) .. '\n'
            .. string.rep(' ', 52) .. '\n'
            .. string.rep(' ', 52) .. '\n'
            .. string.rep(' ', 52) .. '\n'
            .. string.rep(' ', 52),
        {
            x = x,
            y = y,
            bg_alpha = 200,
            bg_r = 15,
            bg_g = 18,
            bg_b = 28,
            bg_visible = true,
            size = 11,
            r = 15,
            g = 18,
            b = 28,
            padding = PAD,
        }
    )

    elements.title = make_text('Kotoba v2.0 - Translation Assistant', {
        x = x + PAD,
        y = y + 2,
        size = 12,
        bold = true,
        r = 255,
        g = 220,
        b = 100,
    })

    elements.auto = make_text('[ ] Auto-Translate Incoming', {
        x = x + PAD,
        y = y + LINE_H * 1,
        size = 11,
        r = 200,
        g = 220,
        b = 255,
    })

    elements.lang = make_text('Language: Japanese', {
        x = x + PAD,
        y = y + LINE_H * 2,
        size = 11,
        r = 200,
        g = 255,
        b = 200,
    })

    elements.compose = make_text('Compose: (empty — //kb compose <text>)', {
        x = x + PAD,
        y = y + LINE_H * 3,
        size = 10,
        r = 210,
        g = 210,
        b = 210,
    })

    elements.buttons = make_text('[Translate & Send]  [Copy]  [Paste]  [Clear]', {
        x = x + PAD,
        y = y + LINE_H * 4,
        size = 10,
        bold = true,
        r = 120,
        g = 220,
        b = 120,
    })

    elements.channel = make_text('Send to: Say', {
        x = x + PAD,
        y = y + LINE_H * 5,
        size = 11,
        r = 255,
        g = 200,
        b = 160,
    })

    elements.tell = make_text('Tell target: (//kb tell <name>)', {
        x = x + PAD,
        y = y + LINE_H * 6,
        size = 10,
        r = 180,
        g = 180,
        b = 200,
    })

    elements.status = make_text('Status: ready', {
        x = x + PAD,
        y = y + LINE_H * 7,
        size = 10,
        r = 160,
        g = 255,
        b = 160,
    })

    rebuild_click_map()
    created = true
end

local function apply_visibility(show)
    if not created then
        return
    end
    for _, el in pairs(elements) do
        if el then
            if show then
                el:show()
            else
                el:hide()
            end
        end
    end
    -- Hide tell line when channel is not tell (refresh handles text; visibility here is coarse)
end

function panel.bind_actions(action_table)
    actions = action_table or {}
end

function panel.set_pos(x, y)
    if settings_ref then
        settings_ref.pos_x = x
        settings_ref.pos_y = y
    end
    if not created then
        return
    end
    if elements.root then
        elements.root:pos(x, y)
    end
    local offsets = {
        title = 2,
        auto = LINE_H * 1,
        lang = LINE_H * 2,
        compose = LINE_H * 3,
        buttons = LINE_H * 4,
        channel = LINE_H * 5,
        tell = LINE_H * 6,
        status = LINE_H * 7,
    }
    for name, oy in pairs(offsets) do
        if elements[name] then
            elements[name]:pos(x + PAD, y + oy)
        end
    end
end

function panel.get_root()
    return elements.root
end

function panel.get_click_map()
    return click_map
end

function panel.is_visible()
    return visible
end

function panel.refresh(settings, state)
    settings_ref = settings or settings_ref
    state_ref = state or state_ref
    if not visible or not texts then
        return
    end
    ensure_created()

    local s = settings_ref or {}
    local st = state_ref or {}

    local auto_on = s.auto_translate and true or false
    elements.auto:text((auto_on and '[x]' or '[ ]') .. ' Auto-Translate Incoming')

    local lang = (s.language or 'ja'):lower()
    elements.lang:text('Language: ' .. controls.lang_name(lang) .. ' (' .. lang .. ')')

    local compose = st.compose_buffer or ''
    if compose == '' then
        elements.compose:text('Compose: (empty — //kb compose <text>)')
    else
        local preview = compose
        if #preview > 60 then
            preview = preview:sub(1, 57) .. '...'
        end
        elements.compose:text('Compose: ' .. preview)
    end

    -- Green translate + red utility hint via label text
    elements.buttons:text('[Translate & Send]  [Copy]  [Paste]  [Clear]')
    if elements.buttons.color then
        elements.buttons:color(100, 220, 100)
    end

    local ch = (s.send_channel or 'say'):lower()
    elements.channel:text('Send to: ' .. controls.channel_label(ch) .. '  (click to cycle)')

    if ch == 'tell' then
        local tgt = st.tell_target or ''
        if tgt == '' then
            elements.tell:text('Tell target: (set with //kb tell <name>)')
        else
            elements.tell:text('Tell target: ' .. tgt)
        end
        elements.tell:show()
    else
        elements.tell:text('')
        elements.tell:hide()
    end

    local status = st.status_message or ''
    if status == '' then
        elements.status:text('Status: ready')
    else
        elements.status:text('Status: ' .. status)
    end

    -- Keep positions in sync
    local x, y = base_pos()
    panel.set_pos(x, y)
end

function panel.show(settings, state)
    settings_ref = settings or settings_ref
    state_ref = state or state_ref
    if not texts then
        visible = true
        return
    end
    ensure_created()
    visible = true
    apply_visibility(true)
    panel.refresh(settings_ref, state_ref)
end

function panel.hide()
    visible = false
    apply_visibility(false)
end

function panel.destroy()
    destroy_elements()
    visible = false
end

return panel
