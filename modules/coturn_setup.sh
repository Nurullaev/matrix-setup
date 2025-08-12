#!/bin/bash

# Coturn TURN Server Setup Module for Matrix
# Устанавливает и настраивает coturn для надежных VoIP вызовов
# Версия: 1.0.0

# Настройки модуля
LIB_NAME="Coturn TURN Server Setup"
LIB_VERSION="1.0.0"
MODULE_NAME="coturn_setup"

# Подключение общей библиотеки
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="${SCRIPT_DIR}/../common/common_lib.sh"

if [ ! -f "$COMMON_LIB" ]; then
    echo "ОШИБКА: Не найдена библиотека common_lib.sh по пути: $COMMON_LIB"
    exit 1
fi

source "$COMMON_LIB"

# Конфигурационные переменные
CONFIG_DIR="/opt/matrix-install"
COTURN_CONFIG_FILE="/etc/turnserver.conf"
COTURN_BACKUP_DIR="$CONFIG_DIR/coturn_backups"

# Функция проверки системных требований для coturn
check_coturn_requirements() {
    print_header "ПРОВЕРКА ТРЕБОВАНИЙ ДЛЯ COTURN" "$BLUE"
    
    log "INFO" "Проверка системных требований для coturn..."
    
    # Проверка прав root
    check_root || return 1
    
    # Проверка архитектуры
    local arch=$(uname -m)
    if [[ ! "$arch" =~ ^(x86_64|amd64|arm64|aarch64)$ ]]; then
        log "ERROR" "Неподдерживаемая архитектура: $arch"
        return 1
    fi
    log "INFO" "Архитектура: $arch - поддерживается"
    
    # Проверка доступной памяти (минимум 512MB для coturn)
    local memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local memory_mb=$((memory_kb / 1024))
    
    if [ "$memory_mb" -lt 512 ]; then
        log "WARN" "Недостаточно оперативной памяти: ${memory_mb}MB (рекомендуется минимум 512MB)"
        if ! ask_confirmation "Продолжить установку с недостаточным объемом памяти?"; then
            return 1
        fi
    else
        log "INFO" "Оперативная память: ${memory_mb}MB - достаточно"
    fi
    
    # Проверка подключения к интернету
    check_internet || return 1
    
    # Определение типа сервера для дальнейшей настройки
    load_server_type || return 1
    log "INFO" "Тип сервера: $SERVER_TYPE"
    
    log "SUCCESS" "Системные требования для coturn проверены"
    return 0
}

# Функция получения доменного имени для TURN
get_turn_domain() {
    local domain_file="$CONFIG_DIR/domain"
    local turn_domain_file="$CONFIG_DIR/turn_domain"
    
    # Читаем основной домен Matrix
    if [[ -f "$domain_file" ]]; then
        MATRIX_DOMAIN=$(cat "$domain_file")
        log "INFO" "Основной домен Matrix: $MATRIX_DOMAIN"
    else
        log "ERROR" "Не найден файл с доменом Matrix сервера"
        return 1
    fi
    
    # Проверяем сохранённый домен TURN
    if [[ -f "$turn_domain_file" ]]; then
        TURN_DOMAIN=$(cat "$turn_domain_file")
        log "INFO" "Найден сохранённый домен TURN: $TURN_DOMAIN"
        
        if ask_confirmation "Использовать сохранённый домен TURN $TURN_DOMAIN?"; then
            return 0
        fi
    fi
    
    print_header "НАСТРОЙКА ДОМЕНА TURN СЕРВЕРА" "$CYAN"
    
    # Предлагаем варианты доменов в зависимости от типа сервера
    case "$SERVER_TYPE" in
        "proxmox"|"home_server"|"docker"|"openvz")
            local suggested_domain="turn.${MATRIX_DOMAIN#*.}"
            safe_echo "${BLUE}Для локального сервера рекомендуется домен: ${CYAN}$suggested_domain${NC}"
            safe_echo "${YELLOW}Или используйте IP адрес сервера для простоты${NC}"
            ;;
        *)
            local suggested_domain="turn.$MATRIX_DOMAIN"
            safe_echo "${BLUE}Для облачного сервера рекомендуется домен: ${CYAN}$suggested_domain${NC}"
            ;;
    esac
    
    while true; do
        echo
        safe_echo "${YELLOW}Варианты домена TURN сервера:${NC}"
        safe_echo "${GREEN}1.${NC} Использовать поддомен (рекомендуется): turn.$MATRIX_DOMAIN"
        safe_echo "${GREEN}2.${NC} Использовать основной домен: $MATRIX_DOMAIN"
        safe_echo "${GREEN}3.${NC} Использовать IP адрес: ${PUBLIC_IP:-$LOCAL_IP}"
        safe_echo "${GREEN}4.${NC} Ввести собственный домен"
        
        echo
        read -p "$(safe_echo "${YELLOW}Выберите вариант (1-4): ${NC}")" domain_choice
        
        case $domain_choice in
            1)
                TURN_DOMAIN="turn.$MATRIX_DOMAIN"
                break
                ;;
            2)
                TURN_DOMAIN="$MATRIX_DOMAIN"
                break
                ;;
            3)
                TURN_DOMAIN="${PUBLIC_IP:-$LOCAL_IP}"
                break
                ;;
            4)
                read -p "$(safe_echo "${YELLOW}Введите домен TURN сервера: ${NC}")" custom_domain
                if [[ -n "$custom_domain" ]]; then
                    TURN_DOMAIN="$custom_domain"
                    break
                fi
                ;;
            *)
                log "ERROR" "Неверный выбор, попробуйте снова"
                ;;
        esac
    done
    
    log "INFO" "Домен TURN сервера: $TURN_DOMAIN"
    
    # Сохраняем домен
    mkdir -p "$CONFIG_DIR"
    echo "$TURN_DOMAIN" > "$turn_domain_file"
    log "SUCCESS" "Домен TURN сервера сохранён в $turn_domain_file"
    
    export TURN_DOMAIN
    return 0
}

# Функция установки coturn
install_coturn() {
    print_header "УСТАНОВКА COTURN" "$BLUE"
    
    log "INFO" "Установка coturn TURN сервера..."
    
    # Проверка, не установлен ли уже coturn
    if systemctl is-active --quiet coturn 2>/dev/null; then
        log "INFO" "Coturn уже установлен и запущен"
        local coturn_version=$(coturn --help 2>&1 | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "неизвестна")
        log "INFO" "Версия coturn: $coturn_version"
        
        if ask_confirmation "Пересоздать конфигурацию coturn?"; then
            return 0
        else
            return 0
        fi
    fi
    
    # Установка coturn
    log "INFO" "Установка пакета coturn..."
    if ! apt update; then
        log "ERROR" "Ошибка обновления списка пакетов"
        return 1
    fi
    
    if ! apt install -y coturn; then
        log "ERROR" "Ошибка установки coturn"
        return 1
    fi
    
    # Проверка установки
    if ! command -v turnserver >/dev/null 2>&1; then
        log "ERROR" "Coturn не установился корректно"
        return 1
    fi
    
    local coturn_version=$(turnserver --help 2>&1 | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "неизвестна")
    log "SUCCESS" "Coturn установлен, версия: $coturn_version"
    
    return 0
}

# Функция генерации конфигурации coturn
create_coturn_config() {
    print_header "СОЗДАНИЕ КОНФИГУРАЦИИ COTURN" "$CYAN"
    
    log "INFO" "Создание конфигурации coturn..."
    
    # Резервная копия существующей конфигурации
    if [[ -f "$COTURN_CONFIG_FILE" ]]; then
        backup_file "$COTURN_CONFIG_FILE" "coturn-config"
    fi
    
    # Генерация секретного ключа
    local turn_secret
    if [[ -f "$CONFIG_DIR/coturn_secret" ]]; then
        turn_secret=$(cat "$CONFIG_DIR/coturn_secret")
        log "INFO" "Использование существующего секрета TURN"
    else
        turn_secret=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
        echo "$turn_secret" > "$CONFIG_DIR/coturn_secret"
        chmod 600 "$CONFIG_DIR/coturn_secret"
        log "INFO" "Сгенерирован новый секрет TURN"
    fi
    
    # Определение настроек в зависимости от типа сервера
    local listening_ip="0.0.0.0"
    local external_ip=""
    local relay_ips=""
    
    case "$SERVER_TYPE" in
        "proxmox"|"home_server"|"docker"|"openvz")
            # Для локальных серверов настраиваем NAT
            if [[ -n "${PUBLIC_IP:-}" ]] && [[ "$PUBLIC_IP" != "$LOCAL_IP" ]]; then
                external_ip="external-ip=$PUBLIC_IP"
                log "INFO" "Настройка для NAT: внутренний IP $LOCAL_IP, внешний IP $PUBLIC_IP"
            else
                log "INFO" "Настройка для локальной сети без NAT"
            fi
            
            # Разрешаем локальные IP для тестирования
            if [[ -n "${LOCAL_IP:-}" ]]; then
                relay_ips="allowed-peer-ip=$LOCAL_IP"
            fi
            ;;
        *)
            # Для облачных серверов используем публичный IP
            if [[ -n "${PUBLIC_IP:-}" ]]; then
                external_ip="external-ip=$PUBLIC_IP"
            fi
            log "INFO" "Настройка для облачного сервера"
            ;;
    esac
    
    # Создание конфигурации coturn
    log "INFO" "Создание файла конфигурации $COTURN_CONFIG_FILE..."
    cat > "$COTURN_CONFIG_FILE" <<EOF
# Coturn TURN Server Configuration
# Generated by Matrix Setup Tool
# Server Type: $SERVER_TYPE
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

# Основные настройки
listening-port=3478
tls-listening-port=5349

# Адреса для прослушивания
listening-ip=$listening_ip
$external_ip

# Realm (домен) - используется клиентами для аутентификации
realm=$TURN_DOMAIN

# Секретный ключ для аутентификации
use-auth-secret
static-auth-secret=$turn_secret

# Логирование
syslog

# Настройки безопасности
# Запрещаем TCP relay для VoIP (только UDP)
no-tcp-relay

# Блокируем приватные IP адреса (безопасность)
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=172.16.0.0-172.31.255.255

# Дополнительные блокировки для безопасности
no-multicast-peers
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=100.64.0.0-100.127.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=192.0.0.0-192.0.0.255
denied-peer-ip=192.0.2.0-192.0.2.255
denied-peer-ip=192.88.99.0-192.88.99.255
denied-peer-ip=198.18.0.0-198.19.255.255
denied-peer-ip=198.51.100.0-198.51.100.255
denied-peer-ip=203.0.113.0-203.0.113.255
denied-peer-ip=240.0.0.0-255.255.255.255

# Разрешения для локального тестирования (если необходимо)
$relay_ips

# Ограничения для предотвращения DoS атак
user-quota=12
total-quota=1200

# Настройки производительности
max-bps=3000000

# Отключение TLS по умолчанию (можно включить позже)
no-tls
no-dtls

# Добавляем поддержку диапазона портов для relay
min-port=49152
max-port=65535

# Fingerprint для проверки подлинности
fingerprint

# Мобильная оптимизация
mobility

# Настройки для различных типов серверов
$(case "$SERVER_TYPE" in
    "proxmox"|"home_server"|"docker"|"openvz")
        cat <<'EOF_LOCAL'
# Настройки для локального/домашнего сервера
# Более мягкие ограничения для локальной сети
user-quota=20
total-quota=2000

# Разрешаем локальные сети (раскомментировать при необходимости)
# allowed-peer-ip=192.168.0.0-192.168.255.255
# allowed-peer-ip=10.0.0.0-10.255.255.255
# allowed-peer-ip=172.16.0.0-172.31.255.255
EOF_LOCAL
        ;;
    *)
        cat <<'EOF_CLOUD'
# Настройки для облачного сервера
# Более строгие ограничения
user-quota=8
total-quota=800

# Дополнительные меры безопасности
simple-log
EOF_CLOUD
        ;;
esac)
EOF

    # Установка прав доступа
    chown root:root "$COTURN_CONFIG_FILE"
    chmod 644 "$COTURN_CONFIG_FILE"
    
    log "SUCCESS" "Конфигурация coturn создана для типа сервера: $SERVER_TYPE"
    return 0
}

# Функция настройки systemd службы coturn
configure_coturn_service() {
    print_header "НАСТРОЙКА СЛУЖБЫ COTURN" "$CYAN"
    
    log "INFO" "Настройка системной службы coturn..."
    
    # Включение котурна в systemd
    if ! systemctl enable coturn; then
        log "ERROR" "Ошибка включения автозапуска coturn"
        return 1
    fi
    
    # Создание переопределения службы для лучшей производительности
    local override_dir="/etc/systemd/system/coturn.service.d"
    mkdir -p "$override_dir"
    
    cat > "$override_dir/matrix-optimization.conf" <<EOF
# Matrix TURN Server Optimizations
[Unit]
Description=Coturn TURN Server for Matrix
After=network.target

[Service]
# Увеличиваем лимиты для лучшей производительности
LimitNOFILE=65536
LimitNPROC=32768

# Настройки для стабильной работы
Restart=always
RestartSec=5
TimeoutStartSec=30
TimeoutStopSec=30

# Опциональные настройки безопасности
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/log /var/run

[Install]
WantedBy=multi-user.target
EOF

    # Перезагрузка systemd конфигурации
    systemctl daemon-reload
    
    log "SUCCESS" "Служба coturn настроена"
    return 0
}

# Функция настройки файрвола для coturn
configure_coturn_firewall() {
    print_header "НАСТРОЙКА ФАЙРВОЛА ДЛЯ COTURN" "$CYAN"
    
    log "INFO" "Настройка правил файрвола для coturn..."
    
    # Проверяем, установлен ли ufw
    if command -v ufw >/dev/null 2>&1; then
        log "INFO" "Настройка правил ufw для coturn..."
        
        # Основные порты TURN
        ufw allow 3478/tcp comment "Coturn TURN TCP"
        ufw allow 3478/udp comment "Coturn TURN UDP"
        ufw allow 5349/tcp comment "Coturn TURN TLS TCP"
        ufw allow 5349/udp comment "Coturn TURN TLS UDP"
        
        # Диапазон портов для relay
        ufw allow 49152:65535/udp comment "Coturn UDP relay range"
        
        log "SUCCESS" "Правила ufw для coturn настроены"
    else
        log "WARN" "ufw не установлен, настройте файрвол вручную"
        safe_echo "${YELLOW}Необходимо открыть порты:${NC}"
        safe_echo "  - 3478/tcp и 3478/udp (TURN)"
        safe_echo "  - 5349/tcp и 5349/udp (TURN TLS)"
        safe_echo "  - 49152-65535/udp (UDP relay)"
    fi
    
    return 0
}

# Функция запуска и проверки coturn
start_and_verify_coturn() {
    print_header "ЗАПУСК И ПРОВЕРКА COTURN" "$GREEN"
    
    log "INFO" "Запуск службы coturn..."
    
    # Запуск службы
    if ! systemctl start coturn; then
        log "ERROR" "Ошибка запуска coturn"
        log "INFO" "Проверьте логи: journalctl -u coturn -n 50"
        return 1
    fi
    
    # Ожидание запуска
    log "INFO" "Ожидание готовности coturn..."
    local attempts=0
    local max_attempts=10
    
    while [ $attempts -lt $max_attempts ]; do
        if systemctl is-active --quiet coturn; then
            log "SUCCESS" "Coturn запущен"
            break
        fi
        
        attempts=$((attempts + 1))
        if [ $attempts -eq $max_attempts ]; then
            log "ERROR" "Coturn не запустился в течение 10 секунд"
            log "INFO" "Проверьте логи: journalctl -u coturn -n 50"
            return 1
        fi
        
        log "DEBUG" "Ожидание запуска... ($attempts/$max_attempts)"
        sleep 1
    done
    
    # Проверка портов
    log "INFO" "Проверка сетевых портов..."
    if check_port 3478; then
        log "SUCCESS" "Порт 3478 готов для TURN соединений"
    else
        log "WARN" "Порт 3478 может быть недоступен"
    fi
    
    if check_port 5349; then
        log "SUCCESS" "Порт 5349 готов для TURN TLS соединений"
    else
        log "WARN" "Порт 5349 может быть недоступен"
    fi
    
    log "SUCCESS" "Coturn запущен и готов к работе"
    return 0
}

# Функция интеграции с Matrix Synapse
integrate_with_synapse() {
    print_header "ИНТЕГРАЦИЯ С MATRIX SYNAPSE" "$MAGENTA"
    
    log "INFO" "Настройка интеграции coturn с Matrix Synapse..."
    
    # Читаем секрет TURN
    local turn_secret
    if [[ -f "$CONFIG_DIR/coturn_secret" ]]; then
        turn_secret=$(cat "$CONFIG_DIR/coturn_secret")
    else
        log "ERROR" "Секрет TURN не найден"
        return 1
    fi
    
    # Создание конфигурации для Synapse
    local synapse_turn_config="$CONFIG_DIR/synapse_turn_config.yaml"
    log "INFO" "Создание конфигурации TURN для Synapse..."
    
    cat > "$synapse_turn_config" <<EOF
# TURN server configuration for Matrix Synapse
# Add this to your homeserver.yaml or include it via config includes

# TURN server URIs
turn_uris:
  - "turn:$TURN_DOMAIN:3478?transport=udp"
  - "turn:$TURN_DOMAIN:3478?transport=tcp"

# Shared secret for TURN authentication
turn_shared_secret: "$turn_secret"

# User lifetime for TURN credentials (24 hours)
turn_user_lifetime: 86400000

# Allow guests to use TURN server
turn_allow_guests: true
EOF

    chmod 600 "$synapse_turn_config"
    
    # Добавление в основную конфигурацию Synapse если возможно
    local synapse_config="/etc/matrix-synapse/homeserver.yaml"
    local synapse_conf_d="/etc/matrix-synapse/conf.d"
    
    if [[ -d "$synapse_conf_d" ]]; then
        # Предпочитаемый способ - отдельный файл в conf.d
        local turn_config_file="$synapse_conf_d/turn.yaml"
        cp "$synapse_turn_config" "$turn_config_file"
        chown matrix-synapse:matrix-synapse "$turn_config_file" 2>/dev/null || true
        
        log "SUCCESS" "Конфигурация TURN добавлена в $turn_config_file"
    elif [[ -f "$synapse_config" ]]; then
        # Резервный способ - показываем что добавить вручную
        log "WARN" "Добавьте следующие строки в $synapse_config:"
        echo
        safe_echo "${CYAN}# TURN server configuration${NC}"
        safe_echo "${CYAN}turn_uris:${NC}"
        safe_echo "${CYAN}  - \"turn:$TURN_DOMAIN:3478?transport=udp\"${NC}"
        safe_echo "${CYAN}  - \"turn:$TURN_DOMAIN:3478?transport=tcp\"${NC}"
        safe_echo "${CYAN}turn_shared_secret: \"$turn_secret\"${NC}"
        safe_echo "${CYAN}turn_user_lifetime: 86400000${NC}"
        safe_echo "${CYAN}turn_allow_guests: true${NC}"
        echo
    else
        log "WARN" "Конфигурация Synapse не найдена"
        log "INFO" "Используйте файл $synapse_turn_config для ручной настройки"
    fi
    
    # Сохранение конфигурации для справки
    cat > "$CONFIG_DIR/coturn_info.conf" <<EOF
# Coturn TURN Server Information
TURN_DOMAIN=$TURN_DOMAIN
TURN_SECRET_FILE=$CONFIG_DIR/coturn_secret
SYNAPSE_TURN_CONFIG=$synapse_turn_config
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
SERVER_TYPE=$SERVER_TYPE
EOF

    log "SUCCESS" "Интеграция с Matrix Synapse настроена"
    log "INFO" "Перезапустите Matrix Synapse для применения настроек TURN"
    
    return 0
}

# Функция проверки работы coturn
test_coturn_functionality() {
    print_header "ТЕСТИРОВАНИЕ COTURN" "$GREEN"
    
    log "INFO" "Проверка функциональности coturn..."
    
    # Базовые проверки
    if ! systemctl is-active --quiet coturn; then
        log "ERROR" "Coturn не запущен"
        return 1
    fi
    
    # Проверка портов
    local ports=(3478 5349)
    for port in "${ports[@]}"; do
        if ss -tlnp | grep -q ":$port "; then
            log "SUCCESS" "✓ Порт $port прослушивается"
        else
            log "WARN" "✗ Порт $port не прослушивается"
        fi
    done
    
    # Проверка конфигурации
    if turnserver --check-config -c "$COTURN_CONFIG_FILE" >/dev/null 2>&1; then
        log "SUCCESS" "✓ Конфигурация coturn корректна"
    else
        log "WARN" "✗ Возможны проблемы в конфигурации coturn"
    fi
    
    # Инструкции по тестированию
    safe_echo "${BOLD}${BLUE}Дополнительное тестирование:${NC}"
    safe_echo "1. ${CYAN}Тестер Matrix VoIP:${NC}"
    safe_echo "   https://test.voip.librepush.net/"
    echo
    safe_echo "2. ${CYAN}WebRTC тестер:${NC}"
    safe_echo "   https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/"
    echo
    safe_echo "3. ${CYAN}Информация для тестирования:${NC}"
    safe_echo "   TURN URI: turn:$TURN_DOMAIN:3478"
    safe_echo "   Username: test"
    safe_echo "   Password: используйте временные credentials из Synapse"
    
    return 0
}

# Функция показа статуса coturn
show_coturn_status() {
    print_header "СТАТУС COTURN" "$CYAN"
    
    echo "Домен TURN сервера: ${TURN_DOMAIN:-не настроен}"
    echo "Конфигурация: $COTURN_CONFIG_FILE"
    echo "Тип сервера: ${SERVER_TYPE:-не определен}"
    
    # Статус службы
    echo
    echo "Статус службы:"
    if systemctl is-active --quiet coturn; then
        safe_echo "${GREEN}• Coturn: запущен${NC}"
        
        # Показываем порты
        echo "  Прослушиваемые порты:"
        ss -tlnp | grep -E ":(3478|5349) " | while read line; do
            safe_echo "    ${GREEN}✓${NC} $line"
        done
    else
        safe_echo "${RED}• Coturn: остановлен${NC}"
    fi
    
    # Информация о конфигурации
    echo
    echo "Конфигурация:"
    if [[ -f "$CONFIG_DIR/coturn_secret" ]]; then
        safe_echo "${GREEN}• Секрет TURN: настроен${NC}"
    else
        safe_echo "${RED}• Секрет TURN: не настроен${NC}"
    fi
    
    if [[ -f "$CONFIG_DIR/coturn_info.conf" ]]; then
        source "$CONFIG_DIR/coturn_info.conf"
        safe_echo "${GREEN}• Дата установки: ${INSTALL_DATE:-неизвестна}${NC}"
    fi
    
    # Статистика подключений (если доступна)
    echo
    echo "Статистика (последние 24 часа):"
    local turn_sessions=$(journalctl -u coturn --since "24 hours ago" 2>/dev/null | grep -c "session" || echo "0")
    echo "  Сессий TURN: $turn_sessions"
    
    return 0
}

# Функция управления котурном
manage_coturn() {
    while true; do
        print_header "УПРАВЛЕНИЕ COTURN" "$YELLOW"
        
        safe_echo "${BOLD}Доступные действия:${NC}"
        safe_echo "${GREEN}1.${NC} Показать статус coturn"
        safe_echo "${GREEN}2.${NC} Перезапустить coturn"
        safe_echo "${GREEN}3.${NC} Остановить coturn"
        safe_echo "${GREEN}4.${NC} Запустить coturn"
        safe_echo "${GREEN}5.${NC} Показать логи coturn"
        safe_echo "${GREEN}6.${NC} Проверить конфигурацию"
        safe_echo "${GREEN}7.${NC} Тестировать функциональность"
        safe_echo "${GREEN}8.${NC} Диагностика сетевой доступности"
        safe_echo "${GREEN}9.${NC} Пересоздать конфигурацию"
        safe_echo "${GREEN}10.${NC} Назад в главное меню"
        
        echo
        read -p "$(safe_echo "${YELLOW}Выберите действие (1-10): ${NC}")" choice
        
        case $choice in
            1)
                show_coturn_status
                ;;
            2)
                log "INFO" "Перезапуск coturn..."
                if restart_service coturn; then
                    log "SUCCESS" "Coturn перезапущен"
                else
                    log "ERROR" "Ошибка перезапуска coturn"
                fi
                ;;
            3)
                log "INFO" "Остановка coturn..."
                if systemctl stop coturn; then
                    log "SUCCESS" "Coturn остановлен"
                else
                    log "ERROR" "Ошибка остановки coturn"
                fi
                ;;
            4)
                log "INFO" "Запуск coturn..."
                if systemctl start coturn; then
                    log "SUCCESS" "Coturn запущен"
                else
                    log "ERROR" "Ошибка запуска coturn"
                fi
                ;;
            5)
                log "INFO" "Логи coturn (Ctrl+C для выхода):"
                journalctl -u coturn -f
                ;;
            6)
                log "INFO" "Проверка конфигурации coturn..."
                if turnserver --check-config -c "$COTURN_CONFIG_FILE"; then
                    log "SUCCESS" "Конфигурация корректна"
                else
                    log "ERROR" "Ошибки в конфигурации"
                fi
                ;;
            7)
                test_coturn_functionality
                ;;
            8)
                diagnose_turn_connectivity
                ;;
            9)
                if ask_confirmation "Пересоздать конфигурацию coturn?"; then
                    create_coturn_config
                    if ask_confirmation "Перезапустить coturn для применения изменений?"; then
                        restart_service coturn
                    fi
                fi
                ;;
            10)
                return 0
                ;;
            *)
                log "ERROR" "Неверный выбор"
                sleep 1
                ;;
        esac
        
        if [ $choice -ne 10 ]; then
            read -p "Нажмите Enter для продолжения..."
        fi
    done
}

# Функция удаления coturn
remove_coturn() {
    print_header "УДАЛЕНИЕ COTURN" "$RED"
    
    if ! ask_confirmation "Вы уверены, что хотите удалить coturn TURN сервер?"; then
        log "INFO" "Удаление отменено пользователем"
        return 0
    fi
    
    log "INFO" "Начинаем удаление coturn..."
    
    # Остановка и отключение службы
    systemctl stop coturn 2>/dev/null || true
    systemctl disable coturn 2>/dev/null || true
    
    # Создание резервной копии конфигурации
    if [[ -f "$COTURN_CONFIG_FILE" ]]; then
        mkdir -p "$COTURN_BACKUP_DIR"
        cp "$COTURN_CONFIG_FILE" "$COTURN_BACKUP_DIR/turnserver.conf.backup-$(date +%Y%m%d_%H%M%S)"
        log "INFO" "Резервная копия конфигурации создана в $COTURN_BACKUP_DIR"
    fi
    
    # Удаление пакета
    apt remove -y coturn 2>/dev/null || true
    apt autoremove -y 2>/dev/null || true
    
    # Удаление конфигурационных файлов
    rm -f "$COTURN_CONFIG_FILE"
    rm -rf /etc/systemd/system/coturn.service.d/
    
    # Очистка systemd
    systemctl daemon-reload
    
    # Удаление из конфигурации Synapse
    local synapse_turn_config="/etc/matrix-synapse/conf.d/turn.yaml"
    if [[ -f "$synapse_turn_config" ]]; then
        mv "$synapse_turn_config" "$COTURN_BACKUP_DIR/synapse_turn.yaml.backup-$(date +%Y%m%d_%H%M%S)"
        log "INFO" "Конфигурация TURN удалена из Synapse"
    fi
    
    log "SUCCESS" "Coturn успешно удален"
    log "INFO" "Резервные копии сохранены в: $COTURN_BACKUP_DIR"
    log "WARN" "Не забудьте перезапустить Matrix Synapse и удалить настройки TURN из homeserver.yaml"
    
    return 0
}

choose_turn_deployment() {
    print_header "ВЫБОР СПОСОБА РАЗВЕРТЫВАНИЯ TURN" "$CYAN"
    
    case "$SERVER_TYPE" in
        "proxmox"|"home_server"|"docker"|"openvz")
            safe_echo "${YELLOW}⚠️ ОБНАРУЖЕНА ПРОБЛЕМА С СЕТЕВОЙ КОНФИГУРАЦИЕЙ${NC}"
            safe_echo "${RED}Для Proxmox за NAT требуются дополнительные порты:${NC}"
            safe_echo "   - 3478 (TURN TCP/UDP)"
            safe_echo "   - 5349 (TURN TLS TCP/UDP)"  
            safe_echo "   - 49152-65535 (UDP relay range)"
            echo
            safe_echo "${BLUE}Доступные варианты:${NC}"
            safe_echo "${GREEN}1.${NC} Установить локально (требует открытия портов на роутере)"
            safe_echo "${GREEN}2.${NC} Использовать внешний TURN сервер (рекомендуется)"
            safe_echo "${GREEN}3.${NC} Использовать публичный TURN сервер Matrix.org"
            safe_echo "${GREEN}4.${NC} Отменить установку"
            ;;
        *)
            # Для облачных серверов - стандартная установка
            return 0
            ;;
    esac
    
    echo
    read -p "$(safe_echo "${YELLOW}Выберите вариант (1-4): ${NC}")" deployment_choice
    
    case $deployment_choice in
        1)
            show_router_configuration_help
            if ask_confirmation "Порты уже настроены на роутере?"; then
                return 0  # Продолжить локальную установку
            else
                return 1  # Прервать установку
            fi
            ;;
        2)
            configure_external_turn_server
            return $?
            ;;
        3)
            configure_public_turn_server
            return $?
            ;;
        4)
            log "INFO" "Удаление TURN отменено пользователем"
            return 1
            ;;
        *)
            log "ERROR" "Неверный выбор"
            return 1
            ;;
    esac
}

# Функция помощи по настройке роутера (улучшенная версия)
show_router_configuration_help() {
    print_header "НАСТРОЙКА ПОРТОВ НА РОУТЕРЕ" "$YELLOW"
    
    safe_echo "${BOLD}Для работы TURN сервера необходимо открыть следующие порты:${NC}"
    echo
    safe_echo "${CYAN}Основные порты TURN:${NC}"
    safe_echo "   3478/tcp → ${LOCAL_IP}:3478"
    safe_echo "   3478/udp → ${LOCAL_IP}:3478"
    safe_echo "   5349/tcp → ${LOCAL_IP}:5349"  
    safe_echo "   5349/udp → ${LOCAL_IP}:5349"
    echo
    safe_echo "${CYAN}UDP relay диапазон:${NC}"
    safe_echo "   49152-65535/udp → ${LOCAL_IP}:49152-65535"
    echo
    safe_echo "${RED}⚠️ ВНИМАНИЕ: Диапазон 49152-65535/udp может быть большой нагрузкой${NC}"
    safe_echo "${YELLOW}💡 Рекомендуется использовать внешний TURN сервер вместо локального${NC}"
    echo
    
    # Добавляем специфичные инструкции для MikroTik
    safe_echo "${BOLD}${BLUE}Инструкции для MikroTik RouterOS:${NC}"
    echo
    safe_echo "${CYAN}1. Настройка NAT правил через Winbox:${NC}"
    safe_echo "   IP → Firewall → NAT → Add New"
    safe_echo "   Chain: dstnat"
    safe_echo "   Protocol: tcp"
    safe_echo "   Dst. Port: 3478"
    safe_echo "   Action: dst-nat"
    safe_echo "   To Addresses: ${LOCAL_IP}"
    safe_echo "   To Ports: 3478"
    echo
    safe_echo "${CYAN}2. Через командную строку MikroTik:${NC}"
    safe_echo "   /ip firewall nat"
    safe_echo "   add chain=dstnat protocol=tcp dst-port=3478 action=dst-nat to-addresses=${LOCAL_IP} to-ports=3478"
    safe_echo "   add chain=dstnat protocol=udp dst-port=3478 action=dst-nat to-addresses=${LOCAL_IP} to-ports=3478"
    safe_echo "   add chain=dstnat protocol=tcp dst-port=5349 action=dst-nat to-addresses=${LOCAL_IP} to-ports=5349"
    safe_echo "   add chain=dstnat protocol=udp dst-port=5349 action=dst-nat to-addresses=${LOCAL_IP} to-ports=5349"
    safe_echo "   add chain=dstnat protocol=udp dst-port=49152-65535 action=dst-nat to-addresses=${LOCAL_IP}"
    echo
    safe_echo "${CYAN}3. Разрешающие правила файрвола:${NC}"
    safe_echo "   /ip firewall filter"
    safe_echo "   add chain=forward protocol=tcp dst-port=3478 action=accept"
    safe_echo "   add chain=forward protocol=udp dst-port=3478 action=accept"
    safe_echo "   add chain=forward protocol=tcp dst-port=5349 action=accept"
    safe_echo "   add chain=forward protocol=udp dst-port=5349 action=accept"
    safe_echo "   add chain=forward protocol=udp dst-port=49152-65535 action=accept"
    echo
    safe_echo "${RED}⚠️ ВАЖНО: UDP диапазон 49152-65535 может создать проблемы безопасности!${NC}"
    safe_echo "${YELLOW}Рекомендуется ограничить до меньшего диапазона, например 50000-51000${NC}"
    echo
    safe_echo "${BLUE}Альтернативный подход - ограниченный диапазон:${NC}"
    safe_echo "   add chain=dstnat protocol=udp dst-port=50000-51000 action=dst-nat to-addresses=${LOCAL_IP}"
    safe_echo "   add chain=forward protocol=udp dst-port=50000-51000 action=accept"
    echo
    safe_echo "${CYAN}И обновить конфигурацию coturn:${NC}"
    safe_echo "   min-port=50000"
    safe_echo "   max-port=51000"
}

# Функция настройки внешнего TURN сервера
configure_external_turn_server() {
    print_header "НАСТРОЙКА ВНЕШНЕГО TURN СЕРВЕРА" "$BLUE"
    
    safe_echo "${BLUE}Рекомендуемые провайдеры для TURN сервера:${NC}"
    safe_echo "1. Hetzner Cloud (от 300₽/мес)"
    safe_echo "2. DigitalOcean (от $4/мес)"
    safe_echo "3. Vultr (от $2.50/мес)"
    safe_echo "4. Свой VPS"
    echo
    
    safe_echo "${YELLOW}Минимальные требования:${NC}"
    safe_echo "• 512MB RAM"
    safe_echo "• 1 CPU core"
    safe_echo "• Публичный IPv4"
    safe_echo "• Открытые порты 3478, 5349, 49152-65535"
    echo
    
    read -p "$(safe_echo "${YELLOW}Введите IP адрес внешнего TURN сервера: ${NC}")" external_turn_ip
    read -p "$(safe_echo "${YELLOW}Введите домен TURN сервера (или нажмите Enter для IP): ${NC}")" external_turn_domain
    
    # Валидация IP адреса
    if [[ ! "$external_turn_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log "ERROR" "Неверный формат IP адреса: $external_turn_ip"
        return 1
    fi
    
    TURN_DOMAIN="${external_turn_domain:-$external_turn_ip}"
    echo "$TURN_DOMAIN" > "$CONFIG_DIR/turn_domain"
    
    # Сохраняем IP для использования в других функциях
    export external_turn_ip
    
    # Генерация секрета для внешнего сервера
    local turn_secret=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    echo "$turn_secret" > "$CONFIG_DIR/coturn_secret"
    chmod 600 "$CONFIG_DIR/coturn_secret"
    
    log "INFO" "Сгенерирован секрет TURN для внешнего сервера"
    
    # Создание скрипта установки для внешнего сервера
    create_external_turn_install_script "$external_turn_ip" "$turn_secret"
    
    # Настройка Synapse для внешнего TURN
    configure_synapse_for_external_turn
    
    print_header "ВНЕШНИЙ TURN СЕРВЕР НАСТРОЕН!" "$GREEN"
    
    safe_echo "${GREEN}✅ Конфигурация для внешнего TURN сервера готова${NC}"
    safe_echo "${BLUE}📋 Информация:${NC}"
    safe_echo "   ${BOLD}IP сервера:${NC} $external_turn_ip"
    safe_echo "   ${BOLD}Домен TURN:${NC} $TURN_DOMAIN"
    safe_echo "   ${BOLD}Скрипт установки:${NC} $CONFIG_DIR/external_turn_install.sh"
    echo
    safe_echo "${YELLOW}📝 Следующие шаги:${NC}"
    safe_echo "   1. ${CYAN}Скопируйте и запустите скрипт на внешнем сервере${NC}"
    safe_echo "   2. ${CYAN}Убедитесь в доступности портов извне${NC}"
    safe_echo "   3. ${CYAN}Перезапустите Matrix Synapse${NC}"
    safe_echo "   4. ${CYAN}Протестируйте VoIP звонки${NC}"
    
    return 0
}

# Функция использования публичного TURN
configure_public_turn_server() {
    print_header "НАСТРОЙКА ПУБЛИЧНОГО TURN СЕРВЕРА" "$GREEN"
    
    safe_echo "${BLUE}Использование публичного TURN сервера Matrix.org${NC}"
    safe_echo "${YELLOW}⚠️ Это временное решение для тестирования${NC}"
    safe_echo "${RED}Не рекомендуется для продакшена!${NC}"
    echo
    
    if ask_confirmation "Продолжить с публичным TURN сервером?"; then
        TURN_DOMAIN="turn.matrix.org"
        echo "$TURN_DOMAIN" > "$CONFIG_DIR/turn_domain"
        
        # Создание конфигурации для публичного TURN
        local synapse_turn_config="$CONFIG_DIR/synapse_turn_config.yaml"
        cat > "$synapse_turn_config" <<EOF
# Public TURN server configuration (TEMPORARY SOLUTION)
# Replace with your own TURN server for production use

turn_uris:
  - "turn:turn.matrix.org:3478?transport=udp"
  - "turn:turn.matrix.org:3478?transport=tcp"
  - "turns:turn.matrix.org:5349?transport=udp"
  - "turns:turn.matrix.org:5349?transport=tcp"

# This is a placeholder - you'll need to get actual credentials
turn_shared_secret: "ask_matrix_org_for_credentials"
turn_user_lifetime: 86400000
turn_allow_guests: true
EOF
        
        # Добавление в Synapse
        local synapse_conf_d="/etc/matrix-synapse/conf.d"
        if [[ -d "$synapse_conf_d" ]]; then
            cp "$synapse_turn_config" "$synapse_conf_d/turn.yaml"
            chown matrix-synapse:matrix-synapse "$synapse_conf_d/turn.yaml" 2>/dev/null || true
        fi
        
        safe_echo "${GREEN}✅ Публичный TURN сервер настроен${NC}"
        safe_echo "${YELLOW}📝 Замените на собственный TURN сервер как можно скорее${NC}"
        
        return 0
    else
        return 1
    fi
}

# Функция создания скрипта установки для внешнего сервера
create_external_turn_install_script() {
    local external_turn_ip="$1"
    local turn_secret="$2"
    local install_script="$CONFIG_DIR/external_turn_install.sh"
    
    log "INFO" "Создание скрипта установки для внешнего TURN сервера..."
    
    cat > "$install_script" <<EOF
#!/bin/bash
# Automatic Coturn TURN Server Installation Script
# Generated by Matrix Setup Tool for external server
# Target server: $external_turn_ip
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\${GREEN}═══════════════════════════════════════════════════════════════\${NC}"
echo -e "\${GREEN}          COTURN TURN SERVER INSTALLATION SCRIPT              \${NC}"
echo -e "\${GREEN}═══════════════════════════════════════════════════════════════\${NC}"
echo

# Check root privileges
if [[ \$EUID -ne 0 ]]; then
    echo -e "\${RED}Error: This script must be run as root\${NC}"
    echo "Usage: sudo \$0"
    exit 1
fi

# Update system
echo -e "\${BLUE}Updating system packages...\${NC}"
apt update && apt upgrade -y

# Install coturn
echo -e "\${BLUE}Installing coturn...\${NC}"
apt install -y coturn

# Create coturn configuration
echo -e "\${BLUE}Creating coturn configuration...\${NC}"
cat > /etc/turnserver.conf <<'TURN_EOF'
# Coturn TURN Server Configuration
# Generated for Matrix external TURN server
# Server IP: $external_turn_ip
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

# Basic settings
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
external-ip=$external_turn_ip

# Realm and authentication
realm=$TURN_DOMAIN
use-auth-secret
static-auth-secret=$turn_secret

# Logging
syslog

# Security settings
no-tcp-relay

# Block private IP addresses
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=192.0.0.0-192.0.0.255
denied-peer-ip=192.0.2.0-192.0.2.255
denied-peer-ip=192.88.99.0-192.88.99.255
denied-peer-ip=198.18.0.0-198.19.255.255
denied-peer-ip=198.51.100.0-198.51.100.255
denied-peer-ip=203.0.113.0-203.0.113.255
denied-peer-ip=240.0.0.0-255.255.255.255

# Performance and security limits
user-quota=12
total-quota=1200
max-bps=3000000

# Disable TLS by default (can be enabled later)
no-tls
no-dtls

# UDP relay port range
min-port=49152
max-port=65535

# Additional options
fingerprint
mobility
TURN_EOF

# Set permissions
chown root:root /etc/turnserver.conf
chmod 644 /etc/turnserver.conf

# Configure systemd service
echo -e "\${BLUE}Configuring systemd service...\${NC}"
systemctl enable coturn

# Create service optimization
mkdir -p /etc/systemd/system/coturn.service.d
cat > /etc/systemd/system/coturn.service.d/matrix-optimization.conf <<'SYSTEMD_EOF'
# Matrix TURN Server Optimizations
[Unit]
Description=Coturn TURN Server for Matrix (External)
After=network.target

[Service]
# Performance limits
LimitNOFILE=65536
LimitNPROC=32768

# Stability settings
Restart=always
RestartSec=5
TimeoutStartSec=30
TimeoutStopSec=30

# Security settings
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/log /var/run

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

# Reload systemd and start service
systemctl daemon-reload
systemctl start coturn

# Configure firewall (UFW)
if command -v ufw >/dev/null 2>&1; then
    echo -e "\${BLUE}Configuring firewall...\${NC}"
    ufw allow 3478/tcp comment "Coturn TURN TCP"
    ufw allow 3478/udp comment "Coturn TURN UDP"  
    ufw allow 5349/tcp comment "Coturn TURN TLS TCP"
    ufw allow 5349/udp comment "Coturn TURN TLS UDP"
    ufw allow 49152:65535/udp comment "Coturn UDP relay range"
    echo -e "\${GREEN}UFW rules added for coturn\${NC}"
else
    echo -e "\${YELLOW}UFW not found. Configure firewall manually:\${NC}"
    echo "  - Allow ports 3478/tcp, 3478/udp"
    echo "  - Allow ports 5349/tcp, 5349/udp" 
    echo "  - Allow ports 49152-65535/udp"
fi

# Verify installation
echo -e "\${BLUE}Verifying installation...\${NC}"
sleep 3

if systemctl is-active --quiet coturn; then
    echo -e "\${GREEN}✅ Coturn is running successfully!\${NC}"
else
    echo -e "\${RED}❌ Coturn failed to start\${NC}"
    echo "Check logs: journalctl -u coturn -n 20"
    exit 1
fi

# Check ports
if ss -tlnp | grep -q ":3478 "; then
    echo -e "\${GREEN}✅ Port 3478 is listening\${NC}"
else
    echo -e "\${YELLOW}⚠️  Port 3478 check failed\${NC}"
fi

if ss -tlnp | grep -q ":5349 "; then
    echo -e "\${GREEN}✅ Port 5349 is listening\${NC}"
else
    echo -e "\${YELLOW}⚠️  Port 5349 check failed\${NC}"
fi

echo
echo -e "\${GREEN}═══════════════════════════════════════════════════════════════\${NC}"
echo -e "\${GREEN}           COTURN INSTALLATION COMPLETED SUCCESSFULLY!         \${NC}"
echo -e "\${GREEN}═══════════════════════════════════════════════════════════════\${NC}"
echo
echo -e "\${BLUE}Server Information:\${NC}"
echo "  TURN Domain: $TURN_DOMAIN"
echo "  External IP: $external_turn_ip"
echo "  Ports: 3478, 5349, 49152-65535"
echo
echo -e "\${BLUE}Configuration Files:\${NC}"
echo "  Main config: /etc/turnserver.conf"
echo "  Service override: /etc/systemd/system/coturn.service.d/"
echo
echo -e "\${BLUE}Management Commands:\${NC}"
echo "  Status: systemctl status coturn"
echo "  Logs: journalctl -u coturn -f"
echo "  Restart: systemctl restart coturn"
echo
echo -e "\${YELLOW}Next Steps:\${NC}"
echo "1. Verify external connectivity to ports 3478, 5349"
echo "2. Test TURN server: https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/"
echo "3. Configure Matrix Synapse to use this TURN server"
echo
echo -e "\${GREEN}TURN server is ready for Matrix integration!\${NC}"
echo -e "\${BLUE}💡 VoIP звонки теперь будут работать даже за NAT/firewall${NC}"
    
    # Сохранение информации об установке
    set_config_value "$CONFIG_DIR/coturn.conf" "COTURN_INSTALLED" "true"
    set_config_value "$CONFIG_DIR/coturn.conf" "INSTALL_DATE" "$(date '+%Y-%m-%d %H:%M:%S')"
    set_config_value "$CONFIG_DIR/coturn.conf" "SERVER_TYPE" "$SERVER_TYPE"
    set_config_value "$CONFIG_DIR/coturn.conf" "TURN_DOMAIN" "$TURN_DOMAIN"
    set_config_value "$CONFIG_DIR/coturn.conf" "TURN_DEPLOYMENT_MODE" "local"
    
    return 0
}

# Функция главного меню модуля (обновленная версия)
coturn_menu() {
    while true; do
        show_menu "УПРАВЛЕНИЕ COTURN TURN SERVER" \
            "Установить coturn (автовыбор типа)" \
            "Установить локально (принудительно)" \
            "Настроить внешний TURN сервер" \
            "Настроить публичный TURN сервер" \
            "Показать статус" \
            "Управление службой" \
            "Тестировать функциональность" \
            "Диагностика сетевой доступности" \
            "Пересоздать конфигурацию" \
            "Удалить coturn" \
            "Назад в главное меню"
        
        local choice=$?
        
        case $choice in
            1) 
                # Стандартная установка с автовыбором
                main 
                ;;
            2) 
                # Принудительная локальная установка (пропускаем choose_turn_deployment)
                log "INFO" "Принудительная локальная установка coturn..."
                if check_coturn_requirements && get_turn_domain; then
                    install_coturn && create_coturn_config && configure_coturn_service && \
                    configure_coturn_firewall && start_and_verify_coturn && \
                    integrate_with_synapse && test_coturn_functionality
                fi
                ;;
            3)
                # Только настройка внешнего TURN сервера
                if check_coturn_requirements; then
                    configure_external_turn_server
                fi
                ;;
            4)
                # Только настройка публичного TURN сервера
                if check_coturn_requirements; then
                    configure_public_turn_server
                fi
                ;;
            5) 
                show_coturn_status 
                ;;
            6) 
                manage_coturn 
                ;;
            7) 
                test_coturn_functionality 
                ;;
            8)
                diagnose_turn_connectivity
                ;;
            9) 
                if ask_confirmation "Пересоздать конфигурацию coturn?"; then
                    create_coturn_config
                    if ask_confirmation "Перезапустить coturn для применения изменений?"; then
                        restart_service coturn
                    fi
                fi
                ;;
            10) 
                remove_coturn 
                ;;
            11) 
                break 
                ;;
            *) 
                log "ERROR" "Неверный выбор" 
                ;;
        esac
        
        if [ $choice -ne 11 ]; then
            echo
            read -p "Нажмите Enter для продолжения..."
        fi
    done
}

# Экспорт функций для использования в других скриптах
export -f main
export -f coturn_menu
export -f show_coturn_status
export -f manage_coturn
export -f test_coturn_functionality

# Проверка, вызван ли скрипт напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    coturn_menu
fi