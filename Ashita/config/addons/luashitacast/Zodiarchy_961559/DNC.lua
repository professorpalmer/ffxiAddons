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
    THMode = false,
    TeleportActive = false,  -- Blocks swaps while using rings/tele items
};

local sets = {
    -- Idle / misc
    Idle = Equip.NewSet {
        Head = 'Malignance Chapeau',
        Body = 'Malignance Tabard',
        Hands = 'Malignance Gloves',
        Legs = 'Malignance Tights',
        Feet = 'Malignance Boots',
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
        Feet = 'Tandava Crackows',
    },
    Adoulin = Equip.NewSet {
        Body = "Councilor's Garb",
    },
    DT = Equip.NewSet {
        -- Full damage taken set
    },
    Naked = Equip.NewSet {
        -- Leave empty for naked state (useful in sortie)
    },

    -- TP
    Engaged = Equip.NewSet {
        Ammo = 'Coiste Bodhar',
        Head = 'Malignance Chapeau',
        Neck = { Name = 'Etoile Gorget +2', AugPath = 'A' },
        Ear1 = 'Sherida Earring',
        Ear2 = { Name = 'Macu. Earring +2', Augment = { [1] = 'Mag. Acc.+16', [2] = 'Accuracy+16', [3] = 'AGI+7', [4] = '"Store TP"+6', [5] = 'DEX+7' } },
        Body = 'Malignance Tabard',
        Hands = 'Malignance Gloves',
        Ring1 = 'Gere Ring',
        Ring2 = 'Epona\'s Ring',
        Back = 'Null Shawl',
        Waist = { Name = 'Sailfi Belt +1', AugPath = 'A' },
        Legs = 'Malignance Tights',
        Feet = 'Malignance Boots',
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
        Head = 'Maxixi Tiara +2',
        Hands = 'Maxixi Bangles +1',
        Legs = 'Maxixi Slops +2',
        Feet = 'Horos Toe Shoes +1',
    },

    Jigs = Equip.NewSet {
        Legs = 'Horos Tights +3'
    },
    ReverseFlourish = Equip.NewSet {
        -- TP return on Reverse Flourish
        Hands = "Maculele Bangles",
    },
    NoFootRise = Equip.NewSet {
        -- Conserve TP / job ability utility
        Body = "Horos Casaque +1"
    },

    ViolentFlourish = Equip.NewSet {
        Body = "Horos Casaque +1"
    },

    Samba = Equip.NewSet {
        Head = 'Maxixi Tiara +2',
        --Back = Null Shawl
    },

    Waltz = Equip.NewSet {
        Head = 'Horos Tiara +1',
        Body = 'Maxixi Casaque +2',
        Neck = { Name = 'Etoile Gorget +2', AugPath = 'A' },
        Feet = 'Maxixi Toe Shoes +1'

    },
    Climactic = Equip.NewSet {
        -- On ability use and while buff is active
        Head = "Maculele Tiara",
    },

    Striking = Equip.NewSet {
        -- On ability use and while buff is active
        Body = "Maculele Casaque"
    },

    FanDance = Equip.NewSet {
        -- While Fan Dance buff active
        Hands = "Horos Bangles +3",
    },

    SaberDance = Equip.NewSet {
        -- While Saber Dance buff active
        Legs = "Horos Tights +3",
    },

    -- Enmity / utility
    Enmity = Equip.NewSet {
        -- Provoke / Animated Flourish
    },
    TH = Equip.NewSet {
        Ammo = 'Per. Lucky Egg',
        Hands = { Name = 'Herculean Gloves', Augment = { [1] = 'Weapon Skill Acc.+19', [2] = 'Mag. Acc.+1', [3] = 'STR+11', [4] = '"Mag. Atk. Bns."+1', [5] = '"Treasure Hunter"+1' } },
        Feet = { Name = 'Herculean Boots', Augment = { [1] = 'Mag. Acc.+16', [2] = 'Accuracy+8', [3] = '"Mag. Atk. Bns."+16', [4] = 'MND+12', [5] = '"Treasure Hunter"+2' } },
    },

    -- Fast cast / spells
    Precast = Equip.NewSet {
        -- Fast cast / snapshot
    },

    -- Weapon skills
    WeaponSkill = {
        Default = Equip.NewSet {
            -- Generic WS set
            Ammo = 'Coiste Bodhar',
            Head = 'Maculele Tiara',
            Body = 'Nyame Mail',
            Hands = 'Nyame Gauntlets',
            Legs = 'Nyame Flanchard',
            Feet = 'Nyame Sollerets',
            Neck = 'Etoile Gorget +2',
            Waist = 'Sailfi Belt +1',
            Ear1 = 'Sherida Earring',
            Ear2 = 'Macu. Earring +2',
            Ring1 = 'Gere Ring',
            Ring2 = 'Rajas Ring',
            --Back = AgiDAcape,
        },

        ['Rudra\'s Storm'] = Equip.NewSet {
            -- DEX/WS damage
            Ammo = 'Coiste Bodhar',
            Head = 'Maculele Tiara',
            Body = 'Nyame Mail',
            Hands = 'Nyame Gauntlets',
            Legs = 'Nyame Flanchard',
            Feet = 'Nyame Sollerets',
            Neck = 'Etoile Gorget +2',
            Waist = 'Sailfi Belt +1',
            Ear1 = 'Sherida Earring',
            Ear2 = 'Macu. Earring +2',
            Ring1 = 'Gere Ring',
            Ring2 = 'Rajas Ring',
            --Back = AgiDAcape,
        },
        ['Evisceration'] = Equip.NewSet {
            -- Crit/DEX
            Ammo = 'Charis Feather',
            Head = 'Maculele Tiara',
            Body = 'Nyame Mail',
            Hands = 'Nyame Gauntlets',
            Legs = 'Nyame Flanchard',
            Feet = 'Nyame Sollerets',
            Neck = 'Fotia Gorget',
            Waist = 'Fotia Belt',
            Ear1 = 'Sherida Earring',
            Ear2 = 'Macu. Earring +2',
            Ring1 = 'Gere Ring',
            Ring2 = 'Rajas Ring',
            --Back = AgiDAcape,
        },
        ['Pyrrhic Kleos'] = Equip.NewSet {
            -- Multi-hit
            Ammo = 'Coiste Bodhar',
            Head = 'Maculele Tiara',
            Body = 'Nyame Mail',
            Hands = 'Nyame Gauntlets',
            Legs = 'Nyame Flanchard',
            Feet = 'Nyame Sollerets',
            Neck = 'Etoile Gorget +2',
            Waist = 'Sailfi Belt +1',
            Ear1 = 'Sherida Earring',
            Ear2 = 'Macu. Earring +2',
            Ring1 = 'Gere Ring',
            Ring2 = 'Rajas Ring',
            --Back = AgiDAcape,
        },
        ['Aeolian Edge'] = Equip.NewSet {
            -- Magic WS
            Ammo = 'Coiste Bodhar',
            Head = 'Maculele Tiara',
            Body = 'Nyame Mail',
            Hands = 'Nyame Gauntlets',
            Legs = 'Nyame Flanchard',
            Feet = 'Nyame Sollerets',
            Neck = 'Etoile Gorget +2',
            Waist = 'Sailfi Belt +1',
            Ear1 = 'Sherida Earring',
            Ear2 = 'Macu. Earring +2',
            Ring1 = 'Gere Ring',
            Ring2 = 'Rajas Ring',
            --Back = AgiDAcape,
        },
        ['Exenterator'] = Equip.NewSet {
            -- AGI/acc
            Ammo = 'Coiste Bodhar',
            Head = 'Maculele Tiara',
            Body = 'Nyame Mail',
            Hands = 'Nyame Gauntlets',
            Legs = 'Nyame Flanchard',
            Feet = 'Nyame Sollerets',
            Neck = 'Etoile Gorget +2',
            Waist = 'Sailfi Belt +1',
            Ear1 = 'Sherida Earring',
            Ear2 = 'Macu. Earring +2',
            Ring1 = 'Gere Ring',
            Ring2 = 'Rajas Ring',
            --Back = AgiDAcape,
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
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /th /lac fwd th');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /idle /lac fwd idle');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /wsset /lac fwd wsset');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /naked /lac fwd naked');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /warpring /lac fwd warpring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /dimring /lac fwd dimring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /refreshgear /lac fwd refresh');

    thModule.set_enabled(settings.THMode);

    print('DNC profile loaded.');
    print('Toggles: /meleemode (default/acc/hybrid), /dt, /hybrid, /th, /idle (default/regen/refresh), /wsset (default/acc/hybrid), /naked');
    print('Teleport: /warpring, /dimring');
    print('Movement gear auto-equips when moving outside of combat');
end

profile.OnUnload = function()
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /meleemode');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /dt');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /hybrid');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /th');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /idle');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /wsset');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /naked');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /warpring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /dimring');
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
    elseif (args[1] == 'warpring') then
        settings.TeleportActive = true;
        print('Warp Ring equipped - Using in 10 seconds...');
        gFunc.ForceEquip('Ring2', 'Warp Ring');
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
        gFunc.ForceEquip('Ring2', 'Dim. Ring (Holla)');
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

    -- Not engaged - return idle set (movement is handled as overlay in HandleDefault)
    return get_idle_set();
end

profile.HandleDefault = function()
    local player = gData.GetPlayer();
    local env = gData.GetEnvironment();
    local inAdoulin = false;
    if (env ~= nil and env.Area ~= nil) then
        local area = env.Area;
        if (area == 'Western Adoulin' or area == 'Eastern Adoulin') then
            inAdoulin = true;
        end
    end

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

    if (sets.Movement and player ~= nil and player.Status ~= 'Engaged' and player.IsMoving == true) then
        Equip.Set(sets.Movement);
    end

    if (inAdoulin and sets.Adoulin) then
        Equip.Set(sets.Adoulin);
    end
end

profile.HandleAbility = function()
    thModule.clear_on_action('ability');
    local ability = gData.GetAction();

    if string.find(ability.Name, 'Step') then
        Equip.Set(sets.Steps);
    elseif string.find(ability.Name, 'Jig') then
        Equip.Set(sets.Jigs);
    elseif ability.Name == 'Reverse Flourish' then
        Equip.Set(sets.ReverseFlourish);
    elseif ability.Name == 'No Foot Rise' then
        Equip.Set(sets.NoFootRise);
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

