# SuperWarp (Ashita Version)

**Simplified homepoint teleportation system for Ashita 4**

Converted from the original Windower SuperWarp by Akaden. This Ashita version focuses on the core homepoint functionality needed by TripleFarm and other automated farming systems.

## Features

- 🏠 **Homepoint Teleportation** - Instant travel to any unlocked homepoint
- ⚡ **Simple Commands** - Easy `//hp <zone>` syntax
- 🎯 **TripleFarm Integration** - Designed specifically for boss farming rotations
- 🔒 **Safety Checks** - Validates homepoint unlock status and proximity
- 📦 **Lightweight** - Focused implementation without unnecessary features

## Installation

1. Place `superwarp.lua` in your `Ashita/addons/superwarp/` folder
2. Load the addon: `/addon load superwarp`
3. You're ready to teleport!

## Commands

### Basic Homepoint Teleportation
```
/hp <zone_name>
```

### Available Zones
- **qufim** - Qufim Island (for Azi Dahaka farming)
- **misareaux** - Misareaux Coast (for Naga Raja farming)  
- **jeuno** - Port Jeuno
- **bastok** - Bastok Markets
- **windurst** - Windurst Waters
- **sandoria** - Southern San d'Oria

### Help Commands
```
/superwarp help     - Show command help
/superwarp status   - Show current addon status
```

## Usage Examples

### Basic Teleportation
```bash
# Teleport to Qufim Island (for Azi farming)
/hp qufim

# Teleport to Misareaux Coast (for Naga farming)  
/hp misareaux

# Teleport to Jeuno
/hp jeuno
```

### TripleFarm Integration
This addon is designed to work seamlessly with TripleFarm:

```lua
-- In TripleFarm.lua, these commands now work in Ashita:
windower.send_command('wait 8;hp misareaux')  -- Travel to Misareaux Coast
windower.send_command('wait 8;hp qufim')      -- Travel to Qufim Island
```

## Requirements

- **Ashita 4** - Latest version recommended
- **Homepoint Access** - Target homepoints must be unlocked
- **Proximity** - Must be within 6.0 units of a homepoint to use

## How It Works

1. **Command Input** - User types `/hp <zone>`
2. **Validation** - Checks if zone exists and homepoint is unlocked
3. **NPC Detection** - Finds nearby homepoint NPC automatically
4. **Packet Injection** - Sends proper interaction and menu packets
5. **Teleportation** - Character warps to destination homepoint

## Technical Details

### Packet Structure
- **Interaction Packet (0x1A)** - Initiates NPC interaction
- **Menu Packet (0x5B)** - Sends teleport request with destination
- **Menu Response (0x34)** - Receives homepoint menu for processing

### Zone Data
Each homepoint contains:
```lua
{
    name = 'Zone Display Name',
    index = 114,           -- Homepoint index for packets
    expac = 0,            -- Expansion requirement
    zone_id = 126,        -- Zone ID for validation
    npc_id = 521          -- NPC ID (reference only)
}
```

## Troubleshooting

### "No homepoint found nearby!"
- Move closer to a homepoint NPC
- Ensure you're in a zone with homepoints

### "Unknown homepoint zone"
- Check spelling of zone name
- Use `//superwarp help` to see available zones

### "Homepoint menu timeout"
- Try again - sometimes packets get delayed
- Ensure homepoint NPC is not busy

### Adding New Zones
To add more homepoint destinations, edit the `homepoint_data` table in `superwarp.lua`:

```lua
['newzone'] = {
    name = 'New Zone Name',
    index = 123,          -- Get from original SuperWarp data
    expac = 0,           -- Expansion requirement
    zone_id = 456,       -- Zone ID
    npc_id = 789         -- NPC ID
}
```

## Differences from Windower SuperWarp

This Ashita version is **intentionally simplified** and focuses only on:
- ✅ Homepoint teleportation
- ✅ Basic zone support
- ✅ TripleFarm compatibility

**Not included** (from original SuperWarp):
- ❌ Waypoints, Survival Guides
- ❌ Escha portals, Unity warps
- ❌ Abyssea, Sortie, Odyssey
- ❌ Multi-character IPC
- ❌ Advanced configuration options

## Version History

### 1.0.0 - Initial Ashita Release
- ✅ Core homepoint teleportation
- ✅ Six major city/zone support
- ✅ TripleFarm integration ready
- ✅ Packet validation and error handling

## Credits

- **Original Author**: Akaden (Windower SuperWarp)
- **Ashita Conversion**: Palmer (Zodiarchy @ Asura)
- **Purpose**: TripleFarm automated boss farming support

---

**Perfect for TripleFarm users who want seamless homepoint teleportation in Ashita!** 🎯 