# som-jobboard

The **Jobs** phone app and the lottery behind it. A ready group waits on a job type; every
`Config.drawSeconds` the board draws one waiting group per free slot and offers it the job. It does
not know what a job is: a provider resource registers itself, starts the job and says when it is over.

## How a job is given out

1. The leader of a group where everyone is ready picks a job in Jobs and waits. A member un-readying,
   or the group disbanding, takes it out of the queue.
2. Each round, per provider with a free slot, one eligible group is drawn at random. Weight is
   1 plus one point per `Config.minutesPerPoint` waited, capped at `Config.maxWeight` (4), so waiting
   helps but never guarantees a win.
3. The group has `Config.offerSeconds` to accept. Declining or ignoring `Config.declinesBeforeLock`
   offers locks the group out for `Config.lockSeconds`, so nobody fishes for a better job.
4. Accepting calls the provider's `start(info)`. The group is marked busy in `som-groups` until the
   provider calls `finish`.

This design is mine, not copied from any server: NoPixel's group job board was described by players
but its code is private. The weights and times are defaults to tune.

## For providers

```lua
exports['som-jobboard']:registerProvider({
    id = 'courier', label = 'Courier run', summary = 'Deliver parcels', -- summary optional
    minSize = 1, maxSize = 4, slots = 2,   -- slots: jobs of this kind running at once
    canStart = function(group) return true end,   -- optional, return false, 'reason' to refuse
    start = function(group) ... return true end,  -- group is som-groups' getGroup shape
})

exports['som-jobboard']:finish(groupId) -- only the resource that registered the provider may call it
```

A provider that returns false or errors from `start` leaves the group free. A provider is not told
when a running group disbands; it should listen to `som-groups:server:changed`.

## Limits

Queues and refusals are in memory, so a restart clears them. A refusal lock follows the group, not
the people, so regrouping clears it (accepted for now). Not verified in a game.
