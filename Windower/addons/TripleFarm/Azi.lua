_addon.author   = 'Erupt'
_addon.version  = '2.05'
_addon.commands = {'Azi'}

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

--Defaults
nexttime = os.clock()
delay = 0
busy = false
inside = false
running = false
fighting = false
waiting = false
tp = false
affi = false
pause = 'on'
azi_x = -11.00
azi_y = 37.50
teleport_ring = "Warp Ring"		--Set your teleport ring here

--[[
	This script is a little different from the Quetz script.  You will need to set your home point
	in Qufim Island in order for this to work.  This acts as the Dimentional Teleport ring here.
]]

--Set your trusts here, and under trustx_short put the name as it appears in the party list or when they speak in party chat
trust1 = 'Matsui-P'
trust1_short = 'Matsui-P'
trust2 = 'Koru-Moru'
trust2_short = 'Koru'
trust3 = 'Prishe II'
trust3_short = 'Prishe'
trust4 = 'Lilisette II'
trust4_short = 'Lilisette'
trust5 = 'Nashmeira II'
trust5_short = 'Nashmeira'

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

windower.register_event('prerender', function()
	local curtime = os.clock()
	local waste = math.random()
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
		
		if zone == 'Qufim Island' then	--If we're in the areas with the crags, enter escha
			enterRuaun()
		elseif zone == 'Escha - Zi\'Tah' then	--If we're in escha, check if we're inside the arena already
			affi = safeGetMob('Affi')
			if me and me.x < -100 then		--Check coordinates to see if we're inside since distance is fucky when using warp packets
				inside = false
			else
				inside = true
			end
			if not inside then								--If not inside, enter the arena
				enterArena()
			elseif inside then
				if player.status == 1 or player.in_combat then		--If we're in combat, engage and fight it
					waiting = true
					fight()
				elseif not waiting then										--Move into position when inside the arena and get ready to fight
					windower.send_command('setkey escape down;wait 1;setkey escape up')
					moveToLocation()
				elseif waiting then
					fight()
				end
			end
		end
	end
end)

function getEquippedItem(slot_name)
	local inventory = windower.ffxi.get_items()
	local equipment = inventory['equipment'];
	local item_id = windower.ffxi.get_items(equipment[string.format('%s_bag', slot_name)], equipment[slot_name]).id
	return res.items:with('id', item_id).en
end

function summonTrust()		--Return the name of your trusts that may have died/aren't in your party currently
	local party = windower.ffxi.get_party()
	if party.p5 then 
		return false  -- Party is full, don't summon more trusts
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

function isBuffActive(id)
	local self = windower.ffxi.get_player()
	for k,v in pairs( self.buffs ) do
		if (v == id) then -- check for buff
			return true
		end	
	end
	return false
end

function enterRuaun()			--Take the Undulating Confluence
	local me = windower.ffxi.get_mob_by_target('me')
	tp = safeGetMob('Undulating Confluence')
	if tp and math.sqrt(tp.distance) > DISTANCES.INTERACTION and not running then
		log('Entering Escha - Zi\'Tah')
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

function enterArena()
	local me = windower.ffxi.get_mob_by_target('me')
	affi = safeGetMob('Affi')
	if affi and math.sqrt(affi.distance) > DISTANCES.CLOSE_INTERACTION and not running then		-- we need to run to affi
		log('Entering Escha - Zi\'Tah')
		windower.ffxi.run(affi.x - me.x, affi.y - me.y)
		running = true
	elseif affi and math.sqrt(affi.distance) <= DISTANCES.CLOSE_INTERACTION then
		windower.ffxi.run(false)
		running = false
        local p = packets.new('outgoing', 0x01A, {
            ['Target'] = affi.id,
            ['Target Index'] = affi.index,
        })
		busy = true
		packets.inject(p)
		
		windower.send_command('setkey escape down;wait 0.5;setkey escape up')	--sometimes the menu gets stuck open when getting elvorseal, this hits escape to fix it
		delay = 5
    end
end

function randomFloat(min, max)
    return min + math.random() * (max - min);
end

function findWaitPosition()
	wait_x = azi_x + math.random(0.10,1.5)
	wait_y = azi_y + math.random(0.10,1.5)
end

findWaitPosition()

function moveToLocation()
	local me = windower.ffxi.get_mob_by_target('me')
	if not me then
		log('Error: Cannot get player position')
		return
	end
	
	if isBuffActive(BUFFS.ELVORSEAL) then
		windower.send_command('setkey escape down;wait 1;setkey escape up')							--To escape out of the menu with affi
		if math.abs(wait_x - me.x) > 2 and math.abs(wait_y - me.y) > 2 and not waiting then		--Run to location
			windower.ffxi.run(wait_x - me.x, wait_y - me.y)
		elseif math.abs(wait_x - me.x) <= 2 and math.abs(wait_y - me.y) <= 2 and not waiting then		--We're here, so stop
			windower.ffxi.run(false)
			waiting = true
			delay = 3
			findWaitPosition()
		end
	else
		fight()
	end
end

function fight()
	local azi = safeGetMob('Azi Dahaka')
	local player = windower.ffxi.get_player()
	local party = windower.ffxi.get_party()
	local partymembers = party.p5 or false
	
	if not azi then
		log('Error: Cannot find Azi Dahaka')
		return
	end
	
	if isBuffActive(BUFFS.ELVORSEAL) then	
		if azi.hpp > 0 then
			fighting = true
		else
			fighting = false
		end
		if waiting and player.status == 0 then										--Summon trusts while waiting
			if summonTrust() ~= false and not isBuffActive(BUFFS.SILENCE) and not isBuffActive(BUFFS.SLEEP) then
				windower.send_command('input /ma "'..summonTrust()..'" <me>')
			end
			delay = 3
		end

		if player.status == 0 and isBuffActive(BUFFS.ELVORSEAL) and fighting then			--If not engaged then engage
			engagenaga = packets.new('outgoing', 0x01A, {
				['Target'] = azi.id,
				['Target Index'] = azi.index,
				['Category'] = 0x02,
			})
			packets.inject(engagenaga)
			delay = 1
		elseif math.sqrt(azi.distance) > DISTANCES.COMBAT and player.status == 1 and fighting then		--Turn and run to azi
			local target = windower.ffxi.get_mob_by_index(player.target_index or 0)
			local self_vector = windower.ffxi.get_mob_by_index(player.index or 0)
			local angle = (math.atan2((target.y - self_vector.y), (target.x - self_vector.x))*180/math.pi)*-1
			windower.ffxi.turn((angle):radian())
			windower.ffxi.run(true)
		elseif math.sqrt(azi.distance) <= DISTANCES.COMBAT and player.status == 1 and fighting and not partymembers then		--Summon trusts when they die
			windower.ffxi.run(false)
			if summonTrust() ~= false and not isBuffActive(BUFFS.SILENCE) and not isBuffActive(BUFFS.SLEEP) then
				windower.send_command('input /ma "'..summonTrust()..'" <me>')
			end
			delay = 3
		end
	elseif not isBuffActive(BUFFS.ELVORSEAL) and not isBuffActive(BUFFS.SLEEP) then			--If our elvorseal is gone, try to take a raise if we're dead, or release if we don't have one. teleport ring out
		windower.ffxi.run(false)
		if player.status > 1 then
			delay = 30
			windower.send_command('wait 10;setkey enter down;wait 1;setkey enter up;wait 3;setkey left down;wait 1;setkey left up;wait 3;setkey enter down;wait 1;setkey enter up')
		else
			if getEquippedItem('right_ring') ~= teleport_ring then
				windower.send_command('wait 3;input /equip ring2 "'..teleport_ring..'"')
			else
				windower.send_command('wait 3;input /item "'..teleport_ring..'" <me>')
			end
			delay = 30
		end
	end
end

windower.register_event('outgoing chunk',function(id,data,modified,injected,blocked)
	local player = windower.ffxi.get_player()
	local me = windower.ffxi.get_mob_by_target('me')
	local zone_id = windower.ffxi.get_info().zone
	local zone_name = res.zones[zone_id].name
	if id == 0x05B or id == 0x05C then
		if busy == true and portnow == true and isBuffActive(BUFFS.ELVORSEAL) then		--Warp to the arena
			local port = packets.new('outgoing', 0x05C, {
				["X"] = -27.000001907349,
				["Z"] = 0,
				["Y"] = 34.5,
				["Target ID"] = affi.id,
				["_unknown1"] = 12,
				["Zone"] = zone_id,
				["Menu ID"] = 9701,
				["Target Index"] = affi.index,
				["_unknown3"] = 1,
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

windower.register_event('incoming chunk',function(id,data,modified,injected,blocked)
	local player = windower.ffxi.get_player()
	local me = windower.ffxi.get_mob_by_target('me')
	local zone_id = windower.ffxi.get_info().zone
	local menu_id = 65
	if id == 0x034 or id == 0x032 then
		if busy == true then
			local parse = packets.parse('incoming', data)
			local npc_id = parse['NPC']
			if tp and npc_id == tp.id then		--Undulating Confluence
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
				delay = 10
				busy = false
			elseif affi and npc_id == affi.id then	--affi
				if not isBuffActive(BUFFS.ELVORSEAL) then
					local elvorseal = packets.new('outgoing', 0x05B, {
						["Target"] = affi.id,
						["Option Index"] = 10,
						["_unknown1"] = 0,
						["Target Index"] = affi.index,
						["Automated Message"] = true,
						["_unknown2"] = 0,
						["Zone"] = zone_id,
						["Menu ID"] = 9701
					})
					packets.inject(elvorseal)
				end
				local elvorseal = packets.new('outgoing', 0x05B, {
					["Target"] = affi.id,
					["Option Index"] = 11,
					["_unknown1"] = 16384,
					["Target Index"] = affi.index,
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
		if affi and npc_id == affi.id and message_id == 6407 then
			windower.send_command('setkey escape down;wait 1;setkey escape up')
			delay = 300
		end
	end
end)

--Zone change timers
windower.register_event('zone change', function(new, old)
	local zone = res.zones[new].name
	if zone == 'Escha - Zi\'Tah' then
		delay = 20
	elseif zone == 'Qufim Island' then
		log('Don\'t forget to set your HP here!!!')
		delay = 15
		inside = false
		running = false
		fighting = false
		waiting = false
	else
		delay = 15
	end
end)

windower.register_event('addon command', function(...)
    local command = {...}
	if command[1] == 'stop' then
		pause = 'on'
		log('Stopping Azi')
    elseif command[1] == 'start' then
		pause = 'off'
		log('Starting Azi')
	end
end)