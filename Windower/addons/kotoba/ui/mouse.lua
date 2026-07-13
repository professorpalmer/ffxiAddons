--[[
    Kotoba UI mouse handling

    Dropdowns are hit-tested first (they may extend below the panel root).
    Click / drag patterns adapted from ruptchat mouse_events.lua.
]]

local mouse = {}

local texts_ok, texts = pcall(require, 'texts')
if not texts_ok then
    texts = nil
end

local panel_ref = nil
local on_drag_end = nil

local dragged = nil
local left_clicked = false

local function hit_test(regions, panel_x, panel_y, x, y)
    if not regions then
        return nil
    end
    for _, region in ipairs(regions) do
        if x >= panel_x + region.x_start
            and x <= panel_x + region.x_end
            and y >= panel_y + region.y_start
            and y <= panel_y + region.y_end then
            return region
        end
    end
    return nil
end

local function try_dropdowns(x, y)
    if not panel_ref or not panel_ref.get_dropdowns then
        return false
    end
    local dds = panel_ref.get_dropdowns()
    if not dds then
        return false
    end
    -- Prefer an already-open dropdown first
    for _, dd in ipairs(dds) do
        if dd and dd.open and dd.handle_click and dd:handle_click(x, y) then
            return true
        end
    end
    for _, dd in ipairs(dds) do
        if dd and dd.handle_click and dd:handle_click(x, y) then
            return true
        end
    end
    return false
end

function mouse.register(panel, drag_end_cb)
    panel_ref = panel
    on_drag_end = drag_end_cb

    if not texts then
        return
    end

    windower.register_event('mouse', function(eventtype, x, y, delta, blocked)
        if blocked or not panel_ref or not panel_ref.is_visible() then
            return
        end

        local root = panel_ref.get_root()
        if not root then
            return
        end

        local hovered = false
        if texts.hover then
            hovered = texts.hover(root, x, y)
        elseif root.hover then
            hovered = root:hover(x, y)
        end

        -- Dropdown lists can extend past root; still treat as interactive
        local dd_open = false
        if panel_ref.get_dropdowns then
            for _, dd in ipairs(panel_ref.get_dropdowns() or {}) do
                if dd and dd.open then
                    dd_open = true
                    break
                end
            end
        end

        local pos_x, pos_y = 0, 0
        if texts.pos then
            pos_x, pos_y = texts.pos(root)
        elseif root.pos then
            pos_x, pos_y = root:pos()
        end

        if eventtype == 0 then
            if left_clicked then
                return true
            end
            if dragged then
                panel_ref.set_pos(x - dragged.x, y - dragged.y)
                return true
            end
            if hovered or dd_open then
                return true
            end
            return

        elseif eventtype == 1 then
            if try_dropdowns(x, y) then
                left_clicked = true
                return true
            end
            if hovered then
                if panel_ref.close_dropdowns then
                    panel_ref.close_dropdowns()
                end
                local region = hit_test(panel_ref.get_click_map(), pos_x, pos_y, x, y)
                if region and region.action then
                    region.action()
                    left_clicked = true
                    return true
                end
                dragged = { x = x - pos_x, y = y - pos_y }
                return true
            end
            if panel_ref.close_dropdowns then
                panel_ref.close_dropdowns()
            end
            return

        elseif eventtype == 2 then
            if left_clicked then
                left_clicked = false
                return true
            end
            if dragged then
                dragged = nil
                if on_drag_end then
                    on_drag_end()
                end
                return true
            end
            if hovered or dd_open then
                return true
            end
            return
        end
    end)
end

return mouse
