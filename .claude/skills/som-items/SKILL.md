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

## Generating a missing icon (realistic house style)
1. Generate with Higgsfield `generate_image` (model `gpt_image_2_6`, 1:1, about 0.25 credits): "Photorealistic product photo of <object>, single object, centred, three-quarter angle, soft studio lighting, no shadow, plain white seamless background, game inventory icon".
2. Cut out with Higgsfield `remove_background` on the job id (the plan limits generations and cutouts per day; if refused, use the local fallback below).
3. `node tools/icon-process.mjs in.png out.png 100` crops, pads and scales to a 100px transparent PNG. Cutouts that already have alpha are only cropped. For plain white backdrops of dark objects pass `dark` as a fourth argument. White or translucent objects need the service cutout (a local flood fill cannot tell them from the shadow).
4. Review on a contact sheet (`node tools/icon-sheets.mjs <dir>`), show the owner, and only then copy into `web/images`.
