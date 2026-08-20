-- qb-core's Locale class, vendored.
--
-- WHY THIS FILE EXISTS AT ALL.
--
-- ps-hud's fxmanifest loads '@qb-core/shared/locale.lua'. That is a FILE PATH,
-- not an export, and FiveM resolves it against a real resource directory on
-- disk. som-compat's `provide 'qb-core'` satisfies a `dependency 'qb-core'`
-- line and does nothing for a file reference, so with no qb-core directory on
-- this server ps-hud failed to start before a line of its code ran.
--
-- The dependency is not cosmetic either. ps-hud's locales/en.lua ends with
-- `Lang = Lang or Locale:new(...)`, and Lang is called on both sides, so
-- without the class every notify path throws.
--
-- ps-hud's manifest is repointed at this file. That edit is on the re-apply
-- list: a ps-hud update overwrites its own fxmanifest and takes the repoint
-- with it.
--
-- Behaviour matches qb-core's: :t/:translate formats a phrase by key,
-- substituting %{name} placeholders, and warns rather than throwing on a
-- missing key so a wrong key costs a string and not the resource.
-- qb-core is GPL-3.0 and so is ps-hud, which is what makes carrying this here
-- legitimate.

Locale = {}
Locale.__index = Locale

function Locale:new(opts)
    assert(type(opts) == 'table', 'Locale:new expects a table')

    local self = setmetatable({}, Locale)

    self.fallbackLang = opts.fallbackLang or self
    self.warnOnMissing = opts.warnOnMissing ~= false
    self.phrases = {}

    self:extend(opts.phrases or {})

    return self
end

-- Phrase tables are NESTED and keys are looked up DOTTED. ps-hud writes
-- `Translations.notify.hud_start` and reads `Lang:t('notify.hud_start')`, so
-- the tree has to be flattened into dotted keys on the way in. A shallow copy
-- stores one entry per top level group, every real lookup misses, and every
-- string on screen reads back as its own key.
---@param phrases table
---@param prefix string|nil
function Locale:extend(phrases, prefix)
    for key, phrase in pairs(phrases) do
        local path = prefix and (prefix .. '.' .. key) or key

        if type(phrase) == 'table' then
            self:extend(phrase, path)
        else
            self.phrases[path] = phrase
        end
    end
end

---@param key string
---@param subs table|nil values for %{placeholder} substitution
---@return string
function Locale:t(key, subs)
    local phrase = self.phrases[key]

    if type(phrase) ~= 'string' then
        if self.warnOnMissing then
            print(('[som-compat] locale key missing: %s'):format(tostring(key)))
        end
        -- The KEY back, never nil. Callers concatenate this straight into a
        -- string, so nil here would throw at the call site rather than show a
        -- gap in the text.
        return tostring(key)
    end

    if type(subs) ~= 'table' then return phrase end

    return (phrase:gsub('%%{(.-)}', function(name)
        local value = subs[name]
        return value ~= nil and tostring(value) or ('%{' .. name .. '}')
    end))
end

Locale.translate = Locale.t

return Locale
