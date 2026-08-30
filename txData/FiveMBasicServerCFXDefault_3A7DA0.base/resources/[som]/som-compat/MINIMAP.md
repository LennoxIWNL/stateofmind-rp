# karma-minimap, and who owns the radar

`karma-minimap` lives in `[assets-streams]`, which is gitignored in full, so an
edit to it never reaches the VPS by `git pull` and is lost outright on a fresh
install of the pack. The fixed file is committed here beside this note, exactly
as `som-police` keeps its copy of the police handling.meta.

## What was wrong

The minimap zoomed in and out several times a second, and changing the map
shape in the ps-hud settings made no difference.

Two resources were calling `SetRadarZoom` with different values, on different
intervals:

| Resource | Call | Interval |
|---|---|---|
| karma-minimap | `SetRadarZoom(1200)` | every 80ms |
| ps-hud, "Minimap update" thread | `SetRadarZoom(1000)` | every 500ms |

ps-hud pulled the zoom to 1000 twice a second and karma-minimap dragged it back
to 1200 within 80ms, so the map pulsed between the two levels continuously. The
shape toggle is a separate code path in ps-hud, around `SetMinimapClipType`, and
was never going to affect this.

This is the same failure AUDIT records against `DisplayRadar`, and the same one
som.cfg warns about where it says two HUDs must not both run: **if another
resource can change a thing, do not also drive it yourself.**

## The fix

karma-minimap's `SetRadarZoom` thread is removed. ps-hud is the sole owner of
radar zoom, at 1000. karma-minimap keeps what it is actually for: the
`SetMapZoomDataLevel` presets, its streamed map tiles, and the Cayo block.

ps-hud is `ps-*`, which CLAUDE.md marks third-party and config-edits-only, and
it exposes no zoom setting, so the fix belongs on this side. To change the zoom
level now, edit ps-hud's "Minimap update" thread. One number, one place.

## Deploying it

    cd txData/FiveMBasicServerCFXDefault_3A7DA0.base/resources
    cp "[som]/som-compat/karma-minimap.client.lua" \
       "[assets-streams]/[graphics]/karma-minimap/client.lua"

Re-do it after any fresh install of karma-minimap.

## Still open: a second collision

Both resources stream a file named `minimap.gfx`:

- `karma-minimap/stream/gfx/minimap.gfx`
- `ps-hud/stream/minimap.gfx`

Two resources streaming the same asset name resolve by load order, which is not
something to rely on. This has not caused a visible problem yet, most likely
because `ps-hud/stream/` is itself gitignored and may not be on the VPS at all.
It becomes a real question the moment that folder is hand-copied across: decide
then which minimap artwork should win, and stop the other from streaming it.
