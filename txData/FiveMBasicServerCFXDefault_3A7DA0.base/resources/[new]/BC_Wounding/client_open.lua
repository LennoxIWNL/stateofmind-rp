-- ONLY EDIT IF YOU KNOW WHAT YOU'RE DOING. --

RegisterNetEvent('BC_Wounding:client:bleed', function(entity, attacker, weapon, isMelee)
    local weaponClass = Config.Weapons[weapon]
    local weaponWL = WeaponWhitelist(weaponClass) -- Shooting
    local hit, retvalBone = GetPedLastDamageBone(cache.ped)
    local bodyPartName = 'HEAD'
    if weaponClass == 14 or weaponClass == 7 or weaponClass == 8 or weaponClass == 9 then
        if math.random(1, 40) <= 15 then
            BodyParts[bodyPartName] = { broken = true, severity = true, bleeding = true }
        else
            BodyParts[bodyPartName] = { severity = true, bleeding = true }
        end

        bodyPartName = 'LARM'
        if math.random(1, 100) <= 40 then
            BodyParts[bodyPartName] = { broken = true, severity = true }
        end
        if math.random(1, 100) <= 40 then
            BodyParts['UPPER_BODY'] = { broken = true, severity = true }
            BodyParts['LOWER_BODY'] = { broken = true, severity = true }
        end

        bodyPartName = 'RARM'
        if math.random(1, 100) <= 50 then
            BodyParts[bodyPartName] = { broken = true, severity = true }
        end

        bodyPartName = 'LLEG'
        if math.random(1, 100) <= 50 then
            BodyParts[bodyPartName] = { broken = true, severity = true }
        end
    end
    if weaponClass == 12 then
        local bodyPartName = 'RFOOT'

        if math.random(1, 40) <= 5 then
            BodyParts["LFOOT"] = { severity = true, bleeding = true }
        else
            BodyParts[bodyPartName] = { severity = true, bleeding = true }
        end

        bodyPartName = 'LARM'
        if math.random(1, 100) <= 40 then
            BodyParts[bodyPartName] = { bleeding = true, severity = true }
        end

        bodyPartName = 'RARM'
        if math.random(1, 100) <= 50 then
            BodyParts[bodyPartName] = { bleeding = true, severity = true }
        end

        bodyPartName = 'LLEG'
        if math.random(1, 100) <= 50 then
            BodyParts[bodyPartName] = { bleeding = true, severity = true }
        end
        bodyPartName = 'RLEG'
        if math.random(1, 100) <= 40 then
            BodyParts[bodyPartName] = { bleeding = true, severity = true }
        end
    end
    if weaponClass == 5 then
        local bodyPartName = 'LOWER_BODY'

        if math.random(1, 40) <= 5 then
            BodyParts[bodyPartName] = { severity = true, bleeding = true }
        end

        bodyPartName = 'UPPER_BODY'
        if math.random(1, 100) <= 20 then
            BodyParts[bodyPartName] = { bleeding = true, severity = true }
        end

        bodyPartName = 'HEAD'
        if math.random(1, 100) <= 50 then
            BodyParts[bodyPartName] = { bleeding = true, severity = true }
        end
    end

    if hit then
        local BodyPart = Config.Bones[retvalBone]
        if BodyPart then
            if not BodyParts[BodyPart] then
                BodyParts[BodyPart] = {}
            end
            if not BodyParts[BodyPart].bullet then
                BodyParts[BodyPart].bullet = 0
            end
            if not BodyParts[BodyPart].bleeding then
                BodyParts[BodyPart].bleeding = false
            end
            if not BodyParts[BodyPart].severity then
                BodyParts[BodyPart].severity = false
            end
            if not BodyParts[BodyPart].broken then
                BodyParts[BodyPart].broken = false
            end
            if weaponWL then
                if BodyParts[BodyPart].bullet == 0 then
                    BodyParts[BodyPart].bullet = 1
                else
                    BodyParts[BodyPart].bullet = BodyParts[BodyPart].bullet + 1
                end
                if BodyParts[BodyPart].bullet >= 3 then
                    BodyParts[BodyPart].severity = true
                end
                if BodyParts[BodyPart].bullet >= 5 then
                    BodyParts[BodyPart].broken = true
                end
                if BodyParts[BodyPart].bullet >= 7 then
                    BodyParts[BodyPart].bleeding = true
                end
            end
            if weaponClass == 14 then
                if math.random(1, 40) <= 5 then
                    BodyParts[BodyPart].broken = true
                end
                BodyParts[BodyPart].severity = true
                BodyParts[BodyPart].bleeding = true
            end
        end
    end
    TriggerServerEvent('BC_Wounding:server:SaveDamage', BodyParts)
end)
