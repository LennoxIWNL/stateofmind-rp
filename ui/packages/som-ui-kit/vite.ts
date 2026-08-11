import { defineConfig, type UserConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { resolve } from 'node:path'

/**
 * The vite config every SOM NUI app uses.
 *
 * Centralised because three of these settings are not preferences, they are
 * the difference between a page that loads in FiveM and one that silently
 * renders nothing. Each app calling this rather than hand-rolling its own is
 * what stops the next app rediscovering them.
 */
export interface SomAppOptions {
  /**
   * Path from the app folder to the resource folder the build lands in,
   * e.g. '../../../txData/.../resources/[som]/som-police/html'.
   */
  outDir: string
  /** Dev server port. Only matters when running vite outside the game. */
  port?: number
}

export function somApp({ outDir, port = 5173 }: SomAppOptions): UserConfig {
  return defineConfig({
    plugins: [react()],

    /**
     * Relative, never absolute.
     *
     * NUI serves the page from a cfx-nui-<resource> origin. An absolute
     * '/assets/app.js' resolves against the root of that origin instead of the
     * page's own folder, so the request 404s and the screen stays blank with
     * no error a player would ever see.
     */
    base: './',

    build: {
      outDir: resolve(process.cwd(), outDir),

      /**
       * The resource folder is not ours alone: index.html, the fxmanifest's
       * other files and any hand-written CSS live beside the build output.
       * Emptying it would delete them.
       */
      emptyOutDir: false,

      // Debugging a minified NUI through CEF's devtools is miserable without
      // these, and they cost nothing at runtime.
      sourcemap: true,

      // CEF in FiveM is recent Chromium, so there is no reason to ship ES5.
      target: 'es2022',

      rollupOptions: {
        output: {
          /**
           * Stable names, no content hash.
           *
           * A FiveM resource declares its files in fxmanifest.lua. Default
           * vite names like app-D4f9x2.js would change on every build and the
           * manifest would need editing every time, which is exactly the kind
           * of step that gets forgotten and produces a resource that starts
           * fine and serves nothing.
           */
          entryFileNames: 'assets/[name].js',
          chunkFileNames: 'assets/[name].js',
          assetFileNames: 'assets/[name].[ext]',
        },
      },
    },

    server: { port },
  })
}
