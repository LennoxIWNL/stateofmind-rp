-- ===========================================================================
--  Gabz MRPD doors for ox_doorlock
--
--  OPTIONAL and ONE-TIME. Deliberately NOT part of setup.sql, because
--  setup.sql is safe to re-run and `ox_doorlock` has no unique key on `name`,
--  so folding this in would insert a duplicate set of doors on every import.
--
--    mysql -u root -p stateofmindrp < sql/mrpd-doors.sql
--
--  Safe to re-run on its own: the DELETE below clears the previous set first,
--  so correcting a door and re-importing replaces rather than duplicates.
--
--  ---------------------------------------------------------------------------
--  WHERE THIS CAME FROM, AND WHY IT MAY NOT ALL FIT
--
--  Converted from a public qb-doorlock config written for Gabz MRPD
--  (github.com/Intelligentzombie29/qb-doorlock-with-Gabz-mrpd-locks). Only the
--  DOOR DATA is used: model names, headings and coordinates. Model names are
--  joaat hashed here because ox_doorlock stores the hash, not the name.
--
--  A widely circulated 85-door MRPD set also exists, and it is NOT this one:
--  that set targets Prompt Studio's MRPD, a different MLO, so its doors would
--  land in the wrong places in a Gabz build.
--
--  Even so, these coordinates come from somebody else's Gabz install, and Gabz
--  has shipped more than one MRPD revision. ox_doorlock matches a door by model
--  AND position within `maxDistance`, so a door whose coordinates are off is
--  simply never found: it stays unlocked and nothing breaks. Walk the station
--  after importing, and fix any that did not take with /doorlock rather than
--  assuming the whole set is wrong.
--
--  Every door is gated on `groups: { police: 0 }`, which ox_doorlock resolves
--  through the som-compat bridge at
--  ox_doorlock/server/framework/som-compat.lua.
-- ===========================================================================

DELETE FROM `ox_doorlock` WHERE `name` LIKE 'MRPD %';

INSERT INTO `ox_doorlock` (`id`, `name`, `data`) VALUES
    (DEFAULT, 'MRPD Reception Entrance', '{"doors":[{"model":-1547307588,"heading":90.1,"coords":{"x":434.7,"y":-983.0,"z":30.8}},{"model":-1547307588,"heading":269.0,"coords":{"x":434.7,"y":-980.7,"z":30.8}}],"coords":{"x":434.7,"y":-981.85,"z":30.8},"state":0,"maxDistance":2.5,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Reception Side 1', '{"model":-96679321,"heading":177.9,"doors":false,"coords":{"x":440.5,"y":-988.2,"z":30.8},"state":1,"maxDistance":2.5,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Reception Side 2', '{"model":-1406685646,"heading":2.6,"doors":false,"coords":{"x":440.5,"y":-977.6,"z":30.8},"state":1,"maxDistance":2.5,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Side Entrance', '{"doors":[{"model":-1547307588,"heading":1.8,"coords":{"x":440.7,"y":-998.7,"z":30.8}},{"model":-1547307588,"heading":178.0,"coords":{"x":443.0,"y":-998.7,"z":30.8}}],"coords":{"x":441.85,"y":-998.7,"z":30.8},"state":1,"maxDistance":2.5,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Armoury 1', '{"model":-692649124,"heading":89.7,"doors":false,"coords":{"x":479.7,"y":-999.6,"z":30.7},"state":1,"maxDistance":1.25,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Armoury 2', '{"model":-692649124,"heading":180.9,"doors":false,"coords":{"x":487.4,"y":-1000.1,"z":30.7},"state":1,"maxDistance":1.25,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Garage Parking', '{"model":1830360419,"heading":88.0,"doors":false,"coords":{"x":464.1,"y":-997.5,"z":26.3},"state":1,"maxDistance":1.5,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Back Entrance', '{"doors":[{"model":-692649124,"heading":179.7,"coords":{"x":469.7,"y":-1014.4,"z":26.4}},{"model":-692649124,"heading":359.9,"coords":{"x":467.3,"y":-1014.4,"z":26.4}}],"coords":{"x":468.5,"y":-1014.4,"z":26.4},"state":1,"maxDistance":1.5,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Back Gate', '{"model":-1603817716,"heading":90.0,"doors":false,"coords":{"x":488.8,"y":-1017.2,"z":27.1},"state":1,"maxDistance":1.25,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Cells Corridor', '{"doors":[{"model":149284793,"heading":90.0,"coords":{"x":471.3,"y":-1010.1,"z":26.4}},{"model":149284793,"heading":270.0,"coords":{"x":471.3,"y":-1007.7,"z":26.4}}],"coords":{"x":471.3,"y":-1008.9,"z":26.4},"state":1,"maxDistance":2.5,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Cell 1', '{"model":-53345114,"heading":0.0,"doors":false,"coords":{"x":477.9,"y":-1012.1,"z":26.4},"state":1,"maxDistance":1.25,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Cell 2', '{"model":-53345114,"heading":0.0,"doors":false,"coords":{"x":480.9,"y":-1012.1,"z":26.4},"state":1,"maxDistance":1.25,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Cell 3', '{"model":-53345114,"heading":0.0,"doors":false,"coords":{"x":483.9,"y":-1012.1,"z":26.4},"state":1,"maxDistance":1.25,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Cell 4', '{"model":-53345114,"heading":0.0,"doors":false,"coords":{"x":486.9,"y":-1012.1,"z":26.4},"state":1,"maxDistance":1.25,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Cell 5', '{"model":-53345114,"heading":180.0,"doors":false,"coords":{"x":484.1,"y":-1007.7,"z":26.4},"state":1,"maxDistance":1.25,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Cell Block Door', '{"doors":[{"model":149284793,"heading":179.0,"coords":{"x":482.0,"y":-997.9,"z":26.4}},{"model":149284793,"heading":359.9,"coords":{"x":479.6,"y":-997.9,"z":26.4}}],"coords":{"x":480.8,"y":-997.9,"z":26.4},"state":1,"maxDistance":1.5,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Evidence', '{"model":-692649124,"heading":134.9,"doors":false,"coords":{"x":475.8,"y":-990.4,"z":26.4},"state":1,"maxDistance":1.25,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Interrogation 1', '{"model":-1406685646,"heading":270.1,"doors":false,"coords":{"x":482.6,"y":-987.5,"z":26.4},"state":1,"maxDistance":1.25,"groups":{"police":0}}'),
    (DEFAULT, 'MRPD Interrogation 2', '{"model":-1406685646,"heading":270.0,"doors":false,"coords":{"x":482.6,"y":-995.7,"z":26.4},"state":1,"maxDistance":1.25,"groups":{"police":0}}');
