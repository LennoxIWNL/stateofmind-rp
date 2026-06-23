AddEventHandler('qb-playerDied', function(weaponLabel, time)
    TriggerClientEvent('som-deathscreen:openUI', source, time)
end)