# Ashita Roller v0.4.0
FFXI Addon for Ashita v4 - Automated COR Rolling with Subjob Support

**Major Ashita v4 Port by Palmer (Zodiarchy @ Asura)**
- Original windower addon: https://github.com/Noobcakes/Roller
- Based on Ashita v3 port by towbes & matix
- v0.3 improvements by Lumlum
- **v0.4 Complete Ashita4 rewrite with subjob COR support**

## New in v0.4.0 (Ashita v4 Port)
- ✅ **Full Ashita v4 compatibility** - Complete API migration
- ✅ **Subjob COR support** - Works when COR is your subjob (THF/COR, etc.)
- ✅ **Smart subjob behavior** - Single roll only, less aggressive double-ups (1-4 only)
- ✅ **Automatic mode detection** - Recognizes main vs subjob COR automatically
- ✅ **Enhanced status display** - Shows current mode and job info
- ✅ **Self-contained** - Single file, no external dependencies

## Features

### Core Rolling
- **Automatic corsair rolling** for both main and subjob COR
- **Intelligent double-up logic** based on your job setup
- **Roll management** with Crooked Cards, Fold, Snake Eye, Random Deal support
- **Zone-safe** - Automatically stops/resumes on zone changes

### Job Mode Support
| Mode | Rolls | Double-Up Strategy | Special Abilities |
|------|-------|-------------------|-------------------|
| **Main COR** | Two rolls | Aggressive (1-5+) | Full access to Snake Eye, Crooked Cards, Fold, Random Deal |
| **Sub COR** | Single roll | Conservative (1-4 only) | Limited abilities, no advanced features |

### Advanced Features
- **Quick Mode** - Fast setup for short content (Ambuscade, etc.)
- **Gamble Mode** - Maintains double 11s using bust immunity (ML parties)
- **Party Alerts** - Optional countdown warnings
- **Stealth Detection** - Pauses while Sneak/Invisible

## Commands

### Basic Control
```
/roller start          - Begin automatic rolling
/roller stop           - Stop automatic rolling  
/roller                - Show current status and mode
/roller flags          - Debug information
```

### Roll Configuration
```
/roller roll1 <roll>   - Set first roll (e.g., "cors", "chaos", "samurai")
/roller roll2 <roll>   - Set second roll (main COR only)
/roller preset <type>  - Quick presets (TP, Acc, WS, Nuke, Pet, PetNuke)
```

### Settings
```
/roller engaged on/off     - Only roll while engaged
/roller crooked2 on/off    - Use Crooked Cards for second roll
/roller randomdeal on/off  - Enable Random Deal usage
/roller oldrandomdeal on/off - Focus: on=Snake Eye/Fold, off=Crooked Cards
/roller gamble on/off      - Abuse bust immunity for double 11s
/roller partyalert on/off  - Party countdown messages
/roller once              - Roll once then stop
/roller display on/off    - Toggle GUI overlay
```

## Usage Examples

### Subjob COR (THF/COR, WAR/COR, etc.)
```bash
/roller roll1 chaos    # Set Chaos Roll
/roller start          # Begin rolling (single roll, conservative)
```
**Expected behavior:** Only attempts Chaos Roll, doubles up on 1-4, stops on 5+

### Main COR - Quick Mode (Ambuscade)
```bash
/roller preset TP
/roller crooked2 on
/roller randomdeal on
/roller oldrandomdeal off
/roller start
```

### Main COR - Gamble Mode (ML Parties)
```bash
/roller roll1 corsair
/roller roll2 samurai  
/roller crooked2 off
/roller randomdeal on
/roller oldrandomdeal on
/roller gamble on
/roller start
```

## Installation
1. Copy `ashitaroller.lua` to your `/addons/ashitaroller/` folder
2. Load with `/addon load ashitaroller`
3. The addon will auto-detect your job setup and configure accordingly

## Mode Detection
The addon automatically detects your setup:
- **Main Job COR (ID: 17)** = Full features, two rolls
- **Sub Job COR (ID: 17)** = Limited features, single roll  
- **No COR** = Rolling disabled

Use `/roller` to verify your current mode is detected correctly.

## Compatibility
- **Ashita v4 only** (use v0.3 for Ashita v3)
- **FFXI Retail** tested on multiple servers
- **All job combinations** that include COR as main or sub

## Credits
- **Original concept:** Noobcakes (Windower Roller)
- **Ashita v3 port:** towbes, matix  
- **v0.3 improvements:** Lumlum
- **v0.4 Ashita4 port & subjob support:** Palmer (Zodiarchy @ Asura)

---
*For bugs or feature requests, contact Palmer on Asura or submit an issue.*
```

You can **safely delete** `buffsmap.lua` and `job_abilities.lua` - they're no longer needed since everything is self-contained in the main file now!
