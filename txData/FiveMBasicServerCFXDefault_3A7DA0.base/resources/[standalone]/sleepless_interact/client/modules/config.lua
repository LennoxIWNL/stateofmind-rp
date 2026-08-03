-- SOM PATCH. Third-party resource, config edits only.
-- Re-apply after upgrading sleepless_interact. Upstream defaults noted inline.

local config = {}

-- this is the maximum distance that interacts will render the indicator sprite (little cirlce)
-- recommend keeping this pretty low for optimization
--
-- SOM: 5.0 is upstream and kept. Deliberately short. The circles say "there is
-- something here", they are not a map of every interactable on the block.
config.maxInteractDistance = 5.0

-- {0-255, 0-255, 0-255, 0-255}
-- SOM: was { 28, 100, 184, 200 }, the stock blue. Now brand pink, matching
-- --som-pink #ff1493 in som-assets/tokens.css.
config.themeColor = { 255, 20, 147, 200 } --- r, g, b, a

--- texture dictionary and texture name for the sprite used to show non active interactions.
--- SOM: a base game texture, so nothing needs streaming for this to work.
config.IndicatorSprite = { dict = 'shared', txt = 'emptydot_32' }

-- boolean true/false use a keybind to show and hide the interactions
-- SOM: was false, which left the circles on screen permanently. On, so the
-- world stays clean until you ask what is interactable.
config.useShowKeyBind = true

-- string default key mapping for the show interactions keybind
-- SOM: Left Alt, the key qb-target used, so muscle memory carries over.
config.defaultShowKeyBind = 'LMENU'

-- "hold" | "toggle" sets the behavior of the show interactions key bind
-- SOM: was 'toggle'. Hold, so releasing clears the screen and the circles can
-- never be left switched on by accident.
config.showKeyBindBehavior = 'hold'

return config
