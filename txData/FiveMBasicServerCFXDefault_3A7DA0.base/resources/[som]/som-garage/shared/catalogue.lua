-- What the dealerships sell.
--
-- ONE RULE ABOVE ALL OTHERS: every model in here must actually stream on this
-- server. Both reference scripts ship a catalogue of every vanilla vehicle,
-- which on a server with a curated asset set means a shop that sells cars that
-- never load: the player pays, the row is written, and the car cannot be taken
-- out of the garage. That is worse than a short catalogue.
--
-- So this list is base game models plus the twenty five spawn names actually
-- present in som-lorefriendly, and nothing else. som-lorefriendly is gitignored
-- and hand-copied, so `Catalogue.Streamed` guards those at runtime rather than
-- trusting the list: a model that is not on the server is dropped from the
-- catalogue instead of being sold.
--
-- PRICING. Deliberately flat and legible rather than tuned. AUDIT 12.2 records
-- economy balance as an owner decision that must not be guessed at, so these
-- are placeholders with a shape: a compact is a few days of honest work, a
-- supercar is not reachable on a wage at all. Change the numbers, not the
-- structure.

Catalogue = {}

-- ---------------------------------------------------------------------------
-- Categories
--
-- Used for the shop tabs and for the cheap-range filter that decides what the
-- free-use lot may sell. Ordered, because pairs() is not.
-- ---------------------------------------------------------------------------

Catalogue.Categories = {
    { id = 'compact',  label = 'Compact' },
    { id = 'sedan',    label = 'Sedans' },
    { id = 'suv',      label = 'SUVs' },
    { id = 'coupe',    label = 'Coupes' },
    { id = 'muscle',   label = 'Muscle' },
    { id = 'offroad',  label = 'Off-road' },
    { id = 'van',      label = 'Vans and Utility' },
    { id = 'sport',    label = 'Sports' },
    { id = 'motorcycle', label = 'Motorcycles' },
}

-- ---------------------------------------------------------------------------
-- The cars
--
-- `lore` marks the twenty five som-lorefriendly spawn names. They are flagged
-- rather than separated so the shop lists them alongside the base game cars,
-- which is the point of having them: a street that looks lived in does not
-- separate its stock into two lists.
-- ---------------------------------------------------------------------------

Catalogue.Vehicles = {
    -- Compacts. The bottom of the market and the free-use lot's whole range.
    { model = 'blista',    label = 'Dinka Blista',        category = 'compact', price = 9000 },
    { model = 'panto',     label = 'Benefactor Panto',    category = 'compact', price = 8500 },
    { model = 'brioso',    label = 'Grotti Brioso R/A',   category = 'compact', price = 14000 },
    { model = 'issi2',     label = 'Weeny Issi',          category = 'compact', price = 11000 },
    { model = 'prairie',   label = 'Bollokan Prairie',    category = 'compact', price = 13000 },
    { model = 'rhapsody',  label = 'Declasse Rhapsody',   category = 'compact', price = 10000 },

    -- Sedans. The bulk of what anyone actually drives.
    { model = 'asea',      label = 'Declasse Asea',       category = 'sedan', price = 12000 },
    { model = 'primo',     label = 'Albany Primo',        category = 'sedan', price = 15000 },
    { model = 'stanier',   label = 'Vapid Stanier',       category = 'sedan', price = 16000 },
    { model = 'washington',label = 'Albany Washington',   category = 'sedan', price = 19000 },
    { model = 'intruder',  label = 'Karin Intruder',      category = 'sedan', price = 17000 },
    { model = 'fugitive',  label = 'Cheval Fugitive',     category = 'sedan', price = 22000 },
    { model = 'premier',   label = 'Declasse Premier',    category = 'sedan', price = 18000 },
    { model = 'schafter2', label = 'Benefactor Schafter', category = 'sedan', price = 42000 },
    { model = 'tailgater', label = 'Obey Tailgater',      category = 'sedan', price = 38000 },

    { model = 'esperanto', label = 'Albany Esperanto',    category = 'sedan', price = 21000, lore = true },
    { model = 'primoard',  label = 'Albany Primo ARD',    category = 'sedan', price = 24000, lore = true },
    { model = 'primolx',   label = 'Albany Primo LX',     category = 'sedan', price = 26000, lore = true },
    { model = '91prem',    label = 'Declasse Premier 91', category = 'sedan', price = 23000, lore = true },
    { model = 'elegant',   label = 'Elegant',             category = 'sedan', price = 25000, lore = true },
    { model = 'sunrise1',  label = 'Sunrise',             category = 'sedan', price = 27000, lore = true },
    { model = 'streiter2', label = 'Benefactor Streiter', category = 'sedan', price = 34000, lore = true },
    { model = 'schafter3rs', label = 'Benefactor Schafter V12', category = 'sedan', price = 58000, lore = true },
    { model = 'vincent3',  label = 'Maibatsu Vincent Tourer', category = 'sedan', price = 29000, lore = true },
    { model = 'sheavas',   label = 'Sheavas',             category = 'sedan', price = 28000, lore = true },

    -- SUVs and wagons.
    { model = 'granger',   label = 'Declasse Granger',    category = 'suv', price = 32000 },
    { model = 'landstalker', label = 'Dundreary Landstalker', category = 'suv', price = 30000 },
    { model = 'baller',    label = 'Gallivanter Baller',  category = 'suv', price = 46000 },
    { model = 'cavalcade', label = 'Albany Cavalcade',    category = 'suv', price = 41000 },
    { model = 'radi',      label = 'Vapid Radius',        category = 'suv', price = 27000 },

    { model = 'ncavalcade', label = 'Albany Cavalcade III', category = 'suv', price = 52000, lore = true },
    { model = 'indiana',   label = 'Declasse Indiana',    category = 'suv', price = 36000, lore = true },
    { model = 'indianaxl', label = 'Declasse Indiana XL', category = 'suv', price = 39000, lore = true },
    { model = 'millennial', label = 'Dinka Millennial Wagon', category = 'suv', price = 31000, lore = true },
    { model = 'nebulaw',   label = 'Vulcar Nebula Wagon', category = 'suv', price = 24000, lore = true },
    { model = 'panorama',  label = 'Panorama',            category = 'suv', price = 33000, lore = true },
    { model = 'panoramab', label = 'Panorama B',          category = 'suv', price = 34000, lore = true },
    { model = 'panoramas', label = 'Panorama S',          category = 'suv', price = 37000, lore = true },
    { model = 'torrence',  label = 'Vapid Torrence',      category = 'suv', price = 35000, lore = true },
    { model = 'atlas',     label = 'Atlas',               category = 'suv', price = 30000, lore = true },

    -- Coupes.
    { model = 'felon',     label = 'Lampadati Felon',     category = 'coupe', price = 48000 },
    { model = 'exemplar',  label = 'Dewbauchee Exemplar', category = 'coupe', price = 52000 },
    { model = 'sentinel',  label = 'Ubermacht Sentinel',  category = 'coupe', price = 44000 },
    { model = 'zion',      label = 'Ubermacht Zion',      category = 'coupe', price = 40000 },
    { model = 'oracle2',   label = 'Ubermacht Oracle XS', category = 'coupe', price = 38000 },

    -- Muscle.
    { model = 'buffalo2',  label = 'Bravado Buffalo S',   category = 'muscle', price = 45000 },
    { model = 'dominator', label = 'Vapid Dominator',     category = 'muscle', price = 47000 },
    { model = 'gauntlet',  label = 'Bravado Gauntlet',    category = 'muscle', price = 43000 },
    { model = 'sabregt',   label = 'Declasse Sabre Turbo', category = 'muscle', price = 39000 },
    { model = 'vigero',    label = 'Declasse Vigero',     category = 'muscle', price = 36000 },
    { model = 'ruiner',    label = 'Imponte Ruiner',      category = 'muscle', price = 34000 },

    -- Off-road.
    { model = 'rebel2',    label = 'Karin Rebel',         category = 'offroad', price = 26000 },
    { model = 'bifta',     label = 'BF Bifta',            category = 'offroad', price = 29000 },
    { model = 'sandking2', label = 'Vapid Sandking',      category = 'offroad', price = 54000 },
    { model = 'bodhi2',    label = 'Canis Bodhi',         category = 'offroad', price = 25000 },

    -- Vans and utility. The working end of the market, and what a delivery or
    -- a courier job needs to exist at all.
    { model = 'burrito3',  label = 'Declasse Burrito',    category = 'van', price = 21000 },
    { model = 'bison',     label = 'Bravado Bison',       category = 'van', price = 23000 },
    { model = 'rumpo',     label = 'Bravado Rumpo',       category = 'van', price = 22000 },
    { model = 'youga',     label = 'Bravado Youga',       category = 'van', price = 20000 },

    { model = 'servicevan', label = 'Bravado Boxville MBU', category = 'van', price = 44000, lore = true },
    { model = 'l35s',      label = 'Declasse Walton S',   category = 'van', price = 32000, lore = true },
    { model = 'l35l',      label = 'Declasse Walton L',   category = 'van', price = 35000, lore = true },
    { model = 'l35r',      label = 'Declasse Walton R',   category = 'van', price = 38000, lore = true },
    { model = 'turtle',    label = 'Karin Turtle',        category = 'van', price = 33000, lore = true },

    -- Sports. Above what a wage reaches, on purpose.
    { model = 'sultan',    label = 'Karin Sultan',        category = 'sport', price = 62000 },
    { model = 'elegy2',    label = 'Annis Elegy RH8',     category = 'sport', price = 74000 },
    { model = 'jester',    label = 'Dinka Jester',        category = 'sport', price = 96000 },
    { model = 'comet2',    label = 'Pfister Comet',       category = 'sport', price = 105000 },
    { model = 'ninef',     label = 'Obey 9F',             category = 'sport', price = 88000 },
    { model = 'feltzer2',  label = 'Benefactor Surano',   category = 'sport', price = 84000 },

    -- Motorcycles.
    { model = 'faggio2',   label = 'Pegassi Faggio',      category = 'motorcycle', price = 6000 },
    { model = 'sanchez',   label = 'Maibatsu Sanchez',    category = 'motorcycle', price = 12000 },
    { model = 'bagger',    label = 'Western Bagger',      category = 'motorcycle', price = 24000 },
    { model = 'akuma',     label = 'Dinka Akuma',         category = 'motorcycle', price = 31000 },
}

-- ---------------------------------------------------------------------------
-- Lookup
-- ---------------------------------------------------------------------------

local byModel = {}

for _, entry in ipairs(Catalogue.Vehicles) do
    byModel[entry.model] = entry
end

---@param model string
---@return table|nil
function Catalogue.Entry(model)
    if type(model) ~= 'string' then return nil end
    return byModel[model:lower()]
end

---@param id string category id
---@return string label
function Catalogue.CategoryLabel(id)
    for _, category in ipairs(Catalogue.Categories) do
        if category.id == id then return category.label end
    end
    return id
end

-- ---------------------------------------------------------------------------
-- Stock
--
-- The one rule at the top of this file, enforced rather than trusted.
--
-- There is no server side way to ask whether a model streams: IsModelValid and
-- IsModelInCdimage are CLIENT natives and there is no server equivalent. What
-- the server CAN see is which resources are running, and that is the whole
-- question here: base game models always exist, and every `lore` entry exists
-- if and only if som-lorefriendly is started.
--
-- som-lorefriendly is gitignored and hand-copied to the VPS, so this is not
-- theoretical. A fresh server without that copy would otherwise sell twenty
-- five cars that no client can load, and the buyer would pay for a row they can
-- never take out of a garage.
-- ---------------------------------------------------------------------------

---@param model string
---@return boolean
function Catalogue.IsStreamed(model)
    local entry = Catalogue.Entry(model)
    if not entry then return false end

    if entry.lore then
        return GetResourceState('som-lorefriendly') == 'started'
    end

    return true
end
