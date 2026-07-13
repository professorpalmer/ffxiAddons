# Kotoba for Ashita (v2.0.1)

**Japanese → English auto-translate for FFXI**, plus outbound compose with a language picker (ja / en / es / fr / de / ko / zh). LLM backend (DeepSeek / OpenAI-compatible / OpenRouter / Ollama) + SQLite cache + FFXI glossary.

Windower users: see `Windower/addons/kotoba/` — same `translator.py` (sync with `tools/sync_kotoba_shared.ps1`).

## Setup

1. Copy this folder to `<YourAshitaInstall>\addons\kotoba\`  
   (if you cloned `ffxiAddons`, copy from `Ashita/addons/kotoba`)
2. Double-click **`install.bat`** — installs `httpx` from `requirements.txt`, creates config, builds seed DB
3. Edit **`translator_config.txt`**:
   ```
   LLM_API_KEY=your_key_here
   LLM_BASE_URL=https://api.deepseek.com/v1
   LLM_MODEL=deepseek-chat
   ```
   Never commit that file (gitignored).
4. In FFXI: `/addon load kotoba` → `/kotoba`  
   The addon checks your config, then auto-starts `pythonw translator.py` (falls back to `python`).  
   Optional visible console: `start_translator.bat`.

Seed DB is built by `install.bat` / `start_translator.bat` — not on bare first load.

### Troubleshooting

| Problem | Fix |
|---------|-----|
| No translations | Set a real `LLM_API_KEY` (not `your_api_key_here`) |
| Chat says config missing | Run `install.bat` in the kotoba folder |
| `ModuleNotFoundError: httpx` | `pip install -r requirements.txt` |
| Prefer a console | Run `start_translator.bat` (addon auto-start is the default) |

## Features

- Auto-translate **incoming Japanese → English**
- ImGui compose + language dropdown for outbound
- 500+ FFXI glossary terms (`ffxi_glossary.txt`, hot-reloads)
- SQLite durable cache (`translations.db`)
- Heartbeat auto-shutdown when you leave the game
- Suggested missing terms → `suggested_terms.log` (local only)

## Commands

- `/kotoba` or `/kb` — Toggle window
- `/kotoba help` — Help
- `/kotoba clear` — Clear in-addon message history
- `/kotoba debug` — Toggle debug mode

## How it works

```
JP chat → kotoba.lua → translation_queue.txt
                      → translator.py (+ translations.db / LLM)
                      → translation_results.txt → game chat
```

## Custom glossary

Edit `ffxi_glossary.txt` (one `jp|en` per line). Changes apply on the next translation (mtime reload).

See `GLOSSARY_GUIDE.md` and `GLOSSARY_COVERAGE.md`.

## Examples

| Japanese | Kotoba |
|----------|--------|
| ソーティやる？ | Wanna do Sortie? |
| 白魔募集中 | LFM WHM |
| おつかれ！ | gj! |

## Credits

- Architecture inspired by [Sendoria](https://github.com/trevorssf/Sendoria)
- FFXI terms: [FFXIclopedia Dictionary](https://ffxiclopedia.fandom.com/wiki/Final_Fantasy_XI_Dictionary_of_Terms_and_Slang)
- Author: Zodiarchy @ Asura
