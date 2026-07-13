--[[
    Kotoba UI mouse handling (Wave 2)

    Click / drag patterns adapted from ruptchat mouse_events.lua
    (https://github.com/erupt321/ruptchat) — do not port full ruptchat.
]]

local mouse = {}

local texts_ok, texts = pcall(require, 'texts')
if not texts_ok then
    texts = nil
end

-- panel module reference + optional on_drag_end callback
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

        local pos_x, pos_y = 0, 0
        if texts.pos then
            pos_x, pos_y = texts.pos(root)
        elseif root.pos then
            pos_x, pos_y = root:pos()
        end

        -- 0 = move (drag follow)
        if eventtype == 0 then
            if left_clicked then
                return true
            end
            if dragged then
                local new_x = x - dragged.x
                local new_y = y - dragged.y
                panel_ref.set_pos(new_x, new_y)
                return true
            end
            if hovered then
                return true
            end
            return

        -- 1 = left click down
        elseif eventtype == 1 then
            if hovered then
                local region = hit_test(panel_ref.get_click_map(), pos_x, pos_y, x, y)
                if region and region.action then
                    region.action()
                    left_clicked = true
                    return true
                end
                -- Title-bar / background drag (ruptchat-style)
                dragged = { x = x - pos_x, y = y - pos_y }
                return true
            end
            return

        -- 2 = left click up
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
            if hovered then
                return true
            end
            return
        end
    end)
end

return mouse
