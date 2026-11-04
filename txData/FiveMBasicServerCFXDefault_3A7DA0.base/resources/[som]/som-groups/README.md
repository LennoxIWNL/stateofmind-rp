# som-groups

A leader, invited members and a ready state. Shown as the **Groups** app on `som-phone`, which
renders it from a view description (plain data), so this resource has no UI of its own.

Groups are held in memory on purpose: a group is session state, so a restart disbands them and
nothing in the database can disagree with who is actually online. Leaving the game leaves the group.

## Rules

- One group per character, at most `Config.maxSize` (6) members.
- Invite by phone number, leader only. The target must be online and not in a group. An invite
  lasts `Config.inviteSeconds` and is held per person, so a newer one replaces an older one.
- If the leader leaves, the member who joined first becomes leader.
- Member ids in the app are a counter, never a citizen id, so a client cannot learn or guess one.
- A group marked busy by a job cannot invite or change ready states.

## For job resources

```lua
local group = exports['som-groups']:getGroup(source)
-- nil, or { id, leader = source, allReady, busy, members = { { source, citizenid, name, ready } } }

exports['som-groups']:setBusy(group.id, 'Delivery run')  -- blocks invites and ready changes
exports['som-groups']:setBusy(group.id, nil)             -- clears it and resets everyone to not ready
```

`som-groups:server:changed` (group id) fires on every change.

## Prior art

slrn_groups and sd-phone's Groups app (read for what players expect: a leader, a size cap, a
ready flag). Both are GPL-3.0, so only the ideas were used. Unlike slrn_groups, no export trusts a
client for membership; everything is derived from the loaded player.

## Not verified

Nothing here has run in a game. See `LAUNCH-TODO.md`.
