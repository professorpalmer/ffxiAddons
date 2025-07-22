--[[
* Mass Checker - Simple ITG scanner for nearby mobs
* Checks all mobs within range for Impossible to Gauge
--]]

_addon.name = 'MassChecker'
_addon.author = 'Palmer'
_addon.version = '2.0.0'
_addon.commands = {'masschecker', 'mcheck'}

require('strings')
coroutine = require('coroutine')
packets = require('packets')
local bit = require('bit')
local dats = require('datmap')

---------------------------------------------------------------------------------------------------
-- Configuration
---------------------------------------------------------------------------------------------------
local settings = {
    check_range = 50,        -- Range in yalms to check mobs
    check_delay = 1.0,       -- Delay between checks in seconds
    zone_delay = 0.8         -- Delay between zone checks (faster for zone scans)
}

---------------------------------------------------------------------------------------------------
-- Auto-check state
---------------------------------------------------------------------------------------------------
local auto_check_state = {
    active = false,
    candidates = {},
    current_index = 1,
    confirmed_itg = {}
}

---------------------------------------------------------------------------------------------------
-- Helper Functions
---------------------------------------------------------------------------------------------------

-- Get distance between player and mob
local function get_distance(mob)
    local player_mob = windower.ffxi.get_mob_by_target('me')
    if not player_mob or not mob then return 999 end
    
    if not mob.x or not mob.y or not mob.z or not player_mob.x or not player_mob.y or not player_mob.z then
        return 999
    end
    
    local dx = mob.x - player_mob.x
    local dy = mob.y - player_mob.y
    local dz = mob.z - player_mob.z
    
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- Send proper check packet using packets library
local function check_mob_by_index(target_index)
    if target_index and target_index > 0 then
        local target_mob = windower.ffxi.get_mob_by_index(target_index)
        if target_mob and target_mob.id then
            -- Create proper check packet (0x0DD)
            local packet = packets.new('outgoing', 0x0DD, {
                ['Target'] = target_mob.id,
                ['Target Index'] = target_index,
                ['Check Type'] = 0  -- 0 = Normal /check
            })
            
            packets.inject(packet)
            return true
        end
    end
    return false
end

-- Find all mobs within check range
local function find_nearby_mobs()
    local candidates = {}
    local mob_array = windower.ffxi.get_mob_array()
    local player = windower.ffxi.get_player()
    
    if not player then return candidates end
    
    for index, mob in pairs(mob_array) do
        if mob and mob.spawn_type == 16 and mob.id and mob.id ~= 0 and mob.id ~= player.id then
            if mob.name and mob.name ~= '' then
                local distance = get_distance(mob)
                if distance <= settings.check_range then
                    table.insert(candidates, {
                        index = index,
                        name = mob.name,
                        distance = distance,
                        mob = mob
                    })
                end
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(candidates, function(a, b) return a.distance < b.distance end)
    
    return candidates
end

-- Process next candidate in auto-check queue
local function process_next_check()
    if not auto_check_state.active or auto_check_state.current_index > #auto_check_state.candidates then
        -- Finished checking all candidates
        auto_check_state.active = false
        local confirmed_count = #auto_check_state.confirmed_itg
        
        windower.add_to_chat(121, string.format('[masschecker] Check complete! Found %d ITG mob%s:', 
            confirmed_count, confirmed_count ~= 1 and 's' or ''))
            
        if confirmed_count > 0 then
            for _, mob_info in pairs(auto_check_state.confirmed_itg) do
                windower.add_to_chat(158, string.format('  ★ %s - IMPOSSIBLE TO GAUGE! (%.1f yalms)', 
                    mob_info.name, mob_info.distance))
            end
        else
            windower.add_to_chat(121, '[masschecker] No ITG mobs found in range.')
        end
        return
    end
    
    local candidate = auto_check_state.candidates[auto_check_state.current_index]
    
    windower.add_to_chat(121, string.format('[masschecker] Checking %s (%.1f yalms) [%d/%d]...', 
        candidate.name, candidate.distance, auto_check_state.current_index, #auto_check_state.candidates))
    
    if check_mob_by_index(candidate.index) then
        auto_check_state.current_index = auto_check_state.current_index + 1
        -- Reasonable delay for check packet response
        coroutine.schedule(process_next_check, 1.2)
    else
        auto_check_state.current_index = auto_check_state.current_index + 1
        process_next_check()
    end
end

-- Start auto-checking nearby mobs
local function start_nearby_check()
    windower.add_to_chat(121, '[masschecker] Starting nearby check...')
    
    if auto_check_state.active then
        windower.add_to_chat(167, '[masschecker] Check already in progress. Use //mcheck stop to cancel.')
        return false
    end
    
    local candidates = find_nearby_mobs()
    
    if #candidates == 0 then
        windower.add_to_chat(167, string.format('[masschecker] No mobs found within %d yalms.', settings.check_range or 50))
        return false
    end
    
    auto_check_state.active = true
    auto_check_state.candidates = candidates
    auto_check_state.current_index = 1
    auto_check_state.confirmed_itg = {}
    
    windower.add_to_chat(121, string.format('[masschecker] Starting ITG check of %d mob%s within %d yalms...', 
        #candidates, #candidates ~= 1 and 's' or '', settings.check_range))
    
    process_next_check()
    return true
end

---------------------------------------------------------------------------------------------------
-- Packet monitoring for ITG detection (borrowed from checker.lua)
---------------------------------------------------------------------------------------------------



windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
    if injected then return end
    
    -- Message Basic Packet (Check results) - exact copy from checker.lua
    if id == 0x29 then
        local data = original
        
        -- Extract fields using string.byte and bit operations (converting 0-based to 1-based)
        local p = data:byte(0x0C + 1) + (data:byte(0x0D + 1) * 256) + (data:byte(0x0E + 1) * 65536) + (data:byte(0x0F + 1) * 16777216) -- Monster Level
        local v = data:byte(0x10 + 1) + (data:byte(0x11 + 1) * 256) + (data:byte(0x12 + 1) * 65536) + (data:byte(0x13 + 1) * 16777216) -- Check Type  
        local m = data:byte(0x18 + 1) + (data:byte(0x19 + 1) * 256) -- Defense and Evasion
        local target = data:byte(0x16 + 1) + (data:byte(0x17 + 1) * 256) -- Target Index

        -- Convert signed integer if needed
        if p > 2147483647 then p = p - 4294967296 end
        
        -- Check results are processed silently for cleaner output
        
        -- Check for impossible to gauge (exact logic from checker.lua)
        if m == 0xF9 then
            local entity = windower.ffxi.get_mob_by_index(target)
            if entity then
                local entity_name = entity.name or 'Unknown'
                local distance = get_distance(entity)
                local lvl = '???'
                if p > 0 then
                    lvl = tostring(p)
                end
                
                -- If we're auto-checking, add to confirmed list
                if auto_check_state.active then
                    table.insert(auto_check_state.confirmed_itg, {
                        name = entity_name,
                        distance = distance,
                        index = target
                    })
                end
                
                windower.add_to_chat(158, string.format('[masschecker] ★ IMPOSSIBLE TO GAUGE: %s (Lv. %s) (%.1f yalms)', 
                    entity_name, lvl, distance))
            end
        end
        
        -- Don't block the message - let checker.lua handle it too
        return false
    end
end)

---------------------------------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------------------------------
windower.register_event('addon command', function(command, ...)
    command = command and command:lower() or ''
    local args = {...}
    
    if command == 'help' then
        windower.add_to_chat(121, 'Mass Checker Commands:')
        windower.add_to_chat(121, string.format('  //mcheck - Check all mobs within %d yalms for ITG', settings.check_range))
        windower.add_to_chat(121, '  //mcheck range <number> - Set check range (1-50 yalms)')
        windower.add_to_chat(121, '  //mcheck stop - Stop current checking')
        windower.add_to_chat(121, '  //mcheck list - Show nearby mobs without checking')
        windower.add_to_chat(121, '')
        windower.add_to_chat(121, 'Simple and reliable ITG detection within your immediate area!')
        
    elseif command == 'range' then
        local new_range = tonumber(args[1])
        if not new_range or new_range < 1 or new_range > 50 then
            windower.add_to_chat(167, '[masschecker] Please specify a range between 1 and 50 yalms.')
            return
        end
        settings.check_range = new_range
        windower.add_to_chat(121, string.format('[masschecker] Check range set to %d yalms.', new_range))
        
    elseif command == 'stop' then
        if auto_check_state.active then
            auto_check_state.active = false
            windower.add_to_chat(121, '[masschecker] Check stopped.')
        else
            windower.add_to_chat(167, '[masschecker] No check in progress.')
        end
        
    elseif command == 'list' then
        local candidates = find_nearby_mobs()
        if #candidates > 0 then
            windower.add_to_chat(121, string.format('[masschecker] Found %d mob%s within %d yalms:', 
                #candidates, #candidates ~= 1 and 's' or '', settings.check_range))
            for i, mob in pairs(candidates) do
                windower.add_to_chat(121, string.format('  %d. %s (%.1f yalms)', i, mob.name, mob.distance))
            end
        else
            windower.add_to_chat(121, string.format('[masschecker] No mobs found within %d yalms.', settings.check_range))
        end
        
    elseif command == '' then
        -- Default command - start checking
        start_nearby_check()
    else
        windower.add_to_chat(167, string.format('[masschecker] Unknown command: "%s". Use //mcheck help for commands.', tostring(command)))
    end
end)

---------------------------------------------------------------------------------------------------
-- Load event
---------------------------------------------------------------------------------------------------
windower.register_event('load', function()
    windower.add_to_chat(121, 'Mass Checker loaded! Use //mcheck to scan for ITG mobs nearby.')
end)
