module.exports = {
  apps: [
    // ── Discord bot ──────────────────────────────────────────────────────────
    {
      name: "discord-bot",
      script: "./index.mjs",
      interpreter: "node",
      cwd: __dirname,
      autorestart: true,
      watch: false,
      max_restarts: 20,
      restart_delay: 5000,
      env: {
        NODE_ENV: "production",
        // DISCORD_TOKEN loaded from .env in this folder
      },
    },

    // ── GitHub auto-pull webhook ─────────────────────────────────────────────
    // Listens for GitHub push events and runs git fetch + git reset --hard.
    // It can NEVER push — there is no push code path.
    {
      name: "git-webhook",
      script: "./git-webhook.mjs",
      interpreter: "node",
      cwd: __dirname,
      autorestart: true,
      watch: false,
      max_restarts: 10,
      restart_delay: 3000,
      env: {
        NODE_ENV: "production",
        // WEBHOOK_SECRET, REPO_PATH, BRANCH, WEBHOOK_PORT loaded from .env
      },
    },
  ],
};
