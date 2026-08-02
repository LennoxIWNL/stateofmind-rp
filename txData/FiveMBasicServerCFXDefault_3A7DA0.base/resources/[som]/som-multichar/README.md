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
| `Config.Shell.camOffset` | Camera position. There is no aim point: the camera always looks at the character, at `lookHeight` up their body |
| `Config.Camera` | FOV, depth of field and orbit, applied to whichever scene is active |
| `Config.Fallback` | World scene used when the shell is off or its model fails. **This is the default.** |
| `Config.HiddenCoords` | Where the real player ped is parked while hidden |
| `Config.DefaultSpawn` | Fallback when a character has no stored position |
| `Config.PedModels` | Freemode model per gender |
| `Config.Nationalities` | Dropdown options |

## The scene

**Default: the fallback world scene, with cinematic framing.** The camera sits close to the character with a 34 degree FOV and shallow depth of field, so the city behind reduces to soft colour. That reads as a deliberate portrait rather than a player stood in a street. A slow sine-eased orbit keeps it from being a dead frame.

### About shells

A **shell** is an interior box the character stands inside, so none of the live world is visible behind them. It is the nicer look and `Config.Shell` supports it, but it is **off by default because it requires a streamed asset**.

Base-game GTA has no spawnable interior shell. The `apa_mp_h_*` models are apartment *furniture* (bathtub, table, lamp), not rooms. Every shell used by character screens and housing scripts is a downloadable asset pack.

To enable one:

1. Put a shell resource in `[assets-streams]` and make sure it starts. Note that dev mode does not ensure `[assets-streams]`, so it must be started explicitly while iterating.
2. Set `Config.Shell.model` to the shell's model name.
3. Set `Config.Shell.enabled = true`.
4. Tune `pedOffset` and `camOffset` in game. Shell models differ in where their floor sits, so the first attempt will almost certainly be misframed.

If the model fails to load, the code logs it and falls back to the world scene rather than stranding the player in an empty void.

### Two details that are easy to get wrong

- The hidden player ped is parked **next to the scene**, not left elsewhere on the map. Streaming follows the player, so leaving it behind means the shell and preview ped never render.
- `SetUseHiDof` only applies for the frame it is called on, so depth of field runs on a per-frame thread for as long as the scene is up.
- The native is `SetNuiFocus`, **not** `SetNUIFocus`. The capitalised spelling is nil and throws, leaving a UI with no cursor.

## Live scene tuning

Shell models differ in where their floor and furniture sit, so these offsets are always wrong on the first attempt and guessing them from screenshots costs a restart per try. `Config.SceneTuning.enabled` turns on an in-game tuner.

| Key | Action |
|---|---|
| **F10** | Toggle tuning |
| Arrows | Move, relative to the screen: up is away from the camera |
| **Z** / **X** | Height, up and down |
| **+** / **-** | Zoom, narrows and widens the field of view |
| **,** / **.** | Aim height on the character, lower brings more of the body into frame |
| **Q** / **E** | Rotate the character |
| **R** | Cycle target: camera ↔ character |
| **P** | Print current values to F8, ready to paste into `config.lua` |
| **F11** | Print your own coordinates. In-world only, after spawning |

Input is handled in `html/app.js` and forwarded over NUI callbacks. The character screen holds NUI focus with keep-input disabled, so the game receives no keyboard at all while it is open and neither `RegisterKeyMapping` nor raw key polling works there.

Movement is screen-relative and derived from the camera's real rotation via `GetCamRot`, not from config values, since config can describe an orientation that is not the one being rendered.

The orbit pauses while tuning, because a drifting shot makes it impossible to judge an offset.

**Set `Config.SceneTuning.enabled = false` for production.**

## Known gaps

- **No appearance customisation.** `qb-clothing` was removed in the teardown and Phase 7 owns the replacement, so characters render as the default freemode ped for their gender. Creation collects gender but no facial features.
- The preview ped does not reflect a saved appearance, because none is stored yet. `som_characters.appearance` exists in the schema for when it is.
- Not verified against a live server: no Lua toolchain or database was available when this was written.
