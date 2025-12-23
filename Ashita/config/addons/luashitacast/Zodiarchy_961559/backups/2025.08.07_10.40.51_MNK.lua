require('common');

local gear = gFunc.LoadFile('common/gear.lua');
local Equip = gFunc.LoadFile('common/equip.lua');
local Status = gFunc.LoadFile('common/status.lua');
local itemHandler = gFunc.LoadFile('common/items.lua');

local profile = {}

local settings = {
    MeleeMode = 'Default', -- Default, Acc, Hybrid, DT
    ImpetusMode = false, -- Track Impetus buff for special gear swaps
    FootworkMode = false, -- Track Footwork buff
    CounterstanceMode = false, -- Track Counterstance buff
    Weapon = 'Godhands', -- Primary weapon: Godhands, Xiucoatl, Karambit
    DTMode = false, -- Toggle damage taken mode
    HybridMode = false, -- Toggle hybrid DT/DPS mode
    TeleportActive = false, -- Prevent automatic gear changes when teleport item equipped
    IdleEnabled = true, -- Toggle automatic idle gear changes
    MovementMode = false, -- Movement speed mode
    THMode = false, -- Treasure Hunter mode
}

-- Define cape objects for different purposes
local mnkCape = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'Damage taken-5%', [2] = '"Dbl.Atk."+10', [3] = 'Accuracy+20', [4] = 'Attack+20', [5] = 'DEX+30' } };
local wsCape = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'STR+30', [2] = 'Crit.hit rate+10', [3] = 'Attack+20', [4] = 'Accuracy+20' } };

local sets = {

    -- Idle sets
    Idle = Equip.NewSet {
        Main = "Godhands",
        Head = "Mpaca\'s Cap",
        Body = 'Hiza. Haramaki +2',
        Hands = "Herculean Gloves",
        Legs = "Heyoka Subligar +1",
        Feet = "Mpaca\'s Boots",
        Neck = "Shulmanu Collar",
        Waist = "Moonbow Belt +1",
        Ear1 = "Sroda Earring",
        Ear2 = "Mache Earring +1",
        Ring1 = "Gere Ring",
        Ring2 = "Niqmaddu Ring",
        Back = mnkCape,
    },

    -- Regen focused idle (when resting)
    IdleRegen = Equip.NewSet {
        Main = "Godhands",
        Head = "Mpaca\'s Cap",
        Body = 'Hiza. Haramaki +2',
        Hands = "Herculean Gloves",
        Legs = "Heyoka Subligar +1",
        Feet = "Mpaca\'s Boots",
        Neck = "Shulmanu Collar",
        Waist = "Moonbow Belt +1",
        Ear1 = "Sroda Earring",
        Ear2 = "Mache Earring +1",
        Ring1 = "Gere Ring",
        Ring2 = "Niqmaddu Ring",
        Back = mnkCape,
    },

    -- Town/movement set
    Town = Equip.NewSet {
        Main = "Godhands",
        Body = "Councilor's Garb",
        Legs = "Crimson Cuisses",
        Feet = "Herald's Gaiters",
    },

    -- Movement speed set
    Movement = Equip.NewSet {
        Feet = "Herald's Gaiters",
    },

    -- Standard TP sets
    Engaged = Equip.NewSet {
        Main = "Godhands",
        Head = "Mpaca\'s Cap",
        Body = "Mpaca\'s Doublet +2",
        Hands = "Herculean Gloves",
        Legs = "Mpaca\'s Hose",
        Feet = "Herculean Boots",
        Neck = "Shulmanu Collar",
        Waist = "Moonbow Belt +1",
        Ear1 = "Mache Earring +1",
        Ear2 = "Mache Earring +1",
        Ring1 = "Gere Ring",
        Ring2 = "Niqmaddu Ring",
        Back = mnkCape,
    },

    -- High Accuracy TP set
    EngagedAcc = Equip.NewSet {
        Main = "Godhands",
        Head = "Mpaca\'s Cap",
        Body = "Malignance Tabard",
        Hands = "Herculean Gloves",
        Legs = "Mpaca\'s Hose",
        Feet = "Herculean Boots",
        Neck = "Shulmanu Collar",
        Waist = "Moonbow Belt +1",
        Ear1 = "Mache Earring +1",
        Ear2 = "Zennaroi Earring",
        Ring1 = "Gere Ring",
        Ring2 = "Chirich Ring +1",
        Back = mnkCape,
    },

    -- Hybrid DT/DPS set
    EngagedHybrid = Equip.NewSet {
        Main = "Godhands",
        Head = "Mpaca\'s Cap",
        Body = "Malignance Tabard",
        Hands = "Herculean Gloves",
        Legs = "Mpaca\'s Hose",
        Feet = { Name = 'Herculean Boots', Augment = { [1] = 'Accuracy+19', [2] = 'CHR+3', [3] = 'Attack+11', [4] = '"Triple Atk."+4' } },
        Neck = "Shulmanu Collar",
        Waist = "Moonbow Belt +1",
        Ear1 = "Mache Earring +1",
        Ear2 = "Mache Earring +1",
        Ring1 = "Gere Ring",
        Ring2 = "Niqmaddu Ring",
        Back = mnkCape,
    },

    -- Full DT set
    DT = Equip.NewSet {
        Main = "Godhands",
        Head = "Mpaca\'s Cap",
        Body = "Malignance Tabard",
        Hands = "Herculean Gloves",
        Legs = "Mpaca\'s Hose",
        Feet = { Name = 'Herculean Boots', Augment = { [1] = 'Accuracy+19', [2] = 'CHR+3', [3] = 'Attack+11', [4] = '"Triple Atk."+4' } },
        Neck = "Shulmanu Collar",
        Waist = "Moonbow Belt +1",
        Ear1 = "Mache Earring +1",
        Ear2 = "Mache Earring +1",
        Ring1 = "Gelatinous Ring +1",
        Ring2 = "Niqmaddu Ring",
        Back = mnkCape,
    },

    -- Weapon Skills
    WeaponSkill = {
        -- Victory Smite - STR-based, crit rate varies by TP
        ['Victory Smite'] = Equip.NewSet {
            Main = "Godhands",
            Head = "Mpaca\'s Cap",
            Body = "Hiza. Haramaki +2",
            Hands = "Herculean Gloves",
            Legs = "Hiza. Hizayoroi +2",
            Feet = "Hiza. Sune-Ate +2",
            Neck = "Fotia Gorget",
            Waist = "Fotia Belt",
            Ear1 = "Mache Earring +1",
            Ear2 = "Mache Earring +1",
            Ring1 = "Gere Ring",
            Ring2 = "Rajas Ring",
            Back = wsCape,
        },

        -- Shijin Spiral - DEX-based WS
        ['Shijin Spiral'] = Equip.NewSet {
            Main = "Godhands",
            Head = "Mpaca\'s Cap",
            Body = "Malignance Tabard",
            Hands = "Herculean Gloves",
            Legs = "Hiza. Hizayoroi +2",
            Feet = "Tali'ah Crackows +2",
            Neck = "Fotia Gorget",
            Waist = "Fotia Belt",
            Ear1 = "Mache Earring +1",
            Ear2 = "Mache Earring +1",
            Ring1 = "Gere Ring",
            Ring2 = "Rajas Ring",
            Back = wsCape,
        },

        -- Asuran Fists - STR-based, 8-hit (accuracy important)
        ['Asuran Fists'] = Equip.NewSet {
            Main = "Godhands",
            Head = "Mpaca\'s Cap",
            Body = "Malignance Tabard",
            Hands = "Herculean Gloves",
            Legs = "Hiza. Hizayoroi +2",
            Feet = "Tali'ah Crackows +2",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Zennaroi Earring",
            Ear2 = "Mache Earring +1",
            Ring1 = "Gere Ring",
            Ring2 = "Varar Ring +1",
            Back = wsCape,
        },

        -- Default fallback for other weapon skills
        Default = Equip.NewSet {
            Main = "Godhands",
            Head = "Mpaca\'s Cap",
            Body = "Malignance Tabard",
            Hands = "Herculean Gloves",
            Legs = "Hiza. Hizayoroi +2",
            Feet = "Tali'ah Crackows +2",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Sroda Earring",
            Ear2 = "Mache Earring +1",
            Ring1 = "Gere Ring",
            Ring2 = "Varar Ring +1",
            Back = wsCape,
        },
    },

    -- Job Abilities
    Focus = Equip.NewSet {
        Head = "Anchorite\'s Crown",
    },

    Dodge = Equip.NewSet {
        Feet = "Mpaca\'s Boots", -- Using available boots with evasion
    },

    Chakra = Equip.NewSet {
        Body = "Hiza. Haramaki +2", -- Good for chakra healing
        Hands = "Herculean Gloves",
    },

    FootworkJA = Equip.NewSet {
        Feet = "Hiza. Sune-Ate +2", -- Best available kick attack gear
    },

    Footwork = Equip.NewSet {
        Feet = "Hiza. Sune-Ate +2", -- While buff is active
    },

    HundredFists = Equip.NewSet {
        Legs = "Hiza. Hizayoroi +2", -- Enhances Hundred Fists
    },

    FormlessStrikes = Equip.NewSet {
        Body = "Hiza. Haramaki +2", -- Enhances Formless Strikes
    },

    Counterstance = Equip.NewSet {
        Feet = "Hiza. Sune-Ate +2", -- Also used for Mantra
    },

    Mantra = Equip.NewSet {
        Feet = "Hiza. Sune-Ate +2",
    },

    -- Impetus buff override (worn while buff is active)
    Impetus = Equip.NewSet {
        Body = "Hiza. Haramaki +2", -- Enhances Impetus effect
    },

    -- Fast Cast
    Precast = Equip.NewSet {
        Ear1 = "Loquacious Earring",
        Ring1 = "Prolix Ring",
    },

    -- Treasure Hunter set
    TH = Equip.NewSet {
        Waist = "Chaac Belt",
        Feet = { Name = 'Herculean Boots', Augment = { [1] = 'Accuracy+19', [2] = 'CHR+3', [3] = 'Attack+11', [4] = '"Treasure Hunter"+2' } },
    },

    -- Teleportation rings
    WarpRing = Equip.NewSet {
        Ring1 = "Warp Ring",
    },

    DimRing = Equip.NewSet {
        Ring1 = "Dim. Ring (Holla)",
    },

    -- Waltz set
    Waltz = Equip.NewSet {
        Body = "Passion Jacket", -- Enhances Waltz
    },
}

-- Function to update weapon in all relevant sets
local function UpdateWeapon()
    local weapon = settings.Weapon;
    
    -- Update all sets with current weapon
    sets.Idle.Main = weapon;
    sets.IdleRegen.Main = weapon;
    sets.Town.Main = weapon;
    sets.Engaged.Main = weapon;
    sets.EngagedAcc.Main = weapon;
    sets.EngagedHybrid.Main = weapon;
    sets.DT.Main = weapon;
    
    -- Update weapon skill sets
    for wsName, wsSet in pairs(sets.WeaponSkill) do
        wsSet.Main = weapon;
    end
    
    -- Refresh current gear
    profile.HandleDefault();
end

profile.Sets = sets

profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    gFunc.LockStyle(sets.Idle); -- Lock to idle gear appearance
    
    -- Chat aliases/commands
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /meleemode /lac fwd meleemode');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /dt /lac fwd dt');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /hybrid /lac fwd hybrid');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /godhands /lac fwd godhands');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /xiucoatl /lac fwd xiucoatl');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /karambit /lac fwd karambit');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /warpring /lac fwd warpring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /dimring /lac fwd dimring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /refresh /lac fwd refresh');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /movement /lac fwd movement');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /th /lac fwd th');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /idle /lac fwd idle');
    
    -- Register hotkey for DEL key (Vile Elixir)
    AshitaCore:GetChatManager():QueueCommand(1, '/bind delete /lac fwd vileelixir');
    
    print('MNK Profile Loaded');
    print('Commands: /meleemode (default/acc/hybrid), /dt, /hybrid, /movement, /th');
    print('Weapons: /godhands, /xiucoatl, /karambit');
    print('Teleport: /warpring, /dimring, /refresh');
    print('Idle Control: /idle on/off - Toggle automatic gear changes');
    print('Hotkey: DEL key for Vile Elixir items');
end

profile.OnUnload = function()
    -- Clean up aliases
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /meleemode');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /dt');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /hybrid');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /godhands');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /xiucoatl');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /karambit');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /warpring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /dimring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /refresh');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /movement');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /th');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /idle');
    
    -- Unbind DEL key
    AshitaCore:GetChatManager():QueueCommand(1, '/unbind delete');
end

profile.HandleCommand = function(args)
    if (args[1] == 'meleemode') then
        if (args[2] ~= nil) then
            local mode = string.lower(args[2]);
            if (mode == 'default' or mode == 'acc' or mode == 'hybrid') then
                settings.MeleeMode = mode:gsub("^%l", string.upper);
                -- Clear conflicting modes
                if settings.MeleeMode ~= 'Default' then
                    settings.DTMode = false;
                    settings.HybridMode = false;
                end
                print('Melee mode set to: ' .. settings.MeleeMode);
                profile.HandleDefault();
            else
                print('Invalid mode. Use: default, acc, or hybrid');
            end
        else
            print('Current melee mode: ' .. settings.MeleeMode);
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
        print('Movement mode: ' .. (settings.MovementMode and 'On' or 'Off'));
        profile.HandleDefault();
        return;
    elseif (args[1] == 'th') then
        settings.THMode = not settings.THMode;
        print('Treasure Hunter mode: ' .. (settings.THMode and 'On' or 'Off'));
        profile.HandleDefault();
        return;
    elseif (args[1] == 'godhands') then
        settings.Weapon = 'Godhands';
        UpdateWeapon();
        print('Weapon set to: Godhands');
        return;
    elseif (args[1] == 'xiucoatl') then
        settings.Weapon = 'Xiucoatl';
        UpdateWeapon();
        print('Weapon set to: Xiucoatl');
        return;
    elseif (args[1] == 'karambit') then
        settings.Weapon = 'Karambit';
        UpdateWeapon();
        print('Weapon set to: Karambit');
        return;
    elseif (args[1] == 'warpring') then
        settings.TeleportActive = true;
        print('Warp Ring equipped - Use /refresh to return to normal gear');
        gFunc.ForceEquip(14, "Warp Ring");
        return;
    elseif (args[1] == 'dimring') then
        settings.TeleportActive = true;
        print('Dimensional Ring equipped - Use /refresh to return to normal gear');
        gFunc.ForceEquip(14, "Dim. Ring (Holla)");
        return;
    elseif (args[1] == 'refresh') then
        settings.TeleportActive = false;
        settings.DTMode = false;
        settings.HybridMode = false;
        settings.MovementMode = false;
        settings.MeleeMode = 'Default';
        print('Returning to normal gear');
        profile.HandleDefault();
        return;
    elseif (args[1] == 'idle') then
        if (args[2] ~= nil) then
            local state = string.lower(args[2]);
            if (state == 'on') then
                settings.IdleEnabled = true;
                print('Idle gear changes: ON');
                profile.HandleDefault();
            elseif (state == 'off') then
                settings.IdleEnabled = false;
                print('Idle gear changes: OFF');
            else
                print('Invalid state. Use: /idle on or /idle off');
            end
        else
            print('Idle gear changes: ' .. (settings.IdleEnabled and 'ON' or 'OFF'));
        end
        return;
    elseif (args[1] == 'vileelixir') then
        -- Vile Elixir search and use logic (copied from PUP.lua)
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local resx = AshitaCore:GetResourceManager();
        local containers = { 0, 8, 10, 11, 12, 13, 14, 15, 16 };
        
        print('Searching for Vile Elixir items...');
        
        -- First pass: Search specifically for Vile Elixir +1
        for _, container in ipairs(containers) do
            for index = 0, 80 do
                local item = inv:GetContainerItem(container, index);
                if item and item.Id > 0 then
                    local itemName = resx:GetItemById(item.Id).Name[1];
                    
                    if string.find(string.lower(itemName), "vile elixir") then
                        print('Found potential Vile Elixir item: "' .. itemName .. '" (ID: ' .. item.Id .. ')');
                    end
                    
                    if itemName == "Vile Elixir +1" or itemName == "Vile Elixir+1" or string.find(string.lower(itemName), "vile elixir%+1") then
                        print('Using Vile Elixir +1');
                        AshitaCore:GetChatManager():QueueCommand(1, '/item "' .. itemName .. '" <me>');
                        return;
                    end
                end
            end
        end
        
        -- Second pass: regular Vile Elixir
        for _, container in ipairs(containers) do
            for index = 0, 80 do
                local item = inv:GetContainerItem(container, index);
                if item and item.Id > 0 then
                    local itemName = resx:GetItemById(item.Id).Name[1];
                    
                    if itemName == "Vile Elixir" and not string.find(string.lower(itemName), "%+1") then
                        print('Using Vile Elixir');
                        AshitaCore:GetChatManager():QueueCommand(1, '/item "' .. itemName .. '" <me>');
                        return;
                    end
                end
            end
        end
        
        print('No Vile Elixir items found in inventory');
        return;
    end
end

-- Function to get the appropriate base set
local function GetBaseSet()
    local player = gData.GetPlayer();
    
    -- Check if we're in a town
    local env = gData.GetEnvironment();
    if (env.Area == "Western Adoulin" or env.Area == "Eastern Adoulin") then
        return sets.Town;
    end
    
    -- Check for movement mode
    if (settings.MovementMode or player.IsMoving) then
        return sets.Movement;
    end
    
    -- Check for damage modes
    if (settings.DTMode) then
        return sets.DT;
    elseif (settings.HybridMode) then
        return sets.EngagedHybrid;
    end
    
    -- Handle different player states
    if (player.Status == 'Engaged') then
        if (settings.MeleeMode == 'Acc') then
            return sets.EngagedAcc;
        elseif (settings.MeleeMode == 'Hybrid') then
            return sets.EngagedHybrid;
        else
            return sets.Engaged;
        end
    elseif (player.Status == 'Resting') then
        return sets.IdleRegen;
    else
        -- Normal idle
        if (settings.IdleEnabled) then
            return sets.Idle;
        else
            return nil;
        end
    end
end

profile.HandleDefault = function()
    -- Skip automatic gear changes if teleport item is active
    if (settings.TeleportActive) then
        return;
    end
    
    local player = gData.GetPlayer();
    
    -- Get base set
    local baseSet = GetBaseSet();
    if (baseSet ~= nil) then
        Equip.Set(baseSet);
        
        -- Apply buff-specific gear overrides
        if (Status.HasStatus('Impetus') and sets.Impetus) then
            Equip.Set(sets.Impetus);
            settings.ImpetusMode = true;
        else
            settings.ImpetusMode = false;
        end
        
        if (Status.HasStatus('Footwork') and sets.Footwork) then
            Equip.Set(sets.Footwork);
            settings.FootworkMode = true;
        else
            settings.FootworkMode = false;
        end
        
        if (Status.HasStatus('Counterstance') and sets.Counterstance) then
            Equip.Set(sets.Counterstance);
            settings.CounterstanceMode = true;
        else
            settings.CounterstanceMode = false;
        end
        
        -- Apply TH gear if mode is active
        if (settings.THMode) then
            Equip.Set(sets.TH);
        end
    end
end

profile.HandleAbility = function()
    local ability = gData.GetAction();
    
    if (ability.Name == 'Focus') then
        Equip.Set(sets.Focus);
    elseif (ability.Name == 'Dodge') then
        Equip.Set(sets.Dodge);
    elseif (ability.Name == 'Chakra') then
        Equip.Set(sets.Chakra);
    elseif (ability.Name == 'Footwork') then
        Equip.Set(sets.FootworkJA);
    elseif (ability.Name == 'Hundred Fists') then
        Equip.Set(sets.HundredFists);
    elseif (ability.Name == 'Formless Strikes') then
        Equip.Set(sets.FormlessStrikes);
    elseif (ability.Name == 'Counterstance' or ability.Name == 'Mantra') then
        Equip.Set(sets.Counterstance);
    elseif (string.find(ability.Name, 'Waltz')) then
        Equip.Set(sets.Waltz);
    end
end

profile.HandleWeaponskill = function()
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
    local spell = gData.GetAction();
    Equip.Set(sets.Precast);
end

profile.HandleMidcast = function()
    local spell = gData.GetAction();
    -- Apply TH gear during midcast if mode is active
    if (settings.THMode) then
        Equip.Set(sets.TH);
    end
end

profile.HandleItem = function()
    itemHandler();
end

profile.HandleAftercast = function()
    -- Return to default gear after abilities/spells finish
    profile.HandleDefault();
end

return profile
