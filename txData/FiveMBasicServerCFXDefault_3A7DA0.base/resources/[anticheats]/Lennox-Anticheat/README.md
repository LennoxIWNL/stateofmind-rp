# 🛡️ Lennox Anti-Cheat

A lightweight, server-authoritative anti-cheat for FiveM. Plug-and-play, easy to
configure, and built to stop the most common cheat clients with near-zero false
positives.

---

## ✨ Features

- **Weapon protection** — blocks blacklisted weapons (minigun, railgun, etc.), rapid-fire, and impossible damage.
- **Explosion & entity protection** — stops explosion spam, blacklisted blast types, and mass entity/prop spawning.
- **Movement checks** — flags teleporting and speed hacks (with smart exemptions so respawns and interiors never false-flag).
- **Honeypot traps** — instantly bans cheaters who trigger admin/money events that no legitimate player can.
- **Resource & tamper detection** — catches known cheat menus and AC tampering.
- **Smart ban system** — multi-identifier + token bans that block ban evasion and alt accounts on connect.
- **Full Discord logging** — 5 separate channels (bans, kicks, flags, events, connections).
- **Admin-safe** — your staff are automatically excluded from all actions.

---

## 📋 Requirements

- A FiveM server (any framework — **standalone**).
- *Optional:* `qb-log` — if present, bans are also mirrored to your existing `anticheat` log channel. Not required.

---

## 📥 Installation

1. Drop the `Lennox-Anticheat` folder into your server's `resources` directory.
2. Add this to your `server.cfg` (place it **near the top**, right after your framework so it loads early):
   ```
   ensure Lennox-Anticheat
   ```
   > If you keep it inside a `[custom]` folder that's already `ensure`d, it will auto-start — no extra line needed.
3. Open `config.lua` and fill in your settings (see below).
4. Restart your server. You'll see the Lennox banner in the console when it loads. ✅

---

## ⚙️ Configuration

Everything you need to edit lives in **`config.lua`**. You never need to touch any
file in `server/` or `client/`.

### 1. Discord Webhooks

Create 5 channels in your Discord and paste a webhook for each:

```lua
LACConfig.Webhooks = {
    bans        = 'https://discord.com/api/webhooks/...',  -- confirmed auto-bans (@here ping)
    kicks       = 'https://discord.com/api/webhooks/...',  -- kicks / soft actions
    flags       = 'https://discord.com/api/webhooks/...',  -- warnings & anomalies
    events      = 'https://discord.com/api/webhooks/...',  -- blocked weapons/explosions/entities
    connections = 'https://discord.com/api/webhooks/...',  -- ban-evasion & tamper alerts
}
```

> **How to get a webhook:** Discord → Channel Settings → Integrations → Webhooks → New Webhook → Copy URL.

### 2. Admin Immunity (IMPORTANT)

Your staff must be excluded so they're never actioned. There are **two ways** —
use either or both:

**Option A — by permission (recommended).** Anyone with these aces is auto-immune. By default this covers `qbcore.god` and anyone in `group.admin`:
```lua
LACConfig.AdminAces = {
    'qbcore.god',
    'command',
}
```

**Option B — by identifier.** Add specific staff identifiers (license/steam/discord):
```lua
LACConfig.AdminIdentifiers = {
    'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    'steam:110000xxxxxxxxx',
}
```

> 💡 Always add **at least your own license** here before going live, so you can never lock yourself out.

### 3. Sensitivity (optional)

Defaults are tuned for a normal RP server. Lower = stricter, higher = more lenient.

| Setting | What it does | Default |
|---|---|---|
| `KickThreshold` | Score that triggers a kick | `15` |
| `BanThreshold` | Score that triggers a ban | `25` |
| `MaxOnFootSpeed` | Max running speed (m/s) before flagging | `15.0` |
| `TeleportDistanceThreshold` | Jump distance (m) that counts as a teleport | `200.0` |
| `MaxExplosionsPer5Sec` | Explosion spam limit | `5` |
| `MaxEntitiesPer2Sec` | Entity spawn spam limit | `15` |

You can also edit the **blacklisted weapons/explosions** and **cheat-menu name**
lists in the same file.

### 4. Honeypots (read this once)

```lua
LACConfig.Honeypots = { 'admin:giveWeapon', 'server:addCash', ... }
```

These are fake "admin" events that instantly ban anyone who triggers them — a
cheater poking around will hit one and ban themselves. **Before going live, make
sure none of these names are real events used by another resource on your
server.** If unsure, leave the defaults; they're chosen to be uncommon.

---

## 🎮 Commands

| Command | Where | Who | What it does |
|---|---|---|---|
| `/cheater [id]` | In-game chat | Admins | **Test command.** Force-bans a player (works on yourself too) to verify the system. |
| `lac_unban [banId or identifier]` | Server / txAdmin console | Admins / Console | Removes a ban so the player can rejoin. |

---

## 🧪 Testing It Works

1. Join your server.
2. Open chat and run `/cheater [your server id]` (find your ID on the scoreboard/playerlist).
3. You'll be banned and kicked, a `#lennox-ac-bans` Discord alert will fire, and if you try to rejoin you'll be blocked. 🎉

### 🔓 How to unban yourself afterwards

You're locked out of the game, but **not the console**:

- **Easiest:** Open **txAdmin → Live Console** (or your server console) and run:
  ```
  lac_unban license:YOUR_LICENSE_HERE
  ```
  Then reconnect. (The Ban ID also works: `lac_unban LAC-XXXXXX`.)

- **Or:** Open `data/bans.json`, replace everything with `[]`, save, and run
  `restart Lennox-Anticheat` in console.

---

## ❓ FAQ / Troubleshooting

**The console shows "integrity check failed" / "ABORTING".**
Core files were modified. Restore the original `server/` and `client/` files — do not edit them.

**Discord logs aren't appearing.**
Double-check the webhook URLs in `config.lua` are complete and pasted in full. Test the channel by running `/cheater` on a test account.

**A legit player got kicked.**
Raise the relevant threshold in `config.lua` (e.g. `MaxOnFootSpeed` for runners, `KickThreshold` overall). Heuristic checks can only ever *kick*, never auto-ban — bans require deterministic proof.

**Will it ban my admins?**
No — anyone matching `AdminAces` or `AdminIdentifiers` is fully immune. Set this up before going live.

**Does it need a database?**
No. Bans are stored in `data/bans.json` out of the box.

---

## ⚠️ Notes

- **Do not edit anything in `server/` or `client/`.** All your settings live in `config.lua`. Modifying core files will stop the anti-cheat from loading.
- Keep `config.lua` (with your webhooks) private — don't post it publicly.

---

## 🧾 Credits

**Lennox Anti-Cheat** — created by **Lennox**.
Redistribution or resale with the author credit removed is not permitted.
