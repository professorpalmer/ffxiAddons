# TripleFarm - Unified Boss Farming Script

A unified Windower addon that combines the farming capabilities of Quetz.lua, Azi.lua, and Naga.lua into a single script with automatic boss rotation.

## Overview

TripleFarm automates farming for three major bosses:
- **Quetzalcoatl** (Reisenjima)
- **Azi Dahaka** (Escha - Zi'Tah)  
- **Naga Raja** (Escha - Ru'Aun)

The script can either focus on a single boss or automatically rotate between all three bosses based on your configuration.

## Features

- **Automatic Boss Rotation**: Cycles through bosses after a configurable number of kills
- **Single Boss Mode**: Farm only one specific boss
- **Smart Zone Detection**: Automatically teleports to correct zones
- **Elvorseal Management**: Handles getting and renewing elvorseal automatically
- **Trust Summoning**: Automatically summons and re-summons trusts as needed
- **Death Recovery**: Handles player death with automatic raise/release
- **Configurable Settings**: Customize rotation order, kills per boss, teleport rings, etc.

## Prerequisites

### Required Items
- **Dim. Ring (Holla)** - For Quetzalcoatl farming
- **Warp Ring** - For Azi Dahaka and Naga Raja farming

### Required Home Points
- **Qufim Island** - Set as home point for Azi Dahaka farming
- **Misareaux Coast** - Set as home point for Naga Raja farming

### Trust Setup
Configure your trust names in the script variables:
```lua
local trust1 = 'Matsui-P'
local trust2 = 'Koru-Moru'
local trust3 = 'Prishe II'
local trust4 = 'Lilisette II'
local trust5 = 'Nashmeira II'
```

## Installation

1. Place `TripleFarm.lua` in your `Windower/addons/` directory
2. Load the addon: `//lua load TripleFarm`
3. Configure your settings (see Configuration section)

## Commands

### Basic Commands
- `//tf start` - Start farming (default: rotation mode)
- `//tf stop` - Stop farming
- `//tf status` - Show current status and settings

### Boss Selection
- `//tf boss quetz` - Switch to Quetzalcoatl farming
- `//tf boss azi` - Switch to Azi Dahaka farming  
- `//tf boss naga` - Switch to Naga Raja farming

### Rotation Settings
- `//tf rotation on` - Enable automatic boss rotation
- `//tf rotation off` - Disable rotation (single boss mode)
- `//tf kills <number>` - Set kills per boss before rotating
- `//tf next` - Force move to next boss (if rotation enabled)

### Examples
```
//tf start                    # Start rotation farming
//tf boss azi                 # Switch to only Azi Dahaka
//tf rotation off             # Disable rotation
//tf kills 3                  # Set 3 kills per boss
//tf next                     # Force move to next boss
```

## How It Works

### Rotation Mode (Default)
1. Starts with Quetzalcoatl
2. Farms for configured number of kills (default: 1)
3. Teleports to next boss area
4. Repeats cycle: Quetz → Azi → Naga → Quetz...

### Single Boss Mode
1. Farms only the selected boss
2. Re-enters arena after each kill
3. Continues until manually stopped

### Boss Farming Process
For each boss, the script:
1. **Teleports** to the correct zone using appropriate ring
2. **Enters** the target zone (Reisenjima/Escha)
3. **Gets Elvorseal** from the NPC
4. **Warps** into the boss arena
5. **Summons** trusts if needed
6. **Engages** and fights the boss
7. **Tracks** kill count and moves to next boss if rotation enabled

## Configuration

### Teleport Rings
The script uses these rings by default:
- Quetzalcoatl: `"Dim. Ring (Holla)"`
- Azi Dahaka: `"Warp Ring"`
- Naga Raja: `"Warp Ring"`

To change rings, edit the BOSSES configuration in the script.

### Trust Names
Update trust names in the script to match your available trusts:
```lua
local trust1 = 'Your Trust Name'
local trust1_short = 'Short Name'  -- Name as it appears in party
```

### Rotation Order
Default rotation: `{"QUETZ", "AZI", "NAGA"}`

To change the order, modify the `rotation_order` table in the script.

### Boss Positions
Each boss has predefined waiting positions. The script adds random offsets to avoid clustering:
- Quetzalcoatl: X: 612.17, Y: -933.43
- Azi Dahaka: X: -11.00, Y: 37.50  
- Naga Raja: X: 0.00, Y: -210.00

## Zone Requirements

### Quetzalcoatl
- **Entrance Zones**: La Theine Plateau, Konschtat Highlands, Tahrongi Canyon
- **Target Zone**: Reisenjima
- **Portal**: Dimensional Portal
- **NPC**: Shiftrix

### Azi Dahaka  
- **Entrance Zone**: Qufim Island (requires home point)
- **Target Zone**: Escha - Zi'Tah
- **Portal**: Undulating Confluence
- **NPC**: Affi

### Naga Raja
- **Entrance Zone**: Misareaux Coast (requires home point)
- **Target Zone**: Escha - Ru'Aun  
- **Portal**: Undulating Confluence
- **NPC**: Dremi

## Safety Features

- **State Validation**: Checks player and zone data before actions
- **Error Logging**: Logs warnings when mobs/NPCs cannot be found
- **Automatic Pause**: Pauses script if state validation fails
- **Death Recovery**: Handles automatic raise/release on death
- **Buff Checking**: Verifies elvorseal status before actions

## Troubleshooting

### Script Not Working
1. Check that you have the required rings equipped or in inventory
2. Verify home points are set correctly (Qufim, Misareaux Coast)
3. Make sure you're in a valid starting zone
4. Check trust names match your available trusts

### Boss Not Found
- Ensure you're in the correct zone for the current boss
- Check that the boss name matches exactly (case sensitive)
- Try reloading the script: `//lua reload TripleFarm`

### Stuck in Menu
- The script automatically sends escape key presses
- If stuck, manually press escape and restart: `//tf stop` then `//tf start`

### Teleport Issues
- Verify ring names match your inventory exactly
- Check that rings are not equipped in conflicting slots
- Ensure sufficient ring charges

## Tips

1. **Start Fresh**: Begin farming from a home point or major city
2. **Monitor First Run**: Watch the first rotation to ensure smooth transitions
3. **Check Inventory**: Ensure adequate inventory space for drops
4. **Trust Recasts**: Script waits for trust recast timers automatically
5. **Home Points**: Set appropriate home points before starting

## Original Scripts Credit

This unified script is based on the excellent work of:
- **Erupt** - Original author of Quetz.lua, Azi.lua, and Naga.lua
- **Kaotic & Otamarai** - Contributors to the original Quetz script

## Version History

- **v3.0** - Initial unified script with rotation system
- Based on individual scripts v2.05

## Support

For issues or improvements:
1. Check this README for common solutions
2. Verify your setup matches the requirements
3. Test with individual boss modes before using rotation
4. Report specific error messages and circumstances 