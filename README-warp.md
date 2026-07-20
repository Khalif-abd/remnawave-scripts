# 🌐 WTM - WARP & Tor Manager v1.5.0 - Профессиональное управление анонимными сетями

**WTM** - это комплексный bash-скрипт для автоматизации установки и управления **Cloudflare WARP** и **Tor** на Linux серверах.

🆕 **Версия v1.5.0** — поддержка **WARP+** (платная подписка / license key): апгрейд существующей установки командой `wtm warp-plus <KEY>` или сразу при установке `wtm install-warp --license <KEY>`, без повторной регистрации.

**v1.4.2** — host-вариант подключения Xray (`freedom` + `sockopt.interface`) стал полноценным: готовый сниппет + cron-watchdog, который сам перезапускает интерфейс `warp` при потере handshake.

**v1.4.1** — безопасный дефолт `"noKernelTun": true` в генерируемом Xray-outbound: конфиг работает «из коробки» в Docker и других контейнерах.

**v1.4.0** — современная интеграция WARP в ядро **Xray** через нативный `wireguard` outbound, безопасное самообновление, исправление опасного апгрейда ОС и крупный рефакторинг.

### Релиз от проектов [GIG.ovh](https://gig.ovh) и [OpeNode.xyz](https://openode.xyz)

![изображение](https://github.com/user-attachments/assets/907d9304-cd7d-4897-8e24-ea8086924a0a)

## 📋 Возможности

### 🚀 Основные функции

- **Автоматическая установка** Cloudflare WARP через WireGuard
- **Автоматическая установка** Tor с усиленной конфигурацией
- **Нативная интеграция WARP в Xray** — генерация готового `wireguard` outbound (🆕 v1.4.0)
- **Поддержка WARP+** — апгрейд до платной подписки по license key, без повторной регистрации (🆕 v1.5.0)
- **Динамическая генерация пароля** Tor Control Port
- **Интерактивное меню** для удобного управления
- **Безопасная система автообновления** с проверкой целостности (🆕 v1.4.0)
- **Мониторинг состояния** сервисов в реальном времени
- **Тестирование соединений** для проверки работоспособности
- **Принудительная переустановка** флагом `--force` (теперь действительно работает — 🆕 v1.4.0)
- **Глобальная установка** в `/usr/local/bin/wtm` для системного доступа
- **Логирование действий** в `/var/log/wtm.log`
- **Полноценная CLI справка** `wtm --help`

## 💾 Изменения в v1.5.0

- **Поддержка WARP+ (платная подписка / license key).** WARP+ снимает лимит скорости бесплатного WARP. Cloudflare применяет апгрейд **к тому же зарегистрированному устройству** (device_id) на своей стороне — локальные ключи, endpoint и `reserved` не меняются, поэтому Xray-outbound'ы и профиль `warp.conf` **не нужно перегенерировать**, а **повторная регистрация не требуется**.
  - `wtm install-warp --license <KEY>` — установка сразу с WARP+ (ключ применяется к свежезарегистрированному устройству до генерации профиля). Также работает env-переменная `WARP_LICENSE_KEY`.
  - `wtm warp-plus <KEY>` — апгрейд уже установленного WARP на месте: вписывает ключ в `wgcf-account.toml`, выполняет `wgcf update` (с ретраями на временные ошибки Cloudflare) и переподнимает интерфейс. Команда идемпотентна. Доступно и в интерактивном меню WARP (пункт 9).
  - `wtm status` показывает тип аккаунта (`WARP+` / `Free`) для активного WARP — best-effort, через `wgcf status`.
  - Подробности, ручной способ и оговорки — в разделе [WARP+ (подписка / license key)](#-warp-подписка--license-key).

## 💾 Изменения в v1.4.2

- **Host-вариант для Xray — полноценный, а не «legacy»**: при установке WARP генерируется второй готовый сниппет `/etc/wireguard/warp-sockopt-outbound.json` (`freedom` + `sockopt.interface: "warp"` + `tcpFastOpen`). Он быстрее нативного (kernel WireGuard вместо userspace-стека) и не держит ключи в конфиге Xray, но требует, чтобы Xray видел хостовый интерфейс `warp`: Xray на голом хосте или контейнер с `network_mode: host`. В bridge-контейнере (дефолтный remnanode) — только нативный вариант.
- **Watchdog интерфейса `warp`** (ставится автоматически при `install-warp`): cron-задание раз в 5 минут проверяет юнит `wg-quick@warp`, возраст handshake (>180 с = протух) и связность через туннель (HTTPS-запрос `cdn-cgi/trace`, как в остальных проверках скрипта); при сбое перезапускает интерфейс с cooldown 120 с. Управление: `wtm watchdog-on` / `wtm watchdog-off`; лог: `/var/log/wtm-warp-watchdog.log` (сохраняется при `watchdog-off` для диагностики). Статус watchdog виден в меню; `wtm stop-warp` предупреждает, что watchdog поднимет сервис обратно.
- Меню «XRay Configuration» показывает **оба** варианта (A — нативный, B — host) с критерием выбора; при удалении WARP watchdog и оба сниппета вычищаются.
- **Автовычисление `reserved`** (PR #34): нативный outbound генерируется с account-specific значением из client_id вашей регистрации (некоторые PoP Cloudflare молча дропают handshake на общем `[0, 0, 0]`); при недоступном API — fallback на `[0, 0, 0]`. Команда `wtm regen-warp-xray` пересчитывает значение на существующей установке без переустановки.

## 💾 Изменения в v1.4.1

- **`"noKernelTun": true` по умолчанию** в генерируемом `/etc/wireguard/warp-xray-outbound.json` и во всех примерах. При дефолтном `false` Xray проверяет только `CAP_NET_ADMIN` и пытается создать kernel-TUN с записью `rp_filter` в `/proc/sys` — в контейнере с read-only `/proc/sys` (типичный Docker, включая remnanode) запись падает **фатально, без отката на userspace**, и весь outbound не стартует. Userspace-стек (gVisor) работает везде; на голом хосте с `CAP_NET_ADMIN` можно вручную поставить `false` ради производительности kernel-TUN.

## 💾 Изменения в v1.4.0

### 🎯 Интеграция с Xray (главное)
- **Нативный `wireguard` outbound** вместо устаревшего `freedom` + `sockopt.interface:"warp"`. Xray (с версии 1.6.5, актуально для текущей ветки v26.x) подключается к WARP **напрямую** — без kernel-интерфейса, `wg-quick` и `/etc/wireguard/warp.conf`. Это обходит конфликт kernel-WireGuard / `rp_filter`, из-за которого ноды падали в контейнерах.
- При установке WARP скрипт **сохраняет ключи и генерирует готовый Xray-сниппет** с вашими реальными значениями: `/etc/wireguard/warp-xray-outbound.json`. Раздел «XRay Configuration» в меню показывает именно ваш конфиг, а не плейсхолдеры.
- Учтены актуальные изменения схемы Xray: убран устаревший `"type": "field"`, поле `kernelMode` заменено на `noKernelTun` (для Docker / read-only хостов — `"noKernelTun": true`), добавлены оговорки про `geosite.dat`/`geoip.dat`.

### 🐛 Критические исправления
- **wgcf-регистрация починена**: `yes | wgcf register` больше не работает (современный wgcf прячет согласие с ToS за интерактивным TTY-промптом) → используется `wgcf register --accept-tos` с ретраями и выводом ошибок.
- **Опасный апгрейд ОС убран**: на RHEL/Rocky/Alma/Fedora `yum/dnf update -y` выполнял **полный апгрейд системы** (ядро, glibc…) при любой установке → заменено на `makecache` (только метаданные).
- **Безопасное самообновление**: `curl -sSL | install /dev/stdin` (молча писал битый файл при 404/обрыве и рапортовал «успех») заменено двухстадийной загрузкой с валидацией shebang+версии и проверкой реальной смены версии.
- **Флаг `--force`/`-f` теперь работает** — раньше парсился в неиспользуемую переменную, и `install-warp --force` молча делал обычную установку.

### 🔒 Безопасность и надёжность
- **Tor**: порты явно привязаны к `127.0.0.1`, добавлен `SocksPolicy accept 127.0.0.1 / reject *`, убран бесполезный `ConnLimit 1000`, надёжная генерация хэша control-пароля.
- **wgcf** скачивается во временную папку с проверкой целостности (не в текущий каталог).
- **systemctl**-операции рапортуют реальный результат (раньше любой сбой показывался зелёной галочкой).
- **EL8**: автоматически ставится `elrepo-release` + `kmod-wireguard` (модуля WireGuard нет in-tree на EL8; на EL9+ он встроен).
- Корректный strip IPv6, `cd` в подоболочке, очистка временных файлов.

### ♻️ Рефакторинг
- `set -eE` → `set -E` + диагностический ERR-trap: интерактивное меню больше не падает на «нормальных» ненулевых кодах возврата.
- Дедупликация блоков статуса (`render_warp_status_block` / `render_tor_status_block`), пакеты передаются массивами, `ss` приоритетнее `netstat`, редактор конфигов через `$EDITOR` (не хардкод `nano`).

## 💾 Система автообновления

**🔄 Умная система версионирования:**
- **Автоматическая проверка** новых версий при запуске интерактивного режима
- **Безопасное обновление** с двухстадийной загрузкой и проверкой целостности (🆕 v1.4.0)
- **Глобальная установка** в `/usr/local/bin/wtm` для системного доступа
- **Защита от битых обновлений** — версия на диске сверяется после установки

```bash
# Проверка текущей версии
wtm version                          # Полная информация о версии

# Проверка обновлений
wtm check-updates                    # Сравнение с GitHub

# Автоматическое обновление
sudo wtm self-update                 # Обновление до последней версии
sudo wtm update                      # Альтернативная команда
```

**Особенности системы обновлений:**
- **Единый URL обновлений** — совместимость с репозиторием remnawave-scripts
- **Проверка прав доступа** — требование root для обновления
- **Валидация загрузки** — проверка shebang, `# VERSION=` и фактической смены версии
- **Интерактивное меню обновлений** — пункт 9 в главном меню
- **Определение версии** через `# VERSION=` в заголовке скрипта

### ⚙️ Управление сервисами
- Запуск/остановка/перезапуск сервисов с реальной проверкой статуса
- Просмотр логов в реальном времени
- Отображение потребления памяти
- Проверка статуса портов и интерфейсов
- Удаление сервисов с очисткой конфигураций и ключей

### 📊 Мониторинг
- Статус WARP (WireGuard интерфейс)
- Статус Tor (SOCKS5 и Control порты)
- Системная информация (RAM, IP, архитектура)
- Тестирование подключений через каждый прокси
- Верификация через Cloudflare Trace API

### 🔧 Конфигурация
- Готовый нативный `wireguard` outbound для Xray (`/etc/wireguard/warp-xray-outbound.json`)
- Готовый host-outbound `freedom` + `sockopt` (`/etc/wireguard/warp-sockopt-outbound.json`, 🆕 v1.4.2)
- Watchdog интерфейса `warp` с автоперезапуском по handshake/ping (🆕 v1.4.2)
- Примеры роутинга .onion через Tor и стриминга/рекламы через WARP
- Примеры использования curl, ssh, git с прокси

## 📦 Быстрая установка и настройка

Всего одна команда для глобальной установки:

```bash
# Установка как глобальная команда
sudo bash <(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh) @ install-script

# Или прямой запуск
bash <(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh)
```

### 🎯 Умная автоматическая установка

WTM автоматически устанавливается как глобальная команда при любой операции установки:

```bash
# Любая из этих команд автоматически установит wtm глобально
sudo bash <(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh) install-warp
sudo bash <(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh) install-all
# После этого просто используйте: wtm command
```

**Преимущества автоматической установки:**

- 🚀 **Мгновенный доступ** - команда `wtm` доступна сразу после установки
- 🔄 **Нет дублирования** - умная система предотвращает повторные установки
- 💾 **Безопасность** - валидация загруженного скрипта перед установкой
- 📱 **Удобство** - работает как в интерактивном, так и в командном режиме

### Альтернативный способ

```bash
# Скачать и установить скрипт в одну команду
sudo wget https://raw.githubusercontent.com/DigneZzZ/remnawave-scripts/main/wtm.sh -O /usr/local/bin/wtm && sudo chmod +x /usr/local/bin/wtm

# Запустить интерактивное меню
sudo wtm
```

### Из репозитория

```bash
# Клонировать весь репозиторий
git clone https://github.com/DigneZzZ/remnawave-scripts.git
cd remnawave-scripts

# Установить скрипт глобально
sudo cp wtm.sh /usr/local/bin/wtm && sudo chmod +x /usr/local/bin/wtm

# Запустить скрипт
sudo wtm
```

### 🚀 Быстрый старт

После установки просто выполните:

```bash
# Открыть интерактивное меню
sudo wtm

# Или установить всё сразу
sudo wtm install-all
```

## 🚀 Быстрые команды

### Установка сервисов

```bash
# Установить только WARP
sudo wtm install-warp

# Установить WARP сразу с подпиской WARP+ (🆕 v1.5.0)
sudo wtm install-warp --license <LICENSE-KEY>

# Установить только Tor  
sudo wtm install-tor

# Установить оба сервиса (рекомендуется)
sudo wtm install-all
```

### 🔄 Принудительная установка (перезапись существующих)

```bash
# Принудительно переустановить WARP
sudo wtm install-warp-force
sudo wtm install-warp --force        # эквивалент (🆕 v1.4.0: флаг работает)

# Принудительно переустановить Tor
sudo wtm install-tor-force

# Принудительно переустановить оба
sudo wtm install-all-force
```

### ⚙️ Управление сервисами

```bash
# Проверить статус
sudo wtm status

# Запустить/остановить WARP
sudo wtm start-warp
sudo wtm stop-warp
sudo wtm restart-warp

# Watchdog интерфейса warp (🆕 v1.4.2)
sudo wtm watchdog-on
sudo wtm watchdog-off

# Запустить/остановить Tor
sudo wtm start-tor
sudo wtm stop-tor  
sudo wtm restart-tor
```

### 📊 Мониторинг и диагностика

```bash
# Тестировать все соединения
sudo wtm test

# Просмотр логов
sudo wtm logs-warp
sudo wtm logs-tor

# Системная информация
sudo wtm system-info
```

### 📖 Справка и документация

```bash
# Общая справка
sudo wtm help

# Примеры использования
sudo wtm usage-examples

# Примеры конфигурации XRay (включая ваш сгенерированный outbound)
sudo wtm xray-examples

# Проверка версии и обновлений
wtm version
wtm check-updates
sudo wtm self-update
```

## 🚀 WARP+ (подписка / license key)

По умолчанию скрипт регистрирует **бесплатный** аккаунт WARP (со скоростным лимитом). Если у вас есть **WARP+** (платная подписка Cloudflare), лимит скорости снимается.

> **Как это работает под капотом.** WARP+ — это атрибут вашего **зарегистрированного устройства** (`device_id`) на стороне Cloudflare, а не отдельный туннель. Апгрейд применяется через `wgcf update` к тому же устройству: локальные ключи, endpoint и `reserved` **не меняются**. Поэтому Xray-outbound'ы и `warp.conf` перегенерировать **не нужно**, а **регистрироваться заново не требуется** — апгрейдится уже существующий аккаунт.

### Где взять ключ

License key берётся из приложения **1.1.1.1 / WARP** (Cloudflare): раздел **Account → Key** (или на устройстве с WARP+/Warp Team). Формат — три группы по 8 символов через дефис, например `1a2b3c4d-5e6f7g8h-9i0j1k2l`.

### Автоматически (рекомендуется)

```bash
# Новая установка сразу с WARP+
sudo wtm install-warp --license 1a2b3c4d-5e6f7g8h-9i0j1k2l
# (равнозначно: WARP_LICENSE_KEY=... sudo -E wtm install-warp)

# Апгрейд уже установленного WARP на месте
sudo wtm warp-plus 1a2b3c4d-5e6f7g8h-9i0j1k2l

# Проверить тип аккаунта
sudo wtm status        # строка "Account: WARP+ / Free"
```

`wtm warp-plus` идемпотентна — её можно запускать повторно. То же действие доступно в интерактивном меню: **WARP Menu → 9) Upgrade to WARP+**.

### Вручную

Если хочется без команды скрипта — тот же результат делается напрямую через `wgcf`. **Заново регистрироваться не нужно**, апгрейдим существующее устройство:

```bash
# 1. Вписать ключ в существующий аккаунт (файл создаётся при install-warp)
sudo sed -i "s|^license_key.*|license_key = '1a2b3c4d-5e6f7g8h-9i0j1k2l'|" \
    /etc/wireguard/wgcf-account.toml

# 2. Применить ключ к устройству на стороне Cloudflare
sudo WGCF_ACCOUNT=/etc/wireguard/wgcf-account.toml wgcf update

# 3. Проверить, что аккаунт стал WARP+ (Account type: unlimited)
sudo WGCF_ACCOUNT=/etc/wireguard/wgcf-account.toml wgcf status

# 4. Переподнять туннель, чтобы новый handshake подхватил снятый лимит
sudo systemctl restart wg-quick@warp
```

`wgcf generate` вызывать **не обязательно**: ключи и адреса не меняются, профиль остаётся тем же.

### ⚠️ Важные оговорки

- **Лимит устройств.** Потребительский WARP+ ключ имеет лимит устройств (обычно 5). Каждый аккаунт (`device_id`), к которому применён ключ, занимает один слот. Повторное применение к **тому же** устройству слот не тратит — именно поэтому апгрейд на месте (без ре-регистрации) предпочтителен.
- **Не гарантия.** Cloudflare со временем ограничивает применение потребительских WARP+ ключей к устройствам `wgcf`. Если `wgcf status` после апгрейда всё ещё показывает `limited`/`free` — ключ мог не примениться (исчерпан лимит устройств или ключ больше не действителен для wgcf-девайсов). Скрипт в этом случае предупредит и продолжит на бесплатном аккаунте.
- Файл `/etc/wireguard/wgcf-account.toml` содержит `access_token` и `license_key` — храните его с правами `600` (скрипт выставляет их сам).

## 🎨 Интерактивное меню - Профессиональный интерфейс

### 🖥️ Главное меню

```
🌐 WARP & Tor Manager v1.4.2
──────────────────────────────────────────────────

🛠️  Service Management:
   1) 📡 WARP Menu
   2) 🧅 Tor Menu  
   3) 🔄 Quick Actions

📊 Monitoring & Tools:
   4) 🧪 Test Connections
   5) 📋 View Logs
   6) 💻 System Information

📖 Configuration:
   7) ⚙️  XRay Configuration
   8) ❓ Help & Usage Examples
   9) 🔄 Check Updates

   0) 🚪 Exit
```

### 🎯 Умные подсказки

Контекстные советы в зависимости от состояния системы:
- **Новая установка**: "Start with WARP Menu (1) or Tor Menu (2)"
- **Активные сервисы**: "Test connections (4) to verify everything works"
- **Частично настроенная**: "Use service menus to start installed components"

## 🔧 Системные требования

### Минимальные требования:
- **ОС**: Ubuntu 20.04+, Debian 11+, RHEL/Rocky/AlmaLinux 8+, Fedora 35+
- **Права**: root доступ (sudo)
- **RAM**: 1GB свободной памяти
- **Сеть**: доступ в интернет

### Поддерживаемые дистрибутивы:
- Ubuntu (20.04, 22.04, 24.04)
- Debian (11, 12)
- RHEL / Rocky Linux / AlmaLinux (8, 9) — на EL8 модуль WireGuard ставится из ELRepo автоматически
- Fedora (35+)

### Требуемые пакеты (устанавливаются автоматически):
- `wireguard-tools` - для WARP (+ `kmod-wireguard` на EL8)
- `tor` - Tor прокси  
- `curl`, `wget` - для загрузки компонентов
- `wgcf` - генерация конфигурации WARP (скачивается с GitHub во временную папку)

## 📡 Порты, сервисы и файлы

### WARP (WireGuard):
- **Интерфейс**: `warp`
- **Сервис**: `wg-quick@warp`
- **Конфиг wg-quick**: `/etc/wireguard/warp.conf`
- **Учётные данные wgcf**: `/etc/wireguard/wgcf-account.toml` (права 600)
- **Готовый Xray outbound (вариант A, нативный)**: `/etc/wireguard/warp-xray-outbound.json` (🆕 v1.4.0)
- **Готовый Xray outbound (вариант B, host)**: `/etc/wireguard/warp-sockopt-outbound.json` (🆕 v1.4.2)
- **Watchdog**: `/opt/wtm/warp-watchdog.sh`, cron `/etc/cron.d/wtm-warp-watchdog`, лог `/var/log/wtm-warp-watchdog.log` (🆕 v1.4.2)
- **Endpoint**: `engage.cloudflareclient.com:2408`

### Tor:
- **SOCKS5 порт**: `127.0.0.1:9050`
- **Control порт**: `127.0.0.1:9051`
- **Сервис**: `tor`
- **Конфиг**: `/etc/tor/torrc`
- **Логи**: `/var/log/tor/tor.log`
- **Пароль Control**: `/etc/tor/.control_password` (генерируется автоматически, если доступно хэширование)

## 🔍 Примеры использования

### Тестирование соединений:
```bash
# Прямое соединение
curl ifconfig.me

# Через WARP (host-интерфейс)
curl --interface warp ifconfig.me

# Через Tor
curl --socks5 127.0.0.1:9050 ifconfig.me
```

### ProxyChains конфигурация:
```bash
# /etc/proxychains.conf
socks5 127.0.0.1 9050
```

## 🎯 Интеграция с XRay

> Скрипт готовит **оба** варианта подключения Xray к WARP — выбирайте по тому, где живёт Xray:
> **A. Нативный `wireguard` outbound** — Xray подключается к WARP напрямую, без host-интерфейса. Работает везде, включая Docker/remnanode.
> **B. Host-интерфейс (`freedom` + `sockopt`)** — быстрее (kernel WireGuard), но Xray должен видеть интерфейс `warp`: голый хост или `network_mode: host`.

После `sudo wtm install-warp` готовый outbound с **вашими** ключами лежит в
`/etc/wireguard/warp-xray-outbound.json`. Команда `sudo wtm xray-examples`
покажет его содержимое.

### Вариант A: нативный WARP outbound (Docker/контейнеры)

```json
{
  "tag": "warp",
  "protocol": "wireguard",
  "settings": {
    "secretKey": "<wgcf PrivateKey>",
    "address": ["172.16.0.2/32", "2606:4700:110:...:c8e1/128"],
    "peers": [
      {
        "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
        "endpoint": "engage.cloudflareclient.com:2408",
        "allowedIPs": ["0.0.0.0/0", "::/0"]
      }
    ],
    "reserved": [0, 0, 0],
    "mtu": 1280,
    "noKernelTun": true
  }
}
```

- `"noKernelTun": true` (генерируется по умолчанию, 🆕 v1.4.1) — userspace-стек, работает в Docker/LXC и на read-only `/proc/sys`. На голом хосте с `CAP_NET_ADMIN` можно поставить `false` — kernel-TUN быстрее.
- `reserved` вычисляется автоматически из вашей WARP-регистрации (client_id через API Cloudflare). Если в файле осталось `[0, 0, 0]` (API был недоступен) — обновите командой `sudo wtm regen-warp-xray`.
- На `wireguard` outbound **нельзя** вешать `streamSettings`/`sockopt`; для цепочки используйте `dialerProxy` на другом outbound.

### Полный пример: WARP + Tor + роутинг

```json
{
  "outbounds": [
    { "tag": "direct", "protocol": "freedom" },
    {
      "tag": "warp",
      "protocol": "wireguard",
      "settings": {
        "secretKey": "<wgcf PrivateKey>",
        "address": ["172.16.0.2/32"],
        "peers": [
          {
            "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
            "endpoint": "engage.cloudflareclient.com:2408"
          }
        ],
        "reserved": [0, 0, 0],
        "noKernelTun": true
      }
    },
    {
      "tag": "tor",
      "protocol": "socks",
      "settings": {
        "servers": [{ "address": "127.0.0.1", "port": 9050 }]
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "inboundTag": ["VTR-USA", "VTR-NL", "to-foreign-inbound"],
        "outboundTag": "tor",
        "domain": ["regexp:.*\\.onion$"]
      },
      {
        "inboundTag": ["VTR-USA", "VTR-NL", "to-foreign-inbound"],
        "outboundTag": "warp",
        "domain": [
          "geosite:category-ads-all",
          "geosite:google",
          "geosite:cloudflare",
          "geosite:youtube",
          "geosite:netflix"
        ]
      },
      {
        "inboundTag": ["VTR-RU", "VTR-LOCAL", "local-inbound"],
        "outboundTag": "direct",
        "domain": ["geosite:private", "geosite:cn", "geosite:ru"]
      }
    ]
  }
}
```

### 🔀 Маршрутизация трафика

- **.onion домены** → Tor SOCKS5 (`127.0.0.1:9050`)
- **Реклама / стриминг с иностранных inbound'ов** → WARP (нативный `wireguard`)
- **Локальные inbound'ы + Private/RU/CN** → прямое подключение

> **Примечание:** `"type": "field"` в правилах роутинга в актуальном Xray больше **не нужен** (удалён/игнорируется). Теги `geosite:`/`geoip:` требуют наличия `geosite.dat`/`geoip.dat` в `/usr/local/share/xray/` (или задайте `XRAY_LOCATION_ASSET`).

### 🧩 Вариант B: host-интерфейс (`freedom` + `sockopt`) — 🆕 v1.4.2

Готовый сниппет лежит в `/etc/wireguard/warp-sockopt-outbound.json`:

```json
{
  "tag": "warp",
  "protocol": "freedom",
  "settings": { "domainStrategy": "UseIP" },
  "streamSettings": {
    "sockopt": { "interface": "warp", "tcpFastOpen": true }
  }
}
```

> Тег `"warp"` совпадает с вариантом A — все примеры роутинга выше работают без изменений. В один конфиг вставляйте только **один** из вариантов.

Xray привязывает исходящие сокеты к kernel-интерфейсу `wg-quick@warp` (его поднимает скрипт). Это **самый быстрый** вариант — kernel WireGuard вместо userspace-стека — и ключи WARP не попадают в конфиг Xray.

**Требование:** Xray должен видеть хостовый интерфейс `warp` — Xray на голом хосте или контейнер с `network_mode: host`. В bridge-контейнере (дефолтный remnanode) интерфейс не виден — используйте вариант A (нативный).

**Стабильность:** за интерфейсом следит watchdog (ставится автоматически): cron раз в 5 минут проверяет юнит, возраст handshake и связность через туннель (HTTPS `cdn-cgi/trace`), при сбое перезапускает `wg-quick@warp` (cooldown 120 с). Управление: `wtm watchdog-on` / `wtm watchdog-off`, лог: `/var/log/wtm-warp-watchdog.log`.

**Как выбрать:** Xray в Docker → вариант A; Xray на хосте → вариант B.

## 🛠️ Устранение неполадок

### Общие проблемы:

#### WARP не подключается:
```bash
# Проверить интерфейс
ip link show warp

# Проверить конфигурацию
cat /etc/wireguard/warp.conf

# Перезапустить сервис
sudo systemctl restart wg-quick@warp

# Логи сервиса
sudo journalctl -u wg-quick@warp -n 30 --no-pager
```

#### Регистрация WARP падает (Cloudflare 5xx):
```bash
# Cloudflare иногда отдаёт временные ошибки регистрации — скрипт делает
# до 3 попыток. Можно повторить установку чуть позже:
sudo wtm install-warp-force
```

#### Tor не работает:
```bash
# Проверить порты
ss -tlnp | grep ':9050\|:9051'

# Проверить логи
sudo journalctl -u tor -f

# Проверить конфигурацию
sudo tor --verify-config
```

#### Конфликт портов:
```bash
# Найти процесс, использующий порт (ss предпочтительнее netstat)
sudo ss -tlnp | grep ':9050'
sudo lsof -i :9050

# Остановить конфликтующий сервис
sudo systemctl stop service-name
```

### Диагностические команды:
```bash
# Статус всех сервисов
sudo wtm status

# Тест соединений
sudo wtm test

# Полная диагностика
sudo wtm system-info
```

## 📚 Дополнительные ресурсы

### Официальная документация:
- [Cloudflare WARP](https://developers.cloudflare.com/warp-client/)
- [WireGuard](https://www.wireguard.com/quickstart/)
- [Tor Project](https://www.torproject.org/docs/)
- [XRay — WireGuard outbound](https://xtls.github.io/config/outbounds/wireguard.html)
- [XRay — WARP guide](https://xtls.github.io/document/level-2/warp.html)
- [wgcf](https://github.com/ViRb3/wgcf)

## 🔗 Ресурсы и поддержка

- **GitHub Repository**: [https://github.com/DigneZzZ/remnawave-scripts](https://github.com/DigneZzZ/remnawave-scripts)
- **WTM Documentation**: Полная документация в README-warp.md
- **Issue Tracker**: Приветствуются баг-репорты и предложения
- **Project Website**: [https://gig.ovh](https://gig.ovh)

### 🎓 Обучающие материалы

- **XRay конфигурации** с нативным WARP outbound + Tor
- **Тестовые команды** для проверки анонимности

## 🎉 Заключение

✅ **Простота**: Установка в одну команду, интуитивное меню  
✅ **Надежность**: Безопасное самообновление, реальная проверка статуса сервисов  
✅ **Актуальность**: Нативная интеграция WARP в современный Xray (v26.x)  
✅ **Гибкость**: От домашнего использования до enterprise-решений  
✅ **Интеграция**: Часть экосистемы remnawave-scripts

---

**Версия**: v1.4.2  
**Последнее обновление**: 4 июля 2026  
**Автор**: DigneZzZ  
**Проект**: [https://gig.ovh](https://gig.ovh)
