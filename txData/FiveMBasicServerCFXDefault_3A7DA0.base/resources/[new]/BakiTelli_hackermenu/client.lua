local my = {}
local Current = nil
local Search = true
local blockbuttons = false
local currentCameraIndex = 0
local currentCameraIndexIndex = 0
local createdCamera = 0
local camname = "asd"

function Camera(camname)
    SendNUIMessage({
        action = "close"
    })
    blockbuttons = true
	local firstCamx = Config.CctvCamera[camname][1].x
    local firstCamy = Config.CctvCamera[camname][1].y
    local firstCamz = Config.CctvCamera[camname][1].z
    local firstCamr = Config.CctvCamera[camname][1].r
	FreezeEntityPosition(PlayerPedId(), 1)
    SetFocusArea(firstCamx, firstCamy, firstCamz, firstCamx, firstCamy, firstCamz)
    ChangeSecurityCamera(firstCamx, firstCamy, firstCamz, firstCamr)
    currentCameraIndex = 1
    currentCameraIndexIndex = 1
end

function Locked()
	local playerPed		= GetPlayerPed(-1)
    local coords		= GetEntityCoords(playerPed)
	if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 5.0) then
		vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
		SetVehicleAlarm(vehicle, true)
		SetVehicleAlarmTimeLeft(vehicle, 60 * 1000)
		SetVehicleDoorsLocked(vehicle, 1)
		SetVehicleDoorsLockedForAllPlayers(vehicle, false)
		ClearPedTasksImmediately(playerPed)

		SetVehicleNeedsToBeHotwired(vehicle, true)
		IsVehicleNeedsToBeHotwired(vehicle)
		TaskEnterVehicle(playerPed, vehicle, 10.0, -1, 1.0, 1, 0)
		local plate = GetVehicleNumberPlateText(vehicle)
		addKeys(plate)
	end
end

AddEventHandler("BakiTelli_hackermenu:OpenMenu")
RegisterNetEvent("BakiTelli_hackermenu:OpenMenu", function (myx)
    my = myx
    OpenMenu("mainmenu")
end)

AddEventHandler("BakiTelli_hackermenu:Notification")
RegisterNetEvent("BakiTelli_hackermenu:Notification", function (myx, text)
        SendNUIMessage({
            action = "notification",
            myx = myx,
            text = text
        })
end)

AddEventHandler("BakiTelli_hackermenu:StartHack")
RegisterNetEvent("BakiTelli_hackermenu:StartHack", function (id)
    Current = id 
    SendNUIMessage({
        action = "WaitScreen",
        time = Config.HackerMenu[id].HackTime
    })
end)

AddEventHandler("BakiTelli_hackermenu:SetGPS")
RegisterNetEvent("BakiTelli_hackermenu:SetGPS", function (coord)
	SetNewWaypoint(coord.x, coord.y)
end)


AddEventHandler("BakiTelli_hackermenu:cl:getData")
RegisterNetEvent("BakiTelli_hackermenu:cl:getData", function (typ, rtrn)
    if typ == "table" then 
        if Current == "CctvCamera" then 
            SendNUIMessage({
                action = "removePlayer",
                typ = "cctv"
            })
            addCctvCam()
        else
            SendNUIMessage({
                action = "removePlayer",
                typ = "dft"
            })
        end
    end
	if typ == "entertext" then
	 OpenMenu("tweetmenu")
	else
    SendNUIMessage({
        action = "FinishText",
        typ = typ,
        rtrn = rtrn
    })
end
if Current == "LocationCheck" then
	SendNUIMessage({
		action = "inputedit",
		text = Config.Langs.enternumber
	}) 
elseif Current == "PhonefromName" then
	SendNUIMessage({
		action = "inputedit",
		text = Config.Langs.entername
	}) 
end
end)


function addPlayer(namex, identifier)
	SendNUIMessage({
	  action = "addPlayer",
	  identifier = identifier,
	  namex = namex
	})
  end

RegisterNUICallback("close", function ()
    SetNuiFocus(false, false)
    Search = true
end)

RegisterNUICallback("open", function ()
    OpenMenu("mainmenu")
end)

RegisterNUICallback("SendTweet", function (data)
	text = data.text
	if Current == "AnonimTweet" then 
	TriggerServerEvent("BakiTelli_hackermenu:SendTweet", text)
	else 
	TriggerServerEvent("BakiTelli_hackermenu:SendAll", text)
	end
end)

RegisterNUICallback("ClickMain", function (data)
    id = data.id
    TriggerServerEvent("BakiTelli_hackermenu:ClickMain", id)
end)

RegisterNUICallback("Finish", function ()
	if Current == "CarLock" then 
        SendNUIMessage({
			action = "close"
		})
		Locked()
	else
		TriggerServerEvent("BakiTelli_hackermenu:getData", Current)
	end
end)

RegisterNUICallback("Search", function (data)
    if Current == "CctvCamera" then else
        if Search then
            Search = false
            TriggerServerEvent("BakiTelli_hackermenu:getUsers", data.text, Current)
        else 
            TriggerEvent("BakiTelli_hackermenu:Notification", "error", Config.Langs["SearchLimit"])
        end
    end
end)

RegisterNUICallback("SelectSearch", function (data)
	if Current == "CctvCamera" then 
        Camera(data.id)
		camname = data.id
    else
		TriggerServerEvent("BakiTelli_hackermenu:getUserDetail",Current, data.id)
		if Current == "LocationCheck" then 
			SendNUIMessage({
				action = "close"
			})
		end
	end
end)

function OpenMenu(typ)
	if typ == "mainmenu" then 
    AddMain()
	end
	if Current == "AnonimTweet" then
		SendNUIMessage({
			action = "tweettext",
			text = Config.Langs["TweetText"]
		}) 
	elseif Current == "SendAllDM" then 
		SendNUIMessage({
			action = "tweettext",
			text = Config.Langs["AllDMText"]
		}) 
	end
    SetNuiFocus(true, true) 
    SendNUIMessage({
        action = "openmenu",
        typ = typ
    })
end

function addCctvCam()
    for i, key in ipairs({
        "Shop1",
        "Shop2",
        "Shop3",
        "Shop4",
        "Shop5",
        "Shop6",
        "Shop7",
        "Shop8",
        "Shop9",
        "Shop10",
        "Shop11",
        "Shop12",
        "Shop13",
        "Shop14",
        "Shop15",
        "Shop16",
        "Shop17",
        "Shop18",
        "Shop19",
        "Motel",
        "Jewelry",
        "Hospital",
        "Sheriff",
        "State",
        "Police",
        "Bank",
    }) do
        addPlayer(key, key)
    end
end

function AddMain()
    for i, key in ipairs({
        "SendAllDM",
        "BankHack",
        "LocationCheck",
        "CarLock",
        "AnonimTweet",
        "CctvCamera",
        "PhonefromName",
        "PhoneCheck",
        "LspdActivePersonel",
    }) do
        local v = Config.HackerMenu[key]
        local xp =  calculateLevel(json.decode(my).xp)
            SendNUIMessage({
                action = "addMain",
                id = key,
                name = v.label,
                money = v.price,
                lvl = v.level,
                dec = v.dec,
                mylvl =xp
            })
    end
end

function calculateLevel(experience)
    local level = math.floor(tonumber(experience) / 100)
    return level
end



Citizen.CreateThread(function()
	while true do
		local time = 1000
		if createdCamera ~= 0 then
			time = 1
			local instructions = CreateInstuctionScaleform("instructional_buttons")

			DrawScaleformMovieFullscreen(instructions, 255, 255, 255, 255, 0)
			SetTimecycleModifier("scanline_cam_cheap")
			SetTimecycleModifierStrength(2.0)

			if IsControlJustPressed(0, 177) then
				CloseSecurityrdrCamera()
			end

			if IsControlJustPressed(0,174) then
				local newCamIndex

				if currentCameraIndexIndex == 1 then
					newCamIndex = #Config.CctvCamera[camname]
				else
					newCamIndex = currentCameraIndexIndex - 1
				end

				local newCamx = Config.CctvCamera[camname][newCamIndex].x
				local newCamy = Config.CctvCamera[camname][newCamIndex].y
				local newCamz = Config.CctvCamera[camname][newCamIndex].z
				local newCamr = Config.CctvCamera[camname][newCamIndex].r

				SetFocusArea(newCamx, newCamy, newCamz, newCamx, newCamy, newCamz)

				ChangeSecurityCamera(newCamx, newCamy, newCamz, newCamr)
				currentCameraIndexIndex = newCamIndex
			end

			if IsControlJustPressed(0, 175) then
				local newCamIndex
			
				if currentCameraIndexIndex == #Config.CctvCamera[camname] then
					newCamIndex = 1
				else
					newCamIndex = currentCameraIndexIndex + 1
				end

				local newCamx = Config.CctvCamera[camname][newCamIndex].x
				local newCamy = Config.CctvCamera[camname][newCamIndex].y
				local newCamz = Config.CctvCamera[camname][newCamIndex].z
				local newCamr = Config.CctvCamera[camname][newCamIndex].r

				ChangeSecurityCamera(newCamx, newCamy, newCamz, newCamr)
				currentCameraIndexIndex = newCamIndex
			end
			if Config.CctvCamera[camname][currentCameraIndex].canRotate then
				local getCameraRot = GetCamRot(createdCamera, 2)

				if IsControlPressed(1, 108) then
					SetCamRot(createdCamera, getCameraRot.x, 0.0, getCameraRot.z + 0.7, 2)
				end

				if IsControlPressed(1,107) then
					SetCamRot(createdCamera, getCameraRot.x, 0.0, getCameraRot.z - 0.7, 2)
				end

			elseif Config.CctvCamera[camname][currentCameraIndex].canRotate then
				local getCameraRot = GetCamRot(createdCamera, 2)

				if IsControlPressed(1, 108) then
					SetCamRot(createdCamera, getCameraRot.x, 0.0, getCameraRot.z + 0.7, 2)
				end

				if IsControlPressed(1,107) then
					SetCamRot(createdCamera, getCameraRot.x, 0.0, getCameraRot.z - 0.7, 2)
				end
			end

		end
		Citizen.Wait(time)
	end
end)

function ChangeSecurityCamera(x, y, z, r)
	if createdCamera ~= 0 then
		DestroyCam(createdCamera, 0)
		createdCamera = 0
	end

	local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", 1)
	SetCamCoord(cam, x, y, z)
	SetCamRot(cam, r.x, r.y, r.z, 2)
	RenderScriptCams(1, 0, 0, 1, 1)

	createdCamera = cam
end

function CloseSecurityrdrCamera()
	blockbuttons = false
	DestroyCam(createdCamera, 0)
	RenderScriptCams(0, 0, 1, 1, 1)
	createdCamera = 0
	ClearTimecycleModifier("scanline_cam_cheap")
	SetFocusEntity(GetPlayerPed(PlayerId()))
    FreezeEntityPosition(PlayerPedId(), 0)
    -- OpenMenu("progressbar")
    -- TriggerEvent("BakiTelli_hackermenu:cl:getData","table")
	Citizen.Wait(50)
end

function CreateInstuctionScaleform(scaleform)
	local scaleform = RequestScaleformMovie(scaleform)

	while not HasScaleformMovieLoaded(scaleform) do
		Citizen.Wait(10)
	end

	PushScaleformMovieFunction(scaleform, "CLEAR_ALL")
	PopScaleformMovieFunctionVoid()

	PushScaleformMovieFunction(scaleform, "SET_CLEAR_SPACE")
	PushScaleformMovieFunctionParameterInt(200)
	PopScaleformMovieFunctionVoid()

	PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
	PushScaleformMovieFunctionParameterInt(0)
	PushScaleformMovieMethodParameterButtonName(GetControlInstructionalButton(0, 175, true))
	InstructionButtonMessage(Config.Langs["NextCam"])
	PopScaleformMovieFunctionVoid()

	PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
	PushScaleformMovieFunctionParameterInt(1)
	PushScaleformMovieMethodParameterButtonName(GetControlInstructionalButton(0, 174, true))
	InstructionButtonMessage(Config.Langs["PrevCam"])
	PopScaleformMovieFunctionVoid()

	PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
	PushScaleformMovieFunctionParameterInt(2)
	PushScaleformMovieMethodParameterButtonName(GetControlInstructionalButton(0, 177, true))
	InstructionButtonMessage(Config.Langs["Exit"])
	PopScaleformMovieFunctionVoid()

	PushScaleformMovieFunction(scaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
	PopScaleformMovieFunctionVoid()

	PushScaleformMovieFunction(scaleform, "SET_BACKGROUND_COLOUR")
	PushScaleformMovieFunctionParameterInt(0)
	PushScaleformMovieFunctionParameterInt(0)
	PushScaleformMovieFunctionParameterInt(0)
	PushScaleformMovieFunctionParameterInt(80)
	PopScaleformMovieFunctionVoid()

	return scaleform
end

function InstructionButtonMessage(text)
	BeginTextCommandScaleformString("STRING")
	AddTextComponentScaleform(text)
	EndTextCommandScaleformString()
end

Citizen.CreateThread(function()
	while true do
		local time = 1000
		if blockbuttons then
			time = 1
			DisableControlAction(2, 24, true)
			DisableControlAction(2, 257, true)
			DisableControlAction(2, 25, true)
			DisableControlAction(2, 263, true)
			DisableControlAction(2, 45, true)
			DisableControlAction(2, 22, true)
			DisableControlAction(2, 44, true)
			DisableControlAction(2, 37, true)
			DisableControlAction(2, 23, true)
			DisableControlAction(2, 288, true)
			DisableControlAction(2, 289, true)
			DisableControlAction(2, 170, true)
			DisableControlAction(2, 167, true)
			DisableControlAction(2, 168, true)
			DisableControlAction(2, 57, true)
		end
		Citizen.Wait(time)
	end
end)

function DrawText3Dkamera(x, y, z, text, scale)
	local onScreen, _x, _y = World3dToScreen2d(x, y, z)
	local pX, pY, pZ = table.unpack(GetGameplayCamCoords())

	SetTextScale(scale, scale)
	SetTextFont(4)
	SetTextProportional(1)
	SetTextEntry("STRING")
	SetTextCentre(1)
	SetTextColour(255, 255, 255, 215)

	AddTextComponentString(text)
	DrawText(_x, _y)

	local factor = (string.len(text)) / 330
	DrawRect(_x, _y + 0.0150, 0.0 + factor, 0.035, 41, 11, 41, 100)
end
function DrawText3Ds(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x,y,z)
    if onScreen then
        local factor = #text / 325
        SetTextScale(0.27, 0.27)
        SetTextFont(11)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry('STRING')
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        DrawRect(_x, _y + 0.0120, 0.006 + factor, 0.024, 0, 0, 0, 155)
    end
end

