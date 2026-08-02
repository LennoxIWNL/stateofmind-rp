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

## Known gaps

- No queueing: past 5 simultaneous notifications the oldest is dropped rather than deferred.
- No progress or persistent notification type yet. Phase 7 adds those alongside the HUD.
- Not verified against a live server.
