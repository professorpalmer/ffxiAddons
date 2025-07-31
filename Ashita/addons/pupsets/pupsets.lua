addon.name = 'pupsets';
addon.author = 'Palmer (Zodiarchy @ Asura)';
addon.version = '1.0';
addon.desc = 'Manage pup attachments easily with slash commands.';

require('common');
local imgui = require('imgui');
local pup = require('pup');
local chat = require('chat');

-- ImGui state
local gui = {
    is_open = {false}, -- Start closed
    presets = {},
    selected_preset = nil,
    window_size = {400, 500},
    window_pos = {100, 100},
    refresh_needed = true
};

--[[
* Refreshes the list of saved presets
--]]
local function refresh_presets()
    gui.presets = {};
    local path = ('%s\\config\\addons\\%s\\'):fmt(AshitaCore:GetInstallPath(),
                                                  'pupsets');

    if (not ashita.fs.exists(path)) then return; end

    local files = ashita.fs.get_directory(path, '.*\\.txt');
    if (files ~= nil) then
        for _, f in pairs(files) do
            local name = f:gsub('.txt', '');
            local preset = {name = name, attachments = {}};

            -- Load the attachment file
            local filepath = path:append(f);
            local file = io.open(filepath, 'r');
            if (file ~= nil) then
                local index = 1;
                local line_count = 0;
                for line in file:lines() do
                    line_count = line_count + 1;
                    if line_count <= 14 then
                        -- First 14 lines are attachments
                        preset.attachments[index] = line:trim();
                        index = index + 1;
                    elseif line_count == 15 and line:trim() ~= '' then
                        -- 15th line is animator (if present)
                        preset.animator = line:trim();
                    end
                end
                file:close();
            end

            table.insert(gui.presets, preset);
        end
    end

    -- Sort presets by name
    table.sort(gui.presets, function(a, b) return a.name < b.name; end);
    gui.refresh_needed = false;
end

--[[
* Renders the preset viewer ImGui window
--]]
local function render_preset_window()
    if not gui.is_open[1] then return; end

    -- Refresh presets if needed
    if gui.refresh_needed then refresh_presets(); end

    -- Ensure ImGuiCond_FirstUseEver is defined (fallback to 8 if not)
    local cond = ImGuiCond_FirstUseEver or 8;

    imgui.SetNextWindowSize(gui.window_size, cond);
    imgui.SetNextWindowPos(gui.window_pos, cond);

    if imgui.Begin('PupSets Preset Viewer', gui.is_open) then
        -- Left panel - preset list
        imgui.BeginChild('PresetList', {150, -1}, true);
        imgui.Text('Saved Presets:');
        imgui.Separator();

        for i, preset in ipairs(gui.presets) do
            if imgui.Selectable(preset.name, gui.selected_preset == i) then
                gui.selected_preset = i;
            end
        end

        imgui.EndChild();

        imgui.SameLine();

        -- Right panel - preset details and settings
        imgui.BeginChild('PresetDetails', {0, -1}, true);

        -- Settings section at the top
        imgui.Text('Settings:');
        imgui.Separator();

                 -- Fast Mode toggle
         local fast_mode_value = {pup.fast_mode};
         if imgui.Checkbox('Fast Mode (for low ping)', fast_mode_value) then
             pup.fast_mode = fast_mode_value[1];
         end
         imgui.SameLine();
         if imgui.Button('?##fastmode', {20, 20}) then
             print(chat.header(addon.name):append(chat.message(
                                                      'Fast Mode: Windower-like speed (0.5s delay). Turn off if attachments are missed.')));
         end

        -- Auto-Activate toggle
        local auto_activate_value = {pup.auto_activate};
        if imgui.Checkbox('Auto-Activate Automaton', auto_activate_value) then
            pup.auto_activate = auto_activate_value[1];
        end

        -- Auto-Deactivate toggle
        local auto_deactivate_value = {pup.auto_deactivate};
        if imgui.Checkbox('Auto-Deactivate Automaton', auto_deactivate_value) then
            pup.auto_deactivate = auto_deactivate_value[1];
        end

        -- Auto-Equip Animator toggle
        local auto_equip_animator_value = {pup.auto_equip_animator};
        if imgui.Checkbox('Auto-Equip Animator', auto_equip_animator_value) then
            pup.auto_equip_animator = auto_equip_animator_value[1];
        end

        

        -- Delay slider (only show if not in fast mode)
        if not pup.fast_mode then
            imgui.Text('Delay: ' .. string.format('%.2f', pup.delay) .. 's');
            local delay_value = {pup.delay};
            if imgui.SliderFloat('##delay', delay_value, 0.1, 2.0, '%.2f') then
                pup.delay = delay_value[1];
            end
        end

        imgui.Separator();
        imgui.Spacing();

        -- Preset details section
        imgui.Text('Preset Details:');
        imgui.Separator();

        if gui.selected_preset and gui.presets[gui.selected_preset] then
            local preset = gui.presets[gui.selected_preset];
            imgui.Text('Selected: ' .. preset.name);

            -- Attachment list
            local slots = {
                'Head', 'Frame', 'Attachment 1', 'Attachment 2', 'Attachment 3',
                'Attachment 4', 'Attachment 5', 'Attachment 6', 'Attachment 7',
                'Attachment 8', 'Attachment 9', 'Attachment 10',
                'Attachment 11', 'Attachment 12'
            };

            imgui.BeginChild('AttachmentList', {0, -80}, true);
            for i = 1, 14 do
                local attachment = preset.attachments[i] or '';
                if attachment ~= '' then
                    imgui.TextColored({0.0, 1.0, 0.0, 1.0}, slots[i] .. ':');
                    imgui.SameLine();
                    imgui.Text(attachment);
                else
                    imgui.TextColored({0.5, 0.5, 0.5, 1.0},
                                      slots[i] .. ': (empty)');
                end
            end
            
            -- Show animator information
            if preset.animator and preset.animator ~= '' then
                imgui.Separator();
                imgui.TextColored({0.0, 1.0, 1.0, 1.0}, 'Animator:');
                imgui.SameLine();
                imgui.Text(preset.animator);
            end
            
            imgui.EndChild();

            -- Load button
            if imgui.Button('Load This Preset', {-1, 30}) then
                AshitaCore:GetChatManager():QueueCommand(1, '/pupsets load ' ..
                                                             preset.name);
            end
        else
            imgui.Text('Select a preset from the left to view details');
        end

        imgui.EndChild();
    end
    imgui.End();
end

--[[
* Prints the addon help information.
*
* @param {boolean} isError - Flag if this function was invoked due to an error.
--]]
local function print_help(isError)
    -- Print the help header..
    if (isError) then
        print(chat.header(addon.name):append(chat.error(
                                                 'Invalid command syntax for command: '))
                  :append(chat.success('/' .. addon.name)));
    else
        print(
            chat.header(addon.name):append(chat.message('Available commands:')));
    end

    local cmds = T {
        {'/pupsets help', 'Shows the addon help.'},
        {'/pupsets list', 'Lists all available attachment list files.'}, {
            '/pupsets load <file>',
            'Loads the PUP attachments from the given attachment list file.'
        }, {
            '/pupsets save <file>',
            'Saves the current set PUP attachments to the given attachment list file.'
        },
        {'/pupsets delete <file>', 'Deletes the given attachment list file.'},
        {
            '/pupsets (clear | reset | unset)',
            'Unsets all currently set PUP attachments.'
        }, {
            '/pupsets set <slot> <attachment>',
            'Sets the given slot to the given PUP attachment by its id.'
        }, {
            '/pupsets setn <slot> <attachment>',
            'Sets the given slot to the given PUP attachment by its name.'
        },
        {'/pupsets debug <on|off>', 'Toggles debug mode for detailed logging.'},
        {'/pupsets config', 'Shows current configuration settings.'}, {
            '/pupsets delay <amount>',
            'Sets the delay, in seconds, between packets that PupSets will use when loading sets.'
        }, {
            '/pupsets fast <on|off>',
            'Toggles fast mode (default). Turn off if attachments are missed.'
        }, {'/pupsets show', 'Shows the preset viewer window.'},
        {'/pupsets hide', 'Hides the preset viewer window.'}, {
            '/pupsets auto-activate <on|off>',
            'Toggles automatic activation after setting attachments.'
        }, {
            '/pupsets auto-deactivate <on|off>',
            'Toggles automatic deactivation before changing attachments.'
        }, {
            '/pupsets auto-equip-animator <on|off>',
            'Toggles automatic animator equipping when loading sets.'
        }, {
            '/pupsets equip-animator <name>',
            'Equips the specified animator to the ranged slot.'
        }
    };

    -- Print the command list..
    cmds:ieach(function(v)
        print(chat.header(addon.name):append(chat.error('Usage: ')):append(
                  chat.message(v[1]):append(' - ')):append(chat.color1(6, v[2])));
    end);
end

--[[
* event: load
* desc : Event called when the addon is being loaded.
--]]
ashita.events.register('load', 'load_cb', function()
    -- Ensure the configuration folder exists..
    local path = ('%s\\config\\addons\\%s\\'):fmt(AshitaCore:GetInstallPath(),
                                                  'pupsets');
    if (not ashita.fs.exists(path)) then ashita.fs.create_dir(path); end
end);

--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command', 'command_cb', function(e)
    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/pupsets', '/pupset', '/ps')) then
        return;
    end

    -- Block all related commands..
    e.blocked = true;

    -- Handle: /pupsets help - Shows the addon help.
    if (#args >= 2 and args[2]:any('help')) then
        print_help(false);
        return;
    end

    -- Handle: /pupsets list - Lists all available attachment list files.
    if (#args >= 2 and args[2]:any('list')) then
        local path = ('%s\\config\\addons\\%s\\'):fmt(
                         AshitaCore:GetInstallPath(), 'pupsets');
        local files = ashita.fs.get_dir(path, '.*.txt', true);
        if (files ~= nil and #files > 0) then
            T(files):each(function(v)
                print(chat.header(addon.name):append(chat.message(
                                                         'Found attachment set file: '))
                          :append(chat.success(v:gsub('.txt', ''))));
            end);
            return;
        end

        print(chat.header(addon.name):append(chat.message(
                                                 'No saved attachment lists found.')));
        return;
    end

    -- Handle: /pupsets load <file> - Loads the PUP attachments from the given attachment list file.
    if (#args >= 3 and args[2]:any('load')) then

        -- Check for PUP main/sub..
        if (not pup.is_pup_cmd_ok(args[2])) then return; end

        local name = args:concat(' ', 3):gsub('.txt', ''):trim();
        local path = ('%s\\config\\addons\\%s\\'):fmt(
                         AshitaCore:GetInstallPath(), 'pupsets');

        -- Check if the file exists..
        if (not ashita.fs.exists(path:append(name:append('.txt')))) then
            print(chat.header(addon.name):append(chat.error(
                                                     'Failed to load attachment list; file does not exist: '))
                      :append(chat.warning(name)));
            return;
        end

        -- Load the attachment file for reading..
        local f = io.open(path:append(name:append('.txt')), 'r');
        if (f == nil) then
            print(chat.header(addon.name):append(chat.error(
                                                     'Failed to open attachment list file for reading: '))
                      :append(chat.warning(name)));
            return;
        end

        -- Read the attachment file lines..
        local attachments = T {};
        local animator = '';
        local line_count = 0;
        
        for line in f:lines() do
            line_count = line_count + 1;
            if line_count <= 14 then
                -- First 14 lines are attachments
                attachments:append(line);
            elseif line_count == 15 and line:trim() ~= '' then
                -- 15th line is animator (if present)
                animator = line:trim();
            end
        end

        f:close();

        if pup.debug then
            for i, v in pairs(attachments) do
                print(chat.header(addon.name):append(
                          chat.message('[' .. i .. ']: '))
                          :append(chat.success(v)));
            end
            if animator ~= '' then
                print(chat.header(addon.name):append(
                          chat.message('[animator]: '))
                          :append(chat.success(animator)));
            end
        end

        -- Determine the delay to be used while setting attachments..
        local delay = pup.delay;
        if (delay < 1 and pup.mode == 'safe') then delay = 1; end

        -- Apply the attachment list..
        ashita.tasks.once(1, (function(d, lst, anim)
                         -- Check for automatic deactivation
             if pup.auto_deactivate and pup.has_pet() then
                 print(chat.header(addon.name):append(chat.message(
                                                          'Auto-deactivating automaton before changing attachments...')));
                 pup.deactivate_automaton();
                 
                 -- Wait for deactivation to complete instead of fixed delay
                 if not pup.wait_for_deactivation() then
                     print(chat.header(addon.name):append(chat.error(
                                                              'Failed to deactivate automaton in time! Aborting attachment changes.')));
                     return;
                 end
             elseif pup.has_pet() then
                 print(chat.header(addon.name):append(chat.error(
                                                          'Pet must be deactivated to change attachments! Enable auto-deactivate or manually deactivate first.')));
                 return;
             end

                                      -- Fast mode - simple and fast like Windower's autocontrol
             if pup.fast_mode then
                 local fast_success_count = 0;
                 local fast_fail_count = 0;
                 local failed_attachments = {};
                 
                 -- Initialize cache for faster lookups
                 pup.init_attachment_cache();

                 -- Just reset everything and set attachments - no checking, no verification
                 print(chat.header(addon.name):append(chat.message(
                                                          'Starting to equip attachments (fast mode)...')));
                 pup.reset_all_attachments();
                 coroutine.sleep(d);
                 
                 -- Extra small delay after reset to ensure game state is clean
                 coroutine.sleep(0.3);

                 -- Set each attachment sequentially with fixed delay
                 lst:each(function(v, k)
                     local result = pup.set_attachment_by_name(k, v);
                     if result then
                         fast_success_count = fast_success_count + 1;
                     else
                         fast_fail_count = fast_fail_count + 1;
                         table.insert(failed_attachments, 'Slot ' .. k .. ': ' .. (v ~= '' and v or 'empty'));
                     end
                     coroutine.sleep(d);
                 end);

                 -- Equip animator if auto-equip is enabled and animator is specified (regardless of attachment success/failure)
                 if pup.auto_equip_animator and anim ~= '' then
                     coroutine.sleep(pup.animator_delay);
                     print(chat.header(addon.name):append(chat.message(
                                                              'Equipping animator: ' .. anim)));
                     pup.equip_animator(anim);
                 end

                 if fast_fail_count > 0 then
                     print(chat.header(addon.name):append(chat.error('Attachment setting failed! The following attachments could not be set:')));
                     for _, failed in ipairs(failed_attachments) do
                         print(chat.header(addon.name):append(chat.warning('  ' .. failed)));
                     end
                     print(chat.header(addon.name):append(chat.message('Please check your attachment names and try again. Automaton will NOT be activated.')));
                 else
                     print(chat.header(addon.name):append(chat.success(
                                                              'Successfully set all attachments!')));

                     -- Auto-activate if enabled (only if no failures)
                     if pup.auto_activate then
                         coroutine.sleep(pup.activate_delay);
                         print(chat.header(addon.name):append(chat.message(
                                                                  'Auto-activating automaton...')));
                         pup.activate_automaton();
                     end
                 end
                 return;
             end

            -- Legacy mode - simple clear all and set from list
            local success_count = 0;
            local fail_count = 0;
            local failed_attachments = {};

            -- Initialize cache for faster lookups
            pup.init_attachment_cache();

            -- Clear all attachments first
            print(chat.header(addon.name):append(chat.message('Clearing all attachments...')));
            pup.reset_all_attachments();
            coroutine.sleep(d);

            -- Set each attachment from the list
            print(chat.header(addon.name):append(chat.message('Setting attachments: 0/' .. #lst .. ' complete')));

            lst:each(function(v, k)
                local result = pup.set_attachment_by_name(k, v);
                
                if result then
                    success_count = success_count + 1;
                else
                    fail_count = fail_count + 1;
                    local failed_entry = 'Slot ' .. k .. ': ' .. (v ~= '' and v or 'empty');
                    table.insert(failed_attachments, failed_entry);
                    print(chat.header(addon.name):append(chat.error('Failed to set ' .. failed_entry)));
                end

                -- Progress update every few attachments or at end
                if (k % 3 == 0) or (k == #lst) then
                    print(chat.header(addon.name):append(chat.message('Progress: ' .. (success_count + fail_count) .. '/' .. #lst .. ' complete (' .. success_count .. ' success, ' .. fail_count .. ' failed)')));
                end

                coroutine.sleep(d);
            end);

            -- Equip animator if auto-equip is enabled and animator is specified (regardless of attachment success/failure)
            if pup.auto_equip_animator and anim ~= '' then
                coroutine.sleep(pup.animator_delay);
                print(chat.header(addon.name):append(chat.message(
                                                         'Equipping animator: ' .. anim)));
                pup.equip_animator(anim);
            end

            if fail_count > 0 then
                print(chat.header(addon.name):append(chat.error('Attachment setting failed! The following attachments could not be set:')));
                for _, failed in ipairs(failed_attachments) do
                    print(chat.header(addon.name):append(chat.warning('  ' .. failed)));
                end
                print(chat.header(addon.name):append(chat.message('Please check your attachment names and try again. Automaton will NOT be activated.')));
            else
                print(chat.header(addon.name):append(chat.success('Successfully set all ' .. success_count .. ' attachments!')));
                
                -- Auto-activate if enabled (only if no failures)
                if pup.auto_activate then
                    coroutine.sleep(pup.activate_delay);
                    print(chat.header(addon.name):append(chat.message(
                                                             'Auto-activating automaton...')));
                    pup.activate_automaton();
                end
            end
        end):bindn(delay, attachments, animator));

        print(chat.header(addon.name):append(chat.message(
                                                 'Setting from attachment set; please wait..')));
        return;
    end

    -- Handle: /pupsets save <file> - Saves the current set PUP attachments to the given attachment list file.
    if (#args >= 3 and args[2]:any('save')) then

        if (not pup.is_pup_cmd_ok(args[2])) then return; end

        local attachments = pup.get_attachments_names();

        if pup.debug then
            for i, v in pairs(attachments) do
                print(chat.header(addon.name):append(
                          chat.message('[' .. i .. ']: '))
                          :append(chat.success(v)));
            end
        end

        -- Determine appropriate animator based on frame
        local frame_name = attachments[2] or ''; -- Frame is in slot 2
        local animator = pup.get_animator_for_frame(frame_name);

        local name = args:concat(' ', 3):gsub('.txt', ''):trim();
        local path = ('%s\\config\\addons\\%s\\%s.txt'):fmt(
                         AshitaCore:GetInstallPath(), 'pupsets', name);
        local f = io.open(path, 'w+');
        if (f == nil) then
            print(chat.header(addon.name):append(chat.error(
                                                     'Failed to open attachment list file for writing.')));
            return;
        end
        
        -- Write attachments first
        f:write(attachments:concat('\n'));
        
        -- Add animator line if auto-equip is enabled
        if pup.auto_equip_animator and animator ~= '' then
            f:write('\n' .. animator);
        end
        
        f:close();

        print(chat.header(addon.name):append(chat.message(
                                                 'Saved attachment list to: '))
                  :append(chat.success(name)));
        if pup.auto_equip_animator and animator ~= '' then
            print(chat.header(addon.name):append(chat.message(
                                                     'Included animator: '))
                      :append(chat.success(animator)));
        end
        gui.refresh_needed = true; -- Refresh the preset viewer
        return;
    end

    -- Handle: /pupsets delete <file> - Deletes the given attachment list file.
    if (#args >= 3 and args[2]:any('delete')) then
        local name = args:concat(' ', 3):gsub('.txt', ''):trim();
        local path = ('%s\\config\\addons\\%s\\'):fmt(
                         AshitaCore:GetInstallPath(), 'pupsets');

        if (not ashita.fs.exists(path:append(name:append('.txt')))) then
            print(chat.header(addon.name):append(chat.error(
                                                     'Failed to delete attachment list; file does not exist: '))
                      :append(chat.warning(name)));
            return;
        end

        ashita.fs.remove(path:append(name:append('.txt')));

        print(chat.header(addon.name):append(chat.message(
                                                 'Deleted attachment list file: '))
                  :append(chat.success(name)));
        gui.refresh_needed = true; -- Refresh the preset viewer
        return;
    end

    -- Handle: /pupsets (clear | reset | unset) - Unsets all currently set PUP attachments.
    if (#args >= 2 and args[2]:any('clear', 'reset', 'unset')) then

        -- Check for PUP main/sub..
        if (not pup.is_pup_cmd_ok(args[2])) then return; end

        pup.reset_all_attachments();

        print(chat.header(addon.name):append(chat.message('Attachments reset.')));
        return;
    end

    -- Handle: /pupsets set <slot> <attachment> - Sets the given slot to the given PUP attachment by its id.
    if (#args >= 4 and args[2]:any('set')) then

        -- Check for PUP main/sub..
        if (not pup.is_pup_cmd_ok(args[2])) then return; end

        pup.set_attachment(args[3]:num(), args[4]:num_or(0));
        return;
    end

    -- Handle: /pupsets setn <slot> <attachment> - Sets the given slot to the given PUP attachment by its name.
    if (#args >= 4 and args[2]:any('setn')) then

        -- Check for PUP main/sub..
        if (not pup.is_pup_cmd_ok(args[2])) then return; end

        pup.set_attachment_by_name(args[3]:num(), args:concat(' ', 4));
        return;
    end

    -- Handle: /pupsets delay <amount> - Sets the delay, in seconds, between packets that PupSets will use when loading sets. (If safe mode is on, minimum is 1 second.)
    if (#args >= 3 and args[2]:any('delay')) then
        pup.delay = args[3]:num_or(1);
        if (pup.delay <= 0) then pup.delay = 1; end

        print(chat.header(addon.name):append(chat.message(
                                                 'PupSets packet delay set to: '))
                  :append(chat.success(pup.delay)));
        return;
    end

    -- Handle: /pupsets debug <on|off> - Toggles debug mode for detailed logging.
    if (#args >= 2 and args[2]:any('debug')) then
        if (#args >= 3) then
            if args[3]:any('on', 'true', '1') then
                pup.debug = true;
            elseif args[3]:any('off', 'false', '0') then
                pup.debug = false;
            else
                pup.debug = not pup.debug;
            end
        else
            pup.debug = not pup.debug;
        end

        print(chat.header(addon.name):append(chat.message('Debug mode: '))
                  :append(chat.success(pup.debug and 'ON' or 'OFF')));
        return;
    end

    -- Handle: /pupsets config - Shows current configuration settings.
    if (#args >= 2 and args[2]:any('config', 'settings')) then
        print(chat.header(addon.name):append(chat.message(
                                                 'Current Configuration:')));
        print(chat.header(addon.name):append(chat.message('  Mode: ')):append(
                  chat.success(pup.mode)));
        print(chat.header(addon.name):append(chat.message('  Delay: ')):append(
                  chat.success(pup.delay .. 's')));
        print(chat.header(addon.name):append(chat.message('  Debug: ')):append(
                  chat.success(pup.debug and 'ON' or 'OFF')));
        print(chat.header(addon.name):append(chat.message('  Fast Mode: '))
                  :append(chat.success(pup.fast_mode and 'ON (Recommended)' or
                                           'OFF (Legacy with verification)')));
        print(chat.header(addon.name):append(chat.message('  Auto-Activate: '))
                  :append(chat.success(pup.auto_activate and 'ON' or 'OFF')));
        print(
            chat.header(addon.name):append(chat.message('  Auto-Deactivate: '))
                :append(chat.success(pup.auto_deactivate and 'ON' or 'OFF')));
        print(chat.header(addon.name):append(chat.message('  Auto-Equip Animator: '))
                  :append(chat.success(pup.auto_equip_animator and 'ON' or 'OFF')));
        print(chat.header(addon.name):append(chat.message('  Animator Delay: '))
                  :append(chat.success(pup.animator_delay .. 's')));
        if not pup.fast_mode then
            print(chat.header(addon.name):append(chat.message(
                                                     '  Retry Attempts: '))
                      :append(chat.success(pup.retry_attempts)));
            print(chat.header(addon.name):append(
                      chat.message('  Verify Delay: ')):append(chat.success(
                                                                   pup.verify_delay ..
                                                                       's')));
            print(chat.header(addon.name):append(chat.message(
                                                     '  Adaptive Delay: '))
                      :append(chat.success(
                                  pup.adaptive_delay and 'ON' or 'OFF')));
        end
        if pup.adaptive_delay then
            print(chat.header(addon.name):append(chat.message('  Base Delay: '))
                      :append(chat.success(pup.base_delay .. 's')));
            print(chat.header(addon.name):append(chat.message('  Max Delay: '))
                      :append(chat.success(pup.max_delay .. 's')));
        end
        return;
    end

    -- Handle: /pupsets fast <on|off> - Toggles fast mode.
    if (#args >= 2 and args[2]:any('fast', 'speed')) then
        if (#args >= 3) then
            if args[3]:any('on', 'true', '1') then
                pup.fast_mode = true;
            elseif args[3]:any('off', 'false', '0') then
                pup.fast_mode = false;
            else
                pup.fast_mode = not pup.fast_mode;
            end
        else
            pup.fast_mode = not pup.fast_mode;
        end

        print(chat.header(addon.name):append(chat.message('Fast Mode: '))
                  :append(chat.success(pup.fast_mode and 'ON (Recommended)' or
                                           'OFF (Legacy mode)')));
        if pup.fast_mode then
            print(chat.header(addon.name):append(chat.message(
                                                     'Fast mode enabled - Windower-like speed with 0.5s delay')));
        else
            print(chat.header(addon.name):append(chat.message(
                                                     'Legacy mode enabled - verification and retry logic active')));
        end
        return;
    end

    -- Handle: /pupsets show - Shows the preset viewer window.
    if (#args >= 2 and args[2]:any('show')) then
        gui.is_open[1] = true;
        gui.refresh_needed = true;
        print(chat.header(addon.name):append(chat.message(
                                                 'Preset viewer window shown.')));
        return;
    end

    -- Handle: /pupsets hide - Hides the preset viewer window.
    if (#args >= 2 and args[2]:any('hide')) then
        gui.is_open[1] = false;
        print(chat.header(addon.name):append(chat.message(
                                                 'Preset viewer window hidden.')));
        return;
    end

    -- Handle: /pupsets auto-activate <on|off> - Toggles automatic activation.
    if (#args >= 2 and args[2]:any('auto-activate', 'autoactivate')) then
        if (#args >= 3) then
            if args[3]:any('on', 'true', '1') then
                pup.auto_activate = true;
            elseif args[3]:any('off', 'false', '0') then
                pup.auto_activate = false;
            else
                pup.auto_activate = not pup.auto_activate;
            end
        else
            pup.auto_activate = not pup.auto_activate;
        end

        print(chat.header(addon.name):append(chat.message('Auto-Activate: '))
                  :append(chat.success(pup.auto_activate and 'ON' or 'OFF')));
        return;
    end

    -- Handle: /pupsets auto-deactivate <on|off> - Toggles automatic deactivation.
    if (#args >= 2 and args[2]:any('auto-deactivate', 'autodeactivate')) then
        if (#args >= 3) then
            if args[3]:any('on', 'true', '1') then
                pup.auto_deactivate = true;
            elseif args[3]:any('off', 'false', '0') then
                pup.auto_deactivate = false;
            else
                pup.auto_deactivate = not pup.auto_deactivate;
            end
        else
            pup.auto_deactivate = not pup.auto_deactivate;
        end

        print(chat.header(addon.name):append(chat.message('Auto-Deactivate: '))
                  :append(chat.success(pup.auto_deactivate and 'ON' or 'OFF')));
        return;
    end

    -- Handle: /pupsets auto-equip-animator <on|off> - Toggles automatic animator equipping.
    if (#args >= 2 and args[2]:any('auto-equip-animator', 'autoequipanimator')) then
        if (#args >= 3) then
            if args[3]:any('on', 'true', '1') then
                pup.auto_equip_animator = true;
            elseif args[3]:any('off', 'false', '0') then
                pup.auto_equip_animator = false;
            else
                pup.auto_equip_animator = not pup.auto_equip_animator;
            end
        else
            pup.auto_equip_animator = not pup.auto_equip_animator;
        end

        print(chat.header(addon.name):append(chat.message('Auto-Equip Animator: '))
                  :append(chat.success(pup.auto_equip_animator and 'ON' or 'OFF')));
        return;
    end

    -- Handle: /pupsets equip-animator <name> - Equips the specified animator.
    if (#args >= 3 and args[2]:any('equip-animator', 'equipanimator')) then
        if (not pup.is_pup_cmd_ok(args[2])) then return; end

        local animator_name = args:concat(' ', 3);
        if pup.equip_animator(animator_name) then
            print(chat.header(addon.name):append(chat.message('Equipping animator: '))
                      :append(chat.success(animator_name)));
        else
            print(chat.header(addon.name):append(chat.error('Failed to equip animator: '))
                      :append(chat.warning(animator_name)));
        end
        return;
    end

    -- Unhandled: Print help information..
    print_help(true);
end);

--[[
* Event called when the addon is being rendered.
*
* @param {object} e - Event information.
--]]
ashita.events.register('d3d_present', 'pupsets_present_cb',
                       function() render_preset_window(); end);
