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
	-- Advanced J-Roller settings
	engaged = false,       -- Only roll while engaged
	crooked2 = false,      -- Save Crooked Cards for roll 2 only
	randomdeal = true,     -- Use Random Deal
	oldrandomdeal = false, -- Use Random Deal for Snake/Fold vs Crooked
	partyalert = false,    -- Alert party before rolling
	gamble = false,        -- Aggressive mode: target 11 on roll 1, exploit bust immunity
	bustimmunity = true,   -- Exploit bust immunity (11 on roll 1) for aggressive roll 2
	safemode = false,      -- Ultra-conservative mode: only double up on rolls 1-5
	townmode = false,      -- Only roll when not in town/safe zones
	rollwithbust = true,   -- Allow Roll 2 even when busted
	smartsnakeeye = true,  -- Use Snake Eye for end-of-rotation optimization
	hasSnakeEye = true,    -- Snake Eye enabled
	hasFold = true,        -- Fold enabled
	-- Random Deal Priority (1 = highest priority)
	randomDealPriority = { 'Crooked Cards', 'Snake Eye', 'Fold' },
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

-- Advanced J-Roller state tracking
local lastRoll = 0
local rollCrooked = false
local roll1RollTime = 0
local roll2RollTime = 0
local mainjob = nil
local subjob = nil
local hasSnakeEye = false
local hasFold = false
local partyAlertSent = false
local partyAlertTime = 0
local bustWaitingMessageSent = false
local roll1CompleteTime = 0  -- Track when Roll 1 completed for Random Deal timing
local lastSnakeEyeTime = 0   -- Track when Snake Eye was last used to handle latency

local function addon_message(str)
    windower.add_to_chat(207, _addon.name..': '..str)
end

-- Check for buffs by name (from J-Roller)
local function hasBuff(matchBuff)
    local buffs = windower.ffxi.get_player().buffs
    if type(matchBuff) == 'string' then
        local matchText = string.lower(matchBuff)
        for _, buff in pairs(buffs) do
            local buffString = res.buffs[buff] and res.buffs[buff].english
            if buffString then
                buffString = string.lower(buffString)
                if buffString == matchText then
                    return true
                end
            end
        end
    elseif type(matchBuff) == 'number' then
        for _, buff in pairs(buffs) do
            if buff == matchBuff then
                return true
            end
        end
    end
    return false
end

-- Check for incapacitation status (from J-Roller)
local function isIncapacitated()
    return hasBuff(16)    -- Amnesia
        or hasBuff(261)   -- Impairment  
        or hasBuff(7)     -- Petrification
        or hasBuff(10)    -- Stun
        or hasBuff(0)     -- KO/Dead
        or hasBuff(14)    -- Charm
        or hasBuff(28)    -- Terror
        or hasBuff(2)     -- Sleep
end

-- Job info and merit ability detection (from J-Roller)
local function updateJobInfo()
    local player = windower.ffxi.get_player()
    if not player then return end
    
    mainjob = player.main_job_id
    subjob = player.sub_job_id
    
    -- Merit abilities are only available to main job COR (job id 17)
    if mainjob == 17 then
        -- Main job COR: use manual merit ability settings
        hasSnakeEye = settings.hasSnakeEye
        hasFold = settings.hasFold
    else
        -- Subjob COR: no merit abilities available
        hasSnakeEye = false
        hasFold = false
    end
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

local function use_JA(str,ta)
    windower.send_command(('input /ja "%s" %s'):format(str,ta))
    del = 1.2
end

-- Advanced shouldDoubleUp logic from J-Roller
local function shouldDoubleUp(rollNum, currentRoll)
    local abil_recasts = windower.ffxi.get_ability_recasts()
    local player = windower.ffxi.get_player()
    if not player then return false, "No player data" end
    
    local roll = rolls:with('en', currentRoll)
    if not roll then return false, "Invalid roll" end
    
    local luckyNum = roll.lucky
    local unluckyNum = roll.unlucky
    
    -- Safety check: ensure job info is set
    if not mainjob then
        addon_message("ERROR: mainjob not set! Please report this bug.")
        return false, "Job info not initialized (mainjob is nil)"
    end
    
    -- Sub-COR simplified strategy: double up if roll < 5
    if subjob == 17 and mainjob ~= 17 then
        if rollNum < 5 then
            return true, "Sub-COR: Roll < 5"
        end
        return false, "Sub-COR: Roll >= 5, stopping"
    end
    
    -- Safe mode: use subjob-like strategy even on main COR
    if settings.safemode then
        if rollNum < 5 then
            return true, "Safe Mode: Roll < 5"
        end
        return false, "Safe Mode: Roll >= 5, stopping"
    end
    
    -- Main COR advanced strategy (from J-Roller)
    if mainjob == 17 then
        -- Gamble mode: aggressive strategy targeting 11s
        if settings.gamble then
            -- If we have bust immunity (last roll was 11), be extremely aggressive
            if lastRoll == 11 then
                -- Bust immune - only stop for Snake Eye on 10 for guaranteed 11
                if hasSnakeEye and abil_recasts[197] and abil_recasts[197] == 0 and rollNum == 10 then
                    return false, "Gamble: Snake Eye for guaranteed 11 while immune"
                else
                    -- Otherwise, keep rolling until 11 (can't bust)
                    return true, "Gamble: Bust immune, rolling aggressively for 11"
                end
            else
                -- No bust immunity - still aggressive but use Snake Eye strategically
                if hasSnakeEye and abil_recasts[197] and abil_recasts[197] == 0 and rollNum == 10 then
                    return false, "Gamble: Snake Eye for guaranteed 11"
                else
                    -- Keep doubling up until 11 or bust - fold will handle the bust
                    return true, "Gamble: Rolling for 11, fold will handle bust"
                end
            end
        else
            -- Normal strategy - conservative approach
            
            -- PRIORITY 1: Use Snake Eye for 10 → 11 (highest priority)
            if hasSnakeEye and abil_recasts[197] and abil_recasts[197] == 0 and rollNum == 10 then
                return false, "Using Snake Eye for guaranteed 11 (highest priority)"
            end
            
            -- PRIORITY 2: Use Snake Eye for lucky-1 (second priority)
            if hasSnakeEye and abil_recasts[197] and abil_recasts[197] == 0 
               and rollNum == (luckyNum - 1) and rollCrooked then
                return false, "Using Snake Eye for lucky number (second priority)"
            end
            
            -- PRIORITY 3: Use Snake Eye for unlucky numbers (third priority)
            if hasSnakeEye and abil_recasts[197] and abil_recasts[197] == 0 and rollNum == unluckyNum then
                return false, "Using Snake Eye to avoid unlucky (third priority)"
            end
            
            -- Handle 8+ rolls differently
            if rollNum >= 8 then
                if rollNum == unluckyNum then
                    -- We're on an unlucky 8+ - try to Snake Eye off it
                    if hasSnakeEye and abil_recasts[197] and abil_recasts[197] == 0 then
                        return false, "Using Snake Eye to avoid unlucky " .. unluckyNum
                    else
                        -- No Snake Eye available - be more aggressive in gamble mode
                        if settings.gamble and (hasFold and abil_recasts[198] and abil_recasts[198] == 0) then
                            return true, "Gamble: Rolling off unlucky " .. unluckyNum .. " with Fold insurance"
                        else
                            return false, "Stopping: Unlucky " .. unluckyNum .. " without Snake Eye or Fold"
                        end
                    end
                else
                    -- Good 8+ roll - use Snake Eye if available for potential 9-11
                    if hasSnakeEye and abil_recasts[197] and abil_recasts[197] == 0 and settings.gamble then
                        return false, "Gamble: Using Snake Eye to push " .. rollNum .. " higher"
                    else
                        -- Keep the good 8+ roll
                        return false, "Stopping: " .. rollNum .. " is a good roll"
                    end
                end
            end
            
            -- Roll 7: Use fold as insurance to risk for 8+
            if rollNum == 7 then
                if hasFold and abil_recasts[198] and abil_recasts[198] == 0 then
                    return true, "Roll 7: Doubling up with Fold insurance for 8+"
                else
                    return false, "Stopping: Roll 7 without Fold insurance (hasFold=" .. tostring(hasFold) .. ", CD=" .. tostring(abil_recasts[198] or 0) .. ")"
                end
            end
            
            -- Roll 6: Very aggressive - lowest bust risk of any 6+ roll
            if rollNum == 6 then
                if settings.bustimmunity and lastRoll == 11 then
                    return true, "Roll 6: Bust immune, definitely continuing"
                elseif hasFold and abil_recasts[198] and abil_recasts[198] == 0 then
                    return true, "Roll 6: Low bust risk with Fold insurance"
                elseif hasSnakeEye then
                    return true, "Roll 6: Low bust risk, Snake Eye available for optimization"
                elseif settings.randomdeal and abil_recasts[196] and abil_recasts[196] == 0 then
                    return true, "Roll 6: Low bust risk with Random Deal backup"
                else
                    -- Even without safety nets, Roll 6 has good odds (6/11 safe outcomes)
                    return true, "Roll 6: Aggressive (good odds even without safety nets)"
                end
            end
            
            -- Always continue on rolls < 6
            if rollNum < 6 then
                return true, "Roll < 6, continuing"
            end
            
            -- Fallback
            return false, "Stopping: conditions not met"
        end
    end
    
    return false, "Unknown job configuration"
end

-- Advanced Snake Eye logic from J-Roller
local function executeSnakeEye(rollNum, currentRoll)
    local player = windower.ffxi.get_player()
    if not player then return false end
    
    -- Skip Snake Eye logic for sub-COR
    if (subjob == 17 and mainjob ~= 17) or not hasSnakeEye then
        return false
    end
    
    local abil_recasts = windower.ffxi.get_ability_recasts()
    local roll = rolls:with('en', currentRoll)
    if not roll then return false end
    
    local snakeEyesActive = hasBuff("Snake Eye")
    local luckyNum = roll.lucky
    local unluckyNum = roll.unlucky
    
    -- Check for latency gap: used Snake Eye recently but buff not up yet
    if os.clock() - lastSnakeEyeTime < 3 then
        -- We likely used Snake Eye and are waiting for buff or effect
        return true -- Wait
    end
    
    if snakeEyesActive then
        addon_message("Snake Eye buff detected, queueing Double-Up immediately")
        use_JA("Double-Up", '<me>')
        return true
    end
    
    -- Check if Snake Eye is available
    if abil_recasts[197] and abil_recasts[197] == 0 then
        -- Determine which roll we're currently working on
        local haveRoll1 = buffs[rolls:with('en', settings.roll[1]).buff]
        local workingOnRoll2 = haveRoll1 and currentRoll == settings.roll[2]
        
        -- PRIORITY 1: Gamble mode - aggressive Snake Eye usage for 11s
        if settings.gamble then
            -- With bust immunity (last roll was 11), be very aggressive
            if lastRoll == 11 then
                if rollNum == 10 or (rollNum == (luckyNum - 1) and rollCrooked) then
                    addon_message("Gamble + Bust Immune: Snake Eye for guaranteed benefit")
                    use_JA("Snake Eye", '<me>')
                    lastSnakeEyeTime = os.clock()
                    return true
                end
            else
                -- No bust immunity - still aggressive but strategic
                if rollNum == 10 then
                    addon_message("Gamble: Snake Eye 10→11 for bust immunity")
                    use_JA("Snake Eye", '<me>')
                    lastSnakeEyeTime = os.clock()
                    return true
                elseif rollNum == (luckyNum - 1) and rollCrooked then
                    addon_message("Gamble: Snake Eye for lucky number")
                    use_JA("Snake Eye", '<me>')
                    lastSnakeEyeTime = os.clock()
                    return true
                end
            end
        end
        
        -- PRIORITY 2: Standard Snake Eye usage (non-gamble)
        if not settings.gamble then
            if rollNum == 10 then
                addon_message("Standard: Snake Eye 10→11")
                use_JA("Snake Eye", '<me>')
                lastSnakeEyeTime = os.clock()
                return true
            elseif rollNum == (luckyNum - 1) and rollCrooked then
                addon_message("Standard: Snake Eye for lucky number")
                use_JA("Snake Eye", '<me>')
                lastSnakeEyeTime = os.clock()
                return true
            elseif rollNum == unluckyNum then
                addon_message("Standard: Snake Eye to avoid unlucky")
                use_JA("Snake Eye", '<me>')
                lastSnakeEyeTime = os.clock()
                return true
            end
        end
        
        -- PRIORITY 3: Smart end-rotation optimization (ONLY for Roll 2)
        if settings.smartsnakeeye and workingOnRoll2 then
            -- Check if we're unlikely to double-up further (end of rotation)
            local wouldDoubleUp = shouldDoubleUp(rollNum, currentRoll)
            
            if not wouldDoubleUp and rollNum >= 8 and rollNum < 10 then
                -- Calculate if Snake Eye will recharge before buffs expire
                local currentTime = os.time()
                local buffTimeRemaining = math.min(
                    (roll1RollTime + 300) - currentTime, -- Roll 1 expires in ~5 min
                    (roll2RollTime + 300) - currentTime  -- Roll 2 expires in ~5 min
                )
                
                -- Snake Eye recharges in 60 seconds, give 60s buffer for next rotation
                local snakeEyeWillBeReady = buffTimeRemaining > 120 -- 60s recharge + 60s buffer
                
                if snakeEyeWillBeReady and (rollNum + 1) ~= unluckyNum then
                    addon_message("Smart optimization (Roll 2): Snake Eye " .. rollNum .. "→" .. (rollNum + 1) .. " (will recharge in time)")
                    use_JA("Snake Eye", '<me>')
                    lastSnakeEyeTime = os.clock()
                    return true
                end
            end
        end
    end
    
    return false
end

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

local function try_random_deal()
    local abil_recasts = windower.ffxi.get_ability_recasts()
    if not (abil_recasts[196] and abil_recasts[196] == 0 and use_random_deal >= 1) then
        return false
    end

    -- J-Roller Random Deal logic: Check if any abilities are on cooldown that would benefit
    local should_use_random_deal = false
    local resetReasons = {}
    
    -- Check what abilities are on cooldown and would benefit from reset
    if settings.oldrandomdeal then
        -- Old mode: Only reset Snake Eye and Fold
        if hasSnakeEye and abil_recasts[197] and abil_recasts[197] > 0 then
            resetReasons[#resetReasons + 1] = "Snake Eye"
            should_use_random_deal = true
        end
        if hasFold and abil_recasts[198] and abil_recasts[198] > 0 then
            resetReasons[#resetReasons + 1] = "Fold"
            should_use_random_deal = true
        end
    else
        -- New mode: Reset Crooked Cards primarily, Snake Eye and Fold secondarily
        if abil_recasts[96] and abil_recasts[96] > 0 then
            resetReasons[#resetReasons + 1] = "Crooked Cards"
            should_use_random_deal = true
        end
        if hasSnakeEye and abil_recasts[197] and abil_recasts[197] > 0 then
            resetReasons[#resetReasons + 1] = "Snake Eye"
            should_use_random_deal = true
        end
        if hasFold and abil_recasts[198] and abil_recasts[198] > 0 then
            resetReasons[#resetReasons + 1] = "Fold"
            should_use_random_deal = true
        end
        -- Check Phantom Roll if it has significant cooldown remaining (>10s)
        if abil_recasts[193] and abil_recasts[193] > 10 then
            resetReasons[#resetReasons + 1] = "Phantom Roll"
            should_use_random_deal = true
        end
    end
    
    if should_use_random_deal then
        local reason = table.concat(resetReasons, ", ")
        addon_message("Using Random Deal to reset: " .. reason)
        use_JA("Random Deal", "<me>")
        return true
    end
    return false
end

local function prerender()
    if not actions then return end
    local curtime = os.clock()
	
    if nexttime + del <= curtime then
		del = settings.delay
		nexttime = curtime
        local play = windower.ffxi.get_player()
		
		-- Check basic player status first
		if not play then return end
		
		-- Update job info for advanced logic (must come after player check)
		updateJobInfo()
		
		local isCor = play and (play.main_job == 'COR' or play.sub_job == 'COR')
        if not isCor or play.status > 1 then return end	
		
		-- Advanced safety checks from J-Roller
		if isIncapacitated() then return end
		
		-- Do not roll while hidden
		if hasBuff("sneak") or hasBuff("invisible") then return end
		
		-- Check engaged only setting
		if settings.engaged and play.status ~= 1 then return end -- 1 = engaged
		
		-- Check town mode setting
		if settings.townmode then
			local zone_info = windower.ffxi.get_info()
			if zone_info and zone_info.zone then
				-- Basic town detection - could be enhanced with full city list
				local zone_name = res.zones[zone_info.zone] and res.zones[zone_info.zone].english
				if zone_name and (zone_name:find("Jeuno") or zone_name:find("Bastok") or 
				   zone_name:find("Windurst") or zone_name:find("San d'Oria") or
				   zone_name:find("Adoulin") or zone_name:find("Whitegate")) then
					return
				end
			end
		end
		
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
					-- Roll buff not present - need to cast it
					if abil_recasts[193] == 0 then
						if x == settings.crooked_cards and abil_recasts[96] and abil_recasts[96] == 0 then
							use_JA("Crooked Cards", '<me>')
						else
							use_JA(('%s'):format(roll.en), '<me>')
						end
                    else
                        -- Phantom Roll on cooldown. Try Random Deal to reset it.
                        if try_random_deal() then return end
					end
					return
				elseif buffs[308] and buffs[308] == roll.id then
					-- We have phantom roll window for this roll - double up logic
					-- Check if roll is complete (lucky or 11)
					if buffs[roll.buff] == roll.lucky or buffs[roll.buff] == 11 then
						-- Roll is complete, clear phantom roll buff to allow next roll
						buffs[308] = nil
						addon_message("Roll " .. x .. " complete: " .. roll.en .. " = " .. buffs[roll.buff] .. 
							(buffs[roll.buff] == roll.lucky and " (Lucky!)" or buffs[roll.buff] == 11 and " (Perfect!)" or ""))
						
                        -- Attempt Random Deal immediately if this was Roll 1
                        if x == 1 then
                            if try_random_deal() then return end
                        end
                        
						-- Continue to next iteration to start next roll
					elseif buffs[roll.buff] ~= roll.lucky and buffs[roll.buff] ~= 11 then
						-- Track roll timing for smart Snake Eye optimization
						if x == 1 then
							roll1RollTime = os.time()
						elseif x == 2 then
							roll2RollTime = os.time()
						end
						
						-- Track if Crooked Cards was used
						rollCrooked = buffs[601] ~= nil -- Crooked Cards buff
						
						-- Use advanced Snake Eye logic first
						if executeSnakeEye(buffs[roll.buff], roll.en) then
							return
						end
						
						-- Use advanced double-up logic
						local shouldDouble, reason = shouldDoubleUp(buffs[roll.buff], roll.en)
						
                        if shouldDouble then
                            if (abil_recasts[194] or 0) == 0 then
                                addon_message("Double-Up: " .. reason)
                                use_JA("Double-Up", '<me>')
                            else
                                -- Double-Up desired but on cooldown (animation delay?). Wait.
                                return
                            end
						else
							addon_message("Stopping: " .. (reason or "Advanced logic determined not to double-up"))
							-- Clear phantom roll buff so we can move to next roll
							buffs[308] = nil
                            
                            -- Attempt Random Deal immediately if this was Roll 1
                            if x == 1 then
                                if try_random_deal() then return end
                            end
						end
						return
					end
				end
				-- else: Roll buff is present but no phantom roll window = roll is complete and stable
				-- Continue to next roll check
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
            local roll1 = rolls:with('en', settings.roll[1])
            local roll2 = rolls:with('en', settings.roll[2])
            
            -- Check if Roll 1 is complete and Roll 2 is not active yet (and not in phantom roll window)
            if roll1 and roll2 and buffs[roll1.buff] and not buffs[roll2.buff] and not buffs[308] then
                if try_random_deal() then
                    nextdraw = curtime
                end
            end
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
	elseif commands[1] == 'engaged' then
		local arg = commands[2] and commands[2]:lower()
		if arg == 'on' then
			settings.engaged = true
		elseif arg == 'off' then
			settings.engaged = false
		else
			settings.engaged = not settings.engaged
		end
		addon_message('Engaged Only: ' .. (settings.engaged and 'On' or 'Off'))
	elseif commands[1] == 'crooked2' then
		local arg = commands[2] and commands[2]:lower()
		if arg == 'on' then
			settings.crooked2 = true
		elseif arg == 'off' then
			settings.crooked2 = false
		else
			settings.crooked2 = not settings.crooked2
		end
		addon_message('Save Crooked for Roll 2 Only: ' .. (settings.crooked2 and 'On (Special)' or 'Off (Normal)'))
	elseif commands[1] == 'randomdeal' then
		local arg = commands[2] and commands[2]:lower()
		if arg == 'on' then
			settings.randomdeal = true
		elseif arg == 'off' then
			settings.randomdeal = false
		else
			settings.randomdeal = not settings.randomdeal
		end
		addon_message('Random Deal: ' .. (settings.randomdeal and 'On' or 'Off'))
	elseif commands[1] == 'oldrandomdeal' then
		local arg = commands[2] and commands[2]:lower()
		if arg == 'on' then
			settings.oldrandomdeal = true
		elseif arg == 'off' then
			settings.oldrandomdeal = false
		else
			settings.oldrandomdeal = not settings.oldrandomdeal
		end
		local mode = settings.oldrandomdeal and 'Disabled for Crooked Cards' or 'Smart (All Abilities)'
		addon_message('Random Deal Mode: ' .. mode)
	elseif commands[1] == 'partyalert' then
		local arg = commands[2] and commands[2]:lower()
		if arg == 'on' then
			settings.partyalert = true
		elseif arg == 'off' then
			settings.partyalert = false
		else
			settings.partyalert = not settings.partyalert
		end
		addon_message('Party Alert: ' .. (settings.partyalert and 'On' or 'Off'))
	elseif commands[1] == 'gamble' then
		local arg = commands[2] and commands[2]:lower()
		if arg == 'on' then
			settings.gamble = true
		elseif arg == 'off' then
			settings.gamble = false
		else
			settings.gamble = not settings.gamble
		end
		addon_message('Gamble Mode: ' .. (settings.gamble and 'On (Targeting double 11s)' or 'Off'))
	elseif commands[1] == 'bustimmunity' then
		local arg = commands[2] and commands[2]:lower()
		if arg == 'on' then
			settings.bustimmunity = true
		elseif arg == 'off' then
			settings.bustimmunity = false
		else
			settings.bustimmunity = not settings.bustimmunity
		end
		addon_message('Bust Immunity: ' .. (settings.bustimmunity and 'On (Exploit when available)' or 'Off (Always conservative)'))
	elseif commands[1] == 'safemode' then
		local arg = commands[2] and commands[2]:lower()
		if arg == 'on' then
			settings.safemode = true
		elseif arg == 'off' then
			settings.safemode = false
		else
			settings.safemode = not settings.safemode
		end
		addon_message('Safe Mode: ' .. (settings.safemode and 'On (Ultra-conservative)' or 'Off'))
	elseif commands[1] == 'townmode' then
		local arg = commands[2] and commands[2]:lower()
		if arg == 'on' then
			settings.townmode = true
		elseif arg == 'off' then
			settings.townmode = false
		else
			settings.townmode = not settings.townmode
		end
		addon_message('Town Mode: ' .. (settings.townmode and 'On (No rolling in cities)' or 'Off'))
	elseif commands[1] == 'rollwithbust' then
		local arg = commands[2] and commands[2]:lower()
		if arg == 'on' then
			settings.rollwithbust = true
		elseif arg == 'off' then
			settings.rollwithbust = false
		else
			settings.rollwithbust = not settings.rollwithbust
		end
		addon_message('Roll with Bust: ' .. (settings.rollwithbust and 'On (Allow Roll 2 when busted)' or 'Off'))
	elseif commands[1] == 'smartsnakeeye' then
		local arg = commands[2] and commands[2]:lower()
		if arg == 'on' then
			settings.smartsnakeeye = true
		elseif arg == 'off' then
			settings.smartsnakeeye = false
		else
			settings.smartsnakeeye = not settings.smartsnakeeye
		end
		addon_message('Smart Snake Eye: ' .. (settings.smartsnakeeye and 'On (Optimize end-rotation)' or 'Off'))
	elseif commands[1] == 'snakeeye' then
		local arg = commands[2] and commands[2]:lower()
		if arg == 'on' then
			settings.hasSnakeEye = true
			addon_message('Snake Eye: Enabled')
		elseif arg == 'off' then
			settings.hasSnakeEye = false
			addon_message('Snake Eye: Disabled')
		else
			updateJobInfo()
			addon_message('Snake Eye: ' .. (hasSnakeEye and 'Enabled' or 'Disabled'))
		end
	elseif commands[1] == 'fold' then
		local arg = commands[2] and commands[2]:lower()
		if arg == 'on' then
			settings.hasFold = true
			addon_message('Fold: Enabled')
		elseif arg == 'off' then
			settings.hasFold = false
			addon_message('Fold: Disabled')
		else
			updateJobInfo()
			addon_message('Fold: ' .. (hasFold and 'Enabled' or 'Disabled'))
		end
	elseif commands[1] == 'resetpriority' then
		settings.randomDealPriority = { 'Crooked Cards', 'Snake Eye', 'Fold' }
		addon_message('Random Deal priority reset to default: Crooked Cards > Snake Eye > Fold')
	elseif commands[1] == 'debug' then
		updateJobInfo()
		addon_message('=== Debug Info ===')
		addon_message('Main Job: ' .. tostring(mainjob))
		addon_message('Sub Job: ' .. tostring(subjob))
		addon_message('Snake Eye Available: ' .. tostring(hasSnakeEye))
		addon_message('Fold Available: ' .. tostring(hasFold))
		addon_message('Last Roll: ' .. tostring(lastRoll))
		addon_message('Settings Snake Eye: ' .. tostring(settings.hasSnakeEye))
		addon_message('Settings Fold: ' .. tostring(settings.hasFold))
		addon_message('Random Deal Enabled: ' .. tostring(settings.randomdeal))
		
		-- Show current recast status
		local abil_recasts = windower.ffxi.get_ability_recasts()
		addon_message('=== Recast Status ===')
		addon_message('Snake Eye (197): ' .. tostring(abil_recasts[197] or 0))
		addon_message('Fold (198): ' .. tostring(abil_recasts[198] or 0))
		addon_message('Random Deal (196): ' .. tostring(abil_recasts[196] or 0))
		addon_message('Crooked Cards (96): ' .. tostring(abil_recasts[96] or 0))
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
    elseif commands[1] == 'help' then
        addon_message('=== AutoCOR Enhanced Commands ===')
        addon_message('//cor - Toggle AutoCOR on/off')
        addon_message('//cor on/off - Enable/disable rolling')
        addon_message('//cor roll 1/2 <name> - Set roll')
        addon_message('//cor cc [number] - Set Crooked Cards usage')
        addon_message('//cor autodraw - Toggle Auto Quick Draw')
        addon_message('//cor autorandom - Toggle Auto Random Deal')
        addon_message('')
        addon_message('=== Advanced J-Roller Features ===')
        addon_message('//cor engaged on/off - Only roll while engaged')
        addon_message('//cor crooked2 on/off - Save Crooked Cards for roll 2 only')
        addon_message('//cor randomdeal on/off - Smart Random Deal usage')
        addon_message('//cor oldrandomdeal on/off - Random Deal mode')
        addon_message('//cor partyalert on/off - Alert party before rolling')
        addon_message('//cor gamble on/off - Aggressive mode for double 11s')
        addon_message('//cor bustimmunity on/off - Exploit bust immunity')
        addon_message('//cor safemode on/off - Ultra-conservative mode')
        addon_message('//cor townmode on/off - Prevent rolling in towns')
        addon_message('//cor rollwithbust on/off - Allow Roll 2 when busted')
        addon_message('//cor smartsnakeeye on/off - Smart Snake Eye optimization')
        addon_message('//cor snakeeye/fold on/off - Merit ability settings')
        addon_message('//cor resetpriority - Reset Random Deal priority')
        addon_message('//cor debug - Show debug information')
        addon_message('//cor save - Save current settings')
        addon_message('//cor hide - Toggle UI visibility')
        addon_message('//cor reset - Reset UI position')
    else
        addon_message('Unknown command: ' .. commands[1] .. '. Use //cor help for commands.')
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
                lastRoll = effect -- Track last roll result
            elseif message == 424 then              -- Double-Up
                buffs[rolls[param].buff] = effect
                lastRoll = effect -- Track last roll result
            elseif message == 426 then              -- Bust
                buffs[rolls[param].buff] = nil
                buffs[309] = param
                lastRoll = 12 -- Bust
                bustWaitingMessageSent = false -- Reset bust message flag
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
