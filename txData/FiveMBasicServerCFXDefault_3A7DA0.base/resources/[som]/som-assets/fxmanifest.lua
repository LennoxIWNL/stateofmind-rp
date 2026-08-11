fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-assets'
author 'State of Mind RP'
description 'Shared SOM branding: design tokens and logo assets consumed by every som-* NUI'
version '0.1.0'

files {
    'tokens.css',
    'img/*.png',
    'img/*.svg',
    -- Vehicle shots, keyed by SPAWN NAME (blista.png, polvstr.png).
    --
    -- One folder for the whole server rather than a copy per resource, so the
    -- rental counter, the garage list and a future dealership all draw the same
    -- car the same way. A missing file is expected while the set is incomplete
    -- and every consumer falls back rather than showing a broken image, so this
    -- folder can be filled in over time without anything breaking meanwhile.
    'img/vehicles/*.png',
    -- Oswald, served from THIS resource.
    --
    -- Consumers link tokens.css as https://cfx-nui-som-assets/tokens.css, so a
    -- relative url() inside it resolves against this resource's origin. That
    -- means only som-assets needs these listed, not every consuming NUI.
    --
    -- Shipped rather than linked. A webfont from a CDN is the same failure that
    -- took out ps-mdt's editor and interact-sound's audio: it works on the
    -- machine you tested on and silently falls back to nothing on a client
    -- whose network blocks it.
    'fonts/oswald/*.ttf',
}
