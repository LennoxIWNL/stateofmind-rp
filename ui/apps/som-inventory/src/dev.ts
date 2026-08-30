/**
 * Browser mock for som-inventory.
 *
 * The inventory is the most-touched screen on the server and the hardest to
 * iterate on, because seeing it means joining the game, spawning, finding
 * items and pressing TAB. This file renders the same screen in a browser from
 * `npm run dev`, against data shaped exactly like ox_inventory's.
 *
 * INERT IN GAME. `debugData` returns immediately unless `IS_BROWSER`, which is
 * only true when the page is served from something other than a `cfx-nui-*`
 * origin. Nothing here can reach a live inventory, and nothing here is a way
 * to inject state into one: the page has no authority over items in either
 * environment, the server does.
 *
 * The payloads are the real contract, so this is also the cheapest check that
 * `contract.ts` still describes reality. If a field is renamed upstream and
 * this file is not updated, the browser render breaks in the same way the game
 * render would, which is the point.
 *
 * Item images are served by the dev-only middleware in `vite.config.ts`, which
 * points at ox_inventory's own `web/images`, so icons here are the icons in
 * game rather than placeholders.
 */

import { debugData } from '@som/ui-kit'
import { INBOUND, type ItemData, type Inventory } from './contract'

const IMAGEPATH = '/oxitems'

/**
 * The palette and the font.
 *
 * index.html links these from `https://cfx-nui-som-assets/tokens.css`, an
 * origin that only exists inside FiveM, so in a browser every `var(--som-*)`
 * resolves to nothing: no panel, no borders, no Oswald. Injected here rather
 * than added as a second <link> in index.html, because index.html ships and a
 * link that 404s in game is noise in the CEF console forever.
 */
{
  const link = document.createElement('link')
  link.rel = 'stylesheet'
  link.href = '/somassets/tokens.css'
  document.head.appendChild(link)
}

function item(
  name: string,
  label: string,
  extra: Partial<ItemData> = {},
): [string, ItemData] {
  return [
    name,
    { name, label, stack: true, usable: false, close: true, count: 0, ...extra },
  ]
}

const ITEMS: Record<string, ItemData> = Object.fromEntries([
  item('money', 'Cash'),
  item('phone', 'Phone', { usable: true }),
  item('lockpick', 'Lockpick', { usable: true, description: 'Bent by hand. Will not survive many doors.' }),
  item('joint', 'Joint', { usable: true }),
  item('water', 'Water', { usable: true }),
  item('burger', 'Burger', { usable: true }),
  item('sandwich', 'Sandwich', { usable: true }),
  item('cola', 'Cola', { usable: true }),
  item('bandage', 'Bandage', { usable: true }),
  item('radio', 'Radio', { usable: true }),
  item('armour', 'Body Armour', { usable: true }),
  item('WEAPON_PISTOL', 'Pistol', { stack: false, usable: true }),
])

/** Mirrors a real character carrying a bit of everything. */
const LEFT: Inventory = {
  id: 'CHAR-1',
  type: 'player',
  slots: 50,
  maxWeight: 85000,
  items: [
    { slot: 1, name: 'money', count: 4680, weight: 0 },
    { slot: 2, name: 'WEAPON_PISTOL', count: 1, weight: 1000, durability: 84, metadata: { serial: 'SOM-4471X', registered: 'Lennox' } },
    { slot: 3, name: 'joint', count: 3, weight: 12 },
    { slot: 4, name: 'lockpick', count: 2, weight: 160 },
    { slot: 5, name: 'phone', count: 1, weight: 190 },
    { slot: 6, name: 'radio', count: 1, weight: 220 },
    { slot: 7, name: 'water', count: 4, weight: 500 },
    { slot: 8, name: 'burger', count: 1, weight: 220 },
    { slot: 9, name: 'bandage', count: 6, weight: 100 },
    { slot: 12, name: 'armour', count: 1, weight: 3000, durability: 61 },
    { slot: 14, name: 'sandwich', count: 2, weight: 190 },
    { slot: 18, name: 'cola', count: 3, weight: 350 },
  ],
}

debugData([
  {
    action: INBOUND.init,
    data: {
      locale: {},
      items: ITEMS,
      leftInventory: LEFT,
      imagepath: IMAGEPATH,
    },
  },
])

// Separate message, and after init, because setupInventory is also what opens
// the UI. Sending them together would race the catalogue that the slots are
// rendered against.
debugData([{ action: INBOUND.setupInventory, data: { leftInventory: LEFT } }], 80)
