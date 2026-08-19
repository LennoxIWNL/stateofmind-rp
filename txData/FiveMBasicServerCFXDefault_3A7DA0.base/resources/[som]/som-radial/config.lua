Config = {}

-- ---------------------------------------------------------------------------
-- The radial is one of the three interaction surfaces in AUDIT 14.6, alongside
-- the third eye and the phone. It exists to REPLACE commands, not to wrap them.
--
-- Two rules it must keep:
--
--   1. Nothing here names an event. Entries name a validated export, because a
--      config that can fire an arbitrary event from a menu click lets the
--      client choose both the event and its payload.
--
--   2. Job and gang entries are filtered SERVER side. Sending everything and
--      hiding it in CSS would let the client decide what it is entitled to.
--
-- Emotes are deliberately absent. dpemotes owns them on /e, and a menu full of
-- them is the fastest route to the menu simulator feel this is meant to avoid.
-- ---------------------------------------------------------------------------

Config.OpenKey = 'F1'

-- Held, not toggled. Release selects whatever is under the cursor, which is
-- quicker than click-open then click-pick, and it cannot be left open.
Config.HoldToOpen = true

-- Below this, a flick of the mouse counts as no selection rather than a
-- mis-click on whatever happened to be nearest the centre.
Config.DeadZone = 0.22

Config.Colours = {
    default = '#ff1493',
    vehicle = '#4a9eff',
    job     = '#2ecc71',
    gang    = '#b8860b',
    self    = '#8e8e93',
    danger  = '#ff453a',
}

-- ---------------------------------------------------------------------------
-- Sections
--
-- `when` decides whether a section appears at all. Evaluated client side for
-- situational checks (am I in a vehicle) and server side for entitlement ones
-- (do I have this job).
-- ---------------------------------------------------------------------------

Config.Sections = {
    { id = 'vehicle', label = 'Vehicle', icon = 'car',    order = 10, when = 'vehicle' },
    { id = 'job',     label = 'Work',    icon = 'badge',  order = 20, when = 'job' },
    { id = 'gang',    label = 'Crew',    icon = 'gang',   order = 30, when = 'gang' },
    { id = 'self',    label = 'Self',    icon = 'person', order = 90 },
}

-- ---------------------------------------------------------------------------
-- Built in entries
--
-- Everything else arrives through exports['som-radial']:register from the
-- resource that owns the feature, the same way som-phone takes its apps.
-- ---------------------------------------------------------------------------

Config.Items = {
    -- --- Self ---------------------------------------------------------------
    {
        id = 'self.id',
        section = 'self',
        label = 'Show ID',
        icon = 'id',
        order = 10,
        export = 'som-id.useIdCard',
    },
    {
        id = 'self.handsup',
        section = 'self',
        label = 'Hands Up',
        icon = 'hands',
        order = 30,
        export = 'som-radial.handsUp',
    },

    -- --- Vehicle ------------------------------------------------------------
    --
    -- Doors are a submenu rather than six entries on the ring: a radial stops
    -- being readable past about eight slices.
    {
        id = 'vehicle.doors',
        section = 'vehicle',
        label = 'Doors',
        icon = 'door',
        order = 10,
        menu = 'doors',
    },
    {
        id = 'vehicle.engine',
        section = 'vehicle',
        label = 'Engine',
        icon = 'engine',
        order = 20,
        export = 'som-radial.toggleEngine',
        seatedOnly = true,
    },
    {
        id = 'vehicle.hazards',
        section = 'vehicle',
        label = 'Hazards',
        icon = 'hazard',
        order = 30,
        export = 'som-radial.toggleHazards',
        seatedOnly = true,
    },
    {
        id = 'vehicle.seats',
        section = 'vehicle',
        label = 'Seats',
        icon = 'seat',
        order = 40,
        menu = 'seats',
        seatedOnly = true,
    },
    -- STORING A CAR HAD NO WAY IN.
    --
    -- som-garage has had the whole path built for a while: a store() client
    -- function that handles both sitting in the car and standing beside it, a
    -- som-garage:server:store callback that re-checks ownership and distance,
    -- and canStoreNear/storeNearest exports written specifically to be called
    -- from here. Nothing ever called them, so the only route was the eye on the
    -- garage zone, and ox_target does not work from a driver's seat.
    --
    -- So the feature existed end to end and read as missing, because you had to
    -- get out of the car to put the car away and nothing said so.
    --
    -- NOT seatedOnly: standing beside it is a legitimate way to store, and
    -- canStoreNear accepts the nearest vehicle within 8m as well as the one you
    -- are sitting in.
    {
        id = 'vehicle.store',
        section = 'vehicle',
        label = 'Store vehicle',
        icon = 'garage',
        order = 50,
        export = 'som-garage.storeNearest',
        visible = 'som-garage.canStoreNear',
    },
}

-- Submenus. `dynamic` is built at open time by the client, because seats and
-- doors depend on the vehicle you are actually in.
Config.Menus = {
    doors = { label = 'Doors', dynamic = 'doors' },
    seats = { label = 'Seats', dynamic = 'seats' },
}

-- Door index to label. GTA's ordering, not ours.
Config.Doors = {
    [0] = 'Driver Front',
    [1] = 'Passenger Front',
    [2] = 'Driver Rear',
    [3] = 'Passenger Rear',
    [4] = 'Hood',
    [5] = 'Boot',
}
