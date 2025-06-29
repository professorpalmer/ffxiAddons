# Pouches

Automatically uses items like potions, remedies, and food repeatedly until you run out or stop.

## Installation

1. Drop the `pouches` folder into your Ashita `addons` directory
2. Load in-game: `/addon load pouches`
3. *Optionally* you can add `/addon load pouches` to your default.txt in the scripts folder to have it automatically load with the game.

## Usage

```
/pouches <item_name>     - Start auto-using an item
/pouches stop           - Stop current operation
```

## Examples

```
/pouches remedy         - Auto-use remedies
/pouches "hi-potion"    - Auto-use hi-potions  
/pouches "vile elixir"  - Auto-use vile elixirs
/pouches "echo drops"   - Auto-use echo drops
```

## Auto-Stop Conditions

The addon stops automatically when:
- You run out of the item
- You move or engage in combat
- You change status (casting, resting, etc.)

## Notes

- Only works with items that can target yourself
- Only searches main inventory
- Uses proper timing delays between uses
- Shows usage count when finished

**Original Windower addon by Omnys@Valefor**
