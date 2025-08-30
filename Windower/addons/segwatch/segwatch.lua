--Copyright © 2025, SegWatch by Palmer (Zodiarchy @ Asura)
--All rights reserved.

--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are met:

--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * Neither the name of <addon name> nor the
--      names of its contributors may be used to endorse or promote products
--      derived from this software without specific prior written permission.

--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
--DISCLAIMED. IN NO EVENT SHALL <your name> BE LIABLE FOR ANY
--DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
--ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
--(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

texts = require('texts')
config = require('config')
require('sets')
res = require('resources')
packets = require('packets')
require('pack')
require('chat')
require('statics')

_addon.name = 'SegWatch'
_addon.author = 'Palmer (Zodiarchy @ Asura)'
_addon.version = 1.0
_addon.command = 'sw'

settings = config.load('data\\settings.xml', default_settings)
config.register(settings, initialize)

box = texts.new('${current_string}', settings.text_box_settings, settings)
box.current_string = ''
box:show()

-- Packet handlers for tracking segment gains
packet_handlers = {
    [0x0B] = function(org) -- Zoning
        zoning_bool = true
        box:hide()
    end,
    [0x0A] = function(org) -- Finished zoning
        zoning_bool = nil
        box:show()
    end,

    [0x118] = function(org) -- Currency2 packet (contains newer currencies)
        -- Mog Segments are at offset 0x8C (140 decimal) as a signed int (4 bytes)
        -- +1 for Lua indexing (1-based), packet starts at byte 1
        local segment_offset = 0x8C + 1 -- 0x8C offset + 1 for Lua indexing
        
        if #org >= segment_offset + 3 then
            -- Read segments as 32-bit signed integer (little-endian)
            local new_segments = org:byte(segment_offset) + 
                                org:byte(segment_offset + 1) * 256 + 
                                org:byte(segment_offset + 2) * 65536 + 
                                org:byte(segment_offset + 3) * 16777216
            
            -- Handle signed integer (convert from unsigned to signed if needed)
            if new_segments > 2147483647 then
                new_segments = new_segments - 4294967296
            end
            
            -- Only track gains when we have a previous value and segments increased
            if segments.current > 0 then -- We already had a segment count
                local diff = new_segments - segments.current
                
                if diff > 0 then -- Segments increased
                    local t = os.clock()
                    segments.registry[t] = (segments.registry[t] or 0) + diff
                    segments.run_registry[t] = (segments.run_registry[t] or 0) + diff

                    segments.run_segments = segments.run_segments + diff
                    
                    if segments.run_start_time then
                        segments.run_duration = os.clock() - segments.run_start_time
                    end
                    
                    if settings.show_gain_messages then
                        windower.add_to_chat(123, 'SegWatch: Gained ' .. diff .. ' segments! Total: ' .. new_segments)
                    end
                end
            end
            
            -- Update current value (always)
            segments.current = new_segments
            
            -- Always update display when packet is received
            update_box()
            

        end
    end,

}





-- List of packets that we want to check on initialization
local packet_initiators = L{0x118}

-- Initialize first
initialize()

-- Define update_box function early
function update_box()
    if not windower.ffxi.get_info().logged_in or not windower.ffxi.get_player() then
        box.current_string = ''
        return
    end

    segments.rate = analyze_segments_table(segments.registry)
    segments.run_rate = analyze_run_segments_table(segments.run_registry)

    assert(cur_func)()

    if box.current_string ~= current_string then
        box.current_string = current_string
    end
end





windower.register_event('incoming chunk', function(id, org, modi, is_injected, is_blocked)
    if is_injected or is_blocked then return end
    local handler = packet_handlers[id]
    if handler then
        handler(org, modi)
    end
    

    

end)

-- Function to request currency data 
function request_currency_data()
    -- Send request for Currency2 data (contains Mog Segments)
    windower.packets.inject_outgoing(0x115, string.char(0x15, 0x01, 0x00, 0x00))
end

windower.register_event('zone change', function(new, old)
    -- Reset run statistics when changing zones
    if new ~= old then
        segments.run_start_time = os.clock()
        segments.run_segments = 0

    end

    -- Check if we're in Odyssey zones
    local zone_name = res.zones[new].english
    if string.find(zone_name, 'Odyssey') or string.find(zone_name, 'Segments') then
        segments.in_odyssey = true
        cur_func, loadstring_err = loadstring("current_string = " .. settings.strings.odyssey)
    else
        segments.in_odyssey = false
        cur_func, loadstring_err = loadstring("current_string = " .. settings.strings.default)
    end

    if not cur_func or loadstring_err then
        cur_func = loadstring("current_string = ''")
        error(loadstring_err)
    end

    -- Set the function environment
    if cur_func then
        setfenv(cur_func, _G)
    end

    -- Request currency data after zone change (delayed to avoid issues)
    coroutine.schedule(function()
        request_currency_data()
    end, 2)
    
end)

windower.register_event('addon command', function(...)
    local commands = { ... }
    local first_cmd = table.remove(commands, 1):lower()

    if approved_commands[first_cmd] and #commands >= approved_commands[first_cmd].n then
        local tab = {}
        for i, v in ipairs(commands) do
            tab[i] = tonumber(v) or v
            if i <= approved_commands[first_cmd].n and type(tab[i]) ~= approved_commands[first_cmd].t then
                print('SegWatch: texts library command (' ..
                first_cmd ..
                ') requires ' ..
                approved_commands[first_cmd].n ..
                ' ' ..
                approved_commands[first_cmd].t .. '-type input' .. (approved_commands[first_cmd].n > 1 and 's' or ''))
                return
            end
        end
        texts[first_cmd](box, unpack(tab))
        settings.text_box_settings = box.settings()
        config.save(settings)
    elseif first_cmd == 'reload' then
        windower.send_command('lua r segwatch')
    elseif first_cmd == 'unload' then
        windower.send_command('lua u segwatch')
    elseif first_cmd == 'reset' then
        initialize()
    elseif first_cmd == 'eval' then
        assert(loadstring(table.concat(commands, ' ')))()
    elseif first_cmd == 'add' and #commands >= 1 then
        local amount = tonumber(commands[1])
        if amount then
            add_segments(amount)
            print('SegWatch: Added ' .. amount .. ' segments manually')
        end
    elseif first_cmd == 'set' and #commands >= 1 then
        local amount = tonumber(commands[1])
        if amount then
            segments.current = amount

            update_box()
            print('SegWatch: Set segments to ' .. amount)
        end
    elseif first_cmd == 'stats' then
        print_segment_stats()
    elseif first_cmd == 'status' then
        print('SegWatch: Current segment count is ' .. segments.current)

        print('SegWatch: Segments this run: ' .. segments.run_segments)
    elseif first_cmd == 'refresh' then
        print('SegWatch: Refreshing segment data...')
        request_currency_data()

    end
end)



function analyze_segments_table(tab)
    local t = os.clock()
    local running_total = 0
    local maximum_timestamp = 29

    for ts, amount in pairs(tab) do
        local time_diff = t - ts
        if time_diff > 600 then -- Remove entries older than 10 minutes
            tab[ts] = nil
        else
            running_total = running_total + amount
            if time_diff > maximum_timestamp then
                maximum_timestamp = time_diff
            end
        end
    end

    local rate
    if maximum_timestamp == 29 then
        rate = 0
    else
        rate = math.floor((running_total / maximum_timestamp) * 3600) -- Segments per hour
    end

    return rate
end

function analyze_run_segments_table(tab)
    local t = os.clock()
    local running_total = 0
    local maximum_timestamp = 29

    for ts, amount in pairs(tab) do
        local time_diff = t - ts
        if time_diff > 600 then -- Remove entries older than 10 minutes
            tab[ts] = nil
        else
            running_total = running_total + amount
            if time_diff > maximum_timestamp then
                maximum_timestamp = time_diff
            end
        end
    end

    local rate
    if maximum_timestamp == 29 then
        rate = 0
    else
        rate = math.floor((running_total / maximum_timestamp) * 1800) -- Segments per 30 minutes
    end

    return rate
end



function add_segments(amount)
    local t = os.clock()
    segments.registry[t] = (segments.registry[t] or 0) + amount
    segments.run_registry[t] = (segments.run_registry[t] or 0) + amount

    segments.current = segments.current + amount
    segments.run_segments = segments.run_segments + amount

    if segments.run_start_time then
        segments.run_duration = os.clock() - segments.run_start_time
    end

    update_box()
end

function print_segment_stats()
    print('=== SegWatch Statistics ===')
    print('Current Segments: ' .. segments.current)

    print('Segments This Run: ' .. segments.run_segments)
    print('Current Rate: ' .. segments.rate .. ' segments/hour')
    print('Run Rate: ' .. segments.run_rate .. ' segments/30min')

    if segments.run_duration then
        local hours = math.floor(segments.run_duration / 3600)
        local minutes = math.floor((segments.run_duration % 3600) / 60)
        local seconds = math.floor(segments.run_duration % 60)
        print('Run Duration: ' .. string.format('%02d:%02d:%02d', hours, minutes, seconds))
    end

    if segments.run_segments > 0 and segments.run_duration and segments.run_duration > 0 then
        local avg_per_hour = math.floor((segments.run_segments / segments.run_duration) * 3600)
        print('Average Run Rate: ' .. avg_per_hour .. ' segments/hour')
    end
end



-- Initialize frame counter for prerender
frame_count = 0

-- Set up prerender event for display updates
windower.register_event('prerender', function()
    if frame_count % 30 == 0 and box:visible() then
        update_box()
    end
    frame_count = frame_count + 1
end)

-- Add login event to request currency data
windower.register_event('login', function()
    print('SegWatch: Player logged in, requesting currency data...')
    coroutine.schedule(function()
        request_currency_data()
    end, 3) -- Wait 3 seconds after login
end)

-- Check for last incoming packets after everything is loaded (like PointWatch)
for _, id in ipairs(packet_initiators) do
    local handler = packet_handlers[id]
    if handler then
        local last = windower.packets.last_incoming(id)
        if last then
            handler(last)
        end
    end
end

-- If no last packet available, request currency data
if windower.ffxi.get_info().logged_in then
    print('SegWatch: Addon loaded, requesting current segment data...')
    coroutine.schedule(function()
        request_currency_data()
    end, 1)
end
