# Kotoba v1.1 - Multi-Language Chat Assistant (DeepL Edition)

**Real-time Japanese ⇄ English translation for FFXI using DeepL API + file-based I/O system**

## What is Kotoba?

Kotoba is an Ashita addon that automatically translates Japanese messages in FFXI chat to English using an external Python translator. It uses a fast, reliable file-based system (inspired by Sendoria) with **DeepL API** enhanced by a custom FFXI terminology glossary for natural, gaming-appropriate translations.

## Features

- ✅ **Auto-Translate Incoming Messages** - Japanese → English automatically in game chat
- ✅ **Manual Translation** - Type English → translate to Japanese for sending
- ✅ **FFXI-Aware** - Recognizes **500+ FFXI terms** (jobs, endgame, monsters, items, areas, slang)
- ✅ **Casual Tone** - "ソーティやる？" → "Wanna do Sortie?" (not stiff formal translation)
- ✅ **Community Glossary** - Add your own terms in `ffxi_glossary.txt` (hot-reloads!)
- ✅ **Smart Detection** - Automatically suggests missing glossary terms
- ✅ **Translation Cache** - Repeated phrases translate instantly
- ✅ **Stats Tracking** - See cache hit rates, glossary usage, and more
- ✅ **Non-Blocking** - Never freezes the game
- ✅ **Reliable** - File-based system is bulletproof

## Setup (2 Minutes)

### Step 1: Install Python (One-Time)
1. Download Python 3.8+ from https://www.python.org/downloads/
2. **IMPORTANT**: Check "Add Python to PATH" during installation
3. Verify: Open Command Prompt, type `python --version`

### Step 2: Configure DeepL API Key
1. Sign up for a free DeepL API account at https://www.deepl.com/pro-api
2. Copy your API key from the DeepL dashboard
3. Open `C:\Ashita\addons\kotoba\translator_config.txt`
4. Replace `YOUR_DEEPL_API_KEY_HERE` with your actual key

### Step 3: Start the Translator Service
1. Navigate to `C:\Ashita\addons\kotoba\`
2. Double-click **`start_translator.bat`**
3. First run will auto-install DeepL library (~30 seconds)
4. Leave the window open while playing FFXI
5. You'll see a fancy startup banner! 🌸

### Step 4: Use Kotoba In-Game
```
/addon load kotoba
/kotoba
```
Enable the **"Auto-Translate Incoming"** checkbox and you're done!

## How It Works

```
Japanese message arrives in game
    ↓
Kotoba writes to translation_queue.txt
    ↓
Python translator reads queue → translates with FFXI glossary → writes to translation_results.txt
    ↓
Kotoba reads results → prints English translation to game chat
    ↓
Translation appears in ~1 second!
```

## Commands

- `/kotoba` or `/kb` - Toggle window
- `/kotoba help` - Show help
- `/kotoba clear` - Clear message history
- `/kotoba debug` - Toggle debug mode

## Translation Examples

| Japanese | Old (stiff) | Kotoba (natural) |
|----------|-------------|------------------|
| ソーティやる？ | Are you going to do a sortie? | Wanna do Sortie? |
| 今からオデシー行こ | Let's go to Odyssey now | Let's go Odyssey now |
| 白魔募集中 | White mage recruiting | LFM WHM |
| おつかれ！ | Thank you for your hard work! | gj! |
| タンク欲しい | I want a tank | Want tank |
| ヘイスト ください | Please give me haste | Haste pls |
| ちょっと待って | Wait a moment | Wait a sec |
| やばい、すごい！ | That is dangerous, amazing! | Sick, amazing! |
| 手伝ってください | Please help me | Help pls |
| メリポ行く？ | Are you going to go merit points? | Wanna go merit? |

## Customizing Translations

### Easy Way: Community Glossary (Recommended!)

Edit `ffxi_glossary.txt` - changes apply **instantly** (no restart needed!):

```
# Add your terms here (one per line)
エーベル|Aeonic
アレキ|Alexandrite
メリポ|merit party
倉庫|mule

# Server-specific slang
あいつ|that guy
こっち|over here

# Your linkshell's nicknames
# Character names, etc.
```

**Hot-reload**: Save the file, next translation uses new terms!

### Advanced Way: Edit Python Code

Edit `translator.py` to modify built-in glossary:

```python
FFXI_GLOSSARY = {
    'your_jp_term': 'your_translation',
    # Add more here!
}
```

Requires translator restart.

## Missing Glossary Terms?

Kotoba **automatically detects** terms that might need glossary entries!

Check `suggested_terms.log` for:
- Japanese characters remaining in translations
- Terms that weren't translated properly
- Suggestions for `ffxi_glossary.txt` additions

**Example log entry:**
```
[2025-01-05 14:30:22] Japanese chars in translation
  Original:    エーベル作りたい
  Translation: Want to make エーベル
  Suggest: Add to ffxi_glossary.txt: エーベル|<your_translation>
```

Then add to `ffxi_glossary.txt`:
```
エーベル|Aeonic
```

Next time it translates perfectly!

## Translation Stats

Press **Ctrl+C** in the translator window to see stats:
- Total translations
- Cache hit rate (higher = faster!)
- Glossary terms used
- Community glossary size
- Uptime

Or wait 5 minutes - stats print automatically!

## Troubleshooting

### "No translations appearing"
- ✅ Make sure `start_translator.bat` is running
- ✅ Check translator window for errors
- ✅ Verify Python is in PATH: `python --version`

### "ModuleNotFoundError: deepl"
```
pip install deepl
```

### "Could not load DeepL API key"
- Check that `translator_config.txt` contains your API key
- Format: `DEEPL_API_KEY=your_key_here`
- Get a free key at https://www.deepl.com/pro-api

### "Translation is slow"
- First translation of new text: ~1 second (normal)
- Cached translations: **instant**
- Check stats - high cache hit rate = fast translations!

## Translation Quality

**Current**: DeepL API (requires free signup)
- 🏆 Professional-grade Japanese accuracy
- 🗣️ Excellent context understanding for gaming slang
- ✅ Enhanced with custom FFXI glossary (500+ terms)
- ✅ Casual tone post-processing
- ⚡ Fast and reliable
- 💰 500,000 chars/month free tier

**Why DeepL?**
- 1.7x better than Google Translate for Japanese
- Better at casual/informal language (MMO chat style)
- Understands nuance and context ("やる？" → "Wanna do?" not "Will you do?")

## Performance

- **Memory**: ~50MB Python, ~10MB addon
- **CPU**: Minimal (only active during translation)
- **Disk**: Tiny temp files cleared automatically
- **Game Impact**: Zero (file I/O is async)

## Reference Guides

- **`GLOSSARY_COVERAGE.md`** - **Complete term list (500+ terms!)** - See everything Kotoba knows!
- **`GLOSSARY_GUIDE.md`** - Complete guide to customizing translations
- **`FFXI_ABBREVIATIONS_REFERENCE.md`** - English FFXI slang decoder (what does "LFM for Dyna" mean?)
- **`ffxi_glossary.txt`** - Your editable glossary (500+ Japanese terms pre-loaded!)

## Credits

- **Architecture**: Inspired by [Sendoria](https://github.com/trevorssf/Sendoria)'s reliable file-based approach
- **Translation**: DeepL API + custom FFXI glossary (500+ terms)
- **FFXI Terms**: [FFXIclopedia Dictionary](https://ffxiclopedia.fandom.com/wiki/Final_Fantasy_XI_Dictionary_of_Terms_and_Slang)
- **Author**: Zodiarchy @ Asura

---

**Enjoy natural, fast translations in FFXI!** 🎉
