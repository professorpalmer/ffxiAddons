_addon.author   = 'Palmer (Zodiarchy @ Asura)'
_addon.version  = '1.0'
_addon.commands = {'TripleFarm', 'tf'}

require 'logger'
require 'strings'
require('coroutine')
packets = require('packets')
res = require('resources')

-- Constants
local BUFFS = {
	ELVORSEAL = 603,
	SILENCE = 6,
	SLEEP = 2
}

local DISTANCES = {
	INTERACTION = 6,
	CLOSE_INTERACTION = 3,
	COMBAT = 7
}

-- Boss configurations
local BOSSES = {
	QUETZ = {
		name = "Quetzalcoatl",
		zones = {"La Theine Plateau", "Konschtat Highlands", "Tahrongi Canyon"},
		target_zone = "Reisenjima",
		entrance_zones = {"La Theine Plateau", "Konschtat Highlands", "Tahrongi Canyon"},
		portal_name = "Dimensional Portal",
		npc_name = "Shiftrix",
		boss_name = "Quetzalcoatl",
		teleport_ring = "Dim. Ring (Holla)",
		wait_x = 612.17,
		wait_y = -933.43,
		inside_check = function(me) return not (me.y < -400 and me.y > -550) end
	},
	AZI = {
		name = "Azi Dahaka",
		zones = {"Qufim Island"},
		target_zone = "Escha - Zi'Tah",
		entrance_zones = {"Qufim Island"},
		portal_name = "Undulating Confluence",
		npc_name = "Affi",
		boss_name = "Azi Dahaka",
		teleport_ring = "Warp Ring",
		wait_x = -11.00,
		wait_y = 37.50,
		inside_check = function(me) return not (me.x < -100) end
	},
	NAGA = {
		name = "Naga Raja",
		zones = {"Misareaux Coast"},
		target_zone = "Escha - Ru'Aun",
		entrance_zones = {"Misareaux Coast"},
		portal_name = "Undulating Confluence",
		npc_name = "Dremi",
		boss_name = "Naga Raja",
		teleport_ring = "Warp Ring",
		wait_x = 0.00,
		wait_y = -210.00,
		inside_check = function(me) return not (me.y < -250) end
	}
}

-- Rotation settings
local rotation_order = {"QUETZ", "AZI", "NAGA"}  -- Default rotation order
local current_boss_index = 1
local rotation_enabled = true
local kills_per_boss = 1  -- How many kills before moving to next boss
local current_kills = 0
local boss_defeated = false

-- Global state
local nexttime = os.clock()
local delay = 0
local busy = false
local inside = false
local running = false
local fighting = false
local waiting = false
local tp = false
local npc = false
local pause = 'on'
local current_boss = rotation_order[current_boss_index]

-- Trust settings (shared across all bosses)
local trust1 = 'Matsui-P'
local trust1_short = 'Matsui-P'
local trust2 = 'Koru-Moru'
local trust2_short = 'Koru'
local trust3 = 'Prishe II'
local trust3_short = 'Prishe'
local trust4 = 'Lilisette II'
local trust4_short = 'Lilisette'
local trust5 = 'Nashmeira II'
local trust5_short = 'Nashmeira'

-- Random wait position for current boss
local wait_x = 0
local wait_y = 0

-- Safety function to get mobs
function safeGetMob(name)
	local mob = windower.ffxi.get_mob_by_name(name)
	if not mob then
		log('Warning: Could not find ' .. name)
	end
	return mob
end

-- Validate basic state
function validateState()
	local player = windower.ffxi.get_player()
	if not player then
		log('Error: Cannot get player data')
		return false
	end
	
	local info = windower.ffxi.get_info()
	if not info or not info.zone then
		log('Error: Cannot determine current zone')
		return false
	end
	
	return true
end

-- Get current boss configuration
function getCurrentBoss()
	return BOSSES[current_boss]
end

-- Move to next boss in rotation
function nextBoss()
	if not rotation_enabled then return end
	
	current_boss_index = current_boss_index + 1
	if current_boss_index > #rotation_order then
		current_boss_index = 1
	end
	current_boss = rotation_order[current_boss_index]
	current_kills = 0
	boss_defeated = false
	
	local boss_config = getCurrentBoss()
	log('Switching to: ' .. boss_config.name)
	
	-- Reset state for new boss
	inside = false
	running = false
	fighting = false
	waiting = false
	
	-- Update wait position for new boss
	findWaitPosition()
	
	-- Teleport to new area
	teleportToNextBoss()
end

-- Teleport to the next boss area
function teleportToNextBoss()
	local boss_config = getCurrentBoss()
	local teleport_ring = boss_config.teleport_ring
	
	if getEquippedItem('right_ring') ~= teleport_ring then
		windower.send_command('wait 3;input /equip ring2 "'..teleport_ring..'"')
		windower.send_command('wait 6;input /item "'..teleport_ring..'" <me>')
	else
		windower.send_command('wait 3;input /item "'..teleport_ring..'" <me>')
	end
	delay = 30
end

-- Check if we're in the right zone for current boss
function isInCorrectZone(zone_name)
	local boss_config = getCurrentBoss()
	
	-- Check if we're in an entrance zone
	for _, entrance_zone in ipairs(boss_config.entrance_zones) do
		if zone_name == entrance_zone then
			return true
		end
	end
	
	-- Check if we're in the target zone
	if zone_name == boss_config.target_zone then
		return true
	end
	
	return false
end

-- Generate random wait position
function findWaitPosition()
	local boss_config = getCurrentBoss()
	
	if current_boss == "NAGA" then
		local offset_x = randomFloat(-5, 5)
		local offset_y = randomFloat(-5, 5)
		
		local space_x = offset_x / math.abs(offset_x)
		local space_y = offset_y / math.abs(offset_y)
		
		offset_x = offset_x + space_x * 6
		offset_y = offset_y + space_y * 6

		wait_x = boss_config.wait_x + offset_x
		wait_y = boss_config.wait_y + offset_y
	else
		wait_x = boss_config.wait_x + math.random(0.10, 1.5)
		wait_y = boss_config.wait_y + math.random(0.10, 1.5)
	end
	
	log('Waiting at X: ' .. wait_x .. ', Y: ' .. wait_y)
end

function randomFloat(min, max)
    return min + math.random() * (max - min)
end

-- Initialize wait position
findWaitPosition()

-- Main event loop
windower.register_event('prerender', function()
	local curtime = os.clock()
	if nexttime + delay <= curtime then
		nexttime = curtime
		delay = 0.2
		
		-- Validate basic state before proceeding
		if not validateState() then
			log('State validation failed, pausing')
			pause = 'on'
			return
		end
		
		local player = windower.ffxi.get_player()
		local me = windower.ffxi.get_mob_by_target('me')
		local info = windower.ffxi.get_info()
		local zone = res.zones[info.zone].name
		
		if pause == 'on' then return end
		
		local boss_config = getCurrentBoss()
		
		-- Check if we need to move to next boss
		if boss_defeated and current_kills >= kills_per_boss then
			log(boss_config.name .. ' defeated ' .. current_kills .. ' times, moving to next boss')
			nextBoss()
			return
		end
		
		-- If we're not in the correct zone, teleport there
		if not isInCorrectZone(zone) then
			log('Not in correct zone for ' .. boss_config.name .. ', teleporting...')
			teleportToNextBoss()
			return
		end
		
		-- Handle entrance zones
		local is_entrance_zone = false
		for _, entrance_zone in ipairs(boss_config.entrance_zones) do
			if zone == entrance_zone then
				is_entrance_zone = true
				break
			end
		end
		
		if is_entrance_zone then
			enterTargetZone()
		elseif zone == boss_config.target_zone then
			-- We're in the target zone, handle the boss fight
			npc = safeGetMob(boss_config.npc_name)
			inside = boss_config.inside_check(me)
			
			if not inside then
				enterArena()
			elseif inside then
				if player.status == 1 or player.in_combat then
					waiting = true
					fight()
				elseif not waiting then
					windower.send_command('setkey escape down;wait 1;setkey escape up')
					moveToLocation()
				elseif waiting then
					fight()
				end
			end
		end
	end
end)

-- Enter the target zone (Reisenjima/Escha)
function enterTargetZone()
	local me = windower.ffxi.get_mob_by_target('me')
	local boss_config = getCurrentBoss()
	tp = safeGetMob(boss_config.portal_name)
	
	if tp and math.sqrt(tp.distance) > DISTANCES.INTERACTION and not running then
		log('Entering ' .. boss_config.target_zone)
		windower.ffxi.run(tp.x - me.x, tp.y - me.y)
		running = true
	elseif tp and math.sqrt(tp.distance) <= DISTANCES.INTERACTION then
		windower.ffxi.run(false)
		running = false
		local p = packets.new('outgoing', 0x01A, {
            ['Target'] = tp.id,
            ['Target Index'] = tp.index,
        })
        packets.inject(p)
		busy = true
		inside = true
	end
end

-- Enter the boss arena
function enterArena()
	local me = windower.ffxi.get_mob_by_target('me')
	local boss_config = getCurrentBoss()
	npc = safeGetMob(boss_config.npc_name)
	
	if current_boss == "QUETZ" then
		-- Quetz uses different logic - direct packet injection
		if npc then
			local p = packets.new('outgoing', 0x01A, {
				['Target'] = npc.id,
				['Target Index'] = npc.index,
			})
			busy = true
			packets.inject(p)
		end
	else
		-- Azi and Naga use distance-based approach
		if npc and math.sqrt(npc.distance) > DISTANCES.CLOSE_INTERACTION and not running then
			log('Entering ' .. boss_config.target_zone .. ' arena')
			windower.ffxi.run(npc.x - me.x, npc.y - me.y)
			running = true
		elseif npc and math.sqrt(npc.distance) <= DISTANCES.CLOSE_INTERACTION then
			windower.ffxi.run(false)
			running = false
			local p = packets.new('outgoing', 0x01A, {
				['Target'] = npc.id,
				['Target Index'] = npc.index,
			})
			busy = true
			packets.inject(p)
		end
	end
	
	windower.send_command('setkey escape down;wait 0.5;setkey escape up')
	delay = 5
end

-- Move to waiting location
function moveToLocation()
	local me = windower.ffxi.get_mob_by_target('me')
	if not me then
		log('Error: Cannot get player position')
		return
	end
	
	if isBuffActive(BUFFS.ELVORSEAL) then
		windower.send_command('setkey escape down;wait 1;setkey escape up')
		if math.abs(wait_x - me.x) > 2 and math.abs(wait_y - me.y) > 2 and not waiting then
			windower.ffxi.run(wait_x - me.x, wait_y - me.y)
		elseif math.abs(wait_x - me.x) <= 2 and math.abs(wait_y - me.y) <= 2 and not waiting then
			windower.ffxi.run(false)
			waiting = true
			delay = 3
			findWaitPosition()
		end
	else
		fight()
	end
end

-- Fight the boss
function fight()
	local boss_config = getCurrentBoss()
	local boss = safeGetMob(boss_config.boss_name)
	local player = windower.ffxi.get_player()
	local party = windower.ffxi.get_party()
	local partymembers = party.p5 or false
	
	if not boss then
		log('Error: Cannot find ' .. boss_config.boss_name)
		return
	end
	
	if isBuffActive(BUFFS.ELVORSEAL) then	
		if boss.hpp > 0 then
			fighting = true
			boss_defeated = false
		else
			if fighting then
				-- Boss just died
				current_kills = current_kills + 1
				boss_defeated = true
				fighting = false
				log(boss_config.boss_name .. ' defeated! Kill count: ' .. current_kills)
			end
		end
		
		if waiting and player.status == 0 then
			if summonTrust() ~= false and not isBuffActive(BUFFS.SILENCE) and not isBuffActive(BUFFS.SLEEP) then
				windower.send_command('input /ma "'..summonTrust()..'" <me>')
			end
			delay = 3
		end

		if player.status == 0 and isBuffActive(BUFFS.ELVORSEAL) and fighting then
			local engage_packet = packets.new('outgoing', 0x01A, {
				['Target'] = boss.id,
				['Target Index'] = boss.index,
				['Category'] = 0x02,
			})
			packets.inject(engage_packet)
			delay = 1
		elseif math.sqrt(boss.distance) > DISTANCES.COMBAT and player.status == 1 and fighting then
			local target = windower.ffxi.get_mob_by_index(player.target_index or 0)
			local self_vector = windower.ffxi.get_mob_by_index(player.index or 0)
			local angle = (math.atan2((target.y - self_vector.y), (target.x - self_vector.x))*180/math.pi)*-1
			windower.ffxi.turn((angle):radian())
			windower.ffxi.run(true)
		elseif math.sqrt(boss.distance) <= DISTANCES.COMBAT and player.status == 1 and fighting and not partymembers then
			windower.ffxi.run(false)
			if summonTrust() ~= false and not isBuffActive(BUFFS.SILENCE) and not isBuffActive(BUFFS.SLEEP) then
				windower.send_command('input /ma "'..summonTrust()..'" <me>')
			end
			delay = 3
		end
	elseif not isBuffActive(BUFFS.ELVORSEAL) and not isBuffActive(BUFFS.SLEEP) then
		windower.ffxi.run(false)
		if player.status > 1 then
			delay = 30
			windower.send_command('wait 10;setkey enter down;wait 1;setkey enter up;wait 3;setkey left down;wait 1;setkey left up;wait 3;setkey enter down;wait 1;setkey enter up')
		else
			-- Elvorseal expired, check if we should move to next boss
			if boss_defeated and current_kills >= kills_per_boss then
				nextBoss()
			else
				-- Re-enter arena for another fight
				local boss_config = getCurrentBoss()
				local teleport_ring = boss_config.teleport_ring
				if getEquippedItem('right_ring') ~= teleport_ring then
					windower.send_command('wait 3;input /equip ring2 "'..teleport_ring..'"')
				else
					windower.send_command('wait 3;input /item "'..teleport_ring..'" <me>')
				end
				delay = 30
			end
		end
	end
end

-- Get equipped item
function getEquippedItem(slot_name)
	local inventory = windower.ffxi.get_items()
	local equipment = inventory['equipment']
	local item_id = windower.ffxi.get_items(equipment[string.format('%s_bag', slot_name)], equipment[slot_name]).id
	return res.items:with('id', item_id).en
end

-- Summon trust
function summonTrust()
	local party = windower.ffxi.get_party()
	if party.p5 then 
		return false
	end
	local spellrecasts = windower.ffxi.get_spell_recasts()
	local checkt1 = false
	local checkt2 = false
	local checkt3 = false
	local checkt4 = false
	local checkt5 = false
	
	for i, v in pairs(party) do
		if string.match(i, 'p[0-5]') and v.mob and (v.mob.name == trust1 or v.mob.name == trust1_short) then
			checkt1 = true
		elseif string.match(i, 'p[0-5]') and v.mob and (v.mob.name == trust2 or v.mob.name == trust2_short) then
			checkt2 = true
		elseif string.match(i, 'p[0-5]') and v.mob and (v.mob.name == trust3 or v.mob.name == trust3_short) then
			checkt3 = true
		elseif string.match(i, 'p[0-5]') and v.mob and (v.mob.name == trust4 or v.mob.name == trust4_short) then
			checkt4 = true
		elseif string.match(i, 'p[0-5]') and v.mob and (v.mob.name == trust5 or v.mob.name == trust5_short) then
			checkt5 = true
		end
	end
	
	if spellrecasts[res.spells:with('en', trust1).recast_id] == 0 and not checkt1 then
		return trust1
	elseif spellrecasts[res.spells:with('en', trust2).recast_id] == 0 and not checkt2 then
		return trust2
	elseif spellrecasts[res.spells:with('en', trust3).recast_id] == 0 and not checkt3 then
		return trust3
	elseif spellrecasts[res.spells:with('en', trust4).recast_id] == 0 and not checkt4 then
		return trust4
	elseif spellrecasts[res.spells:with('en', trust5).recast_id] == 0 and not checkt5 then
		return trust5
	else
		return false
	end
end

-- Check if buff is active
function isBuffActive(id)
	local self = windower.ffxi.get_player()
	for k,v in pairs(self.buffs) do
		if (v == id) then
			return true
		end	
	end
	return false
end

-- Packet handling for outgoing chunks
windower.register_event('outgoing chunk',function(id,data,modified,injected,blocked)
	local player = windower.ffxi.get_player()
	local me = windower.ffxi.get_mob_by_target('me')
	local zone_id = windower.ffxi.get_info().zone
	local zone_name = res.zones[zone_id].name
	
	if id == 0x05B or id == 0x05C then
		if busy == true and portnow == true and isBuffActive(BUFFS.ELVORSEAL) then
			local boss_config = getCurrentBoss()
			local warp_coords = {}
			
			-- Set coordinates based on current boss
			if current_boss == "QUETZ" then
				warp_coords = {
					["X"] = 640,
					["Z"] = -372.00003051758,
					["Y"] = -921.00006103516,
					["_unknown3"] = 24321,
				}
			elseif current_boss == "AZI" then
				warp_coords = {
					["X"] = -27.000001907349,
					["Z"] = 0,
					["Y"] = 34.5,
					["_unknown3"] = 1,
				}
			elseif current_boss == "NAGA" then
				warp_coords = {
					["X"] = 0,
					["Z"] = -43.600002288818,
					["Y"] = -238.00001525879,
					["_unknown3"] = 48897,
				}
			end
			
			local port = packets.new('outgoing', 0x05C, {
				["X"] = warp_coords["X"],
				["Z"] = warp_coords["Z"],
				["Y"] = warp_coords["Y"],
				["Target ID"] = npc.id,
				["_unknown1"] = 12,
				["Zone"] = zone_id,
				["Menu ID"] = 9701,
				["Target Index"] = npc.index,
				["_unknown3"] = warp_coords["_unknown3"],
			})
			packets.inject(port)
			busy = false
			portnow = false
			local packet = packets.new('outgoing', 0x016, {
				["Target Index"]=me.index,
			})
			packets.inject(packet)
			delay = 10
		end
	end
end)

-- Packet handling for incoming chunks
windower.register_event('incoming chunk',function(id,data,modified,injected,blocked)
	local player = windower.ffxi.get_player()
	local me = windower.ffxi.get_mob_by_target('me')
	local zone_id = windower.ffxi.get_info().zone
	local zone_name = res.zones[zone_id].name
	
	if id == 0x034 or id == 0x032 then
		if busy == true then
			local parse = packets.parse('incoming', data)
			local npc_id = parse['NPC']
			local boss_config = getCurrentBoss()
			
			if tp and npc_id == tp.id then
				-- Handle portal entry
				local menu_id = 0
				if current_boss == "QUETZ" then
					if zone_name == 'La Theine Plateau' then
						menu_id = 222
					elseif zone_name == 'Konschtat Highlands' or zone_name == 'Tahrongi Canyon' then
						menu_id = 926
					end
					
					local port = packets.new('outgoing', 0x05B, {
						["Target"] = tp.id,
						["Option Index"] = 0,
						["_unknown1"] = 0,
						["Target Index"] = tp.index,
						["Automated Message"] = true,
						["_unknown2"] = 0,
						["Zone"] = zone_id,
						["Menu ID"] = menu_id
					})
					packets.inject(port)
					
					local port = packets.new('outgoing', 0x05B, {
						["Target"] = tp.id,
						["Option Index"] = 2,
						["_unknown1"] = 0,
						["Target Index"] = tp.index,
						["Automated Message"] = false,
						["_unknown2"] = 0,
						["Zone"] = zone_id,
						["Menu ID"] = menu_id
					})
					packets.inject(port)
				else
					-- Azi and Naga use different menu IDs
					menu_id = (current_boss == "AZI") and 65 or 14
					
					local port = packets.new('outgoing', 0x05B, {
						["Target"] = tp.id,
						["Option Index"] = 0,
						["_unknown1"] = 0,
						["Target Index"] = tp.index,
						["Automated Message"] = true,
						["_unknown2"] = 0,
						["Zone"] = zone_id,
						["Menu ID"] = menu_id
					})
					packets.inject(port)
					
					local port = packets.new('outgoing', 0x05B, {
						["Target"] = tp.id,
						["Option Index"] = 1,
						["_unknown1"] = 0,
						["Target Index"] = tp.index,
						["Automated Message"] = false,
						["_unknown2"] = 0,
						["Zone"] = zone_id,
						["Menu ID"] = menu_id
					})
					packets.inject(port)
				end
				delay = 10
				busy = false
				
			elseif npc and npc_id == npc.id then
				-- Handle NPC interaction for elvorseal
				if not isBuffActive(BUFFS.ELVORSEAL) then
					local elvorseal = packets.new('outgoing', 0x05B, {
						["Target"] = npc.id,
						["Option Index"] = 10,
						["_unknown1"] = 0,
						["Target Index"] = npc.index,
						["Automated Message"] = true,
						["_unknown2"] = 0,
						["Zone"] = zone_id,
						["Menu ID"] = 9701
					})
					packets.inject(elvorseal)
				end
				
				local option_index = (current_boss == "QUETZ") and 0 or 11
				local elvorseal = packets.new('outgoing', 0x05B, {
					["Target"] = npc.id,
					["Option Index"] = option_index,
					["_unknown1"] = 16384,
					["Target Index"] = npc.index,
					["Automated Message"] = true,
					["_unknown2"] = 0,
					["Zone"] = zone_id,
					["Menu ID"] = 9701
				})
				
				packets.inject(elvorseal)
				portnow = true
			end
		end
	elseif id == 0x036 and not isBuffActive(BUFFS.ELVORSEAL) then
		local parse = packets.parse('incoming', data)
		local npc_id = parse['Actor']
		local message_id = parse['Message ID']
		if npc and npc_id == npc.id and message_id == 6407 then
			if current_boss == "QUETZ" then
				delay = 60
			elseif current_boss == "AZI" then
				windower.send_command('setkey escape down;wait 1;setkey escape up')
				delay = 300
			elseif current_boss == "NAGA" then
				delay = 300
			end
		end
	end
end)

-- Zone change handler
windower.register_event('zone change', function(new, old)
	local zone = res.zones[new].name
	local boss_config = getCurrentBoss()
	
	if zone == boss_config.target_zone then
		delay = 20
	elseif zone == "Qufim Island" or zone == "Misareaux Coast" then
		log('Don\'t forget to set your HP here!!!')
		delay = 15
		inside = false
		running = false
		fighting = false
		waiting = false
	elseif zone == 'La Theine Plateau' or zone == 'Konschtat Highlands' or zone == 'Tahrongi Canyon' then
		delay = 15
		inside = false
		running = false
		fighting = false
		waiting = false
	else
		delay = 15
	end
end)

-- Command handler
windower.register_event('addon command', function(...)
	local command = {...}
	if command[1] == 'stop' then
		pause = 'on'
		log('Stopping TripleFarm')
	elseif command[1] == 'start' then
		pause = 'off'
		log('Starting TripleFarm on ' .. getCurrentBoss().name)
	elseif command[1] == 'rotation' then
		if command[2] == 'on' then
			rotation_enabled = true
			log('Rotation enabled')
		elseif command[2] == 'off' then
			rotation_enabled = false
			log('Rotation disabled')
		else
			log('Usage: //tf rotation on|off')
		end
	elseif command[1] == 'boss' then
		if command[2] and BOSSES[string.upper(command[2])] then
			current_boss = string.upper(command[2])
			for i, boss_name in ipairs(rotation_order) do
				if boss_name == current_boss then
					current_boss_index = i
					break
				end
			end
			current_kills = 0
			boss_defeated = false
			findWaitPosition()
			log('Switched to: ' .. getCurrentBoss().name)
		else
			log('Available bosses: quetz, azi, naga')
		end
	elseif command[1] == 'kills' then
		if command[2] and tonumber(command[2]) then
			kills_per_boss = tonumber(command[2])
			log('Kills per boss set to: ' .. kills_per_boss)
		else
			log('Current kills per boss: ' .. kills_per_boss)
		end
	elseif command[1] == 'status' then
		local boss_config = getCurrentBoss()
		log('Current boss: ' .. boss_config.name)
		log('Kills: ' .. current_kills .. '/' .. kills_per_boss)
		log('Rotation: ' .. (rotation_enabled and 'enabled' or 'disabled'))
		log('State: ' .. (pause == 'on' and 'paused' or 'running'))
	elseif command[1] == 'next' then
		if rotation_enabled then
			log('Moving to next boss...')
			nextBoss()
		else
			log('Rotation is disabled')
		end
	else
		log('TripleFarm Commands:')
		log('//tf start - Start farming')
		log('//tf stop - Stop farming')
		log('//tf rotation on|off - Enable/disable rotation')
		log('//tf boss <quetz|azi|naga> - Switch to specific boss')
		log('//tf kills <number> - Set kills per boss before rotation')
		log('//tf status - Show current status')
		log('//tf next - Force move to next boss (if rotation enabled)')
	end
end) 