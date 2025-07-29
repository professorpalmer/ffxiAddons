--[[

Copyright © 2019, Wiener
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of ShamiOrbs nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Sammeh BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

]]

addon.name = 'ShamiOrbs'
addon.author = 'Modified from Wiener/Jyouya\'s "PhantomGem" by Palmer'
addon.version = '1.0'
addon.desc = 'Buy orbs from Shami in Port Jeuno'

require('sugar');
local chat = require('chat');

-- Shami is in Port Jeuno (H-8)
npcs = {
    [246] = { name = 'Shami', menuId = 322, zone = 246 } -- Port Jeuno zone ID, menu ID discovered
}

-- Orb data - trying different option indices for Shami
-- Let's try simple sequential numbers first
orbs = {
    [0] = { name = 'Cloudy Orb', seals = 20, seal_type = 'beastmen', cost = 20, oi = 1 },            -- 20 Beastmen's Seals
    [1] = { name = 'Sky Orb', seals = 30, seal_type = 'beastmen', cost = 30, oi = 2 },               -- 30 Beastmen's Seals
    [2] = { name = 'Star Orb', seals = 40, seal_type = 'beastmen', cost = 40, oi = 3 },              -- 40 Beastmen's Seals
    [3] = { name = 'Comet Orb', seals = 50, seal_type = 'beastmen', cost = 50, oi = 4 },             -- 50 Beastmen's Seals
    [4] = { name = 'Moon Orb', seals = 60, seal_type = 'beastmen', cost = 60, oi = 5 },              -- 60 Beastmen's Seals
    [5] = { name = 'Atropos Orb', seals = 30, seal_type = 'kindred', cost = 30, oi = 6 },            -- 30 Kindred's Seals
    [6] = { name = 'Clotho Orb', seals = 30, seal_type = 'kindred', cost = 30, oi = 7 },             -- 30 Kindred's Seals
    [7] = { name = 'Lachesis Orb', seals = 30, seal_type = 'kindred', cost = 30, oi = 8 },           -- 30 Kindred's Seals
    [8] = { name = 'Themis Orb', seals = 99, seal_type = 'kindred', cost = 99, oi = 9 },             -- 99 Kindred's Seals
    [9] = { name = 'Phobos Orb', seals = 30, seal_type = 'crest', cost = 30, oi = 10 },              -- 30 Kindred's Crests
    [10] = { name = 'Deimos Orb', seals = 50, seal_type = 'crest', cost = 50, oi = 11 },             -- 50 Kindred's Crests
    [11] = { name = 'Zelos Orb', seals = 30, seal_type = 'high_crest', cost = 30, oi = 12 },         -- 30 High Kindred's Crests
    [12] = { name = 'Bia Orb', seals = 50, seal_type = 'high_crest', cost = 50, oi = 13 },           -- 50 High Kindred's Crests
    [13] = { name = 'Microcosmic Orb', seals = 10, seal_type = 'sacred_crest', cost = 10, oi = 14 }, -- 10 Sacred Kindred's Crests
    [14] = { name = 'Macrocosmic Orb', seals = 20, seal_type = 'sacred_crest', cost = 20, oi = 15 }  -- 20 Sacred Kindred's Crests
}

shortcuts = {
    -- Beastmen Seal Orbs
    ["cloudy"] = 0,
    ["sky"] = 1,
    ["star"] = 2,
    ["comet"] = 3,
    ["moon"] = 4,

    -- Kindred Seal Orbs
    ["atropos"] = 5,
    ["clotho"] = 6,
    ["lachesis"] = 7,
    ["themis"] = 8,

    -- Kindred Crest Orbs
    ["phobos"] = 9,
    ["deimos"] = 10,

    -- High Kindred Crest Orbs
    ["zelos"] = 11,
    ["bia"] = 12,

    -- Sacred Kindred Crest Orbs
    ["microcosmic"] = 13,
    ["micro"] = 13,
    ["macrocosmic"] = 14,
    ["macro"] = 14
}

local function message(text)
    print(chat.header(addon.name):append(chat.message(text)));
end

-- Function to get current seal counts from packet data
local function getSealCount(seal_type, packet_data)
    if not packet_data then return 999 end -- Fallback

    if seal_type == 'beastmen' then
        return struct.unpack('H', packet_data, 0x08 + 1) or 0
    elseif seal_type == 'kindred' then
        return struct.unpack('H', packet_data, 0x0A + 1) or 0
    elseif seal_type == 'crest' then
        return struct.unpack('H', packet_data, 0x0C + 1) or 0
    elseif seal_type == 'high_crest' then
        return struct.unpack('H', packet_data, 0x0E + 1) or 0
    elseif seal_type == 'sacred_crest' then
        return struct.unpack('L', packet_data, 0x10 + 1) or 0 -- 4-byte for larger numbers
    else
        return 999                                            -- Unknown seal type
    end
end



-- Technically not needed since the npcs have static indices
local function getIndexByName(name)
    local entMgr = AshitaCore:GetMemoryManager():GetEntity();

    for i = 1, 1023 do
        if entMgr:GetName(i) == name then
            return i;
        end
    end
end

local _orb = nil
ashita.events.register('command', 'command_cb', function(e)
    local args = e.command:args();
    if (#args == 0 or args[1] ~= '/orb') then
        return;
    end

    local zone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
    local npc = npcs[zone]

    if (npc) then
        local cmd = args[2];

        if cmd == "reset" then
            ResetDialogue(npc, true)
        elseif cmd == "list" then
            message("Available orbs:")
            for i, orb in pairs(orbs) do
                message(string.format("%d: %s (%d %s seals)", i, orb.name, orb.seals, orb.seal_type))
            end
        else
            _orb = nil
            local orbNumber = tonumber(cmd)
            if type(orbNumber) ~= 'number' then
                orbNumber = shortcuts[cmd:lower()]
            end

            if orbNumber and type(orbNumber) == 'number' and orbs[orbNumber] then
                _orb = orbs[orbNumber]
                local currentSeals = getSealCount(_orb.seal_type)

                if currentSeals >= _orb.cost then
                    message(string.format("Purchasing %s for %d %s seals...", _orb.name, _orb.seals, _orb.seal_type))
                    EngageDialogue(npc)
                else
                    message(string.format("Not enough %s seals! Need %d, have %d", _orb.seal_type, _orb.cost,
                        currentSeals))
                    _orb = nil
                end
            else
                message("Orb not found. Use '/orb list' to see available orbs.")
            end
        end
    else
        message("Not in Port Jeuno or Shami not found!")
    end
end)

function GetStatus()
    local targetIndex = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
    return AshitaCore:GetMemoryManager():GetEntity():GetStatus(targetIndex);
end

function FindNPC(npcName)
    local entMgr = AshitaCore:GetMemoryManager():GetEntity();

    local npcIdx = getIndexByName(npcName);

    if GetStatus() == 0 then
        if math.sqrt(entMgr:GetDistance(npcIdx)) < 6 then
            return entMgr:GetServerId(npcIdx), npcIdx
        else
            message('Shami too far away!');
        end
    end

    return nil, nil
end

local function buildActionPacket(packet)
    local p = struct.pack('BBHLHHLLLL',
        0x1A,
        0x0E,
        0,
        packet['Target'] or 0,
        packet['Target Index'] or 0,
        packet['Category'] or 0,
        0, 0, 0, 0
    );

    return p;
end

local function inject(id, packet)
    AshitaCore:GetPacketManager():AddOutgoingPacket(id, packet:totable());
end

function EngageDialogue(npc)
    local target, targetIndex = FindNPC(npc.name)
    if target and targetIndex then
        local packet = buildActionPacket({
            ["Target"] = target,
            ["Target Index"] = targetIndex,
            ["Category"] = 0,
            ["Param"] = 0,
            ["_unknown1"] = 0
        });
        inject(0x1A, packet)
    end
end

local function buildMenuPacket(packet)
    return struct.pack('BBHLLHHHH',
        0x5B,
        0x0A,
        0,
        packet['Target'] or 0,
        packet['Option Index'] or 0,
        packet['Target Index'] or 0,
        packet['Automated Message'] and 1 or 0,
        packet['Zone'] or 0,
        packet['Menu ID'] or 0
    );
end

ashita.events.register('packet_in', 'orb_cb', function(e)
    if e.injected then return end

    if e.id == 0x034 then
        local zone = struct.unpack('H', e.data, 0x2A + 0x01);
        local menuId = struct.unpack('H', e.data, 0x2C + 0x01);
        local npc = npcs[zone]

        if not _orb or not npc then return false end

        -- Store the actual menu ID when we first encounter it
        if npc.menuId == 0 then
            npc.menuId = menuId
            message(string.format("Detected Shami menu ID: %d", menuId))
        end

        if npc.menuId ~= menuId then return false end

        e.blocked = true;

        -- Get current seal count from packet data
        local currentSeals = getSealCount(_orb.seal_type, e.data)

        if _orb.cost <= currentSeals then
            local packet = {}
            packet["Target"] = struct.unpack('L', e.data, 0x04 + 0x01)
            packet["Option Index"] = _orb.oi
            packet["_unknown1"] = 0
            packet["Target Index"] = struct.unpack('H', e.data, 0x28 + 0x01);
            packet["Automated Message"] = false
            packet["_unknown2"] = 0
            packet["Zone"] = zone
            packet["Menu ID"] = menuId

            inject(0x05B, buildMenuPacket(packet))

            _orb = nil
            return true
        else
            message(string.format('Not enough %s seals to buy %s!', _orb.seal_type, _orb.name))
            ResetDialogue(npc, false)
            _orb = nil
            return true
        end
    end
end);

function ResetDialogue(npc, forced)
    _orb = nil
    local target, targetIndex = FindNPC(npc.name)
    if target and targetIndex then
        local resetPacket = buildMenuPacket {
            ["Target"] = target,
            ["Option Index"] = 16384,
            ["_unknown1"] = 16384,
            ["Target Index"] = targetIndex,
            ["Automated Message"] = false,
            ["_unknown2"] = 0,
            ["Zone"] = npc.zone,
            ["Menu ID"] = npc.menuId
        }
        inject(0x05B, resetPacket)
        if forced then
            message('Reset sent.')
        end
    end
end
