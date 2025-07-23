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
    confirmed_itg = {},
    
    -- New scanning state for zone scans
    scanning_phase = false,  -- true = scanning for existence, false = checking for ITG
    scan_candidates = {},    -- All DAT mobs to scan
    scan_index = 1,
    confirmed_existing = {},  -- Mobs confirmed to exist
    waiting_for_scan = false,
    current_scan_target = nil,
    
    -- Track pending check packets for timeout detection
    pending_checks = {},  -- Table of {index, name, timestamp}
    check_timeout = 2.0,  -- Seconds to wait for response
    
    -- Feedback tracking
    checks_sent = 0,
    checks_responded = 0,
    timeouts = 0
}

---------------------------------------------------------------------------------------------------
-- Helper Functions
---------------------------------------------------------------------------------------------------

-- Check if checker.lua addon is loaded for smarter feedback
local function is_checker_loaded()
    -- Simple check - just assume checker.lua might be loaded
    -- We can't easily detect other addons reliably
    return false
end

-- Clean up timed out check packets
local function cleanup_timeouts()
    if not auto_check_state.active then return end
    
    local current_time = os.clock()
    local timeout_count = 0
    
    for index, check_data in pairs(auto_check_state.pending_checks) do
        if current_time - check_data.timestamp > auto_check_state.check_timeout then
            -- This check timed out (mob doesn't exist)
            timeout_count = timeout_count + 1
            auto_check_state.pending_checks[index] = nil
        end
    end
    
    if timeout_count > 0 then
        auto_check_state.timeouts = auto_check_state.timeouts + timeout_count
        if auto_check_state.scan_type == 'zone' and timeout_count >= 10 then
            windower.add_to_chat(8, string.format('[masschecker] %d mobs timed out (don\'t exist)', timeout_count))
        end
    end
end

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



-- Send scan packet to find existing mobs (like scanzone.lua)
local function scan_mob_by_index(target_index)
    if target_index and target_index > 0 then
        -- Send 0x16 scan packet (exact format from scanzone.lua)
        local packet_data = string.char(0x16, 0x08, 0x00, 0x00, 
                                       (target_index % 256), 
                                       math.floor(target_index / 256), 
                                       0x00, 0x00)
        windower.packets.inject_outgoing(0x16, packet_data)
        return true
    end
    return false
end

-- Send proper check packet using packets library (0x0DD)
local function check_mob_by_index(target_index, candidate_info)
    if target_index and target_index > 0 then
        -- Track this check for timeout detection and stats
        if auto_check_state.active then
            auto_check_state.pending_checks = auto_check_state.pending_checks or {}
            auto_check_state.pending_checks[target_index] = {
                name = candidate_info and candidate_info.name or 'Unknown',
                timestamp = os.clock()
            }
            auto_check_state.checks_sent = (auto_check_state.checks_sent or 0) + 1
        end
        
        -- First try with loaded mob data if available
        local target_mob = windower.ffxi.get_mob_by_index(target_index)
        if target_mob and target_mob.id then
            local packet = packets.new('outgoing', 0x0DD, {
                ['Target'] = target_mob.id,
                ['Target Index'] = target_index,
                ['Check Type'] = 0  -- 0 = Normal /check
            })
            packets.inject(packet)
            return true
        else
            -- For zone scans, try checking by index only (DAT mobs)
            local packet = packets.new('outgoing', 0x0DD, {
                ['Target'] = 0,  -- Unknown ID, let server figure it out
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
            if mob.name and mob.name ~= '' and not should_exclude_mob(mob) then
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

-- Read DAT files to find all mobs in current zone (deduplicated by index)
local function find_all_zone_mobs()
    local results_by_index = {}  -- Use table keyed by index to avoid duplicates
    local zone_id = windower.ffxi.get_info().zone
    
    if zone_id <= 0 then return {} end
    
    local dat = dats[zone_id]
    if not dat or type(dat) ~= 'table' then return {} end
    
    for datNum = 1, #dat do
        if dat[datNum] then
            local file = io.open(string.format('C:\\Program Files (x86)\\PlayOnline\\SquareEnix\\FINAL FANTASY XI\\%s', dat[datNum]), 'rb')
            if file then
                while true do
                    local data = file:read(32)
                    if not data then break end
                    
                    -- Extract name (28 bytes)
                    local name = ''
                    for x = 1, 28 do
                        local char = string.char(data:unpack('c', x))
                        if char ~= '\0' then
                            name = name .. char
                        end
                    end
                    
                    -- Extract ID (4 bytes at position 29)
                    local id = data:unpack('I', 29)
                    local index = bit.band(id, 0xFFF)
                    
                    if name ~= '' and index > 0 then
                        -- Store by index to automatically deduplicate
                        results_by_index[index] = {
                            name = name,
                            id = id,
                            index = index
                        }
                    end
                end
                file:close()
            end
        end
    end
    
    -- Convert back to array
    local results = {}
    for _, mob_data in pairs(results_by_index) do
        table.insert(results, mob_data)
    end
    
    return results
end

-- Check if mob should be excluded (only obvious non-monsters)
local function should_exclude_mob(mob)
    if not mob or not mob.name then return true end
    
    local name = mob.name:lower()
    
    -- Only exclude very specific non-monster patterns
    -- Pure ??? patterns only (like "???" exactly)
    if name == "???" or name == "????" or name == "?????" then return true end
    if name == "qmark" then return true end
    
    return false
end







-- Process next candidate in scan phase (finding existing mobs)
local function process_next_scan()
    if not auto_check_state.active or not auto_check_state.scanning_phase then
        return
    end
    
    if auto_check_state.scan_index > #auto_check_state.scan_candidates then
        -- Finished scanning phase, start checking confirmed existing mobs
        windower.add_to_chat(121, string.format('[masschecker] Scan complete! Found %d existing mob%s. Starting ITG checks...', 
            #auto_check_state.confirmed_existing, #auto_check_state.confirmed_existing ~= 1 and 's' or ''))
        
        auto_check_state.scanning_phase = false
        auto_check_state.candidates = auto_check_state.confirmed_existing
        auto_check_state.current_index = 1
        
        if #auto_check_state.candidates > 0 then
            process_next_check()
        else
            auto_check_state.active = false
            windower.add_to_chat(121, '[masschecker] No existing mobs found to check.')
        end
        return
    end
    
    local candidate = auto_check_state.scan_candidates[auto_check_state.scan_index]
    auto_check_state.current_scan_target = candidate.index
    auto_check_state.waiting_for_scan = true
    
    -- Show progress every 100 scans
    if auto_check_state.scan_index % 100 == 1 or auto_check_state.scan_index == #auto_check_state.scan_candidates then
        windower.add_to_chat(121, string.format('[masschecker] Scanning progress: [%d/%d] (Found existing: %d)', 
            auto_check_state.scan_index, #auto_check_state.scan_candidates, #auto_check_state.confirmed_existing))
    end
    
    if scan_mob_by_index(candidate.index) then
        auto_check_state.scan_index = auto_check_state.scan_index + 1
        -- Very fast scanning with timeout
        coroutine.schedule(function()
            if auto_check_state.waiting_for_scan and auto_check_state.current_scan_target == candidate.index then
                auto_check_state.waiting_for_scan = false
                process_next_scan()
            end
        end, 0.05)
    else
        auto_check_state.scan_index = auto_check_state.scan_index + 1
        process_next_scan()
    end
end

-- Process next candidate in auto-check queue
local function process_next_check()
    if not auto_check_state.active or auto_check_state.current_index > #auto_check_state.candidates then
        -- Finished checking all candidates
        auto_check_state.active = false
        local confirmed_count = #auto_check_state.confirmed_itg
        local scan_type = auto_check_state.scan_type or 'nearby'
        
        windower.add_to_chat(121, string.format('[masschecker] %s scan complete! Found %d ITG mob%s:', 
            scan_type:gsub("^%l", string.upper), confirmed_count, confirmed_count ~= 1 and 's' or ''))
            
        if confirmed_count > 0 then
            for _, mob_info in pairs(auto_check_state.confirmed_itg) do
                windower.add_to_chat(158, string.format('  ★ %s - IMPOSSIBLE TO GAUGE! (%.1f yalms)', 
                    mob_info.name, mob_info.distance))
            end
        else
            windower.add_to_chat(121, string.format('[masschecker] No ITG mobs found in %s scan.', scan_type))
        end
        return
    end
    
    local candidate = auto_check_state.candidates[auto_check_state.current_index]
    
    -- Cleanup timeouts periodically
    if auto_check_state.current_index % 25 == 1 then
        cleanup_timeouts()
    end
    
    -- Show progress every 50 checks for zone scans, or always for nearby
    local show_progress = auto_check_state.scan_type ~= 'zone' or 
                         auto_check_state.current_index % 50 == 1 or 
                         auto_check_state.current_index == #auto_check_state.candidates
    
    if show_progress then
        if auto_check_state.scan_type == 'zone' then
            windower.add_to_chat(121, string.format('[masschecker] Progress: [%d/%d] (ITG: %d, Responded: %d, Timeouts: %d)', 
                auto_check_state.current_index, #auto_check_state.candidates, #auto_check_state.confirmed_itg,
                auto_check_state.checks_responded, auto_check_state.timeouts))
        else
            windower.add_to_chat(121, string.format('[masschecker] Checking %s [%d/%d]...', 
                candidate.name, auto_check_state.current_index, #auto_check_state.candidates))
        end
    end
    
    if check_mob_by_index(candidate.index, candidate) then
        auto_check_state.current_index = auto_check_state.current_index + 1
        -- Use different delays based on scan type
        local delay = auto_check_state.scan_type == 'zone' and settings.zone_delay or 1.2
        coroutine.schedule(process_next_check, delay)
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
    auto_check_state.scan_type = 'nearby'
    
    windower.add_to_chat(121, string.format('[masschecker] Starting ITG check of %d mob%s within %d yalms...', 
        #candidates, #candidates ~= 1 and 's' or '', settings.check_range))
    
    process_next_check()
    return true
end

-- Start zone-wide checking - blast 0x0DD check packets to all DAT indices
local function start_zone_check()
    windower.add_to_chat(121, '[masschecker] Starting zone-wide ITG check...')
    
    if auto_check_state.active then
        windower.add_to_chat(167, '[masschecker] Check already in progress. Use //mcheck stop to cancel.')
        return false
    end
    
    -- Get all possible mobs from DAT files
    local dat_mobs = find_all_zone_mobs()
    
    if #dat_mobs == 0 then
        windower.add_to_chat(167, '[masschecker] No mobs found in zone DAT files.')
        return false
    end
    
    -- Filter out obvious non-monsters and convert to candidates
    local candidates = {}
    for _, dat_mob in pairs(dat_mobs) do
        if not should_exclude_mob({name = dat_mob.name}) then
            table.insert(candidates, {
                index = dat_mob.index,
                name = dat_mob.name,
                distance = 999  -- Unknown distance for DAT mobs
            })
        end
    end
    
    if #candidates == 0 then
        windower.add_to_chat(167, '[masschecker] No valid mobs found after filtering.')
        return false
    end
    
    auto_check_state.active = true
    auto_check_state.candidates = candidates
    auto_check_state.current_index = 1
    auto_check_state.confirmed_itg = {}
    auto_check_state.scan_type = 'zone'
    
    -- Reset tracking counters
    auto_check_state.pending_checks = {}
    auto_check_state.checks_sent = 0
    auto_check_state.checks_responded = 0
    auto_check_state.timeouts = 0
    
    windower.add_to_chat(121, string.format('[masschecker] Checking %d potential mob%s directly for ITG...', 
        #candidates, #candidates ~= 1 and 's' or ''))
    
    process_next_check()
    return true
end

---------------------------------------------------------------------------------------------------
-- Packet monitoring for ITG detection (borrowed from checker.lua)
---------------------------------------------------------------------------------------------------



windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
    if injected then return end
    
    -- Entity Update Packet (Scan results) - like scanzone.lua  
    if id == 0x0E then
        if auto_check_state.scanning_phase and auto_check_state.waiting_for_scan then
            local target_index = original:unpack('h', 0x08 + 1)
            
            if target_index == auto_check_state.current_scan_target then
                auto_check_state.waiting_for_scan = false
                
                -- Extract entity info
                local updatemask = original:unpack('b', 0x0A + 1)
                if updatemask then
                    local id = original:unpack('I', 0x04 + 1)
                    if id and id > 0 then
                        -- Mob exists! Add to confirmed list
                        local name = "Unknown"
                        
                        -- Extract name if available (like scanzone.lua)
                        if bit.band(updatemask, 0x08) == 0x08 then
                            name = ''
                            for i = 1, (#original - 0x34) do
                                local t = original:unpack('c', 0x34 + i)
                                name = name .. string.char(t)
                            end
                            name = name:gsub('\0.*', '') -- Remove nulls
                        end
                        
                        table.insert(auto_check_state.confirmed_existing, {
                            index = target_index,
                            name = name,
                            id = id,
                            distance = 999  -- Unknown distance for scanned mobs
                        })
                    end
                end
                
                -- Continue scanning
                coroutine.schedule(process_next_scan, 0.02)
            end
        end
        return false
    end

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
        
        -- Track response if we're auto-checking
        if auto_check_state.active and auto_check_state.pending_checks[target] then
            auto_check_state.checks_responded = auto_check_state.checks_responded + 1
            auto_check_state.pending_checks[target] = nil
        end
        
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
        else
            -- Show non-ITG check results only for zone scans in standalone mode
            if auto_check_state.active and auto_check_state.scan_type == 'zone' then
                local entity = windower.ffxi.get_mob_by_index(target)
                if entity then
                    local entity_name = entity.name or 'Unknown'
                    local lvl = p > 0 and tostring(p) or '???'
                    windower.add_to_chat(121, string.format('[masschecker] Check: %s (Lv. %s) - Normal', 
                        entity_name, lvl))
                end
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
        windower.add_to_chat(121, '  //mcheck zone - Check ALL mobs in current zone for ITG')
        windower.add_to_chat(121, '  //mcheck range <number> - Set check range (1-50 yalms)')
        windower.add_to_chat(121, '  //mcheck stop - Stop current checking')
        windower.add_to_chat(121, '  //mcheck list - Show nearby mobs without checking')
        windower.add_to_chat(121, '  //mcheck list zone - Show all zone mobs without checking')
        windower.add_to_chat(121, '  //mcheck debug - Debug zone vs widescan comparison')
        windower.add_to_chat(121, '')
        windower.add_to_chat(121, 'Simple and reliable ITG detection for nearby or zone-wide scanning!')
        windower.add_to_chat(167, 'TIP: Load checker.lua for enhanced feedback during zone scans.')
        
    elseif command == 'range' then
        local new_range = tonumber(args[1])
        if not new_range or new_range < 1 or new_range > 50 then
            windower.add_to_chat(167, '[masschecker] Please specify a range between 1 and 50 yalms.')
            return
        end
        settings.check_range = new_range
        windower.add_to_chat(121, string.format('[masschecker] Check range set to %d yalms.', new_range))
        
    elseif command == 'zone' then
        start_zone_check()
        
    elseif command == 'debug' then
        debug_zone_vs_widescan()
        
    elseif command == 'stop' then
        if auto_check_state.active then
            auto_check_state.active = false
            windower.add_to_chat(121, '[masschecker] Check stopped.')
        else
            windower.add_to_chat(167, '[masschecker] No check in progress.')
        end
        
    elseif command == 'list' then
        local scan_type = args[1] == 'zone' and 'zone' or 'nearby'
        
        if scan_type == 'zone' then
            local dat_mobs = find_all_zone_mobs()
            if #dat_mobs > 0 then
                windower.add_to_chat(121, string.format('[masschecker] Found %d potential mob%s in zone DAT files:', 
                    #dat_mobs, #dat_mobs ~= 1 and 's' or ''))
                for i, mob in pairs(dat_mobs) do
                    windower.add_to_chat(121, string.format('  %d. %s (Index: %d)', i, mob.name, mob.index))
                end
            else
                windower.add_to_chat(121, '[masschecker] No mobs found in zone DAT files.')
            end
        else
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
-- Debug function to compare zone scanning vs mob_array vs widescan
local function debug_zone_vs_widescan()
    windower.add_to_chat(121, '[masschecker] === DEBUG COMPARISON ===')
    
    -- Method 1: Direct mob_array scan (what nearby uses)
    local mob_array = windower.ffxi.get_mob_array()
    local player = windower.ffxi.get_player()
    local direct_mobs = {}
    
    for index, mob in pairs(mob_array) do
        if mob and mob.spawn_type == 16 and mob.id and mob.id ~= 0 and mob.id ~= player.id then
            if mob.name and mob.name ~= '' then
                table.insert(direct_mobs, {
                    index = index,
                    name = mob.name,
                    id = mob.id,
                    distance = get_distance(mob)
                })
            end
        end
    end
    
    -- Method 2: Zone DAT mobs (what new zone scan uses)
    local dat_mobs = find_all_zone_mobs()
    
    windower.add_to_chat(121, string.format('[DEBUG] Direct mob_array scan found: %d mobs', #direct_mobs))
    for i, mob in pairs(direct_mobs) do
        windower.add_to_chat(121, string.format('  [%d] %s (Index: %d, ID: %d, %.1f yalms)', 
            i, mob.name, mob.index, mob.id, mob.distance))
    end
    
    windower.add_to_chat(121, string.format('[DEBUG] Zone DAT files contain: %d potential mobs', #dat_mobs))
    for i, mob in pairs(dat_mobs) do
        windower.add_to_chat(121, string.format('  [%d] %s (Index: %d)', 
            i, mob.name, mob.index))
    end
    
    windower.add_to_chat(121, '[masschecker] === END DEBUG ===')
end

windower.register_event('load', function()
    windower.add_to_chat(121, 'Mass Checker loaded! Use //mcheck to scan for ITG mobs nearby.')
    windower.add_to_chat(167, 'TIP: Load checker.lua for enhanced feedback during zone scans.')
end)

