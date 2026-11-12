---
name: fivem-security
description: Mandatory server-authority checklist for every handler, command and callback in this repo. Always load.
---

# Security checklist (CLAUDE.md hard rules)

For every `RegisterNetEvent`, `lib.callback.register` and command:
1. Re-derive the player from `source` (`core:getPlayer`), never from an argument.
2. Validate every argument: type, range, integer-ness, existence in server config. Reject on anything unexpected.
3. The client sends ids, never prices, amounts, results or coordinates it wants honoured. Read positions from the server ped; check distance for any location-bound action.
4. Permission and job checks happen on the server (`core:hasPermission`, `player.job`, `player.gang`), never from a client flag.
5. Money: debit first, credit second, refund on failure; never `addMoney` without a matching debit (player bank, business account, gang account, or treasury). Clean cash from the treasury is capped per hour and starts at 0; marked bills come from `exports['som-launder']:mintBills`.
6. Claim before paying: one atomic conditional `UPDATE`/`INSERT`, check affected rows or insertId (see `oxmysql` skill).
7. Items: remove inputs all-or-nothing and give them back if a later step fails; add outputs and undo if the add fails.
8. Rate limit or cooldown anything repeatable; enforce minimum durations on the server for progress bars (the client bar is cosmetic).
9. Secrets and webhooks come from `GetConvar`, never committed. Admin commands need ACE (`som.admin`, `som.mod`).
10. After writing a server file run `mcp__fivem-kit__fivemAudit` with `filePath`. Known false positives: commands that gate inside the handler, and `/report` (intentionally player facing).
No wanted level, heat or reputation score, ever.
