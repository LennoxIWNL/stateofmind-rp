SomClock = {}

---Seconds into the game day. A pure function of the real clock, so a restart cannot move it.
---@param epoch number POSIX seconds
---@param state table { dayMinutes = real minutes per game day, offset = game seconds, frozen = game seconds|nil }
---@return integer
function SomClock.Seconds(epoch, state)
    if state.frozen then return state.frozen end
    return math.floor(epoch * 86400 / (state.dayMinutes * 60) + state.offset) % 86400
end

---@return integer hour, integer minute, integer second
function SomClock.Time(epoch, state)
    local s = SomClock.Seconds(epoch, state)
    return s // 3600, s % 3600 // 60, s % 60
end
