Ashita v4 blusets by atom0s modified to support PUP. Ashita v3 pupsets by DivByZero used for additional reference.
- Only tested on retail
 
# PupSets
### Manage pup attachments easily with slash commands

Attachment files shall contain one entry per line starting with head then body then attachments. Head and body entries are required. Attachment entries may be optionally be included up to 12 attachments.

An optional 15th line can contain an animator name that will be automatically equipped to the ranged slot when loading the set.

It is recommended to configure the puppet ingame and use '/pupsets save \<file\>' to create the attachment file instead of manually creating files to avoid issues with elemental capacity.

#### Example attachment file:

    Soulsoother Head
    Valoredge Frame
    Optic Fiber
    Optic Fiber II
    Attuner
    Auto-Repair Kit IV
    Magniplug
    Magniplug II
    Turbo Charger
    Turbo Charger II
    Flame Holder
    Inhibitor II
    Mana Jammer
    Mana Jammer II
    Animator P +1

#### Animator Auto-Selection

When saving sets, the addon will automatically determine the appropriate animator based on the frame type:

- **Melee frames** (Turtle, DD, Bruiser, MDTank, Valoredge, Sharpshot): `Animator P +1`
- **Ranged/Mage frames** (RNG, RNGtank, BLM, WHM, RDM, Soulsoother, Spiritreaver): `Animator P II +1`

#### Commands

- `/pupsets auto-equip-animator <on|off>` - Toggles automatic animator equipping when loading sets
- `/pupsets equip-animator <name>` - Equips the specified animator to the ranged slot
