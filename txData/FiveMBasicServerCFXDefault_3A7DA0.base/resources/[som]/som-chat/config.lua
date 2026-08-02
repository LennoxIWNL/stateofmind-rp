Config = {}

-- T is what the stock chat used, so muscle memory holds. Both are rebindable
-- in FiveM settings.
Config.OpenKey = 'T'
Config.AltKey  = 'Y'

Config.MaxLength = 256
Config.MaxHistory = 60

-- How long a message stays on screen once chat is closed. Chat that never
-- fades becomes permanent screen clutter.
Config.FadeAfterMs = 12000

-- Proximity chat. Shouting across the whole map is not roleplay, and a global
-- chat undermines the phone being how you reach someone you cannot see.
Config.Proximity = true
Config.Range = 20.0

-- Anti-spam, enforced server side.
Config.CooldownMs = 700
