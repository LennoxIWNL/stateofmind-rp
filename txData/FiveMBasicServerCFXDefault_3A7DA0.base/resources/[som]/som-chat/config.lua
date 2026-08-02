Config = {}

-- som-chat is a COMMAND LINE, not a chat.
--
-- There is no message log, no history on screen, and nothing is ever visible
-- unless the player is actively typing. Players talk through voice, the phone,
-- and interactions. A visible text chat would compete with all three and pull
-- roleplay out of the world and into a text box.
--
-- Anything a script wants to tell a player goes to som-ui as a notification.

-- T is what the stock chat used, so muscle memory holds. Rebindable in FiveM
-- settings under Key Bindings.
Config.OpenKey = 'T'

Config.MaxLength = 256

-- Reject anything that is not a command. Set false only if a plain text chat
-- is ever genuinely wanted, which would be a design reversal.
Config.CommandsOnly = true
