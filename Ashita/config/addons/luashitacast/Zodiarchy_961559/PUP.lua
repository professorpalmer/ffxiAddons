require('common');
local gear = gFunc.LoadFile('common/gear.lua');
local Equip = gFunc.LoadFile('common/equip.lua');
local Status = gFunc.LoadFile('common/status.lua');
local itemHandler = gFunc.LoadFile('common/items.lua');

local pupLib = nil;
do
    local ok, mod = pcall(require, 'pup');
    if ok then
        pupLib = mod;
    end
end

local setsModule = gFunc.LoadFile('Zodiarchy_961559/lib/sets.lua');
local thModule = gFunc.LoadFile('Zodiarchy_961559/lib/th.lua');
local animator = gFunc.LoadFile('Zodiarchy_961559/lib/animator.lua');
local petActions = gFunc.LoadFile('Zodiarchy_961559/lib/pet_actions.lua');
local petTpSwap = gFunc.LoadFile('Zodiarchy_961559/lib/pet_tp_swap.lua');
local cmdModule = gFunc.LoadFile('Zodiarchy_961559/lib/commands.lua');
local autoManeuver = gFunc.LoadFile('Zodiarchy_961559/lib/auto_maneuver.lua');
local maneuverHud = gFunc.LoadFile('Zodiarchy_961559/lib/maneuver_hud.lua');
local autoManeuverEventId = 'pup_auto_maneuver_tick';
local maneuverHudEventId = 'pup_maneuver_hud_present';

-- Cached pupset name lookup
local pupsetCache = { name = 'unknown', lastRead = 0 };

local function GetCurrentPupset()
    local now = os.time();
    if (now - pupsetCache.lastRead) < 5 then
        return pupsetCache.name;
    end

    local path = string.format('%s\\config\\addons\\pupsets\\last_loaded.txt', AshitaCore:GetInstallPath());
    local f = io.open(path, 'r');
    if f ~= nil then
        local line = f:read('*l');
        f:close();
        if line ~= nil and line ~= '' then
            pupsetCache.name = line;
        else
            pupsetCache.name = 'unknown';
        end
    else
        pupsetCache.name = 'unknown';
    end
    pupsetCache.lastRead = now;
    return pupsetCache.name;
end

local profile = {}

local settings = {
    PetMode = 'Tank',       -- Tank, Melee, Range, Magic
    IsTrusted = false,      -- For pet trusts
    Weapon = 'Kenkonken',   -- Primary weapon: Kenkonken (can switch to Karambit, Godhands, or Xiucoatl)
    AutoManeuver = false,   -- Toggle automatic maneuvers
    PupOnly = false,        -- For fights where only automaton is used (Lobo, etc) - toggleable with /puponly
    TurtleMode = false,     -- For pet -DT tank mode - toggleable with /turtle
    PetHybridMode = false,  -- For pet hybrid DT/DPS mode - toggleable with /pethybrid
    MasterMode = false,     -- For pure master DPS when pet is mage/not used - toggleable with /master
    MasterSTPMode = false,  -- For master Store TP mode when pet is mage/not used - toggleable with /masterstp
    TeleportActive = false, -- Prevent automatic gear changes when teleport item equipped
    DTMode = false,         -- Toggle damage taken mode
    HybridMode = false,     -- Toggle hybrid DT/DPS mode
    CombatMode = '',        -- Combat optimization: lowacc, highacc, lowatk, highatk, lowhaste, highhaste
    RegenMode = false,      -- Manual regen/idle gear mode - toggleable with /regen
    THMode = false,         -- Toggle Treasure Hunter mode - toggleable with /th (now controls automation)
    AM3Mode = true,         -- Toggle AM3 TP set automatic swapping - toggleable with /am3
    PetSwapMode = false,    -- Toggle pet TP-based WS pre-swap - /petswaps
    PetSwapTP = 1000,       -- TP threshold to arm WS set
}

local sets = setsModule.build_sets(Equip);

local function UpdateWeapon()
    setsModule.update_weapon(sets, settings, function() profile.HandleDefault(); end);
end

thModule.init(settings);
animator.init(pupLib);
autoManeuver.init(settings, Status);
cmdModule.set_auto_maneuver_module(autoManeuver);
maneuverHud.init({
    get_rotation = function() return autoManeuver.get_rotation_string(); end,
    get_auto = function() return settings.AutoManeuver; end,
});
cmdModule.set_hud_module(maneuverHud);
petTpSwap.init(settings, Equip, sets);

profile.Sets = sets

profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    thModule.set_enabled(settings.THMode); -- keep TH automation state in sync on load
    gFunc.LockStyle(sets.Idle); -- Lock to idle gear appearance instead of town
    AshitaCore:GetChatManager():QueueCommand(1, '/lockstyleset 4');

    -- Ensure addset is enabled
    print('AddSet functionality enabled: ' .. tostring(gSettings.AllowAddSet));

    -- Chat aliases/commands
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /pupmode /lac fwd pupmode');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /dt /lac fwd dt');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /hybrid /lac fwd hybrid');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /puponly /lac fwd puponly');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /turtle /lac fwd turtle');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /pethybrid /lac fwd pethybrid');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /master /lac fwd master');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /masterstp /lac fwd masterstp');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /xiu /lac fwd xiu');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /karambit /lac fwd karambit');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /godhands /lac fwd godhands');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /kkk /lac fwd kkk');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /warpring /lac fwd warpring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /dimring /lac fwd dimring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /refresh /lac fwd refresh');
    -- Combat mode aliases
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /lowacc /lac fwd lowacc');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /highacc /lac fwd highacc');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /lowatk /lac fwd lowatk');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /highatk /lac fwd highatk');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /lowhaste /lac fwd lowhaste');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /highhaste /lac fwd highhaste');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /regen /lac fwd regen');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /th /lac fwd th');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /am3 /lac fwd am3');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /petswap /lac fwd petswaps'); -- singular alias for convenience
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /petswaps /lac fwd petswaps');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /automaneuver /lac fwd automaneuver');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /maneuver /lac fwd maneuver');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /manhud /lac fwd manhud');

    -- Register a prerender tick for auto maneuvers (runs every frame)
    if (ashita and ashita.events and ashita.events.register) then
        ashita.events.register('prerender', autoManeuverEventId, function()
            local player = gData.GetPlayer();
            local pet = gData.GetPet();
            petTpSwap.tick(player, pet);
            autoManeuver.tick(player, pet);
        end);
        ashita.events.register('d3d_present', maneuverHudEventId, function()
            maneuverHud.render();
        end);
    end

    -- Register hotkey for DEL key
    AshitaCore:GetChatManager():QueueCommand(1, '/bind delete /lac fwd vileelixir');

    print('PUP Profile Loaded');
    print(
        'Commands: /pupmode (tank/melee/range/magic), /dt, /hybrid, /puponly, /turtle, /pethybrid, /master, /masterstp, /xiu, /karambit, /godhands, /kkk, /refresh');
    print('Combat Modes: /lowacc, /highacc, /lowatk, /highatk, /lowhaste, /highhaste');
    print('Teleport Commands: /warpring, /dimring');
    print('Regen Control: /regen - Toggle manual regen/idle gear');
    print('Treasure Hunter: /th - Toggle auto first-hit TH tagging');
    print('AM3 Control: /am3 - Toggle Aftermath Lv.3 automatic gear swap (currently: ' .. (settings.AM3Mode and 'ON' or 'OFF') .. ')');
    print('Hotkey: DEL key for Vile Elixir items');
    print('Default weapon: Kenkonken | PupOnly mode for fights using Lobo only');
    print(
    'Turtle mode for pet -DT tank | PetHybrid for pet DT/DPS balance | Master mode for pure master DPS | MasterSTP mode for master Store TP | Hybrid mode for DT/DPS balance');
    print('NEW: Automatic pet action detection - swaps gear for pet WS/magic!');
end

profile.OnUnload = function()
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /pupmode');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /dt');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /hybrid');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /puponly');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /turtle');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /pethybrid');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /master');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /masterstp');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /xiu');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /karambit');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /godhands');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /kkk');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /warpring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /dimring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /lowacc');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /highacc');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /lowatk');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /highatk');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /lowhaste');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /highhaste');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /regen');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /th');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /am3');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /petswap');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /petswaps');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /automaneuver');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /maneuver');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /manhud');

    -- Unbind DEL key
    AshitaCore:GetChatManager():QueueCommand(1, '/unbind delete');

    if (ashita and ashita.events and ashita.events.unregister) then
        ashita.events.unregister('prerender', autoManeuverEventId);
        ashita.events.unregister('d3d_present', maneuverHudEventId);
    end
end

profile.HandleCommand = cmdModule.make_handler(settings, UpdateWeapon, function() profile.HandleDefault(); end, thModule);

-- Function to get the appropriate base set based on current mode and status
local function GetBaseSet()
    local player = gData.GetPlayer();
    local pet = gData.GetPet();



    -- Check for special modes (high priority)
    if (settings.PupOnly) then
        return sets.PupOnly;
    end

    if (settings.TurtleMode) then
        return sets.Turtle;
    end

    if (settings.PetHybridMode) then
        return sets.PetHybrid;
    end

    if (settings.RegenMode) then
        -- In regen mode, use idle gear based on pet status
        if (pet and pet.isvalid) then
            return sets.PetIdle[settings.PetMode];
        else
            return sets.Idle;
        end
    end

    -- Check for damage/defensive modes
    if (settings.DTMode) then
        return sets.DT;
    elseif (settings.HybridMode) then
        return sets.Hybrid;
    elseif (settings.MasterSTPMode) then
        return sets.MasterSTP;
    elseif (settings.MasterMode) then
        return sets.Master;
    end

    -- Check for Overdrive buff
    if (Status.HasStatus('Overdrive')) then
        return sets.Overdrive;
    end

    -- Handle different player states
    if (player.Status == 'Engaged') then
        -- Check for Aftermath: Lv.3 buff (highest priority for engaged) - only if AM3Mode is enabled
        if (settings.AM3Mode and Status.HasStatus('Aftermath: Lv.3')) then
            return sets.AM3TP;
        end
        
        -- Check for combat mode overrides
        if (settings.CombatMode ~= '' and sets.CombatModes[settings.CombatMode]) then
            return sets.CombatModes[settings.CombatMode];
        else
            return sets.Engaged;
        end
    else
        -- When not engaged, use appropriate idle set based on pet status
        if (pet and pet.isvalid) then
            return sets.PetIdle[settings.PetMode];
        else
            return sets.Idle;
        end
    end
end

profile.HandleDefault = function()
    if (settings.TeleportActive) then
        return;
    end

    local player = gData.GetPlayer();
    local pet = gData.GetPet();
    local env = gData.GetEnvironment();
    local inAdoulin = false;
    if (env ~= nil and env.Area ~= nil) then
        local area = env.Area;
        if (area == 'Western Adoulin' or area == 'Eastern Adoulin') then
            inAdoulin = true;
        end
    end

    thModule.update_target(player);

    local petAction = gData.GetPetAction();
    if (petActions.handle(petAction, sets, Equip)) then
            return;
    end

    local baseSet = GetBaseSet();
    if (baseSet ~= nil) then
        Equip.Set(baseSet);
    end

    thModule.apply_overlay(Equip, sets.TH);
    thModule.maybe_clear_on_tp_gain(player);

    if (sets.Movement and player ~= nil and player.Status ~= 'Engaged' and player.IsMoving == true) then
        Equip.Set(sets.Movement);
    end

    if (inAdoulin and sets.Adoulin) then
        Equip.Set(sets.Adoulin);
    end

    animator.ensure_animator(not thModule.is_pending());
    autoManeuver.tick(player, pet);
end

profile.HandleAbility = function()
    thModule.clear_on_action('ability');
    local ability = gData.GetAction();

    if (ability.Name == 'Deploy') then
        Equip.Set(sets.Deploy);
    elseif (ability.Name == 'Activate') then
        Equip.Set(sets.Activate);
    elseif (ability.Name == 'Repair') then
        -- Use special repair sets when in PupOnly or Turtle mode for repair potency
        if (settings.PupOnly) then
            Equip.Set(sets.RepairPupOnly);
        elseif (settings.TurtleMode) then
            Equip.Set(sets.RepairTurtle);
        else
            Equip.Set(sets.Repair);
        end
    elseif (ability.Name == 'Maintenance') then
        Equip.Set(sets.Maintenance);
    elseif (ability.Name == 'Ventriloquy') then
        Equip.Set(sets.Ventriloquy);
    elseif (ability.Name == 'Tactical Switch') then
        Equip.Set(sets.TacticalSwitch);
    elseif (ability.Name == 'Overdrive') then
        Equip.Set(sets.Overdrive);
    elseif (string.find(ability.Name, 'Maneuver')) then
        Equip.Set(sets.Maneuver);
    elseif (string.find(ability.Name, 'Waltz')) then
        Equip.Set(sets.Waltz);
    end
end

profile.HandleWeaponskill = function()
    thModule.clear_on_action('weaponskill');
    local ws = gData.GetAction();

    -- Use specific sets for each weapon skill
    if (sets.WeaponSkill[ws.Name]) then
        print('Using ' .. ws.Name .. ' set');
        Equip.Set(sets.WeaponSkill[ws.Name]);
    else
        print('Using default WS set for: ' .. ws.Name);
        Equip.Set(sets.WeaponSkill.Default);
    end
end

profile.HandlePrecast = function()
    thModule.clear_on_action('precast');
    local spell = gData.GetAction();

    if (spell.Name == 'Utsusemi: Ichi' or spell.Name == 'Utsusemi: Ni') then
        Equip.Set(sets.Utsusemi.Precast);
    else
        Equip.Set(sets.Precast);
    end
end

profile.HandleMidcast = function()
    local spell = gData.GetAction();

    if (spell.Name == 'Utsusemi: Ichi' or spell.Name == 'Utsusemi: Ni') then
        Equip.Set(sets.Utsusemi.Midcast);
    end
end

profile.HandleItem = function()
    itemHandler();
end

profile.HandleAftercast = function()
    -- Call HandleDefault to refresh gear after abilities finish
    profile.HandleDefault();
end



return profile
