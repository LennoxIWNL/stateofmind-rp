# som-multichar

Character selection, creation, and spawn. Replaces `qb-multicharacter`, which was removed with the QBox layer.

**Without this resource a player cannot enter the world at all**, so it is a hard requirement for a bootable server.

## Flow

1. `playerSpawned` fires. If `som-core:isPlayerLoaded()` is false, selection opens.
2. Screen fades out, the player is moved into a private routing bucket, hidden, and frozen at `Config.HiddenCoords`.
3. The shell interior is spawned and a scripted camera is placed inside it, aimed at the preview ped.
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
| `Config.Shell.enabled` | Use the shell scene. `false` falls back to a plain world location |
| `Config.Shell.model` | Interior shell prop, defaults to a vanilla high-end apartment |
| `Config.Shell.coords` | Where the shell is spawned, far below the map |
| `Config.Shell.pedOffset` / `pedHeading` | Character placement inside the shell |
| `Config.Shell.camOffset` / `camLookAtOffset` | Camera framing |
| `Config.Shell.orbit` | Slow drift, so the shot is not a dead frame |
| `Config.Fallback` | World scene used when the shell is off or its model fails |
| `Config.HiddenCoords` | Where the real player ped is parked while hidden |
| `Config.DefaultSpawn` | Fallback when a character has no stored position |
| `Config.PedModels` | Freemode model per gender |
| `Config.Nationalities` | Dropdown options |

## The scene

The character stands in a **shell**: a vanilla interior prop spawned in the empty space far below the map, with the ped and camera inside it. This is the standard approach for character select backdrops and it beats standing in a real world location:

- Nothing of the live world leaks into the shot. No traffic, weather, or other players.
- **It needs no streamed assets.** The shell models are base-game, so the scene works in dev mode where `[assets-streams]` is not loaded. A custom MLO would simply not exist there.
- Nothing has to be reserved on the real map.

Two details that are easy to get wrong if you edit this:

- The hidden player ped is parked **next to the shell**, not left elsewhere on the map. Streaming follows the player, so leaving it behind means the shell and preview ped never render.
- `SetUseHiDof` only applies for the frame it is called on, so the depth-of-field runs on a per-frame thread for as long as the scene is up.

**The offsets will need tuning in game.** Shell models differ in where their floor and walls sit, so nudge `pedOffset` and `camOffset` until the framing looks right. If the model fails to load, the code logs it and falls back to the world scene rather than leaving the player in an empty void.

Alternative shells worth trying: `apa_mp_h_str_int_shell_01` through `_09` for high-end apartments, or the `ex_mp_h_int_office_*` set for executive offices.

## Known gaps

- **No appearance customisation.** `qb-clothing` was removed in the teardown and Phase 7 owns the replacement, so characters render as the default freemode ped for their gender. Creation collects gender but no facial features.
- The preview ped does not reflect a saved appearance, because none is stored yet. `som_characters.appearance` exists in the schema for when it is.
- Not verified against a live server: no Lua toolchain or database was available when this was written.
