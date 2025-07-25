addon.name = 'SortieBuddy'
addon.author = 'Dabidobido - Ashita 4 conversion by Palmer (Zodiarchy @ Asura)'
addon.version = '1.2.0'
addon.desc = 'Sortie target tracking and distance display for Ashita 4'

require('common')
local imgui = require('imgui')
local settings = require('settings')

local targets = nil
local current_target = ""
local current_zone = nil
local test_mode = false

local default_settings = T{
    pos = T{
        x = 144,
        y = 144
    },
    text = T{
        font = 'Segoe UI',
        size = 12,
        alpha = 255,
        red = 246,
        green = 131,
        blue = 188
    },
    bg = T{
        alpha = 175,
        red = 52,
        green = 109,
        blue = 166
    },
    mobs = T{
        ["133"] = T{ -- Sortie
            a = 144,
            b = 223,
            c = 285,
            d = 373,
            f = 837,
            g = 838,
            h = 839
        }
    }
}

local sortie_settings = settings.load(default_settings)

-- Display variables
local display_text = ""
local show_display = false

local function notice(message)
    print(string.format('\31\200[\31\05%s\31\200]\31\207 %s', addon.name, message))
end

local function help_command()
    notice("showinfo: shows target info for current zone")
    notice("ping (name): ping a target for the current zone")
    notice("spawn (name): forces a target to spawn in the current zone")
    notice("add (name): saves the currently selected target to settings so that it can be spawned or pinged later")
    notice("remove (zone_id, name): removes the named target from the zone_id in the settings file")
    notice("Default settings has target information for Sortie:")
    notice("a = Abject Obdella")
    notice("b = Biune Porxie")
    notice("c = Cachaemic Bhoot")
    notice("d = Demisang Deleterious")
    notice("f = Diaphanous Bitzer #F")
    notice("g = Diaphanous Bitzer #G")
    notice("h = Diaphanous Bitzer #H")
end

-- Command handler
ashita.events.register('command', 'sortiebuddy_command', function (e)
    local args = e.command:args()
    if (#args == 0 or (args[1] ~= '/sortiebuddy' and args[1] ~= '/srtb')) then
        return
    end
    
    e.blocked = true
    
    if (#args == 1) then
        help_command()
        return
    end
    
    local command = args[2]:lower()

    if command == 'ping' then
        if args[3] then
            local zone = tostring(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
            if sortie_settings.mobs[zone] then
                local arg3 = args[3]:lower()
                if sortie_settings.mobs[zone][arg3] then
                    targets = nil
                    show_display = false
                    current_target = arg3
                    
                    -- Create and inject targeting packet (0x016)
                    local target_index = sortie_settings.mobs[zone][current_target]
                    local packet_data = struct.pack('<BBBBI', 0x16, 0x04, 0x00, 0x00, target_index, 0x00, 0x00)
                    AshitaCore:GetPacketManager():AddOutgoingPacket(0x16, packet_data)
                else
                    notice("Error: No info for " .. arg3 .. " in zone " .. zone)
                end
            else
                notice("Error: No info for zone " .. zone)
            end
        else
            notice("Error: Ping command needs a name for 2nd argument")
        end
        
    elseif command == 'add' and args[3] then
        local player = GetPlayerEntity()
        local arg3 = args[3]:lower()
        if player and player.TargetIndex and player.TargetIndex > 0 then
            local zone = tostring(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
            if not sortie_settings.mobs[zone] then 
                sortie_settings.mobs[zone] = T{}
            end
                         sortie_settings.mobs[zone][arg3] = player.TargetIndex
             settings.save(sortie_settings)
            notice("Adding target index " .. player.TargetIndex .. " to zone " .. zone .. " as " .. arg3)
        else
            notice("Error: Need target for add command")
        end
        
    elseif command == 'remove' then
        if args[3] and args[4] then
            if sortie_settings.mobs[args[3]] then
                local arg4 = args[4]:lower()
                if sortie_settings.mobs[args[3]][arg4] then
                    sortie_settings.mobs[args[3]][arg4] = nil
                    notice("Removing " .. arg4 .. " from settings for zone id " .. args[3])
                    local count = 0
                    for _,_ in pairs(sortie_settings.mobs[args[3]]) do
                        count = count + 1
                    end
                    if count == 0 then
                        sortie_settings.mobs[args[3]] = nil
                        notice("Removing zone id " .. args[3] .. " from settings")
                    end
                                         settings.save(sortie_settings)
                else
                    notice("Error: Entry " .. arg4 .. " not found in settings for zone id " .. args[3])
                end
            else
                notice("Error: Zone id " .. args[3] .. " not found in settings")
            end
        else
            notice("Error: Remove command needs zone_id and name arguments")
        end
        
    elseif command == 'spawn' and args[3] then
        local zone = tostring(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
        if sortie_settings.mobs[zone] then
            local arg3 = args[3]:lower()
            if sortie_settings.mobs[zone][arg3] then
                -- Create and inject targeting packet (0x016)  
                local target_index = sortie_settings.mobs[zone][arg3]
                local packet_data = struct.pack('<BBBBI', 0x16, 0x04, 0x00, 0x00, target_index, 0x00, 0x00)
                AshitaCore:GetPacketManager():AddOutgoingPacket(0x16, packet_data)
            else
                notice("Error: No info for " .. arg3 .. " in zone " .. zone)
            end
        else
            notice("Error: No info for zone " .. zone)
        end
        
    elseif command == 'showinfo' then
        local zone = tostring(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
        notice('Current zone is ' .. zone)
        if sortie_settings.mobs[zone] then
            for name, index in pairs(sortie_settings.mobs[zone]) do
                notice(name .. " = " .. index)
            end
        else
            notice("No mob data for zone " .. zone)
        end
    else
        help_command()
    end
end)

local function get_distance(p1, p2)
    if p1 and p2 then
        return math.sqrt(math.pow(p1.x - p2.x, 2) + math.pow(p1.y - p2.y, 2))
    else
        return 0
    end
end

local function get_direction(p1, p2)
    if p1 and p2 then 
        local angle = math.atan2(p2.y - p1.y, p2.x - p1.x)
        angle = angle + math.pi
        angle = angle / (math.pi * 2 / 8)
        local heading = math.round(angle) % 8
        if heading == 0 then return "W"
        elseif heading == 1 then return "SW"
        elseif heading == 2 then return "S"
        elseif heading == 3 then return "SE"
        elseif heading == 4 then return "E"
        elseif heading == 5 then return "NE"
        elseif heading == 6 then return "N"
        elseif heading == 7 then return "NW"
        end
    end
    return "??"
end

local function update_display_text()
    if not targets then 
        display_text = ""
        return 
    end
    
    local player = GetPlayerEntity()
    if not player then 
        display_text = ""
        return 
    end
    
    display_text = ""
    for k, v in pairs(targets) do
        local distance = get_distance(player, v)
        local direction = get_direction(player, v)
        display_text = display_text .. v.name .. " Distance: " .. string.format("%.2f", distance) .. " (" .. direction .. ")\n"
    end
end

-- Packet handler for mob position data
ashita.events.register('packet_in', 'sortiebuddy_packet_in', function(e)
    if current_zone and current_target ~= "" then
        if e.id == 0x0E then
            local mob_index = struct.unpack('<H', e.data, 0x04 + 1)
            if sortie_settings.mobs[current_zone] and sortie_settings.mobs[current_zone][current_target] == mob_index then
                local mobx = struct.unpack('<f', e.data, 0x0C + 1)
                local moby = struct.unpack('<f', e.data, 0x14 + 1)
                notice("got mob x: " .. string.format("%.2f", mobx) .. " y: " .. string.format("%.2f", moby))
                targets = T{}
                targets[mob_index] = T{ x = mobx, y = moby, name = current_target }
                current_target = ""
                show_display = true
            end
        end
    end
end)

-- Zone change handler
local function zone_change()
    targets = nil
    current_target = ""
    current_zone = tostring(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
    show_display = false
end

-- Event registrations
ashita.events.register('packet_in', 'sortiebuddy_zone_change', function(e)
    if e.id == 0x0A then -- Zone change packet
        zone_change()
    end
end)

-- Load handler
ashita.events.register('load', 'sortiebuddy_load', function()
    current_zone = tostring(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
end)

-- Unload handler  
ashita.events.register('unload', 'sortiebuddy_unload', function()
    targets = nil
    current_target = ""
    show_display = false
end)

-- Render loop
ashita.events.register('d3d_present', 'sortiebuddy_render', function()
    if targets and show_display then 
        update_display_text()
        
        -- Display using ImGui
        if display_text ~= "" then
            if imgui.Begin('SortieBuddy', true, ImGuiWindowFlags_AlwaysAutoResize) then
                -- Apply custom styling
                imgui.PushStyleColor(ImGuiCol_WindowBg, {
                    sortie_settings.bg.red / 255, 
                    sortie_settings.bg.green / 255, 
                    sortie_settings.bg.blue / 255, 
                    sortie_settings.bg.alpha / 255
                })
                imgui.PushStyleColor(ImGuiCol_Text, {
                    sortie_settings.text.red / 255,
                    sortie_settings.text.green / 255, 
                    sortie_settings.text.blue / 255,
                    sortie_settings.text.alpha / 255
                })
                
                imgui.Text(display_text)
                
                imgui.PopStyleColor(2)
                imgui.End()
            end
        end
    end
end)