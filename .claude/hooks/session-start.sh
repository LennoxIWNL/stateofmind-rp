#!/usr/bin/env bash
# Runs at the start of every Claude Code session in this repo. Sets the commit
# identity locally, makes sure the test tooling exists, and reminds the session
# of the branch rules. Never fails the session.
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0

git config --local user.name "Lennox"
git config --local user.email "95040675+LennoxIWNL@users.noreply.github.com"

if ! command -v lua5.4 >/dev/null 2>&1; then
  sudo_cmd=""
  [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && sudo_cmd="sudo -n"
  $sudo_cmd apt-get install -y lua5.4 >/dev/null 2>&1 || echo "could not install lua5.4; tests/run.lua will not run"
fi

branch="$(git branch --show-current 2>/dev/null)"
echo "Repo rules are in CLAUDE.md and CONTRIBUTING.md."
echo "Branch: ${branch:-detached}. Work on feature/|fix/|chore/|docs/<kebab-case> branched from main; never commit to main directly."
echo "Commits are authored as Lennox with no co-author, tool, AI or session lines."
case "$branch" in
  main) echo "WARNING: you are on main. Create a branch before editing." ;;
  claude/*) echo "WARNING: branch name has a tool identifier; rename it to a descriptive feature/ or fix/ name." ;;
esac
exit 0
