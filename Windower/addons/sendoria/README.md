# Sendoria - Bidirectional Discord Chat Relay

**Author:** Palmer (Zodiarchy @ Asura)  
**Version:** 2.0 - Bidirectional Relay

Send messages from Discord to FFXI and from FFXI to Discord. Chat with your linkshell, party, or friends even when you're not at your computer!

**Features:** Full Bidirectional Relay | Zero Network Lag | All Chat Types Supported

## What It Does

- **FFXI → Discord**: Your game chat appears in Discord channels
- **Discord → FFXI**: Type in Discord, messages appear in your game
- **Tell Support**: Send tells to specific players from Discord
- **User Attribution**: Shows `[Username]` for Discord messages so you know who's talking
- **All Chat Types**: Party, Linkshells, Say, Shout, Yell, Unity, Tells
- **No Lag**: File-based system eliminates network delays
- **Easy Setup**: Simple configuration with helper script

## Quick Setup (5 Minutes)

### Step 1: Install Sendoria
1. **Extract** the `sendoria` folder to your Windower addons directory
2. **Load in FFXI**: `//lua load sendoria`

### Step 2: Create Discord Bot
1. Go to https://discord.com/developers/applications
2. Click **"New Application"** → Name it "Sendoria Bot"
3. Go to **"Bot"** → Click **"Add Bot"** → **Copy the token**
4. **Important**: Enable **"Message Content Intent"** in Privileged Gateway Intents
5. Go to **"OAuth2" → "URL Generator"** → Check **"bot"**
6. Check permissions: **Send Messages**, **Read Messages**, **Add Reactions**
7. **Use the generated URL** to invite bot to your Discord server

### Step 3: Create Discord Channels
Create channels in your Discord server for the chat types you want:
- `#tells` - For tell messages
- `#party` - For party chat
- `#linkshell1` - For LS1 chat
- `#linkshell2` - For LS2 chat
- `#say` - For local chat
- `#shout` - For zone shouts
- `#yell` - For yell chat

### Step 4: Install Python (One-Time Setup)
**If you don't have Python installed:**
1. **Download Python**: Go to https://www.python.org/downloads/
2. **Install Python**: Run the installer, **check "Add Python to PATH"**
3. **Test installation**: Open Command Prompt, type `python --version`
4. **Install Discord library**: `pip install discord.py`

**If you already have Python:**
- Just run: `pip install discord.py`

### Step 5: Easy Configuration
**Option A: Automatic Setup (Recommended)**
1. **Run setup**: `python config.py`
2. **Follow prompts**: Enter your bot token and channel IDs
3. **Done!** The script configures everything for you

**Option B: Manual Setup**
1. **Enable Developer Mode** in Discord (Settings → Advanced → Developer Mode)
2. **Get Channel IDs**: Right-click each channel → "Copy ID"
3. **Edit** `discord_bot.py` with a text editor:
   - Replace `YOUR_DISCORD_BOT_TOKEN_HERE` with your bot token
   - Replace each `000000000000000000` with your channel IDs

### Step 6: Start the System
1. **Run Discord bot**: `python discord_bot.py`
2. **Enable relay in FFXI**: `//send relay on`
3. **Enable chat types**: `//send tell on`, `//send party on`, etc.

### Step 7: Test It
- **Send a message in FFXI** → Should appear in Discord
- **Type in a Discord channel** → Should appear in FFXI
- **Send tells**: Type `/tell PlayerName message` in #tells channel

## Usage

### From FFXI to Discord
Just play normally! Your chat messages automatically appear in Discord channels.

### From Discord to FFXI
**Regular Messages**: Type normally in Discord channels
- `Hello everyone!` in #party → Appears as `YourName: [DiscordUser] Hello everyone!` in FFXI
- `Looking for party` in #say → Appears as `YourName: [DiscordUser] Looking for party` in FFXI

**Tells**: Use tell format in #tells channel
- `/tell Zodiarchy Hey there!` → Sends tell to Zodiarchy: `[DiscordUser] Hey there!`
- `/t Zodiarchy What's up?` → Same thing (shorter format)

**User Attribution**: All Discord messages show `[Username]` so your linkshell knows who's actually talking!

## Commands

### Basic Commands
- `//send` - Show current status
- `//send help` - Show all commands
- `//send relay on/off` - Enable/disable relay mode

### Enable Chat Types
- `//send tell on` - Enable tell monitoring
- `//send party on` - Enable party chat relay
- `//send ls1 on` - Enable Linkshell 1 relay
- `//send ls2 on` - Enable Linkshell 2 relay
- `//send say on` - Enable say chat relay
- `//send shout on` - Enable shout relay
- `//send yell on` - Enable yell relay
- `//send outgoing on` - Track messages you send

### Status & Maintenance
- `//send status` - Show what's being monitored
- `//send relay` - Show relay configuration
- `//send clean` - Clean old chat logs
- `//send debug on/off` - Toggle debug mode

## Troubleshooting

### Bot Won't Connect
- Double-check your bot token in `discord_bot.py`
- Make sure "Message Content Intent" is enabled in Discord Developer Portal
- Verify you ran `pip install discord.py`

### Messages Not Appearing in Game
- Check `//send relay` - make sure relay mode is enabled
- Check `//send status` - make sure chat types are enabled
- Make sure Discord bot is running (`python discord_bot.py`)

### Messages Not Appearing in Discord
- Make sure bot is running and shows "connected to Discord"
- Check channel IDs in `discord_bot.py` are correct
- Make sure bot has permissions in Discord channels

### Need Help?
- Enable debug mode: `//send debug on`
- Check both the FFXI console and Discord bot console for error messages
- Make sure both the addon and Discord bot are running

## Requirements

- **Windower 4**
- **Python 3.7+** (for Discord bot) - **Free download from python.org**
- **Discord account** and server
- **Internet connection** (for Discord bot only)

**Note:** Python is required for the Discord bot.

---

**Enjoy chatting with your FFXI friends from anywhere!** 🎮💬