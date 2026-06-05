# Realsteal — Real App Front for Reality

`realsteal.sh` manages a **TLS nginx reverse-proxy front** plus a **live Docker application** as a probe-resistant Reality fallback (instead of static templates from `selfsteal.sh`).

## Relationship to selfsteal

| | selfsteal | realsteal |
|---|-----------|-----------|
| Content | Static HTML templates | Real app (Jitsi, …) |
| Front | nginx/Caddy static | nginx reverse-proxy |
| Coexistence | **Mutually exclusive** as active content front on one domain/node |

- `selfsteal.sh` is **not modified**.
- Only **one** Reality `dest` per node — choose either selfsteal **or** realsteal as the active front.

## Front modes

1. **standalone** — new nginx at `/opt/realsteal/front`, ACME certificate (TLS-ALPN via acme.sh), Unix socket `/dev/shm/nginx.sock` (default) or TCP.
2. **adopt** — reuse existing selfsteal nginx at `/opt/nginx-selfsteal` (cert, socket, container). Config switches to reverse-proxy; `selfsteal template` would overwrite it — use `realsteal render` to regenerate.

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/dignezzz/remnawave-scripts/main/realsteal.sh -o realsteal.sh
chmod +x realsteal.sh
sudo ./realsteal.sh install
# or interactive menu:
sudo ./realsteal.sh
```

## Commands

```text
realsteal install              # interactive: domain, front mode, app, auth
realsteal app list|install|uninstall|switch <name>
realsteal up|down|restart|status|logs [app]
realsteal auth <open|b|c>      # Jitsi auth modes
realsteal user add|del|list    # Jitsi users
realsteal renew-ssl
realsteal guide                # Reality dest / serverNames reminder
realsteal render               # idempotent front config regen
realsteal uninstall
realsteal --lang ru|en
```

## State

- `/opt/realsteal/realsteal.env` — domain, front mode, active app, auth, language
- `/opt/realsteal/jitsi` — Jitsi Meet (stage 1)
- Front dir: `/opt/realsteal/front` (standalone) or `/opt/nginx-selfsteal` (adopt)

## Reality panel (after install)

```
dest:     /dev/shm/nginx.sock   (socket mode) or 127.0.0.1:9443 (tcp)
xver:     1
serverNames: ["your.domain.com"]
```

## Apps (plugin contract)

| App | Status | Notes |
|-----|--------|-------|
| jitsi | ✅ | Video conferencing, UDP 10000 |
| nextcloud | 🔜 | Contract stub only |

## i18n

UI strings: **English** and **Russian** (`--lang ru` or `$LANG`).
