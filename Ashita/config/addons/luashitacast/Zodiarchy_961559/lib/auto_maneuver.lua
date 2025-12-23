local M = {};

local settingsRef = nil;
local statusRef = nil;
local lastManeuverTime = 0;
local nextIndex = 1;

-- User-defined rotation (3 maneuvers). Defaults to fire/wind/fire until set.
local currentRotation = { 'Fire Maneuver', 'Wind Maneuver', 'Fire Maneuver' };
local slots = {};
local REFRESH_LEAD = 55; -- fallback seconds after last application if no timer data
local MIN_REMAIN_FOR_REFRESH = 12; -- if timer is known, refresh when remaining <= this
local abilityIds = {
    ['Fire Maneuver'] = 210,
    ['Ice Maneuver'] = 211,
    ['Wind Maneuver'] = 212,
    ['Earth Maneuver'] = 213,
    ['Thunder Maneuver'] = 214,
    ['Water Maneuver'] = 215,
    ['Light Maneuver'] = 216,
    ['Dark Maneuver'] = 217,
};

local function rebuild_slots()
    slots = {};
    for i = 1, 3 do
        slots[i] = {
            name = currentRotation[i],
            last_applied = 0,
        };
    end
end

function M.init(settings, statusModule)
    settingsRef = settings;
    statusRef = statusModule;
    rebuild_slots();
end

function M.set_enabled(enabled)
    if not settingsRef then return; end
    settingsRef.AutoManeuver = enabled;
    if enabled then
        print('[Maneuver] Auto maneuvers: ON');
    else
        print('[Maneuver] Auto maneuvers: OFF');
    end
end

local function get_rotation()
    return currentRotation;
end

-- Try to read remaining seconds for a buff by name from Ashita buff timers.
local function get_buff_remaining_seconds(buffName)
    if not AshitaCore then return nil; end
    local resx = AshitaCore:GetResourceManager();
    local pm = AshitaCore:GetMemoryManager():GetPlayer();
    if not (resx and pm and pm.GetBuffs and pm.GetBuffTimers) then
        return nil;
    end

    local buffs = pm:GetBuffs();
    local timers = pm:GetBuffTimers();
    if not (buffs and timers) then return nil; end

    for idx, buffId in ipairs(buffs) do
        local name = resx:GetString("buffs.names", buffId);
        if name and string.lower(name) == string.lower(buffName) then
            local t = timers[idx];
            if t and t > 0 then
                -- Ashita timers are in milliseconds; convert if large
                if t > 600 then
                    return math.floor(t / 1000);
                else
                    return t;
                end
            end
        end
    end
    return nil;
end

-- Called each HandleDefault; lightweight check to fire maneuvers when needed.
function M.tick(player, pet)
    if not settingsRef or not settingsRef.AutoManeuver then
        return;
    end
    -- Pet validity: be permissive (different installs expose isvalid/IsValid/Valid).
    local petValid = pet and (pet.isvalid == true or pet.IsValid == true or pet.Valid == true or pet.Name ~= nil);
    if not petValid then
        return;
    end
    if statusRef and statusRef.HasStatus and statusRef.HasStatus('Overload') then
        return;
    end

    local now = os.time();

    local rotation = get_rotation();
    if not rotation or #rotation == 0 then
        return;
    end

    -- Determine which slot needs refresh first (priority: missing buff, then nearing expiry)
    local function has_status(name)
        if statusRef and statusRef.HasStatus then
            return statusRef.HasStatus(name);
        end
        return false;
    end

    local needIdx = nil;
    local oldestDelta = -math.huge;

    for i = 1, 3 do
        local slot = slots[i];
        local name = rotation[i];
        slot.name = name;
        local active = has_status(name);
        local delta = now - (slot.last_applied or 0);
        local remain = get_buff_remaining_seconds(name);

        if not active then
            needIdx = i;
            break; -- highest priority
        elseif remain and remain <= MIN_REMAIN_FOR_REFRESH then
            needIdx = i;
            break;
        elseif not remain and delta >= REFRESH_LEAD and delta > oldestDelta then
            needIdx = i;
            oldestDelta = delta;
        end
    end

    if not needIdx then
        return;
    end

    -- Simple cooldown throttle to avoid spam
    local maneuver = rotation[needIdx];
    if now - lastManeuverTime < 11 then
        return;
    end

    if AshitaCore and AshitaCore:GetChatManager() then
        AshitaCore:GetChatManager():QueueCommand(1, '/pet "' .. maneuver .. '" <me>');
    end
    lastManeuverTime = now;
    slots[needIdx].last_applied = now;
    nextIndex = needIdx + 1;
end

-- Parse a string like "firewindfire" or "fire,wind,fire" into a 3-slot rotation.
local function parse_rotation(arg)
    if not arg or arg == '' then return nil; end
    local cleaned = arg:gsub('[,%s]+', ''); -- remove commas/spaces
    local tokens = {};
    local i = 1;
    local map = {
        fire = 'Fire Maneuver',
        ice = 'Ice Maneuver',
        wind = 'Wind Maneuver',
        earth = 'Earth Maneuver',
        thunder = 'Thunder Maneuver',
        water = 'Water Maneuver',
        light = 'Light Maneuver',
        dark = 'Dark Maneuver',
    };
    while i <= #cleaned do
        local matched = false;
        for key, full in pairs(map) do
            local len = #key;
            if cleaned:sub(i, i + len - 1) == key then
                table.insert(tokens, full);
                i = i + len;
                matched = true;
                break;
            end
        end
        if not matched then
            return nil; -- invalid token
        end
    end
    if #tokens == 3 then
        return tokens;
    end
    return nil;
end

-- Command handler to set rotation: expects a single concatenated string or comma-separated.
function M.set_rotation(arg)
    local rot = parse_rotation(string.lower(arg or ''));
    if rot and #rot == 3 then
        currentRotation = rot;
        rebuild_slots();
        print('[Maneuver] Rotation set to: ' .. table.concat(rot, ' | '));
        nextIndex = 1;
        return true;
    else
        print('[Maneuver] Invalid rotation. Example: /maneuver firewindfire or /maneuver fire,wind,fire');
        return false;
    end
end

function M.get_rotation_string()
    if not currentRotation then return 'none'; end
    return table.concat(currentRotation, ' | ');
end

return M;

