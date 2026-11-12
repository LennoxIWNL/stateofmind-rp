---
name: som-release
description: The branch, commit, PR, CI and merge loop for this repo, including how to unstick a hung CI run. Load before committing.
---

# Shipping a change

1. `git checkout BetaRelease && git pull --ff-only`, then `git checkout -b feature|fix|chore|docs/<kebab-case>`. Never commit to `BetaRelease` or `main`; never force-push either.
2. Commit messages are public (Discord #changelogs): a specific, player readable subject plus a 2 to 4 line body of what players or staff get. Work for one update lives on one integration branch `feature/<update-name>` and goes to `BetaRelease` in ONE PR and one merge commit, not feature by feature. Commit as `Lennox <95040675+LennoxIWNL@users.noreply.github.com>` (the session hook sets it). Subject imperative and short, body says why. No person, tool, AI or session identifiers, no `Co-Authored-By`, no "Generated with". No em dashes.
3. Before opening the PR: `lua5.4 tests/run.lua`, `tools/check-lua.sh`, `python3 tools/check-item-icons.py` if items changed, `node tests/nui/run.mjs` if UI changed, `fivemAudit` on new server files, new SQL on the dev database, `ensure` on the headless server and read the console.
4. `git push -u origin <branch>` then `gh pr create --base BetaRelease` with a body of: What, Verified, Not verified, Scope cuts. Add anything unset or unverified (coordinates, prices, convars, tables to import) to `LAUNCH-TODO.md`.
5. Wait for CI: `until s=$(gh pr checks N); ! echo "$s" | grep -qi "pending\|queued\|in_progress"; do sleep 15; done`. Run long waits with `run_in_background`; do not chain `sleep` commands.
6. Merge with the REST API (retry up to 3 times): `gh api -X PUT repos/LennoxIWNL/stateofmind-rp/pulls/N/merge -f merge_method=merge`. Then `git push origin --delete <branch>`, `git checkout BetaRelease && git pull --ff-only`, `git branch -D <branch>`.
7. A CI check stuck "pending" for ten minutes: `gh run cancel <id>`, wait until it reports `completed`, then `gh pr close N && gh pr reopen N` to start a fresh run. Do not `pkill` gh processes; it can kill the shell.
8. Update the progress note in the memory file `roadmap-progress.md`.
Promotion `BetaRelease` into `main` is the owner's job.

## Two sessions in one checkout
Another Claude session may be working in the same directory. Run `git branch --show-current` and `git status` before every commit; if the branch is not yours, do not `git add -A` there. Worktrees are full copies of the repo (about 100 MB each), so use at most ONE extra worktree at a time, and remove it with `git worktree remove` as soon as its branch is merged. Never reset or delete a branch you did not create.
