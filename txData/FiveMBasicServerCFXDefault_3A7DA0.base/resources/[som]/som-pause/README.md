# som-pause

Replaces the GTA pause menu. Opens on the map, per `AUDIT.md` 14.11.

## Why the native menu is replaced rather than skinned

The beige wash behind the pause menu is drawn by the native frontend. There is
no native that recolours it, so the only way to get a pink overlay is to stop
the native menu rendering at all.

`client/main.lua` closes it the frame it opens, calls `TriggerScreenblurFadeIn`
itself for the world blur, and puts the tint in CSS. Change it in one place:

```lua
Config.Overlay.tint = 'rgba(255, 20, 147, 0.13)'
```

## The map

The map tab is **the real game map**, not an image. `SetBigmapActive` expands
the radar and the NUI leaves a hole for it, so blips, the player marker and the
streamed map textures are all live and nothing has to be kept in sync.

The coloured map with no street names comes from `karma-minimap` in
`[assets-streams]/[graphics]`, which replaces `minimap_main_map.gfx` and the
minimap tiles. It was already in the repo but unensured, which is why the
vanilla map was showing. Street and area names are HUD components rather than
part of the texture, so they are hidden separately via
`Config.Map.hideStreetNames`.

### Lining the frame up

`Config.Map` positions the expanded radar; the NUI reads the same four numbers
to draw its frame. If the frame and the map disagree, edit the config and
restart the resource:

```lua
Config.Map = { posX = 0.150, posY = 0.075, sizeX = 0.820, sizeY = 0.780 }
```

Aspect ratios vary and no native reports where the expanded radar actually
landed, so these are config rather than computed. Set `reposition = false` to
leave the radar wherever the game puts it.

## Waypoints

**Click-to-waypoint is gone, and cannot be recreated.** NUI holds the cursor
while the menu is open so the game never sees the click, and there is no native
that converts a screen point on the expanded radar back to world coordinates.

`Config.Waypoints` is the replacement: a searchable destination list that calls
`SetNewWaypoint`. For the places people actually pick it is faster than hunting
across a map, but it only covers what is in the list, so extend it as the map
fills out.

The NUI never holds coordinates. It sends an index and the client resolves it
against config, so the list is the only thing that can be waypointed.

## Tabs

| Tab | Contents |
|---|---|
| Map | Expanded radar plus the destination list |
| Character | Identity, cash and bank, employment, licences |
| Server | Player count, Discord, tagline |
| Staff | Permission tier. Gated on `som.mod` |
| Disconnect | Confirmation, then a server-side `DropPlayer` |

The staff tab is filtered **server side** in `tabsFor`. Sending it and hiding
it in CSS would let the client decide what it is allowed to see.

Disconnecting routes through the server so som-core's save-on-drop path runs
exactly as it would for any other disconnect.

## Known gaps

- **No settings tab.** There is nothing to put in one yet. It arrives with the
  HUD and keybind work rather than shipping as an empty panel.
- Staff tab shows the permission tier and nothing else until `som-admin`
  (roadmapped, 14.8) brings inventory search, disconnect logs and spectating.
- The destination list is static config, not discovered from live blips.
- Not verified against a live server.
