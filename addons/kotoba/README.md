# Kotoba v2.0 - Multi-Language Chat Assistant (LLM Edition)

**Real-time Japanese ⇄ English translation for FFXI using an LLM (DeepSeek/OpenAI-compatible) API + SQLite durable cache**

## What is Kotoba?

Kotoba is an Ashita addon that automatically translates Japanese messages in FFXI chat to English using an external Python translator. It uses a fast, reliable file-based system (inspired by Sendoria) with an **LLM backend** (any OpenAI-compatible API — DeepSeek, OpenAI, local Ollama, etc.) enhanced by a custom FFXI terminology glossary for natural, gaming-appropriate translations. Translations are cached in a durable **SQLite database (`translations.db`)** so repeated phrases are retrieved instantly — even across restarts.

## Features

- ✅ **Auto-Translate Incoming Messages** - Japanese → English automatically in game chat
- ✅ **Manual Translation** - Type English → translate to Japanese for sending
- ✅ **FFXI-Aware** - Recognizes **500+ FFXI terms** (jobs, endgame, monsters, items, areas, slang)
- ✅ **Casual Tone** - "ソーティやる？" → "Wanna do Sortie?" (not stiff formal translation)
- ✅ **Community Glossary** - Add your own terms in `ffxi_glossary.txt` (hot-reloads!)
- ✅ **Smart Detection** - Automatically suggests missing glossary terms
- ✅ **SQLite Durable Cache** - `translations.db` stores every translation for instant retrieval, even after restarts
- ✅ **Warm Cache Seeding** - Run `build_seed_db.py` to pre-load common phrases on first run
- ✅ **Stats Tracking** - See cache hit rates, glossary usage, and more
- ✅ **Non-Blocking** - Never freezes the game
- ✅ **Reliable** - File-based system is bulletproof
- ✅ **Any OpenAI-Compatible API** - Works with DeepSeek, OpenAI, local Ollama, LM Studio, and more

## Setup (2 Minutes)

### Step 1: One-Click Install (One-Time)
1. Navigate to `C:\Ashita\addons\kotoba\`
2. Double-click **`install.bat`** — installs Python dependencies (`httpx`) and sets up the environment

### Step 2: Configure LLM API Key
1. Open `C:\Ashita\addons\kotoba\translator_config.txt`
2. Replace `YOUR_API_KEY_HERE` with your actual API key (DeepSeek, OpenAI, or any OpenAI-compatible provider)
3. Set the API base URL and model name to match your provider (e.g. DeepSeek, OpenAI, or a local Ollama endpoint)

### Step 3: Start the Translator Service
1. Double-click **`start_translator.bat`**
2. First run will auto-install `httpx` and build the seed database (`translations.db`) via `build_seed_db.py`
3. Leave the window open while playing FFXI
4. You'll see a fancy startup banner! 🌸

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
Python translator checks SQLite cache (translations.db)
    ↓
Cache hit? → Return instantly
Cache miss? → Translate with LLM (DeepSeek/OpenAI-compatible) + FFXI glossary → store in cache
    ↓
Python translator writes to translation_results.txt
    ↓
Kotoba reads results → prints English translation to game chat
    ↓
Translation appears in ~1 second (instant on cache hit)!
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

### "ModuleNotFoundError: httpx"
```
pip install httpx
```

### "Could not load API key"
- Check that `translator_config.txt` contains your API key
- Format: `API_KEY=your_key_here`
- Get a key from your LLM provider (DeepSeek, OpenAI, etc.) or run a local Ollama server

### "Translation is slow"
- First translation of new text: ~1 second (normal)
- Cached translations: **instant** (served from `translations.db`)
- Check stats - high cache hit rate = fast translations!
- Run `build_seed_db.py` to warm the cache with common phrases

## Translation Quality

**Current**: LLM-powered translation (DeepSeek/OpenAI-compatible API)
- 🏆 Natural, context-aware Japanese accuracy
- 🗣️ Excellent context understanding for gaming slang
- ✅ Enhanced with custom FFXI glossary (500+ terms)
- ✅ Casual tone via LLM prompting
- ⚡ Fast and reliable, with SQLite durable cache
- 💰 Affordable with DeepSeek; free with local Ollama

**Why LLM?**
- Understands nuance and context ("やる？" → "Wanna do?" not "Will you do?")
- Handles casual/informal MMO chat style naturally
- Works with any OpenAI-compatible endpoint (DeepSeek, OpenAI, local Ollama, LM Studio, etc.)

## Performance

- **Memory**: ~50MB Python, ~10MB addon
- **CPU**: Minimal (only active during translation)
- **Disk**: Tiny temp files cleared automatically; `translations.db` cache grows with usage
- **Game Impact**: Zero (file I/O is async)

## Reference Guides

- **`GLOSSARY_COVERAGE.md`** - **Complete term list (500+ terms!)** - See everything Kotoba knows!
- **`GLOSSARY_GUIDE.md`** - Complete guide to customizing translations
- **`FFXI_ABBREVIATIONS_REFERENCE.md`** - English FFXI slang decoder (what does "LFM for Dyna" mean?)
- **`ffxi_glossary.txt`** - Your editable glossary (500+ Japanese terms pre-loaded!)

## Credits

- **Architecture**: Inspired by [Sendoria](https://github.com/trevorssf/Sendoria)'s reliable file-based approach
- **Translation**: LLM-powered translation (DeepSeek/OpenAI-compatible) + custom FFXI glossary (500+ terms)
- **FFXI Terms**: [FFXIclopedia Dictionary](https://ffxiclopedia.fandom.com/wiki/Final_Fantasy_XI_Dictionary_of_Terms_and_Slang)
- **Author**: Zodiarchy @ Asura

---

**Enjoy natural, fast translations in FFXI!** 🎉
