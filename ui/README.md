# SOM NUI workspace

The first JavaScript build tooling in this project. Everything else in
`resources/` is hand-written HTML, CSS and JS with no build step, and that
stays true: this workspace does not touch those resources, it only produces
output for the ones that opt in.

## Layout

```
ui/
  packages/som-ui-kit/   the shared component kit, imported by every app
  apps/<resource>/       one vite app per NUI, builds INTO that resource
```

## The rules that are easy to get wrong

**Colour and type come from `som-assets/tokens.css`, which the kit never
copies.** The kit's CSS only ever reads `var(--som-*)`. Each app's
`index.html` links `https://cfx-nui-som-assets/tokens.css` at runtime, so
there is exactly one file on the server defining the palette and the font. A
copy in here would drift, which is the specific mistake `tokens.css` was
created to end.

**Build output is committed.** FiveM serves files off disk and has no build
step of its own, so `dist` is not ignored here the way it would be in a normal
web project. If the built assets are not in git, the resource is broken on a
fresh clone.

**Filenames are not hashed.** `vite.ts` pins `[name].js` and `[name].css`
rather than the default `[name]-[hash].js`, because a FiveM resource has to
list its files in `fxmanifest.lua` and a hash that changes every build would
mean editing the manifest every build.

**`base` is `./`.** NUI loads the page from a `cfx-nui-<resource>` origin, and
absolute `/assets/...` paths resolve off the root of that origin rather than
the page's folder. Relative paths are the only ones that work.

## Commands

```
npm install          once, at ui/
npm run build        builds every app into its resource
npm run typecheck    whole workspace
```

Per app: `npm run build -w apps/<name>`.

## Adding an app

1. `apps/<name>/` with `package.json`, `index.html`, `src/main.tsx`.
2. `vite.config.ts` calling `somApp()` from the kit, giving it the resource
   path to build into.
3. Add the built files to that resource's `fxmanifest.lua` `files{}` block.
   Forgetting this is silent: the page loads and the assets 404.
