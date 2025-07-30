# AutoCOR v2.0.0 - Professional UI Edition

## Overview
AutoCOR has been completely redesigned with a modern, professional UI system that rivals desktop applications. Gone are the days of basic text displays - welcome to the future of Windower addons!

## New Features

### 🎨 **Professional UI System**
- **Modern Interface**: Clean, professional appearance with custom graphics
- **Interactive Buttons**: Click buttons instead of typing commands
- **Real-time Updates**: Status displays update instantly
- **Drag & Drop**: Move the UI anywhere on screen
- **Scalable Design**: Adapts to different screen resolutions

### 🎯 **Visual Roll Status**
- **Live Roll Values**: See current roll values and lucky/unlucky status
- **Color-coded Indicators**: Green for lucky, red for unlucky
- **Party AoE Status**: Visual indicators for each party member's AoE range

### 🎮 **Interactive Controls**
- **One-Click Toggle**: Turn AutoCOR on/off with a single click
- **Roll Configuration**: Change rolls directly from the UI
- **Feature Toggles**: Enable/disable Crooked Cards, Quick Draw, Random Deal
- **Party Management**: Visual party member AoE controls

## UI Layout

```
┌─────────────────────────────────────────────────────────┐
│ AUTOCOR CONTROL PANEL                                  │
│                                                         │
│ [AutoCOR OFF]  [Roll 1: Corsair's]  [Roll 2: Chaos]   │
│                                                         │
│ Status:                                                │
│ Corsair's Roll: 5/11 (Lucky!)                         │
│ Chaos Roll: 4/8 (Normal)                              │
│ Party AoE: All Active                                  │
│                                                         │
│ [Crooked Cards ON] [Auto QD OFF] [Auto RD OFF]        │
│                                                         │
│ Party: [P1✓] [P2✓] [P3✓] [P4✓] [P5✓]                │
└─────────────────────────────────────────────────────────┘
```

## Commands

### Basic Commands
- `//cor` - Toggle AutoCOR on/off
- `//cor on` - Turn AutoCOR on
- `//cor off` - Turn AutoCOR off

### Roll Configuration
- `//cor roll 1 [roll name]` - Set first roll
- `//cor roll 2 [roll name]` - Set second roll
- `//cor roll 1 none` - Disable first roll

### Feature Toggles
- `//cor cc [number]` - Set Crooked Cards usage (0 = off, 1+ = on)
- `//cor autodraw` - Toggle Auto Quick Draw
- `//cor autorandom` - Toggle Auto Random Deal

### Party Management
- `//cor aoe [slot]` - Toggle AoE for party member
- `//cor aoe [name]` - Toggle AoE for specific player

### Settings
- `//cor save` - Save current settings
- `//cor eval [lua code]` - Execute Lua code

## Technical Details

### UI System
The new UI uses Windower's primitive rendering system (`windower.prim`) to create a professional interface that:
- **Bypasses chat limitations** - No more text-based displays
- **Supports full mouse interaction** - Click, drag, hover effects
- **Provides pixel-perfect positioning** - Place elements anywhere on screen
- **Enables real-time updates** - Instant visual feedback

### Asset System
- **Pre-drawn PNG buttons** - Professional appearance
- **Dynamic scaling** - Adapts to different resolutions
- **Color-coded states** - Visual feedback for all status

### Event Handling
- **Mouse click detection** - Left, right, middle clicks
- **Drag and drop support** - Move UI elements
- **Hover effects** - Visual feedback on mouse over
- **Scroll support** - Mouse wheel interaction

## Installation

1. Copy the entire `Autocor` folder to your Windower addons directory
2. Ensure the `data` folder contains the button PNG files
3. Load the addon with `//lua load autocor`

## Configuration

The UI position and scaling can be adjusted in `data/settings.xml`:
- `top_left.x/y` - UI position on screen
- `user_ui_scalar` - UI scaling factor
- `ui_hidden` - Show/hide UI

## Compatibility

- **Windower 4+** required
- **FFXI** - All versions supported
- **COR job** - Main or sub job

## Credits

- **Original AutoCOR**: Ivaar|Relisaa
- **UI System**: Based on SmartSkillup by RolandJ
- **Professional UI**: Enhanced by AI Assistant

## Version History

### v2.0.0 - Professional UI Edition
- Complete UI redesign with modern interface
- Interactive buttons and real-time status displays
- Visual roll value tracking with lucky/unlucky indicators
- Party AoE status visualization
- Drag & drop support
- Scalable design for different resolutions

### v1.20.07.19 - Original Version
- Basic text-based interface
- Core AutoCOR functionality
- Command-line configuration

---

**Transform your AutoCOR experience from basic text to professional UI!** 