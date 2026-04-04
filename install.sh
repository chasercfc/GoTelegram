#!/bin/bash

# ============================================
# gotelegram — MTProto Proxy Manager
# Ubuntu 24.04 / Docker / mtg v2
# ============================================

CONTAINER_NAME="mtproto-proxy"
SECRET_FILE="/etc/mtproto_secret"
DOMAIN_FILE="/etc/mtproto_domain"
PORT_FILE="/etc/mtproto_port"
IMAGE="nineseconds/mtg:2"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

get_server_ip() {
    curl -s https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'
}

get_secret() {
    [ -f "$SECRET_FILE" ] && cat "$SECRET_FILE" || echo ""
}

get_domain() {
    [ -f "$DOMAIN_FILE" ] && cat "$DOMAIN_FILE" || echo "google.com"
}

get_port() {
    [ -f "$PORT_FILE" ] && cat "$PORT_FILE" || echo "2443"
}

generate_secret() {
    local domain=$1
    local rand=$(openssl rand -hex 16)
    local domain_hex=$(echo -n "$domain" | xxd -p | tr -d '\n')
    echo "ee${rand}${domain_hex}"
}

show_qr() {
    local data=$1
    if command -v qrencode &>/dev/null; then
        echo "$data" | qrencode -t UTF8 -o -
    else
        echo -e "${YELLOW}(qrencode не установлен)${NC}"
    fi
}

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║      gotelegram — MTProto Proxy        ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

choose_domain() {
    echo -e "${CYAN}Выберите домен для маскировки (Fake TLS)${NC}"
    echo ""
    echo "  1)  google.com          2)  wikipedia.org"
    echo "  3)  habr.com            4)  github.com"
    echo "  5)  coursera.org        6)  udemy.com"
    echo "  7)  medium.com          8)  stackoverflow.com"
    echo "  9)  bbc.com            10)  cnn.com"
    echo " 11)  reuters.com        12)  nytimes.com"
    echo " 13)  lenta.ru           14)  rbc.ru"
    echo " 15)  ria.ru             16)  kommersant.ru"
    echo " 17)  stepik.org         18)  duolingo.com"
    echo " 19)  khanacademy.org    20)  ted.com"
    echo ""
    echo " 21)  Ввести свой домен"
    echo ""
    read -p "Ваш выбор [1-21]: " choice

    case $choice in
        1)  echo "google.com" ;;
        2)  echo "wikipedia.org" ;;
        3)  echo "habr.com" ;;
        4)  echo "github.com" ;;
        5)  echo "coursera.org" ;;
        6)  echo "udemy.com" ;;
        7)  echo "medium.com" ;;
        8)  echo "stackoverflow.com" ;;
        9)  echo "bbc.com" ;;
        10) echo "cnn.com" ;;
        11) echo "reuters.com" ;;
        12) echo "nytimes.com" ;;
        13) echo "lenta.ru" ;;
        14) echo "rbc.ru" ;;
        15) echo "ria.ru" ;;
        16) echo "kommersant.ru" ;;
        17) echo "stepik.org" ;;
        18) echo "duolingo.com" ;;
        19) echo "khanacademy.org" ;;
        20) echo "ted.com" ;;
        21)
            read -p "Введите домен: " custom_domain
            echo "$custom_domain"
            ;;
        *)  echo "google.com" ;;
    esac
}

choose_port() {
    echo ""
    echo -e "${CYAN}Выберите порт${NC}"
    echo ""
    echo "  1)  443   (Рекомендуется)"
    echo "  2)  8443"
    echo "  3)  2443"
    echo "  4)  Свой порт"
    echo ""
    read -p "Выбор: " choice

    case $choice in
        1) echo "443" ;;
        2) echo "8443" ;;
        3) echo "2443" ;;
        4)
            read -p "Введите порт: " custom_port
            echo "$custom_port"
            ;;
        *) echo "443" ;;
    esac
}

show_connection_data() {
    local SECRET=$(get_secret)
    local PORT=$(get_port)
    local IP=$(get_server_ip)

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗"
    echo -e "║          ДАННЫЕ ПОДКЛЮЧЕНИЯ            ║"
    echo -e "╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  IP:     ${RED}${IP}${NC}"
    echo -e "  Port:   ${GREEN}${PORT}${NC}"
    echo -e "  Secret: ${GREEN}${SECRET}${NC}"
    echo ""
    echo -e "  Ссылка:"
    echo -e "  ${GREEN}tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}${NC}"
    echo ""
    echo "  QR-код для подключения:"
    echo ""
    show_qr "tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}"
    echo ""
}

show_status() {
    echo -e "${CYAN}[ Статус ]${NC}"
    echo ""
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "  Прокси: ${GREEN}работает${NC}"
        docker ps --filter "name=${CONTAINER_NAME}" --format "  Запущен: {{.RunningFor}}"
        echo -e "  Домен: $(get_domain)"
        echo -e "  Порт: $(get_port)"
    else
        echo -e "  Прокси: ${RED}не запущен${NC}"
    fi
    echo ""
    read -p "Нажмите Enter..."
}

restart_proxy() {
    echo -e "${YELLOW}Перезапускаю...${NC}"
    docker restart "$CONTAINER_NAME" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Перезапущен успешно.${NC}"
    else
        echo -e "${RED}Ошибка.${NC}"
    fi
    echo ""
    read -p "Нажмите Enter..."
}

remove_proxy() {
    print_header
    echo -e "${CYAN}Удаление контейнера MTProxy${NC}"
    echo ""
    echo "  Будет удалено:"
    echo "  • Контейнер ${CONTAINER_NAME}"
    echo "  • Файлы настроек"
    echo "  • Скрипт /usr/local/bin/gotelegram"
    echo ""
    echo "  Docker и другие контейнеры НЕ будут затронуты."
    echo ""
    read -p "Вы уверены? (Y/N): " confirm
    if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
        docker stop "$CONTAINER_NAME" 2>/dev/null
        docker rm "$CONTAINER_NAME" 2>/dev/null
        rm -f "$SECRET_FILE" "$DOMAIN_FILE" "$PORT_FILE"
        rm -f /usr/local/bin/gotelegram
        echo ""
        echo -e "${GREEN}Удалено успешно.${NC}"
        exit 0
    else
        echo "Отменено."
    fi
    echo ""
    read -p "Нажмите Enter..."
}

install_proxy() {
    print_header
    echo -e "${CYAN}[ Установка MTProto прокси ]${NC}"
    echo ""

    if ! command -v docker &>/dev/null; then
        echo "  Docker не найден. Устанавливаю..."
        apt-get update -q
        apt-get install -y docker.io
        systemctl enable docker
        systemctl start docker
    else
        echo -e "  Docker: ${GREEN}найден${NC}"
    fi

    if ! command -v qrencode &>/dev/null; then
        echo "  Устанавливаю qrencode..."
        apt-get install -y qrencode -q
    fi

    echo ""
    DOMAIN=$(choose_domain)
    echo "$DOMAIN" > "$DOMAIN_FILE"
    echo -e "  Домен: ${GREEN}${DOMAIN}${NC}"

    PORT=$(choose_port)
    echo "$PORT" > "$PORT_FILE"
    echo -e "  Порт: ${GREEN}${PORT}${NC}"

    echo ""
    echo "  Генерирую секрет..."
    SECRET=$(generate_secret "$DOMAIN")
    echo "$SECRET" > "$SECRET_FILE"
    chmod 600 "$SECRET_FILE"
    echo -e "  Секрет: ${GREEN}${SECRET}${NC}"

    docker stop "$CONTAINER_NAME" 2>/dev/null
    docker rm "$CONTAINER_NAME" 2>/dev/null

    echo ""
    echo "  Загрузка образа mtg..."
    docker pull "$IMAGE"

    echo ""
    echo "  Запуск..."
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart always \
        -p "${PORT}:${PORT}" \
        "$IMAGE" \
        simple-run \
        -n 1.1.1.1 \
        -i prefer-ipv4 \
        "0.0.0.0:${PORT}" \
        "$SECRET"

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}  Прокси установлен и запущен!${NC}"
        show_connection_data
    else
        echo -e "${RED}  Ошибка при запуске.${NC}"
    fi

    read -p "Нажмите Enter для возврата в меню..."
}

main_menu() {
    while true; do
        print_header

        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
            echo -e "  Прокси: ${GREEN}работает${NC}"
        else
            echo -e "  Прокси: ${RED}не запущен${NC}"
        fi
        echo ""

        echo "  1)  Установить / Обновить прокси"
        echo "  2)  Показать данные подключения"
        echo "  3)  Перезапустить прокси"
        echo "  4)  Статус"
        echo "  5)  Логи прокси"
        echo "  6)  Удалить"
        echo "  0)  Выход"
        echo ""
        read -p "Пункт: " choice
        echo ""

        case $choice in
            1) install_proxy ;;
            2) show_connection_data; read -p "Нажмите Enter..." ;;
            3) restart_proxy ;;
            4) show_status ;;
            5) docker logs --tail 30 "$CONTAINER_NAME" 2>/dev/null; echo ""; read -p "Нажмите Enter..." ;;
            6) remove_proxy ;;
            0) echo "Выход."; exit 0 ;;
            *) echo -e "${RED}Неверный выбор.${NC}"; sleep 1 ;;
        esac
    done
}

# ============================================
# Точка входа
# ============================================

if ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    print_header
    echo -e "${YELLOW}  MTProto прокси не обнаружен. Запускаю установку...${NC}"
    echo ""
    install_proxy
fi

main_menu
