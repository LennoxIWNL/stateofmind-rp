import { somApp } from '@som/ui-kit/vite'
import { createReadStream, existsSync, statSync } from 'node:fs'
import { extname, join, normalize, resolve } from 'node:path'
import type { Plugin } from 'vite'

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
const config = somApp({
  outDir: '../../../txData/FiveMBasicServerCFXDefault_3A7DA0.base/resources/[standalone]/ox_inventory/web/som',
})

const RESOURCES = resolve(
  process.cwd(),
  '../../../txData/FiveMBasicServerCFXDefault_3A7DA0.base/resources',
)

const TYPES: Record<string, string> = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.css': 'text/css',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
}

/**
 * Serves resource folders to the browser mock.
 *
 * In game this page is served by ox_inventory and reaches its icons over
 * `nui://`, and reaches the palette over `https://cfx-nui-som-assets/`. Neither
 * origin exists in a browser, so `npm run dev` would otherwise render the right
 * markup with no icons, no colours and no font, which is not worth looking at.
 *
 * `apply: 'serve'` so none of this exists in a build.
 *
 * Path handling: the URL is normalised and the resolved path is checked to be
 * inside its root before anything is opened, so `..%2f..%2fserver.cfg` cannot
 * walk out. A dev server that will read any file on the machine is worth
 * avoiding even bound to localhost.
 */
function resourceStatic(prefix: string, root: string): Plugin {
  const base = resolve(RESOURCES, root)

  return {
    name: `som-dev-static${prefix.replace(/\//g, '-')}`,
    apply: 'serve',
    configureServer(server) {
      server.middlewares.use(prefix, (req, res, next) => {
        let requested: string
        try {
          requested = decodeURIComponent((req.url ?? '').split('?')[0])
        } catch {
          return next()
        }

        const file = resolve(join(base, normalize(requested)))
        const type = TYPES[extname(file).toLowerCase()]

        if (
          !type ||
          !file.startsWith(base) ||
          !existsSync(file) ||
          !statSync(file).isFile()
        ) {
          return next()
        }

        res.setHeader('Content-Type', type)
        res.setHeader('Cache-Control', 'no-cache')
        createReadStream(file).pipe(res)
      })
    },
  }
}

config.plugins = [
  ...(config.plugins ?? []),
  resourceStatic('/oxitems', '[standalone]/ox_inventory/web/images'),
  resourceStatic('/somassets', '[som]/som-assets'),
]

export default config
