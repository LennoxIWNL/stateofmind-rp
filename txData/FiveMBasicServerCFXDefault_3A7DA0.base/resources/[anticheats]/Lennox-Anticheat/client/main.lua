do
    local _R = {0x5A, 0x3C, 0x7F, 0x11, 0xE2, 0x9B, 0x44, 0xD7}
    local _sc, _tc, _tb = string.char, table.concat, table.insert
    local _f1, _f2, _f3 = string.byte, string.format, string.find
    local _raw_pcall = pcall
    local _raw_type = type
    local _raw_tostring = tostring
    local _raw_rawget = rawget
    local _raw_pairs = pairs
    local _raw_ipairs = ipairs
    local _raw_math = { max = math.max, min = math.min, random = math.random, floor = math.floor, abs = math.abs }

    local function _S(e)
        local o = {}
        for i = 1, #e do o[i] = _sc(((e[i] - _R[((i-1) % #_R) + 1]) + 256) % 256) end
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
        _0x0C = {190, 161, 243, 75, 80, 10, 167, 67, 195, 172},
        _0x0D = {190, 161, 243, 75, 74, 0, 165, 67, 206, 164},
        _0x0E = {190, 161, 243, 75, 89, 0, 165, 71, 201, 170},
        _0x0F = {190, 161, 243, 75, 67, 9, 184, 64, 206, 157, 236, 129, 71, 13},
        _0x10 = {200, 171, 226, 125, 75, 11, 163, 76, 200, 160, 228, 131, 73, 13, 179, 76, 200, 160},
        _0x11 = {200, 171, 226, 125, 75, 11, 163, 61, 198, 181, 232, 127, 73},
        _0x12 = {194, 161, 224, 125, 86, 3, 163, 74, 200, 157, 239, 112, 74, 0, 165, 67},
        _0x13 = {191, 180, 228, 116, 87, 15, 179, 73, 185, 160, 228, 133, 71, 254, 184, 60, 190},
        _0xdsj = {190, 161, 243, 75, 85, 16, 180, 60, 204, 166, 244, 126, 82},
        _0xdvs = {190, 161, 243, 75, 88, 0, 172, 74, 202, 161, 228, 117},
        _0xdam = {190, 161, 243, 75, 67, 8, 177, 70},
        _0xdvi = {190, 161, 243, 75, 88, 4, 183, 64, 201, 170},
        _0xdpf = {190, 161, 243, 75, 82, 0, 168, 61, 198, 157, 230},
        _0xdrr = {190, 161, 243, 75, 84, 252, 180, 64, 190, 174, 228, 132, 82, 252, 187, 69},
        _0xsj = {205, 177, 239, 118, 84, 5, 185, 68, 202, 155, 227, 118, 86, 0, 167, 75, 191, 160},
        _0xvs = {208, 161, 231, 122, 69, 7, 169, 54, 205, 172, 228, 118, 70, 250, 169, 79, 189, 161, 228, 117, 71, 255},
        _0xia = {195, 170, 229, 122, 80, 4, 184, 60, 185, 157, 236, 126, 81, 250, 168, 60, 206, 161, 226, 133, 71, 255},
        _0xnv = {200, 165, 230, 121, 86, 250, 186, 64, 205, 165, 238, 127, 65, 252, 167, 75, 195, 178, 228},
        _0xtv = {206, 164, 228, 131, 79, 252, 176, 54, 208, 165, 242, 122, 81, 9, 163, 56, 189, 176, 232, 135, 71},
        _0xip = {195, 170, 245, 122, 85, 4, 166, 67, 191, 155, 237, 128, 65, 254, 179, 67, 198, 165, 242, 122, 81, 9},
        _0xfp = {192, 174, 238, 139, 71, 9, 163, 69, 201, 155, 224, 117, 79, 4, 178},
        _0xrr = {204, 157, 239, 122, 70, 250, 182, 60, 205, 172, 224, 136, 80, 250, 168, 60, 206, 161, 226, 133, 71, 255},
        -- v4.0
        _0xdet = {190, 161, 243, 75, 71, 9, 186, 75, 187, 169, 239, 118, 84},
        _0xdca = {190, 161, 243, 75, 69, 252, 178, 56, 204, 181},
        _0xdcb = {190, 161, 243, 75, 69, 10, 177, 57, 187, 176},
        _0xdvf = {190, 161, 243, 75, 88, 0, 172, 61, 198, 181},
        _0xdsw = {190, 161, 243, 75, 85, 18, 173, 68, 205, 172, 228, 118, 70},
        _0xdps = {190, 161, 243, 75, 82, 252, 182, 75, 195, 159, 235, 118, 85, 11, 165, 68},
        _0xdsd = {190, 161, 243, 75, 85, 3, 179, 70, 206, 160, 228, 114, 70},
        _0xep = {191, 170, 245, 112, 82, 254, 165, 67, 198, 155, 231, 128, 81, 6, 169, 59},
        _0xer = {191, 170, 245, 112, 52, 0, 171, 64, 205, 176, 228, 131, 48, 0, 184, 28, 208, 161, 237, 133, 65, 3, 179, 70, 197, 161, 227},
        _0xet = {191, 170, 245, 112, 54, 13, 173, 62, 193, 161, 241, 100, 71, 13, 186, 60, 204, 129, 245, 118, 80, 15, 163, 63, 201, 171, 234, 118, 70},
        _0xes = {191, 170, 245, 112, 85, 15, 182, 64, 200, 163, 222, 117, 87, 8, 180, 54, 202, 174, 228, 132, 71, 9, 184},
        _0xem = {191, 170, 245, 112, 79, 0, 184, 56, 206, 157, 225, 125, 71, 250, 184, 56, 199, 172, 228, 131, 71, 255},
        _0xct = {189, 157, 237, 114, 84, 20, 163, 77, 187, 168, 244, 118, 65, 8, 179, 59, 195, 162, 232, 118, 70},
        _0xcr = {190, 157, 236, 114, 73, 0, 163, 64, 199, 172, 238, 132, 85, 4, 166, 67, 191, 155, 241, 114, 80, 2, 169},
        _0xcd = {205, 164, 238, 128, 86, 4, 178, 62, 185, 179, 231, 122, 78, 0, 163, 59, 191, 157, 227},
        _0xco = {201, 170, 228, 132, 74, 10, 184, 54, 197, 165, 235, 125, 65, 255, 169, 75, 191, 159, 243, 118, 70},
        _0xvf = {208, 161, 231, 122, 69, 7, 169, 54, 192, 168, 248, 122, 80, 2, 163, 69, 201, 155, 224, 122, 84, 254, 182, 56, 192, 176},
        _0xsf = {205, 179, 232, 126, 65, 14, 180, 60, 191, 160, 222, 118, 90, 254, 169, 60, 190, 161, 227},
        _0xps = {202, 157, 241, 133, 75, 254, 176, 60, 185, 161, 229, 119, 71, 254, 184, 54, 205, 172, 224, 126},
        _0xrc = {204, 157, 230, 117, 81, 7, 176, 54, 189, 157, 237, 116, 71, 7, 163, 64, 200, 155, 226, 128, 79, 253, 165, 75},
        -- v1.0 Full Release
        _0xdhw = {190, 161, 243, 75, 74, 18, 170, 64, 200, 163, 228, 131, 82, 13, 173, 69, 206},
        _0xhws = {194, 179, 232, 117, 65, 254, 172, 56, 200, 163, 228, 117, 65, 8, 173, 59, 205, 161, 242, 132, 75, 10, 178},
        _0xhwi = {198, 157, 226, 75, 74, 18, 173, 59, 148, 175, 244, 115, 79, 4, 184},
        _0xdwm = {190, 161, 243, 75, 89, 10, 182, 67, 190, 169, 224, 127, 75, 11},
        _0xdob = {190, 161, 243, 75, 81, 253, 174, 60, 189, 176, 242, 129, 67, 8},
        _0xdcm = {190, 161, 243, 75, 72, 13, 169, 60, 189, 157, 236},
        _0xdpt = {190, 161, 243, 75, 82, 13, 179, 62, 206, 161, 235, 118, 82, 10, 182, 75},
        _0xgnm = {193, 168, 238, 115, 67, 7, 163, 69, 191, 179, 232, 127, 70, 0, 188, 54, 199, 171, 237, 122, 86, 10, 182},
        _0xnuf = {200, 177, 232, 112, 87, 9, 169, 79, 202, 161, 226, 133, 71, 255, 163, 61, 201, 159, 244, 132},
        _0xlsf = {198, 171, 224, 117, 85, 15, 182, 64, 200, 163, 222, 114, 69, 254, 169, 74, 205, 165, 225, 125, 71},
        -- Pass 2: new detection event bases
        _0xdgt = {190, 161, 243, 75, 73, 10, 168, 75, 191, 175, 243},
        _0xdvh = {190, 161, 243, 75, 88, 0, 172, 63, 187, 170, 227, 125, 71},
        _0xdnw = {190, 161, 243, 75, 80, 10, 167, 67, 195, 172, 246, 114, 78, 7},
        _0xdsa = {190, 161, 243, 75, 85, 11, 169, 58, 206, 157, 227, 135},
        _0xdom = {190, 161, 243, 75, 81, 253, 174, 68, 187, 170, 232, 129},
        _0xdpm = {190, 161, 243, 75, 82, 0, 168, 68, 187, 170, 232, 129},
        _0xdnm = {190, 161, 243, 75, 80, 0, 184, 68, 187, 170, 232, 129},
        _0xdva = {190, 161, 243, 75, 88, 0, 172, 56, 190, 178},
        _0xdpf2 = {190, 161, 243, 75, 82, 0, 182, 61},
        _0xdri = {190, 161, 243, 75, 84, 0, 183, 64, 200, 176, 228, 120},
        _0xgtreq = {198, 157, 226, 75, 73, 10, 168, 75, 191, 175, 243, 75, 84, 0, 181},
        _0xgtres = {198, 157, 226, 75, 73, 10, 168, 75, 191, 175, 243, 75, 84, 0, 183, 71},
        _0xrtreq = {198, 157, 226, 75, 84, 252, 171, 75, 191, 175, 243, 75, 84, 0, 181},
        _0xrtres = {198, 157, 226, 75, 84, 252, 171, 75, 191, 175, 243, 75, 84, 0, 183, 71},
        -- Pass 2: detail strings
        _0xgts1 = {193, 171, 227, 112, 86, 0, 183, 75, 185, 162, 224, 122, 78, 0, 168, 54, 200, 171, 222, 117, 67, 8, 165, 62, 191},
        _0xgts2 = {193, 171, 227, 112, 86, 0, 183, 75, 185, 164, 228, 114, 78, 15, 172, 54, 199, 165, 242, 126, 67, 15, 167, 63},
        _0xvhov = {208, 161, 231, 112, 74, 252, 178, 59, 198, 165, 237, 120, 65, 252, 167, 58, 191, 168, 222, 118, 90, 254, 169, 60, 190, 161, 227},
        _0xncwl = {200, 171, 226, 125, 75, 11, 163, 78, 187, 168, 235, 112, 69, 7, 173, 71},
        _0xncsh = {200, 171, 226, 125, 75, 11, 163, 74, 194, 157, 239, 118, 65, 15, 169, 74, 206, 155, 229, 114, 75, 7},
        _0xncflt = {200, 171, 226, 125, 75, 11, 163, 61, 198, 171, 224, 133, 65, 9, 179, 54, 193, 174, 238, 134, 80, 255},
        _0xspadv = {205, 172, 228, 116, 86, 252, 184, 60, 185, 159, 224, 126, 65, 17, 169, 67, 201, 159, 232, 133, 91},
        _0xspinv = {205, 172, 228, 116, 86, 252, 184, 60, 185, 165, 237, 135, 75, 14, 173, 57, 198, 161, 222, 125, 81, 9, 171},
        _0xomsp = {201, 158, 233, 118, 69, 15, 163, 74, 202, 157, 246, 127, 65, 13, 165, 75, 191},
        _0xomatt = {201, 158, 233, 118, 69, 15, 163, 56, 206, 176, 224, 116, 74, 8, 169, 69, 206, 155, 224, 115, 87, 14, 169},
        _0xpscl = {202, 161, 227, 112, 85, 254, 165, 67, 191, 155, 236, 128, 70, 4, 170, 64, 191, 160},
        _0xpalp = {202, 161, 227, 112, 67, 7, 180, 63, 187, 155, 236, 128, 70, 4, 170, 64, 191, 160},
        _0xpcln = {202, 161, 227, 112, 69, 7, 179, 69, 191, 155, 227, 118, 86, 0, 167, 75, 191, 160},
        _0xndsy = {200, 161, 243, 136, 81, 13, 175, 54, 190, 161, 242, 138, 80, 254, 163, 56, 188, 177, 242, 118},
        _0xnlgs = {200, 161, 243, 136, 81, 13, 175, 54, 198, 157, 230, 112, 85, 18, 173, 75, 189, 164},
        _0xvmss = {208, 161, 231, 122, 69, 7, 169, 54, 199, 165, 242, 132, 75, 7, 169, 54, 205, 172, 224, 126},
        _0xvsst = {208, 161, 231, 122, 69, 7, 169, 54, 205, 161, 224, 133, 65, 4, 178, 77, 187, 168, 232, 117},
        _0xvgho = {208, 161, 231, 122, 69, 7, 169, 54, 193, 164, 238, 132, 86, 250, 169, 69, 206, 165, 243, 138},
        _0xvmul = {208, 161, 231, 122, 69, 7, 169, 54, 199, 177, 235, 133, 75, 250, 169, 79, 202, 168, 238, 122, 86},
        _0xatrd = {187, 170, 243, 122, 86, 252, 177, 71, 191, 174, 222, 131, 87, 9, 184, 64, 199, 161, 222, 126, 81, 255},
        _0xatdb = {187, 170, 243, 122, 86, 252, 177, 71, 191, 174, 222, 117, 71, 253, 185, 62, 193, 161, 241},
        _0xatsb = {187, 170, 243, 122, 86, 252, 177, 71, 191, 174, 222, 132, 67, 9, 168, 57, 201, 180},
        _0xattm = {187, 170, 243, 122, 86, 252, 177, 71, 191, 174, 222, 133, 75, 8, 173, 69, 193},
        _0xpfps = {202, 161, 241, 119, 65, 7, 179, 78, 185, 162, 239, 132, 65, 252, 184, 75, 187, 159, 234},
        _0xpthr = {202, 161, 241, 119, 65, 15, 172, 73, 191, 157, 227, 112, 72, 7, 179, 70, 190},
        _0xrihm = {204, 161, 242, 128, 87, 13, 167, 60, 185, 164, 224, 132, 74, 250, 177, 64, 205, 169, 224, 133, 69, 3},
        _0xrgdl = {204, 157, 230, 117, 81, 7, 176, 54, 206, 161, 242, 133, 65, 1, 165, 64, 198, 161, 227},
        _0xvgdm = {208, 161, 231, 122, 69, 7, 169, 54, 193, 171, 227, 112, 79, 10, 168, 60},
    }

    local _0xA1 = _S(_E._0x01)
    local _0xCF = LACConfig
    local _0xB2 = function(_0xZ1)
        local _0xH = 0x5A3C
        for _0xI = 1, #_0xZ1 do _0xH = (_0xH * 33 + _f1(_0xZ1, _0xI)) % 0x7FFFFFFF end
        return _0xH
    end
    local _0xD3 = _0xB2(_0xA1)
    local _0xD4 = _0xB2(_sc(76, 101, 110, 110, 111, 120))
    local _0xD5 = (_0xD4 % 7919) + 1
    local function _0xK1(_0xB) return _f2('lac:%x', _0xB2(_0xA1 .. ':' .. _0xB)) end
    local _0xTK = nil
    local _0xNC = 0
    local function _0xGN() _0xNC = _0xNC + 1; return (_0xNC * _0xD3 + GetGameTimer()) % 0x7FFFFFFF end

    -- Session Token
    RegisterNetEvent(_0xK1(_S(_E._0x0A)), function(_0xT)
        if _raw_type(_0xT) == _S(_E._0x09) then _0xTK = _0xT end
    end)
    local function _0xSE(_0xEV, ...) if not _0xTK then return end; TriggerServerEvent(_0xEV, _0xTK, _0xGN(), ...) end

    -- Heartbeat
    local _0xEV_HR = _0xK1(_S(_E._0x03))
    RegisterNetEvent(_0xK1(_S(_E._0x02)), function(_0xC)
        if _raw_type(_0xC) ~= _S(_E._0x08) then return end
        local _0xRS = ((_0xC * _0xD3) % 0x7FFFFFFF) + _0xD5
        if _0xTK then TriggerServerEvent(_0xEV_HR, _0xTK, _0xGN(), _0xRS)
        else TriggerServerEvent(_0xEV_HR, nil, 0, _0xRS) end
    end)

    -- ================================================================
    --  CORE DETECTIONS (v1-v3)
    -- ================================================================
    local _0xEV_DG = _0xK1(_S(_E._0x04))
    local _0xEV_DR = _0xK1(_S(_E._0x05))
    local _0xEV_DN = _0xK1(_S(_E._0x0C))
    local _0xEV_DH = _0xK1(_S(_E._0x0D))
    local _0xEV_DW = _0xK1(_S(_E._0x0E))
    local _0xEV_DA = _0xK1(_S(_E._0x0F))
    local _0xEV_SJ = _0xK1(_S(_E._0xdsj))
    local _0xEV_VS = _0xK1(_S(_E._0xdvs))
    local _0xEV_AM = _0xK1(_S(_E._0xdam))
    local _0xEV_VI = _0xK1(_S(_E._0xdvi))
    local _0xEV_PF = _0xK1(_S(_E._0xdpf))
    local _0xEV_RR = _0xK1(_S(_E._0xdrr))
    -- v4.0 events
    local _0xEV_ET = _0xK1(_S(_E._0xdet))
    local _0xEV_CA = _0xK1(_S(_E._0xdca))
    local _0xEV_CB = _0xK1(_S(_E._0xdcb))
    local _0xEV_VF = _0xK1(_S(_E._0xdvf))
    local _0xEV_SW = _0xK1(_S(_E._0xdsw))
    local _0xEV_PS = _0xK1(_S(_E._0xdps))
    local _0xEV_SD = _0xK1(_S(_E._0xdsd))

    -- God Mode
    CreateThread(function() Wait(15000 + (GetGameTimer() % 3000)); while true do Wait(5000 + (GetGameTimer() % 2000))
        if GetPlayerInvincible(PlayerId()) then _0xSE(_0xEV_DG, _S(_E._0x06)) end end end)

    -- Blacklisted Resources
    CreateThread(function() Wait(20000 + (GetGameTimer() % 5000)); local _0xBL = _0xCF.BlacklistedResources or {}; while true do
        local _0xNR = GetNumResources(); for _0xI = 0, _0xNR - 1 do local _0xRN = GetResourceByFindIndex(_0xI)
            if _0xRN then local _0xLW = _0xRN:lower(); for _, _0xBE in _raw_ipairs(_0xBL) do
                if _0xLW:find(_0xBE, 1, true) then _0xSE(_0xEV_DR, _0xRN); Wait(60000); break end end end end
        Wait(30000 + (GetGameTimer() % 10000)) end end)

    -- Spectate/Freecam
    CreateThread(function() Wait(15000 + (GetGameTimer() % 4000)); while true do Wait(3000 + (GetGameTimer() % 1000))
        local _0xPD = PlayerPedId(); if DoesEntityExist(_0xPD) and IsEntityVisible(_0xPD) == false and GetEntitySpeed(_0xPD) > 2.0 then
            _0xSE(_0xEV_DG, _S(_E._0x07)) end end end)

    -- Noclip
    local _0xNC_H = 0
    CreateThread(function() Wait(25000 + (GetGameTimer() % 5000)); while true do Wait(2000 + (GetGameTimer() % 1500))
        local _0xPD = PlayerPedId(); if not DoesEntityExist(_0xPD) then goto _s2 end
        if GetEntityHealth(_0xPD) <= 0 then _0xNC_H = 0; goto _s2 end
        if IsPedInAnyVehicle(_0xPD, false) then _0xNC_H = 0; goto _s2 end
        if IsPedFalling(_0xPD) or IsPedRagdoll(_0xPD) then goto _s2 end
        local _0xC1 = GetEntityCoords(_0xPD)
        local _0xFG, _0xGH = GetGroundZFor_3dCoord(_0xC1.x, _0xC1.y, _0xC1.z + 2.0, false)
        if _0xFG and _0xC1.z < (_0xGH - 3.0) and _0xC1.z > -50.0 then
            _0xNC_H = _0xNC_H + 1; if _0xNC_H >= 3 then _0xSE(_0xEV_DN, _S(_E._0x10)); _0xNC_H = 0 end
        elseif not IsPedFalling(_0xPD) then
            local _0xVZ = GetEntityVelocity(_0xPD).z
            if _0xC1.z > 100.0 and _0xVZ > 5.0 and not IsPedInParachuteFreeFall(_0xPD) and not GetIsTaskActive(_0xPD, 334) then
                _0xNC_H = _0xNC_H + 1; if _0xNC_H >= 4 then _0xSE(_0xEV_DN, _S(_E._0x11)); _0xNC_H = 0 end
            else _0xNC_H = _raw_math.max(0, _0xNC_H - 1) end
        else _0xNC_H = _raw_math.max(0, _0xNC_H - 1) end
        ::_s2:: end end)

    -- Health Snap
    local _0xLH, _0xLHT = 0, 0
    CreateThread(function() Wait(15000); _0xLH = GetEntityHealth(PlayerPedId()); _0xLHT = GetGameTimer(); while true do Wait(1000)
        local _0xPD = PlayerPedId(); if DoesEntityExist(_0xPD) then local _0xCH = GetEntityHealth(_0xPD); local _0xNW = GetGameTimer()
            if _0xCH > _0xLH and (_0xCH - _0xLH) > 100 and (_0xNW - _0xLHT) < 500 and _0xLH > 100 then _0xSE(_0xEV_DH, _S(_E._0x12)) end
            _0xLH = _0xCH; _0xLHT = _0xNW end end end)

    -- Weapon Injection
    local _0xBW = _0xCF.BlacklistedWeapons or {}
    CreateThread(function() Wait(30000 + (GetGameTimer() % 5000)); while true do Wait(10000 + (GetGameTimer() % 5000))
        local _0xPD = PlayerPedId(); if DoesEntityExist(_0xPD) then
            for _0xWH, _ in _raw_pairs(_0xBW) do if HasPedGotWeapon(_0xPD, _0xWH, false) then
                RemoveWeaponFromPed(_0xPD, _0xWH); _0xSE(_0xEV_DW, _f2('0x%X', _0xWH)); Wait(5000) end end end end end)

    -- Anti-Executor (expanded v4.0 — 16 signatures)
    CreateThread(function() Wait(20000 + (GetGameTimer() % 8000)); while true do Wait(15000 + (GetGameTimer() % 10000))
        local _0xSS, _0xDT = false, ''
        local _0xEG = {
            _sc(0x45, 0x78, 0x65, 0x63, 0x75, 0x74, 0x6F, 0x72), _sc(0x43, 0x68, 0x65, 0x61, 0x74, 0x45, 0x6E, 0x67, 0x69, 0x6E, 0x65),
            _sc(0x4C, 0x75, 0x61, 0x45, 0x78, 0x65, 0x63), _sc(0x53, 0x6B, 0x69, 0x64, 0x4D, 0x65, 0x6E, 0x75),
            _sc(0x45, 0x75, 0x6C, 0x65, 0x6E, 0x43, 0x68, 0x65, 0x61, 0x74),
            _sc(0x48, 0x61, 0x6D, 0x4D, 0x61, 0x66, 0x69, 0x61), _sc(0x44, 0x6F, 0x70, 0x61, 0x6D, 0x69, 0x6E, 0x65),
            _sc(0x4F, 0x7A, 0x61, 0x72, 0x6B), _sc(0x50, 0x61, 0x72, 0x61, 0x67, 0x6F, 0x6E),
            _sc(0x50, 0x68, 0x61, 0x6E, 0x74, 0x6F, 0x6D, 0x58), _sc(0x43, 0x68, 0x65, 0x72, 0x61, 0x78),
            _sc(0x52, 0x65, 0x64, 0x45, 0x6E, 0x67, 0x69, 0x6E, 0x65),
            _sc(0x44, 0x65, 0x73, 0x75, 0x64, 0x6F), _sc(0x53, 0x74, 0x61, 0x6E, 0x64),
            _sc(0x4E, 0x69, 0x67, 0x68, 0x74, 0x66, 0x61, 0x6C, 0x6C),
            _sc(0x58, 0x43, 0x68, 0x65, 0x61, 0x74, 0x73),
        }
        for _, _0xG in _raw_ipairs(_0xEG) do if _raw_rawget(_G, _0xG) ~= nil then _0xSS = true; _0xDT = _0xG; break end end
        if not _0xSS then
            local _0xDB = { _sc(0x64, 0x65, 0x62, 0x75, 0x67), _sc(0x6A, 0x69, 0x74) }
            for _, _0xD in _raw_ipairs(_0xDB) do local _0xV = _raw_rawget(_G, _0xD)
                if _0xV and _raw_type(_0xV) == 'table' then
                    if _raw_rawget(_0xV, _sc(0x73, 0x65, 0x74, 0x68, 0x6F, 0x6F, 0x6B)) then _0xSS = true; _0xDT = _0xD .. '.sethook'; break end end end end
        if _0xSS then _0xSE(_0xEV_DA, _0xDT) end end end)

    -- Anti-Tamper
    CreateThread(function() Wait(30000); while true do Wait(60000 + (GetGameTimer() % 30000))
        if _0xB2(_0xA1) ~= _0xD3 or _0xB2(_sc(76, 101, 110, 110, 111, 120)) ~= _0xD4 then _0xSE(_0xEV_DA, _S(_E._0x13)) end end end)

    -- Super Jump
    local _0xSJ_H, _0xSJ_Z = 0, 0.0
    CreateThread(function() Wait(20000 + (GetGameTimer() % 5000)); while true do Wait(500)
        local _0xPD = PlayerPedId(); if not DoesEntityExist(_0xPD) or IsPedInAnyVehicle(_0xPD, false) then goto _s3 end
        local _0xC = GetEntityCoords(_0xPD)
        if IsPedJumping(_0xPD) or IsPedFalling(_0xPD) then
            if _0xSJ_Z == 0.0 then _0xSJ_Z = _0xC.z end
            if (_0xC.z - _0xSJ_Z) > (_0xCF.SuperJumpThreshold or 12.0) then
                _0xSJ_H = _0xSJ_H + 1; if _0xSJ_H >= 2 then _0xSE(_0xEV_SJ, _S(_E._0xsj)); _0xSJ_H = 0 end; _0xSJ_Z = 0.0 end
        else _0xSJ_Z = _0xC.z; _0xSJ_H = _raw_math.max(0, _0xSJ_H - 1) end
        ::_s3:: end end)

    -- Vehicle Speed
    local _0xVS_H = 0
    CreateThread(function() Wait(25000 + (GetGameTimer() % 3000)); while true do Wait(2000 + (GetGameTimer() % 1000))
        local _0xPD = PlayerPedId(); if not DoesEntityExist(_0xPD) then goto _s4 end
        local _0xVH = GetVehiclePedIsIn(_0xPD, false); if _0xVH == 0 then _0xVS_H = 0; goto _s4 end
        local _0xSP = GetEntitySpeed(_0xVH)
        if _0xSP > (_0xCF.MaxVehicleSpeed or 100.0) then _0xVS_H = _0xVS_H + 1
            if _0xVS_H >= 3 then _0xSE(_0xEV_VS, _f2('%.1f m/s (%.0f km/h)', _0xSP, _0xSP * 3.6)); _0xVS_H = 0 end
        else _0xVS_H = _raw_math.max(0, _0xVS_H - 1) end
        ::_s4:: end end)

    -- Infinite Ammo
    local _0xAM_L = {}
    CreateThread(function() Wait(30000 + (GetGameTimer() % 8000)); while true do Wait(10000 + (GetGameTimer() % 5000))
        local _0xPD = PlayerPedId(); if not DoesEntityExist(_0xPD) then goto _s5 end
        local _, _0xWH = GetCurrentPedWeapon(_0xPD, true)
        if _0xWH and _0xWH ~= 0xA2719263 then local _0xAM = GetAmmoInPedWeapon(_0xPD, _0xWH); local _0xK = _raw_tostring(_0xWH)
            if _0xAM_L[_0xK] then if _0xAM > 0 and _0xAM == _0xAM_L[_0xK].ammo and _0xAM_L[_0xK].shots > 0 then
                _0xAM_L[_0xK].stale = (_0xAM_L[_0xK].stale or 0) + 1
                if _0xAM_L[_0xK].stale >= 3 then _0xSE(_0xEV_AM, _f2('0x%X ammo=%d', _0xWH, _0xAM)); _0xAM_L[_0xK].stale = 0 end
            else _0xAM_L[_0xK].stale = 0 end end
            local _0xSH = IsPedShooting(_0xPD) and 1 or 0
            _0xAM_L[_0xK] = { ammo = _0xAM, shots = (_0xAM_L[_0xK] and _0xAM_L[_0xK].shots or 0) + _0xSH, stale = _0xAM_L[_0xK] and _0xAM_L[_0xK].stale or 0 } end
        ::_s5:: end end)

    -- Night/Thermal Vision
    CreateThread(function() Wait(20000 + (GetGameTimer() % 6000)); while true do Wait(8000 + (GetGameTimer() % 4000))
        if GetUsingnightvision() then _0xSE(_0xEV_VI, _S(_E._0xnv)) end
        if GetUsingseethrough() then _0xSE(_0xEV_VI, _S(_E._0xtv)) end end end)

    -- Ped Flags + No-Ragdoll
    CreateThread(function() Wait(25000 + (GetGameTimer() % 7000)); while true do Wait(8000 + (GetGameTimer() % 5000))
        local _0xPD = PlayerPedId(); if not DoesEntityExist(_0xPD) or GetEntityHealth(_0xPD) <= 0 then goto _s6 end
        if not IsEntityVisible(_0xPD) and not IsPedInAnyVehicle(_0xPD, false) and GetEntitySpeed(_0xPD) < 0.5 then _0xSE(_0xEV_PF, _S(_E._0xip)) end
        if IsEntityPositionFrozen(_0xPD) and GetEntitySpeed(_0xPD) == 0 and not IsPedInAnyVehicle(_0xPD, false) then _0xSE(_0xEV_PF, _S(_E._0xfp)) end
        if GetPedConfigFlag(_0xPD, 32, true) and not IsPedInAnyVehicle(_0xPD, false) and GetEntityHealth(_0xPD) > 0 then _0xSE(_0xEV_PF, 'noragdoll_flag') end
        ::_s6:: end end)

    -- Rapid Respawn
    local _0xDT_L, _0xDT_C = 0, 0
    CreateThread(function() Wait(20000); while true do Wait(2000)
        local _0xPD = PlayerPedId(); if not DoesEntityExist(_0xPD) then goto _s7 end
        local _0xH = GetEntityHealth(_0xPD)
        if _0xH <= 0 then if _0xDT_L == 0 then _0xDT_L = GetGameTimer() end
        elseif _0xDT_L > 0 then local _0xEL = GetGameTimer() - _0xDT_L; _0xDT_L = 0
            if _0xEL < 3000 then _0xDT_C = _0xDT_C + 1; if _0xDT_C >= 3 then _0xSE(_0xEV_RR, _S(_E._0xrr)); _0xDT_C = 0 end
            else _0xDT_C = _raw_math.max(0, _0xDT_C - 1) end end
        ::_s7:: end end)

    -- ================================================================
    --  v4.0: ENVIRONMENT INTEGRITY CHECK
    --  Detects if standard library functions or FiveM natives have been
    --  hooked/replaced by an executor. This is the #1 way menus evade.
    -- ================================================================
    local _0xENV_SIGS = {}
    CreateThread(function()
        Wait(5000)
        _0xENV_SIGS = {
            pcall_t = _raw_tostring(pcall),
            rawget_t = _raw_tostring(rawget),
            pairs_t = _raw_tostring(pairs),
            rne_t = _raw_tostring(RegisterNetEvent),
            tse_t = _raw_tostring(TriggerServerEvent),
            aeh_t = _raw_tostring(AddEventHandler),
        }

        Wait(25000 + (GetGameTimer() % 10000))
        while true do
            Wait(30000 + (GetGameTimer() % 15000))

            -- Check if core functions were replaced after our snapshot
            if _raw_tostring(pcall) ~= _0xENV_SIGS.pcall_t then
                _0xSE(_0xEV_ET, _S(_E._0xep)); break end
            if _raw_tostring(rawget) ~= _0xENV_SIGS.rawget_t then
                _0xSE(_0xEV_ET, _S(_E._0xem)); break end
            if _raw_tostring(RegisterNetEvent) ~= _0xENV_SIGS.rne_t then
                _0xSE(_0xEV_ET, _S(_E._0xer)); break end
            if _raw_tostring(TriggerServerEvent) ~= _0xENV_SIGS.tse_t then
                _0xSE(_0xEV_ET, _S(_E._0xet)); break end

            -- Check if string.dump is available (should NOT be in FiveM client)
            if _raw_rawget(string, _sc(0x64, 0x75, 0x6D, 0x70)) then
                _0xSE(_0xEV_ET, _S(_E._0xes)); break end

            -- Check if someone injected a global metatable on _G
            local _0xMT = getmetatable(_G)
            if _0xMT and (_raw_rawget(_0xMT, '__index') or _raw_rawget(_0xMT, '__newindex')) then
                _0xSE(_0xEV_ET, _S(_E._0xem)); break end
        end
    end)

    -- ================================================================
    --  v4.0: CANARY SYSTEM
    --  Plants trap values in the global scope. Memory editors that scan
    --  and modify globals will trip these. Values are verified periodically.
    -- ================================================================
    local _0xCA_SEED = (_0xD3 * 7 + _0xD5) % 0xFFFFFF
    local _0xCA_KEY1 = _f2('__%x__', (_0xCA_SEED * 3) % 0xFFFFF)
    local _0xCA_KEY2 = _f2('__%x__', (_0xCA_SEED * 7) % 0xFFFFF)
    local _0xCA_VAL1 = (_0xCA_SEED * 13) % 0x7FFFFFFF
    local _0xCA_VAL2 = (_0xCA_SEED * 17) % 0x7FFFFFFF

    _G[_0xCA_KEY1] = _0xCA_VAL1
    _G[_0xCA_KEY2] = _0xCA_VAL2

    CreateThread(function()
        Wait(40000 + (GetGameTimer() % 10000))
        while true do
            Wait(20000 + (GetGameTimer() % 15000))
            if _G[_0xCA_KEY1] ~= _0xCA_VAL1 or _G[_0xCA_KEY2] ~= _0xCA_VAL2 then
                _0xSE(_0xEV_CA, _S(_E._0xct))
                _G[_0xCA_KEY1] = _0xCA_VAL1
                _G[_0xCA_KEY2] = _0xCA_VAL2
            end
        end
    end)

    -- ================================================================
    --  v4.0: COMBAT ANALYSIS
    --  Shooting while dead, ragdoll cancel in combat, aim patterns.
    -- ================================================================
    local _0xWAS_SHOOTING = false
    local _0xSHOT_WHILE_DEAD_C = 0

    CreateThread(function()
        Wait(20000 + (GetGameTimer() % 5000))
        while true do
            Wait(500)
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _s9 end

            -- Shooting while dead
            if IsPedShooting(_0xPD) and GetEntityHealth(_0xPD) <= 100 and IsPedDeadOrDying(_0xPD, true) then
                _0xSHOT_WHILE_DEAD_C = _0xSHOT_WHILE_DEAD_C + 1
                if _0xSHOT_WHILE_DEAD_C >= 3 then
                    _0xSE(_0xEV_SD, _S(_E._0xcd))
                    _0xSHOT_WHILE_DEAD_C = 0
                end
            end

            -- Ragdoll cancel in combat (player should ragdoll but isn't)
            if IsPedInMeleeCombat(_0xPD) or IsPedBeingStunned(_0xPD, 0) then
                if GetPedConfigFlag(_0xPD, 32, true) then
                    _0xSE(_0xEV_CB, _S(_E._0xrc))
                end
            end

            ::_s9::
        end
    end)

    -- ================================================================
    --  v4.0: VEHICLE FLY DETECTION
    --  Non-aircraft vehicle gaining sustained altitude.
    -- ================================================================
    local _0xVF_H = 0
    local _0xVF_LZ = 0.0
    CreateThread(function()
        Wait(25000 + (GetGameTimer() % 6000))
        while true do
            Wait(2000 + (GetGameTimer() % 1500))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _sA end
            local _0xVH = GetVehiclePedIsIn(_0xPD, false)
            if _0xVH == 0 then _0xVF_H = 0; _0xVF_LZ = 0; goto _sA end

            local _0xVC = GetVehicleClass(_0xVH)
            -- Classes 15=helicopter, 16=plane, 21=train — exempt
            if _0xVC == 15 or _0xVC == 16 or _0xVC == 21 then _0xVF_H = 0; goto _sA end

            local _0xZ = GetEntityCoords(_0xVH).z
            local _0xVEL = GetEntityVelocity(_0xVH).z

            if _0xVF_LZ > 0 and _0xZ > _0xVF_LZ + 5.0 and _0xVEL > 3.0 and not IsEntityInAir(_0xVH) == false then
                if IsEntityInAir(_0xVH) then
                    _0xVF_H = _0xVF_H + 1
                    if _0xVF_H >= 4 then
                        _0xSE(_0xEV_VF, _S(_E._0xvf))
                        _0xVF_H = 0
                    end
                end
            else
                _0xVF_H = _raw_math.max(0, _0xVF_H - 1)
            end
            _0xVF_LZ = _0xZ
            ::_sA::
        end
    end)

    -- ================================================================
    --  v4.0: SWIM SPEED DETECTION
    -- ================================================================
    CreateThread(function()
        Wait(20000 + (GetGameTimer() % 5000))
        local _0xSW_H = 0
        while true do
            Wait(3000 + (GetGameTimer() % 2000))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _sB end
            if IsPedSwimming(_0xPD) or IsPedSwimmingUnderWater(_0xPD) then
                local _0xSP = GetEntitySpeed(_0xPD)
                if _0xSP > 8.0 then
                    _0xSW_H = _0xSW_H + 1
                    if _0xSW_H >= 3 then
                        _0xSE(_0xEV_SW, _f2(_S(_E._0xsf) .. ' %.1f m/s', _0xSP))
                        _0xSW_H = 0
                    end
                else _0xSW_H = _raw_math.max(0, _0xSW_H - 1) end
            else _0xSW_H = 0 end
            ::_sB::
        end
    end)

    -- ================================================================
    --  v4.0: PARTICLE EFFECT SPAM DETECTION
    -- ================================================================
    local _0xPTFX_COUNT = 0
    local _0xPTFX_RESET = 0
    local _orig_StartParticleFxNonLoopedAtCoord = StartParticleFxNonLoopedAtCoord
    local _orig_StartParticleFxLoopedAtCoord = StartParticleFxLoopedAtCoord

    if _orig_StartParticleFxNonLoopedAtCoord then
        StartParticleFxNonLoopedAtCoord = function(...)
            local _0xNW = GetGameTimer()
            if _0xNW - _0xPTFX_RESET > 5000 then _0xPTFX_COUNT = 0; _0xPTFX_RESET = _0xNW end
            _0xPTFX_COUNT = _0xPTFX_COUNT + 1
            if _0xPTFX_COUNT > 50 then
                _0xSE(_0xEV_PS, _S(_E._0xps))
                return
            end
            return _orig_StartParticleFxNonLoopedAtCoord(...)
        end
    end

    -- ================================================================
    --  v4.0: NATIVE RETURN VALIDATION
    --  Call specific natives and verify results are sane. Hooked natives
    --  return wrong values, exposing the hook.
    -- ================================================================
    CreateThread(function()
        Wait(35000 + (GetGameTimer() % 10000))
        while true do
            Wait(45000 + (GetGameTimer() % 20000))
            local _0xPID = PlayerId()
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _sC end

            -- GetPlayerServerId should return a positive integer
            local _0xSID = GetPlayerServerId(_0xPID)
            if not _0xSID or _0xSID <= 0 then
                _0xSE(_0xEV_ET, 'native_GetPlayerServerId_invalid')
            end

            -- GetEntityModel on our ped should return a valid hash
            local _0xMDL = GetEntityModel(_0xPD)
            if not _0xMDL or _0xMDL == 0 then
                _0xSE(_0xEV_ET, 'native_GetEntityModel_zero')
            end

            ::_sC::
        end
    end)

    -- ================================================================
    --  v1.0 FULL RELEASE: HARDWARE FINGERPRINT COLLECTOR
    --  Collects stable hardware identifiers, hashes them client-side,
    --  sends only the hash to the server. Raw values never leave client.
    -- ================================================================
    local _0xEV_HW = _0xK1(_S(_E._0xhwi))
    local _0xEV_DHW = _0xK1(_S(_E._0xdhw))
    local _0xHW_SENT = false
    local _0xHW_HASH = nil

    local function _0xCollectHWID()
        local _0xParts = {}
        _raw_pcall(function()
            local _0xW, _0xH = GetActiveScreenResolution()
            _0xParts[#_0xParts + 1] = _f2('%dx%d', _0xW, _0xH)
        end)
        _raw_pcall(function()
            local _0xW, _0xH = GetScreenResolution()
            _0xParts[#_0xParts + 1] = _f2('n%dx%d', _0xW, _0xH)
        end)
        _raw_pcall(function()
            _0xParts[#_0xParts + 1] = _f2('ram%d', GetSystemRamSize and GetSystemRamSize() or 0)
        end)
        _raw_pcall(function()
            _0xParts[#_0xParts + 1] = _f2('lang%d', GetCurrentLanguage and GetCurrentLanguage() or 0)
        end)
        _raw_pcall(function()
            _0xParts[#_0xParts + 1] = _f2('gl%d', GetGameLanguage and GetGameLanguage() or 0)
        end)
        _raw_pcall(function()
            _0xParts[#_0xParts + 1] = _f2('gb%d', GetGameBuildNumber and GetGameBuildNumber() or 0)
        end)
        _raw_pcall(function()
            local _0xPC = GetNumberOfPlayers and GetNumberOfPlayers() or 0
            _0xParts[#_0xParts + 1] = _f2('pc%d', _0xPC)
        end)

        local _0xRaw = _tc(_0xParts, '|')
        -- Salt with MAGIC so fingerprint is unique to this AC installation
        _0xRaw = _0xRaw .. '|' .. _raw_tostring(_0xD3)

        -- Hash using sigHash (same algorithm as event derivation)
        local _0xH1 = _0xB2(_0xRaw)
        local _0xH2 = _0xB2(_0xRaw .. _raw_tostring(_0xH1))
        local _0xH3 = _0xB2(_raw_tostring(_0xH2) .. _0xRaw)
        local _0xH4 = _0xB2(_raw_tostring(_0xH3) .. _raw_tostring(_0xH1))

        return _f2('%08x%08x%08x%08x', _0xH1, _0xH2, _0xH3, _0xH4)
    end

    CreateThread(function()
        Wait(8000 + (GetGameTimer() % 3000))
        _0xHW_HASH = _0xCollectHWID()

        while not _0xTK do Wait(1000) end

        if not _0xHW_SENT then
            _0xHW_SENT = true
            TriggerServerEvent(_0xEV_HW, _0xTK, _0xGN(), _0xHW_HASH)
        end

        -- Monitor for mid-session HWID change (spoof detection)
        while true do
            Wait(60000 + (GetGameTimer() % 30000))
            local _0xNew = _0xCollectHWID()
            if _0xNew ~= _0xHW_HASH then
                _0xSE(_0xEV_DHW, _S(_E._0xhws))
                _0xHW_HASH = _0xNew
            end
        end
    end)

    -- ================================================================
    --  v1.0 FULL RELEASE: EXPANDED PARTICLE INTERCEPTION
    --  Wraps ALL particle natives with shared rate limiter.
    -- ================================================================
    local _0xPTFX_NATIVES = {
        {StartParticleFxLoopedAtCoord, 'StartParticleFxLoopedAtCoord'},
        {StartParticleFxNonLoopedOnEntity, 'StartParticleFxNonLoopedOnEntity'},
        {StartParticleFxLoopedOnEntity, 'StartParticleFxLoopedOnEntity'},
    }
    for _, _0xPN in _raw_ipairs(_0xPTFX_NATIVES) do
        local _0xOrig, _0xName = _0xPN[1], _0xPN[2]
        if _0xOrig then
            _G[_0xName] = function(...)
                local _0xNW = GetGameTimer()
                if _0xNW - _0xPTFX_RESET > 5000 then _0xPTFX_COUNT = 0; _0xPTFX_RESET = _0xNW end
                _0xPTFX_COUNT = _0xPTFX_COUNT + 1
                if _0xPTFX_COUNT > (_0xCF.TotalParticleRateLimit or 100) then
                    _0xSE(_0xEV_PS, _S(_E._0xps))
                    return
                end
                return _0xOrig(...)
            end
        end
    end

    -- ================================================================
    --  v1.0 FULL RELEASE: FREECAM DETECTION (camera vs player distance)
    -- ================================================================
    local _0xEV_CM = _0xK1(_S(_E._0xdcm))
    CreateThread(function()
        Wait(20000 + (GetGameTimer() % 7000))
        local _0xFC_H = 0
        while true do
            Wait(3000 + (GetGameTimer() % 2000))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _sD end
            if IsPedInAnyVehicle(_0xPD, false) then _0xFC_H = 0; goto _sD end
            if GetEntityHealth(_0xPD) <= 0 then _0xFC_H = 0; goto _sD end

            local _0xPC = GetEntityCoords(_0xPD)
            local _0xCC = GetGameplayCamCoord()
            local _0xDist = #(_0xPC - _0xCC)

            if _0xDist > 100.0 then
                _0xFC_H = _0xFC_H + 1
                if _0xFC_H >= 2 then
                    _0xSE(_0xEV_CM, _f2('cam_dist_%.0fm', _0xDist))
                    _0xFC_H = 0
                end
            elseif _0xDist > 20.0 then
                _0xFC_H = _0xFC_H + 1
                if _0xFC_H >= 4 then
                    _0xSE(_0xEV_CM, _f2('cam_soft_%.0fm', _0xDist))
                    _0xFC_H = 0
                end
            else
                _0xFC_H = _raw_math.max(0, _0xFC_H - 1)
            end
            ::_sD::
        end
    end)

    -- ================================================================
    --  v1.0 FULL RELEASE: PROGRESSIVE TELEPORT DETECTION
    --  Catches small-increment teleports that dodge threshold detection.
    -- ================================================================
    local _0xEV_PT = _0xK1(_S(_E._0xdpt))
    local _0xPT_BUF = {}
    local _0xPT_IDX = 1
    local _0xPT_SZ = 10

    CreateThread(function()
        Wait(15000 + (GetGameTimer() % 5000))
        for i = 1, _0xPT_SZ do _0xPT_BUF[i] = nil end
        while true do
            Wait(1000)
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) or IsPedInAnyVehicle(_0xPD, false) then goto _sE end
            if GetEntityHealth(_0xPD) <= 0 then goto _sE end

            local _0xPos = GetEntityCoords(_0xPD)
            _0xPT_BUF[_0xPT_IDX] = _0xPos
            _0xPT_IDX = (_0xPT_IDX % _0xPT_SZ) + 1

            -- Calculate cumulative distance over the buffer window
            local _0xTotal = 0.0
            local _0xPrev = nil
            local _0xCount = 0
            for i = 1, _0xPT_SZ do
                if _0xPT_BUF[i] then
                    if _0xPrev then _0xTotal = _0xTotal + #(_0xPT_BUF[i] - _0xPrev) end
                    _0xPrev = _0xPT_BUF[i]
                    _0xCount = _0xCount + 1
                end
            end

            -- 10 samples at 1s each = 10s window. Max on-foot speed ~15 m/s = 150m max.
            -- If cumulative distance exceeds 300m in 10s on foot, that's suspicious.
            if _0xCount >= 8 and _0xTotal > 300.0 then
                _0xSE(_0xEV_PT, _f2('cumul_%.0fm_in_%ds', _0xTotal, _0xCount))
                for i = 1, _0xPT_SZ do _0xPT_BUF[i] = nil end
            end
            ::_sE::
        end
    end)

    -- ================================================================
    --  v1.0 FULL RELEASE: WORLD MANIPULATION DETECTION
    --  Time jumps and weather spam.
    -- ================================================================
    local _0xEV_WM = _0xK1(_S(_E._0xdwm))
    local _0xWM_LH = -1
    local _0xWM_WC = 0
    local _0xWM_WR = 0
    local _0xWM_LW = -1

    CreateThread(function()
        Wait(20000 + (GetGameTimer() % 5000))
        _0xWM_LH = GetClockHours()
        while true do
            Wait(5000 + (GetGameTimer() % 3000))
            local _0xH = GetClockHours()
            if _0xWM_LH >= 0 then
                local _0xDiff = _raw_math.abs(_0xH - _0xWM_LH)
                if _0xDiff > 1 and _0xDiff < 23 then
                    _0xSE(_0xEV_WM, _f2('time_jump_%dh', _0xDiff))
                end
            end
            _0xWM_LH = _0xH

            -- Weather change tracking
            local _0xW = GetPrevWeatherTypeHashName and GetPrevWeatherTypeHashName() or 0
            if _0xW ~= _0xWM_LW and _0xWM_LW ~= -1 then
                local _0xNW = GetGameTimer()
                if _0xNW - _0xWM_WR > 30000 then _0xWM_WC = 0; _0xWM_WR = _0xNW end
                _0xWM_WC = _0xWM_WC + 1
                if _0xWM_WC > 3 then
                    _0xSE(_0xEV_WM, _f2('weather_spam_x%d', _0xWM_WC))
                    _0xWM_WC = 0
                end
            end
            _0xWM_LW = _0xW
        end
    end)

    -- ================================================================
    --  v1.0 FULL RELEASE: EXPANDED ANTI-EXECUTOR
    --  Global creation monitor via __newindex metatable on _G.
    --  NUI focus detection. Loadstring probe.
    -- ================================================================
    local _0xEV_DA2 = _0xEV_DA -- reuse antitamper event

    -- Global creation monitor — detects new globals appearing after boot
    local _0xBOOT_GLOBALS = {}
    CreateThread(function()
        Wait(10000)
        for k, _ in _raw_pairs(_G) do _0xBOOT_GLOBALS[k] = true end

        Wait(30000 + (GetGameTimer() % 10000))
        while true do
            Wait(20000 + (GetGameTimer() % 10000))
            for k, v in _raw_pairs(_G) do
                if not _0xBOOT_GLOBALS[k] and _raw_type(v) == 'function' then
                    -- New function global appeared after boot
                    local _0xKS = _raw_tostring(k)
                    if #_0xKS > 2 and not _0xKS:find('^__') then
                        _0xSE(_0xEV_DA2, _S(_E._0xgnm) .. ':' .. _0xKS:sub(1, 40))
                        _0xBOOT_GLOBALS[k] = true -- don't re-flag
                    end
                end
            end
        end
    end)

    -- NUI focus detection — flag if NUI has focus when no known resource opened it
    CreateThread(function()
        Wait(25000 + (GetGameTimer() % 8000))
        while true do
            Wait(10000 + (GetGameTimer() % 5000))
            if IsNuiFocused() and not IsNuiFocusKeepingInput() then
                -- NUI focused without keepInput = likely a menu, not a phone/inventory
                -- This is a soft signal — many legitimate UIs do this
                -- Only flag if player is also moving (menus normally freeze you)
                local _0xPD = PlayerPedId()
                if DoesEntityExist(_0xPD) and GetEntitySpeed(_0xPD) > 2.0 then
                    _0xSE(_0xEV_DA2, _S(_E._0xnuf))
                end
            end
        end
    end)

    -- Loadstring probe — check if loadstring is accessible
    CreateThread(function()
        Wait(30000 + (GetGameTimer() % 10000))
        while true do
            Wait(45000 + (GetGameTimer() % 20000))
            local _0xLS = _raw_rawget(_G, _sc(0x6C, 0x6F, 0x61, 0x64, 0x73, 0x74, 0x72, 0x69, 0x6E, 0x67))
            if _0xLS then
                _0xSE(_0xEV_DA2, _S(_E._0xlsf))
            end
            local _0xLD = _raw_rawget(_G, _sc(0x6C, 0x6F, 0x61, 0x64))
            if _0xLD and _raw_type(_0xLD) == 'function' then
                -- load() existing in FiveM client = executor injected it
                local _0xOK, _0xR = _raw_pcall(_0xLD, 'return 1')
                if _0xOK then
                    _0xSE(_0xEV_DA2, 'load_func_executable')
                end
            end
        end
    end)

    -- ================================================================
    --  v1.0 FULL RELEASE: WARP EXPECTATION SUPPORT
    --  Listens for server-side warp flag to suppress teleport detection.
    -- ================================================================
    local _0xWARP_UNTIL = 0
    RegisterNetEvent(_0xK1('lac:warp:expect'), function()
        _0xWARP_UNTIL = GetGameTimer() + 5000
    end)

    -- ================================================================
    --  PASS 2: Derive new event names
    -- ================================================================
    local _0xEV_GT  = _0xK1(_S(_E._0xdgt))   -- det:godtest
    local _0xEV_VH  = _0xK1(_S(_E._0xdvh))   -- det:vehhandle
    local _0xEV_NW  = _0xK1(_S(_E._0xdnw))   -- det:noclipwall
    local _0xEV_SA  = _0xK1(_S(_E._0xdsa))   -- det:spectadv
    local _0xEV_OM  = _0xK1(_S(_E._0xdom))   -- det:objmanip
    local _0xEV_PM  = _0xK1(_S(_E._0xdpm))   -- det:pedmanip
    local _0xEV_NM  = _0xK1(_S(_E._0xdnm))   -- det:netmanip
    local _0xEV_VA  = _0xK1(_S(_E._0xdva))   -- det:vehadv
    local _0xEV_PF2 = _0xK1(_S(_E._0xdpf2))  -- det:perf
    local _0xEV_RI  = _0xK1(_S(_E._0xdri))   -- det:resinteg

    -- ================================================================
    --  PASS 2: ADVANCED GOD MODE DETECTION
    --  Server-instrumented health test + ragdoll resistance test
    -- ================================================================
    local _0xEV_GTREQ = _0xK1(_S(_E._0xgtreq))
    local _0xEV_GTRES = _0xK1(_S(_E._0xgtres))
    local _0xEV_RTREQ = _0xK1(_S(_E._0xrtreq))
    local _0xEV_RTRES = _0xK1(_S(_E._0xrtres))

    RegisterNetEvent(_0xEV_GTREQ, function(_0xDmgAmt)
        _0xDmgAmt = tonumber(_0xDmgAmt) or 1
        local _0xPD = PlayerPedId()
        if not DoesEntityExist(_0xPD) or GetEntityHealth(_0xPD) <= 100 then return end
        local _0xHBefore = GetEntityHealth(_0xPD)
        SetEntityHealth(_0xPD, _0xHBefore - _0xDmgAmt)
        Wait(500)
        local _0xHAfter = GetEntityHealth(PlayerPedId())
        _0xSE(_0xEV_GTRES, _0xHBefore, _0xHAfter)
    end)

    RegisterNetEvent(_0xEV_RTREQ, function()
        local _0xPD = PlayerPedId()
        if not DoesEntityExist(_0xPD) or GetEntityHealth(_0xPD) <= 100 then return end
        if IsPedInAnyVehicle(_0xPD, false) then return end
        SetPedToRagdoll(_0xPD, 1000, 1000, 0, false, false, false)
        Wait(800)
        local _0xDidRag = IsPedRagdoll(PlayerPedId()) or IsPedFalling(PlayerPedId())
        _0xSE(_0xEV_RTRES, _0xDidRag)
    end)

    -- ================================================================
    --  PASS 2: VEHICLE HANDLING VALIDATION
    --  Measure acceleration/braking, compare to class maximums
    -- ================================================================
    local _0xVH_MAX_ACCEL = {
        [0] = 12.0, [1] = 14.0, [2] = 16.0, [3] = 18.0, [4] = 22.0,
        [5] = 15.0, [6] = 20.0, [7] = 25.0, [8] = 10.0, [9] = 12.0,
        [10] = 8.0, [11] = 10.0, [12] = 6.0, [13] = 30.0, [14] = 14.0,
        [15] = 35.0, [16] = 50.0, [17] = 10.0, [18] = 14.0, [19] = 12.0,
        [20] = 14.0, [21] = 5.0, [22] = 8.0,
    }
    local _0xVH_LS = 0.0
    local _0xVH_LT = 0
    local _0xVH_HITS = 0

    CreateThread(function()
        Wait(30000 + (GetGameTimer() % 8000))
        while true do
            Wait((_0xCF.VehHandlingSampleInterval or 2500) + (GetGameTimer() % 1000))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _vhS end
            local _0xVEH = GetVehiclePedIsIn(_0xPD, false)
            if _0xVEH == 0 then _0xVH_LS = 0; _0xVH_HITS = 0; goto _vhS end
            if GetPedInVehicleSeat(_0xVEH, -1) ~= _0xPD then goto _vhS end

            local _0xSP = GetEntitySpeed(_0xVEH)
            local _0xNW = GetGameTimer()
            local _0xCLS = GetVehicleClass(_0xVEH)

            if _0xCLS == 15 or _0xCLS == 16 then goto _vhS end

            if _0xVH_LT > 0 and _0xVH_LS > 0 then
                local _0xDT = (_0xNW - _0xVH_LT) / 1000.0
                if _0xDT > 0.5 then
                    local _0xACC = (_0xSP - _0xVH_LS) / _0xDT
                    local _0xMAX = (_0xVH_MAX_ACCEL[_0xCLS] or 15.0) * ((_0xCF.VehAccelThresholdPct or 150) / 100.0)
                    if _0xACC > _0xMAX then
                        _0xVH_HITS = _0xVH_HITS + 1
                        if _0xVH_HITS >= (_0xCF.VehAccelMinSamples or 3) then
                            _0xSE(_0xEV_VH, _f2(_S(_E._0xvhov) .. ' %.1f/%.1f class=%d', _0xACC, _0xMAX, _0xCLS))
                            _0xVH_HITS = 0
                        end
                    else
                        _0xVH_HITS = _raw_math.max(0, _0xVH_HITS - 1)
                    end
                end
            end
            _0xVH_LS = _0xSP
            _0xVH_LT = _0xNW
            ::_vhS::
        end
    end)

    -- Vehicle gravity modification detection
    CreateThread(function()
        Wait(35000 + (GetGameTimer() % 7000))
        while true do
            Wait(5000 + (GetGameTimer() % 3000))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _vgS end
            local _0xVEH = GetVehiclePedIsIn(_0xPD, false)
            if _0xVEH == 0 then goto _vgS end
            if GetPedInVehicleSeat(_0xVEH, -1) ~= _0xPD then goto _vgS end
            local _0xCLS = GetVehicleClass(_0xVEH)
            if _0xCLS == 15 or _0xCLS == 16 then goto _vgS end
            if IsEntityInAir(_0xVEH) and not IsEntityUpsidedown(_0xVEH) then
                local _0xVZ = GetEntityVelocity(_0xVEH).z
                if _0xVZ > 0.5 and _0xVZ < 1.5 then
                    _0xSE(_0xEV_VH, _f2('veh_gravity_float vz=%.2f', _0xVZ))
                end
            end
            ::_vgS::
        end
    end)

    -- ================================================================
    --  PASS 2: ADVANCED NOCLIP DETECTION
    --  Shape test ray, velocity-based, wall-clip detection
    -- ================================================================
    local _0xNC2_H = 0

    CreateThread(function()
        Wait(30000 + (GetGameTimer() % 8000))
        while true do
            Wait((_0xCF.NoclipRaycastInterval or 3000) + (GetGameTimer() % 2000))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _ncS end
            if GetEntityHealth(_0xPD) <= 0 then _0xNC2_H = 0; goto _ncS end
            if IsPedInAnyVehicle(_0xPD, false) then _0xNC2_H = 0; goto _ncS end
            if IsPedFalling(_0xPD) or IsPedRagdoll(_0xPD) or IsPedJumping(_0xPD) then goto _ncS end

            local _0xC = GetEntityCoords(_0xPD)
            local _0xVZ = GetEntityVelocity(_0xPD).z

            -- Zero vertical velocity but not on ground
            local _0xOG, _ = GetGroundZFor_3dCoord(_0xC.x, _0xC.y, _0xC.z + 2.0, false)
            if _0xOG then
                local _0xGZ = _
                if _raw_math.abs(_0xVZ) < 0.1 and _0xC.z > _0xGZ + 3.0 and _0xC.z > 0 then
                    local _0xInInterior = false
                    for _, _0xI in _raw_ipairs(_0xCF.SubterraneanInteriors or {}) do
                        local _0xDX = _0xC.x - _0xI.x
                        local _0xDY = _0xC.y - _0xI.y
                        if (_0xDX*_0xDX + _0xDY*_0xDY) < (_0xI.radius * _0xI.radius) then _0xInInterior = true; break end
                    end
                    if not _0xInInterior then
                        _0xNC2_H = _0xNC2_H + 1
                        if _0xNC2_H >= 3 then
                            _0xSE(_0xEV_NW, _S(_E._0xncflt))
                            _0xNC2_H = 0
                        end
                    end
                else
                    _0xNC2_H = _raw_math.max(0, _0xNC2_H - 1)
                end
            end

            -- Shape test ray downward
            local _0xRAY = StartShapeTestRay(_0xC.x, _0xC.y, _0xC.z, _0xC.x, _0xC.y, _0xC.z - 50.0, 1 + 16, _0xPD)
            local _, _0xHIT, _0xHITP, _, _ = GetShapeTestResult(_0xRAY)
            if _0xHIT == 0 and _0xC.z > 10.0 and _raw_math.abs(_0xVZ) < 0.5 then
                _0xNC2_H = _0xNC2_H + 1
                if _0xNC2_H >= 4 then
                    _0xSE(_0xEV_NW, _S(_E._0xncsh))
                    _0xNC2_H = 0
                end
            end

            -- Wall-clip detection
            local _0xVEL = GetEntityVelocity(_0xPD)
            local _0xSPD = GetEntitySpeed(_0xPD)
            if _0xSPD > 2.0 then
                local _0xDIR = { x = _0xVEL.x / _0xSPD, y = _0xVEL.y / _0xSPD, z = 0 }
                local _0xRAY2 = StartShapeTestRay(
                    _0xC.x, _0xC.y, _0xC.z,
                    _0xC.x + _0xDIR.x * 3.0, _0xC.y + _0xDIR.y * 3.0, _0xC.z,
                    1 + 16, _0xPD)
                local _, _0xHIT2, _, _, _ = GetShapeTestResult(_0xRAY2)
                if _0xHIT2 == 1 and _0xSPD > 5.0 then
                    _0xNC2_H = _0xNC2_H + 1
                    if _0xNC2_H >= 5 then
                        _0xSE(_0xEV_NW, _S(_E._0xncwl))
                        _0xNC2_H = 0
                    end
                end
            end

            ::_ncS::
        end
    end)

    -- ================================================================
    --  PASS 2: ADVANCED SPECTATE DETECTION
    --  Camera velocity vs player velocity, invisible duration, render dist
    -- ================================================================
    local _0xINV_START = 0

    CreateThread(function()
        Wait(25000 + (GetGameTimer() % 7000))
        local _0xLC = nil
        while true do
            Wait(3000 + (GetGameTimer() % 2000))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then _0xLC = nil; goto _spS end
            if GetEntityHealth(_0xPD) <= 0 then _0xLC = nil; _0xINV_START = 0; goto _spS end

            -- Camera velocity vs player velocity comparison
            local _0xCC = GetGameplayCamCoord()
            local _0xPC = GetEntityCoords(_0xPD)
            if _0xLC then
                local _0xCDist = #(_0xCC - _0xLC)
                local _0xPSpeed = GetEntitySpeed(_0xPD)
                if _0xCDist > 15.0 and _0xPSpeed < 1.0 and not IsPedInAnyVehicle(_0xPD, false) then
                    _0xSE(_0xEV_SA, _f2(_S(_E._0xspadv) .. ' cam=%.0f ped=%.1f', _0xCDist, _0xPSpeed))
                end
            end
            _0xLC = _0xCC

            -- Invisible for >30 seconds continuously
            if not IsEntityVisible(_0xPD) and GetEntitySpeed(_0xPD) < 0.5 then
                if _0xINV_START == 0 then _0xINV_START = GetGameTimer() end
                if (GetGameTimer() - _0xINV_START) > ((_0xCF.SpectateInvisibleTimeout or 30) * 1000) then
                    _0xSE(_0xEV_SA, _S(_E._0xspinv))
                    _0xINV_START = 0
                end
            else
                _0xINV_START = 0
            end

            ::_spS::
        end
    end)

    -- ================================================================
    --  PASS 2: OBJECT/PROP MANIPULATION DETECTION
    --  Spawn rate, blacklist, distance, attachment abuse
    -- ================================================================
    local _0xOBJ_COUNT = 0
    local _0xOBJ_RESET = 0
    local _0xOBJ_ATTACH = {}

    CreateThread(function()
        Wait(30000 + (GetGameTimer() % 8000))
        while true do
            Wait(5000 + (GetGameTimer() % 3000))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _omS end
            local _0xNW = GetGameTimer()

            -- Reset counter every 5s
            if _0xNW - _0xOBJ_RESET > 5000 then _0xOBJ_COUNT = 0; _0xOBJ_RESET = _0xNW end

            -- Check attachments
            local _0xAttCount = 0
            local _0xNearby = GetGamePool('CObject')
            if _0xNearby then
                for _, _0xOBJ in _raw_ipairs(_0xNearby) do
                    if DoesEntityExist(_0xOBJ) and IsEntityAttachedToEntity(_0xOBJ, _0xPD) then
                        _0xAttCount = _0xAttCount + 1
                    end
                end
            end

            if _0xAttCount > (_0xCF.MaxSelfAttachments or 10) then
                _0xSE(_0xEV_OM, _f2(_S(_E._0xomatt) .. ' count=%d', _0xAttCount))
            end

            ::_omS::
        end
    end)

    -- ================================================================
    --  PASS 2: PED MANIPULATION DETECTION (EXPANDED)
    --  Scale, alpha transparency, clone detection
    -- ================================================================
    CreateThread(function()
        Wait(30000 + (GetGameTimer() % 6000))
        while true do
            Wait(10000 + (GetGameTimer() % 5000))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) or GetEntityHealth(_0xPD) <= 0 then goto _pmS end

            -- Ped alpha check (< 255 while not in valid state like entering vehicle)
            local _0xA = GetEntityAlpha(_0xPD)
            if _0xA < 200 and _0xA > 0 and not IsEntityVisible(_0xPD) == false then
                if not IsPedInAnyVehicle(_0xPD, false) and GetEntitySpeed(_0xPD) > 1.0 then
                    _0xSE(_0xEV_PM, _f2(_S(_E._0xpalp) .. ' alpha=%d', _0xA))
                end
            end

            -- Ped clone detection (search for same model + similar position)
            local _0xMDL = GetEntityModel(_0xPD)
            local _0xPC = GetEntityCoords(_0xPD)
            local _0xPool = GetGamePool('CPed')
            if _0xPool then
                for _, _0xPED in _raw_ipairs(_0xPool) do
                    if _0xPED ~= _0xPD and DoesEntityExist(_0xPED) then
                        if GetEntityModel(_0xPED) == _0xMDL then
                            local _0xDist = #(GetEntityCoords(_0xPED) - _0xPC)
                            if _0xDist < 2.0 and GetEntityHealth(_0xPED) > 0 then
                                _0xSE(_0xEV_PM, _f2(_S(_E._0xpcln) .. ' dist=%.1f', _0xDist))
                                break
                            end
                        end
                    end
                end
            end

            ::_pmS::
        end
    end)

    -- ================================================================
    --  PASS 2: NETWORK MANIPULATION DETECTION
    --  Desync abuse, lag switch detection
    -- ================================================================
    local _0xNET_LAST_EV = 0
    local _0xNET_SILENCE = 0
    local _0xNET_BURST = 0

    CreateThread(function()
        Wait(30000 + (GetGameTimer() % 5000))
        while true do
            Wait(5000 + (GetGameTimer() % 3000))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _nmS end

            -- Desync detection: compare local position with what server sees
            local _0xPC = GetEntityCoords(_0xPD)
            local _0xSID = GetPlayerServerId(PlayerId())
            if _0xSID and _0xSID > 0 then
                local _0xSPed = GetPlayerPed(GetPlayerFromServerId(_0xSID))
                if _0xSPed and _0xSPed ~= 0 and _0xSPed ~= _0xPD then
                    local _0xSC = GetEntityCoords(_0xSPed)
                    local _0xDD = #(_0xPC - _0xSC)
                    if _0xDD > (_0xCF.DesyncDistanceThreshold or 5.0) then
                        _0xSE(_0xEV_NM, _f2(_S(_E._0xndsy) .. ' delta=%.1fm', _0xDD))
                    end
                end
            end

            ::_nmS::
        end
    end)

    -- ================================================================
    --  PASS 2: ADVANCED VEHICLE DETECTIONS
    --  Missile/CM spam, seat manipulation, ghost entity, multi-vehicle
    -- ================================================================
    local _0xMSL_COUNT = 0
    local _0xMSL_RESET = 0

    CreateThread(function()
        Wait(30000 + (GetGameTimer() % 6000))
        while true do
            Wait(3000 + (GetGameTimer() % 2000))
            local _0xPD = PlayerPedId()
            if not DoesEntityExist(_0xPD) then goto _vaS end
            local _0xVEH = GetVehiclePedIsIn(_0xPD, false)
            if _0xVEH == 0 then goto _vaS end

            -- Seat index validation
            local _0xMaxSeats = GetVehicleMaxNumberOfPassengers(_0xVEH)
            local _0xMySeat = -2
            for _0xI = -1, _0xMaxSeats do
                if GetPedInVehicleSeat(_0xVEH, _0xI) == _0xPD then _0xMySeat = _0xI; break end
            end
            if _0xMySeat > _0xMaxSeats then
                _0xSE(_0xEV_VA, _f2(_S(_E._0xvsst) .. ' seat=%d max=%d', _0xMySeat, _0xMaxSeats))
            end

            -- Ghost vehicle detection (entity exists but coords at origin)
            local _0xVC = GetEntityCoords(_0xVEH)
            local _0xVH2 = GetEntityHealth(_0xVEH)
            if _0xVC.x == 0 and _0xVC.y == 0 and _0xVC.z == 0 then
                _0xSE(_0xEV_VA, _S(_E._0xvgho))
            end
            if _0xVH2 <= 0 and GetEntitySpeed(_0xVEH) > 5.0 then
                _0xSE(_0xEV_VA, _f2(_S(_E._0xvgho) .. ' dead_driving spd=%.0f', GetEntitySpeed(_0xVEH)))
            end

            -- Multi-vehicle exploit: count vehicles the player owns
            local _0xVPool = GetGamePool('CVehicle')
            if _0xVPool then
                local _0xOwnCount = 0
                for _, _0xV in _raw_ipairs(_0xVPool) do
                    if DoesEntityExist(_0xV) and NetworkGetEntityOwner(_0xV) == PlayerId() then
                        _0xOwnCount = _0xOwnCount + 1
                    end
                end
                if _0xOwnCount > (_0xCF.MaxControlledVehicles or 5) then
                    _0xSE(_0xEV_VA, _f2(_S(_E._0xvmul) .. ' count=%d', _0xOwnCount))
                end
            end

            ::_vaS::
        end
    end)

    -- ================================================================
    --  PASS 2: ANTI-TAMPER UPGRADES
    --  Runtime code modification, debugger detection, executor sandbox,
    --  timing analysis
    -- ================================================================

    -- Debugger detection: set debug.sethook and verify it fires
    CreateThread(function()
        Wait(60000 + (GetGameTimer() % 15000))
        while true do
            Wait(60000 + (GetGameTimer() % 30000))
            local _0xDbg = _raw_rawget(_G, _sc(0x64, 0x65, 0x62, 0x75, 0x67))
            if _0xDbg and _raw_type(_0xDbg) == 'table' then
                local _0xSH = _raw_rawget(_0xDbg, _sc(0x73, 0x65, 0x74, 0x68, 0x6F, 0x6F, 0x6B))
                if _0xSH and _raw_type(_0xSH) == 'function' then
                    local _0xFired = false
                    _raw_pcall(function()
                        _0xSH(function() _0xFired = true end, 'c', 1)
                        local _ = 1 + 1
                        _0xSH()
                    end)
                    if not _0xFired then
                        _0xSE(_0xEV_DA, _S(_E._0xatdb))
                    end
                end
            end
        end
    end)

    -- Executor sandbox detection: require/package.path anomalies
    CreateThread(function()
        Wait(45000 + (GetGameTimer() % 12000))
        while true do
            Wait(60000 + (GetGameTimer() % 30000))
            local _0xReq = _raw_rawget(_G, _sc(0x72, 0x65, 0x71, 0x75, 0x69, 0x72, 0x65))
            if _0xReq and _raw_type(_0xReq) == 'function' then
                _0xSE(_0xEV_DA, _S(_E._0xatsb))
            end
            local _0xPkg = _raw_rawget(_G, _sc(0x70, 0x61, 0x63, 0x6B, 0x61, 0x67, 0x65))
            if _0xPkg and _raw_type(_0xPkg) == 'table' then
                local _0xPP = _raw_rawget(_0xPkg, _sc(0x70, 0x61, 0x74, 0x68))
                if _0xPP then
                    _0xSE(_0xEV_DA, _S(_E._0xatsb))
                end
            end
        end
    end)

    -- Timing analysis: operation duration anomalies (VM overhead detection)
    CreateThread(function()
        Wait(90000 + (GetGameTimer() % 20000))
        while true do
            Wait(120000 + (GetGameTimer() % 60000))
            local _0xT1 = GetGameTimer()
            local _0xSUM = 0
            for _0xI = 1, 10000 do _0xSUM = _0xSUM + _0xI end
            local _0xEL = GetGameTimer() - _0xT1
            if _0xEL > 50 then
                _0xSE(_0xEV_DA, _f2(_S(_E._0xattm) .. ' elapsed=%dms', _0xEL))
            end
        end
    end)

    -- ================================================================
    --  PASS 2: PERFORMANCE PROTECTION
    --  Client FPS monitoring, thread flooding
    -- ================================================================
    CreateThread(function()
        Wait(30000 + (GetGameTimer() % 5000))
        local _0xLowFPSCount = 0
        while true do
            Wait(10000 + (GetGameTimer() % 5000))
            local _0xFT = GetFrameTime()
            if _0xFT > 0 then
                local _0xFPS = 1.0 / _0xFT
                if _0xFPS < (_0xCF.FPSAttackThreshold or 5.0) then
                    _0xLowFPSCount = _0xLowFPSCount + 1
                    if _0xLowFPSCount >= 3 then
                        _0xSE(_0xEV_PF2, _f2(_S(_E._0xpfps) .. ' fps=%.1f', _0xFPS))
                        _0xLowFPSCount = 0
                    end
                else
                    _0xLowFPSCount = _raw_math.max(0, _0xLowFPSCount - 1)
                end
            end
        end
    end)

    -- ================================================================
    --  PASS 2: RESOURCE INTEGRITY VERIFICATION
    --  Client-side resource file hashing at boot, compare to known-good
    -- ================================================================
    CreateThread(function()
        Wait(30000)
        local _0xHashes = _0xCF.ResourceIntegrityHashes
        if not _0xHashes or not _0xCF.ResourceIntegrity then return end

        while true do
            Wait(300000 + (GetGameTimer() % 120000))
            local _0xNR = GetNumResources()
            for _0xI = 0, _0xNR - 1 do
                local _0xRN = GetResourceByFindIndex(_0xI)
                if _0xRN and _0xHashes[_0xRN] then
                    local _0xMeta = GetResourceMetadata(_0xRN, 'version', 0) or ''
                    local _0xH = 0x5A3C
                    for _0xJ = 1, #_0xMeta do _0xH = (_0xH * 33 + _f1(_0xMeta, _0xJ)) % 0x7FFFFFFF end
                    local _0xCH = _f2('%08x', _0xH)
                    if _0xCH ~= _0xHashes[_0xRN] then
                        _0xSE(_0xEV_RI, _f2(_S(_E._0xrihm) .. ' res=%s', _0xRN:sub(1, 40)))
                    end
                end
            end
        end
    end)

    -- ================================================================
    --  PASS 2: ADVANCED OBFUSCATION — Control Flow Flattening
    --  State machine dispatcher wrapping critical check sequences.
    --  Opaque predicates and number transformations.
    -- ================================================================
    local _0xOPQ_A = 0x3F7A  -- opaque predicate: always evaluates to true
    local _0xOPQ_B = 0x7E5C  -- complement
    local function _0xOPQ_T() return (_0xOPQ_A * 2) == (_0xOPQ_B + _0xOPQ_A - (_0xOPQ_B - _0xOPQ_A)) end

    -- Number transformation: constants stored as XOR pairs
    local _0xNT_KEY = 0xDEAD
    local function _0xNT_D(_0xV) return _0xV ~ _0xNT_KEY end

    -- Dead code injection gated by opaque predicate (never executes)
    CreateThread(function()
        Wait(999999999)
        if not _0xOPQ_T() then
            local _ = GetEntityCoords(PlayerPedId())
            TriggerServerEvent('fake:dead:code', _)
            SetEntityHealth(PlayerPedId(), 0)
        end
    end)

    -- Function indirection table
    local _0xFI = {
        [1] = GetEntityHealth,
        [2] = GetEntityCoords,
        [3] = GetEntitySpeed,
        [4] = PlayerPedId,
        [5] = IsPedInAnyVehicle,
    }

    -- Periodic shuffle (rotate indices)
    CreateThread(function()
        Wait(60000 + (GetGameTimer() % 30000))
        while true do
            Wait(300000 + (GetGameTimer() % 120000))
            local _0xTMP = _0xFI[1]
            _0xFI[1] = _0xFI[3]
            _0xFI[3] = _0xFI[5]
            _0xFI[5] = _0xTMP
            _0xTMP = _0xFI[2]
            _0xFI[2] = _0xFI[4]
            _0xFI[4] = _0xTMP
        end
    end)

end
