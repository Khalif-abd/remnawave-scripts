# Realsteal — Real App Front for Reality

Репозиторий: [Khalif-abd/remnawave-scripts](https://github.com/Khalif-abd/remnawave-scripts)

## Установка (надёжный способ)

**Если `curl | bash` молча ничего не делает** — curl не скачал скрипт (блокировка/ошибка), а bash запустил пустой stdin.  
Используйте **скачивание в файл** (`&&`):

```bash
curl -fsSL https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh -o /tmp/realsteal.sh && \
  ls -la /tmp/realsteal.sh && \
  bash /tmp/realsteal.sh @ --nginx --force --domain meet2.work-mesh.org install
```

Должно появиться: `▶ Realsteal v1.0.5 (bash …)` — если нет, смотрите размер файла (`ls -la`).

### Диагностика

```bash
# скачать и проверить
curl -fsSL https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh -o /tmp/realsteal.sh
wc -c /tmp/realsteal.sh    # должно быть ~75000+ байт
head -3 /tmp/realsteal.sh  # #!/usr/bin/env bash

bash /tmp/realsteal.sh doctor
```

### Очистка старых копий

```bash
rm -f /realsteal.sh /root/realsteal.sh
rm -f /usr/local/bin/realsteal   # переустановится при install
rm -rf /opt/realsteal/jitsi      # только если Jitsi битый; полный сброс: rm -rf /opt/realsteal
```

### После install

```bash
realsteal menu
realsteal status
```

## Не работает

| Симптом | Причина | Решение |
|--------|---------|---------|
| Пустой вывод | `curl \| bash` + curl fail | `curl -o /tmp/realsteal.sh && bash /tmp/...` |
| `/dev/fd/63: No such file` | `sudo bash <(curl…)` | Не использовать `<(curl)` с sudo |
| YAML jitsi | битый compose | `rm -rf /opt/realsteal/jitsi && realsteal app install jitsi` |

## Флаги

`--force --domain`, `--adopt`, `--auth b|c|open`, `--nginx` (игнор), `--lang en`

## Reality

```
dest: /dev/shm/nginx.sock
xver: 1
serverNames: ["meet2.work-mesh.org"]
```
