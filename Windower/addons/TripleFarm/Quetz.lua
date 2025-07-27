_addon.author   = 'Kaotic, rewritten by Otamarai'
_addon.version  = '2.05'
_addon.commands = {'Quetz'}

require 'logger'
require 'strings'
require('coroutine')
packets = require('packets')
res = require('resources')

--Defaults
nexttime = os.clock()
delay = 0
busy = false
inside = false
running = false
fighting = false
waiting = false
tp = false
gob = false
pause = 'on'
quetz_x = 612.17
quetz_y = -933.43
exitmenu = false
teleport_ring = "Dim. Ring (Holla)"		--Set your teleport ring here

--Set your trusts here, and under trustx_short put the name as it appears in the party list or when they speak in party chat
trust1 = 'Cherukiki'
trust1_short = 'Cheru'
trust2 = 'Mayakov'
trust2_short = 'Mayakov'
trust3 = 'Koru-Moru'
trust3_short = 'Koru'
trust4 = 'Lilisette II'
trust4_short = 'Lilisette'
trust5 = 'Nashmeira II'
trust5_short = 'Nashmeira'

windower.register_event('prerender', function()
	local curtime = os.clock()
	if nexttime + delay <= curtime then
		nexttime = curtime
		delay = 0.2
		local player = windower.ffxi.get_player()
		local me = windower.ffxi.get_mob_by_target('me')
		local info = windower.ffxi.get_info()
		local zone = res.zones[info.zone].name
		
		if pause == 'on' then return end
		
		if zone == 'La Theine Plateau' or zone == 'Konschtat Highlands' or zone == 'Tahrongi Canyon' then	--If we're in the areas with the crags, enter reisen
			enterReisen()
		elseif zone == 'Reisenjima' then	--If we're in reisen, check if we're inside already
			gob = windower.ffxi.get_mob_by_name('Shiftrix')
			if me and me.y < -400 and me.y > -550 then		--Check coordinates to see if we're inside since goblin distance is fucky when using warp packets
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
		elseif zone ~= 'Reisenjima' and zone ~= 'La Theine Plateau' and zone ~= 'Konschtat Highlands' and zone ~= 'Tahrongi Canyon' then	--If we were sent to our home point for any reason, just warp our ass back out there
			if getEquippedItem('right_ring') ~= teleport_ring then
				windower.send_command('wait 3;input /equip ring2 "'..teleport_ring..'"')
			else
				windower.send_command('wait 3;input /item "'..teleport_ring..'" <me>')
			end
			delay = 15
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

function enterReisen()			--Take the Dimensional Portal
	local me = windower.ffxi.get_mob_by_target('me')
	tp = windower.ffxi.get_mob_by_name('Dimensional Portal')
	if tp and math.sqrt(tp.distance) > 3 and not running then
		log('Entering Reisenjima')
		windower.ffxi.run(tp.x - me.x, tp.y - me.y)
		running = true
	elseif tp and math.sqrt(tp.distance) <= 3 then
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
	gob = windower.ffxi.get_mob_by_name('Shiftrix')
    if gob then
        local p = packets.new('outgoing', 0x01A, {
            ['Target'] = gob.id,
            ['Target Index'] = gob.index,
        })
		busy = true
		packets.inject(p)
    end
	windower.send_command('setkey escape down;wait 0.5;setkey escape up')	--sometimes the menu gets stuck open when getting elvorseal, this hits escape to fix it
	delay = 5
end

function moveToLocation()
	local me = windower.ffxi.get_mob_by_target('me')
	if isBuffActive(603) then
		windower.send_command('setkey escape down;wait 1;setkey escape up')							--To escape out of the menu with shiftrix
		if math.abs(quetz_x - me.x) > 2 and math.abs(quetz_y - me.y) > 2 and not waiting then		--Run to location
			windower.ffxi.run(quetz_x - me.x, quetz_y - me.y)
		elseif math.abs(quetz_x - me.x) <= 2 and math.abs(quetz_y - me.y) <= 2 and not waiting then		--We're here, so stop
			windower.ffxi.run(false)
			waiting = true
			delay = 3
		end
	else
		fight()
	end
end

function fight()
	local quetz = windower.ffxi.get_mob_by_name('Quetzalcoatl')
	local player = windower.ffxi.get_player()
	local party = windower.ffxi.get_party()
	local partymembers = party.p5 or false
	if isBuffActive(603) then	
		if quetz.hpp > 0 then
			fighting = true
		else
			fighting = false
		end
		if waiting and player.status == 0 then										--Summon trusts while waiting
			if summonTrust() ~= false and not isBuffActive(6) and not isBuffActive(2) then
				windower.send_command('input /ma "'..summonTrust()..'" <me>')
			end
			delay = 3
		end

		if player.status == 0 and isBuffActive(603) and fighting then			--If not engaged then engage
			engagequetz = packets.new('outgoing', 0x01A, {
				['Target'] = quetz.id,
				['Target Index'] = quetz.index,
				['Category'] = 0x02,
			})
			packets.inject(engagequetz)
			delay = 1
		elseif math.sqrt(quetz.distance) > 7 and player.status == 1 and fighting then		--Turn and run to quetz
			local target = windower.ffxi.get_mob_by_index(player.target_index or 0)
			local self_vector = windower.ffxi.get_mob_by_index(player.index or 0)
			local angle = (math.atan2((target.y - self_vector.y), (target.x - self_vector.x))*180/math.pi)*-1
			windower.ffxi.turn((angle):radian())
			windower.ffxi.run(true)
		elseif math.sqrt(quetz.distance) <= 7 and player.status == 1 and fighting and not partymembers then		--Summon trusts when they die
			windower.ffxi.run(false)
			if summonTrust() ~= false and not isBuffActive(6) and not isBuffActive(2) then
				windower.send_command('input /ma "'..summonTrust()..'" <me>')
			end
			delay = 3
		end
	elseif not isBuffActive(603) and not isBuffActive(2) then			--If our elvorseal is gone, try to take a raise if we're dead, or release if we don't have one. teleport ring out
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
	if id == 0x05B then
		if busy == true and portnow == true and isBuffActive(603) then		--Warp to the arena
			local port = packets.new('outgoing', 0x05C, {
				["X"] = 640,
				["Z"] = -372.00003051758,
				["Y"] = -921.00006103516,
				["Target ID"] = gob.id,
				["_unknown1"] = 12,
				["Zone"] = zone_id,
				["Menu ID"] = 9701,
				["Target Index"] = gob.index,
				["_unknown3"] = 24321,
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
	local zone_name = res.zones[zone_id].name
	local menu_id = 0
	if id == 0x034 or id == 0x032 then
		if busy == true then
			local parse = packets.parse('incoming', data)
			local npc_id = parse['NPC']
			if tp and npc_id == tp.id then		--Dimensional Portal
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
				delay = 10
				busy = false
			elseif gob and npc_id == gob.id then	--Shiftrix
				if not isBuffActive(603) then
					local elvorseal = packets.new('outgoing', 0x05B, {
						["Target"] = gob.id,
						["Option Index"] = 10,
						["_unknown1"] = 0,
						["Target Index"] = gob.index,
						["Automated Message"] = true,
						["_unknown2"] = 0,
						["Zone"] = zone_id,
						["Menu ID"] = 9701
					})
					packets.inject(elvorseal)
				end
				local elvorseal = packets.new('outgoing', 0x05B, {
					["Target"] = gob.id,
					["Option Index"] = 0,
					["_unknown1"] = 16384,
					["Target Index"] = gob.index,
					["Automated Message"] = true,
					["_unknown2"] = 0,
					["Zone"] = zone_id,
					["Menu ID"] = 9701
				})
				
				packets.inject(elvorseal)
				portnow = true
			end
		end
	elseif id == 0x036 and not isBuffActive(603) then
		local parse = packets.parse('incoming', data)
		local npc_id = parse['Actor']
		local message_id = parse['Message ID']
		if npc_id == gob.id and message_id == 6407 then
			delay = 60
		end
	end
end)

--Zone change timers
windower.register_event('zone change', function(new, old)
	local zone = res.zones[new].name
	if zone == 'Reisenjima' then
		delay = 20
	elseif zone == 'La Theine Plateau' or zone == 'Konschtat Highlands' or zone == 'Tahrongi Canyon' then
		delay = 15
		inside = false
		running = false
		fighting = false
		waiting = false
		exitmenu = false
	else
		delay = 15
	end
end)

windower.register_event('addon command', function(...)
    local command = {...}
	if command[1] == 'stop' then
		pause = 'on'
		log('Stopping Quetz')
    elseif command[1] == 'start' then
		pause = 'off'
		log('Starting Quetz')
	end
end)