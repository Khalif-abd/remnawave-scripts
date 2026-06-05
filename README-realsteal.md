# Realsteal — Real App Front for Reality

> 🎭 Форк на базе скелета [selfsteal](./README-selfsteal.md). Репозиторий: [Khalif-abd/remnawave-scripts](https://github.com/Khalif-abd/remnawave-scripts)

Скрипт для установки и управления **TLS-фронтом (nginx reverse-proxy)** в связке с **реальным Docker-приложением** в качестве витрины для маскировки трафика Reality. В отличие от `selfsteal` (статические HTML-шаблоны), `realsteal` поднимает **живое приложение** (Jitsi Meet и др.) — оно отвечает на активный пробинг как настоящий сервис. Порт 443 остаётся за Xray.

## Чем отличается от selfsteal

| | selfsteal | realsteal |
|--|-----------|-----------|
| Витрина | Статические AI-шаблоны (HTML) | Реальное приложение (Jitsi Meet, …) |
| Фронт | Caddy / Nginx | Nginx (socket/tcp) |
| Назначение | «сайт-обманка» | работающий сервис за тем же доменом |
| Скелет/дизайн/CLI | — | **тот же, что у selfsteal** |

## Архитектура

```
Интернет ──▶ :443 Xray (Reality) ──proxy_protocol(xver:1)──▶ /dev/shm/nginx.sock
                                                                    │
                                                          Nginx (realsteal front)
                                                                    │ reverse-proxy
                                                          127.0.0.1:8000 Jitsi Meet
```

Nginx **не слушает 443** — порт принадлежит Xray. Фронт принимает трафик от Xray через Unix socket (по умолчанию) или TCP-порт с `proxy_protocol`.

## Режимы фронта

- **standalone** — свой новый nginx-фронт в `/opt/realsteal/front` (+ собственный сертификат ACME).
- **adopt** — переиспользовать существующий фронт `selfsteal` (`/opt/nginx-selfsteal`): серт/сокет/контейнер остаются, конфиг перегенерируется на reverse-proxy к приложению.

> ⚠️ `realsteal` и `selfsteal` **взаимоисключающи** как активная витрина-фронт.

## Установка (надёжный способ)

**Если `curl | bash` молча ничего не делает** — curl не скачал скрипт (блокировка/ошибка), а bash запустил пустой stdin. Скачивайте в файл:

```bash
curl -fsSL https://raw.githubusercontent.com/Khalif-abd/remnawave-scripts/main/realsteal.sh -o /tmp/realsteal.sh
bash /tmp/realsteal.sh @ --force --domain reality.example.com install
```

> ❗ `sudo bash <(curl …)` не работает (`/dev/fd/63: No such file`) — используйте способ выше.

После установки скрипт копирует себя в `/usr/local/bin/realsteal`.

## Использование

```bash
realsteal              # интерактивное меню
realsteal help         # справка
```

### Команды

| Команда | Описание |
|---------|----------|
| `install` | Установить фронт + приложение-витрину |
| `up` / `down` | Запустить / остановить фронт + приложение |
| `restart` | Перезапустить сервисы |
| `status` | Статус и информация |
| `logs [front\|app]` | Логи фронта или приложения |
| `app list\|install\|uninstall\|switch <name>` | Управление приложениями |
| `auth <open\|b\|c>` | Режим авторизации Jitsi |
| `user add\|del\|list` | Пользователи Jitsi |
| `renew-ssl` | Обновить сертификат Let's Encrypt |
| `guide` | Памятка dest/serverNames для Reality |
| `doctor` | Диагностика curl / старых копий / состояния |
| `uninstall` | Удалить (+ восстановить adopt-фронт) |
| `update` | Проверить и установить обновление скрипта |

### Опции

| Опция | Описание |
|-------|----------|
| `--force`, `-f` | Неинтерактивная установка (нужен `--domain`) |
| `--domain <domain>` | Домен для установки |
| `--app <jitsi>` | Приложение-витрина (по умолчанию: jitsi) |
| `--auth <open\|b\|c>` | Режим авторизации Jitsi (в `--force` по умолчанию `b`) |
| `--adopt` | Переиспользовать фронт selfsteal |
| `--standalone` | Новый nginx-фронт (по умолчанию без selfsteal) |
| `--lang <en\|ru>` | Язык интерфейса (по умолчанию: ru) |
| `--source <url>` | Свой URL скрипта для self-install/обновления |
| `--debug` | Подробный вывод + ERR-trap (диагностика) |

## Приложения-витрины

| Приложение | Статус | Порты |
|-----------|--------|-------|
| ✅ **Jitsi Meet** | реализовано | `10000/udp` (медиа) + reverse-proxy на `127.0.0.1:8000` |
| 🔜 Nextcloud | в планах | — |

### Режимы авторизации Jitsi

- `open` — без авторизации, гости заходят свободно.
- `b` — нужен логин, гостям разрешено присоединяться.
- `c` — нужен логин, гости запрещены.

При `b`/`c` при установке создаётся пользователь, креды показываются **один раз**.

## Конфигурация Xray Reality

```json
{
  "dest": "/dev/shm/nginx.sock",
  "xver": 1,
  "serverNames": ["reality.example.com"]
}
```

| Параметр | Значение |
|----------|----------|
| `dest`/`target` | `/dev/shm/nginx.sock` (socket) или `127.0.0.1:9443` (tcp) |
| `xver` | всегда `1` |
| `serverNames` | домен, указанный при установке |

> ⚠️ При Xray в Docker (remnanode и т.п.) пробросьте `/dev/shm:/dev/shm`, иначе контейнер не увидит сокет.

## Диагностика

```bash
bash /tmp/realsteal.sh doctor          # curl-тест, старые копии, состояние
bash /tmp/realsteal.sh --debug install # подробный трейс + ERR-trap
```

| Симптом | Причина | Решение |
|--------|---------|---------|
| Пустой вывод | `curl \| bash` + curl fail | `curl -o /tmp/realsteal.sh && bash /tmp/...` |
| `/dev/fd/63: No such file` | `sudo bash <(curl…)` | Не использовать `<(curl)` с sudo |
| Битый jitsi compose | повреждённый YAML | `rm -rf /opt/realsteal/jitsi && realsteal app install jitsi` |

## Удаление

```bash
realsteal uninstall
```

В режиме `adopt` фронт selfsteal восстанавливается из бэкапа.

## Лицензия

MIT. Проект: [gig.ovh](https://gig.ovh).
