# State of Mind RP: supporter tiers

Planning document. **Patreon does not exist yet and prices are placeholders.**
The mechanism is built (`som-core/shared/tiers.lua`, `server/entitlements.lua`),
the perks mostly are not, because the systems they attach to have not been built.

---

## The one rule

**Nothing purchasable may be pay to win.**

A perk is acceptable if a paying player and a non-paying player who meet in the
world are still on equal footing. It is not acceptable the moment money buys an
edge in an interaction, an economy, or a conflict.

| Acceptable | Never |
|---|---|
| Queue priority | Money, vehicles, items, weapons |
| Character slots | Inventory weight or slot increases |
| Cosmetic names, colours, plates | Stash or garage capacity |
| Phone and profile personalisation | Faster cooldowns, timers or crafting |
| Cosmetic titles and badges | Access to jobs, gangs or areas |
| Discord role and colour | Anything affecting combat, wages or drug yield |

The grey areas are worth naming rather than glossing over:

- **Character slots** are mild convenience and are treated as acceptable, in
  line with the norm across RP servers. They do not confer any advantage on a
  given character.
- **Queue priority** is the standard supporter perk and is what most tiers
  actually sell. It costs non-payers waiting time, which is the trade being
  made deliberately.
- **Custom plates** must reject duplicates and reserved formats, or they turn
  into impersonation of police and government vehicles.

---

## Tiers

Slots climb 2, 3, 5, 6, 7 and then stop. **Seven is the purchasable ceiling.**
Ten exists only for management, which is what keeps it feeling like a staff
thing rather than something to buy. The top tier therefore sells cosmetics
rather than yet another slot.

| Tier | Price | Slots | Queue | Perks |
|---|---:|---:|---:|---|
| **Citizen** | free | 2 | – | – |
| **Resident** | €5 | 3 | slight | One extra slot and a nudge up the queue. Nothing else. |
| **Insider** | €10 | 5 | low | + custom phone number |
| **Patron** | €20 | 6 | medium | + custom Twitter handle, 1 colourway, 1 custom plate |
| **Benefactor** | €30 | 7 | high | + 3 colourways, 2 plates, profile title |
| **Founder** | €40 | 7 | highest | + 6 colourways, 3 plates, phone theme |

Staff are resolved separately and a player gets the **better** of the two, so a
purchase never removes a staff entitlement and staff rank never substitutes for
supporting.

| Staff | Slots | Queue |
|---|---:|---:|
| Mod | 3 | medium |
| Admin | 7 | high |
| Management | 10 | highest |

---

## Perk ideas by system

Ordered by how easily each could actually ship. Everything below is cosmetic or
convenience by construction.

### Phone (Phase 4b)

The phone is the richest source of non-pay-to-win perks, because almost
everything on it is presentation.

| Perk | Notes |
|---|---|
| **Custom phone number** | Choose the last four digits, or a vanity number. `som_characters.phone` already exists and is auto-generated. Must enforce uniqueness. |
| **Phone theme** | Alternate colourways for the phone shell and UI, built on `som-assets/tokens.css`. |
| **Wallpaper slots** | Upload or pick from a supporter-only set. |
| **Custom ringtone** | From a curated list, not arbitrary uploads. |

### Twitter / social app (Phase 4b, not yet designed)

| Perk | Notes |
|---|---|
| **Custom handle** | Rather than an auto-generated one. Needs a reserved-word blocklist. |
| **Handle colourways** | 1 at Patron, 3 at Benefactor, 6 at Founder. Purely a text colour on posts. |
| **Profile picture** | From a curated set, or upload with moderation. |
| **Pinned post** | Cosmetic profile feature. |

Explicitly **not** a verified badge that implies staff status, and **not**
higher character limits or post rate limits, which would be a real advantage in
an argument or a business advert.

### Vehicles (Phase 5+)

| Perk | Notes |
|---|---|
| **Custom licence plates** | 1, 2 or 3 owned vehicles by tier. `som_vehicles.plate` is already unique. Must reject duplicates, and reserved formats such as police and government plates. |
| **Plate style** | Where the base game offers variants. |
| **Garage nickname** | Rename a vehicle in the garage list. |

Never: better handling, exclusive performance vehicles, free vehicles, or extra
garage capacity.

### Character and identity

| Perk | Notes |
|---|---|
| **Character slots** | The tier ladder above. |
| **Profile title** | A short cosmetic tag on the ID card or MDT profile, moderated. |
| **Extra outfit saves** | Convenience, no gameplay effect. |
| **Walk style unlocks** | Cosmetic animation variants. |

Never: extra inventory, stash, or property capacity.

### Connection

| Perk | Notes |
|---|---|
| **Queue priority** | The backbone of every tier. `connectqueue` already has a `Config.Priority` table keyed by identifier, so wiring `queuePriority` to it is small once it is re-enabled. |

Priority should be **graduated, not absolute**. Even the top tier should wait
behind a full queue of other supporters rather than skipping everyone, or the
server stops being playable for non-payers at peak.

### Out of scope on purpose

- Anything touching the economy: wages, prices, drug yield, sale values.
- Anything touching police, EMS or gang capability.
- Anything touching combat, health, armour or injury.
- Housing or business ownership, which are gameplay progression.

---

## Implementation status

| Piece | State |
|---|---|
| Tier definitions | **Built**, `som-core/shared/tiers.lua` |
| Entitlement resolution | **Built**, `som-core/server/entitlements.lua` |
| Character slots | **Built and server enforced** in `Characters.Create` |
| Queue priority | Blocked: `connectqueue` disabled in dev mode |
| Custom phone number | Blocked: no phone |
| Twitter perks | Blocked: no social app |
| Custom plates | Blocked: no vehicle ownership |
| Profile title, themes | Blocked: no phone or MDT integration |

### How a tier is granted

Through **ACE**, not by reading Patreon directly, so the same mechanism works
from a manual line today and from an automated source later without changing
anything downstream:

```
add_principal identifier.license:<license> group.founder
add_ace group.founder som.tier.founder allow
```

Neither automated route exists yet. The txAdmin Discord bot is **disabled**, and
Patreon is not set up. Grants are manual until one is wired, and the likely
order is Discord roles first (txAdmin can map them) with Patreon syncing to
Discord rather than to the server directly.

### Before taking real money

- Decide refund and chargeback handling, especially for lifetime grants.
- Decide whether tiers are recurring or one-off. The ACE model supports both,
  but recurring needs something that revokes on lapse.
- Moderation for every player-authored string: handles, plates, titles.
- A visible statement of the non-pay-to-win rule, since it is a selling point.
