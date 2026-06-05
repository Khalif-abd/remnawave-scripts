#!/usr/bin/env bash
# ╔════════════════════════════════════════════════════════════════╗
# ║  Realsteal - Real App Front-end for Reality Traffic Masking     ║
# ║  TLS front (nginx reverse-proxy) + live Docker applications     ║
# ║                                                                ║
# ║  Project: gig.ovh                                              ║
# ║  License: MIT                                                  ║
# ╚════════════════════════════════════════════════════════════════╝
# VERSION=1.0.0

SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Handle @ prefix for consistency with other scripts
if [ $# -gt 0 ] && [ "$1" = "@" ]; then
    shift
fi

set -euo pipefail

# ── Globals ──────────────────────────────────────────────────────
APP_NAME="realsteal"
REALSTEAL_DIR="/opt/realsteal"
STATE_FILE="$REALSTEAL_DIR/realsteal.env"
LOG_FILE="/var/log/realsteal.log"
SCRIPT_URL="https://raw.githubusercontent.com/dignezzz/remnawave-scripts/main/realsteal.sh"

STANDALONE_FRONT_DIR="$REALSTEAL_DIR/front"
SELFSTEAL_DIR="/opt/nginx-selfsteal"
CADDY_SELFSTEAL_DIR="/opt/caddy"

CONTAINER_NAME_STANDALONE="nginx-realsteal"
CONTAINER_NAME_ADOPT="nginx-selfsteal"
NGINX_VERSION="1.29.3-alpine"
SOCKET_PATH="/dev/shm/nginx.sock"
DEFAULT_TCP_PORT="9443"

DEBUG_MODE=false
FORCE_MODE=false
COMMAND=""
ARGS=()
LANGUAGE="en"

# ACME
[ -z "${HOME:-}" ] && HOME=$(getent passwd "$(id -u)" | cut -d: -f6)
[ "$(id -u)" = "0" ] && HOME="/root"
ACME_HOME="$HOME/.acme.sh"
ACME_PORT=""
ACME_FALLBACK_PORTS=(8443 9443 10443 18443 28443)

# Runtime state (loaded from STATE_FILE)
DOMAIN=""
FRONT_MODE=""
FRONT_TYPE=""
FRONT_DIR=""
FRONT_PORT=""
SSL_DIR=""
ACTIVE_APP=""
AUTH_MODE=""
ADOPTED_FROM=""
SERVER_IP=""
CONTAINER_NAME=""

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;37m'
readonly NC='\033[0m'

DOCKER_HUB_MIRRORS=("mirror.gcr.io" "dockerhub.timeweb.cloud" "huecker.io" "cr.yandex/mirror")

# App registry: name:implemented (1=yes 0=stub)
declare -A APP_IMPL=(
    [jitsi]=1
    [nextcloud]=0
)

# ── i18n ─────────────────────────────────────────────────────────
declare -A T_EN T_RU

init_i18n() {
    T_EN=(
        [err_root]="This script must be run as root (use sudo)"
        [err_unknown_cmd]="Unknown command: %s"
        [err_not_installed]="Realsteal is not installed. Run: realsteal install"
        [err_no_active_app]="No active application configured"
        [err_app_not_found]="Application not found: %s"
        [err_app_not_impl]="Application '%s' is not implemented yet (coming soon)"
        [err_domain_invalid]="Invalid domain format"
        [err_dns_fail]="Domain does not resolve to this server (%s)"
        [err_port_busy]="Port %s is already in use"
        [err_nginx_test]="Nginx configuration test failed"
        [err_docker]="Docker Compose v2 is required (docker compose)"
        [info_installing]="Installing Realsteal..."
        [info_adopt_warn]="Adopting existing selfsteal front. Content management moves to realsteal."
        [info_adopt_template]="Warning: running 'selfsteal template' will overwrite the front config. Use 'realsteal' to regenerate."
        [info_selfsteal_conflict]="Active selfsteal front detected. realsteal and selfsteal are mutually exclusive as content front."
        [ok_installed]="Realsteal installed successfully"
        [ok_uninstalled]="Realsteal uninstalled successfully"
        [ok_front_rendered]="Front configuration rendered and reloaded"
        [ok_app_installed]="Application '%s' installed"
        [ok_app_switched]="Switched active application to '%s'"
        [prompt_domain]="Enter domain name"
        [prompt_front_mode]="Select front mode"
        [prompt_front_standalone]="1) Standalone — new nginx front + certificate"
        [prompt_front_adopt]="2) Adopt — reuse existing selfsteal nginx (/opt/nginx-selfsteal)"
        [prompt_app]="Select application"
        [prompt_auth]="Select authentication mode"
        [prompt_auth_open]="1) Open — no authentication"
        [prompt_auth_b]="2) Secure (B) — login required, guests can join"
        [prompt_auth_c]="3) Secure (C) — login required, no guests"
        [prompt_confirm]="Are you sure? [y/N]"
        [prompt_continue]="Continue anyway? [y/N]"
        [status_running]="Running"
        [status_stopped]="Stopped"
        [status_not_installed]="Not installed"
        [label_domain]="Domain"
        [label_front_mode]="Front mode"
        [label_active_app]="Active app"
        [label_auth]="Auth mode"
        [label_upstream]="Upstream"
        [menu_title]="Realsteal — Real App Front for Reality"
        [menu_install]="Install"
        [menu_up]="Start services"
        [menu_down]="Stop services"
        [menu_restart]="Restart services"
        [menu_status]="Status"
        [menu_logs]="View logs"
        [menu_app]="Manage applications"
        [menu_auth]="Change auth mode"
        [menu_users]="Manage users"
        [menu_renew_ssl]="Renew SSL certificate"
        [menu_guide]="Setup guide (Reality dest/serverNames)"
        [menu_uninstall]="Uninstall"
        [menu_exit]="Exit"
        [guide_title]="Realsteal Setup Guide"
        [guide_reality_hint]="Configure in Remnawave panel — dest / serverNames"
        [firewall_warn]="Firewall may be blocking %s"
        [firewall_open_hint]="To open: %s"
        [jitsi_creds]="Jitsi user created — save these credentials (shown once):"
        [uninstall_adopt_restore]="Adopted front restored to selfsteal static config backup"
        [uninstall_adopt_manual]="Adopted front: restore selfsteal manually with 'selfsteal template' if needed"
    )
    T_RU=(
        [err_root]="Скрипт нужно запускать от root (sudo)"
        [err_unknown_cmd]="Неизвестная команда: %s"
        [err_not_installed]="Realsteal не установлен. Запустите: realsteal install"
        [err_no_active_app]="Активное приложение не настроено"
        [err_app_not_found]="Приложение не найдено: %s"
        [err_app_not_impl]="Приложение '%s' ещё не реализовано (скоро)"
        [err_domain_invalid]="Неверный формат домена"
        [err_dns_fail]="Домен не указывает на этот сервер (%s)"
        [err_port_busy]="Порт %s уже занят"
        [err_nginx_test]="Проверка конфигурации nginx не прошла"
        [err_docker]="Нужен Docker Compose v2 (docker compose)"
        [info_installing]="Установка Realsteal..."
        [info_adopt_warn]="Перенимаем фронт selfsteal. Управление контентом переходит к realsteal."
        [info_adopt_template]="Внимание: 'selfsteal template' перезапишет конфиг фронта. Используйте 'realsteal' для перегенерации."
        [info_selfsteal_conflict]="Обнаружен активный фронт selfsteal. realsteal и selfsteal взаимоисключающи как витрина."
        [ok_installed]="Realsteal успешно установлен"
        [ok_uninstalled]="Realsteal удалён"
        [ok_front_rendered]="Конфиг фронта сгенерирован и перезагружен"
        [ok_app_installed]="Приложение '%s' установлено"
        [ok_app_switched]="Активное приложение переключено на '%s'"
        [prompt_domain]="Введите домен"
        [prompt_front_mode]="Выберите режим фронта"
        [prompt_front_standalone]="1) Standalone — новый nginx + сертификат"
        [prompt_front_adopt]="2) Adopt — перенять selfsteal nginx (/opt/nginx-selfsteal)"
        [prompt_app]="Выберите приложение"
        [prompt_auth]="Выберите режим авторизации"
        [prompt_auth_open]="1) Open — без авторизации"
        [prompt_auth_b]="2) Secure (B) — вход обязателен, гости могут подключаться"
        [prompt_auth_c]="3) Secure (C) — вход обязателен, без гостей"
        [prompt_confirm]="Вы уверены? [y/N]"
        [prompt_continue]="Продолжить всё равно? [y/N]"
        [status_running]="Работает"
        [status_stopped]="Остановлен"
        [status_not_installed]="Не установлен"
        [label_domain]="Домен"
        [label_front_mode]="Режим фронта"
        [label_active_app]="Активное приложение"
        [label_auth]="Режим auth"
        [label_upstream]="Upstream"
        [menu_title]="Realsteal — реальный фронт для Reality"
        [menu_install]="Установка"
        [menu_up]="Запустить сервисы"
        [menu_down]="Остановить сервисы"
        [menu_restart]="Перезапустить"
        [menu_status]="Статус"
        [menu_logs]="Логи"
        [menu_app]="Управление приложениями"
        [menu_auth]="Сменить режим auth"
        [menu_users]="Управление пользователями"
        [menu_renew_ssl]="Обновить SSL-сертификат"
        [menu_guide]="Памятка Reality (dest/serverNames)"
        [menu_uninstall]="Удалить"
        [menu_exit]="Выход"
        [guide_title]="Памятка по настройке Realsteal"
        [guide_reality_hint]="Настройте в панели Remnawave — dest / serverNames"
        [firewall_warn]="Firewall может блокировать %s"
        [firewall_open_hint]="Открыть: %s"
        [jitsi_creds]="Создан пользователь Jitsi — сохраните (показывается один раз):"
        [uninstall_adopt_restore]="Фронт selfsteal восстановлен из бэкапа статики"
        [uninstall_adopt_manual]="Adopt: при необходимости восстановите selfsteal через 'selfsteal template'"
    )
}

t() {
    local key="$1"
    shift
    local msg
    if [ "$LANGUAGE" = "ru" ]; then
        msg="${T_RU[$key]:-${T_EN[$key]:-$key}}"
    else
        msg="${T_EN[$key]:-$key}"
    fi
    # shellcheck disable=SC2059
    printf "$msg" "$@"
}

detect_language() {
    if [ -f "$STATE_FILE" ]; then
        local saved
        saved=$(grep "^LANGUAGE=" "$STATE_FILE" 2>/dev/null | cut -d= -f2- || true)
        [ -n "$saved" ] && LANGUAGE="$saved" && return
    fi
    case "${LANG:-en}" in
        ru*|RU*) LANGUAGE="ru" ;;
        *) LANGUAGE="en" ;;
    esac
}

# ── Logging ──────────────────────────────────────────────────────
log_info() {
    echo -e "${WHITE}ℹ️  $*${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    echo -e "${RED}❌ $*${NC}" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$LOG_FILE" 2>/dev/null || true
}

create_dir_safe() {
    local dir="$1"
    [ -d "$dir" ] || mkdir -p "$dir"
}

check_running_as_root() {
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        log_error "$(t err_root)"
        exit 1
    fi
}

# ── State management ───────────────────────────────────────────
state_init_file() {
    create_dir_safe "$REALSTEAL_DIR"
    [ -f "$STATE_FILE" ] || touch "$STATE_FILE"
}

state_get() {
    local key="$1"
    local default="${2:-}"
    if [ -f "$STATE_FILE" ]; then
        local val
        val=$(grep "^${key}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2- || true)
        if [ -n "$val" ]; then
            echo "$val"
            return
        fi
    fi
    echo "$default"
}

state_set() {
    local key="$1"
    local value="$2"
    state_init_file
    if grep -q "^${key}=" "$STATE_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$STATE_FILE"
    else
        echo "${key}=${value}" >> "$STATE_FILE"
    fi
}

state_load() {
    DOMAIN=$(state_get DOMAIN "")
    FRONT_MODE=$(state_get FRONT_MODE "")
    FRONT_TYPE=$(state_get FRONT_TYPE "socket")
    FRONT_DIR=$(state_get FRONT_DIR "")
    FRONT_PORT=$(state_get FRONT_PORT "$DEFAULT_TCP_PORT")
    SSL_DIR=$(state_get SSL_DIR "")
    ACTIVE_APP=$(state_get ACTIVE_APP "")
    AUTH_MODE=$(state_get AUTH_MODE "b")
    ADOPTED_FROM=$(state_get ADOPTED_FROM "")
    SERVER_IP=$(state_get SERVER_IP "")
    CONTAINER_NAME=$(state_get CONTAINER_NAME "")
    LANGUAGE=$(state_get LANGUAGE "$LANGUAGE")
    [ -z "$FRONT_DIR" ] && [ "$FRONT_MODE" = "standalone" ] && FRONT_DIR="$STANDALONE_FRONT_DIR"
    [ -z "$FRONT_DIR" ] && [ "$FRONT_MODE" = "adopt" ] && FRONT_DIR="$SELFSTEAL_DIR"
    [ -z "$SSL_DIR" ] && [ -n "$FRONT_DIR" ] && SSL_DIR="${FRONT_DIR}/ssl"
    [ -z "$CONTAINER_NAME" ] && {
        if [ "$FRONT_MODE" = "adopt" ]; then
            CONTAINER_NAME="$CONTAINER_NAME_ADOPT"
        else
            CONTAINER_NAME="$CONTAINER_NAME_STANDALONE"
        fi
    }
}

state_save_all() {
    state_set DOMAIN "$DOMAIN"
    state_set FRONT_MODE "$FRONT_MODE"
    state_set FRONT_TYPE "$FRONT_TYPE"
    state_set FRONT_DIR "$FRONT_DIR"
    state_set FRONT_PORT "$FRONT_PORT"
    state_set SSL_DIR "$SSL_DIR"
    state_set ACTIVE_APP "$ACTIVE_APP"
    state_set AUTH_MODE "$AUTH_MODE"
    state_set ADOPTED_FROM "$ADOPTED_FROM"
    state_set SERVER_IP "$SERVER_IP"
    state_set CONTAINER_NAME "$CONTAINER_NAME"
    state_set LANGUAGE "$LANGUAGE"
}

# Robust .env setter (handles commented lines)
env_set() {
    local file="$1" key="$2" value="$3"
    if [ ! -f "$file" ]; then
        echo "${key}=${value}" >> "$file"
        return
    fi
    if grep -qE "^#?${key}=" "$file" 2>/dev/null; then
        sed -i "s|^#\\?${key}=.*|${key}=${value}|" "$file"
    else
        echo "${key}=${value}" >> "$file"
    fi
}

env_get() {
    local file="$1" key="$2" default="${3:-}"
    if [ -f "$file" ]; then
        local val
        val=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -1 | cut -d= -f2- || true)
        [ -n "$val" ] && echo "$val" && return
    fi
    echo "$default"
}

# ── Network / system helpers ───────────────────────────────────
get_server_ip() {
    local ip
    ip=$(curl -s -4 --connect-timeout 5 ifconfig.io 2>/dev/null) || \
    ip=$(curl -s -4 --connect-timeout 5 icanhazip.com 2>/dev/null) || \
    ip=$(curl -s -4 --connect-timeout 5 api.ipify.org 2>/dev/null) || \
    ip=$(curl -s -4 --connect-timeout 5 ipecho.net/plain 2>/dev/null) || \
    ip="127.0.0.1"
    echo "${ip:-127.0.0.1}"
}

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "$(t err_docker)"
        return 1
    fi
    if ! docker compose version >/dev/null 2>&1; then
        log_error "$(t err_docker)"
        return 1
    fi
    return 0
}

install_docker() {
    log_info "Installing Docker..."
    local install_log
    install_log=$(mktemp)
    if curl -fsSL https://get.docker.com 2>/dev/null | sh >"$install_log" 2>&1; then
        rm -f "$install_log"
        systemctl start docker 2>/dev/null || true
        systemctl enable docker 2>/dev/null || true
        log_success "Docker installed"
        return 0
    fi
    log_error "Failed to install Docker"
    tail -10 "$install_log" 2>/dev/null
    rm -f "$install_log"
    return 1
}

ensure_image() {
    local ref="$1"
    local repo="${ref%%:*}"
    local tag="${ref##*:}"
    if docker image inspect "$ref" >/dev/null 2>&1; then
        return 0
    fi
    log_info "Pulling image $ref..."
    if docker pull "$ref" >/dev/null 2>&1; then
        return 0
    fi
    for mirror in "${DOCKER_HUB_MIRRORS[@]}"; do
        local mirror_ref="${mirror}/${repo}:${tag}"
        if docker pull "$mirror_ref" >/dev/null 2>&1; then
            docker tag "$mirror_ref" "$ref" 2>/dev/null || true
            return 0
        fi
    done
    return 1
}

port_in_use() {
    local spec="$1"
    if [[ "$spec" == *"/udp" ]]; then
        local p="${spec%/udp}"
        ss -ulnp 2>/dev/null | grep -q ":${p} "
    elif [[ "$spec" == *"/tcp" ]]; then
        local p="${spec%/tcp}"
        ss -tlnp 2>/dev/null | grep -q ":${p} "
    else
        ss -tlnp 2>/dev/null | grep -q ":${spec} " || \
        ss -ulnp 2>/dev/null | grep -q ":${spec} "
    fi
}

check_firewall_port() {
    local port_spec="$1"
    local port="${port_spec%%/*}"
    local proto="${port_spec#*/}"
    [ "$proto" = "$port" ] && proto="tcp"
    local blocked=false

    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        if ! ufw status | grep -qE "^${port}(/${proto})?\s+ALLOW"; then
            blocked=true
            log_warning "$(t firewall_warn "$port_spec")"
            log_info "$(t firewall_open_hint "ufw allow ${port}/${proto}")"
        fi
    fi
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
        if ! firewall-cmd --list-ports 2>/dev/null | grep -qE "${port}/${proto}"; then
            blocked=true
            log_warning "$(t firewall_warn "$port_spec")"
            log_info "$(t firewall_open_hint "firewall-cmd --add-port=${port}/${proto} --permanent && firewall-cmd --reload")"
        fi
    fi
    $blocked && return 1
    return 0
}

open_firewall_port() {
    local port_spec="$1"
    local port="${port_spec%%/*}"
    local proto="${port_spec#*/}"
    [ "$proto" = "$port" ] && proto="tcp"
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw allow "${port}/${proto}" >/dev/null 2>&1 || true
    fi
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
        firewall-cmd --add-port="${port}/${proto}" --permanent >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
    fi
}

preflight_install_checks() {
    local app="$1"
    SERVER_IP="${SERVER_IP:-$(get_server_ip)}"

    if [ -f "$STATE_FILE" ] && [ -n "$(state_get DOMAIN "")" ]; then
        log_warning "Realsteal already configured for $(state_get DOMAIN "")"
        read -r -p "Reinstall / reconfigure? [y/N]: " re
        [[ "$re" =~ ^[Yy]$ ]] || return 1
    fi

    validate_domain_dns "$DOMAIN" "$SERVER_IP" "$FORCE_MODE" || return 1

    if port_in_use "${JITSI_HTTP_PORT}" && [ "$app" = "jitsi" ]; then
        if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qi jitsi; then
            log_error "$(t err_port_busy "${JITSI_HTTP_PORT}")"
            return 1
        fi
    fi

    local fw
    fw=$(app_dispatch firewall_ports "$app" 2>/dev/null || true)
    while IFS= read -r fp; do
        [ -n "$fp" ] || continue
        if port_in_use "$fp"; then
            if ! docker ps 2>/dev/null | grep -qi jitsi; then
                log_warning "$(t err_port_busy "$fp") (may be ok if app already running)"
            fi
        fi
        check_firewall_port "$fp" || true
    done <<< "$fw"

    return 0
}

validate_domain_dns() {
    local domain="$1"
    local server_ip="$2"
    local force="${3:-false}"

    if ! [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "$(t err_domain_invalid)"
        return 1
    fi

    if ! command -v dig >/dev/null 2>&1; then
        command -v apt-get >/dev/null 2>&1 && apt-get install -y -qq dnsutils >/dev/null 2>&1 || true
        command -v yum >/dev/null 2>&1 && yum install -y -q bind-utils >/dev/null 2>&1 || true
    fi

    local dns_match=false
    local a_records
    a_records=$(dig +short A "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)
    while IFS= read -r ip; do
        [ -z "$ip" ] && continue
        [ "$ip" = "$server_ip" ] && dns_match=true
    done <<< "$a_records"

    if [ "$dns_match" = true ]; then
        return 0
    fi

    log_error "$(t err_dns_fail "$server_ip")"
    [ -n "$a_records" ] && echo -e "${GRAY}   DNS A: $(echo "$a_records" | tr '\n' ' ')${NC}"
    if [ "$force" = true ]; then
        return 0
    fi
    read -r -p "$(t prompt_continue) " cont
    [[ "$cont" =~ ^[Yy]$ ]]
}

detect_selfsteal_nginx() {
    [ -d "$SELFSTEAL_DIR" ] && [ -f "$SELFSTEAL_DIR/docker-compose.yml" ]
}

detect_realsteal_conflict() {
    if [ -f "$STATE_FILE" ] && [ -n "$(state_get ACTIVE_APP "")" ]; then
        return 0
    fi
    if detect_selfsteal_nginx; then
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME_ADOPT}$"; then
            if [ ! -f "$STATE_FILE" ] || [ -z "$(state_get FRONT_MODE "")" ]; then
                return 0
            fi
        fi
    fi
    return 1
}

require_installed() {
    state_load
    if [ ! -f "$STATE_FILE" ] || [ -z "$DOMAIN" ]; then
        log_error "$(t err_not_installed)"
        exit 1
    fi
}

# ── ACME (adapted from selfsteal) ────────────────────────────────
check_acme_installed() {
    [ -f "$ACME_HOME/acme.sh" ]
}

install_acme() {
    if check_acme_installed; then
        "$ACME_HOME/acme.sh" --set-default-ca --server letsencrypt >/dev/null 2>&1 || true
        return 0
    fi
    local random_email="user$(shuf -i 10000-99999 -n 1)@$(hostname -f 2>/dev/null || echo localhost.local)"
    local temp_script="/tmp/acme_install_$$.sh"
    if curl -sS --connect-timeout 30 --max-time 60 https://get.acme.sh -o "$temp_script" 2>/dev/null && [ -s "$temp_script" ]; then
        sh "$temp_script" email="$random_email" >/dev/null 2>&1 || true
    fi
    rm -f "$temp_script"
    for acme_path in "$ACME_HOME/acme.sh" "$HOME/.acme.sh/acme.sh" "/root/.acme.sh/acme.sh"; do
        if [ -f "$acme_path" ]; then
            ACME_HOME=$(dirname "$acme_path")
            "$ACME_HOME/acme.sh" --set-default-ca --server letsencrypt >/dev/null 2>&1 || true
            return 0
        fi
    done
    return 1
}

find_available_acme_port() {
    [ -n "$ACME_PORT" ] && echo "$ACME_PORT" && return 0
    for port in "${ACME_FALLBACK_PORTS[@]}"; do
        if ! ss -tlnp 2>/dev/null | grep -q ":$port "; then
            echo "$port"
            return 0
        fi
    done
    echo ""
}

setup_acme_port_redirect() {
    local target_port="$1"
    [ "$target_port" != "443" ] || return 0
    iptables -t nat -I PREROUTING 1 -p tcp --dport 443 -j REDIRECT --to-port "$target_port" 2>/dev/null || true
    iptables -t nat -I OUTPUT 1 -p tcp --dport 443 -o lo -j REDIRECT --to-port "$target_port" 2>/dev/null || true
}

cleanup_acme_port_redirect() {
    local target_port="$1"
    [ "$target_port" != "443" ] || return 0
    iptables -t nat -D PREROUTING -p tcp --dport 443 -j REDIRECT --to-port "$target_port" 2>/dev/null || true
    iptables -t nat -D OUTPUT -p tcp --dport 443 -o lo -j REDIRECT --to-port "$target_port" 2>/dev/null || true
}

issue_ssl_certificate() {
    local domain="$1"
    local ssl_dir="$2"
    local skip_reload="${3:-false}"

    check_acme_installed || install_acme || return 1
    create_dir_safe "$ssl_dir"

    if ! command -v socat >/dev/null 2>&1; then
        command -v apt-get >/dev/null 2>&1 && apt-get install -y -qq socat >/dev/null 2>&1 || true
    fi

    local acme_port
    acme_port=$(find_available_acme_port)
    [ -n "$acme_port" ] || return 1

    check_firewall_port "${acme_port}/tcp" || true

    local reload_cmd=""
    if [ "$skip_reload" != "true" ] && docker ps -q -f "name=$CONTAINER_NAME" 2>/dev/null | grep -q .; then
        reload_cmd="docker exec $CONTAINER_NAME nginx -s reload 2>/dev/null || true"
    fi

    log_info "Issuing certificate via TLS-ALPN on port $acme_port..."
    setup_acme_port_redirect "$acme_port"

    local args=(--issue --standalone -d "$domain"
        --key-file "$ssl_dir/private.key"
        --fullchain-file "$ssl_dir/fullchain.crt"
        --alpn --tlsport "$acme_port"
        --server letsencrypt --force)
    [ -n "$reload_cmd" ] && args+=(--reloadcmd "$reload_cmd")

    local exit_code=0
    "$ACME_HOME/acme.sh" "${args[@]}" >/dev/null 2>&1 || exit_code=$?
    cleanup_acme_port_redirect "$acme_port"

    if [ $exit_code -eq 0 ] && [ -f "$ssl_dir/private.key" ] && [ -f "$ssl_dir/fullchain.crt" ]; then
        chmod 600 "$ssl_dir/private.key"
        chmod 644 "$ssl_dir/fullchain.crt"
        return 0
    fi
    return 1
}

setup_ssl_auto_renewal() {
    local front_dir="$1"
    check_acme_installed || return 1
    local wrapper_script="$front_dir/acme-renew.sh"
    cat > "$wrapper_script" <<'WRAPPER_EOF'
#!/usr/bin/env bash
set -e
ACME_HOME="__ACME_HOME__"
CONTAINER="__CONTAINER__"
tls_ports=()
for domain_conf in "$ACME_HOME"/*/[!.]*.conf; do
    [ -f "$domain_conf" ] || continue
    saved_port=$(grep "^Le_TLSPort=" "$domain_conf" 2>/dev/null | cut -d"'" -f2 | tr -d '"')
    [ -n "$saved_port" ] && [ "$saved_port" != "443" ] && tls_ports+=("$saved_port")
done
for port in "${tls_ports[@]}"; do
    iptables -t nat -I PREROUTING 1 -p tcp --dport 443 -j REDIRECT --to-port "$port" 2>/dev/null || true
    iptables -t nat -I OUTPUT 1 -p tcp --dport 443 -o lo -j REDIRECT --to-port "$port" 2>/dev/null || true
done
"$ACME_HOME/acme.sh" --cron --home "$ACME_HOME" >/dev/null 2>&1
renew_exit=$?
for port in "${tls_ports[@]}"; do
    iptables -t nat -D PREROUTING -p tcp --dport 443 -j REDIRECT --to-port "$port" 2>/dev/null || true
    iptables -t nat -D OUTPUT -p tcp --dport 443 -o lo -j REDIRECT --to-port "$port" 2>/dev/null || true
done
docker exec "$CONTAINER" nginx -s reload 2>/dev/null || true
exit $renew_exit
WRAPPER_EOF
    sed -i "s|__ACME_HOME__|$ACME_HOME|g" "$wrapper_script"
    sed -i "s|__CONTAINER__|$CONTAINER_NAME|g" "$wrapper_script"
    chmod 700 "$wrapper_script"
    crontab -l 2>/dev/null | grep -v "realsteal.*acme-renew" | crontab - 2>/dev/null || true
    (crontab -l 2>/dev/null; echo "0 3 * * * $wrapper_script # realsteal acme-renew") | crontab -
}

renew_ssl_certificates() {
    check_acme_installed || return 1
    local tls_ports=()
    for domain_conf in "$ACME_HOME"/*/[!.]*.conf; do
        [ -f "$domain_conf" ] || continue
        local saved_port
        saved_port=$(grep "^Le_TLSPort=" "$domain_conf" 2>/dev/null | cut -d"'" -f2 | tr -d '"')
        [ -n "$saved_port" ] && [ "$saved_port" != "443" ] && tls_ports+=("$saved_port")
    done
    for port in "${tls_ports[@]}"; do setup_acme_port_redirect "$port"; done
    "$ACME_HOME/acme.sh" --cron --home "$ACME_HOME" 2>&1 || true
    for port in "${tls_ports[@]}"; do cleanup_acme_port_redirect "$port"; done
    if [ -f "$SSL_DIR/fullchain.crt" ] && [ -n "$DOMAIN" ]; then
        cp -f "$ACME_HOME/${DOMAIN}_ecc/fullchain.cer" "$SSL_DIR/fullchain.crt" 2>/dev/null || \
        cp -f "$ACME_HOME/${DOMAIN}/fullchain.cer" "$SSL_DIR/fullchain.crt" 2>/dev/null || true
        cp -f "$ACME_HOME/${DOMAIN}_ecc/${DOMAIN}.key" "$SSL_DIR/private.key" 2>/dev/null || \
        cp -f "$ACME_HOME/${DOMAIN}/${DOMAIN}.key" "$SSL_DIR/private.key" 2>/dev/null || true
    fi
    front_reload nginx
}

# ── App module dispatch ────────────────────────────────────────
app_exists() {
    local name="$1"
    declare -f "app_${name}_meta" >/dev/null 2>&1
}

app_is_implemented() {
    local name="$1"
    [ "${APP_IMPL[$name]:-0}" = "1" ]
}

app_dispatch() {
    local hook="$1"
    local app="${2:-$ACTIVE_APP}"
    if ! app_exists "$app"; then
        log_error "$(t err_app_not_found "$app")"
        return 1
    fi
    "app_${app}_${hook}"
}

app_list_names() {
    for name in jitsi nextcloud; do
        app_exists "$name" && echo "$name"
    done
}

# ── Module: jitsi ────────────────────────────────────────────────
JITSI_DIR="$REALSTEAL_DIR/jitsi"
JITSI_HTTP_PORT="8000"

app_jitsi_meta() {
    if [ "$LANGUAGE" = "ru" ]; then
        echo "jitsi|Jitsi Meet|Видеоконференции|10000/udp"
    else
        echo "jitsi|Jitsi Meet|Video conferencing|10000/udp"
    fi
}

app_jitsi_upstream() {
    echo "127.0.0.1:${JITSI_HTTP_PORT}"
}

app_jitsi_firewall_ports() {
    echo "10000/udp"
}

jitsi_patch_compose_ports() {
    local file="$JITSI_DIR/docker-compose.yml"
    local port="$JITSI_HTTP_PORT"
    [ -f "$file" ] || return 1
    sed -i \
        -e "/^[[:space:]]*- '443:443'/d" \
        -e '/^[[:space:]]*- "443:443"/d' \
        -e "s|^[[:space:]]*- '80:80'|      - '127.0.0.1:${port}:80'|" \
        -e "s|^[[:space:]]*- \"80:80\"|      - '127.0.0.1:${port}:80'|" \
        "$file"
    if ! grep -q "127.0.0.1:${port}:80" "$file"; then
        awk -v port="$port" '
            /^[[:space:]]*web:/ { in_web=1 }
            in_web && /^[[:space:]]*ports:/ { print; print "      - '\''127.0.0.1:" port ":80'\''"; skip=1; next }
            skip && /^[[:space:]]+- / { next }
            skip && /^[[:space:]]*[a-z]/ { skip=0; in_web=0 }
            { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    fi
}

app_jitsi_nginx_locations() {
    local upstream
    upstream=$(app_jitsi_upstream)
    cat <<EOF
    location = /xmpp-websocket {
        proxy_pass http://${upstream}/xmpp-websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-For \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_buffering off;
        tcp_nodelay on;
    }

    location = /colibri-ws {
        proxy_pass http://${upstream}/colibri-ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-For \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_buffering off;
        tcp_nodelay on;
    }

    location / {
        proxy_pass http://${upstream};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-For \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_read_timeout 900s;
        client_max_body_size 0;
    }
EOF
}

jitsi_apply_auth_env() {
    local mode="${1:-$AUTH_MODE}"
    local env_file="$JITSI_DIR/.env"
    [ -f "$env_file" ] || return 1
    case "$mode" in
        open)
            env_set "$env_file" ENABLE_AUTH "0"
            env_set "$env_file" ENABLE_GUESTS "1"
            ;;
        b)
            env_set "$env_file" ENABLE_AUTH "1"
            env_set "$env_file" AUTH_TYPE "internal"
            env_set "$env_file" ENABLE_GUESTS "1"
            ;;
        c)
            env_set "$env_file" ENABLE_AUTH "1"
            env_set "$env_file" AUTH_TYPE "internal"
            env_set "$env_file" ENABLE_GUESTS "0"
            ;;
    esac
}

app_jitsi_install() {
    local auth_mode="${1:-$AUTH_MODE}"
    AUTH_MODE="$auth_mode"

    create_dir_safe "$JITSI_DIR"
    if [ ! -f "$JITSI_DIR/docker-compose.yml" ]; then
        log_info "Cloning docker-jitsi-meet..."
        git clone --depth 1 https://github.com/jitsi/docker-jitsi-meet "$JITSI_DIR/src" 2>/dev/null || return 1
        cp "$JITSI_DIR/src/docker-compose.yml" "$JITSI_DIR/"
        cp "$JITSI_DIR/src/env.example" "$JITSI_DIR/.env"
        cp "$JITSI_DIR/src/gen-passwords.sh" "$JITSI_DIR/"
        chmod +x "$JITSI_DIR/gen-passwords.sh"
    fi

    if ! grep -qE '^JICOFO_AUTH_PASSWORD=[^[:space:]]' "$JITSI_DIR/.env" 2>/dev/null; then
        (cd "$JITSI_DIR" && bash gen-passwords.sh)
    fi

    local tz
    tz=$(cat /etc/timezone 2>/dev/null || timedatectl show -p Timezone --value 2>/dev/null || echo "UTC")
    local pub_ip="${SERVER_IP:-$(get_server_ip)}"

    env_set "$JITSI_DIR/.env" TZ "$tz"
    env_set "$JITSI_DIR/.env" PUBLIC_URL "https://${DOMAIN}"
    env_set "$JITSI_DIR/.env" HTTP_PORT "$JITSI_HTTP_PORT"
    env_set "$JITSI_DIR/.env" DISABLE_HTTPS "1"
    env_set "$JITSI_DIR/.env" ENABLE_HTTP_REDIRECT "0"
    env_set "$JITSI_DIR/.env" ENABLE_LETSENCRYPT "0"
    env_set "$JITSI_DIR/.env" JVB_ADVERTISE_IPS "$pub_ip"
    env_set "$JITSI_DIR/.env" JITSI_IMAGE_VERSION "stable"

    jitsi_apply_auth_env "$auth_mode"

    # CONFIG directories
    local cfg_base="${HOME}/.jitsi-meet-cfg"
    for d in web transcripts prosody/config prosody/prosody-plugins-custom jicofo jvb jigasi jibri; do
        create_dir_safe "${cfg_base}/${d}"
    done
    env_set "$JITSI_DIR/.env" CONFIG "$cfg_base"

    # Patch web ports — loopback only, remove 443
    jitsi_patch_compose_ports

    if port_in_use "${JITSI_HTTP_PORT}"; then
        if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q jitsi; then
            log_error "$(t err_port_busy "${JITSI_HTTP_PORT}")"
            return 1
        fi
    fi

    local fw_port
    fw_port=$(app_jitsi_firewall_ports)
    check_firewall_port "$fw_port" || {
        read -r -p "Open ${fw_port} in firewall? [Y/n]: " open_fw
        [[ ! "$open_fw" =~ ^[Nn]$ ]] && open_firewall_port "$fw_port"
    }

    (cd "$JITSI_DIR" && docker compose up -d) || return 1
    log_success "$(t ok_app_installed jitsi)"
    return 0
}

app_jitsi_uninstall() {
    if [ -d "$JITSI_DIR" ] && [ -f "$JITSI_DIR/docker-compose.yml" ]; then
        (cd "$JITSI_DIR" && docker compose down -v 2>/dev/null) || true
        rm -rf "$JITSI_DIR"
    fi
}

app_jitsi_status() {
    if [ ! -d "$JITSI_DIR" ]; then
        echo "not_installed"
        return
    fi
    (cd "$JITSI_DIR" && docker compose ps 2>/dev/null)
    echo "---"
    echo "auth: ${AUTH_MODE:-unknown}"
    ss -ulnp 2>/dev/null | grep ":10000 " || echo "udp/10000: not listening"
}

app_jitsi_post_notes() {
    if [ "$AUTH_MODE" != "open" ] && [ -f "$JITSI_DIR/.jitsi_admin_created" ]; then
        return 0
    fi
    if [ "$AUTH_MODE" = "open" ]; then
        echo -e "${GRAY}Jitsi: open mode — no login required${NC}"
        return 0
    fi
    : # credentials printed by user_add during install
}

jitsi_user_add() {
    local user="$1"
    local pass="$2"
    [ -n "$user" ] && [ -n "$pass" ] || return 1
    (cd "$JITSI_DIR" && docker compose exec -T prosody \
        prosodyctl --config /config/prosody.cfg.lua register "$user" meet.jitsi "$pass") || return 1
    echo "$user" >> "$JITSI_DIR/.jitsi_users" 2>/dev/null || true
    log_success "$(t jitsi_creds)"
    echo -e "${WHITE}   User: ${CYAN}${user}${NC}"
    echo -e "${WHITE}   Pass: ${CYAN}${pass}${NC}"
    touch "$JITSI_DIR/.jitsi_admin_created"
}

jitsi_user_del() {
    local user="$1"
    (cd "$JITSI_DIR" && docker compose exec -T prosody \
        prosodyctl --config /config/prosody.cfg.lua deluser "${user}@meet.jitsi") 2>/dev/null || true
}

jitsi_user_list() {
    (cd "$JITSI_DIR" && docker compose exec -T prosody \
        prosodyctl --config /config/prosody.cfg.lua list_users meet.jitsi) 2>/dev/null || \
    cat "$JITSI_DIR/.jitsi_users" 2>/dev/null || echo "(no users recorded)"
}

app_jitsi_auth_apply() {
    jitsi_apply_auth_env "$AUTH_MODE"
    (cd "$JITSI_DIR" && docker compose down && docker compose up -d)
}

# ── Module: nextcloud (stub) ─────────────────────────────────────
app_nextcloud_meta() {
    if [ "$LANGUAGE" = "ru" ]; then
        echo "nextcloud|Nextcloud|Облачное хранилище|(443 only)"
    else
        echo "nextcloud|Nextcloud|Cloud storage|(443 only)"
    fi
}

app_nextcloud_upstream() { echo "127.0.0.1:8081"; }
app_nextcloud_firewall_ports() { :; }
app_nextcloud_nginx_locations() {
    local upstream
    upstream=$(app_nextcloud_upstream)
    cat <<EOF
    location /.well-known/carddav { return 301 /remote.php/dav; }
    location /.well-known/caldav  { return 301 /remote.php/dav; }
    location /.well-known/webfinger { return 301 /index.php/.well-known/webfinger; }
    location /.well-known/nodeinfo  { return 301 /index.php/.well-known/nodeinfo; }
    location / {
        proxy_pass http://${upstream};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-For \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-Proto https;
        client_max_body_size 10G;
    }
EOF
}

app_nextcloud_install() {
    log_error "$(t err_app_not_impl nextcloud)"
    return 1
}

app_nextcloud_uninstall() { :; }
app_nextcloud_status() { echo "not_implemented"; }
app_nextcloud_post_notes() { echo "Nextcloud: coming soon"; }

# ── Front configuration ──────────────────────────────────────────
backup_front_conf() {
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$FRONT_DIR/backups/${ts}"
    create_dir_safe "$backup_dir"
    [ -d "$FRONT_DIR/conf.d" ] && cp -a "$FRONT_DIR/conf.d" "$backup_dir/"
    [ -f "$FRONT_DIR/nginx.conf" ] && cp -a "$FRONT_DIR/nginx.conf" "$backup_dir/"
    echo "$backup_dir"
}

restore_front_conf() {
    local backup_dir="$1"
    [ -d "$backup_dir/conf.d" ] && cp -a "$backup_dir/conf.d/." "$FRONT_DIR/conf.d/"
    [ -f "$backup_dir/nginx.conf" ] && cp -a "$backup_dir/nginx.conf" "$FRONT_DIR/nginx.conf"
}

write_nginx_main_conf() {
    cat > "$FRONT_DIR/nginx.conf" << 'NGINX_MAIN'
user nginx;
worker_processes auto;
worker_rlimit_nofile 65535;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent"';

    log_format proxy_protocol '$proxy_protocol_addr - $remote_user [$time_local] "$request" '
                              '$status $body_bytes_sent "$http_referer" '
                              '"$http_user_agent"';

    access_log /var/log/nginx/access.log main;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    server_tokens off;
    client_max_body_size 100m;
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    include /etc/nginx/conf.d/*.conf;
}
NGINX_MAIN
}

render_front_conf() {
    local app="${1:-$ACTIVE_APP}"
    [ -n "$app" ] || { log_error "$(t err_no_active_app)"; return 1; }
    [ -n "$FRONT_DIR" ] || return 1

    local backup
    backup=$(backup_front_conf)

    create_dir_safe "$FRONT_DIR/conf.d"
    create_dir_safe "$FRONT_DIR/html/.well-known/acme-challenge"
    create_dir_safe "$FRONT_DIR/logs"
    create_dir_safe "$FRONT_DIR/ssl"

    write_nginx_main_conf

    local locations upstream listen_block
    locations=$(app_dispatch nginx_locations "$app")
    upstream=$(app_dispatch upstream "$app")

    local conf_file="$FRONT_DIR/conf.d/realsteal.conf"
    local http_block
    http_block=$(cat <<EOF
# HTTP — ACME + redirect
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files \$uri =404;
    }
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF
)

    local https_common
    https_common=$(cat <<EOF
    ssl_certificate /etc/nginx/ssl/fullchain.crt;
    ssl_certificate_key /etc/nginx/ssl/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    access_log /var/log/nginx/access.log proxy_protocol;
    error_log /var/log/nginx/error.log warn;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

${locations}
EOF
)

    if [ "$FRONT_TYPE" = "socket" ]; then
        cat > "$conf_file" <<EOF
${http_block}

# HTTPS via Unix socket + proxy_protocol (Reality xver:1)
server {
    listen unix:${SOCKET_PATH} ssl proxy_protocol http2;
    server_name ${DOMAIN};
${https_common}
}
EOF
    else
        cat > "$conf_file" <<EOF
${http_block}

server {
    listen 127.0.0.1:${FRONT_PORT} ssl proxy_protocol http2;
    server_name ${DOMAIN};
${https_common}
}

server {
    listen 127.0.0.1:${FRONT_PORT} ssl default_server;
    server_name _;
    ssl_certificate /etc/nginx/ssl/fullchain.crt;
    ssl_certificate_key /etc/nginx/ssl/private.key;
    return 204;
}
EOF
    fi

    # Mark realsteal ownership
    echo "realsteal" > "$FRONT_DIR/.realsteal_managed"

    if ! front_validate_nginx; then
        log_error "$(t err_nginx_test)"
        restore_front_conf "$backup"
        return 1
    fi

    log_success "$(t ok_front_rendered)"
    echo -e "${GRAY}   upstream: ${upstream}${NC}"
    return 0
}

front_validate_nginx() {
    ensure_image "nginx:${NGINX_VERSION}" || true
    local out
    if out=$(docker run --rm \
        -v "$FRONT_DIR/nginx.conf:/etc/nginx/nginx.conf:ro" \
        -v "$FRONT_DIR/conf.d:/etc/nginx/conf.d:ro" \
        -v "$FRONT_DIR/ssl:/etc/nginx/ssl:ro" \
        nginx:${NGINX_VERSION} nginx -t 2>&1); then
        return 0
    fi
    echo "$out" | tail -15
    return 1
}

front_reload() {
    local svc="${1:-nginx}"
    if docker ps -q -f "name=$CONTAINER_NAME" 2>/dev/null | grep -q .; then
        docker exec "$CONTAINER_NAME" nginx -t && docker exec "$CONTAINER_NAME" nginx -s reload
    elif [ -d "$FRONT_DIR" ]; then
        (cd "$FRONT_DIR" && docker compose up -d)
    fi
}

write_standalone_compose() {
    local html_dir="$FRONT_DIR/html"
    if [ "$FRONT_TYPE" = "socket" ]; then
        cat > "$FRONT_DIR/docker-compose.yml" <<EOF
services:
  nginx:
    image: nginx:${NGINX_VERSION}
    container_name: ${CONTAINER_NAME_STANDALONE}
    restart: unless-stopped
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ${html_dir}:/var/www/html:ro
      - ./logs:/var/log/nginx
      - ./ssl:/etc/nginx/ssl:ro
      - /dev/shm:/dev/shm
    network_mode: "host"
EOF
    else
        cat > "$FRONT_DIR/docker-compose.yml" <<EOF
services:
  nginx:
    image: nginx:${NGINX_VERSION}
    container_name: ${CONTAINER_NAME_STANDALONE}
    restart: unless-stopped
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ${html_dir}:/var/www/html:ro
      - ./logs:/var/log/nginx
      - ./ssl:/etc/nginx/ssl:ro
    network_mode: "host"
EOF
    fi
}

front_standalone_setup() {
    FRONT_MODE="standalone"
    FRONT_DIR="$STANDALONE_FRONT_DIR"
    SSL_DIR="$FRONT_DIR/ssl"
    CONTAINER_NAME="$CONTAINER_NAME_STANDALONE"

    create_dir_safe "$FRONT_DIR"
    create_dir_safe "$FRONT_DIR/html/.well-known/acme-challenge"
    create_dir_safe "$FRONT_DIR/ssl"

    if [ ! -f "$SSL_DIR/fullchain.crt" ] || [ ! -f "$SSL_DIR/private.key" ]; then
        issue_ssl_certificate "$DOMAIN" "$SSL_DIR" "true" || return 1
        setup_ssl_auto_renewal "$FRONT_DIR"
    fi

    write_standalone_compose
    render_front_conf "$ACTIVE_APP" || return 1
    ensure_image "nginx:${NGINX_VERSION}" || true
    (cd "$FRONT_DIR" && docker compose up -d)
}

front_adopt_setup() {
    if ! detect_selfsteal_nginx; then
        log_error "selfsteal nginx not found at $SELFSTEAL_DIR"
        return 1
    fi

    FRONT_MODE="adopt"
    FRONT_DIR="$SELFSTEAL_DIR"
    SSL_DIR="$FRONT_DIR/ssl"
    CONTAINER_NAME="$CONTAINER_NAME_ADOPT"
    ADOPTED_FROM="$SELFSTEAL_DIR"

    log_warning "$(t info_adopt_warn)"
    log_warning "$(t info_adopt_template)"

    # Detect socket vs tcp from existing conf
    if grep -q "listen unix:${SOCKET_PATH}" "$FRONT_DIR/conf.d/"*.conf 2>/dev/null; then
        FRONT_TYPE="socket"
    elif grep -q "listen 127.0.0.1:" "$FRONT_DIR/conf.d/"*.conf 2>/dev/null; then
        FRONT_TYPE="tcp"
        FRONT_PORT=$(grep -oh "listen 127.0.0.1:[0-9]*" "$FRONT_DIR/conf.d/"*.conf 2>/dev/null | head -1 | cut -d: -f3 || echo "$DEFAULT_TCP_PORT")
    fi

    # Backup selfsteal static conf
    local adopt_backup="$REALSTEAL_DIR/adopt_backup_$(date +%Y%m%d_%H%M%S)"
    create_dir_safe "$adopt_backup"
    cp -a "$FRONT_DIR/conf.d" "$adopt_backup/" 2>/dev/null || true
    state_set ADOPT_BACKUP "$adopt_backup"

    # Read domain from selfsteal .env if not set
    if [ -z "$DOMAIN" ] && [ -f "$FRONT_DIR/.env" ]; then
        DOMAIN=$(env_get "$FRONT_DIR/.env" SELF_STEAL_DOMAIN "")
    fi

    render_front_conf "$ACTIVE_APP" || return 1
    front_reload nginx
}

front_restore_adopt_backup() {
    local backup
    backup=$(state_get ADOPT_BACKUP "")
    if [ -n "$backup" ] && [ -d "$backup/conf.d" ]; then
        cp -a "$backup/conf.d/." "$SELFSTEAL_DIR/conf.d/"
        rm -f "$SELFSTEAL_DIR/.realsteal_managed"
        front_reload nginx
        log_success "$(t uninstall_adopt_restore)"
        return 0
    fi
    log_warning "$(t uninstall_adopt_manual)"
}

install_management_script() {
    local target="/usr/local/bin/$APP_NAME"
    local src="$0"
    [ -f "$src" ] && [ "$src" != "bash" ] || src="$SCRIPT_DIR/realsteal.sh"
    if [ -f "$src" ]; then
        cp "$src" "$target" 2>/dev/null && chmod +x "$target" && log_success "Installed: $target"
    fi
}

# ── Commands ─────────────────────────────────────────────────────
install_command() {
    check_running_as_root
    log_info "$(t info_installing)"

    command -v docker >/dev/null 2>&1 || install_docker
    check_docker || return 1

    SERVER_IP=$(get_server_ip)

    # Domain
    if [ -z "$DOMAIN" ]; then
        read -r -p "$(t prompt_domain): " DOMAIN
    fi

    # App selection (early for preflight)
    echo
    echo "$(t prompt_app):"
    echo "  1) jitsi — $(app_jitsi_meta | cut -d'|' -f3-)"
    echo "  2) nextcloud — $(app_nextcloud_meta | cut -d'|' -f3-) [soon]"
    read -r -p "Choice [1]: " app_choice
    case "$app_choice" in
        2) ACTIVE_APP="nextcloud" ;;
        *) ACTIVE_APP="jitsi" ;;
    esac

    if ! app_is_implemented "$ACTIVE_APP"; then
        log_error "$(t err_app_not_impl "$ACTIVE_APP")"
        return 1
    fi

    preflight_install_checks "$ACTIVE_APP" || return 1

    # Front mode
    echo
    echo "$(t prompt_front_mode):"
    echo "  $(t prompt_front_standalone)"
    if detect_selfsteal_nginx; then
        echo "  $(t prompt_front_adopt)"
    fi
    read -r -p "Choice [1/2]: " fm_choice
    case "$fm_choice" in
        2)
            if detect_selfsteal_nginx; then
                FRONT_MODE="adopt"
            else
                FRONT_MODE="standalone"
            fi
            ;;
        *) FRONT_MODE="standalone" ;;
    esac

    if [ "$FRONT_MODE" = "standalone" ]; then
        FRONT_TYPE="socket"
        FRONT_DIR="$STANDALONE_FRONT_DIR"
        CONTAINER_NAME="$CONTAINER_NAME_STANDALONE"
        if detect_selfsteal_nginx && docker ps --format '{{.Names}}' 2>/dev/null | grep -q "$CONTAINER_NAME_ADOPT"; then
            log_warning "$(t info_selfsteal_conflict)"
            read -r -p "$(t prompt_continue) " cont
            [[ "$cont" =~ ^[Yy]$ ]] || return 1
        fi
        if [ -d "$CADDY_SELFSTEAL_DIR" ] && [ -f "$CADDY_SELFSTEAL_DIR/docker-compose.yml" ]; then
            log_warning "$(t info_selfsteal_conflict) (caddy at $CADDY_SELFSTEAL_DIR)"
        fi
    else
        FRONT_DIR="$SELFSTEAL_DIR"
        CONTAINER_NAME="$CONTAINER_NAME_ADOPT"
    fi

    # App already selected above

    # Auth (jitsi)
    if [ "$ACTIVE_APP" = "jitsi" ]; then
        echo
        echo "$(t prompt_auth):"
        echo "  $(t prompt_auth_open)"
        echo "  $(t prompt_auth_b)"
        echo "  $(t prompt_auth_c)"
        read -r -p "Choice [2]: " auth_choice
        case "$auth_choice" in
            1) AUTH_MODE="open" ;;
            3) AUTH_MODE="c" ;;
            *) AUTH_MODE="b" ;;
        esac
    fi

    state_init_file
    state_save_all

    # Install app
    app_dispatch install "$ACTIVE_APP" "$AUTH_MODE" || return 1

    # Setup front
    if [ "$FRONT_MODE" = "standalone" ]; then
        front_standalone_setup || return 1
    else
        front_adopt_setup || return 1
    fi

    # Create jitsi user for B/C
    if [ "$ACTIVE_APP" = "jitsi" ] && [ "$AUTH_MODE" != "open" ]; then
        local juser jpass
        juser="${DOMAIN%%.*}"
        [ ${#juser} -gt 20 ] && juser="admin"
        jpass=$(openssl rand -base64 12 2>/dev/null || head -c 12 /dev/urandom | base64)
        sleep 5
        jitsi_user_add "$juser" "$jpass" || true
    fi

    state_save_all
    install_management_script
    app_dispatch post_notes "$ACTIVE_APP" || true
    guide_command_brief

    log_success "$(t ok_installed)"
}

guide_command_brief() {
    local xray_target
    if [ "$FRONT_TYPE" = "socket" ]; then
        xray_target="$SOCKET_PATH"
    else
        xray_target="127.0.0.1:${FRONT_PORT}"
    fi
    echo
    echo -e "${CYAN}$(t guide_reality_hint)${NC}"
    echo -e "${WHITE}   dest / target:${NC} ${CYAN}${xray_target}${NC}"
    echo -e "${WHITE}   serverNames:${NC} ${CYAN}${DOMAIN}${NC}"
    echo -e "${WHITE}   xver:${NC} ${CYAN}1${NC}"
    echo -e "${WHITE}   Active app:${NC} ${CYAN}${ACTIVE_APP}${NC} → $(app_dispatch upstream "$ACTIVE_APP")"
}

guide_command() {
    require_installed
    clear
    echo -e "${WHITE}📖 $(t guide_title)${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 50))${NC}"
    echo
    guide_command_brief
    echo
    echo -e "${GRAY}Reality inbound example (Remnawave panel):${NC}"
    local xray_target
    [ "$FRONT_TYPE" = "socket" ] && xray_target="$SOCKET_PATH" || xray_target="127.0.0.1:${FRONT_PORT}"
    cat <<EOF
{
  "dest": "${xray_target}",
  "xver": 1,
  "serverNames": ["${DOMAIN}"]
}
EOF
    echo
    read -r -p "Press Enter..." _
}

up_command() {
    require_installed
    check_running_as_root
    case "$ACTIVE_APP" in
        jitsi) [ -d "$JITSI_DIR" ] && (cd "$JITSI_DIR" && docker compose up -d) ;;
    esac
    [ -d "$FRONT_DIR" ] && (cd "$FRONT_DIR" && docker compose up -d)
    log_success "$(t status_running)"
}

down_command() {
    require_installed
    check_running_as_root
    case "$ACTIVE_APP" in
        jitsi) [ -d "$JITSI_DIR" ] && (cd "$JITSI_DIR" && docker compose down) ;;
    esac
    [ -d "$FRONT_DIR" ] && (cd "$FRONT_DIR" && docker compose stop) 2>/dev/null || true
}

restart_command() {
    down_command
    up_command
    front_reload nginx
}

status_command() {
    require_installed
    echo -e "${WHITE}📊 Realsteal Status${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 40))${NC}"
    printf "   %-14s %s\n" "$(t label_domain):" "$DOMAIN"
    printf "   %-14s %s\n" "$(t label_front_mode):" "$FRONT_MODE ($FRONT_TYPE)"
    printf "   %-14s %s\n" "$(t label_active_app):" "$ACTIVE_APP"
    printf "   %-14s %s\n" "$(t label_auth):" "${AUTH_MODE:-n/a}"
    printf "   %-14s %s\n" "$(t label_upstream):" "$(app_dispatch upstream "$ACTIVE_APP" 2>/dev/null || echo n/a)"
    echo
    echo -e "${WHITE}Front ($CONTAINER_NAME):${NC}"
    docker ps -f "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  not running"
    echo
    echo -e "${WHITE}App ($ACTIVE_APP):${NC}"
    app_dispatch status "$ACTIVE_APP" 2>/dev/null || echo "  n/a"
}

logs_command() {
    require_installed
    local target="${1:-front}"
    case "$target" in
        app|jitsi)
            [ -d "$JITSI_DIR" ] && (cd "$JITSI_DIR" && docker compose logs -f --tail=100) ;;
        *)
            [ -d "$FRONT_DIR" ] && (cd "$FRONT_DIR" && docker compose logs -f --tail=100) ;;
    esac
}

app_list_command() {
    echo -e "${WHITE}Available applications:${NC}"
    while IFS= read -r name; do
        local meta impl_mark
        meta=$(app_dispatch meta "$name" 2>/dev/null || echo "$name")
        if app_is_implemented "$name"; then impl_mark="✅"; else impl_mark="🔜"; fi
        echo "  $impl_mark $meta"
    done < <(app_list_names)
}

app_install_command() {
    require_installed
    local name="${1:-}"
    [ -n "$name" ] || { app_list_command; read -r -p "App name: " name; }
    app_is_implemented "$name" || { log_error "$(t err_app_not_impl "$name")"; return 1; }
    app_dispatch install "$name" || return 1
    ACTIVE_APP="$name"
    state_set ACTIVE_APP "$ACTIVE_APP"
    render_front_conf "$ACTIVE_APP" && front_reload nginx
}

app_uninstall_command() {
    require_installed
    local name="${1:-$ACTIVE_APP}"
    read -r -p "$(t prompt_confirm) " c
    [[ "$c" =~ ^[Yy]$ ]] || return 0
    app_dispatch uninstall "$name"
    [ "$ACTIVE_APP" = "$name" ] && state_set ACTIVE_APP ""
}

app_switch_command() {
    require_installed
    local name="${1:-}"
    [ -n "$name" ] || { app_list_command; read -r -p "Switch to: " name; }
    app_is_implemented "$name" || { log_error "$(t err_app_not_impl "$name")"; return 1; }
    if [ ! -d "$REALSTEAL_DIR/$name" ] && [ "$name" = "jitsi" ] && [ ! -d "$JITSI_DIR" ]; then
        app_dispatch install "$name" || return 1
    fi
    ACTIVE_APP="$name"
    state_set ACTIVE_APP "$ACTIVE_APP"
    render_front_conf "$ACTIVE_APP" && front_reload nginx
    log_success "$(t ok_app_switched "$name")"
}

auth_command() {
    require_installed
    [ "$ACTIVE_APP" = "jitsi" ] || { log_error "Auth only supported for jitsi"; return 1; }
    local mode="${1:-}"
    mode=$(echo "$mode" | tr '[:upper:]' '[:lower:]')
    if [ -z "$mode" ]; then
        echo "Usage: realsteal auth <open|b|c>"
        return 1
    fi
    case "$mode" in
        open) AUTH_MODE="open" ;;
        b) AUTH_MODE="b" ;;
        c) AUTH_MODE="c" ;;
        *) log_error "Invalid mode: $mode"; return 1 ;;
    esac
    state_set AUTH_MODE "$AUTH_MODE"
    app_jitsi_auth_apply
    log_success "Auth mode: $AUTH_MODE"
}

user_command() {
    require_installed
    [ "$ACTIVE_APP" = "jitsi" ] || return 1
    local sub="${1:-}" user="${2:-}" pass="${3:-}"
    case "$sub" in
        add)
            [ -z "$user" ] && read -r -p "Username: " user
            [ -z "$pass" ] && pass=$(openssl rand -base64 12 2>/dev/null || head -c 12 /dev/urandom | base64)
            jitsi_user_add "$user" "$pass"
            ;;
        del)
            [ -z "$user" ] && read -r -p "Username: " user
            jitsi_user_del "$user"
            ;;
        list) jitsi_user_list ;;
        *) echo "Usage: realsteal user add|del|list [user] [pass]" ;;
    esac
}

renew_ssl_command() {
    require_installed
    check_running_as_root
    renew_ssl_certificates
    log_success "SSL renewal completed"
}

uninstall_command() {
    require_installed
    check_running_as_root
    read -r -p "$(t prompt_confirm) " c
    [[ "$c" =~ ^[Yy]$ ]] || return 0

    case "$ACTIVE_APP" in
        jitsi) app_jitsi_uninstall ;;
    esac

    if [ "$FRONT_MODE" = "adopt" ]; then
        front_restore_adopt_backup
    else
        [ -d "$STANDALONE_FRONT_DIR" ] && (cd "$STANDALONE_FRONT_DIR" && docker compose down -v 2>/dev/null) || true
        rm -rf "$STANDALONE_FRONT_DIR"
    fi

    rm -f "/usr/local/bin/$APP_NAME"
    rm -rf "$REALSTEAL_DIR"
    log_success "$(t ok_uninstalled)"
}

show_help() {
    cat <<EOF
$(t menu_title) v${SCRIPT_VERSION}

Usage: $APP_NAME [options] <command> [args]

Commands:
  install              Interactive install (front + app)
  up|down|restart        Lifecycle front + app
  status|logs [app]      Status and logs
  app list|install|uninstall|switch <name>
  auth <open|b|c>        Jitsi auth mode
  user add|del|list      Jitsi users
  renew-ssl              Renew Let's Encrypt certificate
  guide                  Reality dest/serverNames reminder
  uninstall              Remove realsteal (+ restore adopt backup)
  menu                   Interactive menu
  --lang en|ru           UI language
  --help|--version

Note: realsteal and selfsteal are mutually exclusive as active content front.
      Only one Reality dest per domain/node.
EOF
}

main_menu() {
    detect_language
    while true; do
        clear
        echo -e "${WHITE}🔗 $(t menu_title)${NC} v${SCRIPT_VERSION}"
        echo -e "${GRAY}$(printf '─%.0s' $(seq 1 40))${NC}"
        state_load
        if [ -n "$DOMAIN" ]; then
            printf "   %-12s %s\n" "$(t label_domain):" "$DOMAIN"
            printf "   %-12s %s / %s\n" "$(t label_active_app):" "${ACTIVE_APP:-—}" "${FRONT_MODE:-—}"
        else
            echo "   $(t status_not_installed)"
        fi
        echo
        echo "  1) $(t menu_install)"
        echo "  2) $(t menu_up)"
        echo "  3) $(t menu_down)"
        echo "  4) $(t menu_restart)"
        echo "  5) $(t menu_status)"
        echo "  6) $(t menu_logs)"
        echo "  7) $(t menu_app)"
        echo "  8) $(t menu_auth)"
        echo "  9) $(t menu_users)"
        echo " 10) $(t menu_renew_ssl)"
        echo " 11) $(t menu_guide)"
        echo " 12) $(t menu_uninstall)"
        echo "  0) $(t menu_exit)"
        echo
        read -r -p "Choice: " choice
        case "$choice" in
            1) install_command; read -r -p "Enter..." _ ;;
            2) up_command; read -r -p "Enter..." _ ;;
            3) down_command; read -r -p "Enter..." _ ;;
            4) restart_command; read -r -p "Enter..." _ ;;
            5) status_command; read -r -p "Enter..." _ ;;
            6) logs_command; ;;
            7) app_list_command; read -r -p "Enter..." _ ;;
            8)
                echo "  1) open  2) b  3) c"
                read -r -p "Auth mode: " am
                case "$am" in 1) auth_command open ;; 3) auth_command c ;; *) auth_command b ;; esac
                read -r -p "Enter..." _
                ;;
            9) user_command list; read -r -p "Enter..." _ ;;
            10) renew_ssl_command; read -r -p "Enter..." _ ;;
            11) guide_command ;;
            12) uninstall_command; read -r -p "Enter..." _ ;;
            0) exit 0 ;;
        esac
    done
}

# ── Argument parsing ─────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug) DEBUG_MODE=true; set +e; shift ;;
        --force) FORCE_MODE=true; shift ;;
        --lang)
            LANGUAGE="$2"; shift 2 ;;
        --lang=*) LANGUAGE="${1#*=}"; shift ;;
        --help|-h) init_i18n; show_help; exit 0 ;;
        --version|-v) echo "Realsteal v$SCRIPT_VERSION"; exit 0 ;;
        *)
            if [ -z "$COMMAND" ]; then COMMAND="$1"; else ARGS+=("$1"); fi
            shift ;;
    esac
done

init_i18n
detect_language
state_load

case "${COMMAND:-}" in
    install) install_command ;;
    up) up_command ;;
    down) down_command ;;
    restart) restart_command ;;
    status) status_command ;;
    logs) logs_command "${ARGS[0]:-front}" ;;
    app)
        sub="${ARGS[0]:-list}"
        case "$sub" in
            list) app_list_command ;;
            install) app_install_command "${ARGS[1]:-}" ;;
            uninstall) app_uninstall_command "${ARGS[1]:-}" ;;
            switch) app_switch_command "${ARGS[1]:-}" ;;
            *) log_error "$(t err_unknown_cmd "$sub")"; exit 1 ;;
        esac ;;
    auth) auth_command "${ARGS[0]:-}" ;;
    user)
        user_command "${ARGS[0]:-}" "${ARGS[1]:-}" "${ARGS[2]:-}" ;;
    renew-ssl) renew_ssl_command ;;
    guide) guide_command ;;
    uninstall) uninstall_command ;;
    render)
        require_installed
        render_front_conf && front_reload nginx ;;
    menu|"") main_menu ;;
    help) show_help ;;
    *)
        if [ -n "$COMMAND" ]; then
            log_error "$(t err_unknown_cmd "$COMMAND")"
            show_help
            exit 1
        fi
        main_menu ;;
esac
