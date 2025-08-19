# TellNotifier Addon (Windower Version)

**Author:** Palmer (Zodiarchy @ Asura)

This addon sends Discord notifications to your mobile phone when you receive chat messages in Final Fantasy XI.

**Converted from Ashita to Windower**

## Features

- **Multi-Chat Support**: Monitor tells, party, linkshells, say, shout, and yell
- **Separate Linkshell Support**: Distinguish between Linkshell 1 and Linkshell 2
- **Discord Notifications**: Send alerts with chat type identification
- **Automatic Name Detection**: Extracts sender names from chat messages
- **Configurable Monitoring**: Enable/disable specific chat types
- **Cooldown System**: Prevents spam notifications
- **Debug Mode**: Test and troubleshoot notifications
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

### Step 4: Configure the Addon (Choose One Method)

**Method A: Edit Settings File (Recommended)**
1. Open `tellnotifier/data/settings.xml` in a text editor
2. Find the line: `<webhook_url>PASTE_YOUR_DISCORD_WEBHOOK_URL_HERE</webhook_url>`
3. Replace `PASTE_YOUR_DISCORD_WEBHOOK_URL_HERE` with your webhook URL
4. Save the file
5. Load the addon: `//lua load tellnotifier`
6. Test it: `//tn test`

**Method B: In-Game Command**
1. In FFXI, type: `//tn seturl <paste_your_webhook_url_here>`
2. Example: `//tn seturl https://discord.com/api/webhooks/1234567890/abcdef...`
3. Test it: `//tn test`

Both methods work the same way. Method A is recommended since it's easier to copy/paste and keeps your configuration organized.

### Step 5: Mobile Notifications
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
- `//tn seturl <url>` - Set Discord webhook URL
- `//tn reload` - Reload settings
- `//tn help` - Show all commands

### Chat Monitoring Commands
- `//tn monitor <type> <on/off>` - Enable/disable specific chat types
- `//tn status` - Show monitoring status for all chat types

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
//tn monitor party on          # Enable party chat notifications
//tn monitor linkshell1 on     # Enable Linkshell 1 notifications
//tn monitor ls2 on            # Enable Linkshell 2 notifications
//tn monitor say off           # Disable say chat notifications
//tn monitor outgoing on       # Enable outgoing message notifications
//tn status                    # Check what's currently being monitored
```

## How It Works

The addon:
1. **Monitors chat messages** using Windower's `chat message` event for multiple chat types
2. **Extracts sender name and message** from the event data
3. **Identifies chat type** (Tell, Party, Linkshell1, etc.)
4. **Sends Discord notification** with chat type and full message content
5. **Respects cooldown** to prevent spam (1 second by default)

## Settings

Settings are stored in `data/settings.xml` and include:

### Core Settings
- **enabled**: Turn notifications on/off
- **discord_enabled**: Enable/disable Discord notifications specifically
- **debug_mode**: Show detailed information
- **cooldown**: Seconds between notifications (prevents spam)
- **webhook_url**: Your Discord webhook URL

### Chat Type Settings
- **monitor_tells**: Monitor tell messages (default: true)
- **monitor_party**: Monitor party chat (default: false)
- **monitor_linkshell1**: Monitor Linkshell 1 chat (default: false)
- **monitor_linkshell2**: Monitor Linkshell 2 chat (default: false)
- **monitor_say**: Monitor say chat (default: false)
- **monitor_shout**: Monitor shout chat (default: false)
- **monitor_yell**: Monitor yell chat (default: false)
- **monitor_unity**: Monitor unity chat (default: false)
- **monitor_outgoing**: Monitor messages you send (default: false)

## Example Notifications

The addon sends different notification formats based on chat type:

**Tell:** `FFXI Tell from Zodiarchy: Hey, want to party?`  
**Party:** `FFXI Party from Tank: Ready to pull`  
**Linkshell1:** `FFXI Linkshell1 from Palmer: Anyone up for Omen?`  
**Linkshell2:** `FFXI Linkshell2 from Seller: Selling HQ gear!`  
**Say:** `FFXI Say from Stranger: Hi there!`  
**Shout:** `FFXI Shout from Player: LFG Dynamis!`  
**Outgoing:** `FFXI Say from YourName: Hello everyone!`

## Troubleshooting

### "No webhook URL configured"
- Run `//tn seturl <your_webhook_url>`
   - Alternatively, insert the webhook directly into your settings.xml file
- Make sure you copied the full webhook URL

### "Test works but tells don't"
- Enable debug mode: `//tn debug`
- Send yourself a tell and check console output
- Look for "Chat mode 3" messages

### "Ping test failed"
- Check your webhook URL is correct
- Verify internet connection

## Requirements

- **Windower 4**
- **Discord account**
- **Internet connection**

## Key Differences from Ashita Version

### API Changes
- Uses `windower.register_event` instead of `ashita.events.register`
- Uses `chat message` event instead of `packet_in` for tell detection
- Uses Windower's `config` library instead of Ashita's `settings`
- Uses Windower's `texts` library instead of ImGui for GUI

### Event Handling
- **Ashita**: Parsed raw packet data (0x0017) with manual text extraction
- **Windower**: Uses clean `chat message` event with pre-parsed sender and message

### GUI System
- **Ashita**: Full ImGui interface with checkboxes and interactive elements
- **Windower**: Text-based display using `texts` library (less interactive but functional)

### Settings System
- **Ashita**: Custom settings system with `.save()` and `.load()`
- **Windower**: Standard `config` library with XML-based storage

### Performance Benefits
- **Simpler**: No complex packet parsing required
- **More Reliable**: Less prone to packet structure changes
- **Cleaner Code**: Windower's event system is more straightforward
- **No External Dependencies**: Uses built-in LuaSocket library instead of curl
- **No CMD Window Popup**: Direct HTTPS requests without spawning external processes

## Security Notes

- Webhook URLs are stored in Windower settings files
- Keep your webhook URL private
- Anyone with your webhook URL can send messages to your channel
- You can regenerate webhook URLs in Discord if compromised

## Advanced Usage

### Complete Chat Logging
- **Outgoing Messages**: Enable `//tn monitor outgoing on` to capture messages you send
- **Complete Conversations**: Monitor both incoming and outgoing for full chat logs
- **Discord Funneling**: Perfect for keeping Discord groups updated on all chat activity
- **Use Case**: Linkshell leaders can funnel all LS chat to Discord for members who aren't online

### Multiple Characters
- Each character can have their own webhook URL
- Use `//tn seturl` on each character separately
- Settings are character-specific via Windower's config system

### Custom Cooldowns
- Edit the cooldown value in the settings file or through the config system
- Default: 1 second (can be adjusted to your preference)
- Prevents notification spam during conversations

### Debug Mode
- Shows chat message detection information
- Useful for troubleshooting
- Shows chat modes and message content

## Support

If you encounter issues:
1. **Enable debug mode**: `//tn debug`
2. **Check console output** when receiving tells
3. **Test webhook**: `//tn ping`
4. **Verify settings**: `//tn` (shows status)

## Version History

- **v1.2 (Windower)**: Converted from my original version made for Ashita. 
   - You can find the Ashita version under the Ashita directory on this same repo!
- Full Discord webhook support
- Automatic chat type detection via chat message events
- Command-line interface for easy configuration

## License

This addon is released under the GNU General Public License v3.
