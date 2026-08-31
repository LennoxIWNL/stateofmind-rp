--- Shell models and where you stand when you walk in.
---
--- A shell is an interior with no location. It is spawned wherever the routing
--- bucket for a property puts it, and the player is placed at the shell origin
--- plus the offset below. So an offset is a property of the MODEL, which is why
--- it lives here once rather than on every property row that uses that model.
---
--- WHERE THESE NUMBERS COME FROM. They are lifted from `qb-interior`'s own
--- exports, which is the community reference set for the K4MB1 starter shells
--- and the only place on disk that has them. Nothing else in the tree records a
--- single shell offset. They were read out of the resource rather than measured,
--- so treat a wrong one as a transcription error and fix it here.
---
--- `h` is the heading to face on arrival, chosen so you are looking into the
--- room rather than at the door you came through.

-- GLOBAL, not local. FiveM loads each script in a resource separately and a
-- top-level `return` is not captured by anything, so a local here would be
-- invisible to config.lua, which validates its property list against it.
Shells = {}

--- Every shell whose model is actually streamed AND whose offset is known.
---
--- The check that matters is that both halves are true. `standardmotel_shell`
--- streams from qb-interior and has no offset anywhere in it, so it is absent
--- here rather than present with a guess: a shell that drops you inside a wall
--- is worse than a shell that is not offered.
Shells.Offsets = {
    -- Apartments and small residential
    ['furnitured_midapart'] = { x = 1.46,  y = -10.33, z = 1.06, h = 0.39 },
    ['shell_v16low']        = { x = 4.693, y = -6.015, z = 1.11, h = 358.634 },
    ['shell_v16mid']        = { x = 1.561, y = -14.305, z = 1.147, h = 2.263 },
    ['modernhotel_shell']   = { x = 4.98,  y = 4.35,   z = 1.16, h = 179.79 },

    -- Houses
    ['shell_frankaunt']     = { x = -0.36, y = -5.89,  z = 1.7,  h = 358.21 },
    ['shell_ranch']         = { x = -1.257, y = -5.469, z = 2.5, h = 270.57 },
    ['shell_michael']       = { x = -9.49, y = 5.54,   z = 9.91, h = 270.86 },
    ['shell_trevor']        = { x = 0.374, y = -3.789, z = 2.428, h = 358.633 },
    ['shell_trailer']       = { x = -1.4,  y = -2.1,   z = 3.3,  h = 358.634 },
    ['shell_lester']        = { x = -1.78, y = -0.795, z = 1.1,  h = 270.3 },

    -- Commercial and industrial. The warehouse tiers are built on these.
    ['shell_warehouse1']    = { x = -8.95, y = 0.51,   z = 1.04, h = 268.82 },
    ['container_shell']     = { x = 0.08,  y = -5.73,  z = 1.24, h = 359.32 },
    ['shell_office1']       = { x = 1.88,  y = 5.06,   z = 2.05, h = 180.07 },
    ['shell_store1']        = { x = -2.61, y = -4.73,  z = 1.08, h = 1.0 },

    -- NOTE THE MODEL NAME. qb-interior's own CreateGarageMed asks for
    -- `shell_garagemed`, and the file it streams is `shell_garagem.ydr`. That
    -- export has therefore never worked. The name here is the one that exists.
    ['shell_garagem']       = { x = 13.9,  y = 1.63,   z = 1.0,  h = 87.05 },
}

--- Shells that are streamed but cannot be used yet, and why.
---
--- Kept as data rather than deleted so the next person does not go looking for
--- them again. `jordqn_free_shells` is already ensured for som-multichar's
--- character-select backdrop, so these four cost nothing to stream and only
--- need somebody to stand in one and read the coordinates back.
Shells.Unmeasured = {
    ['apart_luxe_1']        = 'jordqn_free_shells. Origin is in the bedroom; som-multichar uses roughly (-1.2, -2.33) for the living area, which is a camera position and not an exit.',
    ['coke_business_empty'] = 'jordqn_free_shells. Wanted for the largest warehouse tier.',
    ['motel_low']           = 'jordqn_free_shells.',
    ['warehouse_small']     = 'jordqn_free_shells. Wanted for the smallest warehouse tier.',
    ['standardmotel_shell'] = 'qb-interior streams it, but no offset exists in either of its client files.',
}

---Whether a shell can actually be entered.
---@param model string
---@return boolean
function Shells.IsUsable(model)
    return type(model) == 'string' and Shells.Offsets[model] ~= nil
end

---The exit offset for a shell, or nil.
---
---nil is a real answer and every caller must handle it. A property configured
---against an unmeasured shell must refuse to open rather than drop somebody
---into geometry, which is the failure this table exists to prevent.
---@param model string
---@return table|nil
function Shells.OffsetFor(model)
    if type(model) ~= 'string' then return nil end
    return Shells.Offsets[model]
end

