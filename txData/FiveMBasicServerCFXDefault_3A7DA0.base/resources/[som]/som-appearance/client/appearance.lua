-- Reading and applying a ped's appearance.
--
-- This is the whole engine. Everything else in this resource is a way to drive
-- it: the creator, the barber and the clothing shop all end up here.
--
-- The table shape is the fivem-appearance / illenium standard, so what is
-- stored in som_characters.appearance is readable by any tool in the ecosystem
-- and importable from one. See shared/config.lua.

Appearance = {}

---@param value any
---@param min number
---@param max number
---@param fallback number
---@return number
local function clamp(value, min, max, fallback)
    local n = tonumber(value)
    if not n or n ~= n then return fallback end
    if n < min then return min end
    if n > max then return max end
    return n
end

-- ---------------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------------

---@param gender number 0 male, 1 female
---@return table
function Appearance.Default(gender)
    gender = (tonumber(gender) == 1) and 1 or 0

    local components = {}
    for _, c in ipairs(Config.Components) do
        -- Drawable 0 texture 0 is the plain default for every slot. Underwear
        -- is not: leaving torso and legs at 0 spawns the ped in pants, which is
        -- the correct starting point for a creator rather than a nude ped.
        components[#components + 1] = { component_id = c.id, drawable = 0, texture = 0 }
    end

    local overlays = {}
    for _, o in ipairs(Config.HeadOverlays) do
        overlays[o.key] = { style = 0, opacity = 0.0, colour = 0, secondColour = 0 }
    end

    local features = {}
    for i = 0, 19 do features[i] = 0.0 end

    return {
        model = Config.Models[gender],
        gender = gender,
        headBlend = {
            shapeFirst = 0, shapeSecond = 0, shapeThird = 0,
            skinFirst = 0, skinSecond = 0, skinThird = 0,
            shapeMix = 0.5, skinMix = 0.5, thirdMix = 0.0,
        },
        faceFeatures = features,
        headOverlays = overlays,
        hair = { style = 0, colour = 0, highlight = 0 },
        eyeColour = 0,
        components = components,
        props = {},
        tattoos = {},
    }
end

-- ---------------------------------------------------------------------------
-- Applying
-- ---------------------------------------------------------------------------

---@param ped number
---@param data table
function Appearance.ApplyHeadBlend(ped, data)
    local b = data.headBlend
    if not b then return end

    SetPedHeadBlendData(ped,
        math.floor(clamp(b.shapeFirst, 0, 45, 0)),
        math.floor(clamp(b.shapeSecond, 0, 45, 0)),
        math.floor(clamp(b.shapeThird, 0, 45, 0)),
        math.floor(clamp(b.skinFirst, 0, 45, 0)),
        math.floor(clamp(b.skinSecond, 0, 45, 0)),
        math.floor(clamp(b.skinThird, 0, 45, 0)),
        clamp(b.shapeMix, 0.0, 1.0, 0.5),
        clamp(b.skinMix, 0.0, 1.0, 0.5),
        clamp(b.thirdMix, 0.0, 1.0, 0.0),
        false)
end

---@param ped number
---@param data table
function Appearance.ApplyFaceFeatures(ped, data)
    local features = data.faceFeatures
    if not features then return end

    -- Blending has to finish before features take, or the values are applied
    -- to a head that is about to be replaced and silently lost.
    local deadline = GetGameTimer() + 1000
    while not HasPedHeadBlendFinished(ped) and GetGameTimer() < deadline do Wait(0) end

    for i = 0, 19 do
        SetPedFaceFeature(ped, i, clamp(features[i] or features[tostring(i)], -1.0, 1.0, 0.0))
    end
end

---@param ped number
---@param data table
function Appearance.ApplyOverlays(ped, data)
    local overlays = data.headOverlays or {}

    for _, def in ipairs(Config.HeadOverlays) do
        local o = overlays[def.key] or {}
        local style = math.floor(clamp(o.style, 0, 255, 0))
        local opacity = clamp(o.opacity, 0.0, 1.0, 0.0)

        -- 255 is the game's "none". Style 0 is a real style, so a zero opacity
        -- overlay still has to be set to 255 or it renders faintly.
        if opacity <= 0.0 then
            SetPedHeadOverlay(ped, def.id, 255, 0.0)
        else
            SetPedHeadOverlay(ped, def.id, style, opacity)

            if def.colourType then
                SetPedHeadOverlayColor(ped, def.id, def.colourType,
                    math.floor(clamp(o.colour, 0, 63, 0)),
                    math.floor(clamp(o.secondColour, 0, 63, 0)))
            end
        end
    end
end

---@param ped number
---@param data table
function Appearance.ApplyHair(ped, data)
    local hair = data.hair or {}

    SetPedComponentVariation(ped, Config.HairComponent,
        math.floor(clamp(hair.style, 0, 255, 0)), 0, 0)

    SetPedHairColor(ped,
        math.floor(clamp(hair.colour, 0, 63, 0)),
        math.floor(clamp(hair.highlight, 0, 63, 0)))
end

---@param ped number
---@param data table
function Appearance.ApplyApparel(ped, data)
    for _, c in ipairs(data.components or {}) do
        local id = tonumber(c.component_id)
        -- Hair is applied by ApplyHair with its colour, so it is skipped here
        -- to stop the two fighting over the same slot.
        if id and id ~= Config.HairComponent then
            SetPedComponentVariation(ped, id,
                math.floor(clamp(c.drawable, 0, 255, 0)),
                math.floor(clamp(c.texture, 0, 255, 0)), 0)
        end
    end

    for _, p in ipairs(data.props or {}) do
        local id = tonumber(p.prop_id)
        if id then
            local drawable = math.floor(clamp(p.drawable, -1, 255, -1))

            if drawable < 0 then
                ClearPedProp(ped, id)
            else
                SetPedPropIndex(ped, id, drawable,
                    math.floor(clamp(p.texture, 0, 255, 0)), true)
            end
        end
    end
end

---Applies a whole appearance, changing the model first if it has to.
---@param ped number
---@param data table
---@return number ped the ped, which may be a NEW handle if the model changed
function Appearance.Apply(ped, data)
    if type(data) ~= 'table' then return ped end

    local model = data.model or Config.Models[0]
    local hash = joaat(model)

    if IsModelValid(hash) and GetEntityModel(ped) ~= hash then
        RequestModel(hash)

        local deadline = GetGameTimer() + 5000
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end

        if HasModelLoaded(hash) then
            -- SetPlayerModel replaces the ped, so the old handle is dead after
            -- this and every caller has to take the new one back.
            SetPlayerModel(PlayerId(), hash)
            SetModelAsNoLongerNeeded(hash)
            ped = PlayerPedId()

            -- Freemode peds spawn with nothing set; without this the head is
            -- bald and untextured before the rest is applied.
            SetPedDefaultComponentVariation(ped)
        end
    end

    Appearance.ApplyHeadBlend(ped, data)
    Appearance.ApplyFaceFeatures(ped, data)
    Appearance.ApplyOverlays(ped, data)
    Appearance.ApplyHair(ped, data)
    Appearance.ApplyApparel(ped, data)

    if data.eyeColour then
        SetPedEyeColor(ped, math.floor(clamp(data.eyeColour, 0, 31, 0)))
    end

    return ped
end

-- ---------------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------------

---Reads what a ped currently looks like, in the same shape Apply takes.
---@param ped number
---@return table
function Appearance.Get(ped)
    local model = GetEntityModel(ped)
    local gender = model == joaat(Config.Models[1]) and 1 or 0

    local blend = { GetPedHeadBlendData(ped) }

    local features = {}
    for i = 0, 19 do features[i] = GetPedFaceFeature(ped, i) end

    local overlays = {}
    for _, def in ipairs(Config.HeadOverlays) do
        local _, style, colour, secondColour, opacity = GetPedHeadOverlayData(ped, def.id)

        overlays[def.key] = {
            -- 255 is "none" going in, so it is stored as style 0 with no
            -- opacity rather than as a style nothing can render.
            style = style == 255 and 0 or style,
            opacity = style == 255 and 0.0 or opacity,
            colour = colour,
            secondColour = secondColour,
        }
    end

    local components = {}
    for _, c in ipairs(Config.Components) do
        components[#components + 1] = {
            component_id = c.id,
            drawable = GetPedDrawableVariation(ped, c.id),
            texture = GetPedTextureVariation(ped, c.id),
        }
    end

    local props = {}
    for _, p in ipairs(Config.Props) do
        props[#props + 1] = {
            prop_id = p.id,
            drawable = GetPedPropIndex(ped, p.id),
            texture = GetPedPropTextureIndex(ped, p.id),
        }
    end

    return {
        model = Config.Models[gender],
        gender = gender,
        headBlend = {
            shapeFirst = blend[1], shapeSecond = blend[2], shapeThird = blend[3],
            skinFirst = blend[4], skinSecond = blend[5], skinThird = blend[6],
            shapeMix = blend[7], skinMix = blend[8], thirdMix = blend[9],
        },
        faceFeatures = features,
        headOverlays = overlays,
        hair = {
            style = GetPedDrawableVariation(ped, Config.HairComponent),
            colour = GetPedHairColor(ped),
            highlight = GetPedHairHighlightColor(ped),
        },
        eyeColour = GetPedEyeColor(ped),
        components = components,
        props = props,
        tattoos = {},
    }
end

-- ---------------------------------------------------------------------------
-- Limits
--
-- How many drawables and textures a slot actually has, for THIS ped. It varies
-- by model and by what is streamed, so it is asked at runtime rather than
-- hardcoded: a UI that offers a drawable the ped does not have renders an
-- invisible torso, which is the classic broken clothing menu.
-- ---------------------------------------------------------------------------

---@param ped number
---@return table
function Appearance.Limits(ped)
    local components = {}
    for _, c in ipairs(Config.Components) do
        local drawables = GetNumberOfPedDrawableVariations(ped, c.id)
        components[tostring(c.id)] = {
            drawables = drawables,
            textures = GetNumberOfPedTextureVariations(ped, c.id,
                GetPedDrawableVariation(ped, c.id)),
        }
    end

    local props = {}
    for _, p in ipairs(Config.Props) do
        props[tostring(p.id)] = {
            drawables = GetNumberOfPedPropDrawableVariations(ped, p.id),
            textures = GetNumberOfPedPropTextureVariations(ped, p.id,
                GetPedPropIndex(ped, p.id)),
        }
    end

    return {
        components = components,
        props = props,
        hair = GetNumberOfPedDrawableVariations(ped, Config.HairComponent),
    }
end
