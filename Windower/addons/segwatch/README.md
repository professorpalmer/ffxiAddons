# SegWatch - Moogle Segment Tracker

A Windower addon for Final Fantasy XI that tracks Moogle Segments obtained during Odyssey content.

## Features

- **Real-time Segment Tracking**: Monitors your current segment count and total segments gained
- **Rate Calculation**: Shows segments per hour and segments per 30 minutes
- **Run Statistics**: Tracks segments gained during your current run with duration
- **Zone Detection**: Automatically detects when you're in Odyssey zones
- **Customizable Display**: Configurable text box with draggable positioning
- **Manual Input**: Commands to manually add or set segment counts

## Installation

1. Place the `segwatch` folder in your Windower addons directory
2. Load the addon with: `//lua load segwatch`
3. The addon will automatically start tracking segments

## Commands

### Basic Commands
- `//sw reload` - Reload the addon
- `//sw unload` - Unload the addon
- `//sw reset` - Reset all statistics
- `//sw stats` - Display detailed statistics in chat
- `//sw status` - Show current segment status
- `//sw refresh` - Manually refresh segment data from the server

### Manual Segment Management
- `//sw add <amount>` - Manually add segments (e.g., `//sw add 100`)
- `//sw set <amount>` - Set your segment count to a specific value (e.g., `//sw set 500`)

### Text Box Commands
- `//sw show` - Show the text box
- `//sw hide` - Hide the text box
- `//sw pos <X> <Y>` - Move the text box to coordinates X/Y
- `//sw font <font_name>` - Change the font
- `//sw size <point_size>` - Change the font size
- `//sw color <R> <G> <B>` - Change text color (0-255)
- `//sw bg_color <R> <G> <B>` - Change background color (0-255)
- `//sw bg_transparency <number>` - Change background transparency (0-1)

## Display Information

The addon displays the following information:

### Default Display (Outside Odyssey)
- Current Segments
- Total Segments Gained
- Current Rate (segments/hour)
- Run Segments (this session)
- Run Rate (segments/30min)

### Odyssey Display (In Odyssey Zones)
- All default information plus:
- Run Duration (HH:MM:SS format)

## Configuration

The addon automatically creates a `settings.xml` file in the `data` folder. You can modify:

- **Display Strings**: Customize what information is shown
- **Text Box Settings**: Position, colors, fonts, and transparency
- **Gain Messages**: Toggle chat notifications when segments are gained

### Customizing Display Strings

You can modify the display format by editing the strings in `settings.xml` or using the `//sw eval` command. Available variables:

- `segments.current` - Current segment count
- `segments.total` - Total segments gained since addon load
- `segments.rate` - Current rate (segments/hour)
- `segments.run_segments` - Segments gained this run
- `segments.run_rate` - Run rate (segments/30min)
- `segments.run_duration` - Duration of current run

## How It Works

1. **Packet Monitoring**: The addon monitors game packets to detect segment gains
2. **Rate Calculation**: Calculates rates based on a 10-minute rolling window
3. **Run Tracking**: Resets run statistics when changing zones
4. **Zone Detection**: Automatically detects Odyssey zones for enhanced display

## Technical Details

### How It Works
SegWatch monitors packet 0x118 (Currency2) which contains Mog Segments at offset 0x8C as a signed 32-bit integer. The addon:
- Checks last incoming packet on load for instant display (like PointWatch)
- Automatically requests updates on login and zone changes
- Updates when you open menus (F10/F11)
- Reads your current segment count from the game
- Tracks gains when segments increase
- Calculates rates per hour and per 30 minutes
- Shows run-specific statistics

### Troubleshooting

If the addon shows 0 segments:
1. Make sure you're logged in
2. Open your Currencies 2 menu to trigger an update
3. Zone to force a currency packet
4. Use `//sw check` to enable debug mode and verify packets are being received

### Message IDs
The addon also monitors action messages for segment drops. These message IDs may need updating:

```lua
local segment_messages = {
    185, -- Update these with actual message IDs
    186, -- for segment drops in your game
    187,
}
```

### Manual Tracking
If automatic detection doesn't work, use the manual commands:
- `//sw add <amount>` to add segments as you gain them
- `//sw set <amount>` to set your current count

### Performance
The addon updates every 30 frames (about once per second) to minimize performance impact.

## Version History

- **1.0** - Initial release with basic segment tracking functionality

## Credits

Based on the PointWatch addon structure and design patterns.

## License

This addon is provided as-is for educational and personal use. Please respect the original game's terms of service.
