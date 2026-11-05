# Inventory icon audit

Run 2026-08-11 against `ox_inventory` v2.45.0.

Cross-references every registered item key against
`[standalone]/ox_inventory/web/images/*`.

## How a filename is actually resolved

Read from the source rather than assumed, because getting this wrong is what
makes every weapon read as unmatched:

- `web/src/helpers/index.ts:156-159` builds `` `${imagepath}/${itemName}.png` ``.
  **The item name is used verbatim and is never lowercased.**
- `modules/items/shared.lua` stores `ItemList[k]` with the key exactly as
  written, so `items.lua` keys stay lowercase while `weapons.lua` keys
  `Weapons` and `Components` in UPPERCASE and `Ammo` in lowercase.
- An explicit `client.image` beats the name, and `setImagePath` leaves any
  value carrying a `scheme://` prefix alone.
- `imagepath` is the `inventory:imagepath` convar, default
  `nui://ox_inventory/web/images` (`init.lua:95`).

So the expected file for `WEAPON_PISTOL` is `WEAPON_PISTOL.png`, not
`weapon_pistol.png`. On disk 113 weapon icons are uppercase and the only
lowercase one, `weapon_license.png`, is orphan art belonging to no item.

## Result

| Result | Count |
|---|---:|
| Exact match, art shows today | 730 |
| Case-only mismatch | 0 |
| Ambiguous, needs manual review | 7 |
| Missing, no art at all | 67 |
| Orphan art, on disk but unclaimed | 42 |

804 registered items: 606 in `items.lua`, and 198 in `weapons.lua`
(`Weapons` 108, `Components` 70, `Ammo` 20; there is no `Tints` section on this
install).

**Case-only mismatches are zero**, which is the headline. The casing trap the
handoff warned about does not bite on this install: the weapon art was already
shipped uppercase to match the keys.

## A. Newly matched (1)

| Item | Was | Now |
|---|---|---|
| `at_muzzle_precision` | `at_muzzle_precision'.png` | `at_muzzle_precision.png` |

A stray apostrophe in the filename. Renamed, because it is not a judgement
call: the file was orphan art, the item had no art, and the two names are
identical but for the typo.

**`ifak` is already fixed and was the wrong lead.** The item is `ifaks`, and it
carries an explicit `image = 'ifak.png'` which resolves to art that exists. A
previous session renamed it, recorded in `som-economy/shared/config.lua:207`.
Whatever the owner saw, it was not a missing `ifak` icon.

## B. Ambiguous, needs manual review (7). Nothing renamed

Every one of these is a **false positive** from substring matching, and I
confirmed each candidate file is already claimed by a different real item. None
is available as a rename target, so none should be touched.

| Item wanting art | Candidate found | Verdict |
|---|---|---|
| `glasses` | `glass.png` | Claimed by item `glass` (`items.lua:1356`) |
| `bandageg` | `bandage.png` | Claimed by item `bandage` (`items.lua:56`) |
| `dirty_orange` | `orange.png` | Claimed by item `orange` (`items.lua:2654`) |
| `WEAPON_BATTLERIFLE` | `WEAPON_BAT.png` | Claimed by `WEAPON_BAT`, a baseball bat |
| `at_skin_diamond` | `diamond.png` | Claimed by item `diamond` (`items.lua:1617`) |
| `at_skin_splatter` | `latte.png` | Coincidence. "sp-latte-r". Claimed by a coffee item |
| `at_skin_burgershot` | `burger.png` | Claimed by item `burger` (`items.lua:73`) |

The one pairing that **is** worth a human decision, and which I have not acted
on:

| Item wanting art | Orphan art that would fit | Why it needs your call |
|---|---|---|
| `nikon` | `camera.png` | `nikon` is a camera and `camera.png` is unclaimed, so this is probably right. It is still a guess about intent, and a wrong rename blanks the art silently |

## C. Still missing (67)

**Three are live on this server and are the ones worth fixing first:**

| Item | Used by | Note |
|---|---|---|
| `ammo-taser` | `som-police`, `som-economy` | **Ours.** Added by us per AUDIT 16.2, and shipped with no art |
| `rental_papers` | `som-rentals/config.lua` | |
| `mdtcitation` | `ps-mdt/server/main.lua` | Wants `citation.png` via an explicit `client.image` |

**Police, EMS and evidence kit (14).** None used by our resources yet, but all
of them are on the path for the evidence and medical work:
`gsrtestkit`, `dnatestkit`, `drugtestkit`, `breathalyzer`, `fingerprintreader`,
`accesstool`, `spikespack`, `nikon`, `gauze`, `surgical_tray`, `syringe`,
`forceps`, `surgical_gloves`, `surgical_staple`.

**Clothing and appearance (6):** `clothing`, `tshirt`, `torso`, `arms`,
`jeans`, `ears`.

**Other items (4):** `luxuryfinish_attachment`, `emp_ammo`, `cash_bag`,
`inked_cash_bag`.

**Weapons (3):** `WEAPON_SNOWLAUNCHER`, `WEAPON_TACTICALRIFLE`,
`WEAPON_TEARGAS`.

**Weapon skins and components (37).** Purely cosmetic tint art, absent from
stock ox_inventory too. Lowest priority of anything here:
`at_compensator`, `at_scope_macro`, and 35 `at_skin_*` entries (`luxe`, `wood`,
`metal`, `pearl`, `ballas`, `dollar`, `hate`, `king`, `love`, `pimp`, `player`,
`vagos`, `blagueurs`, `bulletholes`, `cluckinbell`, `fatalincursion`,
`luchalibre`, `trippy`, `tiedye`, `wall`, `vip`, `bodyguard`, `festive`,
`security`, `camo`, `brushstroke`, `woodland`, `skull`, `sessanta`, `perseus`,
`leopard`, `zebra`, `geometric`, `boom`, `patriotic`).

## D. Orphan art, on disk and unclaimed (42)

Not a fault. This is the stock available to fill lists B and C, and the
starting inventory for the task 12 prop/icon/animation binder.

```
ammo-beanbag.png   body_cam.png       camera.png         carkey.png
cigarette.png      cigarettes_redwood.png                cocaine.png
donut.png          ducttape.png       fries.png          idcard.png
identification.png key.png            medikit.png        meth.png
oldkey.png         pizza_ham.png      pizza_ham_box.png  pizza_ham_slice.png
readme.md          trash.png          trash_bread.png    trash_burger.png
trash_can.png      trash_chips.png    usb_black.png      weaponlicense.png
weed.png           weed_ak47.png      weed_amnesia.png   weed_skunk.png
xtcbaggy.png       ziptie.png         WEAPON_ACIDPACKAGE.png
WEAPON_BREAD.png   WEAPON_BRIEFCASE.png                  WEAPON_BRIEFCASE_02.png
WEAPON_DIGISCANNER.png                WEAPON_GARBAGEBAG.png
WEAPON_GAS.png     WEAPON_GRENADELAUNCHER_SMOKE.png      WEAPON_HANDCUFFS.png
```

`readme.md` is not art and is stock ox_inventory.

## Reproducing this

The audit is a script, not a one-off reading, so it can be re-run after any
item or art change. It lives outside the repo deliberately; regenerate it from
the resolution rules at the top of this file if it is needed again.

## Additions for the drug chain and hunting (2026-11-05)

Eleven icons copied from `aifazi/items-images` (the community pack this repo already draws on; the repo has no licence file, its README credits community contributors, so treat provenance as community-shared and re-check before any public redistribution). Each is saved under the item name it will carry, ahead of the items themselves, so the items arrive with art:

| File | Source path in the pack |
|---|---|
| `coke_leaf.png` | `drugs/leaf/cocaineleaf.png` |
| `acetone.png` | `drugs/chemicals/acetone.png` |
| `lithium.png` | `drugs/chemicals/lithium.png` |
| `ephedrine.png` | `drugs/chemicals/ephedrine.png` |
| `hydrochloric_acid.png` | `drugs/chemicals/hydrochloricacid.png` |
| `sulfuric_acid.png` | `drugs/chemicals/acid.png` |
| `venison.png` | `hunting/deer_leg.png` |
| `deer_pelt.png` | `hunting/pelt/pelt-deer-1star.png` |
| `antlers.png` | `hunting/antlers.png` |
| `hunting_knife.png` | `weapons/meele/meleeWpnBladeT1HuntingKnife.png` |
| `hunting_license.png` | `license/hunting_license.png` |

No item uses these yet; they are orphan art until the meth chain and hunting branches add the items. Fishing, mechanic and chop shop items reuse art already in the folder (`fishingrod`, `fishbait`, `codfish`, `repairkit`, `scrapmetal`, `steel`, `aluminum`, `plastic`, `rubber`, `copper`, `glass` and others).
