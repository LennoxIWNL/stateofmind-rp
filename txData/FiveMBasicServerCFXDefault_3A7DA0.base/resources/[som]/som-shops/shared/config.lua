Config = {
    distance = 3.0,             -- player to the counter
    taxRate = 0.08,             -- share of each sale that goes to the city treasury
    sellBackRate = 0.5,         -- sell-back pays this share of the purchase price, from the treasury
    withdrawMax = 2000,         -- per withdrawal
    withdrawCooldownMinutes = 30,
    maxBuyPerPurchase = 20,
    maxStockPerItem = 100,
    maxItemsPerShop = 8,
    maxStaff = 3,
    maxHourlyPay = 250,
    hireDistance = 5.0,
    hireExpireSeconds = 60,
    payIntervalMinutes = 60,
    payTickSeconds = 60,

    -- What a shop may sell and the price range the owner may set, so a shop cannot be used to
    -- move money at absurd prices.
    items = {
        water = { min = 3, max = 30 },
        cola = { min = 4, max = 35 },
        coffee = { min = 4, max = 35 },
        sandwich = { min = 6, max = 45 },
        burger = { min = 8, max = 60 },
        bandage = { min = 15, max = 120 },
    },

    -- Ships disabled: each shop needs coordinates (staff /place, or set here) and enabled = true.
    shops = {
        { id = 'alta', label = 'Alta Street Store', price = 60000, enabled = false, coords = vec3(373.14, 328.62, 103.56) },
        { id = 'strawberry', label = 'Strawberry Corner Shop', price = 60000, enabled = false, coords = vec3(24.47, -1344.99, 29.49) },
    },
}
