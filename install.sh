#!/bin/bash

# ============================================
# gotelegram — MTProto Proxy Manager
# Ubuntu 24.04 / Docker
# ============================================

PORT=2443
CONTAINER_NAME="mtproto-proxy"
SECRET_FILE="/etc/mtproto_secret"
IMAGE="telegrammessenger/proxy:latest"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

get_server_ip() {
    curl -s https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'
}

get_secret() {
    if [ -f "$SECRET_FILE" ]; then
        cat "$SECRET_FILE"
    else
        echo ""
    fi
}

generate_secret() {
    openssl rand -hex 16
}

print_header() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════╗"
    echo "║        gotelegram — MTProto        ║"
    echo "╚════════════════════════════════════╝"
    echo -e "${NC}"
}

show_status() {
    echo -e "${CYAN}[ Статус ]${NC}"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "Контейнер: ${GREEN}работает${NC}"
        docker ps --filter "name=${CONTAINER_NAME}" --format "Запущен: {{.RunningFor}}"
    else
        echo -e "Контейнер: ${RED}не запущен${NC}"
    fi

    SECRET=$(get_secret)
    if [ -n "$SECRET" ]; then
        IP=$(get_server_ip)
        echo ""
        echo -e "Порт: ${PORT}"
        echo -e "Секрет: ${SECRET}"
        echo -e "Ссылка подключения:"
        echo -e "${GREEN}tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}${NC}"
    fi
    echo ""
}

restart_proxy() {
    echo -e "${YELLOW}Перезапускаю контейнер...${NC}"
    docker restart "$CONTAINER_NAME" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Перезапущен успешно.${NC}"
    else
        echo -e "${RED}Ошибка при перезапуске.${NC}"
    fi
    echo ""
}

show_link() {
    SECRET=$(get_secret)
    IP=$(get_server_ip)
    if [ -z "$SECRET" ]; then
        echo -e "${RED}Секрет не найден. Возможно прокси не установлен.${NC}"
    else
        echo -e "${CYAN}[ Ссылка подключения ]${NC}"
        echo -e "${GREEN}tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}${NC}"
        echo ""
        echo "Эту ссылку можно открыть в Telegram — прокси добавится автоматически."
    fi
    echo ""
}

update_proxy() {
    echo -e "${YELLOW}Обновляю образ...${NC}"
    docker pull "$IMAGE"
    docker stop "$CONTAINER_NAME" 2>/dev/null
    docker rm "$CONTAINER_NAME" 2>/dev/null
    SECRET=$(get_secret)
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart always \
        -p "${PORT}:443" \
        -e "SECRET=${SECRET}" \
        "$IMAGE"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Обновлено и запущено.${NC}"
    else
        echo -e "${RED}Ошибка при обновлении.${NC}"
    fi
    echo ""
}

remove_proxy() {
    echo -e "${RED}Удаляю MTProto прокси...${NC}"
    read -p "Вы уверены? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        docker stop "$CONTAINER_NAME" 2>/dev/null
        docker rm "$CONTAINER_NAME" 2>/dev/null
        docker rmi "$IMAGE" 2>/dev/null
        rm -f "$SECRET_FILE"
        echo -e "${GREEN}Удалено.${NC}"
    else
        echo "Отменено."
    fi
    echo ""
}

install_proxy() {
    echo -e "${CYAN}[ Установка MTProto прокси ]${NC}"

    # Проверка Docker
    if ! command -v docker &>/dev/null; then
        echo "Docker не найден. Устанавливаю..."
        apt-get update -q
        apt-get install -y docker.io
        systemctl enable docker
        systemctl start docker
    else
        echo -e "Docker: ${GREEN}найден${NC}"
    fi

    # Генерация секрета
    SECRET=$(generate_secret)
    echo "$SECRET" > "$SECRET_FILE"
    chmod 600 "$SECRET_FILE"
    echo -e "Секрет сгенерирован: ${GREEN}${SECRET}${NC}"

    # Запуск контейнера
    docker pull "$IMAGE"
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart always \
        -p "${PORT}:443" \
        -e "SECRET=${SECRET}" \
        "$IMAGE"

    if [ $? -eq 0 ]; then
        IP=$(get_server_ip)
        echo ""
        echo -e "${GREEN}MTProto прокси установлен и запущен!${NC}"
        echo ""
        echo -e "Ссылка подключения:"
        echo -e "${GREEN}tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}${NC}"
    else
        echo -e "${RED}Ошибка при запуске контейнера.${NC}"
    fi
    echo ""
}

main_menu() {
    while true; do
        print_header
        echo "  1. Статус"
        echo "  2. Перезапустить"
        echo "  3. Показать ссылку подключения"
        echo "  4. Обновить"
        echo "  5. Удалить"
        echo "  0. Выход"
        echo ""
        read -p "Выберите пункт: " choice
        echo ""

        case $choice in
            1) show_status ;;
            2) restart_proxy ;;
            3) show_link ;;
            4) update_proxy ;;
            5) remove_proxy ;;
            0) echo "Выход."; exit 0 ;;
            *) echo -e "${RED}Неверный выбор.${NC}"; echo "" ;;
        esac
    done
}

# ============================================
# Точка входа
# ============================================

# Если запущен впервые и контейнер не существует — установка
if ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$" && [ "$1" != "menu" ]; then
    print_header
    echo -e "${YELLOW}MTProto прокси не обнаружен. Запускаю установку...${NC}"
    echo ""
    install_proxy
fi

main_menu
