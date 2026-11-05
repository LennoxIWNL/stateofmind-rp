---
name: som-patterns
description: House patterns used across the som-* resources (claims, money flows, ships-disabled config, capped buyers, ledger items, phone apps). Load before building a feature.
---

# SOM patterns

- **Ships disabled.** Every place (zone, spot, lab, shop, drop-off, buyer, supplier, site) has `enabled = false` and `coords = nil`. Server code checks `enabled and coords` (see `usable()` in `som-turf/server/main.lua`). Each such item gets a line in `LAUNCH-TODO.md`.
- **Claims.** One atomic conditional UPDATE or `INSERT ... SELECT ... WHERE NOT EXISTS` is the lock and the cooldown (`som-heists` `claimSite`, `som-outdoors/server/chop.lua`, `som-turf/server/lab.lua`). Do the claim before the side effect, and undo it if the side effect fails.
- **Money flows.** Player to business: `core:removeMoney` then `businessTransact`. Treasury to player (capped, e.g. `som-outdoors/server/buyer.lua`, `som-heists` `payClean`): `core:treasuryTransact(-n)` then `core:addMoney`, refund the treasury if the credit fails, one lock against concurrent cap reads. Player to treasury (sink): `core:removeMoney` then `core:taxToTreasury`. Gang account: `core:gangTransact`. Marked bills are never paid from the treasury: `exports['som-launder']:mintBills(src, { worth }, tag)`.
- **Timestamps.** Stage, ready time and cooldowns come from SQL `NOW()` (see plants in `som-turf/server/grow.lua`, cooks in `lab.lua`).
- **Progress bars are cosmetic.** Server records a start time and rejects a finish that comes sooner than the minimum (`som-turf` tagging, `som-outdoors` chop).
- **Ledger items.** An item that grants power points at a database row (`som-heists` dongles, `som-launder` marked bills); the row decides if it still works, so copies do nothing.
- **Phone apps.** Register with `exports['som-phone']:registerApp({ id, label, icon, colour, order, reads = { view = true }, handler })`; the handler returns `{ success, error, view }` (see `som-groups`, `som-turf/server/gang.lua`, `app.lua`). Boss/rank checks use the live database grade, not a cached one.
- **Dispatch.** Add an alert type in `som-dispatch/shared/config.lua` (not `reportable`), raise it with `exports['som-dispatch']:alert(src, type, { coords, message })`. There is deliberately no wanted level.
- **Providers.** Group jobs register with `som-jobboard` and take groups from `som-groups`; see `som-courier` and `som-heists`.
- **Items.** See the `som-items` skill. **Tests.** See `som-testing`. **Shipping.** See `som-release`.
