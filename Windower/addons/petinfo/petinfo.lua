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
    target_id = nil
}

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

-- Update pet information
local function update_pet_info()
    local pet = get_pet()
    
    if not pet then
        pet_data.active = false
        update_display()
        return
    end
    
    pet_data.active = true
    pet_data.name = pet.name
    pet_data.hp_percent = pet.hpp or 0
    pet_data.distance = pet.distance and math.sqrt(pet.distance) or 0
    
    -- Get TP and MP from player data
    local player = windower.ffxi.get_player()
    if player then
        pet_data.tp = player.pet_tp or 0
        pet_data.mp_percent = player.pet_mp_percent or 0
    end
    
    -- Update target info if pet has one
    if pet_data.target_id then
        local target = get_entity_by_server_id(pet_data.target_id)
        if target and target.hpp and target.hpp > 0 then
            pet_data.target_name = target.name
            pet_data.target_hp_percent = target.hpp
            pet_data.target_distance = target.distance and math.sqrt(target.distance) or 0
        else
            pet_data.target_name = nil
            pet_data.target_id = nil
        end
    end
    
    update_display()
end

-- Event handlers
windower.register_event('prerender', function()
    update_pet_info()
end)

windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
    if injected then return end
    
    -- Pet action packet - track pet target
    if id == 0x28 then
        local player = windower.ffxi.get_player()
        local pet = get_pet()
        
        if player and pet then
            local actor_id = original:unpack('I', 0x05)
            if actor_id == pet.id then
                pet_data.target_id = original:unpack('I', 0x16)
            end
        end
    end
    
    -- Pet sync packet
    if id == 0x68 then
        local player = windower.ffxi.get_player()
        if player then
            local owner_id = original:unpack('I', 0x08)
            if owner_id == player.id then
                pet_data.target_id = original:unpack('I', 0x14)
            end
        end
    end
end)

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
