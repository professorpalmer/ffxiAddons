-- PetInfo - Displays pet information in a GUI style display
-- Palmer (Zodiarchy @ Asura)
-- 2025-07-22

config = require('config')
texts = require('texts')
packets = require('packets')
require('strings')

_addon.name = 'PetInfo'
_addon.author = 'Palmer (Zodiarchy @ Asura)'
_addon.version = '1.0'
_addon.commands = {'petinfo', 'pi'}

-- Variables
local pet_data = {
    name = nil,
    hp_percent = 0,
    mp_percent = 0,
    tp = 0,
    distance = 0,
    target_name = nil,
    target_hp_percent = 0,
    target_distance = 0,
    active = false,
    target_id = nil,
    target_last_seen = 0,  -- Add this
    target_from_proximity = false  -- Add this
}

-- Add this debug flag at the top with other variables
local debug_targeting = true

-- Default settings
local defaults = {
    pos = { x = 100, y = 100 },
    bg = { alpha = 200, red = 0, green = 0, blue = 0, visible = true },
    text = { 
        size = 12, 
        font = 'Consolas', 
        alpha = 255, 
        red = 255, 
        green = 255, 
        blue = 255 
    },
    flags = { bold = false, italic = false, draggable = true },
    padding = 8
}

local settings = config.load(defaults)

-- Create text objects for the UI
local main_display = texts.new('', {
    pos = { x = settings.pos.x, y = settings.pos.y },
    bg = settings.bg,
    text = settings.text,
    flags = settings.flags,
    padding = settings.padding
})

-- Helper functions
local function create_progress_bar(percent, width, color_rgb)
    width = width or 20
    local filled = math.floor(percent / 100 * width)
    local empty = width - filled
    
    local bar = string.rep('█', filled) .. string.rep('░', empty)
    if color_rgb then
        bar = string.format('\\cs(%d,%d,%d)%s\\cr', color_rgb[1], color_rgb[2], color_rgb[3], bar)
    end
    return bar
end

local function get_hp_color(percent)
    if percent > 75 then return {100, 255, 100}    -- Green
    elseif percent > 50 then return {255, 255, 100} -- Yellow  
    elseif percent > 25 then return {255, 160, 100} -- Orange
    else return {255, 100, 100} end                 -- Red
end

local function get_mp_color(percent)
    if percent > 75 then return {100, 200, 255}    -- Light Blue
    elseif percent > 50 then return {100, 150, 255} -- Blue
    elseif percent > 25 then return {100, 100, 255} -- Dark Blue
    else return {150, 100, 200} end                 -- Purple
end

local function get_tp_color(tp)
    if tp >= 1000 then return {100, 255, 100}      -- Green
    else return {200, 200, 200} end                -- Gray
end

local function update_display()
    if not pet_data.active then
        main_display:hide()
        return
    end

    local output = ''
    
    -- Pet name and distance
    output = output .. string.format('\\cs(255,255,255)%s\\cr', pet_data.name or 'Unknown')
    if pet_data.distance > 0 then
        output = output .. string.format('%30s%.1f', '', pet_data.distance)
    end
    output = output .. '\n'
    
    -- Separator line
    output = output .. '\\cs(128,128,128)' .. string.rep('─', 30) .. '\\cr\n'
    
    -- HP Bar
    local hp_color = get_hp_color(pet_data.hp_percent)
    local hp_bar = create_progress_bar(pet_data.hp_percent, 20, hp_color)
    output = output .. string.format('HP: %s %d%%', hp_bar, pet_data.hp_percent) .. '\n'
    
    -- MP Bar (only show if pet has MP)
    if pet_data.mp_percent > 0 then
        local mp_color = get_mp_color(pet_data.mp_percent)
        local mp_bar = create_progress_bar(pet_data.mp_percent, 20, mp_color)
        output = output .. string.format('MP: %s %d%%', mp_bar, pet_data.mp_percent) .. '\n'
    end
    
    -- TP Bar
    local tp_color = get_tp_color(pet_data.tp)
    local tp_percent = math.min(pet_data.tp / 3000 * 100, 100)
    local tp_bar = create_progress_bar(tp_percent, 20, tp_color)
    output = output .. string.format('TP: %s %d', tp_bar, pet_data.tp) .. '\n'
    
    -- Target info (if pet has a target)
    if pet_data.target_name and pet_data.target_name ~= '' then
        output = output .. '\n'
        -- Target separator
        output = output .. '\\cs(128,128,128)' .. string.rep('─', 30) .. '\\cr\n'
        
        -- Target name and distance
        output = output .. string.format('\\cs(255,200,200)%s\\cr', pet_data.target_name)
        if pet_data.target_distance > 0 then
            output = output .. string.format('%20s%.1f', '', pet_data.target_distance)
        end
        output = output .. '\n'
        
        output = output .. '\\cs(128,128,128)' .. string.rep('─', 30) .. '\\cr\n'
        
        -- Target HP
        local target_hp_color = get_hp_color(pet_data.target_hp_percent)
        local target_hp_bar = create_progress_bar(pet_data.target_hp_percent, 20, target_hp_color)
        output = output .. string.format('HP: %s %d%%', target_hp_bar, pet_data.target_hp_percent)
    end
    
    main_display:text(output)
    main_display:show()
end

-- Get pet entity
local function get_pet()
    local player = windower.ffxi.get_player()
    if not player then return nil end
    
    return windower.ffxi.get_mob_by_target('pet')
end

-- Get entity by server ID
local function get_entity_by_server_id(sid)
    local mobs = windower.ffxi.get_mob_array()
    for _, mob in pairs(mobs) do
        if mob and mob.id == sid then
            return mob
        end
    end
    return nil
end

-- Update pet information (simplified - don't overwrite packet data)
local function update_pet_info()
    local pet = get_pet()
    
    if not pet then
        if pet_data.active then
            pet_data.active = false
            pet_data.target_id = nil
            pet_data.target_from_proximity = false
            update_display()
        end
        return
    end
    
    pet_data.active = true
    pet_data.name = pet.name or pet_data.name
    pet_data.distance = pet.distance and math.sqrt(pet.distance) or 0
    
    if not pet_data.hp_from_packet then
        pet_data.hp_percent = pet.hpp or 0
    end
    
    local current_time = os.clock()
    
    -- AGGRESSIVE target validation - clear target if it's not valid
    if pet_data.target_id and pet_data.target_id > 0 then
        local target = get_entity_by_server_id(pet_data.target_id)
        local target_valid = false
        
        if target and target.hpp and target.hpp > 0 then
            local target_distance = math.sqrt(target.distance)
            
            -- Target is valid if:
            -- 1. Close to pet (within 15 yalms)
            -- 2. Recently seen (within 3 seconds) OR has taken damage recently
            if target_distance < 15 then
                pet_data.target_name = target.name
                pet_data.target_hp_percent = target.hpp
                pet_data.target_distance = target_distance
                pet_data.target_last_seen = current_time
                target_valid = true
            end
        end
        
        -- Clear target if invalid OR if it's a proximity target that's too old
        if not target_valid or 
           (pet_data.target_from_proximity and (current_time - pet_data.target_last_seen) > 5) then
            windower.add_to_chat(8, 'Clearing invalid/old target')
            pet_data.target_name = nil
            pet_data.target_id = nil
            pet_data.target_from_proximity = false
        end
    end
    
    -- Only search for new target if we don't have one OR our current one is from proximity
    if not pet_data.target_id or pet_data.target_from_proximity then
        local best_target = nil
        local best_score = 0
        
        local mobs = windower.ffxi.get_mob_array()
        for _, mob in pairs(mobs) do
            if mob and mob.spawn_type == 16 and mob.hpp > 0 then
                local distance = math.sqrt(mob.distance)
                
                -- Only consider very close enemies
                if distance < 8 then
                    local score = 0
                    
                    -- HEAVILY prioritize injured enemies (likely in combat)
                    if mob.hpp < 100 then
                        score = score + 100
                    end
                    
                    -- HEAVILY prioritize very close enemies
                    if distance < 5 then
                        score = score + 80
                    end
                    
                    -- Prioritize closer enemies
                    score = score + (8 - distance) * 10
                    
                    -- Big bonus for enemies with status effects
                    if mob.status and mob.status ~= 0 then
                        score = score + 60
                    end
                    
                    if score > best_score then
                        best_score = score
                        best_target = mob
                    end
                end
            end
        end
        
        -- Only use proximity target if it's VERY likely to be correct AND better than current
        if best_target and best_score > 120 then
            -- If we already have a proximity target, only switch if new one is much better
            if pet_data.target_from_proximity then
                if best_target.id ~= pet_data.target_id and best_score > 140 then
                    pet_data.target_id = best_target.id
                    pet_data.target_name = best_target.name
                    pet_data.target_hp_percent = best_target.hpp
                    pet_data.target_distance = math.sqrt(best_target.distance)
                    pet_data.target_from_proximity = true
                    pet_data.target_last_seen = current_time
                    windower.add_to_chat(121, string.format('Switched target: %s (score: %d)', best_target.name, best_score))
                end
            else
                -- No current target, use this one
                pet_data.target_id = best_target.id
                pet_data.target_name = best_target.name
                pet_data.target_hp_percent = best_target.hpp
                pet_data.target_distance = math.sqrt(best_target.distance)
                pet_data.target_from_proximity = true
                pet_data.target_last_seen = current_time
                windower.add_to_chat(121, string.format('New proximity target: %s (score: %d)', best_target.name, best_score))
            end
        end
    end
    
    update_display()
end

-- Event handlers
windower.register_event('prerender', function()
    update_pet_info()
end)

-- Replace the packet handling section with this corrected version:

windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
    if injected then return end
    
    -- Puppet MP/HP update packet
    if id == 0x44 then
        if original:unpack('C', 0x05) == 0x12 then    -- puppet update
            local new_current_hp, new_max_hp, new_current_mp, new_max_mp = original:unpack('HHHH', 0x069)
            local puppet_name = original:unpack('z', 0x59)
            
            if pet_data.active and pet_data.name == puppet_name then
                if new_max_mp > 0 then
                    pet_data.mp_percent = math.floor(100 * new_current_mp / new_max_mp)
                else
                    pet_data.mp_percent = 0
                end
                pet_data.hp_from_packet = true
            end
        end
    end
    
    -- General HP/TP/MP update packets 
    if id == 0x67 or id == 0x68 then
        local packet = packets.parse('incoming', original)
        if not packet then return end
        
        local msg_type = packet['Message Type']
        local pet_idx = packet['Pet Index']
        local own_idx = packet['Owner Index']
        
        if (msg_type == 0x04) and id == 0x67 then
            pet_idx, own_idx = own_idx, pet_idx
        end
        
        if (msg_type == 0x04) then
            local player = windower.ffxi.get_player()
            if not player then return end
            
            if (pet_idx == 0) then
                pet_data.active = false
                pet_data.target_id = nil
                update_display()
            elseif own_idx == player.index then
                local new_hp_percent = packet['Current HP%']
                local new_mp_percent = packet['Current MP%']
                local new_tp_percent = packet['Pet TP']
                local pet_name = packet['Pet Name']
                
                if pet_name and pet_name ~= '' then
                    pet_data.name = pet_name
                    pet_data.active = true
                end
                
                if new_hp_percent and new_hp_percent > 0 then
                    pet_data.hp_percent = new_hp_percent
                    pet_data.hp_from_packet = true
                end
                
                if new_mp_percent and new_mp_percent > 0 then
                    pet_data.mp_percent = new_mp_percent
                end
                
                if new_tp_percent then
                    pet_data.tp = new_tp_percent
                end
            end
        end
    end
    
    -- Pet action packet - ENHANCED targeting logic
    if id == 0x28 then
        local player = windower.ffxi.get_player()
        if not player then return end
        
        local actor_id = original:unpack('I', 0x05)
        local pet = get_pet()
        
        if pet and actor_id == pet.id then
            local targets_count = original:unpack('C', 0x09)
            
            if targets_count > 0 then
                local target_id = original:unpack('I', 0x16)
                
                if target_id and target_id > 0 then
                    pet_data.target_id = target_id
                    pet_data.target_from_proximity = false  -- This is authoritative data
                    pet_data.target_last_seen = os.clock()
                    windower.add_to_chat(121, string.format('Pet action target: %d (PACKET)', target_id))
                end
            end
        end
    end
end)

-- Fallback: Proximity-based target guessing
local function guess_pet_target()
    local pet = get_pet()
    if not pet then return end
    
    local closest_enemy = nil
    local closest_distance = 999
    
    local mobs = windower.ffxi.get_mob_array()
    for _, mob in pairs(mobs) do
        if mob and mob.spawn_type == 16 and mob.hpp > 0 then -- Enemy
            local distance = math.sqrt(mob.distance)
            if distance < 20 and distance < closest_distance then
                closest_distance = distance
                closest_enemy = mob
            end
        end
    end
    
    if closest_enemy then
        pet_data.target_id = closest_enemy.id
        pet_data.target_name = closest_enemy.name
    end
end

windower.register_event('zone change', function()
    pet_data.active = false
    pet_data.target_id = nil
    update_display()
end)

windower.register_event('job change', function()
    pet_data.active = false
    pet_data.target_id = nil
    update_display()
end)

windower.register_event('addon command', function(command, ...)
    command = command and command:lower() or 'help'
    
    if command == 'help' then
        windower.add_to_chat(121, 'PetInfo Commands:')
        windower.add_to_chat(121, '  //petinfo pos <x> <y> - Set position')
        windower.add_to_chat(121, '  //petinfo save - Save settings')
        windower.add_to_chat(121, '  //petinfo reload - Reload addon')
        windower.add_to_chat(121, '  //petinfo test - Show test display')
    elseif command == 'pos' then
        local args = {...}
        if args[1] and args[2] then
            settings.pos.x = tonumber(args[1])
            settings.pos.y = tonumber(args[2])
            main_display:pos(settings.pos.x, settings.pos.y)
            windower.add_to_chat(121, 'Position set to: ' .. settings.pos.x .. ', ' .. settings.pos.y)
        end
    elseif command == 'save' then
        config.save(settings)
        windower.add_to_chat(121, 'Settings saved.')
    elseif command == 'reload' then
        windower.send_command('lua reload petinfo')
    elseif command == 'test' then
        -- Force show test display
        pet_data.active = true
        pet_data.name = "Test Pet"
        pet_data.hp_percent = 85
        pet_data.mp_percent = 60
        pet_data.tp = 1200
        pet_data.distance = 15.3
        update_display()
        windower.add_to_chat(121, 'Test display shown')
    end
end)

windower.register_event('load', function()
    windower.add_to_chat(121, 'PetInfo loaded. Use //petinfo test to test display.')
    update_pet_info()
end)
