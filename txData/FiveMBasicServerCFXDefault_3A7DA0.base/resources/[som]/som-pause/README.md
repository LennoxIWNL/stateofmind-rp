# som-pause

A slim branded bar over the paused world. Not a pause menu.

## What this is, and what it used to be

A full custom pause menu was built first and thrown away. It was a lot of chrome
around things the game already does better, and replacing the native menu cost
click-to-waypoint for nothing in return. It also left the minimap expanded and
repositioned with no restore, which put a large translucent map permanently on
the HUD.

What survived is the part worth keeping: Escape blurs the world, tints it pink,
and shows one bar with the logo, who you are, and three actions. Map and
Settings hand straight back to the native frontend.

**This resource never touches the minimap.** That is the fix, not an oversight.

## Why the native menu is suppressed at all

The beige wash behind the pause menu is drawn by the native frontend and no
native recolours it. Suppressing the menu is the only way to get a different
overlay colour, so the client closes it the frame it opens, calls
`TriggerScreenblurFadeIn` itself, and puts the tint in CSS:

```lua
Config.Overlay.tint = 'rgba(255, 20, 147, 0.13)'
```

## Handing off to the native frontend

```lua
ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_MP_PAUSE'), false, frontend)
```

`frontend` is `-1` for the map and `6` for settings, set per action in
`Config.Actions`.

The suppression loop closes any pause menu it sees, so it would instantly close
the map it was just asked to open. `handedOff` guards that: suppression pauses
from the hand-off until `IsPauseMenuActive()` goes false again.

Because the native map is back, **waypoints work by clicking the map** as
normal. The destination list the previous version needed is gone.

## Branding

The logo is `som-assets/img/som-logo.png`, referenced as
`https://cfx-nui-som-assets/img/som-logo.png`. If it fails to load the bar falls
back to a `SOM` wordmark, since a broken image icon looks worse than the text it
replaced.

## Disconnecting

Routes through the server so som-core's save-on-drop path runs exactly as it
would for any other disconnect.

## Known gaps

- No settings of our own. Settings opens the native page. A SOM settings UI
  arrives with the HUD and keybind work rather than shipping empty.
- The bar shows job and duty but has no interactions; anything actionable
  belongs on the radial or the phone.
- Not verified against a live server.
