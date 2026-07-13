--[[
    Kotoba UI panel v2.1.0 — polished Windower 4 texts chrome

    - Dropdowns for Language / Send-to (not click-to-cycle)
    - Clear shaded input fields
    - Quieter labels, stronger action row
]]

local controls = require('ui/controls')
local dropdown = require('ui/dropdown')

local texts_ok, texts = pcall(require, 'texts')
if not texts_ok then
    texts = nil
end

local panel = {}

local LINE_H = 22
local PAD = 10
local PANEL_W = 480
local FIELD_PAD = 5

local visible = false
local created = false
local actions = {}
local settings_ref = nil
local state_ref = nil

local elements = {}
local click_map = {}
local lang_dd = nil
local channel_dd = nil

-- Rows (compact when tell hidden)
local ROWS = {
    title = 0,
    auto = 1,
    lang = 2,
    sep1 = 3,
    compose_label = 4,
    compose = 5,
    buttons = 6,
    sep2 = 7,
    channel = 8,
    tell_label = 9,
    tell = 10,
    status = 11,
    hint = 12,
}

local ROOT_LINES = 14

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
    if t.left_draggable then t:left_draggable(false) end
    if t.right_draggable then t:right_draggable(false) end
    return t
end

local function destroy_elements()
    if lang_dd then lang_dd:destroy(); lang_dd = nil end
    if channel_dd then channel_dd:destroy(); channel_dd = nil end
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
    return (s and s.pos_x) or 80, (s and s.pos_y) or 100
end

local function row_y(row)
    return LINE_H * row
end

local function rebuild_click_map()
    click_map = {}
    local function add(id, row, fn_name)
        table.insert(click_map, {
            id = id,
            x_start = PAD,
            x_end = PANEL_W - PAD,
            y_start = row_y(row),
            y_end = row_y(row + 1),
            action = function()
                if actions[fn_name] then
                    actions[fn_name]()
                end
            end,
        })
    end

    add('auto', ROWS.auto, 'toggle_auto')
    -- lang/channel handled by dropdowns (hit-tested first in mouse.lua)
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

    add('tell', ROWS.tell, 'focus_tell')
end

local function blank_root()
    local lines = {}
    for _ = 1, ROOT_LINES do
        table.insert(lines, string.rep(' ', 58))
    end
    return table.concat(lines, '\n')
end

local function build_lang_options()
    local opts = {}
    for _, code in ipairs(controls.LANG_CODES) do
        table.insert(opts, { id = code, label = controls.lang_name(code) .. '  (' .. code .. ')' })
    end
    return opts
end

local function build_channel_options()
    local opts = {}
    for _, ch in ipairs(controls.CHANNELS) do
        table.insert(opts, { id = ch, label = controls.channel_label(ch) })
    end
    return opts
end

local function ensure_created()
    if created or not texts then
        return
    end

    local x, y = base_pos()

    elements.root = make_text(blank_root(), {
        x = x, y = y,
        bg_alpha = 220, bg_r = 10, bg_g = 12, bg_b = 20,
        size = 11, r = 10, g = 12, b = 20, padding = PAD,
    })

    elements.title = make_text('Kotoba', {
        x = x + PAD, y = y + 4,
        size = 13, bold = true, r = 255, g = 214, b = 90,
    })

    elements.subtitle = make_text('v2.1.0  ·  Translation', {
        x = x + 78, y = y + 7,
        size = 10, r = 140, g = 155, b = 180,
    })

    elements.auto = make_text('[x]  Auto-translate incoming', {
        x = x + PAD, y = y + row_y(ROWS.auto),
        size = 11, r = 170, g = 200, b = 240,
    })

    lang_dd = dropdown.new({
        x = x + PAD,
        y = y + row_y(ROWS.lang),
        width = PANEL_W - PAD * 2,
        options = build_lang_options(),
        selected = (settings_ref and settings_ref.language) or 'ja',
        closed_prefix = 'Language',
        on_open = function()
            if channel_dd then channel_dd:close() end
        end,
        on_select = function(id)
            if actions.set_lang then
                actions.set_lang(id)
            end
        end,
    })
    lang_dd:ensure()
    lang_dd:show_bar()

    elements.sep1 = make_text(string.rep('─', 42), {
        x = x + PAD, y = y + row_y(ROWS.sep1),
        size = 9, r = 50, g = 60, b = 80,
    })

    elements.compose_label = make_text('MESSAGE', {
        x = x + PAD, y = y + row_y(ROWS.compose_label),
        size = 9, bold = true, r = 120, g = 140, b = 170,
    })

    elements.compose = make_text('  (click to type)', {
        x = x + PAD, y = y + row_y(ROWS.compose),
        size = 11, r = 245, g = 245, b = 250,
        bg_alpha = 180, bg_r = 28, bg_g = 38, bg_b = 58, padding = FIELD_PAD,
    })

    -- Four equal-width button slots (must match rebuild_click_map quarters)
    local btn_w = (PANEL_W - PAD * 2) / 4
    local btn_y = y + row_y(ROWS.buttons)
    local btn_defs = {
        { key = 'btn_send', label = '  Send  ', r = 90, g = 220, b = 130 },
        { key = 'btn_copy', label = '  Copy  ', r = 170, g = 200, b = 230 },
        { key = 'btn_paste', label = '  Paste ', r = 170, g = 200, b = 230 },
        { key = 'btn_clear', label = '  Clear ', r = 230, g = 160, b = 140 },
    }
    for i, def in ipairs(btn_defs) do
        elements[def.key] = make_text(def.label, {
            x = x + PAD + (i - 1) * btn_w,
            y = btn_y,
            size = 10, bold = true, r = def.r, g = def.g, b = def.b,
            bg_alpha = 150, bg_r = 20, bg_g = 36, bg_b = 28, padding = 4,
        })
    end

    elements.sep2 = make_text(string.rep('─', 42), {
        x = x + PAD, y = y + row_y(ROWS.sep2),
        size = 9, r = 50, g = 60, b = 80,
    })

    channel_dd = dropdown.new({
        x = x + PAD,
        y = y + row_y(ROWS.channel),
        width = PANEL_W - PAD * 2,
        options = build_channel_options(),
        selected = (settings_ref and settings_ref.send_channel) or 'say',
        closed_prefix = 'Send to',
        on_open = function()
            if lang_dd then lang_dd:close() end
        end,
        on_select = function(id)
            if actions.set_channel then
                actions.set_channel(id)
            end
        end,
    })
    channel_dd:ensure()
    channel_dd:show_bar()

    elements.tell_label = make_text('TELL TARGET', {
        x = x + PAD, y = y + row_y(ROWS.tell_label),
        size = 9, bold = true, r = 120, g = 140, b = 170,
    })

    elements.tell = make_text('  (click to type name)', {
        x = x + PAD, y = y + row_y(ROWS.tell),
        size = 11, r = 245, g = 245, b = 250,
        bg_alpha = 180, bg_r = 28, bg_g = 38, bg_b = 58, padding = FIELD_PAD,
    })

    elements.status = make_text('Ready', {
        x = x + PAD, y = y + row_y(ROWS.status),
        size = 10, r = 130, g = 210, b = 150,
    })

    elements.hint = make_text('', {
        x = x + PAD, y = y + row_y(ROWS.hint),
        size = 9, bold = true, r = 255, g = 200, b = 90,
    })

    rebuild_click_map()
    created = true
end

local function apply_visibility(show)
    if not created then return end
    for name, el in pairs(elements) do
        if el then
            if show then el:show() else el:hide() end
        end
    end
    if show then
        if lang_dd then lang_dd:show_bar(); lang_dd:close() end
        if channel_dd then channel_dd:show_bar(); channel_dd:close() end
    else
        if lang_dd then lang_dd:hide_all() end
        if channel_dd then channel_dd:hide_all() end
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
    if not created then return end
    if elements.root then elements.root:pos(x, y) end
    local offsets = {
        title = 4,
        subtitle = 6,
        auto = row_y(ROWS.auto),
        sep1 = row_y(ROWS.sep1),
        compose_label = row_y(ROWS.compose_label),
        compose = row_y(ROWS.compose),
        sep2 = row_y(ROWS.sep2),
        tell_label = row_y(ROWS.tell_label),
        tell = row_y(ROWS.tell),
        status = row_y(ROWS.status),
        hint = row_y(ROWS.hint),
    }
    for name, oy in pairs(offsets) do
        if elements[name] then
            if name == 'subtitle' then
                elements[name]:pos(x + 78, y + oy)
            else
                elements[name]:pos(x + PAD, y + oy)
            end
        end
    end
    local btn_w = (PANEL_W - PAD * 2) / 4
    local btn_y = y + row_y(ROWS.buttons)
    local btn_keys = { 'btn_send', 'btn_copy', 'btn_paste', 'btn_clear' }
    for i, key in ipairs(btn_keys) do
        if elements[key] then
            elements[key]:pos(x + PAD + (i - 1) * btn_w, btn_y)
        end
    end
    if lang_dd then lang_dd:set_pos(x + PAD, y + row_y(ROWS.lang)) end
    if channel_dd then channel_dd:set_pos(x + PAD, y + row_y(ROWS.channel)) end
end

function panel.get_root()
    return elements.root
end

function panel.get_click_map()
    return click_map
end

function panel.get_dropdowns()
    return { lang_dd, channel_dd }
end

function panel.is_visible()
    return visible
end

function panel.close_dropdowns()
    if lang_dd then lang_dd:close() end
    if channel_dd then channel_dd:close() end
end

local function set_field_active(el, active)
    if not el then return end
    if active then
        if el.bg_color then el:bg_color(48, 72, 36) end
        if el.bg_alpha then el:bg_alpha(210) end
        if el.color then el:color(255, 245, 130) end
    else
        if el.bg_color then el:bg_color(28, 38, 58) end
        if el.bg_alpha then el:bg_alpha(180) end
        if el.color then el:color(245, 245, 250) end
    end
end

local function truncate(s, n)
    if not s or s == '' then return '' end
    if #s > n then return s:sub(1, n - 3) .. '...' end
    return s
end

function panel.refresh(settings, state)
    settings_ref = settings or settings_ref
    state_ref = state or state_ref
    if not visible or not texts then return end
    ensure_created()

    local s = settings_ref or {}
    local st = state_ref or {}
    local mode = st.input_mode

    local auto_on = s.auto_translate and true or false
    elements.auto:text((auto_on and '[x]' or '[ ]') .. '  Auto-translate incoming')

    if lang_dd then
        lang_dd:set_selected((s.language or 'ja'):lower())
    end
    if channel_dd then
        channel_dd:set_selected((s.send_channel or 'say'):lower())
    end

    local compose = st.compose_buffer or ''
    if mode == 'compose' then
        elements.compose_label:text('MESSAGE  ·  typing…  (Enter = lock)')
        elements.compose:text('  ' .. truncate(compose ~= '' and compose or '…', 48) .. '_')
        set_field_active(elements.compose, true)
    else
        elements.compose_label:text('MESSAGE')
        if compose == '' then
            elements.compose:text('  (click to type your message)')
        else
            elements.compose:text('  ' .. truncate(compose, 52))
        end
        set_field_active(elements.compose, false)
    end

    local ch = (s.send_channel or 'say'):lower()
    if ch == 'tell' then
        local tgt = st.tell_target or ''
        if mode == 'tell' then
            elements.tell_label:text('TELL TARGET  ·  typing…  (Enter = lock)')
            elements.tell:text('  ' .. truncate(tgt ~= '' and tgt or '…', 40) .. '_')
            set_field_active(elements.tell, true)
        else
            elements.tell_label:text('TELL TARGET')
            if tgt == '' then
                elements.tell:text('  (click to type player name)')
            else
                elements.tell:text('  ' .. tgt)
            end
            set_field_active(elements.tell, false)
        end
        elements.tell_label:show()
        elements.tell:show()
    else
        elements.tell_label:hide()
        elements.tell:hide()
    end

    local status = st.status_message or ''
    elements.status:text(status == '' and 'Ready' or status)

    if mode == 'compose' or mode == 'tell' then
        elements.hint:text('Keys isolated from the game  ·  Enter lock  ·  Esc cancel')
        elements.hint:show()
    else
        elements.hint:text('')
        elements.hint:hide()
    end

    local px, py = base_pos()
    panel.set_pos(px, py)
end

function panel.show(settings, state)
    settings_ref = settings or settings_ref
    state_ref = state or state_ref
    if not texts then
        visible = true
        return
    end
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
