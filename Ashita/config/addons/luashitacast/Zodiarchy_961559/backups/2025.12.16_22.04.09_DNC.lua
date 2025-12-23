require('common');

local Equip = gFunc.LoadFile('common/equip.lua');
local Status = gFunc.LoadFile('common/status.lua');
local itemHandler = gFunc.LoadFile('common/items.lua');
local thModule = gFunc.LoadFile('Zodiarchy_961559/lib/th.lua');

local profile = {};

local settings = {
    MeleeMode = 'Default',   -- Default, Acc, Hybrid
    WSMode = 'Default',      -- Default, Acc, Hybrid
    IdleMode = 'Default',    -- Default, Regen, Refresh
    DTMode = false,
    HybridMode = false,
    MovementMode = false,
    THMode = false,
    TeleportActive = false,  -- Blocks swaps while using rings/tele items
};

local sets = {
    -- Idle / misc
    Idle = Equip.NewSet {
        -- Fill idle gear here
    },
    IdleRegen = Equip.NewSet {
        -- Regen-focused idle pieces
    },
    IdleRefresh = Equip.NewSet {
        -- Refresh-focused idle pieces
    },
    Town = Equip.NewSet {
        -- Style set for town
    },
    Movement = Equip.NewSet {
        -- Movement speed pieces
    },
    DT = Equip.NewSet {
        -- Full damage taken set
    },
    Naked = Equip.NewSet {
        -- Leave empty for naked state (useful in sortie)
    },

    -- TP
    Engaged = Equip.NewSet {
        -- Default TP
    },
    EngagedAcc = Equip.NewSet {
        -- Accuracy-focused TP
    },
    EngagedHybrid = Equip.NewSet {
        -- Hybrid TP/DT
    },

    -- Ranged (rare on DNC but kept for completeness)
    Preshot = Equip.NewSet {},
    Midshot = Equip.NewSet {},

    -- Job abilities
    Steps = Equip.NewSet {
        -- Accuracy gear for steps
    },
    ViolentFlourish = Equip.NewSet {
        -- M.Acc gear for stun
    },
    Samba = Equip.NewSet {
        -- DT/haste safe set during samba animation
    },
    Waltz = Equip.NewSet {
        -- Waltz potency/CHR/VE
    },
    Climactic = Equip.NewSet {
        -- On ability use and while buff is active
    },
    Striking = Equip.NewSet {
        -- On ability use and while buff is active
    },
    FanDance = Equip.NewSet {
        -- While Fan Dance buff active
    },
    SaberDance = Equip.NewSet {
        -- While Saber Dance buff active
    },

    -- Enmity / utility
    Enmity = Equip.NewSet {
        -- Provoke / Animated Flourish
    },
    TH = Equip.NewSet {
        -- Treasure Hunter pieces
    },

    -- Fast cast / spells
    Precast = Equip.NewSet {
        -- Fast cast / snapshot
    },

    -- Weapon skills
    WeaponSkill = {
        Default = Equip.NewSet {
            -- Generic WS set
        },
        Acc = Equip.NewSet {
            -- WS accuracy variant
        },
        Hybrid = Equip.NewSet {
            -- WS hybrid DT variant
        },
        ['Rudra\'s Storm'] = Equip.NewSet {
            -- DEX/WS damage
        },
        ['Evisceration'] = Equip.NewSet {
            -- Crit/DEX
        },
        ['Pyrrhic Kleos'] = Equip.NewSet {
            -- Multi-hit
        },
        ['Aeolian Edge'] = Equip.NewSet {
            -- Magic WS
        },
        ['Exenterator'] = Equip.NewSet {
            -- AGI/acc
        },
    },
};

profile.Sets = sets;
thModule.init(settings);

-- Helpers
local function get_idle_set()
    if settings.IdleMode == 'Regen' then
        return sets.IdleRegen;
    elseif settings.IdleMode == 'Refresh' then
        return sets.IdleRefresh;
    end
    return sets.Idle;
end

local function get_engaged_set()
    if settings.DTMode then
        return sets.DT;
    elseif settings.HybridMode then
        return sets.EngagedHybrid;
    elseif settings.MeleeMode == 'Acc' then
        return sets.EngagedAcc;
    end
    return sets.Engaged;
end

local function get_ws_base()
    if settings.WSMode == 'Acc' then
        return sets.WeaponSkill.Acc;
    elseif settings.WSMode == 'Hybrid' then
        return sets.WeaponSkill.Hybrid;
    end
    return sets.WeaponSkill.Default;
end

profile.OnLoad = function()
    gSettings.AllowAddSet = true;

    AshitaCore:GetChatManager():QueueCommand(1, '/alias /meleemode /lac fwd meleemode');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /dt /lac fwd dt');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /hybrid /lac fwd hybrid');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /movement /lac fwd movement');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /th /lac fwd th');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /idle /lac fwd idle');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /wsset /lac fwd wsset');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /naked /lac fwd naked');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /refreshgear /lac fwd refresh');

    thModule.set_enabled(settings.THMode);

    print('DNC profile loaded.');
    print('Toggles: /meleemode (default/acc/hybrid), /dt, /hybrid, /movement, /th, /idle (default/regen/refresh), /wsset (default/acc/hybrid), /naked');
end

profile.OnUnload = function()
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /meleemode');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /dt');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /hybrid');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /movement');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /th');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /idle');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /wsset');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /naked');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /refreshgear');
end

profile.HandleCommand = function(args)
    if (args[1] == 'meleemode') then
        if args[2] then
            local mode = string.lower(args[2]);
            if mode == 'default' or mode == 'acc' or mode == 'hybrid' then
                settings.MeleeMode = mode:gsub('^%l', string.upper);
                settings.DTMode = false;
                print('Melee mode: ' .. settings.MeleeMode);
                profile.HandleDefault();
            else
                print('Use: default / acc / hybrid');
            end
        else
            print('Current melee mode: ' .. settings.MeleeMode);
        end
        return;
    elseif (args[1] == 'wsset') then
        if args[2] then
            local mode = string.lower(args[2]);
            if mode == 'default' or mode == 'acc' or mode == 'hybrid' then
                settings.WSMode = mode:gsub('^%l', string.upper);
                print('WS mode: ' .. settings.WSMode);
            else
                print('Use: default / acc / hybrid');
            end
        else
            print('Current WS mode: ' .. settings.WSMode);
        end
        return;
    elseif (args[1] == 'idle') then
        if args[2] then
            local mode = string.lower(args[2]);
            if mode == 'default' or mode == 'regen' or mode == 'refresh' then
                settings.IdleMode = mode:gsub('^%l', string.upper);
                print('Idle mode: ' .. settings.IdleMode);
                profile.HandleDefault();
            else
                print('Use: default / regen / refresh');
            end
        else
            print('Current idle mode: ' .. settings.IdleMode);
        end
        return;
    elseif (args[1] == 'dt') then
        settings.DTMode = not settings.DTMode;
        if settings.DTMode then
            settings.HybridMode = false;
            settings.MeleeMode = 'Default';
        end
        print('DT mode: ' .. (settings.DTMode and 'On' or 'Off'));
        profile.HandleDefault();
        return;
    elseif (args[1] == 'hybrid') then
        settings.HybridMode = not settings.HybridMode;
        if settings.HybridMode then
            settings.DTMode = false;
            settings.MeleeMode = 'Default';
        end
        print('Hybrid mode: ' .. (settings.HybridMode and 'On' or 'Off'));
        profile.HandleDefault();
        return;
    elseif (args[1] == 'movement') then
        settings.MovementMode = not settings.MovementMode;
        print('Movement: ' .. (settings.MovementMode and 'On' or 'Off'));
        profile.HandleDefault();
        return;
    elseif (args[1] == 'th') then
        settings.THMode = not settings.THMode;
        thModule.set_enabled(settings.THMode);
        print('TH mode: ' .. (settings.THMode and 'On' or 'Off'));
        profile.HandleDefault();
        return;
    elseif (args[1] == 'naked') then
        print('Equipping naked set.');
        Equip.Set(sets.Naked);
        return;
    elseif (args[1] == 'refresh') then
        settings.TeleportActive = false;
        settings.DTMode = false;
        settings.HybridMode = false;
        settings.MovementMode = false;
        settings.MeleeMode = 'Default';
        settings.IdleMode = 'Default';
        settings.WSMode = 'Default';
        print('Modes reset; refreshing gear.');
        profile.HandleDefault();
        return;
    end
end

-- Determine baseline set for current state
local function get_base_set()
    local player = gData.GetPlayer();

    if settings.TeleportActive then
        return nil;
    end

    if player.Status == 'Engaged' then
        return get_engaged_set();
    end

    -- Not engaged
    if settings.MovementMode or player.IsMoving then
        return sets.Movement;
    end

    return get_idle_set();
end

profile.HandleDefault = function()
    local player = gData.GetPlayer();
    local baseSet = get_base_set();

    thModule.update_target(player);

    if baseSet ~= nil then
        Equip.Set(baseSet);
    end

    -- Buff overlays
    if Status.HasStatus('Climactic Flourish') and sets.Climactic then
        Equip.Set(sets.Climactic);
    end
    if Status.HasStatus('Striking Flourish') and sets.Striking then
        Equip.Set(sets.Striking);
    end
    if Status.HasStatus('Fan Dance') and sets.FanDance then
        Equip.Set(sets.FanDance);
    end
    if Status.HasStatus('Saber Dance') and sets.SaberDance then
        Equip.Set(sets.SaberDance);
    end

    -- TH overlay on first swing
    thModule.apply_overlay(Equip, sets.TH);
    thModule.maybe_clear_on_tp_gain(player);
end

profile.HandleAbility = function()
    thModule.clear_on_action('ability');
    local ability = gData.GetAction();

    if string.find(ability.Name, 'Step') then
        Equip.Set(sets.Steps);
    elseif ability.Name == 'Violent Flourish' then
        Equip.Set(sets.ViolentFlourish);
    elseif string.find(ability.Name, 'Waltz') then
        Equip.Set(sets.Waltz);
    elseif string.find(ability.Name, 'Samba') then
        Equip.Set(sets.Samba);
    elseif ability.Name == 'Climactic Flourish' then
        Equip.Set(sets.Climactic);
    elseif ability.Name == 'Striking Flourish' then
        Equip.Set(sets.Striking);
    elseif ability.Name == 'Animated Flourish' then
        Equip.Set(sets.Enmity);
    end
end

profile.HandleWeaponskill = function()
    thModule.clear_on_action('weaponskill');
    local ws = gData.GetAction();

    local base = get_ws_base();
    if base then
        Equip.Set(base);
    end

    if sets.WeaponSkill[ws.Name] then
        Equip.Set(sets.WeaponSkill[ws.Name]);
    end

    if Status.HasStatus('Climactic Flourish') and sets.Climactic then
        Equip.Set(sets.Climactic);
    end
    if Status.HasStatus('Striking Flourish') and sets.Striking then
        Equip.Set(sets.Striking);
    end
end

profile.HandlePrecast = function()
    thModule.clear_on_action('precast');
    Equip.Set(sets.Precast);
end

profile.HandleMidcast = function()
    local spell = gData.GetAction();
    if string.find(spell.Name, 'Waltz') then
        Equip.Set(sets.Waltz);
    end
end

profile.HandlePreshot = function()
    Equip.Set(sets.Preshot);
end

profile.HandleMidshot = function()
    Equip.Set(sets.Midshot);
    if settings.THMode then
        Equip.Set(sets.TH);
    end
end

profile.HandleItem = function()
    itemHandler();
end

profile.HandleAftercast = function()
    profile.HandleDefault();
end

return profile;

