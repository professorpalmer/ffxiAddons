local M = {};

local settings = nil;
local Equip = nil;
local sets = nil;

-- simple state so we only force the WS set once per TP window
local state = {
    armed = false,
    lastTP = 0,
};

function M.init(cfg, equip, setref)
    settings = cfg;
    Equip = equip;
    sets = setref;
end

local function should_arm(player, pet, tp)
    if not settings or not settings.PetSwapMode then
        return false;
    end
    if settings.TeleportActive then
        return false;
    end
    if not player or not pet or not pet.isvalid then
        return false;
    end
    -- Require pet engaged on something (has a target)
    if pet.Status ~= 'Engaged' and pet.Status ~= 'Fighting' then
        return false;
    end
    return tp >= (settings.PetSwapTP or 1000);
end

function M.tick(player, pet)
    if not settings or not Equip or not sets then
        return;
    end

    local petTP = 0;
    local mm = AshitaCore and AshitaCore:GetMemoryManager();
    if mm and mm:GetPlayer() then
        petTP = mm:GetPlayer():GetPetTP() or 0;
    end

    -- If we had armed and TP spent (WS likely went off) or toggle turned off, clear state.
    if state.armed and (not settings.PetSwapMode or petTP < math.max(0, (settings.PetSwapTP or 1000) - 100)) then
        state.armed = false;
    end

    if should_arm(player, pet, petTP) and not state.armed then
        -- Equip pet WS set a moment before the pet acts.
        local wsSet = (sets.Pet and (sets.Pet.WeaponSkill or sets.Pet.Physical)) or nil;
        if wsSet then
            Equip.Set(wsSet);
            state.armed = true;
            print(string.format('[Pet TP Swap] Armed WS set at %d TP.', petTP));
        end
    end

    state.lastTP = petTP;
end

return M;
