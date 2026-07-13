# Kotoba for Windower 4 (Wave 2)

Multi-language FFXI chat assistant with LLM translation (DeepSeek / OpenAI-compatible), SQLite durable cache, and an on-screen control panel.

Core behavior matches **Ashita Kotoba v2.0** (auto-translate, queue/results/heartbeat IPC, headless `pythonw` spawn). Target languages: **ja / en / es / fr / de / ko / zh**.

## Install

1. Copy this folder to your Windower addons directory, e.g. `C:\Windower\addons\kotoba\`  
   (or use this repo path if you already load Windower addons from here).
2. Double-click **`install.bat`** — installs `httpx`, creates `translator_config.txt` from the example if missing, builds the seed DB.
3. Edit **`translator_config.txt`** and set your LLM API key / base URL / model.  
   Never commit that file (it is gitignored).
4. In-game: `//lua load kotoba`  
   The addon auto-starts `pythonw translator.py` headlessly and touches `heartbeat.txt` so the translator exits when you leave.

Manual translator console (optional): run `start_translator.bat`.

## On-screen panel

Title: **Kotoba v2.0 - Translation Assistant**

| Control | Click action |
|---------|--------------|
| `[x] Auto-Translate Incoming` | Toggle auto-translate |
| `Language: …` | Cycle ja → en → es → fr → de → ko → zh |
| Compose preview | Set via `//kb compose <text>` |
| `[Translate & Send]` | Translate compose → `settings.language` and send |
| `[Copy]` / `[Paste]` / `[Clear]` | Best-effort clipboard buffer + compose |
| `Send to: …` | Cycle say / party / tell / ls / ls2 / shout / yell |
| Tell target line | Shown when channel is tell; set with `//kb tell <name>` |

Drag the panel by the title/background to reposition (position is saved).

**Translate & Send / `//kb t` / `//kb send` language rules:** compose text is treated as **English** when the target is not `en`; when the target is `en`, source is **Japanese** (incoming-style).

## Commands

| Command | Action |
|---------|--------|
| `//kb` / `//kotoba` | Toggle window visibility |
| `//kb toggle` | Same as above |
| `//kb on` / `//kb off` | Enable / disable auto-translate |
| `//kb auto` | Toggle auto-translate |
| `//kb status` | Show settings + cache counts |
| `//kb t <text>` | Translate to `settings.language` (source en, or ja if target en) |
| `//kb te <text>` | Translate JA → EN |
| `//kb send <channel> <text>` | Translate to `settings.language` and send |
| `//kb compose <text>` | Set compose buffer (panel preview) |
| `//kb channel <name>` | Set default send channel |
| `//kb cyclechannel` | Cycle send channel |
| `//kb lang <ja\|en\|es\|fr\|de\|ko\|zh>` | Set target language |
| `//kb cyclelang` | Cycle target language |
| `//kb tell <name>` | Set tell target for panel Send |
| `//kb clear` | Clear in-memory translation cache |
| `//kb debug` | Toggle debug mode |
| `//kb help` | Help |

Incoming Japanese chat is auto-queued when auto-translate is on; English results print as `[Kotoba] …` in game chat.

## How it works

```
JP chat → kotoba.lua → translation_queue.txt
                      → translator.py (+ translations.db / LLM)
                      → translation_results.txt → game chat
heartbeat.txt keeps the Python process alive while the addon is loaded
```

## Attribution

- **Ashita Kotoba** (LLM edition) by Zodiarchy @ Asura — translator, glossary, cache, and feature design.
- Panel click-map / drag patterns adapted from [ruptchat](https://github.com/erupt321/ruptchat) by erupt321 (not a full port).
