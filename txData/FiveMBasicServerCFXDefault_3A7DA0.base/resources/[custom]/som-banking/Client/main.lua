TwoNa = exports["2na_core"]:getSharedObject()

RegisterNetEvent("som-banking:Client:BankMenu:Show")
AddEventHandler("som-banking:Client:BankMenu:Show", function() 
    TwoNa.TriggerServerCallback("som-banking:Server:GetUserAccounts", {}, function(bankData) 
        if bankData then 
            SetNuiFocus(true, true)

            TriggerScreenblurFadeIn(500)
            
            SendNUIMessage({
                action = "showMenu",
                playerName = bankData.playerName,
                accounts = bankData.accounts
            })
        end
    end)
end)

RegisterNetEvent("som-banking:Client:BankMenu:Hide")
AddEventHandler("som-banking:Client:BankMenu:Hide", function() 
    SetNuiFocus(false, false)
    
    TriggerScreenblurFadeOut(500)

    SendNUIMessage({
        action = "hideMenu"
    })
end)