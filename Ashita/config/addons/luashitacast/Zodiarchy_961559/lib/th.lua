local M = {};

local settingsRef = nil;

local thState = {
    enabled = false,
    pending = false,
    targetId = nil,
    overlayed = false,
    lastTp = 0,
};

local function reset_state()
    thState.pending = false;
    thState.targetId = nil;
    thState.overlayed = false;
end

-- Retrieve target id (current or subtarget) via gData or memory manager.
local function get_target_id()
    local tgt = gData.GetTarget();
    if (tgt ~= nil and tgt.ServerId ~= nil and tgt.ServerId ~= 0) then
        return tgt.ServerId;
    end

    if (AshitaCore ~= nil) then
        local tm = AshitaCore:GetMemoryManager():GetTarget();
        if (tm ~= nil and tm.GetServerId ~= nil) then
            local id0 = tm:GetServerId(0);
            if (id0 ~= nil and id0 ~= 0 and id0 ~= 0x04000000) then
                return id0;
            end
            local id1 = tm:GetServerId(1);
            if (id1 ~= nil and id1 ~= 0 and id1 ~= 0x04000000) then
                return id1;
            end
        end
    end

    return nil;
end

function M.init(settings)
    settingsRef = settings;
end

function M.set_enabled(enabled)
    if not settingsRef then return; end
    settingsRef.THMode = enabled;
    thState.enabled = enabled;
    if (not enabled) then
        reset_state();
    end
end

function M.update_target(player)
    if (not thState.enabled) then
        reset_state();
        return;
    end

    if (player == nil or player.Status ~= 'Engaged') then
        reset_state();
        return;
    end

    local tgtId = get_target_id();
    if (tgtId ~= nil) then
        if (tgtId ~= thState.targetId) then
            thState.targetId = tgtId;
            thState.pending = true;
            thState.overlayed = false;
            thState.lastTp = player and player.TP or 0;
            print('[TH] Armed for target: ' .. tostring(tgtId));
        end
    else
        reset_state();
    end
end

function M.maybe_clear_on_tp_gain(player)
    if (not (thState.enabled and thState.pending and thState.targetId)) then
        return;
    end
    if (player == nil or player.Status ~= 'Engaged') then
        return;
    end

    local tp = player.TP or 0;
    if (tp > thState.lastTp) then
        thState.pending = false;
        thState.overlayed = false;
        print('[TH] Cleared on TP gain for target: ' .. tostring(thState.targetId));
    end
    thState.lastTp = tp;
end

function M.clear_on_action(reason)
    if (not (thState.enabled and thState.pending and thState.targetId)) then
        return;
    end
    local tgtId = get_target_id();
    if (tgtId ~= nil and tgtId == thState.targetId) then
        thState.pending = false;
        thState.overlayed = false;
        print('[TH] Cleared on action (' .. reason .. ') for target: ' .. tostring(thState.targetId));
    end
end

function M.apply_overlay(Equip, thSet)
    if (not (thState.pending and thState.targetId and thSet ~= nil)) then
        return false;
    end

    if (not thState.overlayed) then
        print('[TH] Overlaying TH set (pending first hit on target ' .. tostring(thState.targetId) .. ')');
        thState.overlayed = true;
    end
    Equip.Set(thSet);
    return true;
end

function M.is_pending()
    return thState.pending;
end

function M.is_enabled()
    return thState.enabled;
end

-- Packet hook to clear overlay on first landed action.
if (ashita and ashita.events and ashita.events.register) then
    ashita.events.register('packet_in', 'pup_th_first_hit', function(e)
        if (e.id ~= 0x28) then
            return;
        end

        if (not (thState.enabled and thState.pending and thState.targetId)) then
            return;
        end

        local buf = e.data_modified_raw or e.data_raw;
        if (buf == nil) then return; end

        if (not ashita.bits or not ashita.bits.unpack_be) then
            return;
        end

        local meId = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0);
        if (meId == nil) then return; end

        local actorId = ashita.bits.unpack_be(buf, 4, 0, 32);
        if (actorId ~= meId) then return; end

        local targetCount = ashita.bits.unpack_be(buf, 9, 0, 8);
        if (targetCount == nil or targetCount == 0) then return; end

        local size = e.size or 0;
        for pos = 10, size - 4 do
            local tid = ashita.bits.unpack_be(buf, pos, 0, 32);
            if (tid ~= nil and tid == thState.targetId) then
                thState.pending = false;
                thState.overlayed = false;
                print('[TH] First-hit detected (scan) on target: ' .. tostring(thState.targetId));
                return;
            end
        end
    end);
end

return M;


