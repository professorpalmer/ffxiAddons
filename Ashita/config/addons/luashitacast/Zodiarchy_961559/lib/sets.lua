local M = {};

-- Build all gear sets. Requires Equip helper passed in.
function M.build_sets(Equip)
    -- Capes and reusable augments
    local petCape = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'Pet: R.Acc.+20', [2] = 'Pet: R.Atk.+20', [3] = 'Pet: Haste+10', [4] = 'Accuracy+20', [5] = 'Attack+20', [6] = 'Pet: Acc.+20', [7] = 'Pet: Atk.+20' } };
    local masterCape = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'Damage taken-5%', [2] = '"Dbl.Atk."+10', [3] = 'Accuracy+20', [4] = 'Attack+20', [5] = 'DEX+30' } };
    local pummelCape = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'STR+30', [2] = 'Crit.hit rate+10', [3] = 'Attack+20', [4] = 'Accuracy+20' } };
    local KaragozEar = { Name = 'Karagoz Earring', Augment = { [1] = 'Accuracy+9', [2] = 'Mag. Acc.+9' } };
    local TurtleCape = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'Pet: R.Acc.+20', [2] = 'Pet: R.Atk.+20', [3] = 'Pet: Damage taken -5%', [4] = 'Pet: "Regen"+10', [5] = 'Pet: Acc.+20', [6] = 'Pet: Atk.+20' } };
    local petNukeCape = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'Pet: M.Dmg.+20', [2] = 'Pet: Mag. Acc.+10', [3] = 'Pet: M.Acc.+20', [4] = 'Pet: Haste+10' } };

    local sets = {
        Idle = Equip.NewSet {
            Head = "Pitre Taj +3",
            Body = 'Hiza. Haramaki +2',
            Hands = { Name = 'Rao Kote +1', AugPath = 'C' },
            Legs = { Name = 'Rao Haidate +1', AugPath = 'C' },
            Feet = { Name = 'Rao Sune-Ate +1', AugPath = 'C' },
            Neck = "Sanctity Necklace",
            Waist = "Moonbow Belt +1",
            Ear1 = "Sroda Earring",
            Ear2 = KaragozEar,
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = petCape,
        },

        Movement = Equip.NewSet {
            Feet = "Hermes' Sandals +1",
        },

        Adoulin = Equip.NewSet {
            Body = "Councilor's Garb",
        },

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
                Feet = "Karagoz Scarpe +2",
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
                Feet = "Karagoz Scarpe +2",
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
                Feet = "Karagoz Scarpe +2",
                Neck = "Shulmanu Collar",
                Waist = "Moonbow Belt +1",
                Ear1 = "Mache Earring +1",
                Ear2 = KaragozEar,
                Ring1 = "Gere Ring",
                Ring2 = "Varar Ring +1",
                Back = petCape,
            },
        },

        PupOnly = Equip.NewSet {
            Head = "Pitre Taj +3",
            Body = "Pitre Tobe +3",
            Hands = "Karagoz Guanti +3",
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

        PetHybrid = Equip.NewSet {
            Head = "Pitre Taj +3",
            Body = "Pitre Tobe +3",
            Hands = { Name = 'Rao Kote +1', AugPath = 'C' },
            Legs = { Name = 'Rao Haidate +1', AugPath = 'C' },
            Feet = "Mpaca\'s Boots",
            Neck = "Shulmanu Collar",
            Waist = "Klouskap Sash +1",
            Ear1 = "Burana Earring",
            Ear2 = KaragozEar,
            Ring1 = "Thurandaut Ring",
            Ring2 = "Varar Ring +1",
            Back = TurtleCape,
        },

        Engaged = Equip.NewSet {
            Head = "Heyoka Cap +1",
            Body = 'Mpaca\'s Doublet',
            Hands = "Karagoz Guanti +3",
            Legs = "Heyoka Subligar +1",
            Feet = "Mpaca\'s Boots",
            Neck = "Shulmanu Collar",
            Waist = "Moonbow Belt +1",
            Ear1 = "Sroda Earring",
            Ear2 = KaragozEar,
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = masterCape,
        },

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

        AM3TP = Equip.NewSet {
            Head = { Name = 'Ryuo Somen +1', AugPath = 'C' },
            Body = 'Malignance Tabard',
            Hands = "Karagoz Guanti +3",
            Legs = "Ryuo Hakama +1",
            Feet = "Malignance Boots",
            Neck = "Lissome Necklace",
            Waist = "Moonbow Belt +1",
            Ear1 = "Digni. Earring",
            Ear2 = "Dedition Earring",
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = "Null Shawl",
        },

        CombatModes = {
            LowAcc = Equip.NewSet {
                Head = "Heyoka Cap +1",
                Body = "Mpaca\'s Doublet",
                Hands = "Herculean Gloves",
                Legs = "Heyoka Subligar +1",
                Feet = "Herculean Boots",
                Neck = "Shulmanu Collar",
                Waist = "Moonbow Belt +1",
                Ear1 = "Brutal Earring",
                Ear2 = "Cessance Earring",
                Ring1 = "Gere Ring",
                Ring2 = "Niqmaddu Ring",
                Back = masterCape,
            },

            HighAcc = Equip.NewSet {
                Head = "Heyoka Cap +1",
                Body = "Malignance Tabard",
                Hands = "Herculean Gloves",
                Legs = "Heyoka Subligar +1",
                Feet = "Herculean Boots",
                Neck = "Shulmanu Collar",
                Waist = "Moonbow Belt +1",
                Ear1 = "Mache Earring +1",
                Ear2 = "Zennaroi Earring",
                Ring1 = "Gere Ring",
                Ring2 = "Chirich Ring +1",
                Back = masterCape,
            },

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

            HighAtk = Equip.NewSet {
                Head = "Adhemar Bonnet +1",
                Body = "Ken. Samue +1",
                Hands = "Adhemar Wrist. +1",
                Legs = "Ken. Hakama +1",
                Feet = "Ken. Sune-Ate +1",
                Neck = "Shulmanu Collar",
                Waist = "Moonbow Belt +1",
                Ear1 = "Mache Earring +1",
                Ear2 = "Mache Earring +1",
                Ring1 = "Gere Ring",
                Ring2 = "Niqmaddu Ring",
                Back = masterCape,
            },

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

            HighHaste = Equip.NewSet {
                Head = "Heyoka Cap +1",
                Body = "Ken. Samue +1",
                Hands = "Adhemar Wrist. +1",
                Legs = "Ken. Hakama +1",
                Feet = "Ken. Sune-Ate +1",
                Neck = "Shulmanu Collar",
                Waist = "Moonbow Belt +1",
                Ear1 = "Brutal Earring",
                Ear2 = "Cessance Earring",
                Ring1 = "Gere Ring",
                Ring2 = "Niqmaddu Ring",
                Back = masterCape,
            },
        },

        Master = Equip.NewSet {
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

        MasterSTP = Equip.NewSet {
            Head = { Name = 'Ryuo Somen +1', AugPath = 'C' },
            Body = 'Malignance Tabard',
            Hands = "Karagoz Guanti +3",
            Legs = "Ryuo Hakama +1",
            Feet = "Malignance Boots",
            Neck = "Lissome Necklace",
            Waist = "Moonbow Belt +1",
            Ear1 = "Digni. Earring",
            Ear2 = "Dedition Earring",
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = "Null Shawl",
        },

        Deploy = Equip.NewSet {
            Ear1 = "Burana Earring",
            Ear2 = "Karagoz Earring",
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
            Head = "Kara. Cappello +2",
            Body = "Passion Jacket",
            Hands = "Nilas Gloves",
            Legs = "Pitre Churidars +3",
            Feet = "Hermes' Sandals +1",
            Neck = "Unmoving Collar +1",
            Waist = "Moonbow Belt +1",
            Ear1 = "Friomisi Earring",
            Ear2 = "Mache Earring +1",
            Ring1 = "Gere Ring",
            Ring2 = "Niqmaddu Ring",
            Back = petCape,
        },

        TacticalSwitch = Equip.NewSet {
            Feet = "Karagoz Scarpe +2",
        },

        WeaponSkill = {
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

            ['Victory Smite'] = Equip.NewSet {
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
                Ring2 = "Rajas Ring",
                Back = masterCape,
            },

            ['Asuran Fists'] = Equip.NewSet {
                Head = "Mpaca\'s Cap",
                Body = "Foire Tobe +3",
                Hands = "Pitre Dastanas +3",
                Legs = "Hiza. Hizayoroi +2",
                Feet = "Mpaca\'s Boots",
                Neck = "Fotia Gorget",
                Waist = "Fotia Belt",
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

            ['Stringing Pummel'] = Equip.NewSet {
                Head = "Mpaca\'s Cap",
                Body = "Mpaca\'s Doublet",
                Hands = "Ryuo Tekko +1",
                Legs = "Mpaca\'s Hose",
                Feet = "Mpaca\'s Boots",
                Neck = "Fotia Gorget",
                Waist = "Fotia Belt",
                Ear1 = "Sroda Earring",
                Ear2 = "Karagoz Earring",
                Ring1 = "Gere Ring",
                Ring2 = "Niqmaddu Ring",
                Back = pummelCape,
            },

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

        Precast = Equip.NewSet {
            Ear1 = "Loquacious Earring",
            Ring1 = "Prolix Ring",
        },

        DT = Equip.NewSet {
            Head = "Nyame Helm",
            Body = "Nyame Mail",
            Hands = "Karagoz Guanti +3",
            Legs = "Kara. Pantaloni +2",
            Feet = "Nyame Sollerets",
            Ring1 = "Gelatinous Ring +1",
            Back = masterCape,
        },

        Hybrid = Equip.NewSet {
            Ammo = 'Automat. Oil +3',
            Head = 'Malignance Chapeau',
            Neck = 'Shulmanu Collar',
            Ear1 = 'Sroda Earring',
            Ear2 = 'Dedition Earring',
            Body = 'Malignance Tabard',
            Hands = 'Karagoz Guanti +3',
            Ring1 = 'Gere Ring',
            Ring2 = 'Niqmaddu Ring',
            Back = { Name = 'Visucius\'s Mantle', Augment = { [1] = 'Damage taken-5%', [2] = '"Dbl.Atk."+10', [3] = 'Accuracy+20', [4] = 'Attack+20', [5] = 'DEX+30' } },
            Waist = 'Moonbow Belt +1',
            Legs = 'Kara. Pantaloni +2',
            Feet = 'Malignance Boots',
        },

        Waltz = Equip.NewSet {
            Body = "Passion Jacket",
        },

        TH = Equip.NewSet {
            Hands = { Name = 'Herculean Gloves', Augment = { [1] = 'Weapon Skill Acc.+19', [2] = 'Mag. Acc.+1', [3] = 'STR+11', [4] = '"Mag. Atk. Bns."+1', [5] = '"Treasure Hunter"+1' } },
            Feet = { Name = 'Herculean Boots', Augment = { [1] = 'Mag. Acc.+16', [2] = 'Accuracy+8', [3] = '"Mag. Atk. Bns."+16', [4] = 'MND+12', [5] = '"Treasure Hunter"+2' } },
        },

        Overdrive = Equip.NewSet {
            Head = "Kara. Capello +2",
            Body = "Pitre Tobe +3",
            Hands = "Karagoz Guanti +3",
            Legs = "Karagoz Pantaloni +2",
            Feet = "Punchinellos",
            Neck = "Shulmanu Collar",
            Waist = "Klouskap Sash +1",
            Ear1 = "Burana Earring",
            Ear2 = KaragozEar,
            Ring1 = "Thurandaut Ring",
            Ring2 = "Varar Ring +1",
            Back = petCape,
        },

        Utsusemi = {
            Precast = Equip.NewSet {
                Head = "Heyoka Cap +1",
                Body = "Passion Jacket",
                Hands = "Rawhide Gloves",
                Legs = "Heyoka Subligar +1",
                Feet = "Tali'ah Crackows +2",
                Neck = "Shulmanu Collar",
                Waist = "Moonbow Belt +1",
                Ear2 = "Mache Earring +1",
                Ring2 = "Varar Ring +1",
                Back = petCape,
            },

            Midcast = Equip.NewSet {
                Head = "Heyoka Cap +1",
                Body = "Passion Jacket",
                Hands = "Rawhide Gloves",
                Legs = "Heyoka Subligar +1",
                Feet = "Tali'ah Crackows +2",
                Neck = "Shulmanu Collar",
                Waist = "Moonbow Belt +1",
                Ear2 = "Mache Earring +1",
                Ring2 = "Varar Ring +1",
                Back = petCape,
            },
        },

        WarpRing = Equip.NewSet {
            Ring1 = "Warp Ring",
        },

        DimRing = Equip.NewSet {
            Ring1 = "Dim. Ring (Holla)",
        },

        Pet = {
            WeaponSkill = Equip.NewSet {
                Head = "Kara. Capello +2",
                Body = "Pitre Tobe +3",
                Hands = "Mpaca's Gloves",
                Legs = "Karagoz Pantaloni +2",
                Feet = "Mpaca's Boots",
                Neck = "Shulmanu Collar",
                Waist = "Klouskap Sash +1",
                Ear1 = "Burana Earring",
                Ear2 = KaragozEar,
                Ring1 = "Thurandaut Ring",
                Ring2 = "Varar Ring +1",
                Back = petCape,
            },

            Physical = Equip.NewSet {
                Head = "Kara. Capello +2",
                Body = "Pitre Tobe +3",
                Hands = "Mpaca's Gloves",
                Legs = "Karagoz Pantaloni +2",
                Feet = "Mpaca's Boots",
                Neck = "Shulmanu Collar",
                Waist = "Klouskap Sash +1",
                Ear1 = "Burana Earring",
                Ear2 = KaragozEar,
                Ring1 = "Thurandaut Ring",
                Ring2 = "Varar Ring +1",
                Back = petCape,
            },

            Magic = Equip.NewSet {
                Head = "Kara. Capello +2",
                Body = "Udug Jacket",
                Hands = "Karagoz Guanti +3",
                Legs = "Pitre Churidars +3",
                Feet = "Pitre Babouches +3",
                Neck = "Pup. Collar +2",
                Waist = "Eschan Stone",
                Ear1 = "Burana Earring",
                Ear2 = KaragozEar,
                Ring1 = "Thurandaut Ring",
                Ring2 = "Tali'ah Ring",
                Back = petNukeCape,
            },

            Cure = Equip.NewSet {
                Head = "Kara. Capello +2",
                Body = "Kara. Farsetto +2",
                Hands = "Karagoz Guanti +3",
                Legs = "Foire Churidars +2",
                Feet = "Foire Babouches +2",
                Neck = "Pup. Collar +2",
                Waist = "Klouskap Sash +1",
                Ear1 = "Burana Earring",
                Ear2 = KaragozEar,
                Ring1 = "Thurandaut Ring",
                Ring2 = "Tali'ah Ring",
                Back = petNukeCape,
            },
        },
    };

    return sets;
end

-- Update all sets with the chosen weapon, then optionally refresh via cb.
function M.update_weapon(sets, settings, refresh_cb)
    local weapon = settings.Weapon;
    if (weapon == nil) then
        return;
    end

    sets.Idle.Main = weapon;
    sets.PetIdle.Tank.Main = weapon;
    sets.PetIdle.Melee.Main = weapon;
    sets.PetIdle.Range.Main = weapon;
    sets.PetIdle.Magic.Main = weapon;
    sets.PupOnly.Main = weapon;
    sets.Turtle.Main = weapon;
    sets.PetHybrid.Main = weapon;
    sets.GodhandsTP.Main = weapon;
    sets.Engaged.Main = weapon;
    sets.AM3TP.Main = weapon;
    sets.Master.Main = weapon;
    sets.MasterSTP.Main = weapon;
    sets.Hybrid.Main = weapon;
    sets.Deploy.Main = weapon;
    sets.Repair.Main = weapon;
    sets.Maintenance.Main = weapon;
    sets.Maneuver.Main = weapon;
    sets.Ventriloquy.Main = weapon;
    sets.TH.Main = weapon;
    if sets.Movement then
        sets.Movement.Main = weapon;
    end

    sets.Utsusemi.Precast.Main = weapon;
    sets.Utsusemi.Midcast.Main = weapon;

    sets.WeaponSkill['Shijin Spiral'].Main = weapon;
    sets.WeaponSkill['Victory Smite'].Main = weapon;
    sets.WeaponSkill.HowlingFists.Main = weapon;
    sets.WeaponSkill['Stringing Pummel'].Main = weapon;
    if weapon == "Karambit" then
        sets.WeaponSkill['Asuran Fists'].Main = weapon;
    end
    sets.WeaponSkill.Default.Main = weapon;

    if sets.Pet and sets.Pet.WeaponSkill then
        sets.Pet.WeaponSkill.Main = weapon;
    end

    sets.Overdrive.Main = weapon;

    sets.CombatModes.LowAcc.Main = weapon;
    sets.CombatModes.HighAcc.Main = weapon;
    sets.CombatModes.LowAtk.Main = weapon;
    sets.CombatModes.HighAtk.Main = weapon;
    sets.CombatModes.LowHaste.Main = weapon;
    sets.CombatModes.HighHaste.Main = weapon;

    if refresh_cb then
        refresh_cb();
    end
end

return M;


