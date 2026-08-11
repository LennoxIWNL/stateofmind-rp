# Dealership research

Written 2026-08-11, before any code. Nothing has been built.

Read in full: `qbcore-framework/qb-vehicleshop` (2,568 lines) and
`Qbox-project/qbx_vehicleshop` (2,269 lines, the maintained rewrite). Also the
seven ready-made integration files the lore-friendly pack ships under
`Dealerships/`, which name the scripts the wider ecosystem targets: JG, okok,
Quasar, IC3D, vMenu, ESX and QBCore.

## Where we start from, which is not nothing

**There is still no dealership in the tree.** But `som-garage/server/fleet.lua`
already contains a correct vehicle purchase flow, written for the PD motor
pool, and it is the right seed:

- the client sends a **model name and nothing else**, never a price;
- the server re-resolves the entry from config, and refuses if it has no price;
- distance is checked server side against the garage coords;
- certification is checked where the entry demands one;
- an ownership cap stops one officer buying the whole fleet;
- `core:payWith` moves the money with a ledger reason;
- **a failed row write refunds in full**;
- the selling business is credited, so a sale MOVES money rather than minting it.

A dealership is that flow with a catalogue, a showroom and a sales floor on top.

## Feature set, from the two scripts

| Feature | qb-vehicleshop | qbx_vehicleshop |
|---|---|---|
| Free-use shops (buy from NPC) | yes | yes |
| **Managed shops** (a real player must sell you the car) | yes, `Type = 'managed'`, job gated | yes |
| Showroom vehicles physically spawned at coords | yes, swappable per pedestal | yes |
| Test drive, time limited, car deleted after | yes | yes, plus employee-initiated test drive for a customer |
| Financing: down payment, term, repossession | yes | yes, cleaner |
| **Finance clock runs on PLAYTIME, not real time** | yes | yes |
| Transfer / sell to another player | `/transfervehicle` | yes |
| Block transferring a financed car | `Config.PreventFinanceSelling` | yes |
| Categories, per-model overrides, blocklist | partial | yes, three-tier fallback |
| Zones | hand-typed PolyZone vertices | same |

## What I liked

- **The finance clock counting playtime rather than wall clock.** A player who
  does not log in for a week does not come back to a repossession. It is the
  fairest version of the mechanic and it costs nothing to copy.
- **Managed shops.** A dealership where a real player has to hand you the car is
  the version worth having here, and it matches where this server is already
  going: AUDIT 10.1 wants commands to become physical interactions, and
  `som-gangboss-app` already forces hiring to happen face to face with
  `MaxHireDistance`.
- **Showroom cars as real vehicles on pedestals**, swappable. Diegetic in
  exactly the way AUDIT 20.4 asks for: the stock IS the showroom, not a list.
- **qbx's three-tier category fallback** (model, then category, then default).
  Small thing, but it means adding a car needs no config edit in the common
  case.
- qbx is the better codebase of the two: typed, split into modules, no nine
  locale files.

## What I did not like, and will not copy

- **`qbx_vehicleshop:server:swapVehicle` takes client data and rebroadcasts it
  to every client with no validation at all** (`TriggerClientEvent(..., -1,
  data)`). Any client can push an arbitrary showroom swap to the whole server.
  That is our hard rule 2, straightforwardly broken. Showroom state has to be
  server-owned.
- **Financing lives in columns on the vehicle row** (`balance`, `financetime`,
  `paymentamount`). That is the same mistake AUDIT 8.5 records against
  `som-banking`, where transactions were a blob in a column and could not be
  queried, audited or reconciled. **We already have the better machinery:**
  `som_transactions` is a real ledger, and `som_phone_bills` already carries
  `auto_collect` and `due_at`, which is exactly a car payment.
- **Shop zones as hand-typed polygon vertices.** The pdm zone is eleven
  `vector2`s typed by hand. `som-jobsetup` exists precisely because placing
  things in game beats typing coordinates.
- **Test drive enforcement is loose.** The server sets a timeout and a state
  bag, but the deletion leans on the client. A test drive that a player can
  keep is a free car.
- Both ship a **catalogue of every vanilla vehicle**. Ours should list only what
  we actually stream, or the shop sells cars that do not load.

## What I would build

`som-dealership`, on `som-garage`'s purchase flow, with:

1. **Catalogue from config**, seeded from the pack's own `Dealerships/QBCore.lua`
   (156 cars already priced, with brand and category), **filtered to the models
   we actually stream**: vanilla plus the 20 lore-friendly cars now in
   `som-lorefriendly`. Selling a car that does not load is worse than not
   selling it.
2. **Free-use and managed shops**, the managed one job-gated, because that is
   the RP version.
3. **Showroom vehicles**, server-owned state, swap requests validated and
   re-broadcast by the server rather than relayed from a client.
4. **Financing through the ledger and a phone app**, not through columns on the
   vehicle. **Owner's direction, 2026-08-11: this is the `Properties` app in
   `som-phone`**, and it is named Properties rather than Finance because
   **Phase 7 extends it to housing**. One place a player sees everything they
   own and everything they owe. A car payment becomes a `som_phone_bills` row
   with `auto_collect`, which already works and already notifies, and missed
   payments drive repossession, so the app is also where a player sees it
   coming rather than logging in to an empty garage.
5. **Test drive with a server-side timer** and a server-side despawn, plus the
   existing distance checks. Owner confirmed test drives are wanted.
6. **A browsable catalogue.** Owner confirmed. The shop NUI from task 3 comes
   free here: the armoury grid, basket and Bank/Cash footer are the same
   screen.

Recorded in `AUDIT.md` 18.4, with the housing half in 18.7.

**Open question, still unanswered:** whether the first dealership is free-use
(buy from a terminal, works on an empty server) or managed (needs a player on
duty, better roleplay). My recommendation is both, with free-use on a limited
cheap range so a new player is never stuck, and managed for everything else.
That is a design call, not a technical one, and it does not block starting.
