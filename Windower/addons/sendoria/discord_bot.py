#!/usr/bin/env python3
"""
Sendoria Discord Bot
Bidirectional Discord chat relay for FFXI
Reads chat from chat_relay.txt and sends to Discord
Reads Discord messages and writes to discord_responses.txt
"""

import discord
from discord.ext import commands, tasks
import os
import time
import asyncio

# Configuration
BOT_TOKEN = "YOUR_DISCORD_BOT_TOKEN_HERE"

# Your Discord channel IDs
CHANNEL_MAP = {
    # Chat type -> Discord channel ID
    'Tell': 1234567890123456789,        # Replace with your #tells channel ID
    'Party': 1234567890123456789,       # Replace with your #party channel ID
    'Linkshell1': 1234567890123456789,  # Replace with your #linkshell1 channel ID
    'Linkshell2': 1234567890123456789,  # Replace with your #linkshell2 channel ID
    'Say': 1234567890123456789,         # Replace with your #say channel ID
    'Shout': 1234567890123456789,       # Replace with your #shout channel ID
    'Yell': 1234567890123456789,        # Replace with your #yell channel ID
    'Unity': 1234567890123456789,       # Replace with your #unity channel ID
}

# File paths
RELAY_FILE = "chat_relay.txt"
RESPONSE_FILE = "discord_responses.txt"
POSITION_FILE = "bot_position.txt"  # Track where we left off

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

@tasks.loop(seconds=0.5)
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
                with open(RELAY_FILE, 'w', encoding='utf-8', errors='ignore') as f:
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
                    discord_username = message.author.display_name or message.author.name
                    formatted_tell = f"[{discord_username}] {tell_message}"
                    with open(RESPONSE_FILE, 'a', encoding='utf-8', errors='ignore') as f:
                        f.write(f"Tell|{target}|{formatted_tell}\n")
                    print(f"Tell parsed: target={target}, message={formatted_tell}")
                else:
                    await message.add_reaction('❌')
                    print(f"Invalid tell format. Use: /tell TargetName message or /t TargetName message")
                    return
            else:
                # Regular format for other chat types - include Discord username
                discord_username = message.author.display_name or message.author.name
                formatted_message = f"[{discord_username}] {content}"
                with open(RESPONSE_FILE, 'a', encoding='utf-8', errors='ignore') as f:
                    f.write(f"{chat_type}|{formatted_message}\n")
            
            # Add reaction to show it was processed
            await message.add_reaction('✅')
            print(f"Processed USER message in {chat_type}: {content}")
        
        except Exception as e:
            print(f"Error writing response: {e}")
            await message.add_reaction('❌')
    
    await bot.process_commands(message)

if __name__ == "__main__":
    print("Starting Sendoria Discord Bot...")
    print("Bidirectional FFXI ↔ Discord Chat Relay")
    print("Make sure discord.py is installed: pip install discord.py")
    print("Make sure the bot is running in the Sendoria folder: python sendoria/discord_bot.py")
    bot.run(BOT_TOKEN)
