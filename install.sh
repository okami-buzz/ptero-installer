#!/bin/bash
# 🚀 Vortex Hosting Manager
# Made by Abinash

clear
echo "=========================================="
echo "🚀 VORTEX HOSTING MANAGER"
echo "=========================================="
echo ""
echo "1) Panel Installation"
echo "2) Wings Installation"
echo "3) Panel Update"
echo "4) Uninstall Tools"
echo "5) Cloudflare Setup"
echo "6) System Information"
echo "0) Exit"
echo ""
read -p "Select an option [0-6]: " option

case $option in
    1)
        echo "Installing Pterodactyl Panel..."
        sudo apt update -y
        sudo apt install -y nginx mariadb-server redis-server unzip git curl tar
        cd /var/www/
        mkdir -p pterodactyl
        cd pterodactyl
        curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
        tar -xzvf panel.tar.gz
        cp .env.example .env
        php artisan key:generate --force
        ;;
    2)
        echo "Installing Wings..."
        curl -sSL https://get.docker.com/ | CHANNEL=stable bash
        curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
        chmod +x /usr/local/bin/wings
        ;;
    3)
        echo "Updating Panel..."
        cd /var/www/pterodactyl
        php artisan down
        curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
        tar -xzvf panel.tar.gz
        php artisan migrate --seed --force
        php artisan up
        ;;
    4)
        echo "Removing panel and wings..."
        sudo rm -rf /var/www/pterodactyl
        sudo rm -rf /etc/pterodactyl
        ;;
    5)
        echo "Setting up Cloudflare Tunnel (optional)..."
        ;;
    6)
        echo "System Information:"
        uname -a
        free -h
        df -h
        ;;
    0)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid option!"
        ;;
esac
