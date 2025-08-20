# TellNotifier Addon (Ashita Version)

**Author:** Palmer (Zodiarchy @ Asura)

This addon sends Discord notifications to your mobile phone when you receive chat messages in Final Fantasy XI.

## Features

- **Multi-Chat Support**: Monitor tells, party, linkshells, say, shout, yell, unity, and emotes
- **Separate Linkshell Support**: Distinguish between Linkshell 1 and Linkshell 2
- **Discord Notifications**: Send alerts with chat type identification
- **Automatic Name Detection**: Extracts sender names from chat packets
- **Configurable Monitoring**: Enable/disable specific chat types via GUI or commands
- **Debug Mode**: Discover chat type values for your server
- **Cooldown System**: Prevents spam notifications
- **GUI Configuration**: Easy-to-use interface with checkboxes for each chat type
- **Completely FREE**: No paid services required

## Quick Start

1. **Copy** the `tellnotifier` folder to your Ashita addons directory
2. **Load** the addon: `/addon load tellnotifier`
3. **Set up Discord webhook** (see detailed setup below)
4. **Test**: `/tn test`
5. **Done!** You'll get Discord notifications when you receive tells

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

**Method A: Edit Settings File**
1. Load the addon once: `/addon load tellnotifier`
2. This creates a settings file
3. Edit the settings file or use the GUI to set your webhook URL
4. Or use the command: `/tn seturl <your_webhook_url>`
5. Test it: `/tn test`

**Method B: In-Game Command**
1. In FFXI, type: `/tn seturl <paste_your_webhook_url_here>`
2. Example: `/tn seturl https://discord.com/api/webhooks/1234567890/abcdef...`
3. Test it: `/tn test`

Both methods work the same way. Method A is easier since you can copy/paste normally.

### Step 5: Mobile Notifications
1. **Install Discord mobile app** on your phone
2. **Join your server** on mobile
3. **Enable notifications** for the channel:
   - Go to channel settings on mobile
   - Turn on notifications
   - Set to "All Messages"

## Commands

### Basic Commands
- `/tn` - Show current status
- `/tn test` - Send a test notification
- `/tn toggle` - Toggle notifications on/off
- `/tn debug` - Toggle debug mode (shows chat type values)
- `/tn ping` - Test webhook connection
- `/tn seturl <url>` - Set Discord webhook URL
- `/tn reload` - Reload settings
- `/tn help` - Show all commands

### Chat Monitoring Commands
- `/tn monitor <type> <on/off>` - Enable/disable specific chat types
- `/tn status` - Show monitoring status for all chat types

### Supported Chat Types
- `tells` / `tell` - Tell messages (enabled by default)
- `party` - Party chat
- `linkshell1` / `ls1` / `ls` / `linkshell` - Linkshell 1 chat
- `linkshell2` / `ls2` - Linkshell 2 chat
- `say` - Say chat (local area)
- `shout` - Shout chat (zone-wide)
- `yell` - Yell chat (wider area)
- `unity` - Unity chat
- `emotes` / `emote` - Emote messages

### Examples
```
/tn monitor party on          # Enable party chat notifications
/tn monitor linkshell1 on     # Enable Linkshell 1 notifications
/tn monitor ls2 on            # Enable Linkshell 2 notifications
/tn monitor say off           # Disable say chat notifications
/tn status                    # Check what's currently being monitored
```

## How It Works

The addon:
1. **Monitors chat packets** (0x0017) for all chat messages
2. **Extracts sender name and message** from the packet data
3. **Identifies chat type** (Tell, Party, Linkshell, etc.)
4. **Sends Discord notification** with chat type and full message content
5. **Respects cooldown** to prevent spam (1 second by default)

## Discovering Chat Types for Your Server

The chat type values may vary between servers. To discover the correct values:

1. **Enable debug mode**: `/tn debug`
2. **Have someone send you messages** of different types (tells, party, linkshell, etc.)
3. **Watch the console output** - it will show:
   ```
   TellNotifier DEBUG: Chat type X from SenderName: Message
   TellNotifier DEBUG: Add this to chat_modes table if needed
   ```
4. **Update the chat_modes table** in the addon code if needed
5. **The addon comes pre-configured** with common values, but you may need to adjust them

Example: If party chat shows as "Chat type 4", then party chat is working correctly. If it shows a different number, you'll need to update the chat_modes table in the lua file.

## Settings

- **Enabled**: Turn notifications on/off
- **Debug Mode**: Show detailed packet information
- **Cooldown**: Seconds between notifications (prevents spam)
- **Webhook URL**: Your Discord webhook URL

## Example Notifications

The addon sends different notification formats based on chat type:

**Tell:** `FFXI Tell from Zodiarchy: Hey, want to party?`  
**Party:** `FFXI Party from Tank: Ready to pull`  
**Linkshell1:** `FFXI Linkshell1 from Palmer: Anyone up for Omen?`  
**Linkshell2:** `FFXI Linkshell2 from Seller: Selling HQ gear!`  
**Say:** `FFXI Say from Stranger: Hi there!`  
**Shout:** `FFXI Shout from Player: LFG Dynamis!`  
**Unity:** `FFXI Unity from Leader: Unity Wanted NM up!`  
**Emote:** `FFXI Emote from Friend: waves goodbye.`

## Troubleshooting

### "No webhook URL configured"
- Run `/tn seturl <your_webhook_url>`
- Make sure you copied the full webhook URL

### "Test works but tells don't"
- Enable debug mode: `/tn debug`
- Send yourself a tell and check console output
- Look for "Chat type 3" messages

### "Ping test failed"
- Check your webhook URL is correct
- Verify internet connection
- Make sure curl is installed (comes with Windows 10/11)

### "Names are truncated"
- This is normal packet behavior
- The addon extracts the best available name from packet data
- Entity lookup provides full names when possible

## Requirements

- **Ashita v4**
- **Windows 10/11** (for curl)
- **Discord account**
- **Internet connection**

## Security Notes

- Webhook URLs are stored in Ashita settings files
- Keep your webhook URL private
- Anyone with your webhook URL can send messages to your channel
- You can regenerate webhook URLs in Discord if compromised

## Advanced Usage

### Multiple Characters
- Each character can have their own webhook URL
- Use `/tn seturl` on each character separately
- Settings are character-specific

### Custom Cooldowns
- Edit the cooldown value in the GUI
- Minimum recommended: 15 seconds
- Prevents notification spam during conversations

### Debug Mode
- Shows packet detection information
- Useful for troubleshooting
- Shows chat types and parsed content

## Support

If you encounter issues:
1. **Enable debug mode**: `/tn debug`
2. **Check console output** when receiving tells
3. **Test webhook**: `/tn ping`
4. **Verify settings**: `/tn` (shows status)
5. **Ask for help** on the Ashita Discord

## Version History

- **v1.2**: Major update with multi-chat support
  - Added support for all chat types (party, linkshell, say, shout, etc.)
  - Separate Linkshell 1 and Linkshell 2 support
  - GUI checkboxes for each chat type
  - Command-line monitoring control
  - Debug mode for discovering chat type values
  - Matches functionality of Windower version
- **v1.0**: Initial release with Discord webhook support
  - Full sender name extraction from packets
  - Automatic message parsing and cooldown system

## License

This addon is released under the GNU General Public License v3.