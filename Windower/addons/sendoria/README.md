# Sendoria - Discord Chat Relay

Chat between FFXI and Discord seamlessly!

## Quick Setup

### 1. Install the Addon
- Copy `sendoria` folder to your Windower addons
- In FFXI: `//lua load sendoria`

### 2. Set Up Discord Bot
- Create a bot at [Discord Developer Portal](https://discord.com/developers/applications)
- Copy the bot token to `sendoria_config.txt`
- **Invite bot to your server**: Bot → OAuth2 → URL Generator → Select "bot" → Select permissions: "Send Messages", "Read Message History" → Copy URL and open it

### 3. Configure Channels (sendoria_config.txt)
- Right-click Discord channels → Copy ID
- Add channel IDs to config file

### 4. Run the Bot
- Double-click `SendoriaBot.exe`
- That's it!

## How to Use

**FFXI → Discord**: Just chat normally in game  
**Discord → FFXI**: Type in Discord channels  
**Tells**: `/tell PlayerName message` in Discord

## FFXI Commands
- `//send help` - Show commands
- `//send party on` - Enable party chat relay
- `//send ls1 on` - Enable linkshell relay
- `//send tell on` - Enable tell relay

## Troubleshooting
- Make sure bot token is correct
- Check channel IDs are valid
- Bot needs "Send Messages" and "Read Message History" permissions

---
Ready to go! Your chats now sync between FFXI and Discord. 🎮💬