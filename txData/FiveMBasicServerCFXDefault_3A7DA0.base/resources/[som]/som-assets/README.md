# som-assets

Shared branding. One design token file and the logo assets, consumed by every `som-*` NUI.

## Why

There is currently no shared token file anywhere in the server. Every resource hardcodes `#ff1493`, and the only two `:root` blocks that exist (in `som-gangboss-app` and `som-jobsetup`) have already drifted apart on five of six values. See `AUDIT.md` section 5.2.

## Usage

```html
<link rel="stylesheet" href="https://cfx-nui-som-assets/tokens.css">
```

Then use the variables. Do not redefine them locally.

```css
.panel {
    background: var(--som-card);
    border: var(--som-border);
    box-shadow: var(--som-shadow), var(--som-glow);
    color: var(--som-text);
}
```

Three ready-made classes are included: `.som-panel`, `.som-btn`, `.som-key`.

## Palette

Extracted from the server logo and the existing UI set. Full table with occurrence counts in `AUDIT.md` section 5.1.

| Token | Value | Role |
|---|---|---|
| `--som-pink` | `#ff1493` | Primary brand |
| `--som-pink-light` | `#ff69b4` | Hover, glow |
| `--som-pink-dark` | `#c2185b` | Pressed |
| `--som-bg` | `#0a0a12` | Background |
| `--som-surface` | `#3d1735` | Plum panel surface |
| `--som-text` | `#e0e0e0` | Body text |
| `--som-danger` / `--som-success` | `#e74c3c` / `#2ecc71` | Status |

Alpha ramp `--som-pink-a16` through `--som-pink-a80` matches the glow convention already used across the existing UIs.

## Logo assets (Phase 1 step, not yet done)

`img/` is intentionally empty. The rebuild spec says relocate branding here **before** deleting its current container, and that container (`[custom]/loadingscreen`) is still live. Copy these in during Phase 1:

```
resources/[custom]/loadingscreen/nui/dist/assets/som-logo.png   ->  img/som-logo.png
resources/[custom]/loadingscreen/nui/dist/assets/bgLogo-28542b40.svg  ->  img/hex-frame.svg
myLogo.png (base folder, square txAdmin icon)                   ->  img/som-icon.png
```

`logo-187456c5.png` is byte-identical to `som-logo.png` and does not need copying.

Note that `logoProgress-8e2224ea.svg` hardcodes `#ff1493` in its stroke, so it needs editing rather than a straight copy if the palette ever changes.

## Reference implementation

The `ox_inventory` reskin (commit `7c788a62`) is the cleanest existing example of this palette applied correctly, with no leftover teal. Use it as the visual reference rather than `som-lib` or `som-textui`, both of which still have teal backgrounds under pink accents.
