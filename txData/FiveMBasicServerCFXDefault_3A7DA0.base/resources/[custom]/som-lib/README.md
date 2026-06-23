


## NOTIFY

- CLIENT

INFO > TriggerEvent('som-lib:notify', "You can write anything here." , 4000, "info")
ERROR > TriggerEvent('som-lib:notify', "You can write anything here." , 4000, "error")
SUCCESS > TriggerEvent('som-lib:notify', "You can write anything here." , 4000, "success")

- SERVER

INFO > TriggerClientEvent('som-lib:notify',source, "You can write anything here." , 4000, "info")
ERROR > TriggerClientEvent('som-lib:notify', source,"You can write anything here." , 4000, "error")
SUCCESS > TriggerClientEvent('som-lib:notify',source, "You can write anything here." , 4000, "success")


## PROGRESSBAR
exports['som-lib']:progbaractive("Helpp", 4000)

## INFO BAR

- CLIENT

OPEN > TriggerEvent('som-lib:openinfo', "Get Car" , "Go to motel and take car.")
CLOSE > TriggerEvent('som-lib:closeinfo')

- SERVER

OPEN > TriggerClientEvent('som-lib:openinfo', source,"Get Car" , "Go to motel and take car.")
CLOSE > TriggerClientEvent('som-lib:closeinfo', source)



## QB Notify example edit ---------------------------------------------- 


function QBCore.Functions.Notify(text, texttype, length)
    length = length or 5000
    texttype = texttype or 'info'

    if texttype == "primary" then 
        texttype = "info"
    end



    TriggerEvent('som-lib:notify', text , length, texttype)
end