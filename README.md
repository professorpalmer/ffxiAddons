This is some stuff I've cobbled together as I've been requested / developed a need for it.

A handful of these addons (AutoCor, J-roller, Checker, etc) are already existing addons that I've made modifications to for personal use/fixes/improvements.
Make sure to check them out to see the differences!

I try to include my name in the author section so that if you have issues you can reach out to me directly to help troubleshoot.
Please, don't bother any other authors as I always keep their names for legacy purposes!

Thanks for all the great code that exists out there I've benefitted from.

For my more "experimental" addons / private requests, please contact me on discord at "palmer."

## Kotoba (JP chat translator)

LLM + glossary translation for FFXI. Clone this repo, then copy **one** tree into your client:

| Client | Path in this repo | Install into |
|--------|-------------------|--------------|
| **Ashita** | `Ashita/addons/kotoba/` | `<Ashita>\addons\kotoba\` |
| **Windower 4** | `Windower/addons/kotoba/` | `<Windower>\addons\kotoba\` |

Then run `install.bat` in that folder, set `LLM_API_KEY` in `translator_config.txt`, and load the addon (`/addon load kotoba` or `//lua load kotoba`). See each folder's README for details.
