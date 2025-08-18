_addon.author = 'Ivaar|Relisaa - Enhanced by Palmer (Zodiarchy @ Asura)'
_addon.name = 'AutoCOR'
_addon.commands = {'cor'}
_addon.version = '3.0.0'

require('luau')
require('pack')
require('lists')
require('tables')
require('strings')
config = require('config')
ui = require('libs/sms_ui')

local default = {
    roll = L{'Corsair\'s Roll','Chaos Roll'},
    active = true,
    crooked_cards = 1,
    text = {text = {size=10}},
    autora = false,
    aoe = {['p1'] = true,['p2'] = true,['p3'] = true,['p4'] = true,['p5'] = true},
	delay = 4.2,
	top_left = {
		x = 100,
		y = 100,
	},
	ui_hidden = false,
	user_ui_scalar = 1,
}

local settings = config.load(default)
local user_scalars = T{
	images = {
		width     = 209,
		height    = 23,
		sidecar_w = 70,
		sidecar_h = 17,
	},
	texts = {
		size         = 13,
		stroke_width =  1,
		padding      =  1,
	},
	offsets = {
		texts     = {x =   6, y =   0},
		subtexts  = {x = 167, y =   0},
		header    = {x =   2, y = -14},
		on        = {x =  87, y = -11},
		slash     = {x = 102, y = -11},
		off       = {x = 106, y = -11},
		pause     = {x = 131, y = -11},
		paused    = {x = 129, y = -11},
		help      = {x = 172, y = -11},
		mj_hdr    = {x =  90, y =  -1},
		mj_label  = {x = 173, y =  -1},
		shutdown  = {x =   4, y =  -1},
		sidecar   = {x = 210, y =   0},
		sc_texts  = {x =   6, y =   0},
		modules   = {x = 213, y = -11},
		limit_hdr = {x =   3, y =  -1},
		limit     = {x =  46, y =  -1},
	},
}
local actions = false
local nexttime = os.clock()
local nextdraw = os.clock()
local del = 0
local buffs = {}
local finish_act = L{2,3,5}
local start_act = L{7,8,9,12}
local is_casting = false

local function use_JA(str,ta)
    windower.send_command(('input /ja "%s" %s'):format(str,ta))
    del = 1.2
end

local rolls = T{
    [98] = {id=98,buff=310,en="Fighter's Roll",lucky=5,unlucky=9,bonus="Double Attack Rate",job='War'},
    [99] = {id=99,buff=311,en="Monk's Roll",lucky=3,unlucky=7,bonus="Subtle Blow",job='Mnk'},
    [100] = {id=100,buff=312,en="Healer's Roll",lucky=3,unlucky=7,bonus="Cure Potency Received",job='Whm'},
    [101] = {id=101,buff=313,en="Wizard's Roll",lucky=5,unlucky=9,bonus="Magic Attack",job='Blm'},
    [102] = {id=102,buff=314,en="Warlock's Roll",lucky=4,unlucky=8,bonus="Magic Accuracy",job='Rdm'},
    [103] = {id=103,buff=315,en="Rogue's Roll",lucky=5,unlucky=9,bonus="Critical Hit Rate",job='Thf'},
    [104] = {id=104,buff=316,en="Gallant's Roll",lucky=3,unlucky=7,bonus="Defense",job='Pld'},
    [105] = {id=105,buff=317,en="Chaos Roll",lucky=4,unlucky=8,bonus="Attack",job='Drk'},
    [106] = {id=106,buff=318,en="Beast Roll",lucky=4,unlucky=8,bonus="Pet Attack",job='Bst'},
    [107] = {id=107,buff=319,en="Choral Roll",lucky=2,unlucky=6,bonus="Spell Interruption Rate",job='Brd'},
    [108] = {id=108,buff=320,en="Hunter's Roll",lucky=4,unlucky=8,bonus="Accuracy",job='Rng'},
    [109] = {id=109,buff=321,en="Samurai Roll",lucky=2,unlucky=6,bonus="Store TP",job='Sam'},
    [110] = {id=110,buff=322,en="Ninja Roll",lucky=4,unlucky=8,bonus="Evasion",job='Nin'},
    [111] = {id=111,buff=323,en="Drachen Roll",lucky=4,unlucky=7,bonus="Pet Accuracy",job='Drg'},
    [112] = {id=112,buff=324,en="Evoker's Roll",lucky=5,unlucky=9,bonus="Refresh",job='smn'},
    [113] = {id=113,buff=325,en="Magus's Roll",lucky=2,unlucky=6,bonus="Magic Defense",job='Blu'},
    [114] = {id=114,buff=326,en="Corsair's Roll",lucky=5,unlucky=9,bonus="Experience Points",job='Cor'},
    [115] = {id=115,buff=327,en="Puppet Roll",lucky=3,unlucky=8,bonus="Pet Magic Accuracy Attack",job='Pup'},
    [116] = {id=116,buff=328,en="Dancer's Roll",lucky=3,unlucky=7,bonus="Regen",job='Dnc'},
    [117] = {id=117,buff=329,en="Scholar's Roll",lucky=2,unlucky=6,bonus="Conserve MP",job='Sch'},
    [118] = {id=118,buff=330,en="Bolter's Roll",lucky=3,unlucky=9,bonus="Movement Speed"},
    [119] = {id=119,buff=331,en="Caster's Roll",lucky=2,unlucky=7,bonus="Fast Cast"},
    [120] = {id=120,buff=332,en="Courser's Roll",lucky=3,unlucky=9,bonus="Snapshot"},
    [121] = {id=121,buff=333,en="Blitzer's Roll",lucky=4,unlucky=9,bonus="Attack Delay"},
    [122] = {id=122,buff=334,en="Tactician's Roll",lucky=5,unlucky=8,bonus="Regain"},
    [302] = {id=302,buff=335,en="Allies' Roll",lucky=3,unlucky=10,bonus="Skillchain Damage"},
    [303] = {id=303,buff=336,en="Miser's Roll",lucky=5,unlucky=7,bonus="Save TP"},
    [304] = {id=304,buff=337,en="Companion's Roll",lucky=2,unlucky=10,bonus="Pet Regain and Regen"},
    [305] = {id=305,buff=338,en="Avenger's Roll",lucky=4,unlucky=8,bonus="Counter Rate"},
    [390] = {id=390,buff=339,en="Naturalist's Roll",lucky=3,unlucky=7,bonus="Enhancing Magic Duration",job='Geo'},
    [391] = {id=391,buff=600,en="Runeist's Roll",lucky=4,unlucky=8,bonus="Magic Evasion",job='Run'},
}

local party_slots = L{'p1','p2','p3','p4','p5'}
local roll_aoe = 8
local random_delay = 2
local use_quick_draw = 0
local quick_delay = 30
local quick_draw_shot = "Light Shot"
local use_random_deal = 0
local incoming_chunk = nil
local outgoing_chunk = nil
local user_events = nil

do
    local equippable_bags = {'Inventory','Wardrobe','Wardrobe2','Wardrobe3','Wardrobe4'}

    for _, bag in ipairs(equippable_bags) do
        local items = windower.ffxi.get_items(bag)
        if items.enabled then
            for i,v in ipairs(items) do
                if v.id == 15810 then
                    roll_aoe = 16
                end
            end
        end
    end
end

local function addon_message(str)
    windower.add_to_chat(207, _addon.name..': '..str)
end

local function calculate_buffs(curbuffs)
    local buffs = {}
    for i,v in pairs(curbuffs) do
        if res.buffs[v] and res.buffs[v].english then
            buffs[res.buffs[v].english:lower()] = (buffs[res.buffs[v].english:lower()] or 0) + 1
        end
    end
    return buffs
end

local function is_valid_target(target, distance)
    return target.hpp > 0 and target.distance:sqrt() < distance and (target.is_npc or not target.charmed)
end

local function aoe_range()
    for slot in party_slots:it() do
        local member = windower.ffxi.get_mob_by_target(slot)

        if member and settings.aoe[slot] and not is_valid_target(member, roll_aoe) then
            return false
        end
    end
    return true
end

local function get_party_member_slot(name)
    for slot in party_slots:it() do
        local member = windower.ffxi.get_mob_by_target(slot)

        if member and member.name:lower() == name then
            return slot
        end
    end
end

local function update_ui()
    -- Update main toggle button
    ui.button_active('autocor_toggle', actions)
    ui.set_text('autocor_toggle', actions and 'AutoCOR ON' or 'AutoCOR OFF')
    
    -- Update roll buttons
    ui.set_text('roll1', 'Roll 1: ' .. settings.roll[1])
    ui.set_text('roll2', 'Roll 2: ' .. settings.roll[2])
    
    -- Update roll status displays with SmartSkillup-style formatting
    local roll1 = rolls:with('en', settings.roll[1])
    local roll2 = rolls:with('en', settings.roll[2])
    
    -- Always show roll1 status with lucky/unlucky values
    if roll1 then
        local status = roll1.en .. ': ' .. (buffs[roll1.buff] or 'Not Active') .. ' | ' .. roll1.lucky .. '/' .. roll1.unlucky
        if buffs[roll1.buff] and buffs[roll1.buff] == roll1.lucky then
            status = status .. ' (LUCKY!)'
        elseif buffs[roll1.buff] and buffs[roll1.buff] == roll1.unlucky then
            status = status .. ' (UNLUCKY!)'
        end
        ui.set_status_text('roll1_status', status)
    else
        ui.set_status_text('roll1_status', 'Roll 1: Not Set')
    end
    
    -- Always show roll2 status with lucky/unlucky values
    if roll2 then
        local status = roll2.en .. ': ' .. (buffs[roll2.buff] or 'Not Active') .. ' | ' .. roll2.lucky .. '/' .. roll2.unlucky
        if buffs[roll2.buff] and buffs[roll2.buff] == roll2.lucky then
            status = status .. ' (LUCKY!)'
        elseif buffs[roll2.buff] and buffs[roll2.buff] == roll2.unlucky then
            status = status .. ' (UNLUCKY!)'
        end
        ui.set_status_text('roll2_status', status)
    else
        ui.set_status_text('roll2_status', 'Roll 2: Not Set')
    end
    
    -- Update Crooked Cards button
    ui.button_active('crooked_cards', settings.crooked_cards > 0)
    ui.set_text('crooked_cards', 'Crooked Cards: ' .. (settings.crooked_cards > 0 and 'ON' or 'OFF'))
    
    -- Update Quick Draw button
    ui.button_active('quick_draw', use_quick_draw > 0)
    ui.set_text('quick_draw', 'Auto QD: ' .. (use_quick_draw > 0 and 'ON' or 'OFF'))
    
    -- Update Random Deal button
    ui.button_active('random_deal', use_random_deal > 0)
    ui.set_text('random_deal', 'Auto RD: ' .. (use_random_deal > 0 and 'ON' or 'OFF'))
    
    -- Update party AoE status
    local active_count = 0
    for slot in party_slots:it() do
        if settings.aoe[slot] then
            active_count = active_count + 1
        end
    end
    
    if active_count == 5 then
        ui.set_status_text('party_status', 'Party AoE: All Active')
    else
        ui.set_status_text('party_status', 'Party AoE: ' .. active_count .. '/5 Active')
    end
    
    -- Update party indicator text buttons
    for slot in party_slots:it() do
        local is_active = settings.aoe[slot]
        local color = is_active and 'green' or 'red'
        ui.set_party_text_color(slot, color)
    end
end

local last_coords = ('fff'):pack(0,0,0)
local is_moving = false

local function check_outgoing_chunk(id,data,modified,is_injected,is_blocked)
    if id == 0x015 then
        is_moving = last_coords ~= modified:sub(5, 16)
        last_coords = modified:sub(5, 16)
    end
end

local function prerender()
    if not actions then return end
    local curtime = os.clock()
	
    if nexttime + del <= curtime then
		del = settings.delay
		nexttime = curtime
        local play = windower.ffxi.get_player()
		
		local isCor = play and (play.main_job == 'COR' or play.sub_job == 'COR')
        if not play or not isCor or play.status > 1 then return end	
		
		local pbuffs = calculate_buffs(play.buffs)
		
        if is_casting or pbuffs.stun or pbuffs.sleep or pbuffs.charm or pbuffs.terror or pbuffs.petrification then return end

        local abil_recasts = windower.ffxi.get_ability_recasts()
		
        if buffs[16] or not aoe_range() then return end
        if buffs[309] then
            if abil_recasts[198] and abil_recasts[198] == 0 then
                use_JA("Fold", '<me>')
            end
            return
        end
			
        for x = 1,2 do
			if (settings.roll[x] ~= 'none') then
				local roll = rolls:with('en',settings.roll[x])
				if not buffs[roll.buff] then
					if abil_recasts[193] == 0 then
						if x == settings.crooked_cards and abil_recasts[96] and abil_recasts[96] == 0 then
							use_JA("Crooked Cards", '<me>')
						else
							use_JA(('%s'):format(roll.en), '<me>')
						end
					end
					return
				elseif buffs[308] and buffs[308] == roll.id and buffs[roll.buff] ~= roll.lucky and buffs[roll.buff] ~= 11 then
					if abil_recasts[197] and abil_recasts[197] == 0 and not buffs[357] and L{roll.lucky-1,10,roll.unlucky > 6 and roll.unlucky}:contains(buffs[roll.buff]) then
						use_JA("Snake Eye", '<me>')
					elseif abil_recasts[194] and abil_recasts[194] == 0 and (buffs[357] or buffs[roll.buff] < 5) then
						use_JA("Double-Up", '<me>')
					end
					return
				end
			end
        end
    end
	
	if nextdraw + random_delay <= curtime then
	    local play = windower.ffxi.get_player()
		
		local isCor = play and (play.main_job == 'COR' or play.sub_job == 'COR')
        if not play or not isCor or play.status > 1 then return end	
		
		local pbuffs = calculate_buffs(play.buffs)
		
		if is_casting or pbuffs.stun or pbuffs.sleep or pbuffs.charm or pbuffs.terror or pbuffs.petrification then return end
		
		local abil_recasts = windower.ffxi.get_ability_recasts()
		
		local quick1 = abil_recasts[195] and abil_recasts[195] == 0;
		local quick2 = abil_recasts[199] and abil_recasts[199] == 0;
		
		if quick1 and quick2 and use_quick_draw >= 1 then
			nextdraw = curtime + quick_delay
			use_JA(quick_draw_shot, "<bt>")
		elseif abil_recasts[196] and abil_recasts[196] == 0 and use_random_deal >= 1 then
			nextdraw = curtime
			use_JA("Random Deal", "<me>")
		end
	end
end

local function addon_command(...)
    local commands = {...}
    commands[1] = commands[1] and commands[1]:lower()
    if not commands[1] then
        actions = not actions
    elseif commands[1] == 'on' then
        actions = true
    elseif commands[1] == 'off' then
        actions = false
    elseif commands[1] == 'toggle' then
        actions = not actions
    elseif commands[1] == 'cc' then
        if commands[2] == 'off' then
            settings.crooked_cards = 0
        elseif commands[2] == 'toggle' then
            -- Toggle crooked cards on/off
            settings.crooked_cards = settings.crooked_cards > 0 and 0 or 1
        elseif commands[2] and tonumber(commands[2]) >= 2 then
            settings.crooked_cards = tonumber(commands[2])
        else
            -- Default toggle behavior
            settings.crooked_cards = settings.crooked_cards > 0 and 0 or 1
        end
    elseif commands[1] == 'roll' then
        commands[2] = commands[2] and tonumber(commands[2])
        if commands[2] and commands[3] then
			if (commands[3] == 'none') then
				settings.roll[commands[2]] = commands[3]
				addon_message("roll set to none")
				update_ui()
				return
			end
            commands[3] = windower.convert_auto_trans(commands[3])
            for x = 3,#commands do commands[x] = commands[x]:ucfirst() end
            commands[3] = table.concat(commands, ' ',3)
            local roll = rolls:with('job',commands[3]) or rolls:with('en',commands[3])
            if roll and not settings.roll:find(roll.en) then
                settings.roll[commands[2]] = roll.en
                addon_message(roll.en)
            else
                for k,v in pairs(rolls) do
                    if v and not settings.roll:find(v.en) and v.en:startswith(commands[3]) then
                        settings.roll[commands[2]] = v.en
                        addon_message(v.en)
                    end
                end
            end
        end
	elseif commands[1] == "autorandom" then
		if use_random_deal >= 1 then
			use_random_deal = 0
			windower.add_to_chat(207, 'Auto random deal off')
		else
			use_random_deal = 1
			windower.add_to_chat(207, 'Auto random deal on')
		end
	elseif commands[1] == "autodraw" then
		if use_quick_draw >= 1 then
			use_quick_draw = 0
			windower.add_to_chat(207, 'Auto quick draw off')
		else
			use_quick_draw = 1
			windower.add_to_chat(207, 'Auto quick draw on')
		end
	elseif commands[1] == "draw" then
		-- todo add in check to verify it is a valid quick draw shot type
		quick_draw_shot = commands[2]
    elseif commands[1] == 'aoe' and commands[2] then
        local slot = tonumber(commands[2], 6, 0) or commands[2]:match('[1-5]')
        slot = slot and 'p' .. slot or get_party_member_slot(commands[2])

        if not slot then
            return
        elseif not commands[3] then
            settings.aoe[slot] = not settings.aoe[slot]
        elseif commands[3] == 'on' then
            settings.aoe[slot] = true
        elseif commands[3] == 'off' then
            settings.aoe[slot] = false
        end

        if settings.aoe[slot] then
            windower.add_to_chat(207, ('Will now ensure <%s> is in AoE range.'):format(slot))
        else
            windower.add_to_chat(207, ('Ignoring slot <%s>'):format(slot))
        end
    elseif commands[1] == 'save' then
        settings:save()
        windower.add_to_chat(207, 'Settings saved.')
    	elseif commands[1] == 'hide' then
		settings.ui_hidden = not settings.ui_hidden
		if settings.ui_hidden then
			ui.hidden(true)
			windower.add_to_chat(207, 'AutoCOR UI hidden. Use //cor hide to show again.')
		else
			ui.hidden(false)
			windower.add_to_chat(207, 'AutoCOR UI shown.')
		end
	elseif commands[1] == 'reset' then
		-- Reset UI position to original coordinates
		settings.top_left.x = 100
		settings.top_left.y = 100
		settings.ui_hidden = false
		
		-- Rebuild UI at new position
		ui.destroy_all()
		ui.initialize(settings, user_scalars)
		update_ui()
		
		windower.add_to_chat(207, 'AutoCOR UI reset to original position (100, 100).')
    elseif commands[1] == 'eval' then
        assert(loadstring(table.concat(commands, ' ',2)))()
    else
        -- create help text
    end
    update_ui()
end

local function check_incoming_chunk(id,data,modified,is_injected,is_blocked)
    if id == 0x028 then
        if data:unpack('I', 6) ~= windower.ffxi.get_mob_by_target('me').id then return false end
        local category, param = data:unpack( 'b4b16', 11, 3)
        local recast, targ_id = data:unpack('b32b32', 15, 7)
        local effect, message = data:unpack('b17b10', 27, 6)
        if category == 6 then                       -- Use Job Ability
            if message == 420 then                  -- Phantom Roll
                buffs[rolls[param].buff] = effect
                buffs[308] = param
            elseif message == 424 then              -- Double-Up
                buffs[rolls[param].buff] = effect
            elseif message == 426 then              -- Bust
                buffs[rolls[param].buff] = nil
                buffs[309] = param
            end
        elseif category == 4 then                   -- Finish Casting
            del = settings.delay
            is_casting = false
        elseif finish_act:contains(category) then   -- Finish Range/WS/Item Use
            is_casting = false
        elseif start_act:contains(category) then
            del = category == 7 and recast or 1
            if param == 24931 then                  -- Begin Casting/WS/Item/Range
                is_casting = true
            elseif param == 28787 then              -- Failed Casting/WS/Item/Range
                is_casting = false
            end
        end
    elseif id == 0x63 and data:byte(5) == 9 then
        local set_buff = {}
        for n=1,32 do
            local buff = data:unpack('H', n*2+7)
            if buff == 255 then break end
            if (buff >= 308 and buff <= 339) or (buff == 600) then
                set_buff[buff] = buffs[buff] and buffs[buff] or 11
            else
                set_buff[buff] = (set_buff[buff] or 0) + 1
            end
        end
        buffs = set_buff
        update_ui()
    end
end

local function reset()
    actions = false
    is_casting = false
    buffs = {}
end

local function status_change(new,old)
    --is_casting = false
    if new > 1 and new < 4 then
        reset()
    end
end

local function load_chunk_event()
    incoming_chunk = windower.register_event('incoming chunk', check_incoming_chunk)
    outgoing_chunk = windower.register_event('outgoing chunk', check_outgoing_chunk)
end

local function unload_chunk_event()
	if incoming_chunk then
		windower.unregister_event(incoming_chunk)
    end
	
	if outgoing_chunk then
		windower.unregister_event(outgoing_chunk)
	end
end

local function unloaded()
    if user_events then
        reset()
        for _,event in pairs(user_events) do
            windower.unregister_event(event)
        end
        ui.destroy_all()
        user_events = nil
        coroutine.schedule(unload_chunk_event,0.1)
    end
end

local function loaded()
    print('AutoCOR: loaded() function called')
    if not user_events then
        print('AutoCOR: Creating user events...')
        user_events = {}
        user_events.prerender = windower.register_event('prerender', prerender)
        user_events.zone_change = windower.register_event('zone change', reset)
        user_events.status_change = windower.register_event('status change', status_change)
        print('AutoCOR: About to call ui.initialize...')
        ui.set_settings(settings)
    ui.initialize(settings, user_scalars)
        print('AutoCOR: ui.initialize completed, calling update_ui...')
        update_ui()
        print('AutoCOR: update_ui completed, scheduling load_chunk_event...')
        coroutine.schedule(load_chunk_event,0.1)
        print('AutoCOR: loaded() function completed')
    else
        print('AutoCOR: loaded() called but user_events already exists')
    end
end

local function check_job()
    local play = windower.ffxi.get_player()
	local isCor = play and (play.main_job == 'COR' or play.sub_job == 'COR')
    print('AutoCOR: check_job called - Player job: ' .. (play and play.main_job or 'none') .. '/' .. (play and play.sub_job or 'none') .. ', isCor: ' .. tostring(isCor))
    if isCor then
        loaded()
    else
        unloaded()
    end
end

windower.register_event('addon command', addon_command)
windower.register_event('job change','login','load', check_job)
windower.register_event('logout', unloaded)
