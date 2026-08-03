# som-radial

F1. One of the three interaction surfaces in `AUDIT.md` 14.6, alongside the
third eye and the phone.

It exists to **replace commands**, not to wrap them.

## Held, not toggled

F1 opens while held; releasing picks whatever the cursor points at. Quicker
than click-open then click-pick, and it cannot be left open by accident.
Releasing inside the dead zone (`Config.DeadZone`) picks nothing, so a flick of
the mouse is not a mis-click.

## Why it is not built on ox_lib's radial

ox_lib ships a perfectly good radial and most third-party menus are built on
it. Its NUI is a compiled 6.3MB React bundle, so restyling means patching built
CSS, which breaks on every ox_lib upgrade. F1 is a primary surface and cannot be
the one thing that does not match the rest of the server.

ox_lib's radial is still there for incidental menus other resources want.

## Contextual, never a fixed list

Two different questions, answered in two different places:

| Question | Decided by | Why |
|---|---|---|
| What are you **entitled** to see? | Server | A job entry filtered only on the client is a job entry any client can restore. |
| What makes **sense right now**? | Client | Whether you are in a vehicle changes several times a second and is not worth a round trip. |

The entitlement list is cached on login and refreshed on job or gang change, so
opening is instant rather than waiting on a callback while the key is held.

## Registering entries

```lua
exports['som-radial']:register({
    id = 'police.cuff',
    section = 'job',
    label = 'Cuff',
    icon = 'badge',
    order = 10,
    export = 'som-police.cuff',
    job = 'police',
    minGrade = 0,
    duty = true,
})
```

**There is no `event` field, deliberately.** qb-radialmenu lets config fire an
arbitrary client or server event by name, which means the client picks both the
event and its payload. Entries name a validated export instead.

Filters: `job`, `gang`, `minGrade`, `duty`, `ace`. All applied server side.

## Sections

| Section | Appears when |
|---|---|
| Vehicle | You are in one, or within 4m of one |
| Work | You hold a job |
| Crew | You are in a gang |
| Self | Always |

Vehicle entries marked `seatedOnly` need you actually sitting in it, so you can
open a boot from outside but not start an engine.

## Submenus

Doors and seats are built at open time from the vehicle you are actually at,
because a radial stops being readable past about eight slices. They act on the
vehicle the menu was **opened against**, so the menu cannot be opened at one car
and applied to another.

## No emotes

dpemotes owns them on `/e`. A wheel full of emotes is the fastest route to the
menu simulator feel this is meant to avoid.

## Rendering

Slices are SVG paths, so the hit area matches the wedge exactly. A ring of
positioned divs would give every slice a rectangular hit box overlapping its
neighbours, which is why those menus feel imprecise near the edges.

Icons are inline SVG and there are no image files. NUI has no network access,
and the palette comes from `som-assets/tokens.css` so the wheel matches the
phone and the pause bar. No `color-mix()` anywhere: FiveM's CEF predates it and
rejects the whole declaration.

## Known gaps

- Nothing registers into Work or Crew yet; som-jobs and som-gangs will.
- No keybind rebinding beyond FiveM's own settings.
- Vehicle entries do not check ownership or keys. That arrives with the vehicle
  system, and until then anyone can open any door.
- Not verified against a live server.
