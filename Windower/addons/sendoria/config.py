#!/usr/bin/env python3
"""
Sendoria Configuration Helper
Helps users configure their Discord bot settings
"""

import os

def configure_bot():
    print("=== Sendoria Configuration Helper ===")
    print()
    
    # Get bot token
    print("1. Discord Bot Token:")
    print("   - Go to https://discord.com/developers/applications")
    print("   - Create new application → Go to 'Bot' → Copy token")
    token = input("   Enter your bot token: ").strip()
    
    print()
    print("2. Discord Channel IDs:")
    print("   - Enable Developer Mode in Discord (Settings → Advanced)")
    print("   - Right-click each channel and 'Copy ID'")
    
    channels = {}
    chat_types = ['Tell', 'Party', 'Linkshell1', 'Linkshell2', 'Say', 'Shout', 'Yell', 'Unity']
    
    for chat_type in chat_types:
        channel_id = input(f"   {chat_type} channel ID (or press Enter to skip): ").strip()
        if channel_id and channel_id.isdigit():
            channels[chat_type] = channel_id
        else:
            channels[chat_type] = "000000000000000000"
    
    # Update discord_bot.py
    try:
        with open('discord_bot.py', 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # Replace token
        content = content.replace('YOUR_DISCORD_BOT_TOKEN_HERE', token)
        
        # Replace channel IDs
        for chat_type, channel_id in channels.items():
            old_line = f"    '{chat_type}': 000000000000000000"
            new_line = f"    '{chat_type}': {channel_id}"
            content = content.replace(old_line, new_line)
        
        with open('discord_bot.py', 'w', encoding='utf-8') as f:
            f.write(content)
        
        print()
        print("✅ Configuration complete!")
        print("✅ discord_bot.py has been updated")
        print()
        print("Next steps:")
        print("1. Run: pip install discord.py")
        print("2. Run: python discord_bot.py")
        print("3. In FFXI: //lua load sendoria")
        print("4. In FFXI: //send relay on")
        print()
        print("Enjoy your bidirectional Discord chat relay!")
        
    except Exception as e:
        print(f"❌ Error updating configuration: {e}")
        print("Please manually edit discord_bot.py with your settings")

if __name__ == "__main__":
    configure_bot()
