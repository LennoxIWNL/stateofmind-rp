---@type DoorlockConfig
---@diagnostic disable-next-line: missing-fields
Config = {}

---Trigger a notification on the client when the door state is successfully updated.
Config.Notify = true

---Create a persistent notification while in-range of a door, prompting to lock/unlock.
-- SOM: on. It replaces the sprite below, and it matches how every other
-- interaction on this server prompts.
Config.DrawTextUI = true

---Set the properties used by [DrawSprite](https://docs.fivem.net/natives/?_0xE7FFAE5EBF23D890).
--
-- SOM: DISABLED, which is what turns the white square on every door back into
-- nothing.
--
-- client/main.lua calls RequestStreamedTextureDict ONCE when its thread starts
-- and never waits for HasStreamedTextureDictLoaded, so if the dictionary is not
-- resident by the first draw the game renders an untextured white quad and
-- keeps rendering it, because the request is never retried.
--
-- Config.DrawTextUI above replaces it. Re-apply on an ox_doorlock upgrade.
Config.DrawSprite = false

---Allow the specified ace principal to use 'command.doorlock'.
Config.CommandPrincipal = 'group.admin'

---Allow players with the 'command.doorlock' principal to use any door.
Config.PlayerAceAuthorised = false

---The default skill check difficulty when lockpicking a door.
Config.LockDifficulty = { 'easy', 'easy', 'medium' }

---Allow lockpicks to be used to lock an unlocked door.
Config.CanPickUnlockedDoors = false

---An array of items that function as lockpicks.
Config.LockpickItems = {
    'lockpick'
}

---Play sounds using game audio (sound natives) instead of through NUI.
Config.NativeAudio = true
