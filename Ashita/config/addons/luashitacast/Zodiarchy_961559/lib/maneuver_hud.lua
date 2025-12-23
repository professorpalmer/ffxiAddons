local imgui = require('imgui');

local M = {};

local state = {
    visible = { true },
    get_rotation = nil,
    get_auto = nil,
    window_pos = { 50, 200 },
    window_size = { 300, 90 },
};

function M.init(providers)
    state.get_rotation = providers and providers.get_rotation or nil;
    state.get_auto = providers and providers.get_auto or nil;
end

function M.toggle()
    state.visible[1] = not state.visible[1];
end

function M.get_visible()
    return state.visible[1];
end

function M.set_visible(flag)
    state.visible[1] = flag and true or false;
end

local function safe_str(val, fallback)
    if val == nil then return fallback; end
    return tostring(val);
end

function M.render()
    if not state.visible[1] then
        return;
    end

    local rotation = state.get_rotation and state.get_rotation() or 'n/a';
    local auto = state.get_auto and state.get_auto() or false;
    local cond = imgui.ImGuiCond_FirstUseEver or 8;
    imgui.SetNextWindowSize(state.window_size, cond);
    imgui.SetNextWindowPos(state.window_pos, cond);

    if imgui.Begin('PUP Auto', state.visible) then
        imgui.Text('Auto Maneuver: ');
        imgui.SameLine();
        imgui.TextColored(auto and {0.2, 1.0, 0.2, 1.0} or {1.0, 0.3, 0.3, 1.0}, auto and 'ON' or 'OFF');

        imgui.Text('Rotation: ');
        imgui.SameLine();
        -- Show without the word "Maneuver" repeated
        local compact = rotation
            :gsub('%s*Maneuver', '')
            :gsub('%s+|%s+', ' | ')
            :gsub('^%s+', '')
            :gsub('%s+$', '');
        imgui.Text(compact);
    end
    imgui.End();
end

return M;

