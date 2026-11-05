# som-dispatch

Crime alerts and the call store. Answers to the `ps-dispatch` surface that
ps-mdt expects, so the MDT's dispatch page works without ps-dispatch existing.

## Why it answers to another resource's name

ps-mdt is preserved third-party code written against ps-dispatch, which is not
on this server. Its dispatch page calls `exports['ps-dispatch']:GetDispatchCalls()`
in six places and fires four events at it.

Rather than rewrite the MDT, this resource takes that name. `provide 'ps-dispatch'`
satisfies the dependency check, and the exports are published under that name
using the `__cfx_export_ps-dispatch_<name>` event, the same mechanism som-compat
uses to answer as qb-core.

**One line of ps-mdt still had to change.** It sets `isDispatchRunning` from
`GetResourceState('ps-dispatch') == 'started'`, and `provide` does not make that
report started. Without the patch the flag stays false and every waypoint, unit
attach and call response silently does nothing. Re-apply on a ps-mdt upgrade.

## The call shape is not ours

It is dictated by ps-mdt's UI. Three details are load-bearing and easy to lose:

- **Keyed by call id, not an array.** ps-mdt indexes `calls[callid]`
  (`server/main.lua:1402`), so a list breaks every waypoint.
- **`origin` is separate from `coords`.** The map marker uses `coords`;
  `SetNewWaypoint` reads `origin` (`client/main.lua:991`). Both are needed.
- **`jobs` must be present.** ps-mdt's renderer does
  `value?.jobs.includes(...)` with no optional chain on the second dereference
  (`ui/app.js:4549`), so a call without it throws in the UI rather than being
  skipped.

`time` is milliseconds, because ps-mdt compares it against `Date.now()` and
hides anything older than ten minutes. Seconds would hide every call instantly.

`dispatchCode` of `"911"` or `"311"` is what makes ps-mdt offer a response box.

## Authority

A client only ever says "this happened near me". It does not decide whether a
call is raised, where it lands, who sees it, or what it says:

- the **position** is read from the reporting player's ped server side, so a
  client claiming to have fired at the airport while standing in Paleto reports
  Paleto;
- the **chance roll** happens server side, because a client deciding whether its
  own gunshot was unlucky enough to report would always decide no;
- the **suppressor scatter** is applied server side for the same reason;
- the **recipients** come from `som-core:getPlayersByJob(job, true)`, on duty
  only.

The worst a crafted report achieves is raising an alert about itself, at its own
position, at its own cooldown.

## Detection

`CEventGunShot` is subscribed by name, matching how r14-evidence does it on this
same server, so it is known to work in this build rather than assumed. **Only
the local player's own shots report**, every nearby client receives that event,
so without the check one gunshot files one call per witness.

Melee and vehicle theft are polled, because neither has a game event worth
listening to. Explosions come off `CEventNetworkEntityDamage` filtered on damage
type 5.

## Testing

`Config.Alerts.shotsFired.chance` ships at **1.0**, so every shot registers.
That is a testing value: lower it to around 0.35 once the loop is proven, or the
map fills with markers and officers learn to ignore them.

Cooldowns are per player per alert type. Without them an automatic weapon files
one call per round.

## Not a phone notification

Dispatch is radio traffic. It goes through `som:client:notify`, not som-phone:
an officer hears a call because they are on duty, not because they happened to
have their phone out. See the routing note on som-phone's `notifyApp` export.

## Working a call

`/dispatch` opens the board. Every action is a callback the server checks again
against the caller's job, duty, grade and the call's own state.

- **Repeat reports merge.** A detected crime of the same kind within
  `Config.Merge.radius` and `window` is one call with a count. At
  `escalateAt` reports a routine call goes up one priority step and is re-sent.
- **Offset alerts.** Types with `offset` are shown at a fixed jittered point
  and a search radius. The real position stays in a server-only table and is
  what merging uses, so repeats cannot be averaged to find it.
- **Respond, assign, close.** A responder attaches to a call for their own
  service. A dispatcher (the `dispatcher` job, which hears every call) or a
  responder at `Config.SupervisorGrade` can assign a named on-duty unit. A unit
  on the call closes its own service; a dispatcher closes all of them. A call
  closes when every service has, and leaves the board after `ClosedKeep`.
- **Major incidents.** A dispatcher or supervisor declares one on a call. Every
  on-duty responder hears it, and units attached to it are spared priority 2 and
  lower traffic until it is stood down.
- **Unattended.** A call with no unit after `UnattendedAfter` is flagged on the board.
- **Report budget.** `Config.ReportBudget` caps detected reports per player per minute.

Calls live in memory, as before; a restart clears the board.

Compared before extending: Project-Sloth/ps-dispatch (merge window, unattended
flag, offset blips, supervisor-declared incidents, rate limits), pessimi-dispatch
(dispatcher panel, nearest-unit fallback when nobody is dispatching),
nb-dispatch (grade based permissions, server-owned callsigns), SolidCore MDT
(respond and clear), xs-mdt, Nexus-Dispatch, skr-dispatch and SnailyCAD (a
separate web CAD). Most are GPL, so only ideas were taken.

## Known gaps

- No phone app yet. The plan is a dispatch app that mirrors the call list.
- `r14-evidence` is not started, so its far better gunshot forensics (GSR,
  casings, impacts) are still unused. Adopting it is the next police step, and
  its `Config.Alerts` should be pointed here rather than at the dead
  `police:server:policeAlert`.
- Not run. Checked structurally only: block balance and a callback
  cross-reference. There is no Lua toolchain installed.
