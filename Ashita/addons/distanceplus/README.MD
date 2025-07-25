# DistancePlus

A highly configurable distance tracking addon for Ashita v4 that displays real-time distance information with job-specific range calculations for optimal combat effectiveness.

![DistancePlus Demo](https://img.shields.io/badge/Ashita-v4-blue) ![License](https://img.shields.io/badge/license-GPL--3.0-green)

## Features

### 🎯 **Smart Distance Calculation**
- **Job-specific range modes** with accurate hit calculations
- **Gun/Bow/Crossbow modes** showing optimal shooting ranges with color coding
- **Magic/Ninjutsu modes** for spell casting range
- **Pet distance tracking** with BST-specific range calculations

### 🎨 **Dual Visual Styles**
- **Modern Style**: Rounded corners, semi-transparent backgrounds, red title bars
- **Classic Style**: Clean black boxes with no borders or title bars (traditional FFXI look)

### ⚙️ **Full GUI Configuration**
- **Dynamic window sizing** (70-400px range)
- **Real-time style switching** between modern and classic modes
- **Customizable transparency, rounding, and padding**
- **Toggle features** on/off (mode indicators, pet windows, text centering)

### 🎮 **Range Mode Color Coding**

| Color | Meaning |
|-------|---------|
| 🔵 **Blue** | **True Shot/Strikes True** - Optimal damage range |
| 🟢 **Green** | **Square Shot/Casting Range** - Good effectiveness |
| 🟡 **Yellow** | **Ranged Capable** - Can attack but no bonus |
| ⚪ **White** | **Out of Range** - Cannot attack/cast |

## Installation

1. Download the `distanceplus` folder
2. Place it in your `Ashita/addons/` directory
3. Load the addon: `/addon load distanceplus`

## Usage

### Basic Commands
```
//dp help          - Show all available commands
//dp config        - Open configuration GUI window
//dp gun           - Switch to gun range mode
//dp bow           - Switch to bow range mode  
//dp xbow          - Switch to crossbow range mode
//dp magic         - Switch to magic casting mode
//dp ninjutsu      - Switch to ninjutsu casting mode
//dp default       - Reset to default mode
```

### Auto Job Detection
DistancePlus automatically detects your job and sets appropriate modes:
- **COR** → Gun mode
- **RNG** → Default (manual selection recommended)
- **WHM/BLM/RDM/SCH/GEO/BRD** → Magic mode
- **NIN** → Ninjutsu mode
- **Other jobs** → Default mode

## Configuration Options

### Window Customization
- **Size Sliders**: Adjust window dimensions (70x70 to 400x400 pixels)
- **Style Toggle**: Switch between modern and classic visual styles
- **Transparency Control**: Adjust background opacity (modern style only)
- **Corner Rounding**: Control window corner radius (modern style only)
- **Padding**: Adjust internal spacing

### Display Options
- **Show Mode Indicator**: Toggle "(Gun)", "(Bow)" text display
- **Show Pet Window**: Enable/disable pet distance tracking
- **Center Text**: Center text within windows vs left-aligned

### Style Comparison

| Feature | Modern Style | Classic Style |
|---------|-------------|---------------|
| Title Bar | Red gradient | None |
| Corners | Rounded | Sharp |
| Background | Semi-transparent | Solid black |
| Border | Soft gray | None |
| Configurability | Full control | Minimal |

## Range Calculations

### Ranged Weapons
Based on accurate FFXI combat mechanics including model size adjustments:

**Gun Ranges** (closest optimal range):
- True Shot: ~3.02-4.32 + model sizes
- Square Shot: ~2.22-6.82 + model sizes

**Bow Ranges** (longest optimal range):
- True Shot: ~6.02-9.52 + model sizes  
- Square Shot: ~4.62-14.52 + model sizes

**Crossbow Ranges** (medium optimal range):
- True Shot: ~5.00-8.40 + model sizes
- Square Shot: ~3.62-11.72 + model sizes

### Magic/Ninjutsu
- **Magic**: 20.0 yalm base range + model size adjustments
- **Ninjutsu**: 16.1 yalm base range + model size adjustments
- **Model size bonuses** for larger targets

### Pet Distance (BST)
- **Range calculation**: 4.0 yalm optimal command range
- **Color coding**: Green when pet is in command range

## Technical Details

### Compatibility
- **Ashita v4** required
- **ImGui-based** configuration interface
- **Real-time updates** with minimal performance impact

### Files Structure
```
distanceplus/
├── distanceplus.lua    # Main addon file
└── README.md          # This documentation
```

## Credits

- **Original Author**: Sammeh (Windower version)
- **Ashita Conversion**: Palmer (Zodiarchy @ Asura)
- **Version**: 1.4.0
- **License**: GNU General Public License v3.0

## Changelog

### v1.4.0
- Based on original Windower DistancePlus v1.3.0.10
- Added full GUI configuration system
- Implemented dual visual styles (modern/classic)
- Fixed distance calculations to match Windower accuracy
- Added comprehensive customization options
- Improved pet distance tracking
- Enhanced job auto-detection

----

**Need Help?** Use `//dp help` in-game or open the configuration window with `//dp config` for visual setup options. 
