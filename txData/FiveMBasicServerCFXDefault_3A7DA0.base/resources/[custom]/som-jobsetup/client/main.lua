local QBCore = exports['qb-core']:GetCoreObject()

local points = {}
local spawned = {}
local markerOn = {}
local showCoords = false

local function vec(p) return vector3(p.coords.x + 0.0, p.coords.y + 0.0, p.coords.z + 0.0) end

local function zoneName(id) return ('som_js_%s'):format(id) end

local function runAction(point)
    local a = point.action
    if not a or not a.kind or not a.name then return end
    if a.kind == 'event' then
        TriggerEvent(a.name, a.args)
    elseif a.kind == 'server_event' then
        TriggerServerEvent(a.name, a.args)
    elseif a.kind == 'command' then
        ExecuteCommand(a.name)
    elseif a.kind == 'export' and a.resource then
        local ok = pcall(function() exports[a.resource][a.name](exports[a.resource], a.args) end)
        if not ok then pcall(function() exports[a.resource][a.name](a.args) end) end
    end
end

local function clearPoint(id)
    local s = spawned[id]
    if not s then return end
    if s.blip and DoesBlipExist(s.blip) then RemoveBlip(s.blip) end
    if s.ped and DoesEntityExist(s.ped) then DeleteEntity(s.ped) end
    if s.zoneName then exports['qb-target']:RemoveZone(s.zoneName) end
    spawned[id] = nil
end

local function clearAll()
    for id in pairs(spawned) do clearPoint(id) end
end

local function renderPoint(point)
    clearPoint(point.id)
    local s = {}
    local coords = vec(point)
    local typeDef = Config.Types[point.type] or {}

    local blipCfg = point.blip or typeDef.blip
    if blipCfg then
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, blipCfg.sprite or 1)
        SetBlipColour(blip, blipCfg.color or 0)
        SetBlipScale(blip, blipCfg.scale or 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(point.label or typeDef.label or point.job)
        EndTextCommandSetBlipName(blip)
        s.blip = blip
    end

    local pedModel = point.ped or typeDef.ped
    if pedModel then
        local hash = type(pedModel) == 'number' and pedModel or GetHashKey(pedModel)
        RequestModel(hash)
        local t = 0
        while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
        if HasModelLoaded(hash) then
            local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, point.heading or 0.0, false, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            s.ped = ped
            SetModelAsNoLongerNeeded(hash)
        end
    end

    local hasAction = (point.action and point.action.kind) and true or false
    if hasAction or point.type ~= 'blip' then
        local zn = zoneName(point.id)
        exports['qb-target']:AddCircleZone(zn, coords, (point.radius or 1.5) + 0.0,
            { name = zn, useZ = true, debugPoly = false },
            {
                options = { {
                    icon = (point.targetIcon or typeDef.targetIcon or 'fas fa-hand-pointer'),
                    label = (point.targetLabel or typeDef.targetLabel or 'Interact'),
                    job = point.restrictJob and point.job or nil,
                    action = function() runAction(point) end,
                    canInteract = function() return true end,
                } },
                distance = Config.TargetDistance,
            })
        s.zoneName = zn
    end

    spawned[point.id] = s
end

local function renderAll()
    clearAll()
    for _, p in pairs(points) do renderPoint(p) end
end

RegisterNetEvent('som-jobsetup:client:sync', function(list)
    points = {}
    for _, p in ipairs(list) do points[p.id] = p end
    renderAll()
end)

CreateThread(function()
    while true do
        local sleep = 500
        if showCoords or next(markerOn) then
            local ped = PlayerPedId()
            local pc = GetEntityCoords(ped)
            for id, on in pairs(markerOn) do
                local p = points[id]
                if on and p then
                    local c = vec(p)
                    if #(pc - c) < Config.MarkerDrawDistance then
                        sleep = 0
                        DrawMarker(Config.Marker.type, c.x, c.y, c.z - 0.95, 0, 0, 0, 0, 0, 0,
                            Config.Marker.size.x, Config.Marker.size.y, Config.Marker.size.z,
                            Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
                            false, true, 2, nil, nil, false)
                    end
                end
            end
            if showCoords then
                sleep = 0
                local h = GetEntityHeading(ped)
                local txt = ('~q~SoM ~w~Coords: ~q~%.2f~w~, ~q~%.2f~w~, ~q~%.2f~w~  Head: ~q~%.2f'):format(pc.x, pc.y, pc.z, h)
                SetTextFont(4); SetTextScale(0.42, 0.42); SetTextColour(255, 255, 255, 220)
                SetTextOutline(); SetTextEntry('STRING')
                AddTextComponentString(txt)
                DrawText(0.5, 0.92)
            end
        end
        Wait(sleep)
    end
end)

local function captureHere()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    return { x = math.floor(c.x * 100) / 100, y = math.floor(c.y * 100) / 100, z = math.floor(c.z * 100) / 100 },
           math.floor(GetEntityHeading(ped) * 100) / 100
end

local function typeOptions()
    local opts = {}
    for k, v in pairs(Config.Types) do opts[#opts + 1] = { value = k, label = v.label } end
    table.sort(opts, function(a, b) return a.label < b.label end)
    return opts
end

local function jobOptions()
    local opts = {}
    for _, j in ipairs(Config.Jobs) do opts[#opts + 1] = j end
    return opts
end

local function addPointDialog()
    local coords, heading = captureHere()
    local input = lib.inputDialog('New Interaction Point', {
        { type = 'input',  label = 'Label', required = true, default = 'New Point' },
        { type = 'select', label = 'Job', options = (function()
            local o = {} for _, j in ipairs(jobOptions()) do o[#o + 1] = { value = j, label = j } end
            o[#o + 1] = { value = '__custom', label = '(type a custom job below)' } return o end)(),
            default = jobOptions()[1] },
        { type = 'input',  label = 'Custom job (optional)', description = 'Used only if you picked "custom job"' },
        { type = 'select', label = 'Type', options = typeOptions(), required = true },
        { type = 'number', label = 'Radius (m)', default = 1.5, min = 0.5, max = 10, step = 0.5 },
        { type = 'checkbox', label = 'Restrict interaction to this job' },
    })
    if not input then return end
    local job = input[2]
    if job == '__custom' then job = (input[3] ~= '' and input[3]) or 'unknown' end
    local point = {
        label = input[1],
        job = job,
        type = input[4],
        radius = input[5] + 0.0,
        restrictJob = input[6] and true or false,
        coords = coords,
        heading = heading,
    }
    TriggerServerEvent('som-jobsetup:server:save', point)
end

local function actionDialog(point)
    local input = lib.inputDialog(('Action for "%s"'):format(point.label), {
        { type = 'select', label = 'Trigger kind', required = true, default = (point.action and point.action.kind) or 'event',
          options = {
            { value = 'event', label = 'Client event (TriggerEvent)' },
            { value = 'server_event', label = 'Server event (TriggerServerEvent)' },
            { value = 'command', label = 'Console command (ExecuteCommand)' },
            { value = 'export', label = 'Export call' },
            { value = 'none', label = 'No action (blip/ped only)' },
          } },
        { type = 'input', label = 'Event / command / export name', default = (point.action and point.action.name) or '',
          description = 'e.g. qb-garages:client:OpenMenu  OR  police:toggleduty' },
        { type = 'input', label = 'Export resource (export kind only)', default = (point.action and point.action.resource) or '' },
        { type = 'input', label = 'Args (string, optional)', default = (point.action and tostring(point.action.args or '')) or '' },
    })
    if not input then return end
    if input[1] == 'none' then
        point.action = nil
    else
        point.action = { kind = input[1], name = input[2], resource = (input[3] ~= '' and input[3] or nil),
                         args = (input[4] ~= '' and input[4] or nil) }
    end
    TriggerServerEvent('som-jobsetup:server:save', point)
end

local function managePointMenu(point)
    lib.registerContext({
        id = 'som_js_point',
        title = ('%s  [%s]'):format(point.label or point.type, point.job or '-'),
        menu = 'som_js_list',
        options = {
            { title = 'Teleport to point', icon = 'location-arrow', onSelect = function()
                SetEntityCoords(PlayerPedId(), vec(point).x, vec(point).y, vec(point).z, false, false, false, false)
                SetEntityHeading(PlayerPedId(), point.heading or 0.0)
            end },
            { title = 'Move point to me (update coords)', icon = 'person-walking-arrow-right', onSelect = function()
                local c, h = captureHere()
                point.coords, point.heading = c, h
                TriggerServerEvent('som-jobsetup:server:save', point)
            end },
            { title = 'Set / edit action', icon = 'bolt',
              description = point.action and ('%s: %s'):format(point.action.kind, point.action.name) or 'none',
              onSelect = function() actionDialog(point) end },
            { title = (markerOn[point.id] and 'Hide marker' or 'Show marker'), icon = 'location-dot', onSelect = function()
                markerOn[point.id] = not markerOn[point.id]
                managePointMenu(point)
            end },
            { title = 'Delete point', icon = 'trash', onSelect = function()
                local ok = lib.alertDialog({ header = 'Delete?', content = ('Delete "%s"?'):format(point.label or point.type),
                    centered = true, cancel = true })
                if ok == 'confirm' then TriggerServerEvent('som-jobsetup:server:delete', point.id) end
            end },
        }
    })
    lib.showContext('som_js_point')
end

local function listMenu()
    local options = {}
    local sorted = {}
    for _, p in pairs(points) do sorted[#sorted + 1] = p end
    table.sort(sorted, function(a, b) return (a.job or '') .. (a.label or '') < (b.job or '') .. (b.label or '') end)
    for _, p in ipairs(sorted) do
        options[#options + 1] = {
            title = p.label or p.type,
            description = ('%s · %s · %.1f,%.1f,%.1f'):format(p.job or '-', p.type, p.coords.x, p.coords.y, p.coords.z),
            icon = 'map-pin',
            onSelect = function() managePointMenu(p) end,
        }
    end
    if #options == 0 then options[1] = { title = 'No points yet', disabled = true } end
    lib.registerContext({ id = 'som_js_list', title = 'Manage Points', menu = 'som_js_main', options = options })
    lib.showContext('som_js_list')
end

local jobLocCache = {}

RegisterNetEvent('som-jobsetup:client:jobLocations', function(resource, list)
    jobLocCache[resource] = list
end)

local function existingFor(resource, locType)
    local out = {}
    for _, e in ipairs(jobLocCache[resource] or {}) do
        if e.type == locType then out[e.index] = e.coords end
    end
    return out
end

local function patchDialog(resource, locType, locDef, jc)
    local existing = existingFor(resource, locType)
    local idxOpts, maxIdx = {}, 0
    for i, coords in pairs(existing) do
        idxOpts[#idxOpts + 1] = { value = tostring(i), label = ('#%d  (%s)'):format(i, coords) }
        if i > maxIdx then maxIdx = i end
    end
    table.sort(idxOpts, function(a, b) return a.label < b.label end)
    if not locDef.nested then
        idxOpts[#idxOpts + 1] = { value = 'new', label = ('+ new (#%d)'):format(maxIdx + 1) }
    end
    if #idxOpts == 0 then idxOpts[1] = { value = '1', label = '#1' } end

    local c, h = captureHere()
    local input = lib.inputDialog(('%s · %s'):format(jc.label, locDef.label or locType), {
        { type = 'select', label = 'Which slot to set', required = true, options = idxOpts, default = idxOpts[1].value,
          description = 'Pick an existing slot to MOVE it, or "+ new" to add one' },
        { type = 'number', label = 'Index (if "+ new")', default = maxIdx + 1, min = 1, step = 1 },
        { type = 'checkbox', label = 'Restart the job now (apply live)', checked = jc.restart and true or false,
          description = 'Restarts ' .. resource .. ' so the change takes effect immediately' },
    })
    if not input then return end
    local index = input[1] == 'new' and math.floor(input[2]) or tonumber(input[1])
    local ok = lib.alertDialog({
        header = 'Confirm write',
        content = ('Write **%s** `[%s][%d]` =\n`%s`\n\nat your feet (%.2f, %.2f, %.2f, %.1f)?\n\nA backup of the config is saved first.')
            :format(resource, locType, index, locDef.label or locType, c.x, c.y, c.z, h),
        centered = true, cancel = true,
    })
    if ok ~= 'confirm' then return end
    TriggerServerEvent('som-jobsetup:server:patchJobLocation', {
        resource = resource, locType = locType, index = index,
        x = c.x, y = c.y, z = c.z, h = h, restart = input[3] and true or false,
    })
end

local function jobLocTypeMenu(resource, jc)
    TriggerServerEvent('som-jobsetup:server:getJobLocations', resource)
    local options = {}
    local keys = {}
    for k in pairs(jc.locations) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local def = jc.locations[k]
        local existing = existingFor(resource, k)
        local count = 0 for _ in pairs(existing) do count = count + 1 end
        options[#options + 1] = {
            title = def.label or k,
            description = ('%s · %d slot(s) · arity %d%s'):format(k, count, def.arity, def.nested and ' · nested' or ''),
            icon = 'location-crosshairs',
            onSelect = function() patchDialog(resource, k, def, jc) end,
        }
    end
    lib.registerContext({ id = 'som_js_jobloc', title = jc.label, menu = 'som_js_jobs', options = options })
    lib.showContext('som_js_jobloc')
end

local function jobConfigMenu()
    local options = {}
    for resource, jc in pairs(Config.JobConfigs) do
        TriggerServerEvent('som-jobsetup:server:getJobLocations', resource)
        options[#options + 1] = {
            title = jc.label, icon = 'screwdriver-wrench', arrow = true,
            description = 'Write coords into ' .. resource .. '/' .. jc.file,
            onSelect = function() jobLocTypeMenu(resource, jc) end,
        }
    end
    if #options == 0 then options[1] = { title = 'No job configs defined', disabled = true } end
    lib.registerContext({ id = 'som_js_jobs', title = 'Set up Job Interactions', menu = 'som_js_main', options = options })
    lib.showContext('som_js_jobs')
end

local function mainMenu()
    lib.registerContext({
        id = 'som_js_main',
        title = 'State of Mind · Job Setup',
        options = {
            { title = 'Set up Job interactions (PD / EMS configs)', icon = 'screwdriver-wrench', arrow = true,
              description = 'Move garage, duty, armory, fingerprint, check-in, beds straight into the job config',
              onSelect = jobConfigMenu },
            { title = 'Add custom interaction point (here)', icon = 'plus',
              description = 'Capture your current position as a new managed point', onSelect = addPointDialog },
            { title = 'Manage custom points', icon = 'list', description = ('%d point(s)'):format((function()
                local n = 0 for _ in pairs(points) do n = n + 1 end return n end)()), onSelect = listMenu },
            { title = (showCoords and 'Hide live coords' or 'Show live coords'), icon = 'crosshairs', onSelect = function()
                showCoords = not showCoords; mainMenu() end },
            { title = 'Export points (to console)', icon = 'file-export',
              description = 'Print the points JSON to F8 console', onSelect = function()
                TriggerServerEvent('som-jobsetup:server:export') end },
        }
    })
    lib.showContext('som_js_main')
end

RegisterCommand(Config.Command, function() mainMenu() end, false)

RegisterNetEvent('som-jobsetup:client:export', function(raw)
    print('^5[som-jobsetup]^7 ===== points.json =====')
    print(raw)
    print('^5[som-jobsetup]^7 ======================')
    lib.notify({ title = 'Job Setup', description = 'Points JSON printed to F8 console', type = 'inform' })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearAll() end
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('som-jobsetup:server:requestSync')
end)
