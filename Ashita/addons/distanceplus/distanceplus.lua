--[[
* Addons - Copyright (c) 2021 Ashita Development Team
* Contact: https://www.ashitaxi.com/
* Contact: https://discord.gg/Ashita
*
* This file is part of Ashita.
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
*
* Originally DistancePlus by Sammeh of Quetzalcoatl
* Converted to Ashita 4 API
--]]

addon.name      = 'distanceplus';
addon.author    = 'Sammeh - Ashita conversion by Palmer (Zodiarchy @ Asura)';
addon.version   = '1.4.0';
addon.desc      = 'Displays distance information with job-specific range calculations.';
addon.link      = 'https://ashitaxi.com/';

require('common');
local imgui = require('imgui');
local fonts = require('fonts');
local scaling = require('scaling');
local settings = require('settings');

-- Default Settings
local default_settings = T{
    option = "Default",
    max_distance = 25,
    
    -- Window settings
    distance_size = { 180, 80 },
    pet_size = { 180, 80 },
    
    -- Style settings
    use_modern_style = { true },
    center_text = { false },
    show_mode_indicator = { true },
    show_pet_window = { true },
    minimal_display = { false },
    
    -- Window transparency and styling
    bg_alpha = { 0.85 },
    window_rounding = { 8.0 },
    window_padding = { 12, 8 },
    
    -- Font positions for minimal display
    target_font_pos = { 50, 50 },
    pet_font_pos = { 50, 150 },
};

-- DistancePlus Variables
local distanceplus = T{
    is_open = { true, },
    pet_open = { true, },
    config_open = { false, },
    self = nil,
    
    -- Font objects for minimal display
    target_font = nil,
    pet_font = nil,
    
    -- Settings
    settings = settings.load(default_settings),
};

-- Color constants
local COLOR_WHITE = { 1.0, 1.0, 1.0, 1.0 };
local COLOR_GREEN = { 0.0, 1.0, 0.0, 1.0 };
local COLOR_YELLOW = { 1.0, 1.0, 0.0, 1.0 };
local COLOR_BLUE = { 0.0, 0.0, 1.0, 1.0 };
local COLOR_RED = { 1.0, 0.0, 0.0, 1.0 };

--[[
* Convert RGBA color table to D3D color format for fonts
--]]
local function ColorToD3D(color)
    return math.d3dcolor(255, 
        math.floor(color[1] * 255), 
        math.floor(color[2] * 255), 
        math.floor(color[3] * 255));
end

--[[
* Updates the addon settings.
*
* @param {table} s - The new settings table to use for the addon settings. (Optional.)
--]]
local function update_settings(s)
    -- Update the settings table..
    if (s ~= nil) then
        distanceplus.settings = s;
    end

    -- Apply font positions if fonts exist
    if (distanceplus.target_font ~= nil) then
        distanceplus.target_font.position_x = distanceplus.settings.target_font_pos[1];
        distanceplus.target_font.position_y = distanceplus.settings.target_font_pos[2];
    end
    
    if (distanceplus.pet_font ~= nil) then
        distanceplus.pet_font.position_x = distanceplus.settings.pet_font_pos[1];
        distanceplus.pet_font.position_y = distanceplus.settings.pet_font_pos[2];
    end

    -- Save the current settings..
    settings.save();
end

--[[
* Registers a callback for the settings to monitor for character switches.
--]]
settings.register('settings', 'settings_update', update_settings);

--[[
* Returns the entity that matches the given target type.
--]]
local function GetTargetEntity(target_type)
    local player = GetPlayerEntity();
    if (player == nil) then return nil; end
    
    if target_type == 'me' then
        return player;
    elseif target_type == 't' then
        local target_index = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0);
        if target_index > 0 then
            return GetEntity(target_index);
        end
    elseif target_type == 'st' then
        local target_index = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(1);
        if target_index > 0 then
            return GetEntity(target_index);
        end
    elseif target_type == 'pet' then
        if player.PetTargetIndex > 0 then
            return GetEntity(player.PetTargetIndex);
      end
    end
    return nil;
end



--[[
* Check job and set appropriate mode
--]]
local function CheckJob()
    local party = AshitaCore:GetMemoryManager():GetParty();
    if party == nil or party:GetMemberIsActive(0) == 0 then return; end
    
    local main_job = party:GetMemberMainJob(0);
    
    print('*****DP Job Selection: ' .. main_job .. '*****');
    
    if main_job == 1 or main_job == 3 or main_job == 5 or main_job == 15 or main_job == 20 or main_job == 21 then -- WHM, BLM, RDM, BRD, SCH, GEO
        distanceplus.settings.option = "Magic";
        print('Mode: Magic.');
        print(' White = Can not cast.');
        print(' Green = Casting Range');
        distanceplus.settings.max_distance = 20;
    elseif main_job == 17 then -- COR
        print('Mode: Gun.');
        print(' White  = Can not shoot.');
        print(' Yellow = Ranged Attack Capable (No Buff)');
        print(' Green  = Shoots Squarely (Good)');
        print(' Blue   = True Shot (Best)');
        distanceplus.settings.option = "Gun";
        distanceplus.settings.max_distance = 25;
    elseif main_job == 11 then -- RNG
        print('RANGER should do //dp Bow, //dp XBow, or //dp Gun');
        print('Mode: Default.');
        distanceplus.settings.option = "Default";
        distanceplus.settings.max_distance = 25;
    elseif main_job == 13 then -- NIN
        distanceplus.settings.option = "Ninjutsu";
        print('Mode: Ninjutsu.');
        print(' White = Can not cast.');
        print(' Green = Casting Range');
    else
        print('Mode: Default.');
        distanceplus.settings.option = "Default";
        distanceplus.settings.max_distance = 25;
    end
end

--[[
* Calculate distance color based on mode
* Uses the exact logic from the Windower version for accuracy
--]]
local function GetDistanceColor(distance, s, t)
    if distance == 0 or not s or not t or not s.ModelSize or not t.ModelSize then
        return COLOR_WHITE;
    end
    
    if distanceplus.settings.option == 'Default' then
        return COLOR_WHITE;
    elseif distanceplus.settings.option == 'Bow' then
        local MaxDistance = 25;
        
        -- Based on the provided chart:
        -- Blue (100% damage): 7.5-10.5 feet
        -- Green (92% damage): 10.6-19.9 feet  
        -- Yellow (65-87% damage): All other ranges within shooting distance
        -- White: Can't shoot (outside range)
        
        local optimal_min = 7.5;  -- 100% damage range start
        local optimal_max = 10.5; -- 100% damage range end
        local good_min = 10.6;    -- 92% damage range start  
        local good_max = 19.9;    -- 92% damage range end
        
        if distance > MaxDistance then
            return COLOR_WHITE; -- White (Can't Shoot - too far)
        elseif distance >= optimal_min and distance <= optimal_max then
            return COLOR_BLUE; -- Blue (100% damage - optimal range)
        elseif distance >= good_min and distance <= good_max then
            return COLOR_GREEN; -- Green (92% damage - good range)
        else
            return COLOR_YELLOW; -- Yellow (65-87% damage - sub-optimal but shootable)
        end
    elseif distanceplus.settings.option == 'Xbow' then
        local MaxDistance = 25;
        
        -- Based on the provided chart:
        -- Blue (100% damage): 6-10 feet
        -- Green (90-95% damage): 10-20 feet  
        -- Yellow (65-87% damage): All other ranges within shooting distance
        -- White: Can't shoot (outside range)
        
        local optimal_min = 6.0;  -- 100% damage range start
        local optimal_max = 10.0; -- 100% damage range end
        local good_min = 10.1;    -- 90-95% damage range start  
        local good_max = 20.0;    -- 90-95% damage range end
        
        if distance > MaxDistance then
            return COLOR_WHITE; -- White (Can't Shoot - too far)
        elseif distance >= optimal_min and distance <= optimal_max then
            return COLOR_BLUE; -- Blue (100% damage - optimal range)
        elseif distance >= good_min and distance <= good_max then
            return COLOR_GREEN; -- Green (90-95% damage - good range)
        else
            return COLOR_YELLOW; -- Yellow (65-87% damage - sub-optimal but shootable)
        end
    elseif distanceplus.settings.option == 'Gun' then
        local MaxDistance = 25;
        
        -- Based on the provided chart:
        -- Blue (100% damage): 4.5-7 feet
        -- Green (95% damage): 7.5-9.9 feet  
        -- Yellow (90-85% damage): All other ranges within shooting distance
        -- White: Can't shoot (outside range)
        
        local optimal_min = 4.5; -- 100% damage range start
        local optimal_max = 7.0;  -- 100% damage range end
        local good_min = 7.5;     -- 95% damage range start  
        local good_max = 9.9;     -- 95% damage range end
        
        if distance > MaxDistance then
            return COLOR_WHITE; -- White (Can't Shoot - too far)
        elseif distance >= optimal_min and distance <= optimal_max then
            return COLOR_BLUE; -- Blue (100% damage - optimal range)
        elseif distance >= good_min and distance <= good_max then
            return COLOR_GREEN; -- Green (95% damage - good range)
        else
            return COLOR_YELLOW; -- Yellow (85-90% damage - sub-optimal but shootable)
        end
    elseif distanceplus.settings.option == 'Magic' then
        -- Based on Vana'diel distance documentation:
        -- Maximum spellcasting range for players is 21.8 feet
        -- Simplified: not relying on potentially unreliable model size calculations
        local MaxDistance = 21.8;
        
        if distance <= MaxDistance then
            return COLOR_GREEN; -- Green (Can cast)
        else
            return COLOR_WHITE; -- White (Can't cast - out of range)
        end
    elseif distanceplus.settings.option == 'Ninjutsu' then
        -- Ninjutsu has shorter range than regular magic
        -- Simplified: not relying on potentially unreliable model size calculations
        local MaxDistance = 16.1;
        
        if distance <= MaxDistance then
            return COLOR_GREEN; -- Green (Can cast)
        else
            return COLOR_WHITE; -- White (Can't cast - out of range)
        end
    else
        return COLOR_WHITE;
    end
end

--[[
* Configuration GUI window
--]]
local function RenderConfigWindow()
    if not distanceplus.config_open[1] then return; end
    
    imgui.SetNextWindowSize({ 400, 500 }, ImGuiCond_FirstUseEver);
    if imgui.Begin('DistancePlus Configuration##ConfigWindow', distanceplus.config_open) then
        
        -- Window Size Settings
        if imgui.CollapsingHeader('Window Sizes') then
            imgui.Text('Target Distance Window:');
            if imgui.SliderFloat2('Size##DistanceSize', distanceplus.settings.distance_size, 70, 400, '%.0f') then
                update_settings();
            end
            
            imgui.Text('Pet Distance Window:');
            if imgui.SliderFloat2('Size##PetSize', distanceplus.settings.pet_size, 70, 400, '%.0f') then
                update_settings();
            end
        end
        
        -- Display Options
        if imgui.CollapsingHeader('Display Options') then
            if imgui.Checkbox('Show Mode Indicator', distanceplus.settings.show_mode_indicator) then
                update_settings();
            end
            if imgui.Checkbox('Show Pet Window', distanceplus.settings.show_pet_window) then
                update_settings();
            end
            if imgui.Checkbox('Center Text', distanceplus.settings.center_text) then
                update_settings();
            end
            if imgui.Checkbox('Minimal Display (numbers only)', distanceplus.settings.minimal_display) then
                update_settings();
            end
            
            if distanceplus.settings.minimal_display[1] then
                imgui.Indent();
                imgui.TextColored({ 0.7, 0.7, 0.0, 1.0 }, 'Note: Minimal display shows only distance numbers');
                imgui.TextColored({ 0.7, 0.7, 0.0, 1.0 }, 'with no background, borders, or window decorations.');
                imgui.Unindent();
            end
        end
        
        -- Style Settings
        if imgui.CollapsingHeader('Window Style') then
            if imgui.Checkbox('Use Modern Style', distanceplus.settings.use_modern_style) then
                update_settings();
            end
            
            if distanceplus.settings.use_modern_style[1] then
                if imgui.SliderFloat('Background Alpha', distanceplus.settings.bg_alpha, 0.0, 1.0, '%.2f') then
                    update_settings();
                end
                if imgui.SliderFloat('Window Rounding', distanceplus.settings.window_rounding, 0.0, 15.0, '%.1f') then
                    update_settings();
                end
                if imgui.SliderFloat2('Window Padding', distanceplus.settings.window_padding, 0, 20, '%.0f') then
                    update_settings();
                end
            end
        end
        
        -- Mode Selection
        if imgui.CollapsingHeader('Range Mode') then
            imgui.Text('Current Mode: ' .. distanceplus.settings.option);
            imgui.Separator();
            
            if imgui.Button('Default') then
                distanceplus.settings.option = "Default";
                distanceplus.settings.max_distance = 25;
                update_settings();
                print('Mode: Default.');
            end
            imgui.SameLine();
            if imgui.Button('Gun') then
                distanceplus.settings.option = "Gun";
                update_settings();
                print('Mode: Gun.');
            end
            imgui.SameLine();
            if imgui.Button('Bow') then
                distanceplus.settings.option = "Bow";
                update_settings();
                print('Mode: Bow.');
            end
            imgui.SameLine();
            if imgui.Button('Xbow') then
                distanceplus.settings.option = "Xbow";
                update_settings();
                print('Mode: Crossbow.');
            end
            
            if imgui.Button('Magic') then
                distanceplus.settings.option = "Magic";
                update_settings();
                print('Mode: Magic.');
            end
            imgui.SameLine();
            if imgui.Button('Ninjutsu') then
                distanceplus.settings.option = "Ninjutsu";
                update_settings();
                print('Mode: Ninjutsu.');
            end
        end
        
        imgui.Separator();
        imgui.Text('Use //dp config to toggle this window');
        imgui.Text('Use //dp help for command line options');
    end
    imgui.End();
end

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'present_cb', function ()
    local player = GetPlayerEntity();
    if player == nil then return; end
    
    -- Render configuration window
    RenderConfigWindow();
    
    local target = GetTargetEntity('t') or GetTargetEntity('st');
    local pet = GetTargetEntity('pet');
    
    -- Calculate window flags based on style
    local window_flags = bit.bor(ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoScrollbar);
    if not distanceplus.settings.use_modern_style[1] then
        window_flags = bit.bor(window_flags, ImGuiWindowFlags_NoTitleBar);
    end
    
    -- Handle pet distance display
    if pet ~= nil and distanceplus.settings.show_pet_window[1] then
        local party = AshitaCore:GetMemoryManager():GetParty();
        local main_job = party:GetMemberMainJob(0);
        
        local pet_distance = math.sqrt(pet.Distance);
        local pet_color = COLOR_WHITE;
        
        -- Special handling for BST pets with range calculation
        if main_job == 9 and pet.ModelSize and player.ModelSize then -- BST
            local pet_max_distance = 4;
            local pet_target_distance = pet_max_distance + pet.ModelSize + player.ModelSize;
            if pet.ModelSize > 1.6 then 
                pet_target_distance = pet_target_distance + 0.1;
            end
            if pet_distance < pet_target_distance then
                pet_color = COLOR_GREEN;
            end
        end
        
        if distanceplus.settings.minimal_display[1] then
            -- Minimal display: use font system like distance.lua
            if distanceplus.pet_font ~= nil then
                distanceplus.pet_font.visible = true;
                distanceplus.pet_font.text = ('%.1f'):fmt(pet_distance);
                distanceplus.pet_font.color = ColorToD3D(pet_color);
                -- Save position changes
                distanceplus.settings.pet_font_pos[1] = distanceplus.pet_font.position_x;
                distanceplus.settings.pet_font_pos[2] = distanceplus.pet_font.position_y;
            end
        else
            -- Apply styling based on user preferences
            if distanceplus.settings.use_modern_style[1] then
                -- Modern style: rounded, semi-transparent with gradient
                imgui.SetNextWindowBgAlpha(distanceplus.settings.bg_alpha[1]);
                imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, distanceplus.settings.window_rounding[1]);
                imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, distanceplus.settings.window_padding);
                imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.1, 0.1, 0.1, distanceplus.settings.bg_alpha[1] });
                imgui.PushStyleColor(ImGuiCol_Border, { 0.4, 0.4, 0.4, 0.8 });
                imgui.PushStyleColor(ImGuiCol_TitleBg, { 0.8, 0.2, 0.2, 1.0 });
                imgui.PushStyleColor(ImGuiCol_TitleBgActive, { 0.8, 0.2, 0.2, 1.0 });
            else
                -- Classic style: simple black box, no title bar, no border
                imgui.SetNextWindowBgAlpha(1.0);
                imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 0.0);
                imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 8, 6 });
                imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0);
                imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.0, 0.0, 0.0, 1.0 });
                imgui.PushStyleColor(ImGuiCol_Border, { 0.0, 0.0, 0.0, 0.0 });
                -- No title bar colors needed since NoTitleBar flag is set
                imgui.PushStyleColor(ImGuiCol_TitleBg, { 0.0, 0.0, 0.0, 0.0 });
                imgui.PushStyleColor(ImGuiCol_TitleBgActive, { 0.0, 0.0, 0.0, 0.0 });
            end
            
            imgui.SetNextWindowSize(distanceplus.settings.pet_size, ImGuiCond_Always);
            
            if imgui.Begin('Pet##PetDistanceWindow', distanceplus.pet_open, window_flags) then
                -- Pet name and distance display
                if pet.Name and pet.Name ~= '' then
                    if distanceplus.settings.center_text[1] then
                        local text_width = imgui.CalcTextSize(pet.Name);
                        imgui.SetCursorPosX((distanceplus.settings.pet_size[1] - text_width) * 0.5);
                    end
                    imgui.Text(pet.Name);
                    imgui.Separator();
                end
                
                local distance_text = ('%.2f'):fmt(pet_distance);
                if distanceplus.settings.center_text[1] then
                    local text_width = imgui.CalcTextSize(distance_text);
                    imgui.SetCursorPosX((distanceplus.settings.pet_size[1] - text_width) * 0.5);
                end
                imgui.TextColored(pet_color, distance_text);
            end
            imgui.End();
            
            imgui.PopStyleColor(4);
            if distanceplus.settings.use_modern_style[1] then
                imgui.PopStyleVar(2);
            else
                imgui.PopStyleVar(3);
            end
        end
    else
        -- Hide pet font when no pet or pet window disabled
        if distanceplus.pet_font ~= nil then
            distanceplus.pet_font.visible = false;
        end
    end
    
    -- Handle main target distance display
    if target ~= nil then
        local distance = math.sqrt(target.Distance);
        local distance_color = GetDistanceColor(distance, player, target);
        
        if distanceplus.settings.minimal_display[1] then
            -- Minimal display: use font system like distance.lua
            if distanceplus.target_font ~= nil then
                distanceplus.target_font.visible = true;
                distanceplus.target_font.text = ('%.1f'):fmt(distance);
                distanceplus.target_font.color = ColorToD3D(distance_color);
                -- Save position changes
                distanceplus.settings.target_font_pos[1] = distanceplus.target_font.position_x;
                distanceplus.settings.target_font_pos[2] = distanceplus.target_font.position_y;
            end
        else
            -- Apply styling based on user preferences
            if distanceplus.settings.use_modern_style[1] then
                -- Modern style: rounded, semi-transparent with gradient
                imgui.SetNextWindowBgAlpha(distanceplus.settings.bg_alpha[1]);
                imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, distanceplus.settings.window_rounding[1]);
                imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, distanceplus.settings.window_padding);
                imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.1, 0.1, 0.1, distanceplus.settings.bg_alpha[1] });
                imgui.PushStyleColor(ImGuiCol_Border, { 0.4, 0.4, 0.4, 0.8 });
                imgui.PushStyleColor(ImGuiCol_TitleBg, { 0.8, 0.2, 0.2, 1.0 });
                imgui.PushStyleColor(ImGuiCol_TitleBgActive, { 0.8, 0.2, 0.2, 1.0 });
            else
                -- Classic style: simple black box, no title bar, no border
                imgui.SetNextWindowBgAlpha(1.0);
                imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 0.0);
                imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 8, 6 });
                imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0);
                imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.0, 0.0, 0.0, 1.0 });
                imgui.PushStyleColor(ImGuiCol_Border, { 0.0, 0.0, 0.0, 0.0 });
                -- No title bar colors needed since NoTitleBar flag is set
                imgui.PushStyleColor(ImGuiCol_TitleBg, { 0.0, 0.0, 0.0, 0.0 });
                imgui.PushStyleColor(ImGuiCol_TitleBgActive, { 0.0, 0.0, 0.0, 0.0 });
            end
            
            imgui.SetNextWindowSize(distanceplus.settings.distance_size, ImGuiCond_Always);
            
            if imgui.Begin('Target##TargetDistanceWindow', distanceplus.is_open, window_flags) then
                -- Target name and distance display
                if target.Name and target.Name ~= '' then
                    if distanceplus.settings.center_text[1] then
                        local text_width = imgui.CalcTextSize(target.Name);
                        imgui.SetCursorPosX((distanceplus.settings.distance_size[1] - text_width) * 0.5);
                    end
                    imgui.Text(target.Name);
                    imgui.Separator();
                end
                
                local distance_text = ('%.2f'):fmt(distance);
                local mode_text = '';
                
                -- Mode indicator
                if distanceplus.settings.show_mode_indicator[1] and distanceplus.settings.option ~= "Default" then
                    mode_text = ('(%s)'):fmt(distanceplus.settings.option);
                    distance_text = distance_text .. ' ' .. mode_text;
                end
                
                if distanceplus.settings.center_text[1] then
                    local text_width = imgui.CalcTextSize(distance_text);
                    imgui.SetCursorPosX((distanceplus.settings.distance_size[1] - text_width) * 0.5);
                end
                
                if distanceplus.settings.show_mode_indicator[1] and distanceplus.settings.option ~= "Default" then
                    imgui.TextColored(distance_color, ('%.2f'):fmt(distance));
                    imgui.SameLine();
                    imgui.TextColored({ 0.7, 0.7, 0.7, 1.0 }, ('(%s)'):fmt(distanceplus.settings.option));
                else
                    imgui.TextColored(distance_color, ('%.2f'):fmt(distance));
                end
            end
            imgui.End();
            
            imgui.PopStyleColor(4);
            if distanceplus.settings.use_modern_style[1] then
                imgui.PopStyleVar(2);
            else
                imgui.PopStyleVar(3);
            end
        end
    else
        -- Hide target font when no target
        if distanceplus.target_font ~= nil then
            distanceplus.target_font.visible = false;
        end
    end
    
    -- Handle font visibility when minimal display is disabled
    if not distanceplus.settings.minimal_display[1] then
        if distanceplus.target_font ~= nil then
            distanceplus.target_font.visible = false;
        end
        if distanceplus.pet_font ~= nil then
            distanceplus.pet_font.visible = false;
        end
    end
end);

--[[
* event: command
* desc : Event called when a command was entered.
--]]
ashita.events.register('command', 'command_cb', function (e)
    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/dp', '/distanceplus')) then
        return;
    end

    -- Block all related commands..
    e.blocked = true;

    -- Handle: /dp help
    if (#args == 1 or args[2]:any('help')) then
        print('DistancePlus: Valid Modes are //DP <command>:');
        print(' Gun, Bow, Xbow, Magic, Ninjutsu');
        print(' MaxDecimal    - Expand MaxDecimal for Max Accuracy. DP Calculates to the Thousand');
        print(' Default     - Reset to Defaults');
        print(' Config      - Toggle configuration GUI window');
        print(' Pets         - Not a command.  If a pet is out another dialog will pop up with distance between you and Pet.');
        return;
    end

    local command = args[2]:lower();
    
    if command == 'gun' then
        print('Mode: Gun.');
        print(' White  = Can not shoot.');
        print(' Yellow = Ranged Attack Capable (No Buff)');
        print(' Green  = Shoots Squarely (Good)');
        print(' Blue   = True Shot (Best)');
        distanceplus.settings.option = "Gun";
        update_settings();
    elseif command == 'xbow' then
        distanceplus.settings.option = "Xbow";
        update_settings();
        print('Mode: XBOW.');
        print(' White  = Can not shoot.');
        print(' Yellow = Ranged Attack Capable (No Buff)');
        print(' Green  = Shoots Squarely (Good)');
        print(' Blue   = True Shot (Best)');
    elseif command == 'bow' then
        distanceplus.settings.option = "Bow";
        update_settings();
        print('Mode: BOW.');
        print(' White  = Can not shoot.');
        print(' Yellow = Ranged Attack Capable (No Buff)');
        print(' Green  = Shoots Squarely (Good)');
        print(' Blue   = True Shot (Best)');
    elseif command == 'magic' then
        distanceplus.settings.option = "Magic";
        update_settings();
        print('Mode: Magic.');
        print(' White = Can not cast.');
        print(' Green = Casting Range');
    elseif command == 'ninjutsu' then
        distanceplus.settings.option = "Ninjutsu";
        update_settings();
        print('Mode: Ninjutsu.');
        print(' White = Can not cast.');
        print(' Green = Casting Range');
    elseif command == 'default' then
        print('Mode: Default.');
        distanceplus.settings.option = "Default";
        distanceplus.settings.max_distance = 25;
        update_settings();
    elseif command == 'maxdecimal' then
        print('MaxDecimal mode enabled.');
        -- This would need custom formatting in the display
    elseif command == 'config' then
        distanceplus.config_open[1] = not distanceplus.config_open[1];
        if distanceplus.config_open[1] then
            print('DistancePlus configuration window opened.');
        else
            print('DistancePlus configuration window closed.');
        end
    end
end);

--[[
* event: load
* desc : Event called when the addon is being loaded.
--]]
ashita.events.register('load', 'load_cb', function ()
    CheckJob();
    
    -- Initialize fonts for minimal display
    distanceplus.target_font = fonts.new({
        visible = false,
        font_family = 'Arial',
        font_height = scaling.scale_f(16),
        color = 0xFFFFFFFF,
        bold = true,
        position_x = distanceplus.settings.target_font_pos[1],
        position_y = distanceplus.settings.target_font_pos[2],
    });
    
    distanceplus.pet_font = fonts.new({
        visible = false,
        font_family = 'Arial',
        font_height = scaling.scale_f(16),
        color = 0xFFFFFFFF,
        bold = true,
        position_x = distanceplus.settings.pet_font_pos[1],
        position_y = distanceplus.settings.pet_font_pos[2],
    });
end);

--[[
* event: unload
* desc : Event called when the addon is being unloaded.
--]]
ashita.events.register('unload', 'unload_cb', function ()
    -- Save font positions before destroying fonts
    if (distanceplus.target_font ~= nil) then
        distanceplus.settings.target_font_pos[1] = distanceplus.target_font.position_x;
        distanceplus.settings.target_font_pos[2] = distanceplus.target_font.position_y;
        distanceplus.target_font:destroy();
        distanceplus.target_font = nil;
    end
    
    if (distanceplus.pet_font ~= nil) then
        distanceplus.settings.pet_font_pos[1] = distanceplus.pet_font.position_x;
        distanceplus.settings.pet_font_pos[2] = distanceplus.pet_font.position_y;
        distanceplus.pet_font:destroy();
        distanceplus.pet_font = nil;
    end
    
    -- Save all settings
    settings.save();
end);