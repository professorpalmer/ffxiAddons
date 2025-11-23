require('common');

local gear = gFunc.LoadFile('common/gear.lua');
local Equip = gFunc.LoadFile('common/equip.lua');
local Status = gFunc.LoadFile('common/status.lua');
local itemHandler = gFunc.LoadFile('common/items.lua');

local profile = {}

local settings = {
    MeleeMode = 'Default',    -- Default, Acc, Hybrid, DT, Proc
    Weapon = 'Kikoku',        -- Primary weapon: Kikoku, Naegling, Karambit
    OffhandWeapon = 'Tauret', -- Offhand weapon: Tauret, Shijo, Kunimitsu
    DTMode = false,           -- Toggle damage taken mode
    HybridMode = false,       -- Toggle hybrid DT/DPS mode
    TeleportActive = false,   -- Prevent automatic gear changes when teleport item equipped
    RegenMode = false,        -- Manual regen/idle gear mode - toggleable with /regen
    MovementMode = false,     -- Movement speed mode
    THMode = false,           -- Treasure Hunter mode
    NinjutsuMode = 'Nuke',    -- Default, Acc, Nuke
    ShadowMode = false,       -- Special shadow casting mode
    EnmityMode = false,       -- Enmity generation mode
}

-- Define back slot gear
local ninCape = 'Null Shawl';
local wsCape = 'Null Shawl';
local fcCape = 'Null Shawl';
local AgiDAcape = { Name = 'Andartia\'s Mantle', Augment = { [1] = 'AGI+20', [2] = '"Dbl.Atk."+10' } };
local magicBack = { Name = 'Andartia\'s Mantle', Augment = { [1] = 'INT+20', [2] = '"Mag. Atk. Bns."+10', [3] = 'Mag. Acc.+20', [4] = 'Magic Damage+20', [5] = 'Magic Damage +10' } };

-- Function to check if it's currently Dusk to Dawn time (17:00-07:00 Vana'diel time)
local function IsDuskToDawn()
    local time = gData.GetTimestamp();
    -- Dusk to Dawn is 17:00 to 07:00 (17-23, 0-6)
    return (time.hour >= 17 or time.hour < 7);
end

local sets = {

    -- Naked set for sortie runs
    Naked = Equip.NewSet {
        -- All slots intentionally left blank for complete naked state
    },

    -- Idle set (when not engaged)
    Idle = Equip.NewSet {
        Ammo = 'Date Shuriken',
        Head = { Name = 'Ryuo Somen +1', AugPath = 'C' },
        Body = 'Hiza. Haramaki +2',
        Hands = { Name = 'Rao Kote +1', AugPath = 'C' },
        Legs = { Name = 'Rao Haidate +1', AugPath = 'C' },
        Feet = { Name = 'Rao Sune-Ate +1', AugPath = 'C' },
        Neck = 'Ninja Nodowa +2',
        Waist = { Name = 'Sailfi Belt +1', AugPath = 'A' },
        Ear1 = 'Dedition Earring',
        Ear2 = 'Hattori Earring +1',
        Ring1 = 'Gere Ring',
        Ring2 = 'Epona\'s Ring',
        Back = ninCape,
    },




    -- Movement speed set
    Movement = Equip.NewSet {
        Feet = 'Herald\'s Gaiters',
    },

    -- Standard TP sets
    Engaged = Equip.NewSet {
        Ammo = 'Date Shuriken',
        Head = 'Malignance Chapeau',
        Body = 'Mpaca\'s Doublet',
        Hands = 'Adhemar Wrist. +1',
        Legs = { Name = 'Ryuo Hakama +1', AugPath = 'D' },
        Feet = 'Tatena. Sune. +1',
        Neck = 'Ninja Nodowa +2',
        Waist = 'Windbuffet Belt +1',
        Ear1 = 'Dedition Earring',
        Ear2 = { Name = 'Hattori Earring +1', Augment = { [1] = 'Accuracy+12', [2] = '"Store TP"+4', [3] = 'Mag. Acc.+12' } },
        Ring1 = 'Gere Ring',
        Ring2 = 'Epona\'s Ring',
        Back = ninCape,
    },

    -- High Accuracy TP set
    EngagedAcc = Equip.NewSet {
        Ammo = 'Date Shuriken',
        Head = { Name = 'Ryuo Somen +1', AugPath = 'C' },
        Body = 'Malignance Tabard',
        Hands = 'Adhemar Wrist. +1',
        Legs = 'Mpaca\'s Hose',
        Feet = 'Tatena. Sune. +1',
        Neck = 'Ninja Nodowa +2',
        Waist = { Name = 'Sailfi Belt +1', AugPath = 'A' },
        Ear1 = 'Dedition Earring',
        Ear2 = { Name = 'Hattori Earring +1', Augment = { [1] = 'Accuracy+12', [2] = '"Store TP"+4', [3] = 'Mag. Acc.+12' } },
        Ring1 = 'Gere Ring',
        Ring2 = 'Chirich Ring +1',
        Back = ninCape,
    },

    -- Hybrid DT/DPS set
    EngagedHybrid = Equip.NewSet {
        Ammo = 'Date Shuriken',
        Head = 'Malignance Chapeau',
        Body = 'Malignance Tabard',
        Hands = 'Malignance Gloves',
        Legs = 'Malignance Tights',
        Feet = 'Malignance Boots',
        Neck = 'Ninja Nodowa +2',
        Waist = 'Windbuffet Belt +1',
        Ear1 = 'Dedition Earring',
        Ear2 = { Name = 'Hattori Earring +1', Augment = { [1] = 'Accuracy+12', [2] = '"Store TP"+4', [3] = 'Mag. Acc.+12' } },
        Ring1 = 'Gere Ring',
        Ring2 = 'Epona\'s Ring',
        Back = ninCape,
    },

    -- Full DT set
    DT = Equip.NewSet {
        Ammo = 'Date Shuriken',
        Head = 'Nyame Helm',
        Body = 'Nyame Mail',
        Hands = 'Nyame Gauntlets',
        Legs = 'Nyame Flanchard',
        Feet = 'Nyame Sollerets',
        Neck = 'Loricate Torque +1',
        Waist = { Name = 'Sailfi Belt +1', AugPath = 'A' },
        Ear1 = 'Dedition Earring',
        Ear2 = 'Hattori Earring +1',
        Ring1 = 'Gelatinous Ring +1',
        Ring2 = 'Epona\'s Ring',
        Back = ninCape,
    },

    -- Proc set for low damage (Abyssea etc)
    EngagedProc = Equip.NewSet {
        Ammo = 'Date Shuriken',
        Head = { Name = 'Ryuo Somen +1', AugPath = 'C' },
        Body = 'Hiza. Haramaki +2',
        Hands = 'Adhemar Wrist. +1',
        Legs = { Name = 'Ryuo Hakama +1', AugPath = 'D' },
        Feet = { Name = 'Herculean Boots', Augment = { [1] = 'Accuracy+19', [2] = 'CHR+3', [3] = 'Attack+11', [4] = '"Triple Atk."+4' } },
        Neck = 'Ninja Nodowa +2',
        Waist = { Name = 'Sailfi Belt +1', AugPath = 'A' },
        Ear1 = 'Dedition Earring',
        Ear2 = { Name = 'Hattori Earring +1', Augment = { [1] = 'Accuracy+12', [2] = '"Store TP"+4', [3] = 'Mag. Acc.+12' } },
        Ring1 = 'Gere Ring',
        Ring2 = 'Epona\'s Ring',
        Back = ninCape,
    },

    -- Weapon Skills
    WeaponSkill = {
        -- Blade: Hi - AGI-based, crit damage varies by TP
        ['Blade: Hi'] = Equip.NewSet {
            Ammo = 'Date Shuriken',
            Head = 'Mpaca\'s Cap',
            Body = 'Mpaca\'s Doublet',
            Hands = 'Adhemar Wrist. +1',
            Legs = 'Mpaca\'s Hose',
            Feet = 'Hattori Kyahan +2',
            Neck = 'Ninja Nodowa +2',
            Waist = 'Fotia Belt',
            Ear1 = 'Mache Earring +1',
            Ear2 = 'Hattori Earring +1',
            Ring1 = 'Gere Ring',
            Ring2 = 'Rajas Ring',
            Back = AgiDAcape,
        },

        -- Blade: Shun - DEX-based, multi-hit
        ['Blade: Shun'] = Equip.NewSet {
            Ammo = 'Date Shuriken',
            Head = 'Mpaca\'s Cap',
            Body = 'Malignance Tabard',
            Hands = 'Adhemar Wrist. +1',
            Legs = 'Mpaca\'s Hose',
            Feet = 'Hattori Kyahan +2',
            Neck = 'Ninja Nodowa +2',
            Waist = 'Fotia Belt',
            Ear1 = 'Mache Earring +1',
            Ear2 = 'Hattori Earring +1',
            Ring1 = 'Gere Ring',
            Ring2 = 'Rajas Ring',
            Back = AgiDAcape,
        },

        -- Blade: Chi - STR-based, magical damage
        ['Blade: Chi'] = Equip.NewSet {
            Ammo = 'Date Shuriken',
            Head = 'Mpaca\'s Cap',
            Body = 'Malignance Tabard',
            Hands = 'Adhemar Wrist. +1',
            Legs = 'Mochi. Hakama +3',
            Feet = 'Hattori Kyahan +2',
            Neck = 'Ninja Nodowa +2',
            Waist = 'Fotia Belt',
            Ear1 = 'Mache Earring +1',
            Ear2 = 'Hattori Earring +1',
            Ring1 = 'Gere Ring',
            Ring2 = 'Rajas Ring',
            Back = AgiDAcape,
        },

        -- Blade: Teki - STR-based, magical damage
        ['Blade: Teki'] = Equip.NewSet {
            Ammo = 'Date Shuriken',
            Head = 'Mpaca\'s Cap',
            Body = 'Malignance Tabard',
            Hands = 'Adhemar Wrist. +1',
            Legs = 'Mochi. Hakama +3',
            Feet = 'Hattori Kyahan +2',
            Neck = 'Ninja Nodowa +2',
            Waist = 'Fotia Belt',
            Ear1 = 'Mache Earring +1',
            Ear2 = 'Hattori Earring +1',
            Ring1 = 'Gere Ring',
            Ring2 = 'Rajas Ring',
            Back = AgiDAcape,
        },

        -- Blade: To - STR-based, magical damage
        ['Blade: To'] = Equip.NewSet {
            Ammo = 'Date Shuriken',
            Head = 'Mpaca\'s Cap',
            Body = 'Malignance Tabard',
            Hands = 'Adhemar Wrist. +1',
            Legs = 'Mochi. Hakama +3',
            Feet = 'Hattori Kyahan +2',
            Neck = 'Ninja Nodowa +2',
            Waist = 'Fotia Belt',
            Ear1 = 'Mache Earring +1',
            Ear2 = 'Hattori Earring +1',
            Ring1 = 'Gere Ring',
            Ring2 = 'Rajas Ring',
            Back = AgiDAcape,
        },

        -- Default fallback for other weapon skills
        Default = Equip.NewSet {
            Ammo = 'Date Shuriken',
            Head = 'Mpaca\'s Cap',
            Body = 'Malignance Tabard',
            Hands = 'Adhemar Wrist. +1',
            Legs = 'Mochi. Hakama +3',
            Feet = 'Hattori Kyahan +2',
            Neck = 'Ninja Nodowa +2',
            Waist = { Name = 'Sailfi Belt +1', AugPath = 'A' },
            Ear1 = 'Mache Earring +1',
            Ear2 = 'Hattori Earring +1',
            Ring1 = 'Gere Ring',
            Ring2 = 'Rajas Ring',
            Back = AgiDAcape,
        },

        -- Proc set for low damage weapon skills
        Proc = Equip.NewSet {
            Ammo = 'Date Shuriken',
            Head = 'Mpaca\'s Cap',
            Body = 'Hiza. Haramaki +2',
            Hands = 'Adhemar Wrist. +1',
            Legs = 'Mpaca\'s Hose',
            Feet = 'Herculean Boots',
            Neck = 'Ninja Nodowa +2',
            Waist = { Name = 'Sailfi Belt +1', AugPath = 'A' },
            Ear1 = 'Mache Earring +1',
            Ear2 = 'Hattori Earring +1',
            Ring1 = 'Gere Ring',
            Ring2 = 'Rajas Ring',
            Back = ninCape,
        },
    },

    -- Fast Cast for ninjutsu
    Precast = Equip.NewSet {
        Ammo = 'Ghastly Tathlum +1',
        Head = { Name = 'Ryuo Somen +1', AugPath = 'C' },
        Body = 'Dread Jupon',
        Hands = 'Mochikuzi Tekko +3',
        Legs = 'Mpaca\'s Hose',
        Feet = 'Herculean Boots',
        Neck = 'Ninja Nodowa +2',
        Waist = { Name = 'Sailfi Belt +1', AugPath = 'A' },
        Ear1 = 'Dedition Earring',
        Ear2 = 'Hattori Earring +1',
        Ring1 = 'Prolix Ring',
        Ring2 = 'Epona\'s Ring',
        Back = AgiDAcape,
    },

    -- Ninjutsu sets
    Ninjutsu = {
        -- Utsusemi (shadow magic)
        Utsusemi = Equip.NewSet {
            Ammo = 'Ghastly Tathlum +1',
            Head = { Name = 'Ryuo Somen +1', AugPath = 'C' },
            Body = 'Mochi. Chainmail +3',
            Hands = 'Mochikuzi Tekko +3',
            Legs = 'Arjuna Breeches',
            Feet = 'Hattori Kyahan +1',
            Neck = 'Ninja Nodowa +2',
            Waist = { Name = 'Sailfi Belt +1', AugPath = 'A' },
            Ear1 = 'Dedition Earring',
            Ear2 = 'Hattori Earring +1',
            Ring1 = 'Gere Ring',
            Ring2 = 'Epona\'s Ring',
            Back = AgiDAcape,
        },

        -- Elemental ninjutsu (nuking)
        Nuke = Equip.NewSet {
            Ammo = 'Ghastly Tathlum +1',
            Head = 'Mochi. Hatsuburi +3', -- MB damage bonus
            Body = 'Nyame Mail',          -- MAB + MB damage
            Hands = 'Hattori Tekko +2',   -- MAB + MB damage
            Legs = 'Nyame Flanchard',     -- MAB + MB damage
            Feet = 'Mochi. Kyahan +3',    -- MAB + MB damage
            Neck = 'Atzintli Necklace',
            Waist = 'Eschan Stone',       -- MAB
            Ear1 = 'Hecate\'s Earring',   -- MAB
            Ear2 = 'Friomisi Earring',    -- MAB
            Ring1 = 'Metamor. Ring +1',   -- MAB
            Ring2 = 'Mujin Band',         -- MB damage
            Back = magicBack,
        },

        -- Magic accuracy focused
        MagicAcc = Equip.NewSet {
            Ammo = 'Ghastly Tathlum +1',
            Head = 'Hachi. Hatsu. +3',
            Body = 'Nyame Mail',
            Hands = 'Nyame Gauntlets',
            Legs = 'Nyame Flanchard',
            Feet = 'Nyame Sollerets',
            Neck = 'Atzintli Necklace',
            Waist = 'Eschan Stone',
            Ear1 = 'Friomisi Earring',
            Ear2 = 'Digni. Earring',
            Ring1 = 'Metamor. Ring +1',
            Ring2 = 'Mujin Band',
            Back = magicBack,
        },
    },

    -- Job Abilities and special modes
    Yonin = Equip.NewSet {
        --Legs = 'Hattori Hakama +1', -- Enhances Yonin effect
    },

    Innin = Equip.NewSet {
        --Head = 'Hattori Zukin +1', -- Best available for Innin
    },

    Migawari = Equip.NewSet {
        --Body = 'Hattori Ningi +1', -- Body piece for Migawari
    },

    Futae = Equip.NewSet {
        Hands = 'Hattori Tekko +2', -- Enhances Futae effect
    },

    -- Enmity generation set
    Enmity = Equip.NewSet {
        Ammo = 'Date Shuriken',
        Head = { Name = 'Ryuo Somen +1', AugPath = 'C' },
        Body = 'Hiza. Haramaki +2',
        Hands = 'Adhemar Wrist. +1',
        Legs = 'Mpaca\'s Hose',
        Feet = 'Herculean Boots',
        Neck = 'Ninja Nodowa +2',
        Waist = { Name = 'Sailfi Belt +1', AugPath = 'A' },
        Ear1 = 'Dedition Earring',
        Ear2 = 'Hattori Earring +1',
        Ring1 = 'Gere Ring',
        Ring2 = 'Epona\'s Ring',
        Back = ninCape,
    },

    -- Treasure Hunter set
    TH = Equip.NewSet {
        Waist = 'Chaac Belt',
        Feet = { Name = 'Herculean Boots', Augment = { [1] = 'Accuracy+19', [2] = 'CHR+3', [3] = 'Attack+11', [4] = '"Treasure Hunter"+2' } },
    },

    -- Dusk to Dawn set (17:00-07:00 in-game time) - applies when not engaged
    DuskToDawn = Equip.NewSet {
        Feet = 'Hachi. Kyahan +1',
    },

    -- Naegling weapon set (activated with /nag command)
    Nag = Equip.NewSet {
        Main = 'Naegling',
        Sub = 'Achiuchikapu',
    },

    -- Teleportation rings
    WarpRing = Equip.NewSet {
        Ring1 = 'Warp Ring',
    },

    DimRing = Equip.NewSet {
        Ring1 = 'Dim. Ring (Holla)',
    },

}

-- Weapons are left blank - manage manually
-- This allows flexibility to experiment with different weapon combinations

profile.Sets = sets

profile.OnLoad = function()
    gSettings.AllowAddSet = true;
    gFunc.LockStyle(sets.Engaged); -- Lock to engaged gear appearance

    -- Chat aliases/commands
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /meleemode /lac fwd meleemode');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /dt /lac fwd dt');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /hybrid /lac fwd hybrid');

    AshitaCore:GetChatManager():QueueCommand(1, '/alias /warpring /lac fwd warpring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /dimring /lac fwd dimring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /refresh /lac fwd refresh');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /movement /lac fwd movement');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /th /lac fwd th');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /regen /lac fwd regen');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /nin /lac fwd nin');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /shadows /lac fwd shadows');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /enmity /lac fwd enmity');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /nag /lac fwd nag');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias /naked /lac fwd naked');

    -- Register hotkey for DEL key (Vile Elixir)
    AshitaCore:GetChatManager():QueueCommand(1, '/bind delete /lac fwd vileelixir');

    print('NIN Profile Loaded');
    print('Commands: /meleemode (default/acc/hybrid/proc), /dt, /hybrid, /movement, /th, /nag');
    print('Ninja: /nin (nuke/macc), /shadows, /enmity');
    print('Teleport: /warpring, /dimring, /refresh');
    print('Regen Control: /regen - Toggle manual regen/idle gear');
    print('Weapons: /nag - Equip Naegling + Achiuchikapu');
    print('Hotkey: DEL key for Vile Elixir items');
end

profile.OnUnload = function()
    -- Clean up aliases
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /meleemode');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /dt');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /hybrid');

    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /warpring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /dimring');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /refresh');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /movement');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /th');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /regen');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /nin');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /shadows');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /enmity');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /nag');
    AshitaCore:GetChatManager():QueueCommand(1, '/alias delete /naked');

    -- Unbind DEL key
    AshitaCore:GetChatManager():QueueCommand(1, '/unbind delete');
end

profile.HandleCommand = function(args)
    if (args[1] == 'meleemode') then
        if (args[2] ~= nil) then
            local mode = string.lower(args[2]);
            if (mode == 'default' or mode == 'acc' or mode == 'hybrid' or mode == 'proc') then
                settings.MeleeMode = mode:gsub('^%l', string.upper);
                -- Clear conflicting modes
                if settings.MeleeMode ~= 'Default' then
                    settings.DTMode = false;
                    settings.HybridMode = false;
                end
                print('Melee mode set to: ' .. settings.MeleeMode);
                profile.HandleDefault();
            else
                print('Invalid mode. Use: default, acc, hybrid, or proc');
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
    elseif (args[1] == 'nin') then
        if (args[2] ~= nil) then
            local mode = string.lower(args[2]);
            if (mode == 'default' or mode == 'nuke' or mode == 'macc') then
                settings.NinjutsuMode = mode:gsub('^%l', string.upper);
                print('Ninjutsu mode set to: ' .. settings.NinjutsuMode);
            else
                print('Invalid mode. Use: default, nuke, or macc');
            end
        else
            print('Current ninjutsu mode: ' .. settings.NinjutsuMode);
        end
        return;
    elseif (args[1] == 'shadows') then
        settings.ShadowMode = not settings.ShadowMode;
        print('Shadow mode: ' .. (settings.ShadowMode and 'On' or 'Off'));
        return;
    elseif (args[1] == 'enmity') then
        settings.EnmityMode = not settings.EnmityMode;
        print('Enmity mode: ' .. (settings.EnmityMode and 'On' or 'Off'));
        profile.HandleDefault();
        return;
    elseif (args[1] == 'nag') then
        print('Equipping Naegling weapon set');
        Equip.Set(sets.Nag);
        return;
    elseif (args[1] == 'naked') then
        print('Equipping Naked set');
        Equip.Set(sets.Naked);
        return;
    elseif (args[1] == 'warpring') then
        -- Equip warp ring and use it after 10 seconds
        settings.TeleportActive = true;
        print('Warp Ring equipped - Using in 10 seconds...');
        gFunc.ForceEquip(14, 'Warp Ring'); -- Slot 14 is Ring1
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
        gFunc.ForceEquip(14, 'Dim. Ring (Holla)'); -- Slot 14 is Ring1
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
        settings.TeleportActive = false;
        settings.DTMode = false;
        settings.HybridMode = false;
        settings.MovementMode = false;
        settings.MeleeMode = 'Default';
        settings.EnmityMode = false;
        print('Returning to normal gear');
        profile.HandleDefault();
        return;
    elseif (args[1] == 'regen') then
        settings.RegenMode = not settings.RegenMode;
        -- Clear other conflicting modes when activating
        if settings.RegenMode then
            settings.DTMode = false;
            settings.HybridMode = false;
            settings.MovementMode = false;
            settings.MeleeMode = 'Default';
            settings.EnmityMode = false;
        end
        print('Regen mode: ' .. (settings.RegenMode and 'On' or 'Off'));
        profile.HandleDefault(); -- Refresh gear
        return;
    elseif (args[1] == 'vileelixir') then
        -- Vile Elixir search and use logic (copied from other profiles)
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

                    if string.find(string.lower(itemName), 'vile elixir') then
                        print('Found potential Vile Elixir item: "' .. itemName .. '" (ID: ' .. item.Id .. ')');
                    end

                    if itemName == 'Vile Elixir +1' or itemName == 'Vile Elixir+1' or string.find(string.lower(itemName), 'vile elixir%+1') then
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

                    if itemName == 'Vile Elixir' and not string.find(string.lower(itemName), '%+1') then
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
        elseif (settings.MeleeMode == 'Proc') then
            return sets.EngagedProc;
        else
            return sets.Engaged;
        end
    else
        -- When not engaged, allow movement overlay and regen preference
        if (settings.MovementMode or player.IsMoving) then
            return sets.Movement;
        end

        if (settings.RegenMode) then
            return sets.Idle;
        end

        return sets.Idle;
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
        if (Status.HasStatus('Yonin') and sets.Yonin) then
            Equip.Set(sets.Yonin);
        end

        if (Status.HasStatus('Innin') and sets.Innin) then
            Equip.Set(sets.Innin);
        end

        if (Status.HasStatus('Migawari') and sets.Migawari) then
            Equip.Set(sets.Migawari);
        end

        -- Apply Dusk to Dawn gear when not engaged
        if (player.Status ~= 'Engaged' and IsDuskToDawn()) then
            Equip.Set(sets.DuskToDawn);
        end

        -- Apply TH gear if mode is active
        if (settings.THMode) then
            Equip.Set(sets.TH);
        end

        -- Apply enmity gear if mode is active
        if (settings.EnmityMode) then
            Equip.Set(sets.Enmity);
        end
    end
end

profile.HandleAbility = function()
    local ability = gData.GetAction();

    -- Job abilities don't need specific gear in our current setup
    -- but we could add specific sets for things like Provoke, etc.
    if (ability.Name == 'Provoke') then
        Equip.Set(sets.Enmity);
    end
end

profile.HandleWeaponskill = function()
    local ws = gData.GetAction();

    -- Check for proc mode first
    if (settings.MeleeMode == 'Proc') then
        Equip.Set(sets.WeaponSkill.Proc);
        return;
    end

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

    if (spell.Skill == 'Ninjutsu') then
        if (string.find(spell.Name, 'Utsusemi')) then
            Equip.Set(sets.Ninjutsu.Utsusemi);
        elseif (string.find(spell.Name, 'Katon') or string.find(spell.Name, 'Hyoton') or
                string.find(spell.Name, 'Huton') or string.find(spell.Name, 'Doton') or
                string.find(spell.Name, 'Raiton') or string.find(spell.Name, 'Suiton')) then
            if (settings.NinjutsuMode == 'Nuke') then
                Equip.Set(sets.Ninjutsu.Nuke);
            elseif (settings.NinjutsuMode == 'Macc') then
                Equip.Set(sets.Ninjutsu.MagicAcc);
            else
                Equip.Set(sets.Ninjutsu.Nuke);
            end

            -- Apply Futae bonus if active
            if (Status.HasStatus('Futae') and sets.Futae) then
                Equip.Set(sets.Futae);
            end
        else
            -- Other ninjutsu (debuffs, etc.)
            Equip.Set(sets.Ninjutsu.MagicAcc);
        end
    end

    -- Apply TH gear if mode is active
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
