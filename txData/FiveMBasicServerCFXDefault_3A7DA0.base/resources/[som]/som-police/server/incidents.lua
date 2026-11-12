-- Per-person roles on an MDT incident.
--
-- ps-mdt records the people on an incident as two JSON blobs of display
-- strings, with no citizen id and no per-person field, so it cannot say who was
-- the victim and who was the suspect. This owns that one missing fact.
--
-- It deliberately owns NOTHING else about an incident. The incident itself, its
-- narrative, its evidence and its convictions all stay in ps-mdt's own tables
-- and are not touched here. This is a junction table beside them, which is why
-- it can exist without patching ps-mdt's server at all.
--
-- Everything below is reachable from a NUI relay in ps-mdt's client, which is
-- to say from an untrusted client. Nothing here trusts a job, a rank or a role
-- that arrives in the payload.

-- The whole vocabulary. Client-sent roles are checked against this and nothing
-- else, so a crafted NUI message cannot invent one. The database column is an
-- ENUM over the same list, which is the second lock rather than the first.
local ROLES = {
    victim      = 'Victim',
    suspect     = 'Suspect',
    witness     = 'Witness',
    complainant = 'Complainant',
    reporting   = 'Reporting Party',
}

---Officers who may assign roles. Writing a role is a records act, not a street
---act, so it needs the job but NOT duty: an officer writing up an incident at
---the end of a shift is the normal case.
---@param source number
---@return table|nil officer, string|nil err
local function writer(source)
    return Police.Officer(source, false)
end

---@param id any
---@return number|nil
local function incidentId(id)
    id = tonumber(id)
    if not id or id ~= id or id < 1 or id % 1 ~= 0 then return nil end
    -- Bounded to INT UNSIGNED. Past that MySQL errors on the out-of-range value
    -- rather than simply not matching, which turns a junk id into a thrown
    -- query instead of an empty result.
    if id > 4294967295 then return nil end
    return id
end

---Confirms a citizen id belongs to a real character.
---
---Without this the table would happily accept a typo or a crafted id and hold a
---role for somebody who does not exist. It also makes the VARCHAR(16) column
---safe: an over-long id fails this lookup rather than being truncated into a
---collision with a real one.
---@param citizenid any
---@return boolean
local function characterExists(citizenid)
    if type(citizenid) ~= 'string' or #citizenid < 1 or #citizenid > 16 then return false end

    return MySQL.scalar.await(
        'SELECT 1 FROM som_characters WHERE citizenid = ? AND deleted = 0',
        { citizenid }
    ) ~= nil
end

---Everyone with a recorded role on an incident, with names for display.
---
---Names are joined from som_characters rather than read back from ps-mdt's
---display strings, so a character who has since changed name reads correctly
---and a deleted one simply drops out.
lib.callback.register('som-police:server:incidentPeople', function(source, data)
    local officer = writer(source)
    if not officer then return { success = false, error = 'not an officer' } end

    local id = incidentId(type(data) == 'table' and data.incidentId or nil)
    if not id then return { success = false, error = 'bad incident' } end

    local rows = MySQL.query.await([[
        SELECT p.citizenid, p.role, c.firstname, c.lastname
        FROM som_incident_people p
        LEFT JOIN som_characters c ON c.citizenid = p.citizenid
        WHERE p.incident_id = ?
        ORDER BY p.role, c.lastname, c.firstname
    ]], { id }) or {}

    local people = {}

    for i = 1, #rows do
        local row = rows[i]

        people[i] = {
            citizenid = row.citizenid,
            role = row.role,
            roleLabel = ROLES[row.role] or row.role,
            name = (row.firstname and row.lastname)
                and ('%s %s'):format(row.firstname, row.lastname)
                or 'Unknown',
        }
    end

    -- The catalogue travels with the answer so the panel renders the same
    -- vocabulary the server enforces, rather than keeping its own copy that can
    -- drift out of step with this one.
    local roles = {}
    for id2, label in pairs(ROLES) do roles[#roles + 1] = { id = id2, label = label } end
    table.sort(roles, function(a, b) return a.label < b.label end)

    return { success = true, people = people, roles = roles }
end)

---Assign or move a person's role on an incident. Upsert: one person holds one
---role per incident, so setting it again moves it rather than stacking a row.
lib.callback.register('som-police:server:setIncidentRole', function(source, data)
    local officer = writer(source)
    if not officer then return { success = false, error = 'not an officer' } end
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local id = incidentId(data.incidentId)
    if not id then return { success = false, error = 'save the incident first' } end

    local citizenid = data.citizenid
    if not characterExists(citizenid) then return { success = false, error = 'no such citizen' } end

    local role = data.role
    if type(role) ~= 'string' or not ROLES[role] then
        return { success = false, error = 'no such role' }
    end

    MySQL.query.await([[
        INSERT INTO som_incident_people (incident_id, citizenid, role, added_by)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE role = VALUES(role)
    ]], { id, citizenid, role, officer.citizenid })

    return { success = true, role = role, roleLabel = ROLES[role] }
end)

---Take a person off an incident entirely.
lib.callback.register('som-police:server:removeIncidentPerson', function(source, data)
    local officer = writer(source)
    if not officer then return { success = false, error = 'not an officer' } end
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local id = incidentId(data.incidentId)
    if not id then return { success = false, error = 'bad incident' } end
    if type(data.citizenid) ~= 'string' then return { success = false, error = 'bad citizen id' } end

    MySQL.query.await(
        'DELETE FROM som_incident_people WHERE incident_id = ? AND citizenid = ?',
        { id, data.citizenid }
    )

    return { success = true }
end)

---Roles recorded against a character, newest first. For the profile panel and
---for anything later that wants "what has this person been involved in".
---@param citizenid string
---@return table
function Police.IncidentRolesFor(citizenid)
    if type(citizenid) ~= 'string' then return {} end

    return MySQL.query.await([[
        SELECT incident_id, role, created
        FROM som_incident_people
        WHERE citizenid = ?
        ORDER BY created DESC
        LIMIT 50
    ]], { citizenid }) or {}
end

exports('incidentRolesFor', Police.IncidentRolesFor)

-- There is no foreign key onto mdt_incidents, by the reasoning in setup.sql, so
-- a deleted incident would otherwise leave its people behind forever. ps-mdt
-- deletes incidents through its own event, which this listens for rather than
-- patching.
-- Note the plural. ps-mdt spells it `deleteIncidents` for a single id
-- (server/main.lua:762). Listening for the singular would have compiled,
-- registered and simply never fired, which is the failure mode AUDIT 21.2
-- describes: a handler on the wrong name does not error, it just never runs.
local deleting = {}
local lastDelete = {}

AddEventHandler('playerDropped', function() lastDelete[source] = nil end)

RegisterNetEvent('mdt:server:deleteIncidents', function(id)
    local src = source
    local incident = incidentId(id)
    if not incident or deleting[incident] then return end

    -- Anybody can fire this event, and each id starts a thread and a query.
    local now = GetGameTimer()
    if lastDelete[src] and now - lastDelete[src] < 2000 then return end
    lastDelete[src] = now
    deleting[incident] = true

    -- This event is ps-mdt's, and ANY client can fire it with ANY id. ps-mdt
    -- checks rank before it deletes the incident, but this handler is a second,
    -- separate listener on the same event and gets no such protection: deleting
    -- unconditionally here would let any player wipe the role assignments off
    -- any incident in the database, which is real data loss even though no
    -- incident data is readable through this path.
    --
    -- Rather than duplicating ps-mdt's permission table, which would then have
    -- to be kept in step with it, the disappearance of the incident IS the
    -- authorisation. If ps-mdt refused the delete, the row is still there and
    -- nothing happens here.
    --
    -- The wait is because both handlers are on one event with no ordering
    -- guarantee, so this has to look after ps-mdt has had its turn.
    CreateThread(function()
        Wait(3000)

        local ok, stillThere = pcall(MySQL.scalar.await,
            'SELECT 1 FROM mdt_incidents WHERE id = ?', { incident }
        )
        deleting[incident] = nil
        if not ok or stillThere then return end

        MySQL.query.await('DELETE FROM som_incident_people WHERE incident_id = ?', { incident })
    end)
end)
