--[[
Copyright © 2024, Byrth - Ashita 4 version by Palmer
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
    * Neither the name of AnsweringMachine nor the
    names of its contributors may be used to endorse or promote products
    derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

addon.name      = 'AnsweringMachine';
addon.author    = 'Byrth - Ashita 4 version by Palmer';
addon.version   = '1.4';
addon.desc      = 'Records tell conversations and provides away message functionality.';
addon.link      = 'https://github.com/Palmer-ashita4/AnsweringMachine';

require('common');
local chat = require('chat');

-- AnsweringMachine Variables
local am = T{
    last_activity = os.time(),
    unseen_message_count = 0,
    away_msg = nil,
    recording = T{},
    text_list = T{},
    text_index = 1,
    overlay_x = 100,
    overlay_y = 100,
    away_sent = T{}, -- Track who we've sent away message to
};

-- Initialize text activity tracking
for i = 1, 10 do
    am.text_list[i] = os.time();
end

--[[
* Utility Functions
--]]

local function split(msg, match)
    local length = msg:len();
    local splitarr = T{};
    local u = 1;
    while u < length do
        local nextanch = msg:find(match, u);
        if nextanch ~= nil then
            splitarr[#splitarr + 1] = msg:sub(u, nextanch - 1);
            if nextanch ~= length then
                u = nextanch + 1;
            else
                u = length;
            end
        else
            splitarr[#splitarr + 1] = msg:sub(u, length);
            u = length;
        end
    end
    return splitarr;
end

local function uc_first(msg)
    local length = msg:len();
    local first_char = msg:sub(1, 1);
    local rest = msg:sub(2, length);
    return first_char:upper() .. rest:lower();
end

local function pl(num)
    if num > 1 then
        return 's';
    else
        return '';
    end
end

local function arrows(bool, name)
    if bool then
        return name .. '>> ';
    else
        return '>>' .. name .. ' : ';
    end
end

local function print_messages(tab, name)
    for p, q in ipairs(tab) do
        print(chat.header('AM'):append(chat.message(os.date('%H:%M:%S', q.timestamp) .. ' ' .. arrows(q.outgoing, uc_first(name)) .. q.message)));
        tab[p].seen = true;
    end
end

local function activity()
    am.last_activity = os.time();
    if am.unseen_message_count > 0 then
        local temp_message_count = 0;
        for i, v in pairs(am.recording) do
            for n, m in pairs(v) do
                if not m.seen then
                    if m.timestamp < am.text_list[((am.text_index + 1) == 11 and 1) or (am.text_index + 1)] then
                        temp_message_count = temp_message_count + 1;
                    else
                        am.recording[i][n].seen = true;
                    end
                end
            end
        end
        am.unseen_message_count = temp_message_count;
    end
end

--[[
* Event Handlers
--]]

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args == 0 or (args[1] ~= '/answeringmachine' and args[1] ~= '/am')) then
        return;
    end
    
    e.blocked = true;
    
    local term = table.concat(args, ' ', 2);
    local broken = split(term, ' ');
    
    if broken[1] ~= nil then
        if broken[1]:upper() == "CLEAR" then
            if broken[2] == nil then
                am.recording = T{};
                am.away_sent = T{};
                print(chat.header('AM'):append(chat.message('Blanking the recordings')));
            elseif am.recording[broken[2]:upper()] then
                print(chat.header('AM'):append(chat.message('Deleting conversation with ' .. uc_first(broken[2]))));
                am.recording[broken[2]:upper()] = nil;
                am.away_sent[broken[2]:upper()] = nil;
            else
                print(chat.header('AM'):append(chat.error('Could not find specified player in tell history')));
            end
        elseif broken[1]:upper() == "LIST" then
            local trig = false;
            for i, v in pairs(am.recording) do
                print(chat.header('AM'):append(chat.message(#v .. ' exchange' .. pl(#v) .. ' with ' .. uc_first(i))));
                trig = true;
            end
            if not trig then
                print(chat.header('AM'):append(chat.message('No exchanges recorded.')));
            end
        elseif broken[1]:upper() == "PLAY" then
            if broken[2] then
                if am.recording[broken[2]:upper()] then
                    local num = #am.recording[broken[2]:upper()];
                    print(chat.header('AM'):append(chat.message(num .. ' exchange' .. pl(num) .. ' with ' .. uc_first(broken[2]))));
                    print_messages(am.recording[broken[2]:upper()], broken[2]);
                end
            else
                print(chat.header('AM'):append(chat.message('Playing back all messages')));
                for i, v in pairs(am.recording) do
                    print(chat.header('AM'):append(chat.message(#v .. ' exchange' .. pl(#v) .. ' with ' .. uc_first(i))));
                    print_messages(v, i);
                end
            end
        elseif broken[1]:upper() == "HELP" then
            print(chat.header('AM'):append(chat.message('Commands:')));
            print(chat.message('  /am clear <name> : Clears current messages, or only messages from <name> if provided'));
            print(chat.message('  /am help : Lists these commands'));
            print(chat.message('  /am list : Lists the names of people who have sent you tells'));
            print(chat.message('  /am msg <message> : Sets your away message'));
            print(chat.message('  /am play <name> : Plays current messages, or only messages from <name> if provided'));
            print(chat.message('  /am pos <x> <y> : Sets overlay position'));
        elseif broken[1]:upper() == "MSG" then
            table.remove(broken, 1);
            if #broken ~= 0 then
                am.away_msg = table.concat(broken, ' ');
                am.away_sent = T{}; -- Reset away message tracking
                print(chat.header('AM'):append(chat.message('Away message set to: ' .. am.away_msg)));
            end
        elseif broken[1]:upper() == "POS" and tonumber(broken[2]) and tonumber(broken[3]) then
            am.overlay_x = tonumber(broken[2]);
            am.overlay_y = tonumber(broken[3]);
            print(chat.header('AM'):append(chat.message('Overlay position set to: ' .. am.overlay_x .. ', ' .. am.overlay_y)));
        end
    end
end);

-- Parse all incoming text for tells
ashita.events.register('text_in', 'text_in_cb', function (e)
    local message = e.message_modified;
    
    -- Check for RECEIVED tells: "PlayerName>> message"
    local incoming_pattern = "^([^%s]+)>>%s*(.+)";
    local player, tell_message = message:match(incoming_pattern);
    
    if player and tell_message then
        print(chat.header('AM'):append(chat.success('Incoming tell from ' .. player .. ': ' .. tell_message)));
        
        -- Record the tell
        if am.recording[player:upper()] then
            am.recording[player:upper()][#am.recording[player:upper()] + 1] = {
                message = tell_message,
                outgoing = false,
                timestamp = os.time(),
                seen = false
            };
        else
            am.recording[player:upper()] = T{{
                message = tell_message,
                outgoing = false,
                timestamp = os.time(),
                seen = false
            }};
        end
        
        am.unseen_message_count = am.unseen_message_count + 1;
        
        -- Send away message if set and not already sent to this player
        if am.away_msg and not am.away_sent[player:upper()] then
            print(chat.header('AM'):append(chat.message('Sending away message to ' .. player)));
            AshitaCore:GetChatManager():QueueCommand(1, ('/tell %s %s'):fmt(player, am.away_msg));
            am.away_sent[player:upper()] = true;
        end
    end
    
    -- Check for SENT tells: ">>PlayerName : message"
    local outgoing_pattern = "^>>([^%s]+)%s*:%s*(.+)";
    local out_player, out_message = message:match(outgoing_pattern);
    
    if out_player and out_message then
        print(chat.header('AM'):append(chat.success('Outgoing tell to ' .. out_player .. ': ' .. out_message)));
        
        -- Record the outgoing tell
        if am.recording[out_player:upper()] then
            am.recording[out_player:upper()][#am.recording[out_player:upper()] + 1] = {
                message = out_message,
                outgoing = true,
                timestamp = os.time(),
                seen = true
            };
        else
            am.recording[out_player:upper()] = T{{
                message = out_message,
                outgoing = true,
                timestamp = os.time(),
                seen = true
            }};
        end
    end
    
    -- Track text activity
    if not e.blocked then
        am.text_list[am.text_index] = os.time();
        am.text_index = am.text_index + 1;
        if am.text_index % 11 == 0 then
            am.text_index = 1;
        end
    end
end);

-- Track activity via input
ashita.events.register('key', 'key_cb', function (e)
    activity();
end);

ashita.events.register('mouse', 'mouse_cb', function (e)
    activity();
end);

-- Simple text overlay using ImGui
ashita.events.register('d3d_present', 'd3d_present_cb', function ()
    if am.unseen_message_count > 0 then
        local imgui = require('imgui');
        
        -- Create animated color effect
        local t = os.clock() % 1;
        local color_val = 150 + 100 * math.sin(t * math.pi);
        
        imgui.SetNextWindowPos({ am.overlay_x, am.overlay_y }, ImGuiCond_FirstUseEver);
        imgui.SetNextWindowSize({ 200, 50 }, ImGuiCond_FirstUseEver);
        
        local window_flags = bit.bor(ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoCollapse, 
                                   ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_AlwaysAutoResize);
        
        if imgui.Begin('AnsweringMachine##overlay', true, window_flags) then
            imgui.PushStyleColor(ImGuiCol_Text, 0, 0, 0, 255);
            imgui.PushStyleColor(ImGuiCol_WindowBg, color_val, color_val, 255, 255);
            
            imgui.Text(('%d Message%s'):fmt(am.unseen_message_count, pl(am.unseen_message_count)));
            
            imgui.PopStyleColor(2);
        end
        imgui.End();
    end
end);
