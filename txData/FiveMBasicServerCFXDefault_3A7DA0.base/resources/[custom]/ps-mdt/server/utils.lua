local QBCore = exports['qb-core']:GetCoreObject()

function GetPlayerData(source)
	local Player = QBCore.Functions.GetPlayer(source)
	if Player == nil then return end -- Player not loaded in correctly
	return Player.PlayerData
end

function UnpackJob(data)
	local job = {
		name = data.name,
		label = data.label
	}
	local grade = {
		name = data.grade.name,
	}

	return job, grade
end

function PermCheck(src, PlayerData)
	local result = true

	if not Config.AllowedJobs[PlayerData.job.name] then
		print(("UserId: %s(%d) tried to access the mdt even though they are not authorised (server direct)"):format(GetPlayerName(src), src))
		result = false
	end

	return result
end

-- SOM stores gender as a TINYINT (0 male, 1 female) where qb used "m"/"f".
-- It arrives here as a number through the `players` view's JSON_OBJECT and as a
-- string through JSON_VALUE, so all three encodings are accepted. Comparing
-- against "f" alone matched nothing and every profile fell back to male.
function ProfPic(gender, profilepic)
	if profilepic then return profilepic end;
	if gender == 1 or gender == "1" or gender == "f" then return "img/female.png" end;
	return "img/male.png"
end

function IsJobAllowedToMDT(job)
	if Config.PoliceJobs[job] then
		return true
	elseif Config.AmbulanceJobs[job] then
		return true
	elseif Config.DojJobs[job] then
		return true
	else
		return false
	end
end

function GetNameFromPlayerData(PlayerData)
	return ('%s %s'):format(PlayerData.charinfo.firstname, PlayerData.charinfo.lastname)
end
