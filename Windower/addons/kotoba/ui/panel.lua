--[[
    Kotoba UI panel — clearer field chrome for Windower 4 texts

    Visual hierarchy:
      Title
      toggles
      COMPOSE box (shaded)  ← obvious type-here
      action buttons
      channel
      TELL box (shaded, when tell)
      status + typing hint
]]

local controls = require('ui/controls')

local texts_ok, texts = pcall(require, 'texts')
if not texts_ok then
    texts = nil
end

local panel = {}

local LINE_H = 20
local PAD = 8
local PANEL_W = 460
local FIELD_PAD = 4

local visible = false
local created = false
local actions = {}
local settings_ref = nil
local state_ref = nil

local elements = {}
local click_map = {}

-- Row layout (y offsets from panel top, after padding)
-- 0 title, 1 auto, 2 lang, 3 compose label, 4 compose field,
-- 5 buttons, 6 channel, 7 tell label, 8 tell field, 9 status, 10 hint
local ROWS = {
    title = 0,
    auto = 1,
    lang = 2,
    compose_label = 3,
    compose = 4,
    buttons = 5,
    channel = 6,
    tell_label = 7,
    tell = 8,
    status = 9,
    hint = 10,
}

local ROOT_LINES = 12

local function make_text(label, opts)
    opts = opts or {}
    local cfg = {
        pos = { x = opts.x or 0, y = opts.y or 0 },
        bg = {
            alpha = opts.bg_alpha or 0,
            red = opts.bg_r or 20,
            green = opts.bg_g or 20,
            blue = opts.bg_b or 30,
            visible = (opts.bg_alpha or 0) > 0,
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
    return (s and s.pos_x) or 80, (s and s.pos_y) or 120
end

local function row_y(row)
    return LINE_H * row
end

local function rebuild_click_map()
    click_map = {}
    local function add(id, row, fn_name, height)
        height = height or 1
        table.insert(click_map, {
            id = id,
            x_start = PAD,
            x_end = PANEL_W - PAD,
            y_start = row_y(row),
            y_end = row_y(row + height),
            action = function()
                if actions[fn_name] then
                    actions[fn_name]()
                end
            end,
        })
    end

    add('auto', ROWS.auto, 'toggle_auto')
    add('lang', ROWS.lang, 'cycle_lang')
    -- Label + shaded field both focus compose
    add('compose_label', ROWS.compose_label, 'focus_compose')
    add('compose', ROWS.compose, 'focus_compose')

    local btn_y0 = row_y(ROWS.buttons)
    local btn_y1 = row_y(ROWS.buttons + 1)
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

    add('channel', ROWS.channel, 'cycle_channel')
    add('tell_label', ROWS.tell_label, 'focus_tell')
    add('tell', ROWS.tell, 'focus_tell')
end

local function blank_root()
    local lines = {}
    for _ = 1, ROOT_LINES do
        table.insert(lines, string.rep(' ', 56))
    end
    return table.concat(lines, '\n')
end

local function ensure_created()
    if created or not texts then
        return
    end

    local x, y = base_pos()

    elements.root = make_text(blank_root(), {
        x = x,
        y = y,
        bg_alpha = 210,
        bg_r = 12,
        bg_g = 14,
        bg_b = 22,
        bg_visible = true,
        size = 11,
        r = 12,
        g = 14,
        b = 22,
        padding = PAD,
    })

    elements.title = make_text('Kotoba v2.0 - Translation Assistant', {
        x = x + PAD,
        y = y + row_y(ROWS.title) + 2,
        size = 12,
        bold = true,
        r = 255,
        g = 220,
        b = 100,
    })

    elements.auto = make_text('[ ] Auto-Translate Incoming', {
        x = x + PAD,
        y = y + row_y(ROWS.auto),
        size = 11,
        r = 180,
        g = 210,
        b = 255,
    })

    elements.lang = make_text('Language: Japanese (ja)  [click to cycle]', {
        x = x + PAD,
        y = y + row_y(ROWS.lang),
        size = 11,
        r = 180,
        g = 240,
        b = 180,
    })

    elements.compose_label = make_text('COMPOSE  —  click box, then type', {
        x = x + PAD,
        y = y + row_y(ROWS.compose_label),
        size = 10,
        bold = true,
        r = 140,
        g = 160,
        b = 190,
    })

    -- Shaded field = the actual type-in area
    elements.compose = make_text('  (empty)', {
        x = x + PAD,
        y = y + row_y(ROWS.compose),
        size = 11,
        r = 240,
        g = 240,
        b = 245,
        bg_alpha = 160,
        bg_r = 30,
        bg_g = 40,
        bg_b = 60,
        padding = FIELD_PAD,
    })

    elements.buttons = make_text('[Translate & Send]   [Copy]   [Paste]   [Clear]', {
        x = x + PAD,
        y = y + row_y(ROWS.buttons),
        size = 10,
        bold = true,
        r = 100,
        g = 230,
        b = 120,
    })

    elements.channel = make_text('Send to: Say  [click to cycle]', {
        x = x + PAD,
        y = y + row_y(ROWS.channel),
        size = 11,
        r = 255,
        g = 190,
        b = 140,
    })

    elements.tell_label = make_text('TELL NAME  —  click box, then type', {
        x = x + PAD,
        y = y + row_y(ROWS.tell_label),
        size = 10,
        bold = true,
        r = 140,
        g = 160,
        b = 190,
    })

    elements.tell = make_text('  (empty)', {
        x = x + PAD,
        y = y + row_y(ROWS.tell),
        size = 11,
        r = 240,
        g = 240,
        b = 245,
        bg_alpha = 160,
        bg_r = 30,
        bg_g = 40,
        bg_b = 60,
        padding = FIELD_PAD,
    })

    elements.status = make_text('Status: ready', {
        x = x + PAD,
        y = y + row_y(ROWS.status),
        size = 10,
        r = 140,
        g = 230,
        b = 150,
    })

    elements.hint = make_text('', {
        x = x + PAD,
        y = y + row_y(ROWS.hint),
        size = 10,
        bold = true,
        r = 255,
        g = 210,
        b = 90,
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
        title = row_y(ROWS.title) + 2,
        auto = row_y(ROWS.auto),
        lang = row_y(ROWS.lang),
        compose_label = row_y(ROWS.compose_label),
        compose = row_y(ROWS.compose),
        buttons = row_y(ROWS.buttons),
        channel = row_y(ROWS.channel),
        tell_label = row_y(ROWS.tell_label),
        tell = row_y(ROWS.tell),
        status = row_y(ROWS.status),
        hint = row_y(ROWS.hint),
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

local function set_field_active(el, active)
    if not el then
        return
    end
    if active then
        if el.bg_color then
            el:bg_color(50, 70, 40)
        end
        if el.bg_alpha then
            el:bg_alpha(200)
        end
        if el.color then
            el:color(255, 245, 120)
        end
    else
        if el.bg_color then
            el:bg_color(30, 40, 60)
        end
        if el.bg_alpha then
            el:bg_alpha(160)
        end
        if el.color then
            el:color(240, 240, 245)
        end
    end
end

local function truncate(s, n)
    if not s or s == '' then
        return ''
    end
    if #s > n then
        return s:sub(1, n - 3) .. '...'
    end
    return s
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
    local mode = st.input_mode

    local auto_on = s.auto_translate and true or false
    elements.auto:text((auto_on and '[x]' or '[ ]') .. ' Auto-Translate Incoming  [click]')

    local lang = (s.language or 'ja'):lower()
    elements.lang:text('Language: ' .. controls.lang_name(lang) .. ' (' .. lang .. ')  [click to cycle]')

    -- Compose field
    local compose = st.compose_buffer or ''
    if mode == 'compose' then
        elements.compose_label:text('COMPOSE  ▶  TYPING NOW  (Enter = lock)')
        local preview = compose ~= '' and compose or '…'
        elements.compose:text('  ' .. truncate(preview, 48) .. '_')
        set_field_active(elements.compose, true)
    else
        elements.compose_label:text('COMPOSE  —  click shaded box, then type')
        if compose == '' then
            elements.compose:text('  (click here to type your message)')
        else
            elements.compose:text('  ' .. truncate(compose, 50))
        end
        set_field_active(elements.compose, false)
    end

    elements.buttons:text('[Translate & Send]   [Copy]   [Paste]   [Clear]')

    local ch = (s.send_channel or 'say'):lower()
    elements.channel:text('Send to: ' .. controls.channel_label(ch) .. '  [click to cycle]')

    if ch == 'tell' then
        local tgt = st.tell_target or ''
        if mode == 'tell' then
            elements.tell_label:text('TELL NAME  ▶  TYPING NOW  (Enter = lock)')
            local live = tgt ~= '' and tgt or '…'
            elements.tell:text('  ' .. truncate(live, 40) .. '_')
            set_field_active(elements.tell, true)
        else
            elements.tell_label:text('TELL NAME  —  click shaded box, then type')
            if tgt == '' then
                elements.tell:text('  (click here to type player name)')
            else
                elements.tell:text('  ' .. tgt)
            end
            set_field_active(elements.tell, false)
        end
        elements.tell_label:show()
        elements.tell:show()
    else
        elements.tell_label:text('')
        elements.tell:text('')
        elements.tell_label:hide()
        elements.tell:hide()
    end

    local status = st.status_message or ''
    elements.status:text(status == '' and 'Status: ready' or ('Status: ' .. status))

    if mode == 'compose' or mode == 'tell' then
        elements.hint:text('>> Typing in Kotoba — Enter locks · Esc cancels')
        elements.hint:show()
    else
        elements.hint:text('')
        elements.hint:hide()
    end

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
    -- Force recreate so layout upgrades apply after //lua reload
    if created then
        destroy_elements()
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
