addon.name      = 'SellNPC';
addon.author    = 'Palmer (Zodiarchy @ Asura)';
addon.version   = '2.0.1';
addon.desc      = 'Queue items to auto-sell when opening an NPC shop.';

require('common');

local chat      = require('chat');
local profiles  = require('profiles');

local ITEMFLAG_NO_NPC_SALE = 0x8000;
local sales_queue = T{};
local shop_open = false;

local function log_message(msg)
    print(chat.header(addon.name):append(chat.message(msg)));
end

local function log_error(msg)
    print(chat.header(addon.name):append(chat.error(msg)));
end

local function normalize_name(name)
    if (not name) then
        return nil;
    end

    local trimmed = name:trim();
    if (trimmed:len() == 0) then
        return nil;
    end

    return trimmed;
end

local function lookup_item(name)
    local cleaned = normalize_name(name);
    if (not cleaned) then
        return nil, 'Item name missing.';
    end

    -- Try to resolve the item by name (English) and fall back to lowercase if needed.
    local resmgr = AshitaCore:GetResourceManager();
    local item = resmgr:GetItemByName(cleaned, 0) or resmgr:GetItemByName(cleaned:lower(), 0);
    if (not item) then
        return nil, ('"%s" not a valid item name.'):format(cleaned);
    end

    local flags = item.Flags or 0;
    if (bit.band(flags, ITEMFLAG_NO_NPC_SALE) ~= 0) then
        return nil, ('"%s" cannot be sold to NPCs.'):format((item.Name and item.Name[1]) or cleaned);
    end

    return item;
end

local function queue_item(name, silent)
    local item, err = lookup_item(name);
    if (not item) then
        log_error(err);
        return;
    end

    sales_queue[item.Id] = true;
    if (silent) then
        return;
    end

    local display_name = (item.Name and item.Name[1]) or name;
    log_message(('"%s" added to sales queue.'):format(display_name));
end

local function send_sell_packets(slot, count, item_id)
    local sell_packet = {
        0x84, 0x06, 0x00, 0x00,
        count, 0x00, 0x00, 0x00,
        bit.band(item_id, 0xFF),
        bit.band(bit.rshift(item_id, 8), 0xFF),
        slot, 0x00
    };

    -- Confirm sell packet.
    local confirm_packet = { 0x85, 0x04, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00 };

    AshitaCore:GetPacketManager():AddOutgoingPacket(0x84, sell_packet);
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x85, confirm_packet);
end

local function sell_all_items()
    if (next(sales_queue) == nil) then
        return;
    end

    local inv = AshitaCore:GetMemoryManager():GetInventory();
    local max_slots = inv:GetContainerCountMax(0);
    local sold = 0;

    for slot = 1, max_slots do
        local item = inv:GetContainerItem(0, slot);
        if (item ~= nil and item.Id ~= 0 and sales_queue[item.Id] and (item.Flags or 0) == 0) then
            send_sell_packets(slot, item.Count, item.Id);
            sold = sold + item.Count;
        end
    end

    sales_queue = T{};

    if (sold > 0) then
        log_message(('Selling %d items.'):format(sold));
    end
end

local function queue_and_sell_now(name)
    queue_item(name, true);

    if (shop_open) then
        sell_all_items();
    else
        log_message('Queued; open an NPC shop to sell.');
    end
end

local function handle_command(e)
    local args = e.command:args();
    if (#args == 0) then
        return;
    end

    local cmd = args[1]:lower();
    if (cmd ~= '/sellnpc') then
        return;
    end

    e.blocked = true;

    if (#args == 1) then
        log_message('Usage: /sellnpc <item name>|<profile name>');
        return;
    end

    local target = args[2]:lower();

    -- /sellnpc all <item name>  (immediate sell if a shop is open)
    if (target == 'all' and #args >= 3) then
        queue_and_sell_now(table.concat(args, ' ', 3));
        return;
    end

    if (profiles[target]) then
        for _, name in ipairs(profiles[target]) do
            queue_item(name, true);
        end
        log_message(('Loaded profile "%s".'):format(target));
        return;
    end

    queue_item(table.concat(args, ' ', 2));
end

ashita.events.register('packet_in', 'sellnpc_packet_in', function (e)
    if (e.id == 0x003C) then
        shop_open = true;
        sell_all_items();
    end
end);

ashita.events.register('command', 'sellnpc_command', handle_command);

