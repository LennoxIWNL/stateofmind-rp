## What and why

<!-- What changed, and the reason. Link the AUDIT.md roadmap entry if relevant. -->

## Scope

<!-- Anything deliberately left out, so it is a recorded decision and not a silent cut. -->

## Verification

- [ ] `lua5.4 tests/run.lua` passes
- [ ] `node tests/nui/run.mjs` passes (if UI changed)
- [ ] New or changed persistence, money or ownership logic has a test
- [ ] No secrets or webhook URLs committed
- [ ] `LAUNCH-TODO.md` updated if this leaves anything unset or unverified
- [ ] Promotion PR only: the in-game checklist passed on the beta server
- [ ] Not verified in a live FXServer: <!-- list what still needs an in-game pass -->

## Deploy notes

<!-- setup.sql sections to import, convars to set in server.cfg, resources to ensure. "None" if none. -->
