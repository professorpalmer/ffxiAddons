# Clipper - Clipboard Paste Addon for Ashita/FFXI

A simple addon that allows you to paste clipboard content directly into FFXI game chat.

## Problem Solved

Ashita has a built-in `/paste` command, but it often fails with the error:
```
Failed to access clipboard for pasting. (2)
```

This addon provides a more reliable clipboard paste functionality using direct Windows API calls.

## Features

- ✅ Paste clipboard text directly to game chat
- ✅ **Full Japanese support** - Proper UTF-16 to Shift-JIS conversion using Windows API!
- ✅ Works with Japanese (日本語) text perfectly
- ✅ Supports various chat prefixes (/say, /party, /tell, etc.)
- ✅ Automatic text cleaning (removes newlines, extra spaces)
- ✅ Configurable max paste length
- ✅ Debug mode for troubleshooting

## Installation

1. Copy the `clipper` folder to your `Ashita/addons/` directory
2. In-game, type: `/addon load clipper`
3. (Optional) Add to your auto-load list

## Usage

### Basic Commands

```
/paste              - Paste clipboard text as-is
/clip               - Same as /paste (shorter alias)
/clipper            - Same as /paste (full name)
```

### Chat Type Prefixes

```
/paste say          - Paste with /say prefix
/paste party        - Paste with /p prefix
/paste linkshell    - Paste with /l prefix
/paste shout        - Paste with /sh prefix
/paste yell         - Paste with /yell prefix
/paste tell <name>  - Paste with /tell <name> prefix
```

### Configuration

```
/paste debug        - Toggle debug mode (shows detailed info)
/paste unicode      - Toggle Unicode/multi-byte support (ON by default)
/paste length <num> - Set max paste length (default: 200)
/paste help         - Show help message
```

### Japanese/Unicode Support

**YES! This addon now supports Japanese text!** 🎌

The addon uses Windows `WideCharToMultiByte` API to properly convert UTF-16 (Windows clipboard format) to **Shift-JIS encoding** (CP932), which is what FFXI's Japanese client uses.

Example:
- Japanese: 皆さんこんにちは！新しく入りました。よろしくお願いします！
- This will paste correctly into FFXI!

**Note:** This works best with Japanese text. Chinese and Korean may have limited support depending on FFXI's Shift-JIS encoding capabilities.

## Examples

1. **Simple paste:**
   - Copy text: "Hello everyone!"
   - In-game: `/paste`
   - Result: "Hello everyone!" appears in chat input

2. **Say to party:**
   - Copy text: "Ready for Dynamis?"
   - In-game: `/paste party`
   - Result: "/p Ready for Dynamis?" is sent

3. **Tell someone:**
   - Copy text: "Come to Jeuno"
   - In-game: `/paste tell PlayerName`
   - Result: "/tell PlayerName Come to Jeuno" is sent

## Keybinding

You can bind the `/paste` command to a key in Ashita's keybind settings:

1. Open Ashita Settings (F11 or /ashita)
2. Go to Keybinds tab
3. Click "Create New Keybind"
4. Set your desired key combination (e.g., Ctrl+V)
5. Set command to: `/paste`

## Technical Details

- Uses Windows Clipboard API via FFI (Foreign Function Interface)
- Supports both Unicode (CF_UNICODETEXT) and ANSI (CF_TEXT) clipboard formats
- **Uses WideCharToMultiByte to convert UTF-16 to Shift-JIS (CP932)**
- Shift-JIS is the native encoding for Japanese FFXI
- Properly handles Japanese multi-byte characters (Hiragana, Katakana, Kanji)
- Falls back to ANSI text if Unicode conversion fails
- Cleans up clipboard text (removes newlines, tabs, extra spaces)
- Respects FFXI's chat length limits (default: 200 characters)

## Troubleshooting

**Q: Still getting "clipboard access failed" errors?**
- A: Make sure you're using `/paste` from the clipper addon, not Ashita's built-in command
- Check that the addon is loaded: `/addon list`
- Try: `/paste debug` to enable debug mode and see what's happening

**Q: Text is truncated?**
- A: FFXI has a 200-character limit for chat messages
- You can adjust: `/paste length 300` for longer text (but may not send properly)

**Q: Japanese/Unicode characters not showing correctly?**
- A: Make sure Unicode mode is ON: `/paste unicode`
- Check that FFXI is set to display the correct language
- Some rare emoji or special characters may not display in FFXI

## Credits

- **Author:** Ashita Development Team
- **Version:** 1.0
- **License:** GPL-3.0

## Support

- Website: https://www.ashitaxi.com/
- Discord: https://discord.gg/Ashita


