# Windower UI research (Kotoba)

Goal: Ashita-like compose / tell text fields on **Windower 4**.

## Hard limits (W4)

| Approach | Reality |
|----------|---------|
| ImGui / Ashita primitives | Not available on Windower 4 |
| `require('core.ui')` + `ui.edit` | **Windower 5 only** ([packages wiki/ui](https://github.com/Windower/packages/wiki/ui)) |
| `texts` library | Display + mouse hover/click/drag only — **no keyboard focus** |
| `windower.chat.get_input()` | Returns `(text, cursor)`. Mirroring it into the panel raced Enter/send and produced the “only last letter” tell bug |
| `keyboard` + `return true` | Blocks keys **only while chat is open** ([Issues#788](https://github.com/Windower/Issues/issues/788)) |

## What other addons actually do

| Source | What we can leverage |
|--------|----------------------|
| [ruptchat](https://github.com/) (local ref) | `texts` panel + click maps + drag — Kotoba already uses this layout pattern |
| [Windower BluGuide `ui/buttons.lua`](https://github.com/Windower/Lua/blob/dev/addons/bluguide/ui/buttons.lua) | Clickable `texts` buttons with hover — same hit-test idea as our `ui/mouse.lua` |
| [Jyouya/GUI-lib](https://github.com/Jyouya/GUI-lib) | W4 widgets: Combobox, FunctionButton, Slider, **PassiveText** — nicer chrome, still **no caret textbox** |
| [XIVCrossbar `env_chooser`](https://github.com/AliekberFFXI/xivcrossbar) | **DIK → string buffer + `return true`** while capturing — this is the real text-input pattern on W4 |
| [Yush](https://github.com/mverteuil/windower4-addons/blob/master/Yush/Yush.lua) | Full DIK keymap table — useful reference for key→char |

## Chosen path (shipped in `ui/input.lua`)

1. Click Compose / Tell → open chat (so blocking works) + clear chat input
2. Capture DIK into Kotoba’s buffer; `return true` so letters never hit game chat
3. Draw buffer on the panel with a `_` caret
4. Enter confirms · Esc cancels
5. `input.tick()` re-opens chat if it closes mid-edit (otherwise WASD still moves you)

That is as close as W4 gets to Ashita `InputText` without waiting for Windower 5.

## Sending Japanese (mojibake fix)

LLM output is UTF-8. FFXI chat expects Shift-JIS. Always run translations through
`windower.to_shift_jis` before `windower.chat.input` / `input /tell …`. Without that,
tells look like garbled CJK — the model was fine; the wire encoding was wrong.

## Future upgrades (optional)

- Vendor GUI-lib for prettier buttons/combos (language / channel) while keeping our keyboard buffer for text
- Windower 5 port: swap panel to `core.ui` + `ui.edit` when the user base moves
- IME / non-US keyboard layouts: extend `KEYMAP` or hook `windower.chat.get_input` only as a paste fallback
