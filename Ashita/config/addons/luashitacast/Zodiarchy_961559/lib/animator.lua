local M = {};

local bit = _G.bit or require('bit');
local RANGE_SLOT = 0x02;
local pupLib = nil;
local lastAnimatorEquipped = nil;

function M.init(pupLibRef)
    pupLib = pupLibRef;
end

local function get_equipped_item_name(slot)
    if (AshitaCore == nil) then
        return nil;
    end

    local inv = AshitaCore:GetMemoryManager():GetInventory();
    if (inv == nil) then
        return nil;
    end

    local equipped = inv:GetEquippedItem(slot);
    if (equipped == nil or equipped.Index == 0) then
        return nil;
    end

    local container = bit.band(equipped.Index, 0xFF00) / 0x0100;
    local index = bit.band(equipped.Index, 0x00FF);
    local item = inv:GetContainerItem(container, index);
    if (item == nil or item.Id == 0) then
        return nil;
    end

    local res = AshitaCore:GetResourceManager():GetItemById(item.Id);
    if (res ~= nil and res.Name[1] ~= '.') then
        return res.Name[1];
    end

    return nil;
end

-- Equip animator matching pet frame (skips if TH overlay pending).
function M.ensure_animator(not_th_pending)
    if (not pupLib) then
        return;
    end

    if (not not_th_pending) then
        lastAnimatorEquipped = nil;
        return;
    end

    if (not pupLib.get_attachments_names or not pupLib.get_animator_for_frame or not pupLib.equip_animator) then
        return;
    end

    local attachments = pupLib.get_attachments_names();
    if (not attachments or not attachments[2] or attachments[2] == '') then
        return;
    end

    local desiredAnimator = pupLib.get_animator_for_frame(attachments[2]);
    if (not desiredAnimator or desiredAnimator == '') then
        return;
    end

    local equippedAnimator = get_equipped_item_name(RANGE_SLOT);
    if (equippedAnimator == desiredAnimator) then
        lastAnimatorEquipped = desiredAnimator;
        return;
    end

    if (pupLib.equip_animator(desiredAnimator)) then
        lastAnimatorEquipped = desiredAnimator;
    end
end

return M;

