# Multi-session workflow

How several Claude sessions build, review and ship together. The rules of the
repo itself live in `CLAUDE.md`, `CONTRIBUTING.md` and the `som-release` skill;
this file only says who does what.

## Roles

- **Director.** Decides what to build, assigns one task per builder, answers
  plans with `go`, reviews and commits builder work, opens PRs, merges, deletes
  branches and worktrees, keeps `LAUNCH-TODO.md` honest. The only role that
  commits, pushes or merges.
- **Builder.** One session per feature. Plans first (`stateofmind-plans/<name>.md`
  plus a 10 line summary to the director), waits for `go`, builds in its own
  worktree, runs `lua5.4 tests/run.lua` and `tools/check-lua.sh`, runs
  `/ponytail-review` on its own change and fixes every finding, then reports and
  stops. Builders do not commit, push or open PRs.
- **Reviewer.** A separate session that never builds. It reads a builder's
  finished diff cold and returns findings. It changes no files.
- **Owner.** Promotes `BetaRelease` into `main` and accepts new icons.

## Lifecycle of one feature

1. Director cuts `feature/<name>` from `BetaRelease` in its own worktree
   (`/home/lennox/projects/som-<name>-wt`) and assigns a builder.
2. Builder plans, director replies `go`, builder builds and self-reviews.
3. Director sends the branch to the reviewer. Findings go back to the builder,
   who fixes them and reports again. Repeat until the reviewer has nothing real.
4. Director reads the money and ownership paths personally, runs the tests,
   and commits with a public, player readable subject as Lennox. No attribution
   lines anywhere.
5. The branch is merged and deleted, then its worktree is removed
   (`git worktree remove`). One feature, one branch, one merge.

## Reaching BetaRelease

Work for one update lands on an integration branch `feature/<update-name>`.
Each finished feature branch merges into it and is deleted. When the update is
complete, ONE PR goes from the integration branch to `BetaRelease` with a body of
What, Verified, Not verified, Scope cuts, and CI must pass first. Merge with the
REST API merge commit (see `som-release`), delete the branch, pull. Never push
to `BetaRelease` or `main`, never force-push, never squash a promotion.

## Rules every session follows

- Server is the authority; every handler validates its arguments.
- Natives and exports are confirmed in the installed resources, never invented.
- New features ship disabled until their coordinates and numbers are placed.
- Anything unset or not run in a live FXServer goes in `LAUNCH-TODO.md`, and
  reports say plainly what was not verified.
- Worktrees are about 100 MB each: remove them as soon as the branch is merged.
