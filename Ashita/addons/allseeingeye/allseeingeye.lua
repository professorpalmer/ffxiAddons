addon.name      = 'AllSeeingEye';
addon.author    = 'Palmer';
addon.version   = '1.0';

require('common');

---------------------------------------------------------------------------------------------------
-- func: packet_in
-- desc: Called when our addon receives an incoming packet.
---------------------------------------------------------------------------------------------------
ashita.events.register('packet_in', 'packet_in_cb', function (e)
	if (e.id == 0x0E) then -- packet ID 14 (0x0E in hex)
		-- Read status byte at position 0x20 (32 decimal)
		local status = struct.unpack('b', e.data_modified, 0x20 + 1);
		
		if (status == 2 or status == 6 or status == 7) then
			-- Get the packet data as string
			local packet = e.data_modified;
			
			-- Zero out specific bytes based on the original Windower logic
			-- Original: data:sub(1, 32) .. '0' .. data:sub(34, 34) .. '0' .. data:sub(36, 41) .. '0' .. data:sub(43)
			-- This replaces bytes at positions 33, 35, and 42 with '0' (0x30 in ASCII)
			local modified = packet:sub(1, 32) .. '0' .. packet:sub(34, 34) .. '0' .. packet:sub(36, 41) .. '0' .. packet:sub(43);
			
			-- Set the modified packet data
			e.data_modified = modified;
		end
	end
end);

