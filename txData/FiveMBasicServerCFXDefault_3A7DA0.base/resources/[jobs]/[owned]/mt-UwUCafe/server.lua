local QBCore = exports['qb-core']:GetCoreObject()

-------- foods ----------

RegisterNetEvent('mt-UwUCafe:server:FazerCupcakeMorango', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacoteleite = exports.ox_inventory:GetItem(src, 'pacote-leite', nil, false)
    local barramanteiga = exports.ox_inventory:GetItem(src, 'barra-manteiga', nil, false)
    local pacotefarinha = exports.ox_inventory:GetItem(src, 'pacote-farinha', nil, false)
    local caixamorangos = exports.ox_inventory:GetItem(src, 'caixa-morangos', nil, false)

    if pacoteleite ~= nil and barramanteiga ~= nil and pacotefarinha ~= nil and caixamorangos ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-leite', 1)
        exports.ox_inventory:RemoveItem(src, 'barra-manteiga', 1)
        exports.ox_inventory:RemoveItem(src, 'pacote-farinha', 1)
        exports.ox_inventory:RemoveItem(src, 'caixa-morangos', 1)
        exports.ox_inventory:AddItem(src, 'cupcake-morango', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerCupcakeLimao', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacoteleite = exports.ox_inventory:GetItem(src, 'pacote-leite', nil, false)
    local barramanteiga = exports.ox_inventory:GetItem(src, 'barra-manteiga', nil, false)
    local pacotefarinha = exports.ox_inventory:GetItem(src, 'pacote-farinha', nil, false)
    local limao = exports.ox_inventory:GetItem(src, 'limao', nil, false)

    if pacoteleite ~= nil and barramanteiga ~= nil and pacotefarinha ~= nil and limao ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-leite', 1)
        exports.ox_inventory:RemoveItem(src, 'barra-manteiga', 1)
        exports.ox_inventory:RemoveItem(src, 'pacote-farinha', 1)
        exports.ox_inventory:RemoveItem(src, 'limao', 1)
        exports.ox_inventory:AddItem(src, 'cupcake-limao', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerCupcakeChocolate', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacoteleite = exports.ox_inventory:GetItem(src, 'pacote-leite', nil, false)
    local barramanteiga = exports.ox_inventory:GetItem(src, 'barra-manteiga', nil, false)
    local pacotefarinha = exports.ox_inventory:GetItem(src, 'pacote-farinha', nil, false)
    local barrachocolate = exports.ox_inventory:GetItem(src, 'barra-chocolate', nil, false)

    if pacoteleite ~= nil and barramanteiga ~= nil and pacotefarinha ~= nil and barrachocolate ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-leite', 1)
        exports.ox_inventory:RemoveItem(src, 'barra-manteiga', 1)
        exports.ox_inventory:RemoveItem(src, 'pacote-farinha', 1)
        exports.ox_inventory:RemoveItem(src, 'barra-chocolate', 1)
        exports.ox_inventory:AddItem(src, 'cupcake-chocolate', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerGeladoMorango', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacotenatas = exports.ox_inventory:GetItem(src, 'pacote-natas', nil, false)
    local leitecondensado = exports.ox_inventory:GetItem(src, 'leite-condensado', nil, false)
    local caixamorangos = exports.ox_inventory:GetItem(src, 'caixa-morangos', nil, false)

    if pacotenatas ~= nil and leitecondensado ~= nil and caixamorangos ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-natas', 1)
        exports.ox_inventory:RemoveItem(src, 'leite-condensado', 1)
        exports.ox_inventory:RemoveItem(src, 'caixa-morangos', 1)
        exports.ox_inventory:AddItem(src, 'gelado-morango', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerGeladoChocolate', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacotenatas = exports.ox_inventory:GetItem(src, 'pacote-natas', nil, false)
    local leitecondensado = exports.ox_inventory:GetItem(src, 'leite-condensado', nil, false)
    local barrachocolate = exports.ox_inventory:GetItem(src, 'barra-chocolate', nil, false)

    if pacotenatas ~= nil and leitecondensado ~= nil and barrachocolate ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-natas', 1)
        exports.ox_inventory:RemoveItem(src, 'leite-condensado', 1)
        exports.ox_inventory:RemoveItem(src, 'barra-chocolate', 1)
        exports.ox_inventory:AddItem(src, 'gelado-chocolate', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerGeladoBaunilha', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacotenatas = exports.ox_inventory:GetItem(src, 'pacote-natas', nil, false)
    local leitecondensado = exports.ox_inventory:GetItem(src, 'leite-condensado', nil, false)
    local extratobaunilha = exports.ox_inventory:GetItem(src, 'extrato-baunilha', nil, false)

    if pacotenatas ~= nil and leitecondensado ~= nil and extratobaunilha ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-natas', 1)
        exports.ox_inventory:RemoveItem(src, 'leite-condensado', 1)
        exports.ox_inventory:RemoveItem(src, 'extrato-baunilha', 1)
        exports.ox_inventory:AddItem(src, 'gelado-baunilha', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerPanquencaNutela', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacotefarinha = exports.ox_inventory:GetItem(src, 'pacote-farinha', nil, false)
    local pacoteleite = exports.ox_inventory:GetItem(src, 'pacote-leite', nil, false)
    local pacoteacucar = exports.ox_inventory:GetItem(src, 'pacote-acucar', nil, false)
    local frasconutela = exports.ox_inventory:GetItem(src, 'frasco-nutela', nil, false)

    if pacotefarinha ~= nil and pacoteleite ~= nil and pacoteacucar ~= nil and frasconutela ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-farinha', 1)
        exports.ox_inventory:RemoveItem(src, 'pacote-leite', 1)
        exports.ox_inventory:RemoveItem(src, 'pacote-acucar', 1)
        exports.ox_inventory:RemoveItem(src, 'frasco-nutela', 1)
        exports.ox_inventory:AddItem(src, 'panqueca-nutela', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerPanquencaOreo', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacotefarinha = exports.ox_inventory:GetItem(src, 'pacote-farinha', nil, false)
    local pacoteleite = exports.ox_inventory:GetItem(src, 'pacote-leite', nil, false)
    local pacoteacucar = exports.ox_inventory:GetItem(src, 'pacote-acucar', nil, false)
    local pacoteoreo = exports.ox_inventory:GetItem(src, 'pacote-oreo', nil, false)

    if pacotefarinha ~= nil and pacoteleite ~= nil and pacoteacucar ~= nil and pacoteoreo ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-farinha', 1)
        exports.ox_inventory:RemoveItem(src, 'pacote-leite', 1)
        exports.ox_inventory:RemoveItem(src, 'pacote-acucar', 1)
        exports.ox_inventory:RemoveItem(src, 'pacote-oreo', 1)
        exports.ox_inventory:AddItem(src, 'panqueca-oreo', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerMuffinChocolate', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacotefarinha = exports.ox_inventory:GetItem(src, 'pacote-farinha', nil, false)
    local pacoteleite = exports.ox_inventory:GetItem(src, 'pacote-leite', nil, false)
    local barrachocolate = exports.ox_inventory:GetItem(src, 'barra-chocolate', nil, false)

    if pacotefarinha ~= nil and pacoteleite ~= nil and barrachocolate ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-farinha', 1)
        exports.ox_inventory:RemoveItem(src, 'pacote-leite', 1)
        exports.ox_inventory:RemoveItem(src, 'barra-chocolate', 1)
        exports.ox_inventory:AddItem(src, 'muffin-chocolate', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerWaffleNutela', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacotefarinha = exports.ox_inventory:GetItem(src, 'pacote-farinha', nil, false)
    local pacoteleite = exports.ox_inventory:GetItem(src, 'pacote-leite', nil, false)
    local frasconutela = exports.ox_inventory:GetItem(src, 'frasco-nutela', nil, false)

    if pacotefarinha ~= nil and pacoteleite ~= nil and frasconutela ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-farinha', 1)
        exports.ox_inventory:RemoveItem(src, 'pacote-leite', 1)
        exports.ox_inventory:RemoveItem(src, 'frasco-nutela', 1)
        exports.ox_inventory:AddItem(src, 'waffle-nutela', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerPastelFrango', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacotefarinha = exports.ox_inventory:GetItem(src, 'pacote-farinha', nil, false)
    local barramanteiga = exports.ox_inventory:GetItem(src, 'barra-manteiga', nil, false)
    local frango = exports.ox_inventory:GetItem(src, 'frango', nil, false)

    if pacotefarinha ~= nil and barramanteiga ~= nil and frango ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-farinha', 1)
        exports.ox_inventory:RemoveItem(src, 'barra-manteiga', 1)
        exports.ox_inventory:RemoveItem(src, 'frango', 1)
        exports.ox_inventory:AddItem(src, 'pastel-frango', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

---------------------------
------- drinks -----------

RegisterNetEvent('mt-UwUCafe:server:FazerCafe', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local water_bottle = exports.ox_inventory:GetItem(src, 'water_bottle', nil, false)
    local graoscafe = exports.ox_inventory:GetItem(src, 'graos-cafe', nil, false)

    if water_bottle ~= nil and graoscafe ~= nil then

        exports.ox_inventory:RemoveItem(src, 'water_bottle', 1)
        exports.ox_inventory:RemoveItem(src, 'graos-cafe', 1)
        exports.ox_inventory:AddItem(src, 'cafe-uwu', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerLatte', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacoteleite = exports.ox_inventory:GetItem(src, 'pacote-leite', nil, false)
    local graoscafe = exports.ox_inventory:GetItem(src, 'graos-cafe', nil, false)

    if graoscafe ~= nil and pacoteleite ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-leite', 1)
        exports.ox_inventory:RemoveItem(src, 'graos-cafe', 1)
        exports.ox_inventory:AddItem(src, 'latte-uwu', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerBubbleTeaAmora', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local water_bottle = exports.ox_inventory:GetItem(src, 'water_bottle', nil, false)
    local caixaamoras = exports.ox_inventory:GetItem(src, 'caixa-amoras', nil, false)

    if water_bottle ~= nil and caixaamoras ~= nil then

        exports.ox_inventory:RemoveItem(src, 'water_bottle', 1)
        exports.ox_inventory:RemoveItem(src, 'caixa-amoras', 1)
        exports.ox_inventory:AddItem(src, 'bubble-amora', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerBubbleTeaMorango', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local water_bottle = exports.ox_inventory:GetItem(src, 'water_bottle', nil, false)
    local caixamorangos = exports.ox_inventory:GetItem(src, 'caixa-morangos', nil, false)

    if water_bottle ~= nil and caixamorangos ~= nil then

        exports.ox_inventory:RemoveItem(src, 'water_bottle', 1)
        exports.ox_inventory:RemoveItem(src, 'caixa-morangos', 1)
        exports.ox_inventory:AddItem(src, 'bubble-morango', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerBubbleTeaMenta', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local water_bottle = exports.ox_inventory:GetItem(src, 'water_bottle', nil, false)
    local extratomenta = exports.ox_inventory:GetItem(src, 'extrato-menta', nil, false)

    if water_bottle ~= nil and extratomenta ~= nil then

        exports.ox_inventory:RemoveItem(src, 'water_bottle', 1)
        exports.ox_inventory:RemoveItem(src, 'extrato-menta', 1)
        exports.ox_inventory:AddItem(src, 'bubble-menta', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerMilkshakeChocolate', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacoteleite = exports.ox_inventory:GetItem(src, 'pacote-leite', nil, false)
    local barrachocolate = exports.ox_inventory:GetItem(src, 'barra-chocolate', nil, false)

    if pacoteleite ~= nil and barrachocolate ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-leite', 1)
        exports.ox_inventory:RemoveItem(src, 'barra-chocolate', 1)
        exports.ox_inventory:AddItem(src, 'milkshake-chocolate', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

RegisterNetEvent('mt-UwUCafe:server:FazerMilkshakeMorango', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pacoteleite = exports.ox_inventory:GetItem(src, 'pacote-leite', nil, false)
    local caixamorangos = exports.ox_inventory:GetItem(src, 'caixa-morangos', nil, false)

    if pacoteleite ~= nil and caixamorangos ~= nil then

        exports.ox_inventory:RemoveItem(src, 'pacote-leite', 1)
        exports.ox_inventory:RemoveItem(src, 'caixa-morangos', 1)
        exports.ox_inventory:AddItem(src, 'milkshake-morango', 1)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have the right items...', 'error')
    end
end)

----------------------------------------------
------- Take money ingredients ----------

RegisterNetEvent('mt-UwUCafe:server:Tirar20dolares', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    Player.Functions.RemoveMoney('bank', 20)
end)

RegisterNetEvent('mt-UwUCafe:server:Tirar30dolares', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    Player.Functions.RemoveMoney('bank', 30)
end)

RegisterNetEvent('mt-UwUCafe:server:Tirar50dolares', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    Player.Functions.RemoveMoney('bank', 50)
end)

-----------------------------------------------
-------- Use Drinks -------------------------

QBCore.Functions.CreateUseableItem("cafe-uwu", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:BeberCafe', source)
        exports.ox_inventory:RemoveItem(source, 'cafe-uwu', 1)
    end
end)

QBCore.Functions.CreateUseableItem("latte-uwu", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:BeberLatte', source)
        exports.ox_inventory:RemoveItem(source, 'latte-uwu', 1)
    end
end)

QBCore.Functions.CreateUseableItem("bubble-amora", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:BeberBubbleTea', source)
        exports.ox_inventory:RemoveItem(source, 'bubble-amora', 1)
    end
end)

QBCore.Functions.CreateUseableItem("bubble-morango", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:BeberBubbleTea', source)
        exports.ox_inventory:RemoveItem(source, 'bubble-morango', 1)
    end
end)

QBCore.Functions.CreateUseableItem("bubble-menta", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:BeberBubbleTea', source)
        exports.ox_inventory:RemoveItem(source, 'bubble-menta', 1)
    end
end)

QBCore.Functions.CreateUseableItem("milkshake-chocolate", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:BeberMilkshake', source)
        exports.ox_inventory:RemoveItem(source, 'milkshake-chocolate', 1)
    end
end)

QBCore.Functions.CreateUseableItem("milkshake-morango", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:BeberMilkshake', source)
        exports.ox_inventory:RemoveItem(source, 'milkshake-morango', 1)
    end
end)


-------------------------------------------------
--------- Using Food --------------------------

QBCore.Functions.CreateUseableItem("cupcake-morango", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:ComerCupcake', source)
        exports.ox_inventory:RemoveItem(source, 'cupcake-morango', 1)
    end
end)

QBCore.Functions.CreateUseableItem("cupcake-chocolate", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:ComerCupcake', source)
        exports.ox_inventory:RemoveItem(source, 'cupcake-chocolate', 1)
    end
end)

QBCore.Functions.CreateUseableItem("cupcake-limao", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:ComerCupcake', source)
        exports.ox_inventory:RemoveItem(source, 'cupcake-limao', 1)
    end
end)

QBCore.Functions.CreateUseableItem("gelado-morango", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:ComerGelado', source)
        exports.ox_inventory:RemoveItem(source, 'gelado-morango', 1)
    end
end)

QBCore.Functions.CreateUseableItem("gelado-chocolate", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:ComerGelado', source)
        exports.ox_inventory:RemoveItem(source, 'gelado-chocolate', 1)
    end
end)

QBCore.Functions.CreateUseableItem("gelado-baunilha", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:ComerGelado', source)
        exports.ox_inventory:RemoveItem(source, 'gelado-baunilha', 1)
    end
end)

QBCore.Functions.CreateUseableItem("panqueca-nutela", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:ComerPanqueca', source)
        exports.ox_inventory:RemoveItem(source, 'panqueca-nutela', 1)
    end
end)

QBCore.Functions.CreateUseableItem("panqueca-oreo", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:ComerPanqueca', source)
        exports.ox_inventory:RemoveItem(source, 'panqueca-oreo', 1)
    end
end)

QBCore.Functions.CreateUseableItem("muffin-chocolate", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:ComerMuffin', source)
        exports.ox_inventory:RemoveItem(source, 'muffin-chocolate', 1)
    end
end)

QBCore.Functions.CreateUseableItem("waffle-nutela", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:ComerWaffle', source)
        exports.ox_inventory:RemoveItem(source, 'waffle-nutela', 1)
    end
end)

QBCore.Functions.CreateUseableItem("pastel-frango", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('mt-UwUCafe:client:ComerPastel', source)
        exports.ox_inventory:RemoveItem(source, 'pastel-frango', 1)
    end
end)

------------------------------------------------
---------- Bill Player ----------------------

RegisterServerEvent("mt-UwUCafe:server:FaturarPlayer")
AddEventHandler("mt-UwUCafe:server:FaturarPlayer", function(playerId, amount)
        local biller = QBCore.Functions.GetPlayer(source)
        local billed = QBCore.Functions.GetPlayer(tonumber(playerId))
        local amount = tonumber(amount)
        if biller.PlayerData.job.name == 'uwu' then
            if billed ~= nil then
                if biller.PlayerData.citizenid ~= billed.PlayerData.citizenid then
                    if amount and amount > 0 then
                        MySQL.Async.execute('INSERT INTO phone_invoices (citizenid, amount, society, sender, sendercitizenid) VALUES (@citizenid, @amount, @society, @sender, @sendercitizenid)', {
                            ['@citizenid'] = billed.PlayerData.citizenid,
                            ['@amount'] = amount,
                            ['@society'] = biller.PlayerData.job.name,
                            ['@sender'] = biller.PlayerData.charinfo.firstname,
                            ['@sendercitizenid'] = biller.PlayerData.citizenid
                        })
                        TriggerClientEvent('qb-phone:RefreshPhone', billed.PlayerData.source)
                        TriggerClientEvent('QBCore:Notify', source, 'Invoice Successfully Sent', 'success')
                        TriggerClientEvent('QBCore:Notify', billed.PlayerData.source, 'New Invoice Received')
                    else
                        TriggerClientEvent('QBCore:Notify', source, 'Must be a number above 0', 'error')
                    end
                else
                    TriggerClientEvent('QBCore:Notify', source, 'You can not bill yourself...', 'error')
                end
            else
                TriggerClientEvent('QBCore:Notify', source, 'The player is not online', 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', source, 'No access', 'error')
        end
end)

RegisterNetEvent('mt-UwUCafe:Server:AddItem', function(item, amount)
    exports.ox_inventory:AddItem(source, item, amount)
end)