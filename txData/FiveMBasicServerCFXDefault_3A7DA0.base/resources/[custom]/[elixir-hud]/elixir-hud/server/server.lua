local QBCore = exports['qb-core']:GetCoreObject()

local CodeID = {
    author = "Elixir FW",
    codeName = 'HUD V2 System 4.0',
    version = '2.2.0'
  }
  
  Citizen.CreateThread(function()
    print(CodeID.author .. ' - [' .. CodeID.codeName .. '] v' .. CodeID.version .. ' sucessfully started!')
  end)

  QBCore.Commands.Add('cash', 'Check Cash Balance', {}, false, function(source, _)
    local Player = QBCore.Functions.GetPlayer(source)
    local cashamount = Player.PlayerData.money.cash
    QBCore.Functions.Notify(source, 'You have:' ..cashamount.. ' in cash', "info")
end)

QBCore.Commands.Add('bank', 'Check Bank Balance', {}, false, function(source, _)
    local Player = QBCore.Functions.GetPlayer(source)
    local bankamount = Player.PlayerData.money.bank
    QBCore.Functions.Notify(source, 'You have:' ..bankamount.. ' in bank', "info")
end)