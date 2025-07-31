require('common');
local chat = require('chat');
local ffi = require('ffi');

-- FFI Prototypes
ffi.cdef [[
    /**
     * Extended equip packet sender. Used for BLU spells, PUP attachments, etc.
     *
     * @param {uint8_t} isSubJob - Flag if the used job is currently subbed or not. (ie. If using BLU, is BLU subbed?)
     * @param {uint16_t} jobType - Flag used for the job packet type. (BLU = 0x1000, PUP = 0x1200)
     * @param {uint16_t} index - The index of the slot being manipulated. (ie. The BLU spell slot.)
     * @param {uint8_t} id - The id of the spell, attachment, etc. being set. (BLU spells are id - 512.)
     * @return {uint8_t} 1 on success, 0 otherwise.
     * @note
     *  This calls the in-game function that is used to send the 0x102 packets.
     */
    typedef uint8_t (__cdecl *equipex_t)(uint8_t isSubJob, uint16_t jobType, uint16_t index, uint8_t id);

    // Packet: 0x0102 - Extended Equip (Client To Server)
    typedef struct packet_equipex_c2s_t {
        uint16_t    IdSize;             /* Packet id and size. */
        uint16_t    Sync;               /* Packet sync count. */
        uint8_t     SpellId;            /* If setting a spell, this is set to the spell id being placed in a 'Spells' entry. If unsetting, it is set to 0. */
        uint8_t     Unknown0000;        /* Forced to 0 by the client. */
        uint16_t    Unknown0001;        /* Unused. */

        /**
         * The following data is job specific, this is how it is defined for BLU.
         */

        uint8_t     JobId;              /* Set to 0x10, BLU's job id. Set to 0x12, PUP's job id. */
        uint8_t     IsSubJob;           /* Flag set if BLU is currently the players sub job. */
        uint16_t    Unknown0002;        /* Unused. (Padding) */
        uint8_t     Spells[20];         /* Array of the BLU spell slots. PUP: [1]=head, [2]=frame, [3-14]=attachments, [15-20]=unused */
        uint8_t     Unknown0003[132];   /* Unused. */
    } packet_equipex_c2s_t;
]];

-- Blue Mage Helper Library
local pup = T {
    offset = ffi.cast('uint32_t*', ashita.memory.find('FFXiMain.dll', 0,
                                                      'C1E1032BC8B0018D????????????B9????????F3A55F5E5B',
                                                      10, 0)),
    equipex = ffi.cast('equipex_t', ashita.memory.find('FFXiMain.dll', 0,
                                                       '8B0D????????81EC9C00000085C95356570F??????????8B',
                                                       0, 0)),

    -- Memory offsets for PUP head/frame and attachments
    equipOffset = 0x2000, -- head/frame
    attachOffset = 0x2100, -- attachments

    -- Animator settings
    auto_equip_animator = true, -- Automatically equip animator when loading sets
    animator_delay = 0.5, -- Delay after setting attachments before equipping animator

    --[[
    Packet Sender Mode

    Sets the mode that will be used when queueing and sending packets by pupsets.

        safe - Uses the games actual functions to rate limit and send the packet properly.
        fast - Uses custom injected packets with custom rate limiting to bypass the internal client buffer limit.
    --]]
    mode = 'fast',

    -- The delay between packet sends when loading a attachment set
    delay = 0.6,

    -- Speed mode - legacy by default, fast mode available for low ping users
    fast_mode = false, -- Default to legacy mode (better for higher ping)

    -- Legacy settings (used when fast_mode is disabled)
    retry_attempts = 3,
    verify_delay = 0.2,
    adaptive_delay = true,
    base_delay = 0.25,
    max_delay = 1.5,

    -- Cache for attachment name-to-ID lookups to avoid repeated resource manager calls
    attachment_cache = {},
    cache_initialized = false,

    -- Auto pet management settings
    auto_activate = true, -- Automatically activate after setting attachments
    auto_deactivate = true, -- Automatically deactivate before changing attachments
    activate_delay = 1.0, -- Delay after setting attachments before activating
    deactivate_delay = 2.0, -- Delay after deactivating before changing attachments
    
    -- Debug mode
    debug = false
};

--[[
* Waits for the automaton to be fully deactivated
* This is critical to prevent attachment setting failures
--]]
function pup.wait_for_deactivation()
    local max_wait_time = 5.0; -- Maximum time to wait (seconds)
    local check_interval = 0.1; -- How often to check (seconds)
    local elapsed = 0;
    
    while pup.has_pet() and elapsed < max_wait_time do
        coroutine.sleep(check_interval);
        elapsed = elapsed + check_interval;
        
        if pup.debug and (elapsed % 1.0 < check_interval) then
            print(chat.header(addon.name):append(chat.message('Waiting for deactivation... (' .. string.format('%.1f', elapsed) .. 's)')));
        end
    end
    
    if pup.has_pet() then
        if pup.debug then
            print(chat.header(addon.name):append(chat.warning('Deactivation timeout - automaton may still be active!')));
        end
        return false;
    else
        if pup.debug then
            print(chat.header(addon.name):append(chat.success('Automaton fully deactivated in ' .. string.format('%.1f', elapsed) .. 's')));
        end
        return true;
    end
end

--[[
* Equips an animator to the ranged slot
*
* @param {string} animator_name - The name of the animator to equip
* @return {boolean} True if successful, false otherwise
--]]
function pup.equip_animator(animator_name)
    if not animator_name or animator_name == '' then
        return false;
    end
    
    -- Use Ashita's equipment system to equip the animator
    local command = ('/equip range "%s"'):fmt(animator_name);
    AshitaCore:GetChatManager():QueueCommand(1, command);
    
    if pup.debug then
        print(chat.header(addon.name):append(chat.message('Equipping animator: ' .. animator_name)));
    end
    
    return true;
end

--[[
* Determines the appropriate animator based on frame type
*
* @param {string} frame_name - The name of the frame
* @return {string} The appropriate animator name
--]]
function pup.get_animator_for_frame(frame_name)
    if not frame_name then return ''; end
    
    local frame_lower = frame_name:lower();
    
    -- Melee frames - use Animator P +1
    if frame_lower:find('turtle') or frame_lower:find('dd') or 
       frame_lower:find('bruiser') or frame_lower:find('mdtank') or
       frame_lower:find('valoredge') or frame_lower:find('sharpshot') then
        return 'Animator P +1';
    end
    
    -- Ranged/Mage frames - use Animator P II +1
    if frame_lower:find('rng') or frame_lower:find('rngtank') or
       frame_lower:find('blm') or frame_lower:find('whm') or 
       frame_lower:find('rdm') or frame_lower:find('soulsoother') or
       frame_lower:find('spiritreaver') then
        return 'Animator P II +1';
    end
    
    -- Default to melee animator if frame type is unclear
    return 'Animator P +1';
end

--[[
* Returns if the player has an active automaton
*
* @return {boolean} True if automaton is active, false otherwise.
--]]
function pup.has_pet()
    local myIndex = AshitaCore:GetMemoryManager():GetParty()
                        :GetMemberTargetIndex(0);
    local petIndex = AshitaCore:GetMemoryManager():GetEntity()
                         :GetPetTargetIndex(myIndex);
    return petIndex ~= 0;
end

--[[
* Activates the automaton using the Activate ability
--]]
function pup.activate_automaton()
    if not pup.has_pet() then
        AshitaCore:GetChatManager():QueueCommand(1, '/ja "Activate" <me>');
        if pup.debug then
            print(chat.header(addon.name):append(chat.message(
                                                     'Activating automaton...')));
        end
    end
end

--[[
* Deactivates the automaton using the Deactivate ability
--]]
function pup.deactivate_automaton()
    if pup.has_pet() then
        AshitaCore:GetChatManager():QueueCommand(1, '/ja "Deactivate" <me>');
        if pup.debug then
            print(chat.header(addon.name):append(chat.message(
                                                     'Deactivating automaton...')));
        end
    end
end

--[[
* Returns if the players main job is PUP.
*
* @return {boolean} True if PUP main, false otherwise.
--]]
function pup.is_pup_main()
    return AshitaCore:GetMemoryManager():GetPlayer():GetMainJob() == 18;
end

--[[
* Returns if the players sub job is PUP.
*
* @return {boolean} True if PUP sub, false otherwise.
--]]
function pup.is_pup_sub()
    return AshitaCore:GetMemoryManager():GetPlayer():GetSubJob() == 18;
end

--[[
* Returns if the players main or sub job is PUP. Prints error if false.
*
* @return {boolean} True if PUP main or sub, false otherwise.
--]]
function pup.is_pup_cmd_ok(cmd)
    if (not pup.is_pup_main() and not pup.is_pup_sub()) then
        print(chat.header(addon.name):append(chat.error(
                                                 'Must be PUP main or sub to use /pupset ' ..
                                                     cmd .. '!')));
        return false;
    else
        return true;
    end
end

--[[
* Initializes the attachment name-to-ID cache for faster lookups
--]]
function pup.init_attachment_cache()
    if pup.cache_initialized then return; end

    pup.attachment_cache = {};

    -- Cache head attachments (1-7)
    for i = 1, 7 do
        local item = AshitaCore:GetResourceManager():GetItemById(
                         pup.equipOffset + i);
        if item ~= nil and item.Name[1] ~= '.' then
            pup.attachment_cache[item.Name[1]] = {id = i, type = 'head'};
        end
    end

    -- Cache frame attachments (32-39)
    for i = 32, 39 do
        local item = AshitaCore:GetResourceManager():GetItemById(
                         pup.equipOffset + i);
        if item ~= nil and item.Name[1] ~= '.' then
            pup.attachment_cache[item.Name[1]] = {id = i, type = 'frame'};
        end
    end

    -- Cache regular attachments (1-254)
    for i = 1, 254 do
        local item = AshitaCore:GetResourceManager():GetItemById(
                         pup.attachOffset + i);
        if item ~= nil and item.Name[1] ~= '.' then
            pup.attachment_cache[item.Name[1]] = {id = i, type = 'attachment'};
        end
    end

    pup.cache_initialized = true;
    if pup.debug then
        print(chat.header(addon.name):append(chat.success(
                                                 'Attachment cache initialized with ' ..
                                                     table.getn(
                                                         pup.attachment_cache) ..
                                                     ' entries')));
    end
end

--[[
* Fast lookup of attachment ID by name using cache
*
* @param {string} name - The attachment name to look up
* @param {number} slot_index - The slot index (1=head, 2=frame, 3+=attachment)
* @return {number|nil} The attachment ID or nil if not found
--]]
function pup.get_attachment_id_cached(name, slot_index)
    if not pup.cache_initialized then pup.init_attachment_cache(); end

    local cached = pup.attachment_cache[name];
    if cached then
        -- Validate the attachment type matches the slot
        if (slot_index == 1 and cached.type == 'head') or
            (slot_index == 2 and cached.type == 'frame') or
            (slot_index > 2 and cached.type == 'attachment') then
            return cached.id;
        end
    end
    return nil;
end

--[[
* Returns the raw buffer used in PUP attachment packets.
*
* @return {number} The current PUP raw buffer pointer.
* @note
*   On private servers, there is a rare chance this buffer is not properly updated immediately until you open an
*   equipment menu or open the PUP set attachments window. Because of this, you may send a bad job id for the packets
*   that rely on this buffers data if used directly.
--]]
function pup.get_pup_buffer_ptr()
    local ptr = ashita.memory.read_uint32(
                    AshitaCore:GetPointerManager():Get('inventory'));
    if (ptr == 0) then return 0; end
    ptr = ashita.memory.read_uint32(ptr);
    if (ptr == 0) then return 0; end
    return ptr + pup.offset[0] + (pup.is_pup_main() and 0x00 or 0x9C);
end

--[[
* Returns the table of current set PUP attachments.
*
* @return {table} The current set PUP attachments.
--]]
function pup.get_attachments()
    local ptr = ashita.memory.read_uint32(
                    AshitaCore:GetPointerManager():Get('inventory'));
    if (ptr == 0) then return T {}; end
    ptr = ashita.memory.read_uint32(ptr);
    if (ptr == 0) then return T {}; end
    return T(ashita.memory.read_array((ptr + pup.offset[0]) +
                                          (pup.is_pup_main() and 0x04 or 0xA0),
                                      0xE));
end

--[[
* Returns the table of current set PUP attachments names.
*
* @return {table} The current set PUP attachments names.
--]]
function pup.get_attachments_names()
    local data = pup.get_attachments();
    for k, v in pairs(data) do
        if (k < 3) then -- head and frame
            data[k] = AshitaCore:GetResourceManager():GetItemById(v +
                                                                      pup.equipOffset);
        else -- attachment
            data[k] = AshitaCore:GetResourceManager():GetItemById(v +
                                                                      pup.attachOffset);
        end
        if (data[k] ~= nil and data[k].Name[1] ~= '.') then
            data[k] = data[k].Name[1];
        else
            data[k] = '';
        end
    end
    return data;
end

--[[
* Resets all of the players current set PUP attachments. (safe)
*
* Uses the in-game packet queue to properly queue a reset packet.
--]]
local function safe_reset_all_attachments()
    AshitaCore:GetPacketManager():QueuePacket(0x102, 0xA4, 0x00, 0x00, 0x00,
                                              function(ptr)
        local p = ffi.cast('uint8_t*', ptr);
        ffi.fill(p + 0x04, 0xA0);
        ffi.copy(p + 0x08, ffi.cast('uint8_t*', pup.get_pup_buffer_ptr()), 0x9C);
        ffi.fill(p + 0x0C, 0x2); -- zero out head and frame IDs
    end);
end

--[[
* Sets a PUP attachment for the give slot index. (safe)
*
* @param {number} index - The slot index to set. (1 to 10)
* @param {number} id - The attachment id to set. (0 if unsetting.)
*
* Uses actual client function used to set PUP attachments to safely and properly queue the packet.
--]]
local function safe_set_attachment(index, id)
    pup.equipex(pup.is_pup_main() == true and 0 or 1, 0x1200, index - 1, id);
end

--[[
* Verifies if an attachment was successfully set in the given slot
*
* @param {number} index - The slot index to check
* @param {number} expected_id - The attachment id that should be set
* @return {boolean} True if the attachment matches, false otherwise
--]]
local function verify_attachment(index, expected_id)
    local attachments = pup.get_attachments();
    return attachments[index] == expected_id;
end

--[[
* Sets an attachment with retry logic and verification
*
* @param {number} index - The slot index to set
* @param {number} id - The attachment id to set
* @param {number} attempt - Current attempt number (for recursion)
* @return {boolean} True if successful, false if all retries failed
--]]
local function set_attachment_with_retry(index, id, attempt)
    attempt = attempt or 1;

    -- Set the attachment
    safe_set_attachment(index, id);

    -- Wait for verification delay
    local verify_delay = pup.ultra_fast_mode and pup.ultra_fast_verify_delay or
                             pup.verify_delay;
    coroutine.sleep(verify_delay);

    -- Verify the attachment was set
    if verify_attachment(index, id) then return true; end

    -- If failed and we have retries left, try again
    if attempt < pup.retry_attempts then
        local delay = pup.adaptive_delay and
                          math.min(pup.base_delay * attempt, pup.max_delay) or
                          pup.delay;
        if pup.debug then
            print(chat.header(addon.name):append(
                      chat.warning('Retry ' .. (attempt + 1) .. ' for slot ' ..
                                       index .. ' with delay ' .. delay)));
        end
        coroutine.sleep(delay);
        return set_attachment_with_retry(index, id, attempt + 1);
    end

    return false;
end

--[[
* Queues the packet required to unset all PUP attachments.
--]]
function pup.reset_all_attachments() safe_reset_all_attachments(); end

--[[
* Queues the packet required to set a PUP attachment. (Or unset.)
*
* @param {number} index - The slot index to set.
* @param {number} id - The attachment id to set. (0 if unsetting.)
* @return {boolean} True if successful, false otherwise
--]]
function pup.set_attachment(index, id)
    if (index <= 0 or index > 14) then
        print(chat.header(addon.name):append(chat.error(
                                                 'Failed to set attachment; invalid index given. (Params - Index: %d, Id: %d)'))
                  :fmt(index, id));
        return false;
    end

    -- In fast mode, skip all checks and verification for maximum speed
    if pup.fast_mode then
        safe_set_attachment(index, id);
        return true;
    end

    -- Check if the attachment is set elsewhere already..
    local attachments = pup.get_attachments();
    local equip = attachments:slice(1, 2);
    local attach = attachments:slice(3, 12);
    if (id ~= 0 and index < 3 and equip:hasval(id)) then
        return true; -- Already set correctly
    elseif (id ~= 0 and index > 2 and attach:hasval(id)) then
        print(chat.header(addon.name):append(chat.error(
                                                 'Failed to set attachment; attachment is already assigned. (Params - Index: %d, Id: %d)'))
                  :fmt(index, id));
        return false;
    end

    -- Check if the attachment is being unset and has a attachment in the desired slot..
    local attachment = attachments[index];
    if (id == 0 and (attachment == nil or attachment == 0)) then
        return true; -- Already unset
    end

    -- Set the attachment with retry logic..
    return set_attachment_with_retry(index, id);
end

--[[
* Sets the given slot index to the attachment matching the given name. If no name is given, the slot is unset.
*
* @param {number} index - The slot index to set the attachment into.
* @param {string|nil} name - The name of the attachment to set. (nil if unsetting attachment.)
* @return {boolean} True if successful, false otherwise
--]]
function pup.set_attachment_by_name(index, name)
    -- Unset the attachment if no name is given..
    if (name == nil or name == '') then return pup.set_attachment(index, 0); end

    -- Use cached lookup for faster performance
    local id = pup.get_attachment_id_cached(name, index);
    if (id == nil) then
        print(chat.header(addon.name):append(chat.error(
                                                 'Failed to set attachment; invalid attachment name given. (Params - Index: %d, Name: %s)'))
                  :fmt(index, name));
        return false;
    end

    -- Set the attachment..
    return pup.set_attachment(index, id);
end

-- Return the library table..
return pup;
