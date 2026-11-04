# som-heists

The heist framework. Each tier (store, small bank, city vault) is a provider on `som-jobboard`, so a
crew is a `som-groups` group and the job arrives through the lottery. Everything that decides an
outcome is on the server; the client shows an objective, a blip and an interaction zone.

## A run

1. **Dongle.** The leader needs a Trojan USB (`trojan_usb`) that the ledger (`som_heist_dongles`)
   still calls issued. The item only points at a row: a crafted, forged or duplicated copy has no
   issued row and does nothing. Accepting the job spends the row first (a conditional `UPDATE`), then
   removes the item, so a duplicate cannot start two runs. Issue one with `/givedongle <id>` (admin)
   or `exports['som-heists']:mintDongle(source, tag)` from a future source (a fence, a drug deal).
2. **Site claim.** One conditional `INSERT` into `som_heist_runs` claims a free, enabled site that is
   off its cooldown. If no site can be claimed the dongle is not spent.
3. **Police gate.** `policeMin` on duty (1, 3, 5 for store, bank, vault) or the job is not offered.
4. **Hack.** At the terminal the server runs `som-hack` (a puzzle whose answer the server holds) and
   reads its own record of the result. The alarm goes to `som-dispatch` (`heistInProgress`, at the
   site's coordinates) on the first attempt. Two failures lock the crew out and end the run.
5. **Doors.** A success opens the site's `ox_doorlock` doors by name.
6. **Loot.** Each loot point is claimed once, in order, by whoever stands at it. The run ends when the
   last one is taken, or after `Config.minutes`.

## Money

- **Clean cash comes from the treasury**, capped per rolling hour per tier (`hourlyCleanCap`), so the
  city cannot be drained. Debit first, credit second, refund if the credit fails. An empty treasury
  pays nothing and creates nothing.
- **Marked bills do not come from the treasury.** They are minted through `som-launder`'s ledger and
  only become spendable by washing them at a front, where the cut is destroyed.

## It ships disabled

Every site in `Config.sites` has `enabled = false` and no coordinates. A site is usable only when
enabled with a terminal and loot points. No heist can start until real locations are set and each is
tested; the list is in `LAUNCH-TODO.md`.

## Prior art

qb-bankrobbery, sd-heists style scripts, peak-phone's job contracts and the NoPixel heist ladder
were read for shape (tiers gated by police, an item to start, a hack, doors, a cooldown). All are
GPL, unclear or closed, so no code was taken. The usual flaws (client reported hacks, a client
asking for its own payout, cooldowns held in memory) are each a test here. Not copied: intel rows
and per-heist custom stages; this is the common spine only.

## Not verified

Nothing here has run in a game: the zone, blip, progress bar, `ox_doorlock` opening from a server
export (its `setDoorState` reads the event `source`, which is nil from a plain export call), the
alarm blip, or a real crew with a real puzzle.
