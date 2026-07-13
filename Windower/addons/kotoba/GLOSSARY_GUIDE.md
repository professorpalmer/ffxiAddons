# Kotoba Community Glossary Guide

## Quick Reference

### What is the Community Glossary?

The `ffxi_glossary.txt` file lets you add custom Japanese→English translations that apply **before** sending text to Google Translate. This ensures game-specific terms, slang, and abbreviations translate correctly.

---

## How It Works

```
Japanese Chat: "ソーティやる？"
       ↓
Glossary:      ソーティ → Sortie
       ↓
Preprocessed:  "Sortie - Wanna do it?"
       ↓
Google:        Translates the preprocessed text
       ↓
Post-process:  Casual tone adjustment
       ↓
Final Result:  "Wanna do Sortie?"
```

---

## File Format

**Location**: `C:\Ashita\addons\kotoba\ffxi_glossary.txt`

**Format**: One term per line, `Japanese|English`

```
# Comments start with #
# Blank lines are ignored

# Endgame content
エーベル|Aeonic
アレキ|Alexandrite

# Common abbreviations
メリポ|merit party
倉庫|mule

# Server slang
あいつ|that guy
こっち|over here
```

---

## Hot-Reload Feature

**NO RESTART NEEDED!** Changes apply immediately:

1. Edit `ffxi_glossary.txt`
2. Save the file
3. Next translation uses new terms automatically!

The translator checks for file changes every time it loads the glossary.

---

## Finding Terms to Add

### Method 1: Check Suggested Terms Log

Kotoba automatically detects problematic translations!

**File**: `suggested_terms.log`

**Example**:
```
[2025-01-05 14:30:22] Japanese chars in translation
  Original:    エーベル作りたい
  Translation: Want to make エーベル
  Suggest: Add to ffxi_glossary.txt: エーベル|Aeonic
```

**Action**: Copy the suggested term to `ffxi_glossary.txt`!

### Method 2: Notice Bad Translations

When you see a weird translation in-game:
1. Check what the Japanese original was
2. Figure out the correct English meaning
3. Add to `ffxi_glossary.txt`

### Method 3: Pre-emptively Add Common Terms

Add terms you **know** will appear often:
- Your linkshell's nicknames
- Common party chat abbreviations
- Server-specific memes/slang

---

## Best Practices

### 1. Longest Match First

The glossary automatically processes **longest terms first** to avoid partial replacements.

**Example**:
```
# Good - both will work correctly
ダイナミス|Dynamis
ダイナミス・バストゥーク|Dynamis - Bastok

# The longer term is checked first, so no conflicts!
```

### 2. Override Built-in Terms

Community glossary terms **override** built-in terms.

**Built-in**: `おつ|thanks`  
**Your file**: `おつ|gj everyone!`  
**Result**: Your version wins!

### 3. Use Natural English

Match the casual tone of FFXI chat:

```
# Good
やばい|awesome
すげー|damn
まじ|fr

# Too formal (avoid)
やばい|That is quite extraordinary
すげー|Most impressive
```

### 4. Consider Context

Some terms have multiple meanings. Pick the most common:

```
# Gaming context
やる|do
走る|run (as in "speed run")
```

---

## Pre-Loaded Glossary

**The included `ffxi_glossary.txt` already has 500+ terms!** Including:

### ✅ **Already Included (No setup needed!)**

**Endgame Content:**
- ソーティ, オデシー, アンバス, デュナミス, リンバス, サルベージ, etc.

**All Jobs:**
- 戦士 (WAR), 白魔 (WHM), 黒魔 (BLM), 忍者 (NIN), etc.

**Party Terms:**
- タンク (tank), 前衛 (DD), 後衛 (support), 釣り (pull), ヘイト (hate)

**Battle Terms:**
- 連携 (SC), マジバ (MB), ウェポンスキル (WS), 範囲 (AoE)

**Status Effects:**
- リジェネ (Regen), ヘイスト (Haste), 空蝉 (Utsusemi), スリプル (Sleep)

**Monsters:**
- スケルトン, ゴブリン, マンドラ, エレメンタル, NM

**Areas:**
- ジュノ (Jeuno), バストゥーク (Bastok), ボスディン (Beaucedine), etc.

**Items:**
- レリック (Relic), エーベル (Aeonic), 武器 (weapon), 防具 (armor)

**Chat Expressions:**
- わかった (got it), おつ (thanks), やばい (sick), すごい (amazing)

**Common Phrases:**
- 手伝って (help), 待って (wait), 教えて (teach me), 欲しい (want)

**Elements:**
- 火 (Fire), 氷 (Ice), 風 (Wind), 雷 (Thunder), etc.

**Directions:**
- 北 (north), こっち (over here), 近く (nearby)

**Questions:**
- 何 (what), 誰 (who), どこ (where), いつ (when)

### 📝 **Add Your Own Terms:**

```
# === Your Linkshell Slang ===
あいつ|that guy
こいつ|this guy
あの人|that person

# === Server Specific ===
# Add terms unique to your server

# === Player Nicknames ===
# Add friend/enemy nicknames
```

---

## Testing Your Terms

1. Add a term to `ffxi_glossary.txt`
2. Save the file
3. Use `/kotoba` in-game
4. Type the Japanese text in the input box
5. Click "Translate & Send"
6. Check if it translates correctly!

---

## Stats & Monitoring

Press **Ctrl+C** in the translator window to see:
- How many community terms are loaded
- How many glossary terms were used
- Cache hit rate (higher = better performance!)

---

## Sharing Your Glossary

Want to share with your linkshell?

1. Copy your `ffxi_glossary.txt`
2. Share the file
3. Everyone drops it in their `kotoba` folder
4. Instant shared translations!

---

## Troubleshooting

### "My term isn't working"

**Check**:
- ✅ File is saved as UTF-8 encoding
- ✅ Format is exactly `Japanese|English` with `|` separator
- ✅ No extra spaces: `term|translation` (not `term | translation`)
- ✅ Japanese text matches exactly (case/spacing matters)

### "Can I use English→Japanese?"

Currently, the glossary only processes Japanese→English (when `source_lang = 'ja'`).

English→Japanese translation doesn't use the glossary (yet!).

### "How many terms can I add?"

**Unlimited!** The file can be as large as you want. Performance impact is minimal (glossary loads once and caches).

---

## Advanced: Phrase Patterns

You can include full phrases, not just single words:

```
# Full phrases work too!
今から行く|going now
ちょっと待って|wait a sec
わかりました|got it
```

---

**Questions?** Check the main `README.md` or open an issue!

Happy translating! 🌸

