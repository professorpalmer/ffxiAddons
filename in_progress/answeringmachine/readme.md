# AnsweringMachine

An Ashita 4 addon that records tell conversations and provides away message functionality for Final Fantasy XI.

## Features

- **Tell Recording**: Automatically records all incoming and outgoing tells
- **Away Messages**: Set custom away messages that are automatically sent to players who tell you
- **Visual Notifications**: Animated overlay showing unseen message count
- **Conversation Playback**: Review recorded conversations with timestamps
- **GM Detection**: Won't send away messages to GMs
- **Activity Tracking**: Marks messages as seen based on your activity

## Installation

1. Download the `answering_machine` folder
2. Place it in your Ashita 4 `addons` directory
3. Load the addon in-game: `/addon load answering_machine`

## Commands

| Command | Description |
|---------|-------------|
| `/am help` | Display all available commands |
| `/am msg <message>` | Set your away message |
| `/am list` | List all players who have sent you tells |
| `/am play [name]` | Play back all messages or messages from specific player |
| `/am clear [name]` | Clear all recordings or recordings from specific player |
| `/am pos <x> <y>` | Set the position of the message overlay |

**Aliases:** `/answeringmachine` or `/am`

## Usage Examples

```
/am msg I'm currently away, will respond when I return!
/am list
/am play Playerone
/am clear Playerone
/am pos 100 200
```

## How It Works

1. **Recording**: The addon automatically records all tells (incoming and outgoing)
2. **Away Messages**: When someone tells you for the first time after setting an away message, they'll receive your auto-reply
3. **Visual Indicator**: An animated overlay appears when you have unseen messages
4. **Activity Detection**: Messages are marked as "seen" when you're active in the game

## Message Overlay

- Appears when you have unseen tells
- Shows count of unseen messages
- Animated background color for visibility
- Can be repositioned with `/am pos <x> <y>`

## Technical Notes

This is an Ashita 4 port of the original Windower AnsweringMachine addon by Byrth. Key conversions include:

- Event system migration from Windower to Ashita 4
- Text overlay system using ImGui instead of Windower texts
- Packet handling for outgoing tell detection
- Activity tracking via input monitoring

## Requirements

- Ashita 4
- FFXI Client

## Author

- **Original**: Byrth (Windower version)
- **Ashita 4 Port**: Palmer

## Version

1.4 - Ashita 4 Edition

## Repository

Part of the unofficial Ashita 4 addon collection: https://github.com/professorpalmer/Ashita4Addons
