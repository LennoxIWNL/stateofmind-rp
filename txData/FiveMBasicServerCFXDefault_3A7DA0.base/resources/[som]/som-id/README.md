# som-id

Identity documents. Using one holds it out and shows it to the people near you.

## Showing is an interaction, not a broadcast

Viewers are resolved **server side** from the holder's position. The client that
showed the card never decides who sees it, and never supplies what is on it:
either would let a player forge a document or flash it across the whole city.

Distance uses a flat radius **plus a separate vertical tolerance**:

```lua
Config.Show = { radius = 6.0, zTolerance = 2.5 }
```

A plain 3D distance would push your ID through the ceiling of a police lobby to
whoever is standing on the floor above. Checking height separately is the whole
point, so keep `zTolerance` below one storey.

Holding the item is re-checked on the server too. The client asking to show a
document is not proof it has one.

## No NUI focus, ever

The card renders bottom centre and takes no cursor. It is something you glance
at while the world carries on, and grabbing focus would turn a glance into a
menu, freezing both people mid-conversation.

## Documents

`Config.Documents` maps an inventory item to a card layout. Adding one is config
plus a `client.export` line in `ox_inventory/data/items.lua`.

| Item | Card |
|---|---|
| `id_card` | Identity Card |
| `driver_license` | Driver Licence |
| `weaponlicense` | Firearms Permit |

Setting `licence` on a document makes the card read `som_licenses` and print
**VALID**, **REVOKED** or **NOT ISSUED**. A revoked licence should look revoked
rather than simply being absent, so police have something to react to.

## The photo

**There is none yet, and the silhouette is deliberate.**

NUI cannot read the game's ped headshot texture: `RegisterPedheadshot` produces a
txd usable by `DrawSprite`, not something a browser can load. A real photo has to
come from a URL stored in `som_characters.photo`, filled in by something that can
capture and host an image.

The column exists and the card renders it when set, falling back to the
silhouette if the URL is missing or broken. Nothing else is blocked by this.

## ox_inventory patch

Three `client.export` lines in `data/items.lua`. **Re-apply after an
ox_inventory upgrade**, alongside the other patched areas listed in
`som-core/README.md`.

## Known gaps

- No photo, as above.
- Documents cannot be handed to somebody to keep; showing is transient.
- Police cannot demand ID. That belongs in som-police.
- No forged or duplicate documents, which is a crime-side feature worth having.
- Not verified against a live server.
