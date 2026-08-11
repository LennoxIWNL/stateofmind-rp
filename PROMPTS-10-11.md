# Session prompts for Task 10 (inventory) and Task 11 (HUD)

Paste both into one new session. They are ordered: the inventory contract work
in Prompt A produces the parity baseline the HUD in Prompt B does not depend on,
so they can also run independently if you'd rather split them.

Read `AUDIT.md` sections 19, 20 and 21 first in that session, and the plan file
`C:\Users\tweet\.claude\plans\i-m-unifying-the-visual-crispy-crescent.md`.

---

## PROMPT A: Task 10, the custom inventory

Continue State of Mind RP. Read AUDIT.md sections 20 and 21, and the plan at
`C:\Users\tweet\.claude\plans\i-m-unifying-the-visual-crispy-crescent.md`.
Do not re-derive what is written there.

Standing rules: commit AND push to main every time and verify the remote head
matches local. Commit as me only, never add a Co-Authored-By trailer or mention
Claude in a commit message. Never invent a native. No em dashes. Never show raw
ledger slugs on bank UI.

Build `som-inventory`: our own React NUI that **speaks ox_inventory's existing
NUI message contract**, with ox_inventory's `ui_page` repointed at it. This is
decided, do not re-open it. We are NOT forking ox_inventory: its Lua stays
stock and upgradeable, our code lives in `[som]`, and the revert is one line.
The same shim pattern already replaced ox_lib's progress bar and context menus,
both documented in AUDIT 16.6 item 4 and 21.4.

Use the shared component kit at `ui/packages/som-ui-kit` (Card, Button,
IconTile, StatusBadge, Meter, Modal, Drawer, ContextMenu, Input, Select,
Stepper, Tabs, plus fetchNui/useNuiEvent). Add the app under `ui/apps/som-inventory`
with `somApp({ outDir })` from `@som/ui-kit/vite`. Colour and type come only
from `som-assets/tokens.css`; a hex value in a component is a bug.

**Order of work, and do not skip step 1:**

1. Enumerate ox_inventory's NUI contract from `[standalone]/ox_inventory/web/src`
   and its client modules: every `action` it sends and every `RegisterNUICallback`
   it accepts. Write it into the resource header the way
   `som-ui/client/progressbar.lua` documents its own. Pin the ox_inventory
   version you read it from. The contract is not versioned upstream, so this
   header is the only thing that makes a future upgrade diagnosable.
2. Build the shell and grid until it is at **parity with stock**: move, split,
   stack, use, shops, stashes, trunks, glovebox. Parity before any new feature.
3. Repoint `ui_page`.
4. Only then add the new features below.

**Feature set** (layout from the Overflow reference described in the plan's
"Reference images" section, recoloured to our tokens):

- Clothing toggle: clicking a worn item removes it with a native GTA animation,
  clicking again re-equips. Chat commands (/top, /glasses) do the same. Needs
  clothing category icons, source or author them, no placeholders.
- Physics throwing: hold to charge a power bar and trajectory arc, release to
  launch along the aim direction, accurate enough for a window or fence gap.
- Drag-to-give: dragging highlights nearby eligible players, releasing over one
  transfers instantly, no confirmation dialog. Also expose Give in the context
  menu.
- Rarity tiers (Common/Rare/Epic/Legendary) assigned in item definitions. Use
  the accent family plus neutrals, NOT the reference's green/purple/orange: a
  screen with four unrelated hues has no accent.
- Secondary panel side-by-side for trunk/glovebox/stash with transfer-all.
  Opens from the LEFT while the player's own opens from the right, so the
  direction tells you whose inventory you are looking at.
- Drag-to-discard zone, lit only while dragging.
- Cursor-anchored context menu (Use, Throw, Split, Give, Drop) that closes on
  outside click and does not move the item or reset scroll.
- Category filter tabs driven by real item categories, not a fixed list.
- Panel animations: main slides in from the right, secondary from the left,
  both reverse on close.

**The one thing worth being slow about:** every action stays server-validated.
Give, throw, discard and transfer go through ox_inventory's existing server
checks, or through a NEW som-inventory server event with its own validation
where no stock path exists. The NUI never moves an item on its own authority.
Test dupes explicitly: give, throw, discard and trunk transfer each verified
against the server's item count, including disconnecting mid-drag and mid-throw.

Note `data/items.lua` keys are lowercase but `weapons.lua` keys Weapons and
Components in UPPERCASE while Ammo is lowercase, and normalisation lives in
`getItem`. Use `exports.ox_inventory:Items(name)`, never `Items()[name]`.

---

## PROMPT B: Task 11, the custom HUD

Continue State of Mind RP. Read AUDIT.md section 21.5 and the plan at
`C:\Users\tweet\.claude\plans\i-m-unifying-the-visual-crispy-crescent.md`.

Same standing rules as above: push every time and verify the remote, commit as
me only with no Claude mention, never invent a native, no em dashes.

Replace `[som]/som-hud` with a React build on the shared kit at
`ui/packages/som-ui-kit`, app under `ui/apps/som-hud`, wired to SOM's existing
player and vehicle state. Read the current `som-hud` first: it already solves
several things worth keeping, including that GTA player health runs 100 to 200
(so raw health shows a corpse at 50%), that pma-voice's range comes from
`LocalPlayer.state.proximity` as `{index, distance, mode}`, and that both loops
must send only on change or the NUI feels heavy in a way profiling will not show.

**Feature set** (layout from the HUD reference sheets described in the plan,
recoloured to tokens as a single fixed theme, no theme switcher):

- `/sethud` in-game drag, scale and toggle editor for every element. Layout
  saved per player and restored on reconnect, plus JSON export/import.
- Core stats: health, armour, hunger, thirst, oxygen, stress. Extend the
  existing five rings to cover the ones missing.
- Speedometer: digital and analog presets for land, bike and air. Auto-detect
  fuel vs electric; electric shows battery percent and PWR/CHG/ECO.
- Aviation panel auto-activating on a plane or helicopter (altitude, vertical
  speed, heading, rotation), replacing the ground display and clearing on exit.
- Seatbelt with speed-based ejection physics, warning sound and prompt,
  configured per vehicle class.
- Vehicle control panel on a key: engine, individual doors and windows, boat
  anchor, indicators. Indicator and hazard state syncs via State Bags so nearby
  players see signals in real time.
- 360 degree compass and live street plus cross-street display.
- Custom minimap textures, circular and square, sharp at 1080p through
  ultrawide, in a stream folder for easy swapping, our branding.
- Three performance modes (Ultra/Balanced/Low). Vehicle loops only run in a
  vehicle, player loops pause while driving, nothing ticks when irrelevant.
- pma-voice mic range and radio channel indicators.

**Two carried constraints:** the fuel gauge is built now and wired only when a
fuel resource exists, because none runs on this server (cdn-fuel fails at load,
ox_fuel is not installed) and a gauge stuck at one number teaches players to
ignore the HUD. And the minimap swap needs packed `.ytd` textures, which needs
OpenIV or a texture packer that is not installed, so author the artwork and
hand that one file back.

Task 13 belongs with this: source free HUD icon sets first, and author original
SVG matching the set's style for anything missing, the way som-hud's five ring
glyphs already are. No placeholders, no mismatched styles.
