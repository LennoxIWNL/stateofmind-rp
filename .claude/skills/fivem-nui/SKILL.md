---
name: fivem-nui
description: NUI work in this repo (React ui workspace, committed builds, test harness). Load before touching any UI.
---

# NUI

- Sources are in `ui/` (npm workspace: `ui/apps/<name>`, shared `ui/packages/*`). Built output is committed under each resource's `html/`; never hand-edit `html/assets`. Rebuild from `ui/`, then commit the build.
- Type check the phone with `npx tsc --noEmit -p apps/som-phone` from `ui/`.
- The phone host app format (`som-phone` `HostApp.tsx`): a server handler returns `view = { sections = { { title, rows = { { title, sub, action, payload } } } }, buttons = { { label, action, payload, danger, prompt = { field, label, maxLength } } }, empty }`. Text is set as text, never HTML. Icons are names from `ui/packages/som-phone-sdk/src/icons.tsx` (adding one needs a rebuild; reuse `briefcase`, `contacts`, `bank` etc. otherwise).
- Server events to refresh a phone app: `TriggerClientEvent('som-phone:client:refresh', src)`; notify with `exports['som-phone']:notifyApp(src, appId, text)`.
- The UI asks the server for its data when it opens; do not push data on open.
- Test with `node tests/nui/run.mjs` (headless Chromium, `cfx-nui-*` served from disk, screenshots in `tests/nui/screenshots/`). Read the screenshots; a passing script does not mean it looks right.
- No stock-script UI, floating ground circles, or default popups.
