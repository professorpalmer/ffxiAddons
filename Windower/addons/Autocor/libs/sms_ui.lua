--[[ CREDIT: This document is originally authored by Windower & included in Windower v4.
	It's current form has only been modified, not authored, by RolandJ. ]]
--[[Copyright © 2022, RolandJ
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of SmartSkillup nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL RolandJ BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.]]

local images = require('libs/sms_images')
local texts = require('libs/sms_texts')
require('tables')



-------------------------------------------------------------------------------------------------------------------
-- The UI object, contains metadata and functions for modifying the UI
-------------------------------------------------------------------------------------------------------------------
local ui = T{
	meta = T{} -- The master record of UI objects, used for tracking active state, lookups, and caching for deletion
}

-- Add find method to ui.meta if it doesn't exist
if not ui.meta.find then
	ui.meta.find = function(self, fn)
		for i, m in ipairs(self) do
			if fn(m) then
				return i, m
			end
		end
		return nil, nil
	end
end


-------------------------------------------------------------------------------------------------------------------
-- Various local variables used throughout the UI
-------------------------------------------------------------------------------------------------------------------
local drag_positions -- cache of positions while dragging. (drag moves need original pos intact)
local path = windower.addon_path .. 'data/' -- where the button images are located (ui.set_path(str))
local header_text -- an optional header. (set using ui.set_header_text(str))
local main_job -- an optional subheader (set using ui.set_main_job(str))
local colors = {
	white  = function() return 255, 255, 255 end,
	grey   = function() return  96,  96,  96 end,
	blue   = function() return  51, 153, 255 end,
	yellow = function() return 250, 250, 100 end,
	orange = function() return 255, 153,  51 end,
	green  = function() return  51, 255,  51 end,
	red    = function() return 255,  51,  51 end,
}


-------------------------------------------------------------------------------------------------------------------
-- Set the button size settings using the user's UI scalar (CREDIT: Joshuateverday: https://github.com/SirEdeonX/FFXIAddons/issues/6)
-------------------------------------------------------------------------------------------------------------------
local windower_settings = windower.get_windower_settings()
local ui_scalar = ((windower_settings.ui_x_res * 1.0) / (windower_settings.x_res * 1.0)) --TODO: user customizable
local scalars = T{
	images = {
		width     = 209 * ui_scalar,
		height    = 23  * ui_scalar,
		sidecar_w = 70  * ui_scalar,
		sidecar_h = 17  * ui_scalar,
	},
	texts = {
		size         = 13 * ui_scalar,
		stroke_width =  1 * ui_scalar,
		padding      =  1 * ui_scalar,
	},
	offsets = {
		texts     = {x =   6 * ui_scalar, y =   0},
		subtexts  = {x = 167 * ui_scalar, y =   0},
		header    = {x =   2 * ui_scalar, y = -14 * ui_scalar},
		on        = {x =  87 * ui_scalar, y = -11 * ui_scalar},
		slash     = {x = 102 * ui_scalar, y = -11 * ui_scalar},
		off       = {x = 106 * ui_scalar, y = -11 * ui_scalar},
		pause     = {x = 131 * ui_scalar, y = -11 * ui_scalar},
		paused    = {x = 129 * ui_scalar, y = -11 * ui_scalar},
		help      = {x = 172 * ui_scalar, y = -11 * ui_scalar},
		mj_hdr    = {x =  90 * ui_scalar, y =  -1 * ui_scalar},
		mj_label  = {x = 173 * ui_scalar, y =  -1 * ui_scalar},
		shutdown  = {x =   4 * ui_scalar, y =  -1 * ui_scalar},
		sidecar   = {x = 210 * ui_scalar, y =   0},
		sc_texts  = {x =   6 * ui_scalar, y =   0},
		modules   = {x = 213 * ui_scalar, y = -11 * ui_scalar},
		limit_hdr = {x =   3 * ui_scalar, y =  -1 * ui_scalar},
		limit     = {x =  46 * ui_scalar, y =  -1 * ui_scalar},
	},
}
local user_scalars = T{} -- updated by config



-------------------------------------------------------------------------------------------------------------------
-- Functions that build/maintain user scalars by multiplying the default scalars by the user scalar preference
-------------------------------------------------------------------------------------------------------------------
function ui.update_user_scalars(settings)
	user_scalars = T{}
	for category, items in pairs(scalars) do
		user_scalars[category] = T{}
		for item, value in pairs(items) do
			if type(value) == 'table' then
				user_scalars[category][item] = T{}
				for subitem, subvalue in pairs(value) do
					user_scalars[category][item][subitem] = subvalue * (settings.user_ui_scalar or 1)
				end
			else
				user_scalars[category][item] = value * (settings.user_ui_scalar or 1)
			end
		end
	end
end

function ui.set_path(str)
	path = str
end

function ui.set_header_text(str)
	header_text = str
end

function ui.set_main_job(str)
	main_job = str
end

-- Store settings reference
local ui_settings = nil
local drag_positions -- cache of positions while dragging

function ui.set_settings(settings_table)
	ui_settings = settings_table
end

-------------------------------------------------------------------------------------------------------------------
-- Function that generates hitboxes for the main UI area used to capture all mouse clicks in said areas
-------------------------------------------------------------------------------------------------------------------
function ui.generate_hitbox_config(kind)
	if kind == nil then return end
	
	if kind == 'main' then
		return {
			x = ui_settings.top_left.x,
			y = ui_settings.top_left.y,
			width  = 350, -- Cover all buttons and party indicators
			height = 150  -- Cover all UI elements
		}
	end
end

function ui.top_left(x, y)
	if x == nil and y == nil then
		if ui_settings and ui_settings.top_left then
			return ui_settings.top_left.x, ui_settings.top_left.y
		end
		return 0, 0 -- Default fallback
	end
	if ui_settings and ui_settings.top_left then
		ui_settings.top_left.x = x or ui_settings.top_left.x
		ui_settings.top_left.y = y or ui_settings.top_left.y
	end
end

function ui.hidden(bool)
	if bool == nil then
		if ui_settings then
			return ui_settings.ui_hidden
		end
		return false
	end
	if ui_settings then
		ui_settings.ui_hidden = bool
	end
	
	-- Hide/show all UI elements
	for _, m in pairs(ui.meta) do
		if m.t and m.t.visible then
			m.t:visible(not bool)
		end
	end
end

function ui.active(bool)
	if bool == nil then return end
	ui.paused(nil, bool)
end

function ui.paused(bool, event_paused)
	if bool == nil then return end
	local _, pause = ui.meta:find(function(m) return m.name == 'paused' end)
	if pause == nil or pause.t == nil then return end

	pause.active = bool
	pause.event = event_paused
	ui.update_color(pause, colors[bool and 'orange' or 'grey']())
end

function ui.event_paused(bool)
	if bool == nil then return end
	ui.paused(nil, bool)
end

function ui.auto_shutdown(bool)
	if bool == nil and event == nil then return end
	local _, shutdown = ui.meta:find(function(m) return m.name == 'shutdown' end)
	if shutdown == nil or shutdown.t == nil then return end

	shutdown.active = bool
	ui.update_color(shutdown, colors[bool and 'orange' or 'grey']())
end

function ui.button_active(name, bool, sidecar)
	if name == nil then return end
	local _, m = ui.meta:find(function(m) return m.name == name and m.kind == 'image' end)
	if not m then return print('unable to get image ' .. name) end
	
	m.active = bool
	m.t:path(path .. 'Button002-' .. (bool and 'Orange' or 'Blue') .. '.png')
end

function ui.set_visible(name, bool)
	if name == nil or bool == nil then return end
	local _, m = ui.meta:find(function(m) return m.name == name end)
	if not m then return print('unable to get element ' .. name) end
	
	m.t:visible(bool)
	m.visible = bool
	m.hidden = not bool
end

function ui.set_text(name, str)
	if name == nil or str == nil then return end
	local _, m = ui.meta:find(function(m) return m.name == name and m.kind == 'text' end)
	if not m then return print('unable to get text ' .. name) end
	
	m.t:text(tostring(str))
end

function ui.set_status_text(name, str)
	if name == nil or str == nil then return end
	local _, m = ui.meta:find(function(m) return m.name == name and m.kind == 'status' end)
	if not m then return print('unable to get status text ' .. name) end
	
	m.t:text(tostring(str))
end

function ui.set_indicator_text(name, str)
	if name == nil or str == nil then return end
	local _, m = ui.meta:find(function(m) return m.name == name and m.kind == 'indicator' end)
	if not m then return print('unable to get indicator text ' .. name) end
	
	m.t:text(tostring(str))
end

function ui.set_indicator_color(name, color)
	if name == nil or color == nil then return end
	local _, m = ui.meta:find(function(m) return m.name == name and m.kind == 'indicator' end)
	if not m then return print('unable to get indicator ' .. name) end
	
	ui.update_color(m, colors[color]())
end

function ui.set_party_text_color(name, color)
	if name == nil or color == nil then return end
	local _, m = ui.meta:find(function(m) return m.name == name and m.kind == 'text_button' end)
	if not m then return print('unable to get party text button ' .. name) end
	
	ui.update_color(m, colors[color]())
end

function ui.set_subtext(name, str)
	if name == nil or str == nil then return end
	local _, m = ui.meta:find(function(m) return m.name == name and m.kind == 'subtext' end)
	if not m then return print('unable to get subtext ' .. name) end
	
	m.t:text(tostring(str))
end

function ui.set_text_color(name, color)
	if name == nil or color == nil then return end
	local text, stext = ui.get_subordinate_texts(name)
	if text == nil or stext == nil then return print('unable to get text ' .. name) end
	
	ui.update_color(text,  colors[color]())
	ui.update_color(stext, colors[color]())
end

function ui.get_subordinate_texts(name)
	if name == nil then return end
	local _, m1 = ui.meta:find(function(m) return m.name == name and m.kind == 'text' end)
	local _, m2 = ui.meta:find(function(m) return m.name == name and m.kind == 'subtext' end)
	return m1, m2
end

function ui.update_color(meta, c1, c2, c3)
	if meta == nil then return end
	
	meta.t:color(c1, c2, c3)
	meta.color = {c1, c2, c3}
end

function ui.store_table(t, name, kind, command)
	if t == nil or name == nil or kind == nil then return end
	
	local x, y = t:pos()
	local m = T{
		t = t,
		name = name,
		kind = kind,
		command = command,
		active = false,
		visible = true,
		hidden = false,
		color = {t:color()}, -- Get the actual color from the element
		pos = {x = x, y = y} -- Get x,y position
	}
	
	ui.meta:insert(m)
end

function ui.generate_hitbox_config(name)
	local hitbox_config = T{}
	
	if name == 'main' then
		hitbox_config.x = ui.top_left()
		hitbox_config.y = ui.top_left()
		hitbox_config.width = user_scalars.images.width
		hitbox_config.height = user_scalars.images.height * 5 -- 5 buttons
	elseif name == 'sidecar' then
		hitbox_config.x = ui.top_left() + user_scalars.offsets.sidecar.x
		hitbox_config.y = ui.top_left() + user_scalars.offsets.sidecar.y
		hitbox_config.width = user_scalars.images.sidecar_w
		hitbox_config.height = user_scalars.images.sidecar_h * 3 -- 3 sidecar elements
	end
	
	return hitbox_config
end

function ui.create_button(name, text, command, x, y, user_scalars, disable_click)
	if name == nil or text == nil then 
		print('AutoCOR UI: create_button failed - name or text is nil')
		return 
	end
	
	print('AutoCOR UI: Creating button ' .. name .. ' at position ' .. x .. ',' .. y)
	
	local button_config = T{
		[name] = T{
			text = text,
			command = command,
			color = 'white',
			subtext = ''
		}
	}
	
	-- Add Image
	local image = images.new()
	image:pos(x, y)
	image:path(path .. 'Button002-Blue.png')
	image:fit(false)
	image:size(user_scalars.images.width, user_scalars.images.height)
	image:left_draggable(false)  -- Disable dragging
	image:right_draggable(false) -- Disable dragging
	image:scroll_draggable(false) -- Disable dragging
	
	-- Only register click events if not disabled
	if not disable_click then
		image:register_event('left_click', ui.left_click_event) -- Register click event
		image:register_event('hover', ui.hover_event) -- Register hover event
	end
	
	ui.store_table(image, name, 'image', button_config[name].command)
	image:show()
	print('AutoCOR UI: Created image for ' .. name)
	
	-- Add Text
	local text_obj = texts.new(text)
	text_obj:pos(x + user_scalars.offsets.texts.x, y)
	text_obj:size(user_scalars.texts.size)
	text_obj:color(colors[button_config[name].color]())
	text_obj:stroke_width(user_scalars.texts.stroke_width)
	text_obj:pad(user_scalars.texts.padding)
	text_obj:italic(true)
	text_obj:bold(true)
	text_obj:bg_visible(false)
	text_obj:left_draggable(false)  -- Disable dragging
	text_obj:right_draggable(false) -- Disable dragging
	text_obj:scroll_draggable(false) -- Disable dragging
	ui.store_table(text_obj, name, 'text')
	text_obj:show()
	print('AutoCOR UI: Created text for ' .. name)
	
	-- Add Subtext
	local subtext = texts.new(button_config[name].subtext or '')
	subtext:pos(x + user_scalars.offsets.subtexts.x, y)
	subtext:size(user_scalars.texts.size)
	subtext:color(colors[button_config[name].color]())
	subtext:stroke_width(user_scalars.texts.stroke_width)
	subtext:pad(user_scalars.texts.padding)
	subtext:italic(true)
	subtext:bold(true)
	subtext:bg_visible(false)
	subtext:left_draggable(false)  -- Disable dragging
	subtext:right_draggable(false) -- Disable dragging
	subtext:scroll_draggable(false) -- Disable dragging
	ui.store_table(subtext, name, 'subtext')
	subtext:show()
	print('AutoCOR UI: Created subtext for ' .. name)
	print('AutoCOR UI: Button ' .. name .. ' complete')
end

function ui.create_status_text(name, text, x, y, user_scalars)
	if name == nil or text == nil then return end
	
	local status_text = texts.new(text)
	status_text:pos(x, y)
	status_text:size(user_scalars.texts.size)
	status_text:color(colors.white())
	status_text:stroke_width(user_scalars.texts.stroke_width)
	status_text:pad(user_scalars.texts.padding)
	status_text:italic(false)
	status_text:bold(true)
	status_text:bg_visible(false)
	status_text:left_draggable(false)  -- Disable dragging
	status_text:right_draggable(false) -- Disable dragging
	status_text:scroll_draggable(false) -- Disable dragging
	ui.store_table(status_text, name, 'status')
	status_text:show()
end

function ui.create_party_text_button(name, text, command, x, y, user_scalars)
	if name == nil or text == nil then return end
	
	local text_button = texts.new(text)
	text_button:pos(x, y)
	text_button:size(user_scalars.texts.size * 0.8)
	text_button:color(colors.green())
	text_button:stroke_width(user_scalars.texts.stroke_width)
	text_button:pad(user_scalars.texts.padding)
	text_button:italic(false)
	text_button:bold(true)
	text_button:bg_visible(false)
	text_button:left_draggable(false)  -- Disable dragging
	text_button:right_draggable(false) -- Disable dragging
	text_button:scroll_draggable(false) -- Disable dragging
	
	-- Register click events
	text_button:register_event('left_click', ui.left_click_event)
	text_button:register_event('hover', ui.hover_event)
	
	ui.store_table(text_button, name, 'text_button', command)
	text_button:show()
end

function ui.create_party_indicator(name, text, x, y, user_scalars)
	if name == nil or text == nil then return end
	
	local indicator = texts.new(text)
	indicator:pos(x, y)
	indicator:size(user_scalars.texts.size * 0.8)
	indicator:color(colors.green())
	indicator:stroke_width(user_scalars.texts.stroke_width)
	indicator:pad(user_scalars.texts.padding)
	indicator:italic(false)
	indicator:bold(true)
	indicator:bg_visible(false)
	indicator:left_draggable(false)  -- Disable dragging
	indicator:right_draggable(false) -- Disable dragging
	indicator:scroll_draggable(false) -- Disable dragging
	ui.store_table(indicator, name, 'indicator')
	indicator:show()
end

function ui.destroy_all()
	for _, m in pairs(ui.meta) do
		if m.t and m.t.destroy then
			m.t:destroy()
		end
	end
	ui.meta:clear()
end

function ui.initialize(settings, user_scalars)
	print('AutoCOR UI: Starting initialization...')
	ui.update_user_scalars(settings)
	print('AutoCOR UI: User scalars updated')
	
	-- Create main control buttons
	print('AutoCOR UI: Creating buttons...')
	ui.create_button('autocor_toggle', 'AutoCOR OFF', 'lua c autocor toggle', settings.top_left.x, settings.top_left.y, user_scalars)
	ui.create_button('roll1', 'Roll 1: Corsair\'s', 'cor roll 1 Corsair\'s Roll', settings.top_left.x, settings.top_left.y + 25, user_scalars, true) -- Disable click
	ui.create_button('roll2', 'Roll 2: Chaos', 'cor roll 2 Chaos Roll', settings.top_left.x, settings.top_left.y + 50, user_scalars, true) -- Disable click
	    ui.create_button('crooked_cards', 'Crooked Cards', 'lua c autocor cc toggle', settings.top_left.x, settings.top_left.y + 75, user_scalars)
	ui.create_button('quick_draw', 'Auto QD OFF', 'lua c autocor autodraw', settings.top_left.x, settings.top_left.y + 100, user_scalars)
	ui.create_button('random_deal', 'Auto RD OFF', 'lua c autocor autorandom', settings.top_left.x, settings.top_left.y + 125, user_scalars)
	ui.create_button('hide_ui', 'Hide UI', 'cor hide', settings.top_left.x, settings.top_left.y + 150, user_scalars)
	ui.create_button('reset_ui', 'Reset UI', 'cor reset', settings.top_left.x, settings.top_left.y + 175, user_scalars)
	print('AutoCOR UI: Buttons created')
	
	-- Create status displays
	print('AutoCOR UI: Creating status texts...')
	ui.create_status_text('roll1_status', 'Corsair\'s: 5/11', settings.top_left.x + 220, settings.top_left.y + 30, user_scalars)
	ui.create_status_text('roll2_status', 'Chaos: 4/8', settings.top_left.x + 220, settings.top_left.y + 60, user_scalars)
	ui.create_status_text('party_status', 'Party AoE: All Active', settings.top_left.x + 220, settings.top_left.y + 90, user_scalars)
	print('AutoCOR UI: Status texts created')
	
	-- Create party indicator text buttons
	print('AutoCOR UI: Creating party indicator text buttons...')
	ui.create_party_text_button('p1', 'P1', 'lua c autocor aoe 1', settings.top_left.x + 220, settings.top_left.y + 120, user_scalars)
	ui.create_party_text_button('p2', 'P2', 'lua c autocor aoe 2', settings.top_left.x + 250, settings.top_left.y + 120, user_scalars)
	ui.create_party_text_button('p3', 'P3', 'lua c autocor aoe 3', settings.top_left.x + 280, settings.top_left.y + 120, user_scalars)
	ui.create_party_text_button('p4', 'P4', 'lua c autocor aoe 4', settings.top_left.x + 310, settings.top_left.y + 120, user_scalars)
	ui.create_party_text_button('p5', 'P5', 'lua c autocor aoe 5', settings.top_left.x + 340, settings.top_left.y + 120, user_scalars)
	print('AutoCOR UI: Party indicator text buttons created')
	
	-- Add Main Area's Hitbox (for drag of entire UI)
	local hitbox_config = ui.generate_hitbox_config('main')
	local hitbox = images.new()
	hitbox:pos(hitbox_config.x, hitbox_config.y)
	hitbox:size(hitbox_config.width, hitbox_config.height)
	hitbox:transparency(1)
	hitbox:right_draggable(true)
	hitbox:register_event('right_drag', ui.move_event)
	ui.store_table(hitbox, 'main', 'hitbox')
	hitbox:show()
	
	-- Create header
	print('AutoCOR UI: Creating header...')
	local header = texts.new('AUTOCOR CONTROL PANEL')
	header:pos(settings.top_left.x, settings.top_left.y - 20)
	header:size(user_scalars.texts.size * 1.2)
	header:color(colors.yellow())
	header:stroke_width(user_scalars.texts.stroke_width * 2)
	header:pad(user_scalars.texts.padding)
	header:bold(true)
	header:italic(true)
	header:bg_visible(false)
	header:left_draggable(false)  -- Disable dragging
	header:right_draggable(false) -- Disable dragging
	header:scroll_draggable(false) -- Disable dragging
	ui.store_table(header, 'header', 'header')
	header:show()
	print('AutoCOR UI: Header created')
	
	-- Apply hidden state if needed
	if settings.ui_hidden then
		ui.hidden(true)
	end
	
	print('AutoCOR UI: Initialization complete. Total UI elements: ' .. #ui.meta)
end

-------------------------------------------------------------------------------------------------------------------
-- The function that moves the buttons in tandem, by comparing the positions of the click, mouse, and image
-------------------------------------------------------------------------------------------------------------------
function ui.move_event(t, root_settings, data)
	if data.release then
		-- END OF DRAG: SAVE NEW UI POSITION
		for i, m in ipairs(ui.meta) do
			m.pos = drag_positions[i] -- only do this post-drag
		end
		drag_positions = nil
		ui_settings.top_left = ui.meta[1].pos
		-- Save to settings if config is available
		if _libs and _libs.config then
			_libs.config.save(ui_settings)
		end
		
	else
		-- DRAGGING: KEEP UI ELEMENTS SYNCED
		local i, m = ui.meta:find(function(m) return m.t == t end)
		drag_positions = T{}
		for i, m in ipairs(ui.meta) do
			local internal = {x = data.click.x - m.pos.x, y = data.click.y - m.pos.y}
			local x, y = data.mouse.x - internal.x, data.mouse.y - internal.y
			m.t:pos(x, y)
			drag_positions[i] = {x = x, y = y} -- movement accelerates if we m.pos mid-drag!
		end
	end
end

-------------------------------------------------------------------------------------------------------------------
-- The function that handles mouse left-click events
-------------------------------------------------------------------------------------------------------------------
function ui.left_click_event(t, root_settings, data)
	-- IGNORE NO-COMMAND CLICKS
	local i, m = ui.meta:find(function(m) return m.t == t end)
	if not m or not m.command then return end -- ignore destroyed or non-interactable elements
	local text, stext = ui.get_subordinate_texts(m.name)
	
	-- LEFT RELEASE: FIRE COMMAND & RESTORE POS
	if data.release then
		if t:hover(data.x, data.y) and not data.dragged then -- cancel command on drag-away
			windower.send_command(m.command)
		end
		t:pos(m.pos.x, m.pos.y)
		if m.kind == 'image' then
			if text  then text.t:pos (text.pos.x , text.pos.y ) end
			if stext then stext.t:pos(stext.pos.x, stext.pos.y) end
		end
		
		-- UNHOVER HELPER: RESTORE COLOR FOR HOVER>DRAGAWAYS
		if m.color and m.color[1] and m.color[2] and m.color[3] then
			t:color(m.color[1], m.color[2], m.color[3])
		end
	
	-- LEFT CLICK : MOVE DOWN/RIGHT 1PX
	else
		local offset = 1 * (settings and settings.user_ui_scalar or 1)
		t:pos(m.pos.x + offset, m.pos.y + offset)
		if m.kind == 'image' then
			if text then  text.t:pos (text.pos.x + offset , text.pos.y + offset ) end
			if stext then stext.t:pos(stext.pos.x + offset, stext.pos.y + offset) end
		end
	end
end

-------------------------------------------------------------------------------------------------------------------
-- The function that handles mouse hover events
-------------------------------------------------------------------------------------------------------------------
local old_hover_color
function ui.hover_event(t, root_settings, hovered, active_click)
	local i, m = ui.meta:find(function(m) return m.t == t end)
	if not m or not m.command then return end -- ignore destroyed or non-interactable elements
	if active_click then return end -- ignore embedded hovers (click > *hover elsewhere* > release)
	
	-- HOVER
	if hovered then
		if m.color and m.color[1] and m.color[2] and m.color[3] then
			t:color(m.color[1]-30, m.color[2]-30, m.color[3]-30)
		end
	
	-- UNHOVER
	else
		if active_click then return end -- ignore, will be restored during click release
		if m.color and m.color[1] and m.color[2] and m.color[3] then
			t:color(m.color[1], m.color[2], m.color[3])
		end
	end
end

return ui 