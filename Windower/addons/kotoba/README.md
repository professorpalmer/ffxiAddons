# Kotoba for Windower 4

FFXI chat translation assistant: LLM backend (DeepSeek / OpenAI-compatible / OpenRouter / Ollama), SQLite cache, FFXI glossary, and an on-screen panel.

**Incoming auto-translate:** Japanese → English  
**Outbound compose:** ja / en / es / fr / de / ko / zh (picker)

Core translator matches **Ashita Kotoba** (`translator.py` is shared — keep in sync with `tools/sync_kotoba_shared.ps1`).

## Install

1. Copy `Windower/addons/kotoba` to your Windower addons folder, e.g.  
   `<YourWindowerInstall>\addons\kotoba\`
2. Double-click **`install.bat`** — installs `httpx`, creates `translator_config.txt` from the example if missing, builds the seed DB.
3. Edit **`translator_config.txt`** and set:
   ```
   LLM_API_KEY=your_key_here
   LLM_BASE_URL=https://api.deepseek.com/v1
   LLM_MODEL=deepseek-chat
   ```
   Never commit that file (gitignored).
4. In-game: `//lua load kotoba`  
   The addon checks your config, then auto-starts `pythonw translator.py` (falls back to `python`). Heartbeat shuts the translator down when you leave.

Optional visible console: run `start_translator.bat`.

### Troubleshooting

| Problem | Fix |
|---------|-----|
| No translations | Confirm `translator_config.txt` has a real `LLM_API_KEY` (not `your_api_key_here`) |
| `python` / `pythonw` missing | Install Python 3.8+ with **Add to PATH**, re-run `install.bat` |
| `ModuleNotFoundError: httpx` | `pip install -r requirements.txt` |
| Stuck keys after typing in panel | `//lua unload kotoba` (forces `keyboard_blockinput 0`) |
| Stale translator | Delete `translator.lock` and reload, or run `start_translator.bat` |

## On-screen panel (v2.1)

| Control | Action |
|---------|--------|
| Auto-translate checkbox | Toggle JP→EN for incoming chat |
| **Language** dropdown | Pick outbound target language |
| **MESSAGE** field | Click → type into Kotoba (keys isolated from the game) |
| **Send / Copy / Paste / Clear** | Translate+send, clipboard, clear compose |
| **Send to** dropdown | say / party / tell / ls / ls2 / shout / yell |
| **TELL TARGET** | Shown when channel is Tell — click to type name |

**Typing (Windower 4):** There is no ImGui on W4. Kotoba uses:

1. `keyboard_blockinput 1` while editing  
2. Temporary `%key` binds → `//kotoba _k …` so keys never hit the game  
3. **Enter** locks the field · **Esc** cancels (also closes open dropdowns)

Drag the dark panel background to reposition (saved).

Outbound language rules: compose is treated as **English** unless target is `en` (then source is **Japanese**).

## Commands

| Command | Action |
|---------|--------|
| `//kb` / `//kotoba` | Toggle panel |
| `//kb on` / `//kb off` / `//kb auto` | Auto-translate |
| `//kb status` | Settings + cache counts |
| `//kb t <text>` | Translate to selected language |
| `//kb te <text>` | Translate JA → EN |
| `//kb send <channel> <text>` | Translate and send |
| `//kb compose <text>` | Set compose buffer |
| `//kb channel <name>` / `//kb cyclechannel` | Send channel |
| `//kb lang <code>` / `//kb cyclelang` | Target language |
| `//kb tell <name>` | Tell target |
| `//kb clear` | Clear in-memory cache |
| `//kb debug` / `//kb help` | Debug / help |

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
