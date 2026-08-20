# som-ui

Notifications. The single implementation behind `som:client:notify`.

Replaces `som-notify` and `som-lib`, both removed in the teardown. `som-core` and `som-compat` already fire this event, so without this resource those calls go nowhere.

## Usage

From any client script:

```lua
TriggerEvent('som:client:notify', 'Vehicle impounded', 'error', 5000)
exports['som-ui']:notify('Payment received', 'success')
```

From the server, targeting one player:

```lua
TriggerClientEvent('som:client:notify', source, 'You are now on duty', 'success')
```

| Argument | Notes |
|---|---|
| `message` | Required string. Rendered with `textContent`, so player names and config text cannot inject markup. |
| `type` | `success`, `error`, `warning`, `info`. Anything else falls back to `info`. |
| `duration` | Milliseconds. Clamped to 500 to 15000, defaults to 4000. |

## Behaviour

- **Never takes NUI focus.** A notification must not steal the player's mouse.
- The stack is capped at 5; a burst drops the oldest rather than filling the screen.
- Type only recolours the left rule and icon, so notifications stay visually consistent with every other SOM surface.
- Animation is CSS, not JavaScript timers, and the progress bar duration is driven from the value the caller passed.

Styling comes from `som-assets/tokens.css`. Nothing is redefined locally.

## The ox_lib replacements

`ox_lib`'s UI is a compiled React bundle and cannot be restyled, so three of its
surfaces are replaced with SOM ones. Each is a shim file that a consumer loads
itself, first in its `client_scripts`, while the state and the drawing stay
here:

```lua
client_scripts {
    '@som-ui/client/progressbar.lua',   -- lib.progressBar, lib.progressCircle
    '@som-ui/client/context.lua',       -- lib.registerContext, showContext
    '@som-ui/client/skillcheck.lua',    -- lib.skillCheck, cancelSkillCheck
    '@som-ui/client/dialog.lua',        -- lib.inputDialog, lib.alertDialog
    'client/whatever.lua',
}
```

The shim runs in the CONSUMER because the callbacks it holds are closures over
that resource's locals and a closure cannot cross a resource boundary. The
result comes back as a broadcast plus a token, so only the resource holding the
live token acts on it. Every shim path must also appear in this resource's
`files{}`, or consumers fail to start on a missing include.

All three fall back to `ox_lib`'s own if `som-ui` is stopped, so a restart
degrades the look rather than breaking the action.

`lib.inputDialog` implements six of `ox_lib`'s eleven row types: `input`,
`number`, `textarea`, `checkbox`, `select` and `slider`. That is every type
anything in this tree asks for. **A dialog containing any other type is handed
to `ox_lib` whole**, rather than drawn with the unknown row missing, because a
form that silently drops a field returns a value the caller believes is real.

Values are coerced and clamped in the shim against the rows the CALLER passed,
not the ones the page rendered, and a `select` value is re-resolved against the
options actually offered. The page decides layout; it decides nothing about what
comes back.

**A skill check is a client side minigame and its result is a client claim**, in
`ox_lib` and here alike. It decides presentation. Nothing a server does may rest
on the player having passed one; the server re-checks the act itself.

## Known gaps

- No queueing: past 5 simultaneous notifications the oldest is dropped rather than deferred.
- `lib.alertDialog` is implemented and has **no caller anywhere in the tree**. It was built because the shim set is one surface, not three, but nothing has exercised it.
- `lib.inputDialog` does not implement `date`, `date-range`, `time`, `color` or `multi-select`. Those calls fall through to `ox_lib` intact.
- `lib.registerMenu` (the keyboard-driven list menu) is still `ox_lib`'s. Its only caller in the tree is `popcornrp-customs`, which is not ensured. If that resource is ever started it will look like ox_lib.
- No progress or persistent notification type yet. Phase 7 adds those alongside the HUD.
- Not verified against a live server.
