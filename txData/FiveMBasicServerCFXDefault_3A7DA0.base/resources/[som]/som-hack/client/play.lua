--- Shows a challenge and forwards answers. It never decides whether an answer
--- is right: the server holds the solution and sends back only feedback.

local playing, token = nil, 0

local function finish()
    if not playing then return end

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hack:stop' })

    local p = playing
    playing = nil
    p:resolve(true)
end

lib.callback.register('som-hack:client:play', function(view)
    if playing then return false end

    playing = promise.new()
    token = token + 1
    local mine = token

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'hack:start', view = view })

    -- A page that never reports back must not hold the mouse for good.
    SetTimeout(Config.ExpireMs + 2000, function()
        if playing and token == mine then finish() end
    end)

    Citizen.Await(playing)
    return true
end)

RegisterNUICallback('submit', function(data, cb)
    cb(lib.callback.await('som-hack:server:submit', false, data.nonce, data.answer) or {})
end)

RegisterNUICallback('guess', function(data, cb)
    cb(lib.callback.await('som-hack:server:guess', false, data.nonce, data.guess) or {})
end)

RegisterNUICallback('done', function(_, cb)
    finish()
    cb({})
end)
