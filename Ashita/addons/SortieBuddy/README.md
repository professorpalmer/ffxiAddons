# Sortie Buddy - Ashita 4

**Sortie target tracking and distance display for Ashita 4**

Originally created for Windower, now fully converted to work with Ashita 4!

⚠️ **Use at your own risk!**

## Features

- 🎯 **Long-range targeting** - Target mobs beyond normal range using packet injection
- 📏 **Distance & direction display** - Real-time distance and compass direction to targets
- 💾 **Persistent mob database** - Save and manage target locations across sessions
- 🖥️ **Modern ImGui interface** - Clean, draggable display window
- ⚡ **Pre-configured for Sortie** - All basement bosses ready to go

## How to Use

### Loading the Addon
```
/addon load sortiebuddy
```

### Pre-configured Sortie Targets
Default settings include all Sortie basement bosses:
- **a** = Abject Obdella
- **b** = Biune Porxie  
- **c** = Cachaemic Bhoot
- **d** = Demisang Deleterious
- **f** = Diaphanous Bitzer #F
- **g** = Diaphanous Bitzer #G
- **h** = Diaphanous Bitzer #H

### Basic Usage

**In Sortie** - Use ping command after zoning into any basement floor:
```
/sortiebuddy ping a    # Targets and shows distance to Abject Obdella
```

**Custom Targets** - Add your own targets anywhere:
1. Target something (e.g., Mireu)
2. Use `/sortiebuddy add mireu` 
3. Later use `/sortiebuddy ping mireu` or `/sortiebuddy spawn mireu`

## Commands

Use `/sortiebuddy` or `/srtb` as shortcuts:

### `/sortiebuddy ping <name>`
> Injects targeting packet and displays distance/direction in ImGui window

### `/sortiebuddy spawn <name>`  
> Injects targeting packet only (no distance display)

### `/sortiebuddy add <name>`
> Save your current target to settings for the current zone

### `/sortiebuddy remove <zone_id> <name>`
> Remove a saved target from specified zone

### `/sortiebuddy showinfo`
> Display current zone and all saved targets for this zone

## Examples

```bash
# Check what zone you're in and what targets are saved
/sortiebuddy showinfo

# In Sortie basement A, target and track Abject Obdella  
/sortiebuddy ping a

# Add a custom target (target it first!)
/sortiebuddy add myboss

# Remove a custom target
/sortiebuddy remove 247 myboss

# Just target without distance display
/sortiebuddy spawn f
```

## Installation

1. Place `SortieBuddy.lua` in `Ashita/addons/SortieBuddy/`
2. Load with `/addon load sortiebuddy`
3. Use `/sortiebuddy help` to see all commands

## Technical Notes

- **Packet Injection**: Uses proper Ashita 4 packet manager for targeting
- **Settings**: Automatically saves to Ashita settings system
- **Display**: Modern ImGui interface with customizable colors
- **Zone Support**: Works in any zone, not just Sortie

## Known Issues

⚠️ **Injecting targeting packets on certain mobs might crash the game!**
- Test carefully with new targets
- Use `/sortiebuddy spawn` first to test targeting safety

## Version History

### 1.2.0 - Ashita 4 Conversion
- **Complete rewrite** for Ashita 4 compatibility
- Replaced Windower texts with ImGui display
- Updated packet injection to use Ashita packet manager  
- Converted settings system to Ashita settings module
- Modernized event handling and command system
- Improved packet structure using struct.pack()
- Added proper error handling and validation

### 1.1.2 - Windower (Legacy)
- Fix spawn command

### 1.1.1 - Windower (Legacy)  
- Fix lua runtime error. Need to save keys as string, not number

### 1.1.0 - Windower (Legacy)
- Moved configuration to settings
- Added spawn, add, remove command

### 1.0.2 - Windower (Legacy)
- Fix info not showing if loaded addon while in sortie
- Fix nil error when zoning out

### 1.0.1 - Windower (Legacy)
- Add shortcut //srtb
- Don't use name from packet, sometimes it's crap

### 1.0.0 - Windower (Legacy)
- First version

---

**Converted to Ashita 4 by Palmer (Zodiarchy @ Asura)**  
**Original Windower version by Dabidobido**