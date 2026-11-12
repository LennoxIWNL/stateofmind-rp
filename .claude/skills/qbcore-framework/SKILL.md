---
name: qbcore-framework
description: Only for the preserved third party resources that expect qb-core (ps-mdt, r14-evidence) via som-compat. Not for our own code.
---

# QBCore (compat only)

SOM is not QBCore. `qbx_core` was removed. `[som]/som-compat` impersonates `qb-core` so a few preserved third party resources (ps-mdt, r14-evidence) run unmodified. Do not write new gameplay against QBCore APIs, do not edit those resources' logic (config only), and implement missing `QBCore.*` members in `som-compat` rather than in the resource. Our own code uses `exports['som-core']` (`getPlayer`, `getPlayerByCitizenId`, `getPlayersByJob`, `getPlayersByGang`, `addMoney`, `removeMoney`, `businessTransact`, `gangTransact`, `treasuryTransact`, `taxToTreasury`, `setGang`, `hasPermission`). Check an export exists in `[som]/som-core/server/*.lua` (`exports('name'`) before calling it.
