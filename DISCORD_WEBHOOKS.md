# Discord Webhook Log Channels — State of Mind RP

Ready-to-use checklist of every Discord webhook log channel the server's resources
expect. For each: create a channel in your Discord, make a webhook (Channel →
Integrations → Webhooks → New Webhook), copy its URL, and paste it into the listed
config slot.

> Tip: you can point several log types at one channel, or split them out — your choice.
> All slots below currently ship **blank** except where flagged ⚠️.

---

## 1. `qb-smallresources/server/logs.lua` — central QBCore logging (38 channels)

This is the main log hub used by most `[qb]` resources. Open the `Webhooks` table at
the top of the file and paste a webhook URL between the quotes for each key you want.

| Channel name (suggested) | Key | Logs |
|---|---|---|
| #log-money            | `playermoney`      | Cash/bank balance changes |
| #log-inventory        | `playerinventory`  | Item give/remove/move |
| #log-robbing          | `robbing`          | Player-on-player robbery |
| #log-cuffing          | `cuffing`          | Handcuff actions |
| #log-drops            | `drop`             | Items dropped on ground |
| #log-trunk            | `trunk`            | Vehicle trunk access |
| #log-stash            | `stash`            | Stash access |
| #log-glovebox         | `glovebox`         | Glovebox access |
| #log-banking          | `banking`          | Bank deposits/withdrawals/transfers |
| #log-vehicleshop      | `vehicleshop`      | Vehicle purchases |
| #log-vehicleupgrades  | `vehicleupgrades`  | Mod-shop upgrades |
| #log-shops            | `shops`            | Store purchases |
| #log-dealers          | `dealers`          | Drug dealer transactions |
| #log-storerobbery     | `storerobbery`     | Store robberies |
| #log-bankrobbery      | `bankrobbery`      | Bank/fleeca robberies |
| #log-powerplants      | `powerplants`      | Power plant events |
| #log-death            | `death`            | Player deaths |
| #log-joinleave        | `joinleave`        | Player connect/disconnect |
| #log-ooc              | `ooc`              | OOC chat |
| #log-reports          | `report`           | /report submissions |
| #log-me               | `me`               | /me actions |
| #log-pmelding         | `pmelding`         | Police call-ins (pmelding) |
| #log-112              | `112`              | 112 emergency calls |
| #log-bans             | `bans`             | Ban actions |
| #log-anticheat        | `anticheat`        | Anticheat triggers |
| #log-weather          | `weather`          | Weather/time changes |
| #log-moneysafes       | `moneysafes`       | Safe robberies |
| #log-bennys           | `bennys`           | Benny's mechanic actions |
| #log-bossmenu         | `bossmenu`         | Boss menu (society funds, hire/fire) |
| #log-robbery          | `robbery`          | Generic robbery events |
| #log-casino           | `casino`           | Casino activity |
| #log-traphouse        | `traphouse`        | Traphouse activity |
| #log-911              | `911`              | 911 dispatch calls |
| #log-palert           | `palert`           | Police alerts |
| #log-house            | `house`            | Housing actions |
| #log-jobs             | `qbjobs`           | Job changes |
| #log-default          | `default`          | Fallback for any unset key (recommended) |
| (test only)           | `testwebhook`      | Manual testing — leave blank |

➡️ **Minimum to set:** `default` (catches everything unset). Set the rest as desired.

---

## 2. `r14-evidence/server/nikon.lua` — camera / evidence photos  ⚠️ SECURITY

The `Webhooks` table maps image-space IDs (from `r14-evidence/config.lua` `Config.Camera`)
to Discord webhooks where in-game photos are uploaded.

> ⚠️ **ACTION REQUIRED:** this file currently contains **two live hardcoded webhooks from
> the original (leaked) server** — `[1]` "LSPD Discord" and `[2]` "Staff Logs". Until you
> replace them, your players' camera photos are being sent to a **stranger's Discord**.
> Overwrite both with your own webhook URLs (or blank them to disable).

| Channel name (suggested) | Key | Logs |
|---|---|---|
| #evidence-lspd   | `[1]` | LSPD / police camera uploads |
| #evidence-staff  | `[2]` | Staff camera uploads |
| (add per image space defined in `Config.Camera`) | `[n]` | Job-specific photo uploads |

---

## 3. Other resources with their own webhook slots

Each of these has a webhook field in the listed file — create a channel and paste a URL.

| Channel name (suggested) | Resource / file | Logs |
|---|---|---|
| #log-billing       | `[new]/randol_billing/sv_charge.lua`            | Invoices / billing charges |
| #log-reports       | `[custom]/karma-reportsystem/server/sv_main.lua`| Player report system (replace `PUT_YOU_WEBHOOK_HERE`) |
| #log-postal        | `[jobs]/[public]/dream-postal/server.lua`       | Postal/delivery job events |
| #log-weed          | `[new]/BakiTelli_weed/shared/config.lua`        | Weed plant/harvest activity |
| #log-hackermenu    | `[new]/BakiTelli_hackermenu/shared/config.lua`  | Hacker menu usage |

---

### Quick setup order
1. Create the channels you care about (start with the ⚠️ r14-evidence fix + `default`).
2. Make a webhook per channel, copy each URL.
3. Paste URLs into the config slots above.
4. Restart the affected resources (`ensure` / `restart <resource>`).
