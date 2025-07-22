--[[
* Checker - Enhanced target checking for Windower
* Originally by atom0s & Lolwutt for Ashita
* Converted to Windower by Palmer
*
* Displays enhanced information about target checks including level,
* difficulty rating, and defense/evasion conditions.
--]]

_addon.name = 'Checker'
_addon.author = 'atom0s & Lolwutt (Windower port by Palmer)'
_addon.version = '3.0.0'
_addon.commands = {'checker'}

require('strings')
packets = require('packets')

---------------------------------------------------------------------------------------------------
-- Check Condition Table
---------------------------------------------------------------------------------------------------
local conditions = {
    { 0xAA, '(High Evasion, High Defense)'},
    { 0xAB, '(High Evasion)' },
    { 0xAC, '(High Evasion, Low Defense)' },
    { 0xAD, '(High Defense)' },
    { 0xAE, '' },
    { 0xAF, '(Low Defense)' },
    { 0xB0, '(Low Evasion, High Defense)' },
    { 0xB1, '(Low Evasion)' },
    { 0xB2, '(Low Evasion, Low Defense)' },
}

---------------------------------------------------------------------------------------------------
-- Check Type Table
---------------------------------------------------------------------------------------------------
local checktype = {
    { 0x40, 'too weak to be worthwhile' },
    { 0x41, 'like incredibly easy prey' },
    { 0x42, 'like easy prey' },
    { 0x43, 'like a decent challenge' },
    { 0x44, 'like an even match' },
    { 0x45, 'tough' },
    { 0x46, 'very tough' },
    { 0x47, 'incredibly tough' }
}

---------------------------------------------------------------------------------------------------
-- Widescan Storage Data
---------------------------------------------------------------------------------------------------
local widescan = {}

---------------------------------------------------------------------------------------------------
-- Event: incoming chunk
-- desc: Called when our addon receives an incoming packet.
---------------------------------------------------------------------------------------------------
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
    if injected then return end
    
    -- Zone Change Packet
    if id == 0x0A then
        -- Reset the widescan data
        widescan = {}
        return
    end

    -- Message Basic Packet (Check results)
    if id == 0x29 then
        -- Parse using proper Windower methods with 1-based indexing
        local data = original
        
        -- Extract fields using string.byte and bit operations (converting 0-based to 1-based)
        local p = data:byte(0x0C + 1) + (data:byte(0x0D + 1) * 256) + (data:byte(0x0E + 1) * 65536) + (data:byte(0x0F + 1) * 16777216) -- Monster Level
        local v = data:byte(0x10 + 1) + (data:byte(0x11 + 1) * 256) + (data:byte(0x12 + 1) * 65536) + (data:byte(0x13 + 1) * 16777216) -- Check Type  
        local m = data:byte(0x18 + 1) + (data:byte(0x19 + 1) * 256) -- Defense and Evasion
        local target = data:byte(0x16 + 1) + (data:byte(0x17 + 1) * 256) -- Target Index

        -- Convert signed integer if needed
        if p > 2147483647 then p = p - 4294967296 end
        
        local ctype = nil
        local ccond = nil

        -- Obtain the check type and condition string
        for k, vv in pairs(checktype) do
            if vv[1] == v then
                ctype = vv[2]
                break
            end
        end
        
        for k, vv in pairs(conditions) do
            if vv[1] == m then
                ccond = vv[2]
                break
            end
        end

        -- Check for impossible to gauge
        if m == 0xF9 then
            ctype = ''
            ccond = ''
        end

        -- Ensure a check type and condition was found
        if ctype == nil or ccond == nil then
            return
        end

        -- Obtain the target entity
        local entity = windower.ffxi.get_mob_by_index(target)
        if entity == nil then
            return
        end

        -- Check the level for overrides from widescan
        if p <= 0 then
            local l = widescan[target]
            if l ~= nil then
                p = l
            end
        end

        -- Print out based on NM or not
        if m == 0xF9 then
            local lvl = '???'
            if p > 0 then
                lvl = tostring(p)
            end
            windower.add_to_chat(207, string.format('[checker] %s >> (Lv. %s) Impossible to gauge!', entity.name, lvl))
        else
            windower.add_to_chat(207, string.format('[checker] %s >> (Lv. %d) Seems %s. %s', entity.name, p, ctype, ccond))
        end

        return true  -- Block the original message from appearing
    end

    -- Widescan Result Packet
    if id == 0xF4 then
        local data = original
        local i = data:byte(0x04 + 1) + (data:byte(0x05 + 1) * 256) -- Entity Index
        local l = data:byte(0x06 + 1) -- Entity Level (signed byte)
        
        -- Convert signed byte if needed
        if l > 127 then l = l - 256 end
        
        -- Store the index and level information
        widescan[i] = l
        return
    end
end)

---------------------------------------------------------------------------------------------------
-- Zone change event handler
---------------------------------------------------------------------------------------------------
windower.register_event('zone change', function()
    widescan = {}
end)

---------------------------------------------------------------------------------------------------
-- Addon command handler
---------------------------------------------------------------------------------------------------
windower.register_event('addon command', function(command, ...)
    command = command and command:lower() or 'help'
    
    if command == 'help' then
        windower.add_to_chat(121, 'Checker Commands:')
        windower.add_to_chat(121, '  //checker help - Show this help')
        windower.add_to_chat(121, '  //checker reload - Reload addon')
        windower.add_to_chat(121, '')
        windower.add_to_chat(121, 'This addon automatically enhances check messages with detailed information.')
        windower.add_to_chat(121, 'Simply check a target and see enhanced difficulty and defense/evasion info.')
    elseif command == 'reload' then
        windower.send_command('lua reload checker')
    end
end)

---------------------------------------------------------------------------------------------------
-- Load event
---------------------------------------------------------------------------------------------------
windower.register_event('load', function()
    windower.add_to_chat(121, 'Checker loaded. Check targets to see enhanced information.')
end) 