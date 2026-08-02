# som-chat

A command line. **Not a chat.**

## Why it exists

The stock cfx `chat` resource is absent from this server, so no typed command
was reachable at all, including staff commands. This restores that and nothing
more.

## What it deliberately is not

There is **no message log**, and nothing is drawn unless the player is actively
typing. Non-command input is rejected.

Players communicate through voice, the phone, and interactions. A visible text
chat competes with all three and pulls roleplay out of the world and into a text
box, which is the opposite of what this server is for.

## Behaviour

| | |
|---|---|
| **T** | Open. Rebindable in FiveM settings. |
| **Enter** | Run and close |
| **Escape** | Cancel |
| **Up / Down** | Previous commands, terminal style |

Input not starting with `/` is refused with a one-line hint. `Config.CommandsOnly = false`
would allow plain text, but that is a design reversal rather than a setting.

## Script output

Everything goes to **som-ui notifications**, so there is exactly one place
feedback appears.

`chat:addMessage` is implemented for compatibility: preserved third-party
resources posting through the stock API are routed to a notification instead of
vanishing, with colour and formatting codes stripped since a notification
renders them literally.

```lua
exports['som-chat']:post(source, 'Message', 'success')   -- or -1 for everyone
```

## Nothing crosses the network

The client sends no text to the server. Input either resolves to a command,
which FiveM routes itself, or is rejected locally.

That removes an entire class of problem: there is no player-authored text to
rate limit, filter, attribute, or moderate, and no chat spam vector.

## Known gaps

- No command autocomplete or suggestions.
- `/me` and `/do` do not exist yet. When they do they belong here, since they
  are the one kind of typed input with no physical anchor.
- Not verified against a live server.
