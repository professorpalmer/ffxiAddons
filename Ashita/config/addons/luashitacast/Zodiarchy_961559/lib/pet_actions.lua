local M = {};

-- Return true if a pet action was handled and gear was set.
function M.handle(petAction, sets, Equip)
    if (petAction == nil) then
        return false;
    end

    local rawType = petAction.ActionType or 'Unknown';
    local normalizedType = '';
    if rawType ~= nil then
        normalizedType = string.lower(tostring(rawType)):gsub('%s+', '');
    end

    print('Pet action detected: ' .. (petAction.Name or 'Unknown') .. ' (' .. tostring(rawType) .. ')');

    -- Normalize the action classification so we catch more server variations.
    local isSpell = (normalizedType == 'spell') or (normalizedType == 'magic') or (normalizedType == 'ninjutsu');
    local isPhysical =
        (normalizedType == 'ability') or
        (normalizedType == 'mobskill') or
        (normalizedType == 'monsterskill') or
        (normalizedType == 'weaponskill') or
        (normalizedType == 'weapon') or
        (normalizedType == 'ws') or
        (normalizedType == 'petability') or
        (normalizedType == 'petweaponskill') or
        (normalizedType == 'range') or
        (normalizedType == 'ranged');

    local name = petAction.Name or 'Unknown';

    -- Certain WS scale with magic damage even though they are WS category.
        local magicWS = {
            ['Magic Mortar'] = true,
            ['Cannibal Blade'] = true,
        };

    if isSpell then
        if (string.find(name, 'Cure') or string.find(name, 'Cura')) then
            print('Pet casting Cure: ' .. name);
            Equip.Set(sets.Pet.Cure);
        else
            print('Pet casting Magic: ' .. name);
            Equip.Set(sets.Pet.Magic);
        end
        return true;
    end

    if isPhysical or magicWS[name] then
        if magicWS[name] then
            print('Using Pet Magic WS set for: ' .. name);
            Equip.Set(sets.Pet.Magic);
        else
            print('Using Pet Physical WS set for: ' .. name .. ' [' .. normalizedType .. ']');
            Equip.Set(sets.Pet.Physical);
        end
        return true;
    end

    -- Fallback: if the server sent an unknown type, assume it is a WS/ability.
    print('Pet action type unrecognized; defaulting to physical WS set.');
    Equip.Set(sets.Pet.Physical);
    return true;
end

return M;

