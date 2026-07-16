local QBCore = exports['qb-core']:GetCoreObject()

-- Functions

local function IsWeaponBlocked(WeaponName)
    local retval = false
    for _, name in pairs(Config.DurabilityBlockedWeapons) do
        if name == WeaponName then
            retval = true
            break
        end
    end
    return retval
end

-- Callback

QBCore.Functions.CreateCallback('weapons:server:GetConfig', function(_, cb)
    cb(Config.WeaponRepairPoints)
end)

QBCore.Functions.CreateCallback('weapon:server:GetWeaponAmmo', function(source, cb, WeaponData)
    local retval = 0
    if WeaponData then
        local slotData = exports.ox_inventory:GetSlot(source, WeaponData.slot)
        if slotData and slotData.metadata then
            retval = slotData.metadata.ammo or 0
        end
    end
    cb(retval, WeaponData.name)
end)

QBCore.Functions.CreateCallback('weapons:server:RepairWeapon', function(source, cb, RepairPoint, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local minute = 60 * 1000
    local Timeout = math.random(5 * minute, 10 * minute)
    local WeaponData = QBCore.Shared.Weapons[GetHashKey(data.name)]
    local WeaponClass = (QBCore.Shared.SplitStr(WeaponData.ammotype, '_')[2]):lower()
    local weaponSlotData = exports.ox_inventory:GetSlot(src, data.slot)

    if weaponSlotData then
        if weaponSlotData.metadata.quality then
            if weaponSlotData.metadata.quality ~= 100 then
                if Player.Functions.RemoveMoney('cash', Config.WeaponRepairCosts[WeaponClass]) then
                    Config.WeaponRepairPoints[RepairPoint].IsRepairing = true
                    Config.WeaponRepairPoints[RepairPoint].RepairingData = {
                        CitizenId = Player.PlayerData.citizenid,
                        WeaponData = weaponSlotData,
                        Ready = false,
                    }
                    if not exports.ox_inventory:RemoveItem(src, data.name, 1, nil, data.slot) then
                        return Player.Functions.AddMoney('cash', Config.WeaponRepairCosts[WeaponClass])
                    end
                    TriggerClientEvent('inventory:client:CheckWeapon', src, data.name)
                    TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)

                    SetTimeout(Timeout, function()
                        Config.WeaponRepairPoints[RepairPoint].IsRepairing = false
                        Config.WeaponRepairPoints[RepairPoint].RepairingData.Ready = true
                        TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)
                        exports['qb-phone']:sendNewMailToOffline(Player.PlayerData.citizenid, {
                            sender = Lang:t('mail.sender'),
                            subject = Lang:t('mail.subject'),
                            message = Lang:t('mail.message', { value = WeaponData.label })
                        })
                        SetTimeout(7 * 60000, function()
                            if Config.WeaponRepairPoints[RepairPoint].RepairingData.Ready then
                                Config.WeaponRepairPoints[RepairPoint].IsRepairing = false
                                Config.WeaponRepairPoints[RepairPoint].RepairingData = {}
                                TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)
                            end
                        end)
                    end)
                    cb(true)
                else
                    cb(false)
                end
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_damage_on_weapon'), 'error')
                cb(false)
            end
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_damage_on_weapon'), 'error')
            cb(false)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_weapon_in_hand'), 'error')
        TriggerClientEvent('weapons:client:SetCurrentWeapon', src, {}, false)
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('prison:server:checkThrowable', function(source, cb, weapon)
    local throwable = false
    for _, v in pairs(Config.Throwables) do
        if QBCore.Shared.Weapons[weapon].name == 'weapon_' .. v then
            if not exports.ox_inventory:RemoveItem(source, 'weapon_' .. v, 1) then return cb(false) end
            throwable = true
            break
        end
    end
    cb(throwable)
end)

-- Events

RegisterNetEvent('weapons:server:UpdateWeaponAmmo', function(CurrentWeaponData, amount)
    local src = source
    amount = tonumber(amount)
    if CurrentWeaponData then
        local slotData = exports.ox_inventory:GetSlot(src, CurrentWeaponData.slot)
        if slotData then
            local metadata = slotData.metadata or {}
            metadata.ammo = amount
            exports.ox_inventory:SetMetadata(src, CurrentWeaponData.slot, metadata)
        end
    end
end)

RegisterNetEvent('weapons:server:TakeBackWeapon', function(k)
    local src = source
    local itemdata = Config.WeaponRepairPoints[k].RepairingData.WeaponData
    local metadata = itemdata.metadata or {}
    metadata.quality = 100
    exports.ox_inventory:AddItem(src, itemdata.name, 1, metadata)
    Config.WeaponRepairPoints[k].IsRepairing = false
    Config.WeaponRepairPoints[k].RepairingData = {}
    TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[k], k)
end)

RegisterNetEvent('weapons:server:SetWeaponQuality', function(data, hp)
    local src = source
    local slotData = exports.ox_inventory:GetSlot(src, data.slot)
    if not slotData then return end
    local metadata = slotData.metadata or {}
    metadata.quality = hp
    exports.ox_inventory:SetMetadata(src, data.slot, metadata)
end)

RegisterNetEvent('weapons:server:UpdateWeaponQuality', function(data, RepeatAmount)
    local src = source
    local WeaponData = QBCore.Shared.Weapons[GetHashKey(data.name)]
    local slotData = exports.ox_inventory:GetSlot(src, data.slot)
    if not slotData then return end
    local metadata = slotData.metadata or {}
    local DecreaseAmount = Config.DurabilityMultiplier[data.name]
    if not IsWeaponBlocked(WeaponData.name) then
        metadata.quality = metadata.quality or 100
        for _ = 1, RepeatAmount, 1 do
            if metadata.quality - DecreaseAmount > 0 then
                metadata.quality = metadata.quality - DecreaseAmount
            else
                metadata.quality = 0
                TriggerClientEvent('inventory:client:UseWeapon', src, data, false)
                TriggerClientEvent('QBCore:Notify', src, Lang:t('error.weapon_broken_need_repair'), 'error')
                break
            end
        end
    end
    exports.ox_inventory:SetMetadata(src, data.slot, metadata)
end)

RegisterNetEvent('weapons:server:removeWeaponAmmoItem', function(item)
    local src = source

    if type(item) ~= 'table' or not item.name or not item.slot then return end

    exports.ox_inventory:RemoveItem(src, item.name, 1, nil, item.slot)
end)

-- Commands

QBCore.Commands.Add('repairweapon', 'Repair Weapon (God Only)', { { name = 'hp', help = Lang:t('info.hp_of_weapon') } }, true, function(source, args)
    TriggerClientEvent('weapons:client:SetWeaponQuality', source, tonumber(args[1]))
end, 'god')

-- Items

-- AMMO
QBCore.Functions.CreateUseableItem('pistol_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_PISTOL', 12, item)
end)

QBCore.Functions.CreateUseableItem('rifle_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_RIFLE', 30, item)
end)

QBCore.Functions.CreateUseableItem('smg_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_SMG', 20, item)
end)

QBCore.Functions.CreateUseableItem('shotgun_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_SHOTGUN', 10, item)
end)

QBCore.Functions.CreateUseableItem('mg_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_MG', 30, item)
end)

QBCore.Functions.CreateUseableItem('snp_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_SNIPER', 10, item)
end)

QBCore.Functions.CreateUseableItem('emp_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_EMPLAUNCHER', 10, item)
end)

-- TINTS

local function GetWeaponSlotData(source, weaponName)
    local slots = exports.ox_inventory:Search(source, 'slots', weaponName)
    return slots and slots[1] or nil
end

local function IsMK2Weapon(weaponHash)
    local weaponName = QBCore.Shared.Weapons[weaponHash]['name']
    return string.find(weaponName, 'mk2') ~= nil
end

local function EquipWeaponTint(source, tintIndex, item, isMK2)
    local ped = GetPlayerPed(source)
    local selectedWeaponHash = GetSelectedPedWeapon(ped)

    if selectedWeaponHash == `WEAPON_UNARMED` then
        TriggerClientEvent('QBCore:Notify', source, 'You have no weapon selected.', 'error')
        return
    end

    local weaponName = QBCore.Shared.Weapons[selectedWeaponHash].name
    if not weaponName then return end

    if isMK2 and not IsMK2Weapon(selectedWeaponHash) then
        TriggerClientEvent('QBCore:Notify', source, 'This tint is only for MK2 weapons', 'error')
        return
    end

    local weaponSlot = GetWeaponSlotData(source, weaponName)
    if not weaponSlot then return end

    local metadata = weaponSlot.metadata or {}
    if metadata.tint == tintIndex then
        TriggerClientEvent('QBCore:Notify', source, 'This tint is already applied to your weapon.', 'error')
        return
    end

    metadata.tint = tintIndex
    exports.ox_inventory:SetMetadata(source, weaponSlot.slot, metadata)
    exports.ox_inventory:RemoveItem(source, item, 1)
    TriggerClientEvent('weapons:client:EquipTint', source, selectedWeaponHash, tintIndex)
end

for i = 0, 7 do
    QBCore.Functions.CreateUseableItem('weapontint_' .. i, function(source, item)
        EquipWeaponTint(source, i, item.name, false)
    end)
end

for i = 0, 32 do
    QBCore.Functions.CreateUseableItem('weapontint_mk2_' .. i, function(source, item)
        EquipWeaponTint(source, i, item.name, true)
    end)
end

-- Attachments

local function HasAttachment(component, attachments)
    for k, v in pairs(attachments) do
        if v.component == component then
            return true, k
        end
    end
    return false, nil
end

local function DoesWeaponTakeWeaponComponent(item, weaponName)
    if WeaponAttachments[item] and WeaponAttachments[item][weaponName] then
        return WeaponAttachments[item][weaponName]
    end
    return false
end

local function EquipWeaponAttachment(src, item)
    local shouldRemove = false
    local ped = GetPlayerPed(src)
    local selectedWeaponHash = GetSelectedPedWeapon(ped)
    if selectedWeaponHash == `WEAPON_UNARMED` then return end
    local weaponName = QBCore.Shared.Weapons[selectedWeaponHash].name
    if not weaponName then return end
    local attachmentComponent = DoesWeaponTakeWeaponComponent(item, weaponName)
    if not attachmentComponent then
        TriggerClientEvent('QBCore:Notify', src, 'This attachment is not valid for the selected weapon.', 'error')
        return
    end
    local weaponSlot = GetWeaponSlotData(src, weaponName)
    if not weaponSlot then return end
    local metadata = weaponSlot.metadata or {}
    metadata.attachments = metadata.attachments or {}
    local hasAttach, attachIndex = HasAttachment(attachmentComponent, metadata.attachments)
    if hasAttach then
        RemoveWeaponComponentFromPed(ped, selectedWeaponHash, attachmentComponent)
        table.remove(metadata.attachments, attachIndex)
    else
        metadata.attachments[#metadata.attachments + 1] = {
            component = attachmentComponent,
        }
        GiveWeaponComponentToPed(ped, selectedWeaponHash, attachmentComponent)
        shouldRemove = true
    end
    exports.ox_inventory:SetMetadata(src, weaponSlot.slot, metadata)
    if shouldRemove then
        exports.ox_inventory:RemoveItem(src, item, 1)
    end
end

for attachmentItem in pairs(WeaponAttachments) do
    QBCore.Functions.CreateUseableItem(attachmentItem, function(source, item)
        EquipWeaponAttachment(source, item.name)
    end)
end

QBCore.Functions.CreateCallback('weapons:server:RemoveAttachment', function(source, cb, AttachmentData, WeaponData)
    local src = source
    local allAttachments = WeaponAttachments
    local AttachmentComponent = allAttachments[AttachmentData.attachment][WeaponData.name]
    local slotData = exports.ox_inventory:GetSlot(src, WeaponData.slot)

    if slotData then
        local metadata = slotData.metadata or {}
        if metadata.attachments and next(metadata.attachments) then
            local HasAttach, key = HasAttachment(AttachmentComponent, metadata.attachments)
            if HasAttach then
                table.remove(metadata.attachments, key)
                exports.ox_inventory:SetMetadata(src, WeaponData.slot, metadata)
                exports.ox_inventory:AddItem(src, AttachmentData.attachment, 1)
                TriggerClientEvent('QBCore:Notify', src, Lang:t('info.removed_attachment', { value = QBCore.Shared.Items[AttachmentData.attachment].label }), 'error')
                cb(metadata.attachments)
            else
                cb(false)
            end
        else
            cb(false)
        end
    else
        cb(false)
    end
end)
