# som-multichar

Character selection, creation, and spawn. Replaces `qb-multicharacter`, which was removed with the QBox layer.

**Without this resource a player cannot enter the world at all**, so it is a hard requirement for a bootable server.

## Flow

1. `playerSpawned` fires. If `som-core:isPlayerLoaded()` is false, selection opens.
2. Screen fades out, the player is moved into a private routing bucket, hidden, and frozen at `Config.HiddenCoords`.
3. A scripted camera is placed at `Config.CamCoords` looking at the preview ped position.
4. `som:server:getCharacters` returns the slots for this license.
5. The player picks or creates. Every action relays to som-core, which validates it.
6. On success som-core fires `som:client:playerLoaded`, this resource spawns the ped, waits for collision, restores the routing bucket, and fades in.

## Security

This resource decides nothing. `som-core/server/characters.lua` owns all validation:

- The license is re-derived from `source`, never sent by the client, so a player cannot select or delete somebody else's character by passing an arbitrary citizenid.
- Names are length and charset checked, dates of birth are range checked, the slot must be free and within `maxSlots`.
- The client-side checks in `app.js` exist for fast feedback only and are duplicated server side.
- All player-supplied text renders through `textContent`, never `innerHTML`.

## Routing buckets

Each player selecting a character sits in bucket `100000 + source`. Without this, every player in selection stands invisible in the same interior and their preview peds collide.

The bucket is released two ways: the client asks once spawned, and `som:server:playerLoaded` releases it server side regardless. `onResourceStart` also sweeps anyone stranded above the offset after a restart.

Set `Config.UseRoutingBuckets = false` to disable, for example if a later phase wants a shared lobby.

## Configuration

| Key | Purpose |
|---|---|
| `Config.Interior` | Preview scene centre |
| `Config.CamCoords` | Scripted camera position and heading |
| `Config.PedCoords` | Where the preview ped stands |
| `Config.HiddenCoords` | Where the real player ped is parked while hidden |
| `Config.DefaultSpawn` | Fallback when a character has no stored position |
| `Config.PedModels` | Freemode model per gender |
| `Config.Nationalities` | Dropdown options |

The scene coordinates are the long-standing qb-multicharacter defaults, kept because they are a known-good enclosed interior. Phase 7 can replace the scene by editing these five values only.

## Known gaps

- **No appearance customisation.** `qb-clothing` was removed in the teardown and Phase 7 owns the replacement, so characters render as the default freemode ped for their gender. Creation collects gender but no facial features.
- The preview ped does not reflect a saved appearance, because none is stored yet. `som_characters.appearance` exists in the schema for when it is.
- Not verified against a live server: no Lua toolchain or database was available when this was written.
