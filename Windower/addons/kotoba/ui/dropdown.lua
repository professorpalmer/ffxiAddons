--[[
    Lightweight dropdown for Windower 4 (texts only — no GUI-lib textures).

    Click the closed bar → expand option list under it → click an option.
    Click elsewhere / Escape via panel → close.
]]

local texts_ok, texts = pcall(require, 'texts')
if not texts_ok then
    texts = nil
end

local dropdown = {}

local function make_text(label, opts)
    opts = opts or {}
    local cfg = {
        pos = { x = opts.x or 0, y = opts.y or 0 },
        bg = {
            alpha = opts.bg_alpha or 0,
            red = opts.bg_r or 24,
            green = opts.bg_g or 28,
            blue = opts.bg_b or 40,
            visible = (opts.bg_alpha or 0) > 0,
        },
        flags = { bold = opts.bold or false, italic = false, draggable = false },
        padding = opts.padding or 3,
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

--[[
    Create a dropdown controller.
    opts = {
      x, y, width,
      options = { { id='ja', label='Japanese' }, ... },
      selected = 'ja',
      on_select = function(id) end,
      closed_prefix = 'Language',
    }
]]
function dropdown.new(opts)
    opts = opts or {}
    local d = {
        x = opts.x or 0,
        y = opts.y or 0,
        width = opts.width or 200,
        options = opts.options or {},
        selected = opts.selected,
        on_select = opts.on_select,
        on_open = opts.on_open,
        closed_prefix = opts.closed_prefix or '',
        open = false,
        row_h = 18,
        bar = nil,
        items = {},
        created = false,
    }

    local function label_for(id)
        for _, opt in ipairs(d.options) do
            if opt.id == id then
                return opt.label
            end
        end
        return id or '?'
    end

    local function closed_text()
        local pref = d.closed_prefix
        if pref ~= '' then
            return pref .. '  [ ' .. label_for(d.selected) .. '  ▾ ]'
        end
        return '[ ' .. label_for(d.selected) .. '  ▾ ]'
    end

    function d:ensure()
        if self.created or not texts then
            return
        end
        self.bar = make_text(closed_text(), {
            x = self.x, y = self.y,
            bg_alpha = 200, bg_r = 32, bg_g = 48, bg_b = 72,
            size = 11, r = 220, g = 235, b = 255, padding = 4,
        })
        self.items = {}
        self.created = true
    end

    local function destroy_items(self)
        for _, it in ipairs(self.items) do
            if it.el and it.el.destroy then
                pcall(function() it.el:destroy() end)
            elseif it.el and it.el.hide then
                pcall(function() it.el:hide() end)
            end
        end
        self.items = {}
    end

    -- Recreate option rows on open so they draw above other panel texts
    local function build_items(self)
        destroy_items(self)
        for i, opt in ipairs(self.options) do
            local item = make_text('  ' .. opt.label, {
                x = self.x,
                y = self.y + self.row_h * i,
                bg_alpha = 240, bg_r = 14, bg_g = 18, bg_b = 28,
                size = 11, r = 210, g = 220, b = 230, padding = 3,
            })
            self.items[i] = { el = item, id = opt.id, label = opt.label }
        end
        self:set_selected(self.selected)
    end

    function d:set_pos(x, y)
        self.x, self.y = x, y
        if not self.created then return end
        self.bar:pos(x, y)
        for i, it in ipairs(self.items) do
            it.el:pos(x, y + self.row_h * i)
        end
    end

    function d:set_selected(id)
        self.selected = id
        if self.bar then
            self.bar:text(closed_text())
        end
        for _, it in ipairs(self.items) do
            if it.id == id then
                it.el:text('  › ' .. it.label)
                if it.el.color then it.el:color(120, 220, 160) end
            else
                it.el:text('  ' .. it.label)
                if it.el.color then it.el:color(210, 220, 230) end
            end
        end
    end

    function d:show_bar()
        self:ensure()
        if self.bar then self.bar:show() end
    end

    function d:hide_all()
        self.open = false
        destroy_items(self)
        if self.bar then self.bar:hide() end
    end

    function d:close()
        self.open = false
        destroy_items(self)
        if self.bar then
            self.bar:text(closed_text())
            self.bar:show()
        end
    end

    function d:toggle()
        if self.open then
            self:close()
        else
            if self.on_open then
                self.on_open()
            end
            self.open = true
            if self.bar then
                self.bar:text((self.closed_prefix ~= '' and (self.closed_prefix .. '  ') or '') .. '[ ' .. label_for(self.selected) .. '  ▴ ]')
            end
            build_items(self)
            for _, it in ipairs(self.items) do
                it.el:show()
            end
        end
    end

    function d:destroy()
        destroy_items(self)
        if self.bar and self.bar.destroy then pcall(function() self.bar:destroy() end) end
        self.bar = nil
        self.created = false
        self.open = false
    end

    -- Returns true if click was consumed
    function d:handle_click(abs_x, abs_y)
        if not self.created or not self.bar then
            return false
        end
        local bx, by = 0, 0
        if texts.pos then
            bx, by = texts.pos(self.bar)
        elseif self.bar.pos then
            bx, by = self.bar:pos()
        else
            bx, by = self.x, self.y
        end

        -- Hit closed/open bar
        if abs_x >= bx and abs_x <= bx + self.width and abs_y >= by and abs_y <= by + self.row_h then
            self:toggle()
            return true
        end

        if self.open then
            for i, it in ipairs(self.items) do
                local iy = by + self.row_h * i
                if abs_x >= bx and abs_x <= bx + self.width and abs_y >= iy and abs_y <= iy + self.row_h then
                    self.selected = it.id
                    self:close()
                    if self.on_select then
                        self.on_select(it.id)
                    end
                    return true
                end
            end
            -- Miss while open: close, but do not swallow the click (other controls may want it)
            self:close()
            return false
        end
        return false
    end

    function d:expanded_height()
        if self.open then
            return self.row_h * (1 + #self.options)
        end
        return self.row_h
    end

    return d
end

return dropdown
