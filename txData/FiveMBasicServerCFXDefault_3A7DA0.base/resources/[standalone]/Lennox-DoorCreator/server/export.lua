TemplateManager = {}

local function generateExportCode()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    local code = ''
    for _ = 1, 16 do
        local idx = math.random(1, #chars)
        code = code .. chars:sub(idx, idx)
    end
    return code
end

function TemplateManager.create(data)
    local exportCode = generateExportCode()
    local templateData = json.encode(data.data)

    local id = MySQL.insert.await(
        'INSERT INTO lennox_templates (name, description, type, data, author, version, export_code) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { data.name, data.description or '', data.type or 'single', templateData, data.author or 'Unknown', data.version or '1.0.0', exportCode }
    )

    return {
        id = id,
        name = data.name,
        exportCode = exportCode,
    }
end

function TemplateManager.getAll()
    local rows = MySQL.query.await(
        'SELECT id, name, description, type, author, version, export_code, created_at FROM lennox_templates ORDER BY created_at DESC'
    )
    return rows or {}
end

function TemplateManager.getById(id)
    local rows = MySQL.query.await('SELECT * FROM lennox_templates WHERE id = ?', { id })
    if not rows or not rows[1] then return nil end
    local template = rows[1]
    template.data = json.decode(template.data or '{}')
    return template
end

function TemplateManager.getByCode(code)
    local rows = MySQL.query.await('SELECT * FROM lennox_templates WHERE export_code = ?', { code })
    if not rows or not rows[1] then return nil end
    local template = rows[1]
    template.data = json.decode(template.data or '{}')
    return template
end

function TemplateManager.delete(id)
    MySQL.update.await('DELETE FROM lennox_templates WHERE id = ?', { id })
end

function TemplateManager.exportToString(id)
    local template = TemplateManager.getById(id)
    if not template then return nil, 'Template not found' end

    local exportData = {
        _type = 'lennox_door_template',
        _version = '1.0.0',
        name = template.name,
        description = template.description,
        type = template.type,
        data = template.data,
        author = template.author,
        exportedAt = os.time(),
    }

    local jsonStr = json.encode(exportData)
    -- Base64 encode for sharing
    local b64 = TemplateManager.base64encode(jsonStr)
    return b64
end

function TemplateManager.importFromString(b64str)
    local jsonStr = TemplateManager.base64decode(b64str)
    if not jsonStr then return nil, 'Invalid import string' end

    local ok, data = pcall(json.decode, jsonStr)
    if not ok or not data then return nil, 'Invalid template data' end

    if data._type ~= 'lennox_door_template' then
        return nil, 'Not a valid Lennox Door Creator template'
    end

    if not data.name or not data.data then
        return nil, 'Template is missing required fields'
    end

    return TemplateManager.create({
        name = data.name .. ' (Imported)',
        description = data.description,
        type = data.type or 'single',
        data = data.data,
        author = data.author or 'Imported',
        version = data._version or '1.0.0',
    })
end

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function TemplateManager.base64encode(data)
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2^(6-i) or 0) end
        return b64chars:sub(c+1, c+1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

function TemplateManager.base64decode(data)
    data = string.gsub(data, '[^' .. b64chars .. '=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (b64chars:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end
