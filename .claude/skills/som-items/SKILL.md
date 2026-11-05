---
name: som-items
description: Adding an ox_inventory item with an icon in this repo. Load before touching ox_inventory/data/items.lua.
---

# Adding an item

1. Add the entry to `txData/*/resources/[standalone]/ox_inventory/data/items.lua` (tab indented): `['name'] = { label, weight, description }`. Reuse existing names where one exists (check `grep "\['name'\]"`).
2. The icon must be `web/images/<name>.png` (the name is used verbatim, lowercase for items), or set `client = { image = 'other.png' }` to an existing file.
3. Find art in the community pack `aifazi/items-images` (list with `gh api 'repos/aifazi/items-images/git/trees/HEAD?recursive=1' --jq '.tree[].path'`, download from `raw.githubusercontent.com/aifazi/items-images/main/<path>`), save as 100px PNG named for the item, and record the source path in `ICON-AUDIT.md`. No paid art. The pack has no licence file; treat provenance as community shared.
4. `python3 tools/check-item-icons.py` must pass (it allows only the baseline of known gaps in `tools/item-icons-baseline.txt`).
5. Restart `ox_inventory` on the headless server, then `ensure` the resources that were stopped with it (`som-turf`, `som-launder`, `som-mechanic`, `som-outdoors`).
6. Anything that gives items out (shops, drops) should be listed in `LAUNCH-TODO.md` if the world has no source yet.
