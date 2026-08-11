import { somApp } from '@som/ui-kit/vite'

/**
 * Builds INTO ox_inventory, not into a som-* resource, and that is deliberate.
 *
 * fetchNui posts to the origin that served the page, and a RegisterNUICallback
 * only answers for the resource owning the frame. Served from anywhere else,
 * all eleven of ox_inventory's callbacks would go unanswered and nothing could
 * be moved, used or bought. See src/contract.ts.
 *
 * `web/som/` is a NEW folder beside their `web/build/`, so their output is
 * untouched and reverting is two lines in their fxmanifest.
 */
export default somApp({
  outDir: '../../../txData/FiveMBasicServerCFXDefault_3A7DA0.base/resources/[standalone]/ox_inventory/web/som',
})
