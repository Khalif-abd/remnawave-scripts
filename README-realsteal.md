# Realsteal — Real App Front for Reality

`realsteal.sh` manages a **TLS nginx reverse-proxy front** plus a **live Docker application** as a probe-resistant Reality fallback (instead of static templates from `selfsteal.sh`).

## Quick start (curl, без ручного скачивания)

Репозиторий: [Khalif-abd/remnawave-scripts](https://github.com/Khalif-abd/remnawave-scripts)

**Важно:** не используйте `sudo bash <(curl …)` — будет ошибка `/dev/fd/63: No such file or directory`.  
Process substitution (`<(…)`) не передаётся в `sudo`. Используйте **pipe**:

```bash
# Вы уже root — так:
curl -fsSL https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh | \
  bash -s -- @ --nginx --force --domain meet2.work-mesh.org install

# Или через sudo (curl без sudo, bash внутри sudo):
curl -fsSL https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh | \
  sudo bash -s -- @ --nginx --force --domain meet2.work-mesh.org install
```

Интерактивная установка:

```bash
curl -fsSL https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh | bash -s -- @ install
```

Adopt (если уже стоит selfsteal nginx):

```bash
curl -fsSL https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh | \
  bash -s -- @ --force --domain meet2.work-mesh.org --adopt install
```

Альтернатива — скачать файл и запустить (удобно при отладке):

```bash
curl -fsSL https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh -o /tmp/realsteal.sh
chmod +x /tmp/realsteal.sh
/tmp/realsteal.sh @ --force --domain meet2.work-mesh.org install
```

После `install` команда **`realsteal`** ставится в `/usr/local/bin/realsteal`:

```bash
realsteal              # меню
realsteal status
realsteal guide
realsteal --lang en menu
```

## Очистка старых копий

Если раньше клали скрипт в `/` или `/root`:

```bash
rm -f /realsteal.sh /root/realsteal.sh
# переустановка CLI из raw URL:
curl -fsSL https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh -o /usr/local/bin/realsteal
chmod +x /usr/local/bin/realsteal
```

Полный сброс realsteal (осторожно — удалит Jitsi и конфиг):

```bash
realsteal uninstall
rm -rf /opt/realsteal
rm -f /usr/local/bin/realsteal
```

## Relationship to selfsteal

| | selfsteal | realsteal |
|---|-----------|-----------|
| Content | Static HTML templates | Real app (Jitsi, …) |
| Front | nginx/Caddy static | nginx reverse-proxy |
| Coexistence | **Mutually exclusive** as active content front on one domain/node |

## Install flags

| Flag | Description |
|------|-------------|
| `--force` | Non-interactive install (needs `--domain`) |
| `--domain <name>` | Domain |
| `--app jitsi` | App plugin (default) |
| `--auth open\|b\|c` | Jitsi auth (default in `--force`: **b**) |
| `--adopt` / `--standalone` | Front mode |
| `--nginx` | Ignored (compatibility with selfsteal habit) |
| `--lang ru\|en` | UI language (**default: ru**) |

## Commands

```text
realsteal install | up | down | restart | status | logs
realsteal app list|install|uninstall|switch <name>
realsteal auth <open|b|c> | user add|del|list
realsteal renew-ssl | guide | render | uninstall
```

## Reality panel

```
dest:     /dev/shm/nginx.sock
xver:     1
serverNames: ["your.domain.com"]
```

## Troubleshooting

Jitsi YAML error:

```bash
sudo rm -rf /opt/realsteal/jitsi
realsteal install
```

Проверка, что curl отдаёт скрипт:

```bash
curl -fsSL https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh | head -3
# должно быть: #!/usr/bin/env bash
```
