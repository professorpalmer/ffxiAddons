local M = {};

-- forward reference to autoManeuver (injected by main)
local autoManeuver = nil;
local hudModule = nil;

function M.set_auto_maneuver_module(mod)
    autoManeuver = mod;
end

function M.set_hud_module(mod)
    hudModule = mod;
end

-- Clear conflicting combat/tank modes when toggling another.
local function clear_conflicts(settings, keepKey)
    if keepKey ~= 'DTMode' then settings.DTMode = false; end
    if keepKey ~= 'HybridMode' then settings.HybridMode = false; end
    if keepKey ~= 'MasterMode' then settings.MasterMode = false; end
    if keepKey ~= 'MasterSTPMode' then settings.MasterSTPMode = false; end
    if keepKey ~= 'PupOnly' then settings.PupOnly = false; end
    if keepKey ~= 'TurtleMode' then settings.TurtleMode = false; end
    if keepKey ~= 'PetHybridMode' then settings.PetHybridMode = false; end
    if keepKey ~= 'RegenMode' then settings.RegenMode = false; end
    if keepKey ~= 'CombatMode' then settings.CombatMode = ''; end
end

function M.make_handler(settings, update_weapon, refresh_gear, thModule)
    return function(args)
        if (args[1] == 'pupmode') then
            if (args[2] ~= nil) then
                local mode = string.lower(args[2]);
                if (mode == 'tank' or mode == 'melee' or mode == 'range' or mode == 'magic') then
                    settings.PetMode = mode:gsub("^%l", string.upper);
                    print('Pet mode set to: ' .. settings.PetMode);
                else
                    print('Invalid mode. Use: tank, melee, range, or magic');
                end
            else
                print('Current pet mode: ' .. settings.PetMode);
            end
            return;
        elseif (args[1] == 'dt') then
            local newVal = not settings.DTMode;
            if newVal then clear_conflicts(settings, 'DTMode'); end
            settings.DTMode = newVal;
            print('DT mode: ' .. (settings.DTMode and 'On' or 'Off'));
            refresh_gear();
            return;
        elseif (args[1] == 'hybrid') then
            local newVal = not settings.HybridMode;
            if newVal then clear_conflicts(settings, 'HybridMode'); end
            settings.HybridMode = newVal;
            print('Hybrid mode: ' .. (settings.HybridMode and 'On' or 'Off'));
            refresh_gear();
            return;
        elseif (args[1] == 'puponly') then
            local newVal = not settings.PupOnly;
            if newVal then clear_conflicts(settings, 'PupOnly'); end
            settings.PupOnly = newVal;
            print('PupOnly mode: ' .. (settings.PupOnly and 'On' or 'Off'));
            refresh_gear();
            return;
        elseif (args[1] == 'turtle') then
            local newVal = not settings.TurtleMode;
            if newVal then clear_conflicts(settings, 'TurtleMode'); end
            settings.TurtleMode = newVal;
            print('Turtle mode: ' .. (settings.TurtleMode and 'On' or 'Off'));
            refresh_gear();
            return;
        elseif (args[1] == 'pethybrid') then
            local newVal = not settings.PetHybridMode;
            if newVal then clear_conflicts(settings, 'PetHybridMode'); end
            settings.PetHybridMode = newVal;
            print('Pet Hybrid mode: ' .. (settings.PetHybridMode and 'On' or 'Off'));
            refresh_gear();
            return;
        elseif (args[1] == 'master') then
            local newVal = not settings.MasterMode;
            if newVal then clear_conflicts(settings, 'MasterMode'); end
            settings.MasterMode = newVal;
            print('Master mode: ' .. (settings.MasterMode and 'On' or 'Off'));
            refresh_gear();
            return;
        elseif (args[1] == 'masterstp') then
            local newVal = not settings.MasterSTPMode;
            if newVal then clear_conflicts(settings, 'MasterSTPMode'); end
            settings.MasterSTPMode = newVal;
            print('MasterSTP mode: ' .. (settings.MasterSTPMode and 'On' or 'Off'));
            refresh_gear();
            return;
        elseif (args[1] == 'xiu') then
            settings.Weapon = 'Xiucoatl';
            update_weapon();
            print('Weapon set to: ' .. settings.Weapon);
            return;
        elseif (args[1] == 'karambit') then
            settings.Weapon = 'Karambit';
            update_weapon();
            print('Weapon set to: ' .. settings.Weapon);
            return;
        elseif (args[1] == 'godhands') then
            settings.Weapon = 'Godhands';
            update_weapon();
            print('Weapon set to: ' .. settings.Weapon);
            return;
        elseif (args[1] == 'kkk') then
            settings.Weapon = 'Kenkonken';
            update_weapon();
            print('Weapon set to: ' .. settings.Weapon);
            return;
        elseif (args[1] == 'automaneuver') then
            local newVal = not settings.AutoManeuver;
            settings.AutoManeuver = newVal;
            print('Auto Maneuver: ' .. (newVal and 'On' or 'Off'));
            refresh_gear();
            return;
        elseif (args[1] == 'maneuver') then
            -- Custom rotation: e.g. /maneuver firewindfire or /maneuver fire,wind,fire
            local argstr = table.concat(args, ' ', 2);
            if argstr == nil or argstr == '' then
                print('Current rotation: ' .. (autoManeuver.get_rotation_string() or 'none'));
                return;
            end
            autoManeuver.set_rotation(argstr);
            return;
        elseif (args[1] == 'manhud') then
            if hudModule and hudModule.toggle then
                hudModule.toggle();
                local vis = hudModule.get_visible and hudModule.get_visible();
                print('Maneuver HUD: ' .. ((vis and 'On') or 'Off'));
            end
            return;
        elseif (args[1] == 'warpring') then
            settings.TeleportActive = true;
            print('Warp Ring equipped - Using in 10 seconds...');
            gFunc.ForceEquip(14, "Warp Ring");
            ashita.tasks.once(10, function()
                print('Using Warp Ring...');
                AshitaCore:GetChatManager():QueueCommand(1, '/item "Warp Ring" <me>');
                ashita.tasks.once(3, function()
                    print('Teleportation complete - refreshing gear...');
                    AshitaCore:GetChatManager():QueueCommand(1, '/lac fwd refresh');
                end);
            end);
            return;
        elseif (args[1] == 'dimring') then
            settings.TeleportActive = true;
            print('Dimensional Ring equipped - Using in 10 seconds...');
            gFunc.ForceEquip(14, "Dim. Ring (Holla)");
            ashita.tasks.once(10, function()
                print('Using Dimensional Ring...');
                AshitaCore:GetChatManager():QueueCommand(1, '/item "Dim. Ring (Holla)" <me>');
                ashita.tasks.once(3, function()
                    print('Teleportation complete - refreshing gear...');
                    AshitaCore:GetChatManager():QueueCommand(1, '/lac fwd refresh');
                end);
            end);
            return;
        elseif (args[1] == 'refresh') then
            settings.TeleportActive = false;
            settings.DTMode = false;
            settings.HybridMode = false;
            settings.MasterMode = false;
            settings.CombatMode = '';
            print('Returning to normal gear');
            refresh_gear();
            return;
        elseif (args[1] == 'lowacc') then
            clear_conflicts(settings, 'CombatMode');
            settings.CombatMode = 'LowAcc';
            print('Combat Mode: Low Accuracy (easy targets)');
            refresh_gear();
            return;
        elseif (args[1] == 'highacc') then
            clear_conflicts(settings, 'CombatMode');
            settings.CombatMode = 'HighAcc';
            print('Combat Mode: High Accuracy (tough targets)');
            refresh_gear();
            return;
        elseif (args[1] == 'lowatk') then
            clear_conflicts(settings, 'CombatMode');
            settings.CombatMode = 'LowAtk';
            print('Combat Mode: Low Attack (high defense targets)');
            refresh_gear();
            return;
        elseif (args[1] == 'highatk') then
            clear_conflicts(settings, 'CombatMode');
            settings.CombatMode = 'HighAtk';
            print('Combat Mode: High Attack (glass cannon)');
            refresh_gear();
            return;
        elseif (args[1] == 'lowhaste') then
            clear_conflicts(settings, 'CombatMode');
            settings.CombatMode = 'LowHaste';
            print('Combat Mode: Low Haste (need more haste)');
            refresh_gear();
            return;
        elseif (args[1] == 'highhaste') then
            clear_conflicts(settings, 'CombatMode');
            settings.CombatMode = 'HighHaste';
            print('Combat Mode: High Haste (haste capped)');
            refresh_gear();
            return;
        elseif (args[1] == 'regen') then
            local newVal = not settings.RegenMode;
            if newVal then clear_conflicts(settings, 'RegenMode'); end
            settings.RegenMode = newVal;
            print('Regen mode: ' .. (settings.RegenMode and 'On' or 'Off'));
            refresh_gear();
            return;
        elseif (args[1] == 'th') then
            local newState = not thModule.is_enabled();
            thModule.set_enabled(newState);
            print('Treasure Hunter auto-first-hit: ' .. (newState and 'On' or 'Off'));
            refresh_gear();
            return;
        elseif (args[1] == 'am3') then
            settings.AM3Mode = not settings.AM3Mode;
            print('AM3 automatic gear swap: ' .. (settings.AM3Mode and 'On' or 'Off'));
            if settings.AM3Mode then
                print('AM3TP set will automatically equip when Aftermath: Lv.3 buff is active');
            else
                print('AM3TP set disabled - will use normal Engaged set even with Aftermath: Lv.3');
            end
            refresh_gear();
            return;
        elseif (args[1] == 'petswaps' or args[1] == 'petswap') then
            settings.PetSwapMode = not settings.PetSwapMode;
            print('Pet WS pre-swap: ' .. (settings.PetSwapMode and 'On' or 'Off') .. ' (TP >= ' .. tostring(settings.PetSwapTP) .. ')');
            refresh_gear();
            return;
        elseif (args[1] == 'vileelixir') then
            local inv = AshitaCore:GetMemoryManager():GetInventory();
            local resx = AshitaCore:GetResourceManager();
            local containers = { 0, 8, 10, 11, 12, 13, 14, 15, 16 };

            print('Searching for Vile Elixir items...');

            for _, container in ipairs(containers) do
                for index = 0, 80 do
                    local item = inv:GetContainerItem(container, index);
                    if item and item.Id > 0 then
                        local itemName = resx:GetItemById(item.Id).Name[1];

                        if string.find(string.lower(itemName), "vile elixir") then
                            print('Found potential Vile Elixir item: "' .. itemName .. '" (ID: ' .. item.Id .. ') in container ' .. container .. ', slot ' .. index);
                        end

                        if itemName == "Vile Elixir +1" or itemName == "Vile Elixir+1" or string.find(string.lower(itemName), "vile elixir%+1") then
                            print('Found Vile Elixir +1 in container ' .. container .. ', slot ' .. index);
                            print('Using Vile Elixir +1');
                            print('Item name being used: "' .. itemName .. '"');
                            print('Item ID: ' .. item.Id);
                            AshitaCore:GetChatManager():QueueCommand(1, '/item "' .. itemName .. '" <me>');
                            return;
                        end
                    end
                end
            end

            print('Vile Elixir +1 not found, searching for regular Vile Elixir...');
            for _, container in ipairs(containers) do
                for index = 0, 80 do
                    local item = inv:GetContainerItem(container, index);
                    if item and item.Id > 0 then
                        local itemName = resx:GetItemById(item.Id).Name[1];

                        if itemName == "Vile Elixir" and not string.find(string.lower(itemName), "%+1") then
                            print('Found Vile Elixir in container ' .. container .. ', slot ' .. index);
                            print('Using Vile Elixir');
                            print('Item name being used: "' .. itemName .. '"');
                            print('Item ID: ' .. item.Id);
                            AshitaCore:GetChatManager():QueueCommand(1, '/item "' .. itemName .. '" <me>');
                            return;
                        end
                    end
                end
            end

            print('No Vile Elixir items found in inventory');
            return;
        end
    end;
end

return M;


