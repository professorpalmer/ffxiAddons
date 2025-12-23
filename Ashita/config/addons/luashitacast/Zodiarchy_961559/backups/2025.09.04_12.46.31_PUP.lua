require('common');

local gear = gFunc.LoadFile('common/gear.lua');
local Equip = gFunc.LoadFile('common/equip.lua');
local Status = gFunc.LoadFile('common/status.lua');
local itemHandler = gFunc.LoadFile('common/items.lua');

local profile = {}

local settings = {
    PetMode = 'Tank',       -- Tank, Melee, Range, Magic
    IsTrusted = false,      -- For pet trusts
    Weapon = 'Xiucoatl',    -- Primary weapon: Xiucoatl (can switch to Karambit or Godhands)
    PupOnly = false,        -- For fights where only automaton is used (Lobo, etc) - toggleable with /puponly
    TurtleMode = false,     -- For pet -DT tank mode - toggleable with /turtle
    MasterMode = false,     -- For pure master DPS when pet is mage/not used - toggleable with /master
    MasterSTPMode = false,  -- For master Store TP mode when pet is mage/not used - toggleable with /masterstp
    TeleportActive = false, -- Prevent automatic gear changes when teleport item equipped
    DTMode = false,         -- Toggle damage taken mode
    HybridMode = false,     -- Toggle hybrid DT/DPS mode
    CombatMode = '',        -- Combat optimization: lowacc, highacc, lowatk, highatk, lowhaste, highhaste
    RegenMode = false,      -- Manual regen/idle gear mode - toggleable with /regen
    THMode = false,         -- Toggle Treasure Hunter mode - toggleable with /th
}

-- Define cape objects separately so they can be referenced in sets
local petCape = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'Pet: R.Acc.+20', [2] = 'Pet: R.Atk.+20', [3] = 'Pet: Haste+10', [4] = 'Accuracy+20', [5] = 'Attack+20', [6] = 'Pet: Acc.+20', [7] = 'Pet: Atk.+20' } };
local masterCape = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'Damage taken-5%', [2] = '"Dbl.Atk."+10', [3] = 'Accuracy+20', [4] = 'Attack+20', [5] = 'DEX+30' } };
local KaragozEar = { Name = 'Karagoz Earring', Augment = { [1] = 'Accuracy+9', [2] = 'Mag. Acc.+9' } };
local TurtleCape = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'Pet: R.Acc.+20', [2] = 'Pet: R.Atk.+20', [3] = 'Pet: Damage taken -5%', [4] = 'Pet: "Regen"+10', [5] = 'Pet: Acc.+20', [6] = 'Pet: Atk.+20' } };
local sets = {

    -- Idle sets
    Idle = Equip.NewSet {
        Head = "Pitre Taj +3",
        Body = 'Hiza. Haramaki +2',
        Hands = { Name = 'Rao Kote +1', AugPath = 'C' },
        Legs = { Name = 'Rao Haidate +1', AugPath = 'C' },
        Feet = { Name = 'Rao Sune-Ate +1', AugPath = 'C' },
        Neck = "Shulmanu Collar",
        Waist = "Moonbow Belt +1",
        Ear1 = "Mache Earring +1",
        Ear2 = KaragozEar,
        Ring1 = "Gere Ring",
        Ring2 = "Niqmaddu Ring",
        Back = petCape,
    },

    -- Pet idle sets (when automaton is out)
    PetIdle = {
        Tank = Equip.NewSet {
            Head = "Heyoka Cap +1",
            Body = "Mpaca\'s Doublet",
            Hands = "Herculean Gloves",
            Legs = "Heyoka Subligar +1",
            Feet = "Herculean Boots",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Mache Earring +1",
            Ear2 = KaragozEar,
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = petCape,
        },

        Melee = Equip.NewSet {
            Head = "Karagoz Capello +1",
            Body = "Karagoz Farsetto +1",
            Hands = "Karagoz Guanti +1",
            Legs = "Karagoz Pantaloni +1",
            Feet = "Karagoz Scarpe +1",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Mache Earring +1",
            Ear2 = KaragozEar,
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = petCape,
        },

        Range = Equip.NewSet {
            Head = "Karagoz Capello +1",
            Body = "Karagoz Farsetto +1",
            Hands = "Karagoz Guanti +1",
            Legs = "Karagoz Pantaloni +1",
            Feet = "Karagoz Scarpe +1",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Mache Earring +1",
            Ear2 = KaragozEar,
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = petCape,
        },

        Magic = Equip.NewSet {
            Head = "Karagoz Capello +1",
            Body = "Karagoz Farsetto +1",
            Hands = "Karagoz Guanti +1",
            Legs = "Karagoz Pantaloni +1",
            Feet = "Karagoz Scarpe +1",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Mache Earring +1",
            Ear2 = KaragozEar,
            Ring1 = "Gere Ring",
            Ring2 = "Varar Ring +1",
            Back = petCape,
        },
    },

    -- Pup Only mode (for fights where only automaton is used)
    PupOnly = Equip.NewSet {
        Head = "Pitre Taj +3",
        Body = "Pitre Tobe +3",
        Hands = "Karagoz Guanti +2",
        --        Hands = { Name = 'Herculean Gloves', Augment = { [1] = 'Pet: "Dbl.Atk."+2', [2] = 'Pet: Rng. Acc.+15', [3] = 'Pet: Accuracy+15', [4] = 'Pet: Crit.hit rate +2' } },
        Legs = "Kara. Pantaloni +2",
        Feet = "Mpaca\'s Boots",
        Neck = "Shulmanu Collar",
        Waist = "Klouskap Sash +1",
        Ear1 = "Burana Earring",
        Ear2 = KaragozEar,
        Ring1 = "Thurandaut Ring",
        Ring2 = "Varar Ring +1",
        Back = petCape,
    },

    -- Turtle mode (identical to PupOnly but for pet -DT tank)
    Turtle = Equip.NewSet {
        Head = "Pitre Taj +3",
        Body = { Name = 'Rao Togi +1', AugPath = 'C' },
        Hands = { Name = 'Rao Kote +1', AugPath = 'C' },
        Legs = { Name = 'Rao Haidate +1', AugPath = 'C' },
        Feet = { Name = 'Rao Sune-Ate +1', AugPath = 'C' },
        Neck = "Empath Necklace",
        Waist = "Klouskap Sash +1",
        Ear1 = "Burana Earring",
        Ear2 = "Hypaspist Earring",
        Ring1 = "Thurandaut Ring",
        Ring2 = "Varar Ring +1",
        Back = TurtleCape,
    },

    -- Master melee sets
    Engaged = Equip.NewSet {
        Head = "Heyoka Cap +1",
        Body = 'Mpaca\'s Doublet',
        Hands = "Herculean Gloves",
        Legs = "Heyoka Subligar +1",
        Feet = "Mpaca\'s Boots",
        Neck = "Shulmanu Collar",
        Waist = "Moonbow Belt +1",
        Ear1 = "Mache Earring +1",
        Ear2 = KaragozEar,
        Ring1 = "Gere Ring",
        Ring2 = "Niqmaddu Ring",
        Back = masterCape,
    },

    -- Godhands TP set (Aeonic H2H weapon)
    GodhandsTP = Equip.NewSet {
        Main = "Godhands",
        Head = "Heyoka Cap +1",
        Body = "Mpaca\'s Doublet",
        Hands = "Herculean Gloves",
        Legs = "Heyoka Subligar +1",
        Feet = "Herculean Boots",
        Neck = "Shulmanu Collar",
        Waist = "Moonbow Belt +1",
        Ear1 = "Mache Earring +1",
        Ear2 = KaragozEar,
        Ring1 = "Gere Ring",
        Ring2 = "Niqmaddu Ring",
        Back = petCape,
    },

    -- Combat Mode Optimization Sets
    CombatModes = {
        -- Low Accuracy situations (easy targets)
        LowAcc = Equip.NewSet {
            Head = "Heyoka Cap +1",
            Body = "Mpaca\'s Doublet",
            Hands = "Herculean Gloves",
            Legs = "Heyoka Subligar +1",
            Feet = "Herculean Boots",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Brutal Earring",   -- More DA
            Ear2 = "Cessance Earring", -- More DA
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = masterCape,
        },

        -- High Accuracy needed (tough targets)
        HighAcc = Equip.NewSet {
            Head = "Heyoka Cap +1",
            Body = "Malignance Tabard", -- More accuracy
            Hands = "Herculean Gloves",
            Legs = "Heyoka Subligar +1",
            Feet = "Herculean Boots",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Mache Earring +1", -- Accuracy focus
            Ear2 = "Zennaroi Earring", -- Accuracy focus
            Ring1 = "Gere Ring",
            Ring2 = "Chirich Ring +1", -- Accuracy
            Back = masterCape,
        },

        -- Low Attack situations (high defense targets)
        LowAtk = Equip.NewSet {
            Head = "Heyoka Cap +1",
            Body = "Mpaca\'s Doublet",
            Hands = "Herculean Gloves",
            Legs = "Heyoka Subligar +1",
            Feet = "Herculean Boots",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Mache Earring +1",
            Ear2 = "Mache Earring +1",
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = masterCape,
        },

        -- High Attack situations (glass cannon)
        HighAtk = Equip.NewSet {
            Head = "Adhemar Bonnet +1",  -- Attack focus
            Body = "Ken. Samue +1",      -- Attack focus
            Hands = "Adhemar Wrist. +1", -- Attack focus
            Legs = "Ken. Hakama +1",     -- Attack focus
            Feet = "Ken. Sune-Ate +1",   -- Attack focus
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Mache Earring +1",
            Ear2 = "Mache Earring +1",
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = masterCape,
        },

        -- Low Haste situations (need more haste)
        LowHaste = Equip.NewSet {
            Head = "Heyoka Cap +1",
            Body = "Mpaca\'s Doublet",
            Hands = "Herculean Gloves",
            Legs = "Heyoka Subligar +1",
            Feet = "Herculean Boots",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Mache Earring +1",
            Ear2 = "Mache Earring +1",
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = masterCape,
        },

        -- High Haste situations (haste capped, focus other stats)
        HighHaste = Equip.NewSet {
            Head = "Heyoka Cap +1",
            Body = "Ken. Samue +1",      -- Less haste, more other stats
            Hands = "Adhemar Wrist. +1", -- Less haste, more other stats
            Legs = "Ken. Hakama +1",     -- Less haste, more other stats
            Feet = "Ken. Sune-Ate +1",   -- Less haste, more other stats
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Brutal Earring",   -- More DA
            Ear2 = "Cessance Earring", -- More DA
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = masterCape,
        },
    },

    -- Master DPS mode (for when pet is mage/not used, focus on master damage)
    Master = Equip.NewSet {
        Main = "Godhands",
        Head = { Name = 'Ryuo Somen +1', AugPath = 'C' },
        Body = 'Mpaca\'s Doublet',
        Hands = "Herculean Gloves",
        Legs = { Name = 'Ryuo Hakama +1', AugPath = 'D' },
        Feet = "Herculean Boots",
        Neck = "Shulmanu Collar",
        Waist = "Moonbow Belt +1",
        Ear1 = "Sroda Earring",
        Ear2 = "Mache Earring +1",
        Ring1 = "Gere Ring",
        Ring2 = "Niqmaddu Ring",
        Back = masterCape,
    },

    -- Master Store TP mode (for when pet is mage/not used, focus on TP gain for WS chains)
    MasterSTP = Equip.NewSet {
        Main = "Godhands",
        Head = { Name = 'Ryuo Somen +1', AugPath = 'C' },
        Body = 'Malignance Tabard',
        Hands = "Karagoz Guanti +2",
        Legs = { Name = 'Ryuo Hakama +1', AugPath = 'D' },
        Feet = "Mpaca\'s Boots",
        Neck = "Shulmanu Collar",
        Waist = "Moonbow Belt +1",
        Ear1 = "Dedition Earring",
        Ear2 = "Mache Earring +1",
        Ring1 = "Gere Ring",
        Ring2 = "Niqmaddu Ring",
        Back = masterCape,
    },

    -- Job abilities
    Deploy = Equip.NewSet {
        Ear1 = "Burana Earring",
    },

    Activate = Equip.NewSet {
        Back = petCape,
        Ear2 = KaragozEar,
        Ring1 = "Gere Ring",
    },

    Repair = Equip.NewSet {

        Body = "Foire Tobe +3",
        Hands = { Name = 'Rao Kote +1', AugPath = 'C' },
        Legs = { Name = 'Rao Haidate +1', AugPath = 'C' },
        Feet = "Foire Babouches +2",
        Ear1 = "Burana Earring",
        Ear2 = "Guignol Earring",
        Back = petCape,
        Ammo = "Automat. Oil +3",
    },

    -- PupOnly repair set with Nibiru Sainti for repair potency
    RepairPupOnly = Equip.NewSet {
        Main = "Nibiru Sainti",
        Body = "Foire Tobe +3",
        Hands = { Name = 'Rao Kote +1', AugPath = 'C' },
        Legs = { Name = 'Rao Haidate +1', AugPath = 'C' },
        Feet = "Foire Babouches +2",
        Ear1 = "Burana Earring",
        Ear2 = "Guignol Earring",
        Back = petCape,
        Ammo = "Automat. Oil +3",
    },

    -- Turtle repair set with Nibiru Sainti for repair potency
    RepairTurtle = Equip.NewSet {
        Main = "Nibiru Sainti",
        Body = "Foire Tobe +3",
        Hands = { Name = 'Rao Kote +1', AugPath = 'C' },
        Legs = { Name = 'Rao Haidate +1', AugPath = 'C' },
        Feet = "Foire Babouches +2",
        Ear1 = "Burana Earring",
        Ear2 = "Guignol Earring",
        Back = petCape,
        Ammo = "Automat. Oil +3",
    },

    Maintenance = Equip.NewSet {
        Hands = { Name = 'Rao Kote +1', AugPath = 'C' },
        Legs = { Name = 'Rao Haidate +1', AugPath = 'C' },
        Feet = "Foire Babouches +2",
        Ear1 = "Burana Earring",
        Ear2 = "Guignol Earring",
        Back = "Visucius\'s Mantle",
        Ammo = "Automat. Oil +3",
    },

    Maneuver = Equip.NewSet {
        Body = "Kara. Farsetto +2",
        Hands = "Foire Dastanas +3",
        Legs = "Heyoka Subligar +1",
        Feet = "Foire Babouches +2",
        Neck = "Bfn. Collar +1",
        Waist = "Moonbow Belt +1",
        Ear1 = "Burana Earring",
        Ear2 = "Mache Earring +1",
        Back = petCape,
    },

    Ventriloquy = Equip.NewSet {
        -- Master-focused ventriloquy gear for enmity and survivability
        Main = "Xiucoatl",
        Head = "Kara. Cappello +2",
        Body = "Passion Jacket",
        Hands = "Nilas Gloves",
        Legs = "Pitre Churidars +3",
        Feet = "Tali'ah Crackows +2",
        Neck = "Unmoving Collar +1",
        Waist = "Moonbow Belt +1",
        Ear1 = "Sroda Earring",
        Ear2 = "Mache Earring +1",
        Ring1 = "Gere Ring",
        Ring2 = "Niqmaddu Ring",
        Back = petCape,
    },

    TacticalSwitch = Equip.NewSet {
        Feet = "Karagoz Scarpe +1",
    },

    -- Weapon skills (UPDATED)
    WeaponSkill = {
        -- Shijin Spiral - DEX-based WS
        ['Shijin Spiral'] = Equip.NewSet {
            Head = "Mpaca\'s Cap",
            Body = "Foire Tobe +3",
            Hands = "Pitre Dastanas +3",
            Legs = "Hiza. Hizayoroi +2",
            Feet = "Mpaca\'s Boots",
            Neck = "Fotia Gorget",
            Waist = "Moonbow Belt +1",
            Ear1 = "Mache Earring +1",
            Ear2 = KaragozEar,
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = masterCape,
        },

        -- Victory Smite - STR-based H2H, crit rate varies by TP
        ['Victory Smite'] = Equip.NewSet {
            Head = "Mpaca\'s Cap",
            Body = "Foire Tobe +3",
            Hands = "Pitre Dastanas +3",
            Legs = "Hiza. Hizayoroi +2",
            Feet = "Mpaca\'s Boots",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Mache Earring +1",
            Ear2 = KaragozEar,
            Ring1 = "Gere Ring",
            Ring2 = "Rajas Ring",
            Back = masterCape,
        },

        -- Asuran Fists - STR-based H2H, 8-hit (accuracy very important)
        ['Asuran Fists'] = Equip.NewSet {
            Head = "Mpaca\'s Cap",
            Body = "Foire Tobe +3",
            Hands = "Pitre Dastanas +3",
            Legs = "Hiza. Hizayoroi +2",
            Feet = "Mpaca\'s Boots",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Zennaroi Earring",
            Ear2 = "Mache Earring +1",
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = masterCape,
        },

        HowlingFists = Equip.NewSet {
            Head = "Mpaca\'s Cap",
            Body = "Foire Tobe +3",
            Hands = "Pitre Dastanas +3",
            Legs = "Hiza. Hizayoroi +2",
            Feet = "Mpaca\'s Boots",
            Ear1 = "Mache Earring +1",
            Ear2 = "Mache Earring +1",
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = masterCape,
        },

        -- Default fallback for any other weapon skills
        Default = Equip.NewSet {
            Head = "Mpaca\'s Cap",
            Body = "Foire Tobe +3",
            Hands = "Pitre Dastanas +3",
            Legs = "Hiza. Hizayoroi +2",
            Feet = "Mpaca\'s Boots",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Sroda Earring",
            Ear2 = "Mache Earring +1",
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = masterCape,
        },
    },

    -- Fast Cast
    Precast = Equip.NewSet {
        Ear1 = "Loquacious Earring",
        Ring1 = "Prolix Ring",
    },



    -- Situational sets
    DT = Equip.NewSet {
        Head = "Nyame Helm",
        Body = "Nyame Mail",
        Hands = "Karagoz Guanti +2",
        Legs = "Kara. Pantaloni +2",
        Feet = "Nyame Sollerets",
        Ring1 = "Gelatinous Ring +1",
        Back = masterCape,
    },

    -- Hybrid DT/DPS set (balance between damage taken and offensive stats)
    Hybrid = Equip.NewSet {
        Main = { Name = 'Xiucoatl', AugPath = 'C' },
        Ammo = 'Automat. Oil +3',
        Head = 'Nyame Helm',
        Neck = 'Shulmanu Collar',
        Ear1 = 'Sroda Earring',
        Ear2 = 'Mache Earring +1',
        Body = 'Malignance Tabard',
        Hands = 'Karagoz Guanti +2',
        Ring1 = 'Gere Ring',
        Ring2 = 'Niqmaddu Ring',
        Back = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'Damage taken-5%', [2] = '"Dbl.Atk."+10', [3] = 'Accuracy+20', [4] = 'Attack+20', [5] = 'DEX+30' } },
        Waist = 'Moonbow Belt +1',
        Legs = 'Kara. Pantaloni +2',
        Feet = 'Malignance Boots',
    },

    -- Waltz set (for healing waltzes)
    Waltz = Equip.NewSet {
        Body = "Passion Jacket", -- Enhances Waltz
    },

    -- Treasure Hunter set
    TH = Equip.NewSet {
        Main = "Xiucoatl",
        Head = "Volte Cap",          -- TH+1
        Body = "Herculean Vest",     -- Can be augmented with TH
        Hands = "Plunderer's Armlets +1", -- TH+2
        Legs = "Herculean Trousers", -- Can be augmented with TH
        Feet = "Skulker's Poulaines +1", -- TH+1
        Waist = "Chaac Belt",        -- TH+1
        Ring1 = "Gere Ring",
        Ring2 = "Niqmaddu Ring",
        Back = masterCape,
    },

    -- Overdrive set (for when 2-hour is active)
    Overdrive = Equip.NewSet {
        Main = "Xiucoatl",
        Head = "Karagoz Capello +2",
        Body = "Pitre Tobe +3",
        Hands = "Karagoz Guanti +2",
        Legs = "Karagoz Pantaloni +2",
        Feet = "Punchinellos",
        Neck = "Shulmanu Collar",
        Waist = "Klouskap Sash +1",
        Ear1 = "Burana Earring",
        Ear2 = KaragozEar,
        Ring1 = "Tali'ah Ring",
        Ring2 = "Varar Ring +1",
        Back = petCape,
    },

    -- Utsusemi sets
    Utsusemi = {
        Precast = Equip.NewSet {
            Main = "Xiucoatl",
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
            Head = "Karagoz Capello +2",
            Body = "Pitre Tobe +3",
            Hands = "Pitre Dastanas +3",
            Legs = "Karagoz Pantaloni +2",
            Feet = "Foire Babouches +2",
            Neck = "Shulmanu Collar",
            Waist = "Klouskap Sash +1",
            Ear1 = "Burana Earring",
            Ear2 = KaragozEar,
            Ring1 = "Thurandaut Ring",
            Ring2 = "Varar Ring +1",
            Back = petCape,
        },

        -- Specific sets for different pet weapon skill types
        -- Physical weapon skills (most common)
        Physical = Equip.NewSet {
            Head = "Karagoz Capello +2",
            Body = "Pitre Tobe +3",
            Hands = "Pitre Dastanas +3",
            Legs = "Karagoz Pantaloni +2",
            Feet = "Foire Babouches +2",
            Neck = "Shulmanu Collar",
            Waist = "Klouskap Sash +1",
            Ear1 = "Burana Earring",
            Ear2 = KaragozEar,
            Ring1 = "Thurandaut Ring",
            Ring2 = "Varar Ring +1",
            Back = petCape,
        },

        -- Magic dmg
        Magic = Equip.NewSet {
            Head = "Karagoz Capello +2",
            Body = "Udug Jacket",
            Hands = "Karagoz Guanti +2",
            Legs = "Pitre Churidars +3",
            Feet = "Pitre Babouches +3",
            Neck = "Pup. Collar",
            Waist = "Eschan Stone",
            Ear1 = "Burana Earring",
            Ear2 = KaragozEar,
            Ring1 = "Thurandaut Ring",
            Ring2 = "Varar Ring +1",
            Back = petCape,
        },

        -- Pet healing
        Cure = Equip.NewSet {
            Head = "Karagoz Capello +2",
            Body = "Kara. Farsetto +2",
            Hands = "Karagoz Guanti +2",
            Legs = "Foire Churidars +2",
            Feet = "Foire Babouches +2",
            Neck = "Pup. Collar",
            Waist = "Klouskap Sash +1",
            Ear1 = "Burana Earring",
            Ear2 = KaragozEar,
            Ring1 = "Thurandaut Ring",
            Ring2 = "Varar Ring +1",
            Back = petCape,
        },
    },
}

-- Function to update weapon in all relevant sets
local function UpdateWeapon()
    local weapon = settings.Weapon;

    -- Special handling for Godhands - swap the Engaged set to GodhandsTP
    if weapon == "Godhands" then
        sets.Engaged = sets.GodhandsTP;
    else
        -- For other weapons, ensure Engaged is the default engaged set
        sets.Engaged = Equip.NewSet {
            Main = weapon,
            Head = "Heyoka Cap +1",
            Body = 'Mpaca\'s Doublet',
            Hands = "Herculean Gloves",
            Legs = "Heyoka Subligar +1",
            Feet = "Mpaca\'s Boots",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Sroda Earring",
            Ear2 = "Mache Earring +1",
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = petCape,
        };
    end

    -- Update all existing sets...
    sets.Idle.Main = weapon;
    sets.PetIdle.Tank.Main = weapon;
    sets.PetIdle.Melee.Main = weapon;
    sets.PetIdle.Range.Main = weapon;
    sets.PetIdle.Magic.Main = weapon;
    sets.PupOnly.Main = weapon;
    sets.Turtle.Main = weapon;     -- Added Turtle set
    sets.GodhandsTP.Main = weapon; -- Added GodhandsTP set
    sets.Master.Main = weapon;
    sets.MasterSTP.Main = weapon;  -- Added MasterSTP set
    sets.Hybrid.Main = weapon;
    sets.Deploy.Main = weapon;
    sets.Repair.Main = weapon;
    sets.Maintenance.Main = weapon;
    sets.Maneuver.Main = weapon;
    sets.Ventriloquy.Main = weapon;
    sets.TH.Main = weapon;

    sets.Utsusemi.Precast.Main = weapon;
    sets.Utsusemi.Midcast.Main = weapon;

    -- Update weapon skill sets (UPDATED)
    sets.WeaponSkill['Shijin Spiral'].Main = weapon;
    sets.WeaponSkill['Victory Smite'].Main = weapon;
    sets.WeaponSkill.HowlingFists.Main = weapon;
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

    -- Update combat mode sets
    sets.CombatModes.LowAcc.Main = weapon;
    sets.CombatModes.HighAcc.Main = weapon;
    sets.CombatModes.LowAtk.Main = weapon;
    sets.CombatModes.HighAtk.Main = weapon;
    sets.CombatModes.LowHaste.Main = weapon;
    sets.CombatModes.HighHaste.Main = weapon;

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
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /turtle /lac fwd turtle');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /master /lac fwd master');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /masterstp /lac fwd masterstp');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /xiu /lac fwd xiu');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /karambit /lac fwd karambit');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /godhands /lac fwd godhands');
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

    -- Register hotkey for DEL key
    AshitaCore:GetChatManager():QueueCommand(1, '/bind delete /lac fwd vileelixir');

    print('PUP Profile Loaded');
    print(
        'Commands: /pupmode (tank/melee/range/magic), /dt, /hybrid, /puponly, /turtle, /master, /masterstp, /xiu, /karambit, /godhands, /refresh');
    print('Combat Modes: /lowacc, /highacc, /lowatk, /highatk, /lowhaste, /highhaste');
    print('Teleport Commands: /warpring, /dimring');
    print('Regen Control: /regen - Toggle manual regen/idle gear');
    print('Treasure Hunter: /th - Toggle TH gear mode');
    print('Hotkey: DEL key for Vile Elixir items');
    print('Default weapon: Xiucoatl | PupOnly mode for fights using Lobo only');
    print(
    'Turtle mode for pet -DT tank | Master mode for pure master DPS | MasterSTP mode for master Store TP | Hybrid mode for DT/DPS balance');
    print('NEW: Automatic pet action detection - swaps gear for pet WS/magic!');
end

profile.OnUnload = function()
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /pupmode');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /dt');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /hybrid');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /puponly');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /turtle');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /master');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /masterstp');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /xiu');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /karambit');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /godhands');
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

    -- Unbind DEL key
    AshitaCore:GetChatManager():QueueCommand(1, '/unbind delete');
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
        -- Clear other conflicting modes when activating
        if settings.DTMode then
            settings.HybridMode = false;
            settings.MasterMode = false;
            settings.PupOnly = false;
            settings.TurtleMode = false;
            settings.CombatMode = '';
            settings.THMode = false;
        end
        print('DT mode: ' .. (settings.DTMode and 'On' or 'Off'));
        profile.HandleDefault(); -- Refresh gear
        return;
    elseif (args[1] == 'hybrid') then
        -- Toggle hybrid DT/DPS mode
        settings.HybridMode = not settings.HybridMode;
        -- Clear other conflicting modes when activating
        if settings.HybridMode then
            settings.DTMode = false;
            settings.MasterMode = false;
            settings.PupOnly = false;
            settings.TurtleMode = false;
            settings.CombatMode = '';
            settings.THMode = false;
        end
        print('Hybrid mode: ' .. (settings.HybridMode and 'On' or 'Off'));
        profile.HandleDefault(); -- Refresh gear
        return;
    elseif (args[1] == 'puponly') then
        settings.PupOnly = not settings.PupOnly;
        -- Clear other conflicting modes when activating
        if settings.PupOnly then
            settings.DTMode = false;
            settings.HybridMode = false;
            settings.MasterMode = false;
            settings.TurtleMode = false;
            settings.CombatMode = '';
            settings.THMode = false;
        end
        print('PupOnly mode: ' .. (settings.PupOnly and 'On' or 'Off'));
        profile.HandleDefault(); -- Refresh gear
        return;
    elseif (args[1] == 'turtle') then
        settings.TurtleMode = not settings.TurtleMode;
        -- Clear other conflicting modes when activating
        if settings.TurtleMode then
            settings.DTMode = false;
            settings.HybridMode = false;
            settings.MasterMode = false;
            settings.PupOnly = false;
            settings.CombatMode = '';
            settings.THMode = false;
        end
        print('Turtle mode: ' .. (settings.TurtleMode and 'On' or 'Off'));
        profile.HandleDefault(); -- Refresh gear
        return;
    elseif (args[1] == 'master') then
        settings.MasterMode = not settings.MasterMode;
        -- Clear other conflicting modes when activating
        if settings.MasterMode then
            settings.DTMode = false;
            settings.HybridMode = false;
            settings.MasterSTPMode = false;
            settings.PupOnly = false;
            settings.TurtleMode = false;
            settings.CombatMode = '';
            settings.THMode = false;
        end
        print('Master mode: ' .. (settings.MasterMode and 'On' or 'Off'));
        profile.HandleDefault(); -- Refresh gear
        return;
    elseif (args[1] == 'masterstp') then
        settings.MasterSTPMode = not settings.MasterSTPMode;
        -- Clear other conflicting modes when activating
        if settings.MasterSTPMode then
            settings.DTMode = false;
            settings.HybridMode = false;
            settings.MasterMode = false;
            settings.PupOnly = false;
            settings.TurtleMode = false;
            settings.CombatMode = '';
            settings.THMode = false;
        end
        print('MasterSTP mode: ' .. (settings.MasterSTPMode and 'On' or 'Off'));
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
    elseif (args[1] == 'godhands') then
        settings.Weapon = 'Godhands';
        UpdateWeapon();
        print('Weapon set to: Godhands');
        return;
    elseif (args[1] == 'warpring') then
        -- Equip warp ring and use it after 10 seconds
        settings.TeleportActive = true;
        print('Warp Ring equipped - Using in 10 seconds...');
        gFunc.ForceEquip(14, "Warp Ring"); -- Slot 14 is Ring1
        -- Queue the item use command after 10 seconds
        ashita.tasks.once(10, function()
            print('Using Warp Ring...');
            AshitaCore:GetChatManager():QueueCommand(1, '/item "Warp Ring" <me>');
            -- Wait a bit more for teleportation to complete, then refresh gear
            ashita.tasks.once(3, function()
                print('Teleportation complete - refreshing gear...');
                AshitaCore:GetChatManager():QueueCommand(1, '/lac fwd refresh');
            end);
        end);
        return;
    elseif (args[1] == 'dimring') then
        -- Equip dimensional ring and use it after 10 seconds
        settings.TeleportActive = true;
        print('Dimensional Ring equipped - Using in 10 seconds...');
        gFunc.ForceEquip(14, "Dim. Ring (Holla)"); -- Slot 14 is Ring1
        -- Queue the item use command after 10 seconds
        ashita.tasks.once(10, function()
            print('Using Dimensional Ring...');
            AshitaCore:GetChatManager():QueueCommand(1, '/item "Dim. Ring (Holla)" <me>');
            -- Wait a bit more for teleportation to complete, then refresh gear
            ashita.tasks.once(3, function()
                print('Teleportation complete - refreshing gear...');
                AshitaCore:GetChatManager():QueueCommand(1, '/lac fwd refresh');
            end);
        end);
        return;
    elseif (args[1] == 'refresh') then
        -- Clear teleport flag and refresh gear
        settings.TeleportActive = false;
        settings.DTMode = false;
        settings.HybridMode = false;
        settings.MasterMode = false;
        settings.CombatMode = '';
        settings.THMode = false;
        print('Returning to normal gear');
        profile.HandleDefault();
        return;
        -- Combat mode commands
    elseif (args[1] == 'lowacc') then
        -- Clear other conflicting modes when activating combat mode
        settings.DTMode = false;
        settings.HybridMode = false;
        settings.MasterMode = false;
        settings.PupOnly = false;
        settings.TurtleMode = false;
        settings.THMode = false;
        settings.CombatMode = 'LowAcc';
        print('Combat Mode: Low Accuracy (easy targets)');
        profile.HandleDefault();
        return;
    elseif (args[1] == 'highacc') then
        -- Clear other conflicting modes when activating combat mode
        settings.DTMode = false;
        settings.HybridMode = false;
        settings.MasterMode = false;
        settings.PupOnly = false;
        settings.TurtleMode = false;
        settings.THMode = false;
        settings.CombatMode = 'HighAcc';
        print('Combat Mode: High Accuracy (tough targets)');
        profile.HandleDefault();
        return;
    elseif (args[1] == 'lowatk') then
        -- Clear other conflicting modes when activating combat mode
        settings.DTMode = false;
        settings.HybridMode = false;
        settings.MasterMode = false;
        settings.PupOnly = false;
        settings.TurtleMode = false;
        settings.THMode = false;
        settings.CombatMode = 'LowAtk';
        print('Combat Mode: Low Attack (high defense targets)');
        profile.HandleDefault();
        return;
    elseif (args[1] == 'highatk') then
        -- Clear other conflicting modes when activating combat mode
        settings.DTMode = false;
        settings.HybridMode = false;
        settings.MasterMode = false;
        settings.PupOnly = false;
        settings.TurtleMode = false;
        settings.THMode = false;
        settings.CombatMode = 'HighAtk';
        print('Combat Mode: High Attack (glass cannon)');
        profile.HandleDefault();
        return;
    elseif (args[1] == 'lowhaste') then
        -- Clear other conflicting modes when activating combat mode
        settings.DTMode = false;
        settings.HybridMode = false;
        settings.MasterMode = false;
        settings.PupOnly = false;
        settings.TurtleMode = false;
        settings.THMode = false;
        settings.CombatMode = 'LowHaste';
        print('Combat Mode: Low Haste (need more haste)');
        profile.HandleDefault();
        return;
    elseif (args[1] == 'highhaste') then
        -- Clear other conflicting modes when activating combat mode
        settings.DTMode = false;
        settings.HybridMode = false;
        settings.MasterMode = false;
        settings.PupOnly = false;
        settings.TurtleMode = false;
        settings.THMode = false;
        settings.CombatMode = 'HighHaste';
        print('Combat Mode: High Haste (haste capped)');
        profile.HandleDefault();
        return;
    elseif (args[1] == 'regen') then
        settings.RegenMode = not settings.RegenMode;
        -- Clear other conflicting modes when activating
        if settings.RegenMode then
            settings.DTMode = false;
            settings.HybridMode = false;
            settings.MasterMode = false;
            settings.PupOnly = false;
            settings.TurtleMode = false;
            settings.CombatMode = '';
            settings.THMode = false;
        end
        print('Regen mode: ' .. (settings.RegenMode and 'On' or 'Off'));
        profile.HandleDefault(); -- Refresh gear
        return;
    elseif (args[1] == 'th') then
        settings.THMode = not settings.THMode;
        -- Clear other conflicting modes when activating
        if settings.THMode then
            settings.DTMode = false;
            settings.HybridMode = false;
            settings.MasterMode = false;
            settings.PupOnly = false;
            settings.TurtleMode = false;
            settings.CombatMode = '';
            settings.RegenMode = false;
        end
        print('Treasure Hunter mode: ' .. (settings.THMode and 'On' or 'Off'));
        profile.HandleDefault(); -- Refresh gear
        return;
    elseif (args[1] == 'vileelixir') then
        -- Try to use Vile Elixir+1 first, then Vile Elixir if +1 is not available
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

                    -- Debug: Print all items that contain "vile elixir" in the name
                    if string.find(string.lower(itemName), "vile elixir") then
                        print('Found potential Vile Elixir item: "' ..
                            itemName .. '" (ID: ' .. item.Id .. ') in container ' .. container .. ', slot ' .. index);
                    end

                    -- Check for Vile Elixir +1 with multiple possible formats
                    if itemName == "Vile Elixir +1" or itemName == "Vile Elixir+1" or string.find(string.lower(itemName), "vile elixir%+1") then
                        print('Found Vile Elixir +1 in container ' .. container .. ', slot ' .. index);
                        print('Using Vile Elixir +1');
                        print('Item name being used: "' .. itemName .. '"');
                        print('Item ID: ' .. item.Id);
                        -- Use the exact item name as requested by user
                        AshitaCore:GetChatManager():QueueCommand(1, '/item "' .. itemName .. '" <me>');
                        return;
                    end
                end
            end
        end

        -- Second pass: Only search for regular Vile Elixir if +1 was not found
        print('Vile Elixir +1 not found, searching for regular Vile Elixir...');
        for _, container in ipairs(containers) do
            for index = 0, 80 do
                local item = inv:GetContainerItem(container, index);
                if item and item.Id > 0 then
                    local itemName = resx:GetItemById(item.Id).Name[1];

                    -- Check for regular Vile Elixir (but not +1)
                    if itemName == "Vile Elixir" and not string.find(string.lower(itemName), "%+1") then
                        print('Found Vile Elixir in container ' .. container .. ', slot ' .. index);
                        print('Using Vile Elixir');
                        print('Item name being used: "' .. itemName .. '"');
                        print('Item ID: ' .. item.Id);
                        -- Use the exact item name as requested by user
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

    if (settings.RegenMode) then
        -- In regen mode, use idle gear based on pet status
        if (pet and pet.isvalid) then
            return sets.PetIdle[settings.PetMode];
        else
            return sets.Idle;
        end
    end

    if (settings.THMode) then
        return sets.TH;
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
    -- Skip automatic gear changes if teleport item is active
    if (settings.TeleportActive) then
        return;
    end

    local player = gData.GetPlayer();
    local pet = gData.GetPet();

    -- Check for active pet actions first (highest priority after teleport)
    local petAction = gData.GetPetAction();
    if (petAction ~= nil) then
        print('Pet action detected: ' ..
            (petAction.Name or 'Unknown') .. ' (' .. (petAction.ActionType or 'Unknown') .. ')');

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
    if (baseSet ~= nil) then
        Equip.Set(baseSet);
    end
end

profile.HandleAbility = function()
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
