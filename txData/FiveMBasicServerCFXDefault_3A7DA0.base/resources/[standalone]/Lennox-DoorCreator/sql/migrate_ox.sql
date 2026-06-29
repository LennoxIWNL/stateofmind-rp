-- Lennox Door Creator — Migration helpers
-- Use these queries to inspect existing ox_doorlock data before importing

-- View all existing ox_doorlock doors
SELECT id, name, JSON_EXTRACT(data, '$.model') AS model, JSON_EXTRACT(data, '$.coords') AS coords FROM ox_doorlock ORDER BY id;

-- Count doors by lock state
SELECT JSON_EXTRACT(data, '$.state') AS lock_state, COUNT(*) AS count FROM ox_doorlock GROUP BY lock_state;

-- Find doors with specific job permissions
SELECT id, name, JSON_EXTRACT(data, '$.groups') AS groups FROM ox_doorlock WHERE JSON_EXTRACT(data, '$.groups') IS NOT NULL;

-- Find double doors
SELECT id, name FROM ox_doorlock WHERE JSON_EXTRACT(data, '$.doors') IS NOT NULL;
