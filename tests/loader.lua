-- Loads a resource's real .lua files into one shared sandboxed environment,
-- the way FXServer loads one resource's scripts into one shared global
-- table, so the production code under test runs unmodified.

local function loadResource(root, files)
    local env = setmetatable({}, { __index = _G })
    for _, path in ipairs(files) do
        local full = root .. '/' .. path
        local f = assert(io.open(full, 'rb'))
        local source = f:read('a')
        f:close()
        -- FiveM's backtick hash literals (`WEAPON_X`) are not Lua; same swap as tools/check-lua.sh.
        local chunk = assert(load(source:gsub('`[^`]*`', '0'), '@' .. full, 't', env))
        chunk()
    end
    return env
end

return { loadResource = loadResource }
