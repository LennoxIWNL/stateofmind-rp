--- Garage, Services and Notes. Small apps that read or write one thing each.

local core = exports['som-core']

local lastEmergency = {}

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function clean(value, maxLength, keepLines)
    if type(value) ~= 'string' then return nil end

    local text = value:gsub('[<>]', '')
    text = text:gsub(keepLines and '[%z\1-\9\11-\31\127]' or '%c', ' ')
    text = text:gsub('^%s*(.-)%s*$', '%1')
    if text == '' then return nil end

    return text:sub(1, maxLength)
end

-- ---------------------------------------------------------------------------
-- Garage: where the character's own vehicles are. Read only.
-- ---------------------------------------------------------------------------

Phone.Register({
    id = 'garage', label = 'Garage', icon = 'car', colour = '#5e5ce6', order = 40,
    actions = {
        list = { fn = function(_, _, player)
            return { vehicles = MySQL.query.await(
                'SELECT plate, model, garage, state FROM som_vehicles WHERE citizenid = ? ORDER BY id LIMIT ?',
                { player.citizenid, Config.City.vehicleLimit }) or {} }
        end },
    },
})

-- ---------------------------------------------------------------------------
-- Services: who is around, and the one number everyone needs.
-- ---------------------------------------------------------------------------

Phone.Register({
    id = 'services', label = 'Services', icon = 'dispatch', colour = '#ff453a', order = 45,
    actions = {
        list = { fn = function()
            local jobs = core:getJobs()
            local rows = {}

            for _, service in ipairs(Config.City.services) do
                local def = jobs[service.job]
                if def then
                    local row = { job = service.job, label = service.label }
                    if service.showCount then row.onDuty = #core:getPlayersByJob(service.job, true) end
                    rows[#rows + 1] = row
                end
            end

            return { services = rows }
        end },
        emergency = { writes = true, fn = function(source, payload, player)
            local message = clean(payload.message, Config.City.emergencyLength)
            if not message or #message < 3 then return done(false, 'say what is happening') end

            if os.time() - (lastEmergency[source] or 0) < Config.City.emergencyGapSeconds then
                return done(false, 'you have already called that in')
            end

            local id = exports['som-dispatch']:alert(source, 'emergencyCall', {
                message = ('911: %s'):format(message),
                information = ('Caller: %s %s, %s'):format(player.charinfo.firstname, player.charinfo.lastname, player.charinfo.phone),
            })
            if not id then return done(false, 'that could not be sent') end

            lastEmergency[source] = os.time()
            return { success = true }
        end },
    },
})

AddEventHandler('som:server:playerUnloaded', function(source) lastEmergency[source] = nil end)

-- ---------------------------------------------------------------------------
-- Notes: private to the character.
-- ---------------------------------------------------------------------------

Phone.Register({
    id = 'notes', label = 'Notes', icon = 'note', colour = '#ffd60a', order = 50,
    actions = {
        list = { fn = function(_, _, player)
            return { notes = MySQL.query.await(
                'SELECT id, title, body FROM som_phone_notes WHERE citizenid = ? ORDER BY updated_at DESC, id DESC LIMIT ?',
                { player.citizenid, Config.City.notes.max }) or {} }
        end },
        save = { writes = true, fn = function(_, payload, player)
            local title = clean(payload.title, Config.City.notes.titleLength)
            local body = clean(payload.body, Config.City.notes.bodyLength, true) or ''
            if not title then return done(false, 'give the note a title') end

            if payload.id ~= nil then
                local id = math.floor(tonumber(payload.id) or 0)
                local changed = MySQL.update.await(
                    'UPDATE som_phone_notes SET title = ?, body = ? WHERE id = ? AND citizenid = ?',
                    { title, body, id, player.citizenid })
                return changed == 1 and { success = true, id = id } or done(false, 'no such note')
            end

            if (MySQL.scalar.await('SELECT COUNT(*) FROM som_phone_notes WHERE citizenid = ?', { player.citizenid }) or 0) >= Config.City.notes.max then
                return done(false, 'you have too many notes')
            end

            return { success = true, id = MySQL.insert.await(
                'INSERT INTO som_phone_notes (citizenid, title, body) VALUES (?, ?, ?)', { player.citizenid, title, body }) }
        end },
        remove = { writes = true, fn = function(_, payload, player)
            local id = math.floor(tonumber(payload.id) or 0)
            local gone = MySQL.update.await('DELETE FROM som_phone_notes WHERE id = ? AND citizenid = ?', { id, player.citizenid })
            return gone == 1 and { success = true } or done(false, 'no such note')
        end },
    },
})
