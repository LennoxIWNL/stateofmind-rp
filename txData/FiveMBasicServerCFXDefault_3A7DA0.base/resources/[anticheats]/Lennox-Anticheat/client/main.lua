-- [[ Lennox Anti-Cheat — Client Module ]] --
-- [[ Protected — tampering will result in detection ]] --

do
    local _R = {0x5A, 0x3C, 0x7F, 0x11, 0xE2, 0x9B, 0x44, 0xD7}
    local _sc, _tc, _tb = string.char, table.concat, table.insert
    local _f1, _f2, _f3 = string.byte, string.format, string.find

    local function _S(e)
        local o = {}
        for i = 1, #e do
            o[i] = _sc(((e[i] - _R[((i-1) % #_R) + 1]) + 256) % 256)
        end
        return _tc(o)
    end

    local _E = {
        _0x01 = {166, 161, 237, 127, 81, 19},
        _0x02 = {194, 158, 185, 116, 74, 252, 176, 67, 191, 170, 230, 118},
        _0x03 = {194, 158, 185, 131, 71, 14, 180, 70, 200, 175, 228},
        _0x04 = {190, 161, 243, 75, 73, 10, 168, 68, 201, 160, 228},
        _0x05 = {190, 161, 243, 75, 84, 0, 183, 70, 207, 174, 226, 118},
        _0x06 = {195, 170, 245, 122, 80, 254, 173, 57, 198, 161, 222, 119, 78, 252, 171, 54, 191, 170, 224, 115, 78, 0, 168},
        _0x07 = {195, 170, 245, 122, 85, 4, 166, 67, 191, 155, 246, 121, 75, 7, 169, 54, 199, 171, 245, 122, 80, 2},
        _0x08 = {200, 177, 236, 115, 71, 13},
        _0x09 = {205, 176, 241, 122, 80, 2},
        _0x0A = {198, 157, 226, 75, 85, 0, 183, 74, 195, 171, 237, 75, 75, 9, 173, 75},
        _0x0B = {198, 157, 226, 75, 85, 0, 183, 74, 195, 171, 237, 75, 88, 252, 176, 64, 190, 157, 243, 118},
        _0x0C = {190, 161, 243, 75, 80, 10, 167, 67, 195, 172},
        _0x0D = {190, 161, 243, 75, 74, 0, 165, 67, 206, 164},
        _0x0E = {190, 161, 243, 75, 89, 0, 165, 71, 201, 170},
        _0x0F = {190, 161, 243, 75, 67, 9, 184, 64, 206, 157, 236, 129, 71, 13},
        _0x10 = {200, 171, 226, 125, 75, 11, 163, 76, 200, 160, 228, 131, 73, 13, 179, 76, 200, 160},
        _0x11 = {200, 171, 226, 125, 75, 11, 163, 61, 198, 181, 232, 127, 73},
        _0x12 = {194, 161, 224, 125, 86, 3, 163, 74, 200, 157, 239, 112, 74, 0, 165, 67},
        _0x13 = {191, 180, 228, 116, 87, 15, 179, 73, 185, 160, 228, 133, 71, 254, 184, 60, 190},
    }

    local _0xA1 = _S(_E._0x01)
    local _0xCF = LACConfig

    local _0xB2 = function(_0xZ1)
        local _0xH = 0x5A3C
        for _0xI = 1, #_0xZ1 do
            _0xH = (_0xH * 33 + _f1(_0xZ1, _0xI)) % 0x7FFFFFFF
        end
        return _0xH
    end

    local _0xD3 = _0xB2(_0xA1)
    local _0xD4 = _0xB2(_sc(76, 101, 110, 110, 111, 120))
    local _0xD5 = (_0xD4 % 7919) + 1

    local function _0xK1(_0xB)
        return _f2('lac:%x', _0xB2(_0xA1 .. ':' .. _0xB))
    end

    -- session token (set by server on join)
    local _0xTK = nil
    local _0xNC = 0

    local function _0xGN()
        _0xNC = _0xNC + 1
        return (_0xNC * _0xD3 + GetGameTimer()) % 0x7FFFFFFF
    end

    -- ========== Session Token Receiver ==========
    local _0xEV_SI = _0xK1(_S(_E._0x0A))

    RegisterNetEvent(_0xEV_SI, function(_0xT)
        if type(_0xT) == _S(_E._0x09) then
            _0xTK = _0xT
        end
    end)

    local function _0xSE(_0xEV, ...)
        if not _0xTK then return end
        local _0xN = _0xGN()
        TriggerServerEvent(_0xEV, _0xTK, _0xN, ...)
    end

    -- ========== Heartbeat Responder ==========
    local _0xEV_HC = _0xK1(_S(_E._0x02))
    local _0xEV_HR = _0xK1(_S(_E._0x03))

    RegisterNetEvent(_0xEV_HC, function(_0xC)
        if type(_0xC) ~= _S(_E._0x08) then return end
        local _0xRS = ((_0xC * _0xD3) % 0x7FFFFFFF) + _0xD5
        if _0xTK then
            local _0xN = _0xGN()
            TriggerServerEvent(_0xEV_HR, _0xTK, _0xN, _0xRS)
        else
            TriggerServerEvent(_0xEV_HR, nil, 0, _0xRS)
        end
    end)

    -- ========== God Mode Detection ==========
    local _0xEV_DG = _0xK1(_S(_E._0x04))

    CreateThread(function()
        Wait(15000 + (GetGameTimer() % 3000))
        while true do
            Wait(5000 + (GetGameTimer() % 2000))
            local _0xPF = GetPlayerInvincible(PlayerId())
            if _0xPF then
                _0xSE(_0xEV_DG, _S(_E._0x06))
            end
        end
    end)

    -- ========== Blacklisted Resource Scan ==========
    local _0xEV_DR = _0xK1(_S(_E._0x05))

    CreateThread(function()
        Wait(20000 + (GetGameTimer() % 5000))
        local _0xBL = _0xCF.BlacklistedResources or {}
        while true do
            local _0xNR = GetNumResources()
            for _0xI = 0, _0xNR - 1 do
                local _0xRN = GetResourceByFindIndex(_0xI)
                if _0xRN then
                    local _0xLW = _0xRN:lower()
                    for _, _0xBE in ipairs(_0xBL) do
                        if _0xLW:find(_0xBE, 1, true) then
                            _0xSE(_0xEV_DR, _0xRN)
                            Wait(60000)
                            break
                        end
                    end
                end
            end
            Wait(30000 + (GetGameTimer() % 10000))
        end
    end)

    -- ========== Spectate / Freecam Detection ==========
    CreateThread(function()
        Wait(15000 + (GetGameTimer() % 4000))
        while true do
            Wait(3000 + (GetGameTimer() % 1000))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _0xSK1 end

            if IsEntityVisible(_0xPD) == false and GetEntitySpeed(_0xPD) > 2.0 then
                _0xSE(_0xEV_DG, _S(_E._0x07))
            end

            ::_0xSK1::
        end
    end)

    -- ========== Noclip Detection ==========
    local _0xEV_DN = _0xK1(_S(_E._0x0C))
    local _0xNC_HITS = 0

    CreateThread(function()
        Wait(25000 + (GetGameTimer() % 5000))
        while true do
            Wait(2000 + (GetGameTimer() % 1500))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _0xSK2 end
            if GetEntityHealth(_0xPD) <= 0 then _0xNC_HITS = 0; goto _0xSK2 end
            if IsPedInAnyVehicle(_0xPD, false) then _0xNC_HITS = 0; goto _0xSK2 end
            if IsPedFalling(_0xPD) or IsPedRagdoll(_0xPD) then goto _0xSK2 end

            local _0xC1 = GetEntityCoords(_0xPD)

            -- underground check
            local _0xGZ = 0.0
            local _0xFG, _0xGH = GetGroundZFor_3dCoord(_0xC1.x, _0xC1.y, _0xC1.z + 2.0, false)
            if _0xFG then _0xGZ = _0xGH end

            if _0xFG and _0xC1.z < (_0xGZ - 3.0) and _0xC1.z > -50.0 then
                _0xNC_HITS = _0xNC_HITS + 1
                if _0xNC_HITS >= 3 then
                    _0xSE(_0xEV_DN, _S(_E._0x10))
                    _0xNC_HITS = 0
                end
            elseif not IsPedInAnyVehicle(_0xPD, false) and not IsPedFalling(_0xPD) then
                -- flying check (not in vehicle, not falling, high up with upward velocity)
                local _0xVZ = GetEntityVelocity(_0xPD).z
                if _0xC1.z > 100.0 and _0xVZ > 5.0 and not IsPedInParachuteFreeFall(_0xPD) and not GetIsTaskActive(_0xPD, 334) then
                    _0xNC_HITS = _0xNC_HITS + 1
                    if _0xNC_HITS >= 4 then
                        _0xSE(_0xEV_DN, _S(_E._0x11))
                        _0xNC_HITS = 0
                    end
                else
                    _0xNC_HITS = math.max(0, _0xNC_HITS - 1)
                end
            else
                _0xNC_HITS = math.max(0, _0xNC_HITS - 1)
            end

            ::_0xSK2::
        end
    end)

    -- ========== Health Snap Detection ==========
    local _0xEV_DH = _0xK1(_S(_E._0x0D))
    local _0xLH = 0
    local _0xLHT = 0

    CreateThread(function()
        Wait(15000)
        local _0xPD = PlayerPedId()
        _0xLH = GetEntityHealth(_0xPD)
        _0xLHT = GetGameTimer()

        while true do
            Wait(1000)
            _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _0xSK3 end

            local _0xCH = GetEntityHealth(_0xPD)
            local _0xNW = GetGameTimer()
            local _0xDT = _0xNW - _0xLHT

            -- instant full heal detection (gained >100 health in <500ms, not from respawn)
            if _0xCH > _0xLH and (_0xCH - _0xLH) > 100 and _0xDT < 500 and _0xLH > 100 then
                _0xSE(_0xEV_DH, _S(_E._0x12))
            end

            _0xLH = _0xCH
            _0xLHT = _0xNW

            ::_0xSK3::
        end
    end)

    -- ========== Weapon Injection Detection ==========
    local _0xEV_DW = _0xK1(_S(_E._0x0E))
    local _0xBW = _0xCF.BlacklistedWeapons or {}

    CreateThread(function()
        Wait(30000 + (GetGameTimer() % 5000))
        while true do
            Wait(10000 + (GetGameTimer() % 5000))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _0xSK4 end

            for _0xWH, _ in pairs(_0xBW) do
                if HasPedGotWeapon(_0xPD, _0xWH, false) then
                    RemoveWeaponFromPed(_0xPD, _0xWH)
                    _0xSE(_0xEV_DW, _f2('0x%X', _0xWH))
                    Wait(5000)
                end
            end

            ::_0xSK4::
        end
    end)

    -- ========== Anti-Executor Detection ==========
    local _0xEV_DA = _0xK1(_S(_E._0x0F))

    CreateThread(function()
        Wait(20000 + (GetGameTimer() % 8000))
        while true do
            Wait(15000 + (GetGameTimer() % 10000))

            local _0xSS = false
            local _0xDT = ''

            -- check common executor globals
            local _0xEG = {
                _sc(0x45, 0x78, 0x65, 0x63, 0x75, 0x74, 0x6F, 0x72),
                _sc(0x43, 0x68, 0x65, 0x61, 0x74, 0x45, 0x6E, 0x67, 0x69, 0x6E, 0x65),
                _sc(0x4C, 0x75, 0x61, 0x45, 0x78, 0x65, 0x63),
                _sc(0x53, 0x6B, 0x69, 0x64, 0x4D, 0x65, 0x6E, 0x75),
                _sc(0x45, 0x75, 0x6C, 0x65, 0x6E, 0x43, 0x68, 0x65, 0x61, 0x74),
            }

            for _, _0xG in ipairs(_0xEG) do
                if rawget(_G, _0xG) ~= nil then
                    _0xSS = true
                    _0xDT = _0xG
                    break
                end
            end

            if _0xSS then
                _0xSE(_0xEV_DA, _0xDT)
            end
        end
    end)

    -- ========== Anti-Tamper Self-Check ==========
    local _0xIT = _0xD3 ~ _0xD4
    CreateThread(function()
        Wait(30000)
        while true do
            Wait(60000 + (GetGameTimer() % 30000))
            local _0xV1 = _0xB2(_0xA1)
            local _0xV2 = _0xB2(_sc(76, 101, 110, 110, 111, 120))
            if _0xV1 ~= _0xD3 or _0xV2 ~= _0xD4 then
                _0xSE(_0xEV_DA, _S(_E._0x13))
            end
        end
    end)
end
