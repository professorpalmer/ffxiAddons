require('common');

local gear = gFunc.LoadFile('common/gear.lua');
local Equip = gFunc.LoadFile('common/equip.lua');
local Status = gFunc.LoadFile('common/status.lua');
local itemHandler = gFunc.LoadFile('common/items.lua');

local profile = {}

local settings = {
    PetMode = 'Tank', -- Tank, Melee, Range, Magic
    IsTrusted = false, -- For pet trusts
    Weapon = 'Xiucoatl', -- Primary weapon: Xiucoatl (can switch to Karambit if needed)
    PupOnly = false, -- For fights where only automaton is used (Lobo, etc) - toggleable with /puponly
    MasterMode = false, -- For pure master DPS when pet is mage/not used - toggleable with /master
    TeleportActive = false, -- Prevent automatic gear changes when teleport item equipped
    DTMode = false, -- Toggle damage taken mode
    HybridMode = false, -- Toggle hybrid DT/DPS mode
}

-- Define cape objects separately so they can be referenced in sets
local petCape = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'Pet: R.Acc.+20', [2] = 'Pet: R.Atk.+20', [3] = 'Pet: Haste+10', [4] = 'Accuracy+20', [5] = 'Attack+20', [6] = 'Pet: Acc.+20', [7] = 'Pet: Atk.+20' } };
local masterCape = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'Damage taken-5%', [2] = '"Dbl.Atk."+10', [3] = 'Accuracy+20', [4] = 'Attack+20', [5] = 'DEX+30' } };

local sets = {

    -- Idle sets
    Idle = Equip.NewSet {
        Main = "Xiucoatl",
        Range = "Animator P II +1",
        Head = "Heyoka Cap +1",
        Body = "Tali'ah Manteel +2", 
        Hands = "Herculean Gloves",
        Legs = "Heyoka Subligar +1",
        Feet = "Herculean Boots",
        Neck = "Shulmanu Collar",
        Waist = "Moonbow Belt +1",
        Ear1 = "Sroda Earring",
        Ear2 = "Mache Earring +1",
        Ring1 = "Rajas Ring",
        Ring2 = "Epona\'s Ring",
        Back = petCape,
    },

    -- Pet idle sets (when automaton is out)
    PetIdle = {
        Tank = Equip.NewSet {
            Main = "Xiucoatl",
            Range = "Animator P II +1",
            Head = "Heyoka Cap +1",
            Body = "Tali'ah Manteel +2",
            Hands = "Herculean Gloves",
            Legs = "Heyoka Subligar +1", 
            Feet = "Herculean Boots",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Sroda Earring",
            Ear2 = "Mache Earring +1",
            Ring1 = "Rajas Ring",
            Ring2 = "Epona\'s Ring",
            Back = petCape,
        },
        
        Melee = Equip.NewSet {
            Main = "Xiucoatl",
            Range = "Animator P II +1", 
            Head = "Karagoz Capello +1",
            Body = "Karagoz Farsetto +1",
            Hands = "Karagoz Guanti +1",
            Legs = "Karagoz Pantaloni +1",
            Feet = "Karagoz Scarpe +1",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Sroda Earring",
            Ear2 = "Mache Earring +1",
            Ring1 = "Rajas Ring",
            Ring2 = "Epona\'s Ring",
            Back = petCape,
        },
        
        Range = Equip.NewSet {
            Main = "Xiucoatl",
            Range = "Animator P II +1",
            Head = "Karagoz Capello +1",
            Body = "Karagoz Farsetto +1", 
            Hands = "Karagoz Guanti +1",
            Legs = "Karagoz Pantaloni +1",
            Feet = "Karagoz Scarpe +1",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Sroda Earring",
            Ear2 = "Mache Earring +1", 
            Ring1 = "Rajas Ring",
            Ring2 = "Epona\'s Ring",
            Back = petCape,
        },
        
        Magic = Equip.NewSet {
            Main = "Xiucoatl",
            Range = "Animator P II +1",
            Head = "Karagoz Capello +1",
            Body = "Karagoz Farsetto +1",
            Hands = "Karagoz Guanti +1", 
            Legs = "Karagoz Pantaloni +1",
            Feet = "Karagoz Scarpe +1",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Sroda Earring",
            Ear2 = "Mache Earring +1",
            Ring1 = "Rajas Ring",
            Ring2 = "Varar Ring +1",
            Back = petCape,
        },
    },

    -- Pup Only mode (for fights where only automaton is used)
    PupOnly = Equip.NewSet {
        Main = "Xiucoatl",
        Range = "Animator P II +1",
        Head = "Kara. Cappello +2",
        Body = "Pitre Tobe +1",
        Hands = "Karagoz Guanti +2",
        Legs = "Kara. Pantaloni +2",
        Feet = "Foire Babouches +2",
        Neck = "Shulmanu Collar",
        Waist = "Klouskap Sash +1",
        Ear1 = "Burana Earring",
        Ear2 = "Kyrene\'s Earring",
        Ring1 = "Thurandaut Ring",
        Ring2 = "Varar Ring +1",
        Back = petCape,
    },

    -- Master melee sets
    Engaged = Equip.NewSet {
        Main = "Xiucoatl",
        Range = "Animator P II +1",
        Head = "Heyoka Cap +1",
        Body = "Tali'ah Manteel +2",
        Hands = "Herculean Gloves",
        Legs = "Heyoka Subligar +1",
        Feet = "Herculean Boots",
        Neck = "Shulmanu Collar",
        Waist = "Moonbow Belt +1",
        Ear1 = "Sroda Earring",
        Ear2 = "Mache Earring +1    ",
        Ring1 = "Rajas Ring",
        Ring2 = "Epona\'s Ring",
        Back = petCape,
    },

    -- Master DPS mode (for when pet is mage/not used, focus on master damage)
    Master = Equip.NewSet {
        Main = "Xiucoatl",
        Range = "Animator P II +1",
        Head = "Heyoka Cap +1",
        Body = "Tali'ah Manteel +2",
        Hands = "Herculean Gloves",
        Legs = "Heyoka Subligar +1",
        Feet = "Herculean Boots",
        Neck = "Shulmanu Collar", -- Master acc/att focused
        Waist = "Moonbow Belt +1",
        Ear1 = "Sroda Earring",
        Ear2 = "Mache Earring +1",
        Ring1 = "Rajas Ring",
        Ring2 = "Epona\'s Ring",
        Back = masterCape,
    },

    -- Job abilities
    Deploy = Equip.NewSet {
        Main = "Xiucoatl",
        Range = "Animator P II +1",
        Ear1 = "Burana Earring",
    },

    Activate = Equip.NewSet {
        Back = petCape,
    },

    Repair = Equip.NewSet {
        Main = "Xiucoatl",
        Range = "Animator P II +1", 
        Body = "Pup. Tobe",
        Hands = "Karagoz Guanti +1",
        Feet = "Foire Babouches +2",
        Ear1 = "Burana Earring",
        Ear2 = "Guignol Earring",
        Back = petCape,
        Ammo = "Automat. Oil +3",
    },

    -- PupOnly repair set with Nibiru Sainti for repair potency
    RepairPupOnly = Equip.NewSet {
        Main = "Nibiru Sainti",
        Range = "Animator P II +1", 
        Hands = "Karagoz Guanti +1",
        Feet = "Herculean Boots",
        Ear1 = "Burana Earring",
        Ear2 = "Guignol Earring",
        Back = petCape,
        Ammo = "Automat. Oil +3",
    },

    Maintenance = Equip.NewSet {
        Main = "Xiucoatl",
        Range = "Animator P II +1", 
        Hands = "Karagoz Guanti +1",
        Feet = "Herculean Boots",
        Ear1 = "Burana Earring",
        Ear2 = "Guignol Earring",
        Back = "Visucius\'s Mantle",
        Ammo = "Automat. Oil +3",
    },
    
    Maneuver = Equip.NewSet {
        Main = "Xiucoatl",
        Range = "Animator P II +1",
        Body = "Cirque Farsetto +1",
        Hands = "Foire Dastanas +2",
        Legs = "Heyoka Subligar +1",
        Feet = "Tali'ah Crackows +2",
        Neck = "Bfn. Collar +1",
        Waist = "Moonbow Belt +1",
        Ear1 = "Burana Earring",
        Ear2 = "Mache Earring +1",
        Back = petCape,
    },

    Ventriloquy = Equip.NewSet {
        -- Master-focused ventriloquy gear for enmity and survivability
        Main = "Xiucoatl",
        Range = "Animator P II +1",
        Head = "Heyoka Cap +1",
        Body = "Passion Jacket",
        Hands = "Nilas Gloves",
        Legs = "Heyoka Subligar +1",
        Feet = "Tali'ah Crackows +2",
        Neck = "Unmoving Collar +1",
        Waist = "Moonbow Belt +1",
        Ear1 = "Sroda Earring",
        Ear2 = "Mache Earring +1",
        Ring1 = "Rajas Ring",
        Ring2 = "Epona\'s Ring",
        Back = petCape,
    },

    -- Weapon skills (UPDATED)
    WeaponSkill = {
        -- Shijin Spiral - DEX-based katana WS, Light elemental
        ['Shijin Spiral'] = Equip.NewSet {
            Head = "Karagoz Capello +2",           -- DEX+
            Body = "Malignance Tabard",           -- DEX+ WS damage
            Hands = "Pitre Dastanas +3",      -- DEX+ WS damage  
            Legs = "Heyoka Subligar +1",      -- DEX+
            Feet = "Tali'ah Crackows +2",     -- DEX+ WS damage
            Neck = "Fotia Gorget",            -- WS damage+
            Waist = "Fotia Belt",             -- WS damage+
            Ear1 = "Moonshade Earring",       -- TP Bonus (if not 3000 TP)
            Ear2 = "Mache Earring +1",        -- DEX+ accuracy
            Ring1 = "Rajas Ring",             -- Store TP
            Ring2 = "Varar Ring +1",          -- DEX+ WS damage
            Back = masterCape,
        },
        
        -- Victory Smite - STR-based H2H, crit rate varies by TP  
        ['Victory Smite'] = Equip.NewSet {
            Head = "Karagoz Capello +2",           -- DEX+
            Body = "Udug Jacket",     -- STR+ crit hit rate
            Hands = "Pitre Dastanas +3",      -- STR+ WS damage
            Legs = "Tali'ah Seraweels +2",    -- STR+ crit hit rate
            Feet = "Tali'ah Crackows +2",     -- STR+ WS damage
            Neck = "Fotia Gorget",            -- WS damage+
            Waist = "Fotia Belt",             -- WS damage+
            Ear1 = "Moonshade Earring",       -- TP Bonus 
            Ear2 = "Mache Earring +1",        -- STR+ accuracy
            Ring1 = "Rajas Ring",             -- Store TP
            Ring2 = "Varar Ring +1",          -- STR+ WS damage
            Back = masterCape,
        },
        
        -- Asuran Fists - STR-based H2H, 8-hit (accuracy very important)
        ['Asuran Fists'] = Equip.NewSet {
            Head = "Karagoz Capello +2",           -- DEX+
            Body = "Malignance Tabard",           -- STR+ accuracy
            Hands = "Pitre Dastanas +3",      -- STR+ WS damage
            Legs = "Tali'ah Seraweels +2",    -- STR+ accuracy
            Feet = "Tali'ah Crackows +2",     -- STR+ WS damage
            Neck = "Shulmanu Collar",         -- Pet: Accuracy+ (some accuracy for master too)
            Waist = "Moonbow Belt +1",        -- Accuracy+
            Ear1 = "Zennaroi Earring",        -- Accuracy+ (if you have it)
            Ear2 = "Mache Earring +1",        -- STR+ accuracy  
            Ring1 = "Rajas Ring",             -- Store TP
            Ring2 = "Varar Ring +1",          -- STR+ accuracy
            Back = masterCape,
        },
        
        -- Default fallback for any other weapon skills
        Default = Equip.NewSet {
            Main = "Xiucoatl",
            Head = "Karagoz Capello +2",
            Body = "Malignance Tabard",
            Hands = "Pitre Dastanas +3",
            Legs = "Heyoka Subligar +1",
            Feet = "Tali'ah Crackows +2",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Sroda Earring",
            Ear2 = "Mache Earring +1",
            Ring1 = "Rajas Ring",
            Ring2 = "Varar Ring +1",
            Back = masterCape,
        },
    },

    -- Magic sets (for puppet magic)
    Precast = Equip.NewSet {
        Ear1 = "Loquacious Earring",
        Ring1 = "Prolix Ring",
    },

    -- Town/movement set
    Town = Equip.NewSet {
        Main = "Xiucoatl",
        Range = "Animator P II +1",
        Body = "Councilor's Garb",
        Legs = "Crimson Cuisses",
        Feet = "Herald's Gaiters",
    },

    -- Situational sets
    DT = Equip.NewSet {
        Head = "Heyoka Cap +1",
        Body = "Malignance Tabard",
        Hands = "Karagoz Guanti +2",
        Legs = "Kara. Pantaloni +2", 
        Feet = "Tali'ah Crackows +2",
        Ring1 = "Gelatinous Ring +1",
        Back = masterCape,
    },

    -- Hybrid DT/DPS set (balance between damage taken and offensive stats)
    Hybrid = Equip.NewSet {
        Main = { Name = 'Xiucoatl', AugPath='C' },
        Range = 'Animator P II +1',
        Ammo = 'Automat. Oil +3',
        Head = 'Kara. Cappello +2',
        Neck = 'Shulmanu Collar',
        Ear1 = 'Sroda Earring',
        Ear2 = 'Mache Earring +1',
        Body = 'Malignance Tabard',
        Hands = 'Karagoz Guanti +2',
        Ring1 = 'Gelatinous Ring +1',
        Ring2 = 'Epona\'s Ring',
        Back = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'Damage taken-5%', [2] = '"Dbl.Atk."+10', [3] = 'Accuracy+20', [4] = 'Attack+20', [5] = 'DEX+30' } },
        Waist = 'Moonbow Belt +1',
        Legs = 'Kara. Pantaloni +2',
        Feet = { Name = 'Herculean Boots', Augment = { [1] = 'Accuracy+19', [2] = 'CHR+3', [3] = 'Attack+11', [4] = '"Triple Atk."+4' } },
    },

    -- Waltz set (for healing waltzes)
    Waltz = Equip.NewSet {
        Body = "Passion Jacket", -- Enhances Waltz
    },

    -- Overdrive set (for when 2-hour is active)
    Overdrive = Equip.NewSet {
        Main = "Xiucoatl",
        Range = "Animator P II +1",
        Head = "Karagoz Capello +1",
        Body = "Pitre Tobe +1",
        Hands = "Karagoz Guanti +1",
        Legs = "Karagoz Pantaloni +1",
        Feet = "Karagoz Scarpe +1",
        Neck = "Shulmanu Collar",
        Waist = "Klouskap Sash +1",
        Ear1 = "Burana Earring",
        Ear2 = "Charivari Earring",
        Ring1 = "Tali'ah Ring",
        Ring2 = "Varar Ring +1",
        Back = petCape,
    },

    -- Utsusemi sets
    Utsusemi = {
        Precast = Equip.NewSet {
            Main = "Xiucoatl",
            Range = "Animator P II +1",
            Head = "Heyoka Cap +1",
            Body = "Passion Jacket",
            Hands = "Rawhide Gloves",
            Legs = "Heyoka Subligar +1",
            Feet = "Tali'ah Crackows +2",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            --Ear1 = "Loquacious Earring", -- Fast cast
            Ear2 = "Mache Earring +1",
            --Ring1 = "Prolix Ring", -- Fast cast
            Ring2 = "Varar Ring +1",
            Back = petCape,
        },
        
        Midcast = Equip.NewSet {
            Main = "Xiucoatl",
            Range = "Animator P II +1",
            Head = "Heyoka Cap +1",
            Body = "Passion Jacket",
            Hands = "Rawhide Gloves",
            Legs = "Heyoka Subligar +1",
            Feet = "Tali'ah Crackows +2",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            --Ear1 = "Loquacious Earring", -- Fast cast
            Ear2 = "Mache Earring +1",
            --Ring1 = "Prolix Ring", -- Fast cast
            Ring2 = "Varar Ring +1",
            Back = petCape,
        },
    },

    -- Teleportation rings
    WarpRing = Equip.NewSet {
        Ring1 = "Warp Ring",
    },

    DimRing = Equip.NewSet {
        Ring1 = "Dim. Ring (Holla)",
    },

    -- Pet Action Sets (UPDATED)
    Pet = {
        -- General pet weapon skill set
        WeaponSkill = Equip.NewSet {
            Main = "Xiucoatl",
            Range = "Animator P II +1",
            Head = "Karagoz Capello +2",
            Body = "Pitre Tobe +1",
            Hands = "Pitre Dastanas +3",
            Legs = "Karagoz Pantaloni +2", 
            Feet = "Foire Babouches +2",
            Neck = "Shulmanu Collar",
            Waist = "Klouskap Sash +1",
            Ear1 = "Burana Earring",
            Ear2 = "Charivari Earring",
            Ring1 = "Thurandaut Ring",
            Ring2 = "Varar Ring +1",
            Back = petCape,
        },
        
        -- Specific sets for different pet weapon skill types
        -- Physical weapon skills (most common)
        Physical = Equip.NewSet {
            Main = "Xiucoatl",
            Range = "Animator P II +1",
            Head = "Karagoz Capello +2",
            Body = "Pitre Tobe +1",
            Hands = "Pitre Dastanas +3",
            Legs = "Karagoz Pantaloni +2", 
            Feet = "Foire Babouches +2",
            Neck = "Shulmanu Collar",
            Waist = "Klouskap Sash +1",
            Ear1 = "Burana Earring",
            Ear2 = "Charivari Earring",
            Ring1 = "Thurandaut Ring",
            Ring2 = "Varar Ring +1",
            Back = petCape,
        },
        
        -- Magic-based weapon skills (Magic Mortar, etc.)
        Magic = Equip.NewSet {
            Main = "Xiucoatl",
            Range = "Animator P II +1",
            Head = "Karagoz Capello +2",
            Body = "Pitre Tobe +1",
            Hands = "Pitre Dastanas +3",
            Legs = "Karagoz Pantaloni +2",
            Feet = "Foire Babouches +2",
            Neck = "Shulmanu Collar",
            Waist = "Klouskap Sash +1",
            Ear1 = "Burana Earring",
            Ear2 = "Kyrene\'s Earring", -- More magic-focused
            Ring1 = "Thurandaut Ring",
            Ring2 = "Varar Ring +1",
            Back = petCape,
        },
        
        -- Pet magic spells
        Cure = Equip.NewSet {
            Main = "Xiucoatl",
            Range = "Animator P II +1",
            Head = "Karagoz Capello +2",
            Body = "Pitre Tobe +1",
            Hands = "Foire Dastanas +2",
            Legs = "Karagoz Pantaloni +2",
            Feet = "Foire Babouches +2",
            Neck = "Shulmanu Collar",
            Waist = "Klouskap Sash +1",
            Ear1 = "Burana Earring",
            Ear2 = "Kyrene\'s Earring",
            Ring1 = "Thurandaut Ring",
            Ring2 = "Varar Ring +1",
            Back = petCape,
        },
    },
}

-- Function to update weapon in all relevant sets
local function UpdateWeapon()
    local weapon = settings.Weapon;
    
    -- Update all existing sets...
    sets.Idle.Main = weapon;
    sets.PetIdle.Tank.Main = weapon;
    sets.PetIdle.Melee.Main = weapon;
    sets.PetIdle.Range.Main = weapon;
    sets.PetIdle.Magic.Main = weapon;
    sets.PupOnly.Main = weapon;
    sets.Engaged.Main = weapon;
    sets.Master.Main = weapon;
    sets.Hybrid.Main = weapon;
    sets.Deploy.Main = weapon;
    sets.Repair.Main = weapon;
    sets.Maintenance.Main = weapon;
    sets.Maneuver.Main = weapon;
    sets.Ventriloquy.Main = weapon;
    sets.Town.Main = weapon;
    sets.Utsusemi.Precast.Main = weapon;
    sets.Utsusemi.Midcast.Main = weapon;
    
    -- Update weapon skill sets (UPDATED)
    sets.WeaponSkill['Shijin Spiral'].Main = weapon;
    sets.WeaponSkill['Victory Smite'].Main = weapon;
    if weapon == "Karambit" then
        sets.WeaponSkill['Asuran Fists'].Main = weapon;
    end
    sets.WeaponSkill.Default.Main = weapon;
    
    -- Update pet action sets if they exist
    if sets.Pet and sets.Pet.WeaponSkill then
        sets.Pet.WeaponSkill.Main = weapon;
    end
    
    -- Overdrive set always uses Xiucoatl
    sets.Overdrive.Main = "Xiucoatl";
    
    -- Refresh current gear
    profile.HandleDefault();
end

profile.Sets = sets

profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    gFunc.LockStyle(sets.Idle); -- Lock to idle gear appearance instead of town
    
    -- Ensure addset is enabled
    print('AddSet functionality enabled: ' .. tostring(gSettings.AllowAddSet));
    
    -- Chat aliases/commands
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /pupmode /lac fwd pupmode');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /dt /lac fwd dt');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /hybrid /lac fwd hybrid');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /puponly /lac fwd puponly');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /master /lac fwd master');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /xiu /lac fwd xiu');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /karambit /lac fwd karambit');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /warpring /lac fwd warpring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /dimring /lac fwd dimring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /refresh /lac fwd refresh');
    
    print('PUP Profile Loaded');
    print('Commands: /pupmode (tank/melee/range/magic), /dt, /hybrid, /puponly, /master, /xiu, /karambit, /refresh');
    print('Teleport Commands: /warpring, /dimring');
    print('Default weapon: Xiucoatl | PupOnly mode for fights using Lobo only');
    print('Master mode for pure master DPS | Hybrid mode for DT/DPS balance');
    print('NEW: Automatic pet action detection - swaps gear for pet WS/magic!');
end

profile.OnUnload = function()
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /pupmode');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /dt');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /hybrid');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /puponly');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /master');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /xiu');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /karambit');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /warpring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /dimring');
end

profile.HandleCommand = function(args)
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
        -- Toggle damage taken mode
        settings.DTMode = not settings.DTMode;
        -- Clear other conflicting modes
        if settings.DTMode then
            settings.HybridMode = false;
            settings.MasterMode = false;
        end
        print('DT mode: ' .. (settings.DTMode and 'On' or 'Off'));
        profile.HandleDefault(); -- Refresh gear
        return;
    elseif (args[1] == 'hybrid') then
        -- Toggle hybrid DT/DPS mode
        settings.HybridMode = not settings.HybridMode;
        -- Clear other conflicting modes
        if settings.HybridMode then
            settings.DTMode = false;
            settings.MasterMode = false;
        end
        print('Hybrid mode: ' .. (settings.HybridMode and 'On' or 'Off'));
        profile.HandleDefault(); -- Refresh gear
        return;
    elseif (args[1] == 'puponly') then
        settings.PupOnly = not settings.PupOnly;
        print('PupOnly mode: ' .. (settings.PupOnly and 'On' or 'Off'));
        return;
    elseif (args[1] == 'master') then
        settings.MasterMode = not settings.MasterMode;
        -- Clear other conflicting modes
        if settings.MasterMode then
            settings.DTMode = false;
            settings.HybridMode = false;
        end
        print('Master mode: ' .. (settings.MasterMode and 'On' or 'Off'));
        profile.HandleDefault(); -- Refresh gear
        return;
    elseif (args[1] == 'xiu') then
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
        -- Equip warp ring directly
        settings.TeleportActive = true;
        print('Warp Ring equipped - Use /refresh to return to normal gear');
        gFunc.ForceEquip(14, "Warp Ring"); -- Slot 14 is Ring1
        return;
    elseif (args[1] == 'dimring') then
        -- Equip dimensional ring directly
        settings.TeleportActive = true;
        print('Dimensional Ring equipped - Use /refresh to return to normal gear');
        gFunc.ForceEquip(14, "Dim. Ring (Holla)"); -- Slot 14 is Ring1
        return;
    elseif (args[1] == 'refresh') then
        -- Clear teleport flag and refresh gear
        settings.TeleportActive = false;
        settings.DTMode = false;
        settings.HybridMode = false;
        settings.MasterMode = false;
        print('Returning to normal gear');
        profile.HandleDefault();
        return;
    end
end

-- Function to get the appropriate base set based on current mode and status
local function GetBaseSet()
    local player = gData.GetPlayer();
    local pet = gData.GetPet();
    
    -- Check if we're in a town
    local env = gData.GetEnvironment();
    if (env.Area == "Western Adoulin" or env.Area == "Eastern Adoulin") then
        return sets.Town;
    end
    
    -- Check for special modes (high priority)
    if (settings.PupOnly) then
        return sets.PupOnly;
    end
    
    -- Check for damage/defensive modes
    if (settings.DTMode) then
        return sets.DT;
    elseif (settings.HybridMode) then
        return sets.Hybrid;
    elseif (settings.MasterMode) then
        return sets.Master;
    end
    
    -- Check for Overdrive buff
    if (Status.HasStatus('Overdrive')) then
        return sets.Overdrive;
    end
    
    -- Handle different player states
    if (player.Status == 'Engaged') then
        return sets.Engaged;
    elseif (pet and pet.isvalid) then
        -- Automaton is out, use pet idle gear
        return sets.PetIdle[settings.PetMode];
    else
        -- No pet, use normal idle
        return sets.Idle;
    end
end

profile.HandleDefault = function()
    -- Skip automatic gear changes if teleport item is active
    if (settings.TeleportActive) then
        return;
    end
    
    local player = gData.GetPlayer();
    local pet = gData.GetPet();
    
    -- Check for active pet actions first (highest priority after teleport)
    local petAction = gData.GetPetAction();
    if (petAction ~= nil) then
        print('Pet action detected: ' .. (petAction.Name or 'Unknown') .. ' (' .. (petAction.ActionType or 'Unknown') .. ')');
        
        if (petAction.ActionType == 'Ability') or (petAction.ActionType == 'MobSkill') then
            -- Pet using weapon skill or ability
            local wsName = petAction.Name or 'Unknown';
            
            -- Define magic-based pet weapon skills
            local magicWS = {
                ['Magic Mortar'] = true,
                ['Cannibal Blade'] = true,
            };
            
            if magicWS[wsName] then
                print('Using Pet Magic WS set for: ' .. wsName);
                Equip.Set(sets.Pet.Magic);
            else
                print('Using Pet Physical WS set for: ' .. wsName);
                Equip.Set(sets.Pet.Physical);
            end
            return;
        elseif (petAction.ActionType == 'Spell') then
            -- Pet casting spell
            local spellName = petAction.Name or 'Unknown';
            if (string.find(spellName, 'Cure') or string.find(spellName, 'Cura')) then
                print('Pet casting Cure: ' .. spellName);
                Equip.Set(sets.Pet.Cure);
            else
                print('Pet casting Magic: ' .. spellName);
                Equip.Set(sets.Pet.Magic);
            end
            return;
        end
    end
    
    -- Use base set determination
    local baseSet = GetBaseSet();
    Equip.Set(baseSet);
end

profile.HandleAbility = function()
    local ability = gData.GetAction();
    
    if (ability.Name == 'Deploy') then
        Equip.Set(sets.Deploy);
    elseif (ability.Name == 'Activate') then 
        Equip.Set(sets.Activate);
    elseif (ability.Name == 'Repair') then
        -- Use special PupOnly repair set when in PupOnly mode for repair potency
        if (settings.PupOnly) then
            Equip.Set(sets.RepairPupOnly);
        else
            Equip.Set(sets.Repair);
        end
    elseif (ability.Name == 'Maintenance') then
        Equip.Set(sets.Maintenance);
    elseif (ability.Name == 'Ventriloquy') then
        Equip.Set(sets.Ventriloquy);
    elseif (ability.Name == 'Overdrive') then
        Equip.Set(sets.Overdrive);
    elseif (string.find(ability.Name, 'Maneuver')) then
        Equip.Set(sets.Maneuver);
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
