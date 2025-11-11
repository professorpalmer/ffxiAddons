# TellNotifier Addon (Windower Version)

**Author:** Palmer (Zodiarchy @ Asura)  
**Version:** 1.5 - Multi-Character Support & Enhanced

This addon sends Discord notifications to your mobile phone when you receive chat messages in Final Fantasy XI.

**Converted from Ashita to Windower** | **Multi-Character Support** | **Per-Channel Webhooks**

## Features

- **Multi-Character Support**: Run on multiple characters with automatic identification
- **Per-Channel Webhooks**: Send different chat types to separate Discord channels
- **Multi-Chat Support**: Monitor tells, party, linkshells, say, shout, yell, and unity
- **Outgoing Message Support**: Track messages you send for complete chat logs
- **Character Identification**: Every Discord message shows `[CharacterName]` prefix
- **Intelligent Deduplication**: No more duplicate notifications
- **Modular Architecture**: Clean, maintainable code structure
- **Simple Commands**: Intuitive `//tn tell on` style commands
- **Debug Mode**: Comprehensive troubleshooting tools
- **Completely FREE**: No paid services required

## Quick Start

1. **Copy** the `tellnotifier` folder to your Windower4 addons directory
2. **Load** the addon: `//lua load tellnotifier`
3. **Set up Discord webhook** (see detailed setup below)
4. **Test**: `//tn test`
5. **Configure chat types**: `//tn monitor party on` (optional - tells enabled by default)
6. **Done!** You'll get Discord notifications for configured chat types

## Discord Setup (Detailed)

### Step 1: Create Discord Server (if needed)

1. Open Discord
2. Click the "+" icon on the left sidebar
3. Select "Create My Own" → "For me and my friends"
4. Name it something like "FFXI Notifications"

### Step 2: Create a Channel for Notifications

1. Right-click your server name
2. Select "Create Channel"
3. Name it `#tells` or `#ffxi-notifications`
4. Make it a Text Channel

### Step 3: Create a Webhook

1. **Right-click** the channel you just created
2. Select **"Edit Channel"**
3. Go to the **"Integrations"** tab
4. Click **"Create Webhook"**
5. Give it a name like "FFXI Tell Notify"
6. **Copy the Webhook URL** (looks like: `https://discord.com/api/webhooks/123456...`)

### Step 4: Configure the Addon

**Edit Settings File (Required)**

1. Open `tellnotifier/data/settings.xml` in a text editor
2. Find the line: `<webhook_url>PASTE_YOUR_DISCORD_WEBHOOK_URL_HERE</webhook_url>`
3. Replace `PASTE_YOUR_DISCORD_WEBHOOK_URL_HERE` with your webhook URL
4. **Optional**: Configure per-chat-type webhooks (see Per-Channel Setup below)
5. Save the file
6. Load the addon: `//lua load tellnotifier`
7. Test it: `//tn test`

### Step 5: Per-Channel Setup (Optional)

To send different chat types to separate Discord channels:

1. **Create additional Discord channels** (e.g., `#party-chat`, `#linkshell-chat`)
2. **Create webhooks for each channel** (repeat Step 3 for each)
3. **Add to settings.xml**:
   ```xml
   <webhook_tell>https://discord.com/api/webhooks/your_tell_webhook</webhook_tell>
   <webhook_party>https://discord.com/api/webhooks/your_party_webhook</webhook_party>
   <webhook_linkshell1>https://discord.com/api/webhooks/your_ls1_webhook</webhook_linkshell1>
   <!-- Add others as needed -->
   ```
4. **Check configuration**: `//tn webhooks`

**Available webhook types:** `webhook_tell`, `webhook_party`, `webhook_say`, `webhook_shout`, `webhook_yell`, `webhook_linkshell1`, `webhook_linkshell2`, `webhook_unity`

### Step 6: Multi-Character Setup (New!)

**Perfect for multi-boxing and managing multiple characters:**

1. **Load addon on each character**: `//lua load tellnotifier`
2. **Each character gets individual settings** automatically
3. **Character identification**: All Discord messages show `[CharacterName]` prefix
4. **Flexible webhook configuration**:
   - **Same server**: All characters use same webhooks → same channels
   - **Separate channels**: Use per-chat-type webhooks for organization
   - **Mixed approach**: Some shared, some separate

**Example Discord output:**
- `[Palmer] FFXI Tell from Smacksterr: Hello!` (your main character)
- `[AltChar] FFXI Tell from Guild: Alt check` (your alt character)
- `[Mule] FFXI Tell from Banker: Storage full` (your mule character)

### Step 7: Mobile Notifications

1. **Install Discord mobile app** on your phone
2. **Join your server** on mobile
3. **Enable notifications** for the channel:
   - Go to channel settings on mobile
   - Turn on notifications
   - Set to "All Messages"

## Commands

### Basic Commands

- `//tn` - Show current status
- `//tn test` - Send a test notification
- `//tn toggle` - Toggle notifications on/off
- `//tn debug` - Toggle debug mode
- `//tn ping` - Test webhook connection
- `//tn reload` - Reload settings
- `//tn multichar` - Show multi-character setup instructions
- `//tn help` - Show all commands

### Chat Monitoring Commands (New Simplified Syntax)

- `//tn <type> <on/off>` - Direct enable/disable commands
- `//tn status` - Show monitoring status for all chat types
- `//tn webhooks` - Show webhook configuration status

### Supported Chat Types

- `tells` / `tell` - Tell messages (enabled by default)
- `party` - Party chat
- `linkshell1` / `ls1` / `ls` / `linkshell` - Linkshell 1 chat
- `linkshell2` / `ls2` - Linkshell 2 chat
- `say` - Say chat (local area)
- `shout` - Shout chat (zone-wide)
- `yell` - Yell chat (wider area)
- `unity` - Unity chat
- `outgoing` - Messages you send (for complete chat logging)

### Examples

```
//tn tell on                   # Enable tell notifications
//tn party on                  # Enable party chat notifications
//tn ls1 on                    # Enable Linkshell 1 notifications
//tn ls2 on                    # Enable Linkshell 2 notifications
//tn say off                   # Disable say chat notifications
//tn outgoing on               # Enable outgoing message notifications
//tn status                    # Check what's currently being monitored
//tn webhooks                  # Check webhook configuration
```

## How It Works

The addon uses a **modular architecture** for reliability:

### **Incoming Messages:**

1. **Monitors chat events** using Windower's `chat message` system
2. **Identifies chat type** (Tell, Party, Linkshell1, etc.)
3. **Applies intelligent deduplication** to prevent spam
4. **Routes to appropriate Discord channel** via per-chat-type webhooks

### **Outgoing Messages:**

1. **Parses outgoing packets** (0x0B5 for speech, 0x0B6 for tells)
2. **Resolves correct chat mode** from packet data
3. **Prevents duplicates** with timestamp-based deduplication
4. **Tracks your sent messages** for complete chat logging

### **Multi-Character Support:**

1. **Automatic character detection** using `windower.ffxi.get_player()`
2. **Character identification** added to all Discord messages
3. **Individual settings per character** (Windower handles this automatically)
4. **Coroutine protection** prevents game freezing during Discord requests

## Settings

Settings are stored in `data/settings.xml` and include:

### Core Settings

- **enabled**: Turn notifications on/off
- **discord_enabled**: Enable/disable Discord notifications specifically
- **debug_mode**: Show detailed information
- **cooldown**: Seconds between notifications (prevents spam)
- **webhook_url**: Your main Discord webhook URL (fallback for all chats)

### Per-Channel Webhook Settings (Optional)

- **webhook_tell**: Dedicated webhook for tell messages
- **webhook_party**: Dedicated webhook for party chat
- **webhook_linkshell1**: Dedicated webhook for Linkshell 1 chat
- **webhook_linkshell2**: Dedicated webhook for Linkshell 2 chat
- **webhook_say**: Dedicated webhook for say chat
- **webhook_shout**: Dedicated webhook for shout chat
- **webhook_yell**: Dedicated webhook for yell chat
- **webhook_unity**: Dedicated webhook for unity chat

### Chat Monitoring Settings

- **monitor_tells**: Monitor tell messages (default: true)
- **monitor_party**: Monitor party chat (default: false)
- **monitor_linkshell1**: Monitor Linkshell 1 chat (default: false)
- **monitor_linkshell2**: Monitor Linkshell 2 chat (default: false)
- **monitor_say**: Monitor say chat (default: false)
- **monitor_shout**: Monitor shout chat (default: false)
- **monitor_yell**: Monitor yell chat (default: false)
- **monitor_unity**: Monitor unity chat (default: false)
- **monitor_outgoing**: Monitor messages you send (default: false)

### Multi-Character Settings

- **Automatic**: Each character gets individual settings automatically
- **Character identification**: All messages show `[CharacterName]` prefix
- **Webhook configuration**: Can use same or different webhooks per character
- **No additional setup**: Just load the addon on each character

## Troubleshooting

### "No webhook URL configured"

- Edit `tellnotifier/data/settings.xml` and add your webhook URL
- Make sure you copied the full webhook URL from Discord
- Use `//tn webhooks` to check configuration status

### "Test works but tells don't"

- Enable debug mode: `//tn debug`
- Send yourself a tell and check console output
- Look for "Chat mode 3" messages

### "Unity messages show as hex strings" (FIXED in v1.6)

- **Issue**: Domain Invasion announcements showed as `: 0a,01f1,0000000a,0000002f,00000120,00000000,00000000,`
- **Solution**: Automatic Unity message parsing now handles encoded system messages
- **Test**: Use `//tn testunity` to verify Unity message parsing works
- **Enable Unity monitoring**: `//tn unity on` to receive Domain Invasion notifications
- **Debug**: Enable `//tn debug` to see Unity message parsing in action

### "Ping test failed"

- Check your webhook URL is correct
- Verify internet connection

### "HTTPS failing, falling back to curl"

- **Multi-character fix**: Character detection moved to main thread
- **Coroutine protection**: All Discord requests use `coroutine.schedule`
- **Reliable HTTPS**: No more falling back to curl unless absolutely necessary
- **Debug mode**: Use `//tn debug` to see detailed HTTPS error messages

## Requirements

- **Windower 4**
- **Discord account**
- **Internet connection**

## Technical Details

### Architecture

- **Modular Design**: Separate modules for config, Discord, chat, and commands
- **Event-Driven**: Uses Windower's `chat message` and `outgoing chunk` events
- **Clean Dependencies**: Built-in LuaSocket for HTTPS, no external tools required
- **XML Configuration**: Standard Windower config system with settings.xml

### Performance

- **Lightweight**: Minimal memory footprint with focused modules
- **Efficient**: Smart deduplication prevents unnecessary API calls
- **Reliable**: Robust error handling and fallback mechanisms
- **Non-Intrusive**: Passive packet monitoring doesn't interfere with game

## Security Notes

- Webhook URLs are stored in Windower settings files
- Keep your webhook URL private
- Anyone with your webhook URL can send messages to your channel
- You can regenerate webhook URLs in Discord if compromised

## Advanced Usage

### Complete Chat Logging

- **Outgoing Messages**: Enable `//tn outgoing on` to capture messages you send
- **Complete Conversations**: Monitor both incoming and outgoing for full chat logs
- **Per-Channel Organization**: Route different chat types to separate Discord channels
- **Use Case**: Linkshell leaders can funnel all LS chat to Discord for members who aren't online

### Per-Channel Setup

Create organized Discord notifications by setting up separate channels:

1. **#ffxi-tells** - Personal tells and urgent messages
2. **#ffxi-party** - Party coordination and dungeon chat
3. **#ffxi-linkshell** - Social linkshell conversations
4. **#ffxi-shouts** - Zone shouts and recruitment calls

### Multiple Characters

- Each character has individual settings in Windower's config system
- Configure different webhook URLs per character
- Perfect for multi-boxing or managing multiple accounts

### Debug Mode

- **Enable**: `//tn debug`
- **Shows**: Chat modes, packet data, deduplication info
- **Useful for**: Troubleshooting duplicate notifications or missing messages
- **Performance**: Minimal impact when disabled

## Support

If you encounter issues:

1. **Enable debug mode**: `//tn debug`
2. **Check console output** when receiving tells
3. **Test webhook**: `//tn ping`
4. **Verify settings**: `//tn` (shows status)

## Version History

- **v1.6 (Unity Message Fix)**: Fixed Unity message parsing for Domain Invasion announcements
  - **Unity message parsing**: Fixed issue where NPC Domain Invasion announcements showed as hex strings
  - **System message detection**: Automatically detects and parses encoded Unity system messages
  - **Domain Invasion support**: Properly handles Domain Invasion location announcements
  - **Test command**: Added `//tn testunity` to test Unity message parsing
  - **Debug improvements**: Enhanced debug output for Unity message troubleshooting
- **v1.5 (Multi-Character Enhanced)**: Enhanced multi-character support and reliability
  - **Multi-character identification**: All Discord messages show `[CharacterName]` prefix
  - **Coroutine protection**: Fixed HTTPS issues by moving character detection to main thread
  - **Enhanced reliability**: No more falling back to curl unless absolutely necessary
  - **Multi-char command**: `//tn multichar` for setup instructions
  - **Perfect for multi-boxing**: Run on multiple characters simultaneously
- **v1.4 (Refactored)**: Complete code refactor for maintainability and reliability
  - Modular architecture with separate lib modules
  - Eliminated duplicate notification issues
  - Removed unused code (auto-translate tables, complex batching)
  - Simplified command syntax (`//tn tell on`)
  - Per-channel webhook support
- **v1.3**: Per-chat-type webhooks and outgoing message support
- **v1.2**: Enhanced chat monitoring and Discord integration
- **v1.0**: Initial release
