# AutoCOR Enhanced v4.0.0

## Overview
AutoCOR Enhanced integrates J-Roller's advanced rolling algorithms with AutoCOR's UI system. Features complete port of J-Roller's strategic decision-making logic for Windower.

## 🧠 **Advanced Rolling Intelligence**

### **Sophisticated Double-Up Logic**
- **Sub-COR Strategy**: Simplified < 5 rule for subjob COR limitations
- **Safe Mode**: Ultra-conservative subjob-like behavior even on main COR
- **Gamble Mode**: Aggressive double-11 targeting with bust immunity exploitation
- **Risk Assessment**: Uses Fold availability, Snake Eye cooldowns, and bust immunity for intelligent decisions
- **Roll-Specific Logic**: Different strategies for Roll 6 (aggressive), Roll 7 (with Fold insurance), Roll 8+ (conservative)

### **Advanced Snake Eye Priority System**
- **Priority 1**: 10 → 11 (guaranteed perfection - highest priority)
- **Priority 2**: Lucky-1 → Lucky (with Crooked Cards active)
- **Priority 3**: Unlucky avoidance (disaster prevention)
- **Smart End-Rotation**: Uses Snake Eye for optimization when it will recharge in time
- **Gamble Integration**: More aggressive Snake Eye usage with bust immunity

### **Priority-Based Random Deal**
- **Configurable Priority**: Default order: Crooked Cards > Snake Eye > Fold
- **Smart Timing**: Uses Random Deal at optimal moments (before Roll 2, after perfect rolls)
- **Old vs New Mode**: Toggle between Crooked Cards focus vs Snake Eye/Fold focus
- **Intelligent Targeting**: Only resets abilities that are actually on cooldown

## 🎨 **UI System**
- **Interactive Interface**: Click-based controls with custom graphics
- **Real-time Updates**: Status displays update instantly with roll information
- **Drag & Drop**: Repositionable UI elements
- **Visual Roll Status**: Live roll values with lucky/unlucky indicators

## ⚙️ **Advanced Strategic Settings**

### **🎯 Combat Strategies**
- **`gamble`**: Aggressive double-11 targeting with bust immunity exploitation
- **`bustimmunity`**: Exploit bust immunity (11 on Roll 1) for aggressive Roll 2
- **`safemode`**: Ultra-conservative mode - only double-up on rolls 1-5 like sub COR
- **`engaged`**: Only roll while engaged in combat
- **`townmode`**: Prevent rolling in towns and safe zones
- **`rollwithbust`**: Allow Roll 2 even when busted (party still benefits)

### **🎲 Merit Ability Intelligence**
- **`smartsnakeeye`**: End-rotation optimization when Snake Eye will recharge in time
- **`hasSnakeEye`**: Manual Snake Eye availability control
- **`hasFold`**: Manual Fold availability control
- **Smart Detection**: Automatically detects main/sub COR for merit ability availability

### **🃏 Crooked Cards Strategies**
- **Normal Mode** (`crooked2 off`): Use on Roll 1, Random Deal resets for Roll 2
- **Special Mode** (`crooked2 on`): Save Crooked Cards for Roll 2 only

### **🔄 Random Deal Intelligence**
- **Priority System**: Configurable ability reset priority (default: Crooked Cards > Snake Eye > Fold)
- **Smart Timing**: Uses Random Deal at optimal moments for maximum benefit
- **Old vs New Mode**: Toggle between legacy Snake Eye/Fold focus vs modern Crooked Cards priority

## 📋 **Commands**

### **Basic Commands**
```bash
//cor                    # Toggle AutoCOR on/off
//cor on/off             # Enable/disable rolling
//cor roll 1/2 <name>    # Set rolls (supports fuzzy matching)
//cor cc [number]        # Set Crooked Cards usage
//cor help               # Show all commands
```

### **Advanced J-Roller Features**
```bash
//cor engaged on/off        # Only roll while engaged
//cor crooked2 on/off       # Save Crooked Cards for Roll 2 only
//cor randomdeal on/off     # Smart Random Deal usage
//cor oldrandomdeal on/off  # Random Deal mode (Snake/Fold vs Crooked)
//cor partyalert on/off     # Alert party before rolling
//cor gamble on/off         # Aggressive mode for double 11s
//cor bustimmunity on/off   # Exploit bust immunity
//cor safemode on/off       # Ultra-conservative mode
//cor townmode on/off       # Prevent rolling in towns
//cor rollwithbust on/off   # Allow Roll 2 when busted
//cor smartsnakeeye on/off  # Smart Snake Eye optimization
//cor snakeeye/fold on/off  # Merit ability settings
//cor resetpriority         # Reset Random Deal priority
//cor debug                 # Show debug information
```

### **UI & Settings**
```bash
//cor save               # Save current settings
//cor hide               # Toggle UI visibility
//cor reset              # Reset UI position
//cor aoe [slot/name]    # Toggle party member AoE
```

## 💡 **Strategic Usage Examples**

### **Conservative Strategy**
```bash
//cor safemode on          # Ultra-safe: only double-up on 1-5
//cor bustimmunity off     # Conservative Roll 2 even with immunity
//cor townmode on          # Prevent rolling in populated areas
```

### **Aggressive Strategy**
```bash
//cor gamble on            # Target double 11s aggressively
//cor bustimmunity on      # Exploit immunity for aggressive Roll 2
//cor rollwithbust on      # Roll 2 even when busted (party benefits)
```

### **Crooked Cards Optimization**
```bash
//cor crooked2 off         # Normal: use on Roll 1, Random Deal resets for Roll 2
//cor crooked2 on          # Special: save Crooked Cards for Roll 2 only
```

### **Party-Focused Setup**
```bash
//cor engaged on           # Only roll during combat
//cor partyalert on        # Warn party before rolling
//cor aoe 1 off            # Exclude specific party member from range check
```

## 🏆 **Technical Features**

### **J-Roller Algorithm Integration**
- Complete port of J-Roller's decision-making algorithms
- Multi-tier risk assessment with ability availability checks
- Three-tier Snake Eye priority system
- Configurable ability reset targeting with optimal timing
- Bust immunity exploitation logic

### **Safety Systems**
- Incapacitation detection (Amnesia, Petrification, Stun, Sleep, Charm, Terror)
- Stealth awareness (pauses during Sneak/Invisible)
- Town mode with city detection
- Automatic main/sub COR detection with merit ability adjustment
- Per-party-member AoE range checking

### **UI Implementation**
- Windower primitive rendering system
- Real-time visual feedback
- Click-based operation with drag & drop positioning
- Scalable design for different screen resolutions

## 📦 **Installation**

1. Copy the entire `Autocor` folder to your Windower addons directory
2. Ensure the `data` folder contains the button PNG files
3. Load the addon with `//lua load autocor`
4. Configure your preferred strategy with the advanced commands
5. Start rolling with `//cor on` or click the UI toggle

## ⚙️ **Configuration**

Settings are automatically saved to `data/settings.xml`:
- **Strategic Settings**: All J-Roller intelligence options
- **UI Position**: `top_left.x/y` coordinates
- **UI Scaling**: `user_ui_scalar` for different resolutions
- **Merit Abilities**: `hasSnakeEye`, `hasFold` manual overrides
- **Random Deal Priority**: Configurable ability reset order

## 🔧 **Compatibility**

- **Windower 4+** required
- **FFXI** - All versions supported
- **COR job** - Main job (full features) or sub job (limited features)
- **Merit Abilities**: Automatically detected, manual override available

## 👏 **Credits**

- **Original AutoCOR**: Ivaar|Relisaa - Foundation and core functionality
- **J-Roller**: Jyouya - Advanced rolling algorithms
- **UI System**: Based on SmartSkillup by RolandJ
- **Enhanced Integration**: Palmer (Zodiarchy @ Asura) - J-Roller algorithm port and UI enhancements

## 📜 **Version History**

### v4.0.0 - J-Roller Algorithm Integration
- Complete J-Roller algorithm integration
- Multi-tier risk assessment with ability checks
- Three-tier Snake Eye priority system
- Configurable ability reset targeting
- Gamble mode with bust immunity exploitation
- Enhanced safety systems with incapacitation and stealth detection
- All J-Roller advanced options (engaged, townmode, safemode, etc.)

### v3.0.0 - UI Enhancement
- Complete UI redesign
- Interactive buttons and real-time status displays
- Visual roll value tracking with lucky/unlucky indicators
- Party AoE status visualization and drag & drop support

### v2.0.0 - Enhanced Random Deal Timing
- Optimized Random Deal usage before second roll
- Smart cooldown detection and ability reset targeting

### v1.20.07.19 - Original Version
- Basic AutoCOR functionality with text-based interface
- Core rolling logic and command-line configuration 