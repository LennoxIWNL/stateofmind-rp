# State of Mind — PM2 deployment package

This folder contains two self-contained Node.js processes managed by PM2:

| Process | File | Purpose |
|---|---|---|
| `discord-bot` | `index.mjs` | The Discord bot (bump reminders, tickets, slash commands) |
| `git-webhook` | `git-webhook.mjs` | GitHub push → instant `git pull` on your VPS. Pull only, never push. |

---

## Bump reminders

The bot uses Disboard's 120-minute cooldown. It sends one reminder with a direct
mention when the cooldown expires, then stays silent until Disboard confirms a
successful `/bump`. The reminder state is saved locally so a PM2 restart cannot
make it spam repeatedly.

---

## One-time setup on your VPS

### 1. Install Node.js 22+
```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
node -v   # should print v22+
```

### 2. Install PM2 globally
```bash
npm install -g pm2
```

### 3. Copy this folder to your VPS
```bash
scp -r ./pm2-package youruser@your-vps-ip:/home/youruser/discord-bot
```
Or transfer it any way you prefer (SFTP, rsync, etc.)

### 4. Create your .env file
```bash
cd /home/youruser/discord-bot
cp .env.example .env
nano .env     # fill in every value — see comments in the file
```

### 5. Make sure git is installed and your repo is cloned
```bash
git --version          # should already be installed on most Linux servers
cd /path/to/your/repo
git remote -v          # confirm origin is pointing to GitHub
```

**Important — disable push access so the webhook can never accidentally push:**
```bash
git -C /path/to/your/repo remote set-url --push origin DISABLED
```
This makes `git push` throw an error from this directory, permanently. Fetch and pull still work normally.

### 6. Open the webhook port in your firewall
```bash
sudo ufw allow 9000/tcp    # or whatever port you set as WEBHOOK_PORT
```

### 7. Start both processes with PM2
```bash
cd /home/youruser/discord-bot
pm2 start ecosystem.config.cjs
pm2 save          # persist the process list
pm2 startup       # follow the printed instructions to survive reboots
```

---

## GitHub webhook setup

1. Go to your GitHub repo → **Settings → Webhooks → Add webhook**
2. Fill in:
   - **Payload URL:** `http://YOUR-VPS-IP:9000/webhook`
   - **Content type:** `application/json`
   - **Secret:** the same value as `WEBHOOK_SECRET` in your `.env`
   - **Which events:** Just the **push** event
3. Click **Add webhook** — GitHub will send a test ping and you should see a green tick

Every time you push to the watched branch, GitHub calls the webhook, the listener verifies
the signature, and runs:
```bash
git -C /your/repo fetch --all --prune
git -C /your/repo reset --hard origin/main
```
Changes are live on your server within a couple of seconds of your push.

---

## Useful PM2 commands

```bash
pm2 status                        # see both processes
pm2 logs discord-bot              # live bot logs
pm2 logs git-webhook              # live webhook logs (shows every sync)
pm2 restart discord-bot           # restart bot after updating index.mjs
pm2 restart git-webhook           # restart webhook listener
pm2 restart all                   # restart everything
```

## Updating the bot later

1. Make your changes in Replit
2. Run `node pm2-package-build.mjs` inside `artifacts/api-server/`
3. Copy the new `index.mjs` (and `git-webhook.mjs` if it changed) to your VPS
4. Run `pm2 restart all`

The GitHub auto-pull process handles server resource updates automatically — you only
need to manually copy files when the bot itself changes.
