# som-appearance

Character creator, barber and clothing. One editor, four scopes.

## Why this was written rather than adopted

Unusually for this project, which reuses wherever it can.

Every free appearance resource is **archived, two years stale, or bound to
qb-core**: `bl_appearance` is archived by its own authors,
`pedr0fontoura/fivem-appearance` last moved in early 2023, and
`illenium-appearance` is MIT and by far the most used but is written for
qb-core and ESX. Everything genuinely maintained is paid.

What tipped it: **half the work already existed.** `som-multichar` has the
interior shell, the scripted camera, the lighting and the preview ped. The
remaining work is a long list of native calls over a well-known table, which is
tedious rather than hard.

**The data shape is still theirs.** `headBlend`, `faceFeatures`, `headOverlays`,
`hair`, `eyeColour`, `components`, `props` is the fivem-appearance standard, so
`som_characters.appearance` stays readable by any tool in the ecosystem and
importable from one. The code is ours, the format is not.

## Scopes are the security boundary

| Scope | May change |
|---|---|
| `creator` | Everything. Free. |
| `barber` | Face, hair, facial hair, detail |
| `clothing` | What you are wearing |

The client sends a whole appearance table because that is what it is holding.
**The server merges only the sections the scope allows** and takes everything
else from the stored record, so an edited request changes nothing it was not
entitled to. A clothing shop cannot alter a face; a barber cannot hand out
armour.

## The barber can change your face, on purpose

A character creator mistake is otherwise permanent, and deleting a character you
have played for a month is a worse outcome.

The cost of that is real and is priced accordingly: **a face is an identity.**
Witnesses, mugshots and "I know who did it" all rely on it staying put. Face
work is an order of magnitude above a haircut and **every change is written to
`som_appearance_log`** with who and when. That makes it a repair rather than a
way to shed a description the police are circulating.

Nothing reads that log yet. som-police and the MDT will.

## Pricing

Charged **per section actually changed**, not per visit, so opening a tab and
closing it again costs nothing. The rail shows the running total before you
commit. Creation is free: nothing has been earned yet.

Charged through som-core's transaction bus, so it lands in the ledger and counts
as an economy sink.

## Every new character customises first

`som-appearance` listens for `som:client:playerLoaded`. A character with no
stored appearance gets the creator; one with an appearance simply has it
applied.

It runs after the character is live rather than inside som-multichar's scene,
because the editor works on the **player's own ped** and during selection that
ped is not in the world yet. One code path then serves creation and the barber
instead of two that drift.

## Limits are asked at runtime

`GetNumberOfPedDrawableVariations` is queried for the actual ped rather than
hardcoded, because the counts vary by model and by what is streamed. A menu that
offers a drawable the ped does not have renders an invisible torso, which is the
classic broken clothing menu.

## Getting in from the world

`client/zones.lua` puts a sphere on every vanilla barber and clothing store in
`Config.Locations` and calls `openEditor` with the matching scope. Before it
existed the editor had exactly one caller, `som-multichar` at character
creation, so a player built a face once and then lived with it and with the
clothes they were created in for the life of the character.

Spheres rather than entity targets, because `ox_target` draws its indicator
circle for zones only. The shops are static, so a sphere behaves identically and
earns the marker. The option hides itself in a vehicle and while downed.

**The zone is not the permission.** `som-appearance:server:save` re-checks the
scope against the same shared `Config.Locations` with the server's own view of
where the ped is, at `Config.SaveDistance`, which is deliberately looser than
the interaction distance because the client's coordinates lag the server's.

`creator` is the one scope with no location, and it is accepted only while
nothing is stored for the character, the same condition `needsCreation` reports
to `som-multichar`. Without that check a client could send `creator` from
anywhere and get every section, the ped model and the gender, for free, which is
a new person rather than a haircut.

## Known gaps

- **No tattoos.** The field is in the shape and reserved; the overlay collection
  work is not done.
- **No outfits or wardrobe.**
- Hair swatch colours are approximations. The game's palette is not exposed to
  NUI, so the swatch is a guess while the value sent is the real palette index.
- Head overlay style counts are assumed rather than queried, so some overlays
  offer more styles than exist and land on none.
- Not verified against a live server.
