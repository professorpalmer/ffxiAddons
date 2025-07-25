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

-- DistancePlus Variables
local distanceplus = T{
    is_open = { true, },
    pet_open = { true, },
    config_open = { false, },
    option = "Default",
    max_distance = 25,
    self = nil,
    
    -- Window settings - now configurable
    distance_size = { 180, 80 },
    pet_size = { 180, 80 },
    
    -- Style settings
    use_modern_style = { true },
    center_text = { false },
    show_mode_indicator = { true },
    show_pet_window = { true },
    
    -- Window transparency and styling
    bg_alpha = { 0.85 },
    window_rounding = { 8.0 },
    window_padding = { 12, 8 },
};

-- Color constants
local COLOR_WHITE = { 1.0, 1.0, 1.0, 1.0 };
local COLOR_GREEN = { 0.0, 1.0, 0.0, 1.0 };
local COLOR_YELLOW = { 1.0, 1.0, 0.0, 1.0 };
local COLOR_BLUE = { 0.0, 0.0, 1.0, 1.0 };
local COLOR_RED = { 1.0, 0.0, 0.0, 1.0 };

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
        distanceplus.option = "Magic";
        print('Mode: Magic.');
        print(' White = Can not cast.');
        print(' Green = Casting Range');
        distanceplus.max_distance = 20;
    elseif main_job == 17 then -- COR
        print('Mode: Gun.');
        print(' White  = Can not shoot.');
        print(' Yellow = Ranged Attack Capable (No Buff)');
        print(' Green  = Shoots Squarely (Good)');
        print(' Blue   = True Shot (Best)');
        distanceplus.option = "Gun";
        distanceplus.max_distance = 25;
    elseif main_job == 11 then -- RNG
        print('RANGER should do //dp Bow, //dp XBow, or //dp Gun');
        print('Mode: Default.');
        distanceplus.option = "Default";
        distanceplus.max_distance = 25;
    elseif main_job == 13 then -- NIN
        distanceplus.option = "Ninjutsu";
        print('Mode: Ninjutsu.');
        print(' White = Can not cast.');
        print(' Green = Casting Range');
    else
        print('Mode: Default.');
        distanceplus.option = "Default";
        distanceplus.max_distance = 25;
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
    
    if distanceplus.option == 'Default' then
        return COLOR_WHITE;
    elseif distanceplus.option == 'Bow' then
        local MaxDistance = 25;
        local trueshotmax = s.ModelSize + t.ModelSize + 9.5199;
        local trueshotmin = s.ModelSize + t.ModelSize + 6.02;
        local squareshot_far_max = s.ModelSize + t.ModelSize + 14.5199;
        local squareshot_close_min = s.ModelSize + t.ModelSize + 4.62;
        
        if t.ModelSize > 1.6 then 
            trueshotmax = trueshotmax + 0.1;
            trueshotmin = trueshotmin + 0.1;
            squareshot_far_max = squareshot_far_max + 0.1;
            squareshot_close_min = squareshot_close_min + 0.1;
        end
        
        if distance < MaxDistance and (distance > squareshot_far_max or distance < squareshot_close_min) then 
            return COLOR_YELLOW; -- Yellow (No Ranged Boost)
        elseif (distance <= squareshot_far_max and distance > trueshotmax) or (distance < trueshotmin and distance >= squareshot_close_min) then 
            return COLOR_GREEN; -- Green (Square Shot)
        elseif (distance <= trueshotmax and distance >= trueshotmin) then
            return COLOR_BLUE; -- Blue (Strikes True)
        else 
            return COLOR_WHITE; -- White (Can't Shoot)
        end
    elseif distanceplus.option == 'Xbow' then
        local MaxDistance = 25;
        local trueshotmax = s.ModelSize + t.ModelSize + 8.3999;
        local trueshotmin = s.ModelSize + t.ModelSize + 5.0007;
        local squareshot_far_max = s.ModelSize + t.ModelSize + 11.7199;
        local squareshot_close_min = s.ModelSize + t.ModelSize + 3.6199;
        
        if t.ModelSize > 1.6 then 
            trueshotmax = trueshotmax + 0.1;
            trueshotmin = trueshotmin + 0.1;
            squareshot_far_max = squareshot_far_max + 0.1;
            squareshot_close_min = squareshot_close_min + 0.1;
        end
        
        if distance < MaxDistance and (distance > squareshot_far_max or distance < squareshot_close_min) then 
            return COLOR_YELLOW; -- Yellow (No Ranged Boost)
        elseif (distance <= squareshot_far_max and distance > trueshotmax) or (distance < trueshotmin and distance >= squareshot_close_min) then 
            return COLOR_GREEN; -- Green (Square Shot)
        elseif (distance <= trueshotmax and distance >= trueshotmin) then
            return COLOR_BLUE; -- Blue (Strikes True)
        else 
            return COLOR_WHITE; -- White (Can't Shoot)
        end
    elseif distanceplus.option == 'Gun' then
        local MaxDistance = 25;
        local trueshotmax = s.ModelSize + t.ModelSize + 4.3189;
        local trueshotmin = s.ModelSize + t.ModelSize + 3.0209;
        local squareshot_far_max = s.ModelSize + t.ModelSize + 6.8199;
        local squareshot_close_min = s.ModelSize + t.ModelSize + 2.2219;
        
        if t.ModelSize > 1.6 then 
            trueshotmax = trueshotmax + 0.1;
            trueshotmin = trueshotmin + 0.1;
            squareshot_far_max = squareshot_far_max + 0.1;
            squareshot_close_min = squareshot_close_min + 0.1;
        end
        
        if distance < MaxDistance and (distance > squareshot_far_max or distance < squareshot_close_min) then 
            return COLOR_YELLOW; -- Yellow (No Ranged Boost)
        elseif (distance <= squareshot_far_max and distance > trueshotmax) or (distance < trueshotmin and distance >= squareshot_close_min) then 
            return COLOR_GREEN; -- Green (Square Shot)
        elseif (distance <= trueshotmax and distance >= trueshotmin) then
            return COLOR_BLUE; -- Blue (Strikes True)
        else 
            return COLOR_WHITE; -- White (Can't Shoot)
        end
    elseif distanceplus.option == 'Magic' then
        local MaxDistance = 20;
        if t.ModelSize > 2 then 
            MaxDistance = MaxDistance + 0.1;
        elseif math.floor(t.ModelSize * 10) == 44 then 
            MaxDistance = 20.0666;
        elseif math.floor(t.ModelSize * 10) == 53 then 
            MaxDistance = 20;
        end
        local targetdistance = MaxDistance + t.ModelSize + s.ModelSize;
        if distance < targetdistance then
            return COLOR_GREEN; -- Green
        else
            return COLOR_WHITE; -- White can't Cast
        end
    elseif distanceplus.option == 'Ninjutsu' then
        local MaxDistance = 16.1;
        if t.ModelSize > 2 then 
            MaxDistance = MaxDistance + 0.1;
        elseif math.floor(t.ModelSize * 10) == 44 then 
            MaxDistance = 16.1;
        elseif math.floor(t.ModelSize * 10) == 53 then 
            MaxDistance = 16.1;
        end
        local targetdistance = MaxDistance + t.ModelSize + s.ModelSize;
        if distance < targetdistance then
            return COLOR_GREEN; -- Green
        else
            return COLOR_WHITE; -- White can't Cast
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
            imgui.SliderFloat2('Size##DistanceSize', distanceplus.distance_size, 70, 400, '%.0f');
            
            imgui.Text('Pet Distance Window:');
            imgui.SliderFloat2('Size##PetSize', distanceplus.pet_size, 70, 400, '%.0f');
        end
        
        -- Display Options
        if imgui.CollapsingHeader('Display Options') then
            imgui.Checkbox('Show Mode Indicator', distanceplus.show_mode_indicator);
            imgui.Checkbox('Show Pet Window', distanceplus.show_pet_window);
            imgui.Checkbox('Center Text', distanceplus.center_text);
        end
        
        -- Style Settings
        if imgui.CollapsingHeader('Window Style') then
            imgui.Checkbox('Use Modern Style', distanceplus.use_modern_style);
            
            if distanceplus.use_modern_style[1] then
                imgui.SliderFloat('Background Alpha', distanceplus.bg_alpha, 0.0, 1.0, '%.2f');
                imgui.SliderFloat('Window Rounding', distanceplus.window_rounding, 0.0, 15.0, '%.1f');
                imgui.SliderFloat2('Window Padding', distanceplus.window_padding, 0, 20, '%.0f');
            end
        end
        
        -- Mode Selection
        if imgui.CollapsingHeader('Range Mode') then
            imgui.Text('Current Mode: ' .. distanceplus.option);
            imgui.Separator();
            
            if imgui.Button('Default') then
                distanceplus.option = "Default";
                distanceplus.max_distance = 25;
                print('Mode: Default.');
            end
            imgui.SameLine();
            if imgui.Button('Gun') then
                distanceplus.option = "Gun";
                print('Mode: Gun.');
            end
            imgui.SameLine();
            if imgui.Button('Bow') then
                distanceplus.option = "Bow";
                print('Mode: Bow.');
            end
            imgui.SameLine();
            if imgui.Button('Xbow') then
                distanceplus.option = "Xbow";
                print('Mode: Crossbow.');
            end
            
            if imgui.Button('Magic') then
                distanceplus.option = "Magic";
                print('Mode: Magic.');
            end
            imgui.SameLine();
            if imgui.Button('Ninjutsu') then
                distanceplus.option = "Ninjutsu";
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
    if not distanceplus.use_modern_style[1] then
        window_flags = bit.bor(window_flags, ImGuiWindowFlags_NoTitleBar);
    end
    
    -- Handle pet distance display
    if pet ~= nil and distanceplus.show_pet_window[1] then
        local party = AshitaCore:GetMemoryManager():GetParty();
        local main_job = party:GetMemberMainJob(0);
        
        -- Apply styling based on user preferences
        if distanceplus.use_modern_style[1] then
            -- Modern style: rounded, semi-transparent with gradient
            imgui.SetNextWindowBgAlpha(distanceplus.bg_alpha[1]);
            imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, distanceplus.window_rounding[1]);
            imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, distanceplus.window_padding);
            imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.1, 0.1, 0.1, distanceplus.bg_alpha[1] });
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
        
        imgui.SetNextWindowSize(distanceplus.pet_size, ImGuiCond_Always);
        
        if imgui.Begin('Pet##PetDistanceWindow', distanceplus.pet_open, window_flags) then
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
            
            -- Pet name and distance display
            if pet.Name and pet.Name ~= '' then
                if distanceplus.center_text[1] then
                    local text_width = imgui.CalcTextSize(pet.Name);
                    imgui.SetCursorPosX((distanceplus.pet_size[1] - text_width) * 0.5);
                end
                imgui.Text(pet.Name);
                imgui.Separator();
            end
            
            local distance_text = ('%.2f'):fmt(pet_distance);
            if distanceplus.center_text[1] then
                local text_width = imgui.CalcTextSize(distance_text);
                imgui.SetCursorPosX((distanceplus.pet_size[1] - text_width) * 0.5);
            end
            imgui.TextColored(pet_color, distance_text);
        end
        imgui.End();
        
        imgui.PopStyleColor(4);
        if distanceplus.use_modern_style[1] then
            imgui.PopStyleVar(2);
        else
            imgui.PopStyleVar(3);
        end
    end
    
    -- Handle main target distance display
    if target ~= nil then
        local distance = math.sqrt(target.Distance);
        
        -- Apply styling based on user preferences
        if distanceplus.use_modern_style[1] then
            -- Modern style: rounded, semi-transparent with gradient
            imgui.SetNextWindowBgAlpha(distanceplus.bg_alpha[1]);
            imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, distanceplus.window_rounding[1]);
            imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, distanceplus.window_padding);
            imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.1, 0.1, 0.1, distanceplus.bg_alpha[1] });
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
        
        imgui.SetNextWindowSize(distanceplus.distance_size, ImGuiCond_Always);
        
        if imgui.Begin('Target##TargetDistanceWindow', distanceplus.is_open, window_flags) then
            local distance_color = GetDistanceColor(distance, player, target);
            
            -- Target name and distance display
            if target.Name and target.Name ~= '' then
                if distanceplus.center_text[1] then
                    local text_width = imgui.CalcTextSize(target.Name);
                    imgui.SetCursorPosX((distanceplus.distance_size[1] - text_width) * 0.5);
                end
                imgui.Text(target.Name);
                imgui.Separator();
            end
            
            local distance_text = ('%.2f'):fmt(distance);
            local mode_text = '';
            
            -- Mode indicator
            if distanceplus.show_mode_indicator[1] and distanceplus.option ~= "Default" then
                mode_text = ('(%s)'):fmt(distanceplus.option);
                distance_text = distance_text .. ' ' .. mode_text;
            end
            
            if distanceplus.center_text[1] then
                local text_width = imgui.CalcTextSize(distance_text);
                imgui.SetCursorPosX((distanceplus.distance_size[1] - text_width) * 0.5);
            end
            
            if distanceplus.show_mode_indicator[1] and distanceplus.option ~= "Default" then
                imgui.TextColored(distance_color, ('%.2f'):fmt(distance));
                imgui.SameLine();
                imgui.TextColored({ 0.7, 0.7, 0.7, 1.0 }, ('(%s)'):fmt(distanceplus.option));
            else
                imgui.TextColored(distance_color, ('%.2f'):fmt(distance));
            end
        end
        imgui.End();
        
        imgui.PopStyleColor(4);
        if distanceplus.use_modern_style[1] then
            imgui.PopStyleVar(2);
        else
            imgui.PopStyleVar(3);
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
        distanceplus.option = "Gun";
    elseif command == 'xbow' then
        distanceplus.option = "Xbow";
        print('Mode: XBOW.');
        print(' White  = Can not shoot.');
        print(' Yellow = Ranged Attack Capable (No Buff)');
        print(' Green  = Shoots Squarely (Good)');
        print(' Blue   = True Shot (Best)');
    elseif command == 'bow' then
        distanceplus.option = "Bow";
        print('Mode: BOW.');
        print(' White  = Can not shoot.');
        print(' Yellow = Ranged Attack Capable (No Buff)');
        print(' Green  = Shoots Squarely (Good)');
        print(' Blue   = True Shot (Best)');
    elseif command == 'magic' then
        distanceplus.option = "Magic";
        print('Mode: Magic.');
        print(' White = Can not cast.');
        print(' Green = Casting Range');
    elseif command == 'ninjutsu' then
        distanceplus.option = "Ninjutsu";
        print('Mode: Ninjutsu.');
        print(' White = Can not cast.');
        print(' Green = Casting Range');
    elseif command == 'default' then
        print('Mode: Default.');
        distanceplus.option = "Default";
        distanceplus.max_distance = 25;
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
end);