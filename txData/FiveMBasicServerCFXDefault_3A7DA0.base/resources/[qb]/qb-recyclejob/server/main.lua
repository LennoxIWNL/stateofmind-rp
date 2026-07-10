local QBCore = exports['qb-core']:GetCoreObject()

-- Events

RegisterNetEvent('qb-recycle:server:getItem', function()
  local src = source
  for _ = 1, math.random(1, Config.MaxItemsReceived), 1 do
    local randItem = Config.ItemTable[math.random(1, #Config.ItemTable)]
    local amount = math.random(Config.MinItemReceivedQty, Config.MaxItemReceivedQty)
    exports.ox_inventory:AddItem(src, randItem, amount)
    Wait(500)
  end

  local chance = math.random(1, 100)
  if chance < 7 then
    exports.ox_inventory:AddItem(src, Config.ChanceItem, 1)
  end

  local luck = math.random(1, 10)
  local odd = math.random(1, 10)
  if luck == odd then
    local random = math.random(1, 3)
    exports.ox_inventory:AddItem(src, Config.LuckyItem, random)
  end
end)