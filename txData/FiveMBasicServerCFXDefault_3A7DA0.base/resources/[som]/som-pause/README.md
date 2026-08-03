# som-pause

A pink wash over the pause menu. That is the whole resource.

## What it is now, and what it was

A full custom pause menu was built first, then cut back to a slim branded bar,
then cut again to this. Both earlier versions replaced the native menu, and both
were worse than the thing they replaced: the game already does the map,
settings, waypoints and quitting better than a reimplementation of them.

What survived is the only part that was actually wanted, which is the colour.

## Why DrawRect and not NUI

This is the important bit.

NUI renders **above** the frontend and, with focus, captures the cursor. That
made the menu underneath unclickable, which is exactly what a decorative
overlay must never do.

`DrawRect` draws into the game's 2D layer instead. The pause menu draws over the
top of it, there is no NUI page, no focus, and nothing to steal a click. The
tint sits behind the menu and in front of the world, which is where it belongs.

## Tuning

```lua
Config.Tint = { r = 255, g = 20, b = 147, a = 38 }
```

`a` is the one to change. **The native menu applies its own beige wash and there
is no native that removes it**, so this sits on top of that rather than
replacing it. Push the alpha too high and the two combine into mud rather than
reading as pink.

## Known gaps

- The beige cannot be removed, only tinted over. Removing it means suppressing
  the native menu, which is what the two discarded versions did.
- No branding. The logo lives in `som-assets/img` and is used by other
  resources; there is nowhere to put it here that would not need NUI.
