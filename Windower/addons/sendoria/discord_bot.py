#!/usr/bin/env python3
"""
Sendoria Discord Bot v2.0
Bidirectional Discord chat relay for FFXI
Author: Palmer (Zodiarchy @ Asura)
"""

import discord
from discord.ext import commands, tasks
import os
import sys
import time
import asyncio

# Configuration file
CONFIG_FILE = "sendoria_config.txt"

# Global configuration variables
BOT_TOKEN = ""
CHANNEL_MAP = {}
RELAY_FILE = "chat_relay.txt"
RESPONSE_FILE = "discord_responses.txt"
POSITION_FILE = "bot_position.txt"
CHECK_INTERVAL = 1

def load_config():
    """Load configuration from sendoria_config.txt"""
    global BOT_TOKEN, CHANNEL_MAP
    
    if not os.path.exists(CONFIG_FILE):
        print(f"ERROR: {CONFIG_FILE} not found!")
        print("Please create sendoria_config.txt with your bot token and channel IDs.")
        print("See sendoria_config_template.txt for the format.")
        return False
    
    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Parse BOT_TOKEN
        if "BOT_TOKEN = " in content:
            start = content.find("BOT_TOKEN = \"") + len("BOT_TOKEN = \"")
            end = content.find("\"", start)
            BOT_TOKEN = content[start:end]
        
        # Parse CHANNEL_MAP
        if "CHANNEL_MAP = {" in content:
            start = content.find("CHANNEL_MAP = {")
            end = content.find("}", start) + 1
            channel_section = content[start:end]
            
            # Extract channel mappings
            lines = channel_section.split('\n')
            for line in lines:
                if "'" in line and ":" in line:
                    # Parse: 'ChatType': 123456789,
                    chat_type_start = line.find("'") + 1
                    chat_type_end = line.find("'", chat_type_start)
                    chat_type = line[chat_type_start:chat_type_end]
                    
                    channel_id_start = line.find(": ") + 2
                    channel_id_end = line.find(",", channel_id_start)
                    if channel_id_end == -1:
                        channel_id_end = line.find("}", channel_id_start)
                    channel_id = int(line[channel_id_start:channel_id_end].strip())
                    
                    CHANNEL_MAP[chat_type] = channel_id
        
        print(f"✅ Configuration loaded from {CONFIG_FILE}")
        print(f"✅ Bot token: {'*' * 20}{BOT_TOKEN[-10:] if BOT_TOKEN else 'NOT SET'}")
        print(f"✅ Channels configured: {len(CHANNEL_MAP)}")
        
        return True
        
    except Exception as e:
        print(f"ERROR: Failed to load configuration: {e}")
        return False

def create_config_interactively():
    """Create configuration file interactively (disabled for .exe distribution)"""
    print("Interactive setup is disabled for the executable version.")
    print("Please manually create sendoria_config.txt using sendoria_config_template.txt as a guide.")
    print("Edit the template file and save it as sendoria_config.txt")
    return False

def ensure_config():
    """Ensure configuration is loaded or created"""
    if not load_config():
        if not create_config_interactively():
            print("Please create sendoria_config.txt manually and try again.")
            return False
    return True

# Bot setup
intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix='!', intents=intents)

# Track last read position
last_read_position = 0

def load_last_position():
    """Load the last read position from file"""
    global last_read_position
    try:
        if os.path.exists(POSITION_FILE):
            with open(POSITION_FILE, 'r') as f:
                last_read_position = int(f.read().strip())
                print(f"Resuming from position: {last_read_position}")
        else:
            # If no position file, start from end of current file
            if os.path.exists(RELAY_FILE):
                last_read_position = os.path.getsize(RELAY_FILE)
                print(f"Starting from end of file: {last_read_position}")
    except Exception as e:
        print(f"Error loading position: {e}, starting from current end")
        if os.path.exists(RELAY_FILE):
            last_read_position = os.path.getsize(RELAY_FILE)

def save_last_position():
    """Save the current read position to file"""
    try:
        with open(POSITION_FILE, 'w') as f:
            f.write(str(last_read_position))
    except Exception as e:
        print(f"Error saving position: {e}")

@bot.event
async def on_ready():
    print(f'{bot.user} has connected to Discord!')
    load_last_position()  # Load where we left off
    check_relay_file.start()

@tasks.loop(seconds=CHECK_INTERVAL)
async def check_relay_file():
    """Check for new chat messages to send to Discord"""
    global last_read_position
    
    if not os.path.exists(RELAY_FILE):
        return
    
    try:
        # Check if file was truncated (reset position if file is smaller)
        file_size = os.path.getsize(RELAY_FILE)
        if file_size < last_read_position:
            last_read_position = 0
            print("Relay file was reset, starting from beginning")
        
        with open(RELAY_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            f.seek(last_read_position)
            new_lines = f.readlines()
            last_read_position = f.tell()
            
        # Save position after reading
        save_last_position()
        
        # Cleanup: If file is getting large, truncate it but preserve position
        if file_size > 50000:  # If file is over ~50KB
            print(f"Relay file is large ({file_size} bytes), cleaning up...")
            # Read all content and keep only recent messages (last 100 lines)
            with open(RELAY_FILE, 'r', encoding='utf-8', errors='ignore') as f:
                all_lines = f.readlines()
            
            if len(all_lines) > 100:
                # Keep last 100 lines
                recent_lines = all_lines[-100:]
                with open(RELAY_FILE, 'w', encoding='utf-8') as f:
                    f.writelines(recent_lines)
                # Reset position to start of cleaned file
                last_read_position = os.path.getsize(RELAY_FILE)
                save_last_position()
                print(f"Cleaned relay file, kept {len(recent_lines)} recent messages")
        
        for line in new_lines:
            line = line.strip()
            if not line:
                continue
            
            # Parse: [timestamp] direction | chat_type | sender | message
            try:
                parts = line.split(' | ', 3)
                if len(parts) != 4:
                    continue
                
                timestamp_direction = parts[0]
                chat_type = parts[1]
                sender = parts[2]
                message = parts[3]
                
                # Get direction from timestamp_direction
                direction = timestamp_direction.split('] ')[1] if '] ' in timestamp_direction else 'UNKNOWN'
                
                # Only send to Discord (don't relay our own bot messages)
                if chat_type in CHANNEL_MAP:
                    channel = bot.get_channel(CHANNEL_MAP[chat_type])
                    if channel:
                        direction_emoji = "📤" if direction == "OUT" else "📥"
                        embed = discord.Embed(
                            title=f"{direction_emoji} {chat_type}",
                            description=f"**{sender}:** {message}",
                            color=0x00ff00 if direction == "OUT" else 0x0099ff
                        )
                        await channel.send(embed=embed)
                        print(f"Sent to Discord: {chat_type} - {sender}: {message}")
            
            except Exception as e:
                print(f"Error parsing line: {line} - {e}")
    
    except Exception as e:
        print(f"Error reading relay file: {e}")

@bot.event
async def on_message(message):
    # Don't respond to ourselves
    if message.author == bot.user:
        return
    
    # Don't respond to webhook messages (these are from the original TellNotifier)
    if message.webhook_id is not None:
        print(f"Ignoring webhook message: {message.content}")
        return
    
    # Don't respond to other bots
    if message.author.bot:
        print(f"Ignoring bot message from {message.author.name}")
        return
    
    # Check if message is in one of our monitored channels
    reverse_channel_map = {v: k for k, v in CHANNEL_MAP.items()}
    if message.channel.id in reverse_channel_map:
        chat_type = reverse_channel_map[message.channel.id]
        
        # Write to response file for addon to read
        try:
            content = message.content.strip()
            
            # Handle tell format: /tell TargetName message OR /t TargetName message
            if chat_type == 'Tell' and (content.startswith('/tell ') or content.startswith('/t ')):
                # Parse: /tell TargetName rest of message OR /t TargetName rest of message
                if content.startswith('/tell '):
                    tell_content = content[6:].strip()  # Remove '/tell ' (6 characters)
                elif content.startswith('/t '):
                    tell_content = content[3:].strip()  # Remove '/t ' (3 characters)
                
                parts = tell_content.split(' ', 1)  # Split into target and message
                if len(parts) >= 2:
                    target = parts[0]
                    tell_message = parts[1]
                    with open(RESPONSE_FILE, 'a', encoding='utf-8') as f:
                        f.write(f"Tell|{target}|{tell_message}\n")
                    print(f"Tell parsed: target={target}, message={tell_message}")
                else:
                    await message.add_reaction('❌')
                    print(f"Invalid tell format. Use: /tell TargetName message or /t TargetName message")
                    return
            else:
                # Regular format for other chat types
                with open(RESPONSE_FILE, 'a', encoding='utf-8') as f:
                    f.write(f"{chat_type}|{content}\n")
            
            # Add reaction to show it was processed
            await message.add_reaction('✅')
            print(f"Processed USER message in {chat_type}: {content}")
        
        except Exception as e:
            print(f"Error writing response: {e}")
            await message.add_reaction('❌')
    
    await bot.process_commands(message)

if __name__ == "__main__":
    print("🚀 Starting Sendoria Discord Bot...")
    print("Bidirectional FFXI ↔ Discord Chat Relay")
    print("=" * 50)
    
    # Load configuration
    if not ensure_config():
        print("❌ Configuration failed. Exiting.")
        input("Press Enter to exit...")
        sys.exit(1)
    
    print("✅ Configuration ready")
    print("🔄 Starting Discord bot...")
    
    try:
        bot.run(BOT_TOKEN)
    except discord.LoginFailure:
        print("❌ ERROR: Invalid bot token!")
        print("Please check your bot token in sendoria_config.txt")
        input("Press Enter to exit...")
    except Exception as e:
        print(f"❌ ERROR: {e}")
        input("Press Enter to exit...")
