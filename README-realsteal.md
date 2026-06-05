# Realsteal — Real App Front for Reality

`realsteal.sh` manages a **TLS nginx reverse-proxy front** plus a **live Docker application** as a probe-resistant Reality fallback (instead of static templates from `selfsteal.sh`).

## Quick start (curl, без ручного скачивания)

Репозиторий: [Khalif-abd/remnawave-scripts](https://github.com/Khalif-abd/remnawave-scripts)

```bash
# Интерактивная установка (меню на русском по умолчанию)
bash <(curl -Ls https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh) @ install

# Non-interactive: домен + jitsi + auth B + auto adopt если есть selfsteal
bash <(curl -Ls https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh) @ \
  --force --domain reality.example.com install

# Явно adopt (если уже стоит selfsteal nginx)
bash <(curl -Ls https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh) @ \
  --force --domain reality.example.com --adopt install

# Флаг --nginx — алиас для привычки от selfsteal (игнорируется, realsteal всегда nginx)
bash <(curl -Ls https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh) @ \
  --nginx --force --domain reality.example.com install
```

После `install` команда **`realsteal`** ставится в `/usr/local/bin/realsteal`:

```bash
realsteal              # меню
realsteal status
realsteal guide
realsteal --lang en menu   # английский UI
```

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

## Install flags

| Flag | Description |
|------|-------------|
| `--force` | Non-interactive install (needs `--domain`) |
| `--domain <name>` | Domain |
| `--app jitsi` | App plugin (default) |
| `--auth open\|b\|c` | Jitsi auth (default in `--force`: **b**) |
| `--adopt` / `--standalone` | Front mode |
| `--nginx` | Ignored (compatibility) |
| `--lang ru\|en` | UI language (**default: ru**) |
| `--source <url>` | Custom raw URL for `realsteal.sh` when installing to `/usr/local/bin` |

## Commands

```text
realsteal install
realsteal app list|install|uninstall|switch <name>
realsteal up|down|restart|status|logs [app]
realsteal auth <open|b|c>
realsteal user add|del|list
realsteal renew-ssl | guide | render | uninstall
```

## State

- `/opt/realsteal/realsteal.env` — domain, front mode, active app, auth, language
- `/opt/realsteal/jitsi` — Jitsi Meet
- Front dir: `/opt/realsteal/front` (standalone) or `/opt/nginx-selfsteal` (adopt)

## Reality panel (after install)

```
dest:     /dev/shm/nginx.sock   (socket mode) or 127.0.0.1:9443 (tcp)
xver:     1
serverNames: ["your.domain.com"]
```

## Troubleshooting

If Jitsi install failed with a YAML error:

```bash
sudo rm -rf /opt/realsteal/jitsi
sudo realsteal install
```

v1.0.2+ uses `docker-compose.override.yml` with `!reset` instead of patching upstream yaml.

## Apps

| App | Status | Notes |
|-----|--------|-------|
| jitsi | ✅ | Video conferencing, UDP 10000 |
| nextcloud | 🔜 | Contract stub only |

## i18n

**Russian** by default; English via `--lang en` or `LANG=en_US`.
