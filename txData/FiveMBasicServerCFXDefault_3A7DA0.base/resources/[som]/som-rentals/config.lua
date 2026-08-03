Config = {}

-- ---------------------------------------------------------------------------
-- Vehicle rental.
--
-- Built first as the honest test of som-interact: a ped you walk up to, an eye
-- that changes when you look at it, an option beside it, and a real thing that
-- happens when you pick it. If that chain does not feel right here it will not
-- feel right anywhere.
--
-- It is also the cheapest way into the world for a new character. Per the
-- economy scale in som-economy, the bottom rung is a van at around 2K to BUY,
-- so renting has to be a small fraction of that or nobody walks.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- PLATES ARE EIGHT CHARACTERS.
--
-- GTA plates are capped at 8. "rental15474" is eleven and would be truncated
-- by the game, so the papers and the vehicle would disagree about the plate,
-- which is exactly the thing the papers exist to prove. RENT + four digits
-- fits exactly.
-- ---------------------------------------------------------------------------
Config.PlatePrefix = 'RENT'

-- ---------------------------------------------------------------------------
-- How far away the indicator circle appears, in metres.
--
-- ox_target draws its marker for ZONES, not for entity targets, so anything
-- that should show a circle is registered as a zone rather than against the
-- entity. This is that zone's radius: stand inside it with the eye up and the
-- circle is visible.
--
-- The per-option `distance` is separate and controls how close you have to be
-- to actually pick the option. Five is deliberately short: the circles answer
-- "is there something here", they are not a map of the district.
-- ---------------------------------------------------------------------------

Config.MarkerRadius = 5.0

Config.Locations = {
    lsia = {
        label = 'LSIA Vehicle Rental',

        -- The ped you interact with. Coordinates are a starting point: stand
        -- where you want it and use F11 to print your position, then correct
        -- these. z here is the ground, the ped is dropped onto it.
        ped = {
            model = 'a_m_y_business_01',
            coords = vec4(-1037.9, -2737.5, 20.17, 328.0),
            scenario = 'WORLD_HUMAN_CLIPBOARD',
        },

        -- Where the rented vehicle appears. Must be clear of the ped and on
        -- something drivable.
        spawn = vec4(-1027.6, -2748.9, 21.3, 148.0),

        blip = { sprite = 326, colour = 5, scale = 0.7 },

        vehicles = {
            { model = 'blista',  label = 'Blista',       price = 120 },
            { model = 'panto',   label = 'Panto',        price = 90 },
            { model = 'asea',    label = 'Asea',         price = 140 },
            { model = 'rumpo',   label = 'Rumpo Van',    price = 220 },
            { model = 'faggio',  label = 'Faggio Sport', price = 60 },
        },
    },
}

-- ---------------------------------------------------------------------------
-- Money
--
-- The deposit is the whole point of the papers. You pay it up front and get it
-- back when the vehicle comes home, which is what stops a rental being a
-- disposable car you abandon at the first traffic light.
-- ---------------------------------------------------------------------------

Config.Deposit = 500

-- Taken from cash, not bank. Renting a car at a counter is a cash transaction,
-- and it gives the starting cash balance something to do.
Config.Account = 'cash'

-- Refunded portion of the deposit when the vehicle is returned. Below 1.0 the
-- difference is a sink; at 1.0 renting costs only the hire fee.
Config.DepositRefund = 1.0

-- The business that takes the money. Must exist in som_businesses or the
-- payment falls back to being a plain sink.
Config.Business = 'downtowncab'

-- ---------------------------------------------------------------------------
-- Papers
--
-- An ox_inventory item carrying the plate, the renter and the time. Hovering
-- it shows all three, because a rental agreement nobody can read is a prop.
-- ---------------------------------------------------------------------------

Config.PapersItem = 'rental_papers'

-- How long a rental lasts before it is considered abandoned, in minutes. The
-- vehicle is not deleted out from under a player; this only marks the row so a
-- cleanup job can find it later.
Config.RentalMinutes = 180
