Config = {
    distance = 3.0,
    taxRate = 0.08,             -- share of each served order that goes to the city treasury
    manageGrade = 3,            -- boss actions: hire, fire, withdraw
    maxStaff = 6,
    hireDistance = 5.0,
    hireExpireSeconds = 60,
    withdrawMax = 3000,
    withdrawCooldownMinutes = 30,
    maxBuyPerPurchase = 20,
    maxLines = 6,
    offerSeconds = 60,          -- how long a customer has to accept an order
    serveWindowMinutes = 15,    -- a paid order not served by then is refunded to the customer
    refundTickSeconds = 60,
    cookMinFraction = 0.9,      -- a finish sooner than this share of the duration is refused

    -- Ships disabled: a restaurant needs a counter (staff /place, or set here) and enabled = true.
    -- Stations are { id = 'grill', kind = 'grill', coords = nil }; the fridge and supplier likewise.
    restaurants = {
        {
            id = 'burgershot', label = 'Burger Shot', job = 'burgershot', business = 'burgershot',
            price = 150000, enabled = false, coords = nil,
            stations = {
                { id = 'prep', kind = 'prep', coords = nil },
                { id = 'grill', kind = 'grill', coords = nil },
                { id = 'fryer', kind = 'fryer', coords = nil },
                { id = 'drinks', kind = 'drinks', coords = nil },
                { id = 'assemble', kind = 'assemble', coords = nil },
            },
            fridge = { coords = nil, slots = 60, weight = 80000 },
            selfServe = { coords = nil },
        },
    },

    -- The city wholesaler. Unit prices live here and nowhere else.
    supplier = {
        enabled = false, coords = nil,
        goods = {
            burgershot_frozenmeat = 10, burgershot_bread = 2, burgershot_tomato = 2, burgershot_cheddar = 2,
            burgershot_sauce = 1, burgershot_bigfrozenpotato = 4, burgershot_smallfrozenpotato = 3,
            burgershot_bigemptyglass = 2, burgershot_smallemptyglass = 1, burgershot_coffeeemptyglass = 1,
        },
    },

    -- Steps follow ox_inventory's crafting.lua shape (ingredients, duration, count), run by the server.
    recipes = {
        thaw = { station = 'prep', label = 'Thaw and shape meat', ingredients = { burgershot_frozenmeat = 1 }, output = 'burgershot_meat', count = 2, duration = 4000 },
        patty = { station = 'grill', label = 'Grill a patty', ingredients = { burgershot_meat = 1 }, output = 'burgershot_patty', count = 1, duration = 8000 },
        fries_big = { station = 'fryer', label = 'Fry big fries', ingredients = { burgershot_bigfrozenpotato = 1 }, output = 'burgershot_patatob', count = 1, duration = 7000 },
        fries_small = { station = 'fryer', label = 'Fry small fries', ingredients = { burgershot_smallfrozenpotato = 1 }, output = 'burgershot_patatos', count = 1, duration = 6000 },
        cola_big = { station = 'drinks', label = 'Pour a big cola', ingredients = { burgershot_bigemptyglass = 1 }, output = 'burgershot_colab', count = 1, duration = 3000 },
        cola_small = { station = 'drinks', label = 'Pour a small cola', ingredients = { burgershot_smallemptyglass = 1 }, output = 'burgershot_colas', count = 1, duration = 2500 },
        coffee = { station = 'drinks', label = 'Make a coffee', ingredients = { burgershot_coffeeemptyglass = 1 }, output = 'burgershot_coffee', count = 1, duration = 3000 },
        bigking = { station = 'assemble', label = 'Assemble a Big King', ingredients = { burgershot_patty = 2, burgershot_bread = 1, burgershot_tomato = 1, burgershot_cheddar = 1, burgershot_sauce = 1 }, output = 'burgershot_bigking', count = 1, duration = 6000 },
        bleeder = { station = 'assemble', label = 'Assemble a Bleeder', ingredients = { burgershot_patty = 1, burgershot_bread = 1, burgershot_tomato = 1, burgershot_sauce = 1 }, output = 'burgershot_bleeder', count = 1, duration = 5000 },
    },

    -- The only prices a customer is ever charged at the counter.
    menu = {
        bigking = { item = 'burgershot_bigking', label = 'Big King', price = 28, maxQty = 5 },
        bleeder = { item = 'burgershot_bleeder', label = 'Bleeder Burger', price = 20, maxQty = 5 },
        patatob = { item = 'burgershot_patatob', label = 'Big Fries', price = 9, maxQty = 5 },
        patatos = { item = 'burgershot_patatos', label = 'Small Fries', price = 6, maxQty = 5 },
        colab = { item = 'burgershot_colab', label = 'Big Cola', price = 6, maxQty = 5 },
        colas = { item = 'burgershot_colas', label = 'Small Cola', price = 4, maxQty = 5 },
        coffee = { item = 'burgershot_coffee', label = 'Coffee', price = 5, maxQty = 5 },
    },

    -- The unstaffed counter: plain shop food at a premium, paid to the city.
    fallback = {
        maxQty = 3,
        goods = {
            burger = { label = 'Burger', price = 32 },
            sandwich = { label = 'Sandwich', price = 26 },
            cola = { label = 'Cola', price = 14 },
            water = { label = 'Water', price = 10 },
        },
    },
}
