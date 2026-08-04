-- The player object and its registry.
--
-- Nothing in here trusts a client. Every setter is called from server code,
-- and the only way a client influences state is by requesting an action that
-- server logic then validates and performs.

Players = {}

local bySource = {}
local bySlug = {}

local PlayerMethods = {}
PlayerMethods.__index = PlayerMethods

-- ---------------------------------------------------------------------------
-- State replication
--
-- Replicated state bags are the subscribe mechanism the rebuild spec asks for:
-- job, gang, and economy consumers read player state without polling.
-- Keys are namespaced som: and are read-only to clients.
-- ---------------------------------------------------------------------------

---Normalises a DATE column into something readable.
---
---oxmysql hands a MySQL DATE back as epoch MILLISECONDS, so passing it straight
---through printed 1217721600000 wherever a date of birth was shown: the MDT,
---the ID card and the character selector all had the same number.
---
---Accepts what the driver actually returns rather than assuming: a number, an
---ISO string, or something already formatted. Anything unrecognised comes back
---untouched rather than becoming nil, because a slightly wrong date is better
---than a blank field.
---@param value any
---@return string|nil
function SomFormatDate(value)
    if value == nil then return nil end

    if type(value) == 'number' then
        -- Milliseconds, and os.date wants seconds.
        return os.date('%d/%m/%Y', math.floor(value / 1000))
    end

    if type(value) == 'string' then
        local y, m, d = value:match('^(%d%d%d%d)-(%d%d)-(%d%d)')
        if y then return ('%s/%s/%s'):format(d, m, y) end

        return value
    end

    return tostring(value)
end

function PlayerMethods:syncState()
    local state = Player(self.source).state

    state:set('som:citizenid', self.citizenid, true)

    -- `label` and `gradeLabel` are included deliberately.
    --
    -- som:client:playerLoaded sends the FULL job table, but the client's
    -- statebag handler then REPLACES PlayerData.job with whatever is in this
    -- bag. Anything omitted here is therefore stripped from the client a moment
    -- after it arrives, which is how ps-mdt ended up concatenating a nil
    -- job.grade.name and never rendering past "Welcome, loading...".
    --
    -- Both are display strings that are already public (a uniform announces
    -- them), so replicating them costs nothing in privacy terms. Pay and
    -- business stay off the bag: those are not the client's business.
    state:set('som:job', {
        name = self.job.name,
        label = self.job.label,
        grade = self.job.grade,
        gradeLabel = self.job.gradeLabel,
        onduty = self.job.onduty,
        type = self.job.type,
        isboss = self.job.isboss,
    }, true)
    state:set('som:gang', {
        name = self.gang.name,
        label = self.gang.label,
        grade = self.gang.grade,
        gradeLabel = self.gang.gradeLabel,
        isboss = self.gang.isboss,
    }, true)

    -- Money is replicated to the owning client only, never broadcast, so other
    -- clients cannot read a player's balance from their own state bag.
    TriggerClientEvent('som:client:setMoney', self.source, self.money)
    TriggerClientEvent('som:client:setMetadata', self.source, self.metadata)
end

-- ---------------------------------------------------------------------------
-- Job and gang
-- ---------------------------------------------------------------------------

---@param name string
---@param grade number|nil defaults to 0
---@return boolean success, string|nil err
function PlayerMethods:setJob(name, grade)
    if type(name) ~= 'string' then return false, 'invalid job name' end

    local job = Jobs[name]
    if not job then return false, ('unknown job %s'):format(name) end

    grade = tonumber(grade) or 0
    local gradeData = job.grades[grade]
    if not gradeData then return false, ('job %s has no grade %s'):format(name, grade) end

    self.job = {
        name = name,
        label = job.label,
        type = job.type,
        grade = grade,
        gradeLabel = gradeData.name,
        isboss = gradeData.isboss or false,
        payment = gradeData.payment or 0,
        onduty = job.defaultDuty ~= false,
        business = job.business,
        armoryGrade = job.armoryGrade,
        radio = job.radio,
    }

    self:syncState()
    TriggerEvent('som:server:jobChanged', self.source, self.citizenid, self.job)
    return true
end

---@param name string
---@param grade number|nil
---@return boolean success, string|nil err
function PlayerMethods:setGang(name, grade)
    if type(name) ~= 'string' then return false, 'invalid gang name' end

    local gang = Gangs[name]
    if not gang then return false, ('unknown gang %s'):format(name) end

    grade = tonumber(grade) or 0
    local gradeData = gang.grades[grade]
    if not gradeData then return false, ('gang %s has no grade %s'):format(name, grade) end

    self.gang = {
        name = name,
        label = gang.label,
        grade = grade,
        gradeLabel = gradeData.name,
        isboss = gradeData.isboss or false,
        payment = gradeData.payment or 0,
        color = gang.color,
    }

    self:syncState()
    TriggerEvent('som:server:gangChanged', self.source, self.citizenid, self.gang)
    return true
end

---@param onduty boolean
function PlayerMethods:setDuty(onduty)
    if type(onduty) ~= 'boolean' then return false, 'duty must be a boolean' end

    self.job.onduty = onduty
    self:syncState()
    TriggerEvent('som:server:dutyChanged', self.source, self.citizenid, self.job.name, onduty)
    return true
end

---@param minGrade number
---@return boolean
function PlayerMethods:hasJobGrade(jobName, minGrade)
    return self.job.name == jobName and self.job.grade >= (tonumber(minGrade) or 0)
end

-- ---------------------------------------------------------------------------
-- Metadata
--
-- Only keys declared in Config.DefaultMetadata are accepted, and numeric keys
-- are clamped to Config.MetadataBounds. A caller cannot invent state or push a
-- value out of range, whether it is buggy job code or a compromised resource.
-- ---------------------------------------------------------------------------

---@param key string
---@param value any
---@return boolean success, string|nil err
function PlayerMethods:setMetadata(key, value)
    if type(key) ~= 'string' then return false, 'metadata key must be a string' end
    if Config.DefaultMetadata[key] == nil and key ~= 'fingerprint' and key ~= 'callsign' then
        return false, ('unknown metadata key %s'):format(key)
    end

    local bounds = Config.MetadataBounds[key]
    if bounds then
        local num = tonumber(value)
        if not num then return false, ('metadata %s must be numeric'):format(key) end
        if num < bounds[1] then num = bounds[1] end
        if num > bounds[2] then num = bounds[2] end
        value = num
    end

    self.metadata[key] = value
    TriggerClientEvent('som:client:setMetadata', self.source, self.metadata)
    TriggerEvent('som:server:metadataChanged', self.source, self.citizenid, key, value)
    return true
end

---@param key string|nil returns the whole table when omitted
function PlayerMethods:getMetadata(key)
    if key == nil then return self.metadata end
    return self.metadata[key]
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

function PlayerMethods:save()
    local ped = GetPlayerPed(self.source)
    if ped and ped ~= 0 then
        local coords = GetEntityCoords(ped)
        self.position = { x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped) }
    end

    MySQL.update.await([[
        UPDATE som_characters SET
            job = ?, job_grade = ?, job_duty = ?,
            gang = ?, gang_grade = ?,
            position = ?, metadata = ?
        WHERE citizenid = ?
    ]], {
        self.job.name, self.job.grade, self.job.onduty and 1 or 0,
        self.gang.name, self.gang.grade,
        json.encode(self.position), json.encode(self.metadata),
        self.citizenid,
    })
end

-- ---------------------------------------------------------------------------
-- Registry
-- ---------------------------------------------------------------------------

---Builds a live player object from a character row and registers it.
---@param source number
---@param row table som_characters row
---@param money table som_character_money row
---@return table player
function Players.Create(source, row, money)
    local charinfo = {
        firstname = row.firstname,
        lastname = row.lastname,
        dob = SomFormatDate(row.dob),
        gender = row.gender,
        nationality = row.nationality,
        phone = row.phone,
    }

    local metadata = row.metadata and json.decode(row.metadata) or {}
    for key, value in pairs(Config.DefaultMetadata) do
        if metadata[key] == nil then
            metadata[key] = type(value) == 'table' and {} or value
        end
    end

    local self = setmetatable({
        source = source,
        license = row.license,
        citizenid = row.citizenid,
        slot = row.slot,
        charinfo = charinfo,
        metadata = metadata,
        position = row.position and json.decode(row.position) or nil,
        money = {
            cash = money and money.cash or 0,
            bank = money and money.bank or 0,
            crypto = money and money.crypto or 0,
            dirty = money and money.dirty or 0,
        },
        job = {},
        gang = {},
    }, PlayerMethods)

    -- setJob/setGang validate against config, so a job that was removed from
    -- config since the character last played falls back rather than erroring.
    if not self:setJob(row.job, row.job_grade) then
        self:setJob('unemployed', 0)
    end
    if not self:setGang(row.gang, row.gang_grade) then
        self:setGang('none', 0)
    end
    self.job.onduty = row.job_duty == 1

    bySource[source] = self
    bySlug[row.citizenid] = self

    self:syncState()
    return self
end

---@param source number
---@return table|nil
function Players.Get(source)
    return bySource[tonumber(source) or 0]
end

---@param citizenid string
---@return table|nil
function Players.GetByCitizenId(citizenid)
    return bySlug[citizenid]
end

---@param license string
---@return table|nil
function Players.GetByLicense(license)
    for _, player in pairs(bySource) do
        if player.license == license then return player end
    end
    return nil
end

---@return table[] all loaded players
function Players.GetAll()
    local list = {}
    for _, player in pairs(bySource) do
        list[#list + 1] = player
    end
    return list
end

---@param jobName string
---@param onlyOnDuty boolean|nil
---@return table[]
function Players.GetByJob(jobName, onlyOnDuty)
    local list = {}
    for _, player in pairs(bySource) do
        if player.job.name == jobName and (not onlyOnDuty or player.job.onduty) then
            list[#list + 1] = player
        end
    end
    return list
end

---@param gangName string
---@return table[]
function Players.GetByGang(gangName)
    local list = {}
    for _, player in pairs(bySource) do
        if player.gang.name == gangName then list[#list + 1] = player end
    end
    return list
end

function Players.Remove(source)
    local player = bySource[source]
    if not player then return end

    bySlug[player.citizenid] = nil
    bySource[source] = nil
end
