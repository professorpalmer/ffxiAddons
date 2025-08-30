# 🚀 Sendoria - Bidirectional Discord Chat Relay

**Author:** Palmer (Zodiarchy @ Asura)  
**Version:** 2.0 - Bidirectional Relay

Send messages from Discord to FFXI and from FFXI to Discord. Chat with your linkshell, party, or friends even when you're not at your computer!

**Features:** Full Bidirectional Relay | Zero Network Lag | All Chat Types Supported | No Python Required!

## 🎯 **What It Does**

- **FFXI → Discord**: Your game chat appears in Discord channels
- **Discord → FFXI**: Type in Discord, messages appear in your game
- **Tell Support**: Send tells to specific players from Discord
- **User Attribution**: Shows `[Username]` for Discord messages so you know who's talking
- **All Chat Types**: Party, Linkshells, Say, Shout, Yell, Unity, Tells
- **No Lag**: File-based system eliminates network delays
- **Easy Setup**: Just run the executable!

## ⚡ **Quick Setup (2 Minutes - No Python!)**

### **Step 1: Install the Addon**
1. **Extract** the `sendoria` folder to your Windower addons directory
2. **Load in FFXI**: `//lua load sendoria`

### **Step 2: Run the Discord Bot**
1. **Double-click** `SendoriaBot.exe`
2. **Watch** the console for connection status
3. **Done!** Your Discord bot is running

**No Python installation required!** The executable includes everything needed.

## 🔧 **Configuration Details**

### **Bot Token**
Your Discord bot token is already in the config file. If you need to change it:
1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Create/select your application
3. Go to "Bot" section
4. Copy the token and replace in `sendoria_config.txt`

### **Channel IDs**
All 8 chat types are configured:
- **Tell**: Private messages
- **Party**: Party chat
- **Linkshell1/2**: Linkshell chat
- **Say**: Local area chat
- **Shout**: Zone-wide chat
- **Yell**: Server-wide chat
- **Unity**: Unity chat

To change channel IDs:
1. Right-click any Discord channel
2. Select "Copy ID"
3. Replace the number in `sendoria_config.txt`

## 📱 **Discord Commands**

### **Send Messages to FFXI**
- **Regular chat**: Just type in any configured channel
- **Tell someone**: `/tell PlayerName message` or `/t PlayerName message`
- **Bot will react** with ✅ when message is processed

### **Message Format**
- **From Discord**: `[DiscordUsername] message`
- **To Discord**: `📤/📥 ChatType: PlayerName: message`

## 🎮 **FFXI Addon Setup**

Make sure you have the Sendoria addon loaded in Windower:
```lua
//lua load sendoria
```

The addon will automatically:
- Create relay files for the bot to read
- Inject Discord messages into your game chat
- Handle all chat types you've configured

## 📝 **Usage**

### **From FFXI to Discord**
Just play normally! Your chat messages automatically appear in Discord channels.

### **From Discord to FFXI**
**Regular Messages**: Type normally in Discord channels
- `Hello everyone!` in #party → Appears as `YourName: [DiscordUser] Hello everyone!` in FFXI
- `Looking for party` in #say → Appears as `YourName: [DiscordUser] Looking for party` in FFXI

**Tells**: Use tell format in #tells channel
- `/tell Zodiarchy Hey there!` → Sends tell to Zodiarchy: `[DiscordUser] Hey there!`
- `/t Zodiarchy What's up?` → Same thing (shorter format)

**User Attribution**: All Discord messages show `[Username]` so your linkshell knows who's actually talking!

## 🎮 **FFXI Commands**

### **Basic Commands**
- `//send` - Show current status
- `//send help` - Show all commands
- `//send relay on/off` - Enable/disable relay mode

### **Enable Chat Types**
- `//send tell on` - Enable tell monitoring
- `//send party on` - Enable party chat relay
- `//send ls1 on` - Enable Linkshell 1 relay
- `//send ls2 on` - Enable Linkshell 2 relay
- `//send say on` - Enable say chat relay
- `//send shout on` - Enable shout relay
- `//send yell on` - Enable yell relay
- `//send outgoing on` - Track messages you send

### **Status & Maintenance**
- `//send status` - Show what's being monitored
- `//send relay` - Show relay configuration
- `//send clean` - Clean old chat logs
- `//send debug on/off` - Toggle debug mode

## 🚨 **Troubleshooting**

### **Bot Won't Start**
- Check your bot token is correct in `sendoria_config.txt`
- Verify channel IDs are valid numbers
- Make sure bot has permissions in your Discord server

### **No Messages in Discord**
- Verify the Sendoria addon is loaded in FFXI
- Check bot has "Send Messages" permission in channels
- Look for error messages in the console

### **No Messages in FFXI**
- Check bot has "Read Message History" permission
- Verify channel IDs match your Discord server
- Look for error messages in the console

### **Need Help?**
- Enable debug mode: `//send debug on`
- Check both the FFXI console and Discord bot console for error messages
- Make sure both the addon and Discord bot are running

## 🔒 **Security Notes**

- **Never share** your bot token publicly
- **Keep** `sendoria_config.txt` private
- **Bot only reads** messages in configured channels
- **Bot only sends** to configured channels

## 📋 **Requirements**

- **Windower 4**
- **Discord account** and server
- **Internet connection** (for Discord bot only)
- **No Python installation required!**

---

## 🎉 **Enjoy Your Bidirectional Discord Chat Relay!**

Your FFXI chat will now appear in Discord, and Discord messages will appear in your game. No more switching between applications! 🚀

**Ready to use immediately** - just run `SendoriaBot.exe` and enjoy chatting with your FFXI friends from anywhere! 🎮💬