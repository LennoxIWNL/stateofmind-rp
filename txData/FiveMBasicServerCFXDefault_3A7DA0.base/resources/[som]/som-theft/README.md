# som-theft

Server-validated cash robbery.

## Why this exists

Cash is **not** an inventory item in SOM. som-core owns every balance outright, because making cash an item hands the authoritative count to ox_inventory and splits ownership of the economy across two systems.

That would normally make cash unstealable, which is bad roleplay. This resource restores robbery as a deliberate action: a thief searches an incapacitated victim, and the server moves the money.

## How it works

1. `som-interact` puts a **Steal Cash** option on players.
2. A progress bar runs with a search animation. Cancelling aborts.
3. The client sends **one** value to the server: the target's server id.
4. The server validates everything and moves the money through som-core's transaction bus.

## What the server checks

Everything, because the client is not trusted with any of it:

| Check | Why |
|---|---|
| Both players are loaded | |
| Target is not the thief | |
| Distance ≤ `Config.MaxDistance` | A client can fire this from anywhere on the map |
| Victim is in a permitted state | Stops pickpocketing anyone walking down the street |
| Victim is not an on-duty exempt job | Officers cannot be robbed of seized cash |
| Cooldown per victim | Stops a downed player being farmed |

The client-side `canInteract` filter only keeps the menu tidy. Hiding or showing the entry grants nothing.

An empty victim still sets the cooldown, otherwise a thief could probe repeatedly to discover the moment they next receive cash.

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `Config.MaxDistance` | `2.0` | Enforced server side |
| `Config.SearchDuration` | `5000` | Progress bar length |
| `Config.CooldownMs` | `30000` | Per victim |
| `Config.RequiredVictimState` | cuffed, isdead, inlaststand, handsup | Any one permits robbery |
| `Config.StealFraction` | `1.0` | Portion of cash taken |
| `Config.ExemptJobs` | police, ambulance | On duty only |

`cuffed` and `handsup` are som-core metadata keys, so restraint is framework state rather than something a job script keeps privately. Phase 5 sets them when police cuff someone.

## Ledger

Both legs are written: the victim gets a `robbed` debit, the thief a `robbery-proceeds` credit, each recording the other as counterparty. Flow is `transfer`, so a robbery moves money without registering as a faucet or a sink in the Phase 4 economy figures.

## Known gaps

- `handsup` is not yet set by anything. Phase 5 wires it to the surrender animation.
- No dispatch alert on a successful robbery. Phase 5 adds it when police exist.
- Not verified against a live server.
