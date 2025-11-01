#!/bin/bash
# 🧠 Ptero Installation By Okami
# Author: Abinash (Okami)
# Description: Automated Pterodactyl Panel + Wings installer

clear
echo -e "\e[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e " 🚀  \e[1;35mPTERO INSTALLATION BY OKAMI\e[0m"
echo -e "      Made with ❤️  by Abinash (Okami)"
echo -e "\e[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo ""
echo -e " [1] Install Pterodactyl Panel"
echo -e " [2] Install Wings"
echo -e " [3] Update Panel"
echo -e " [4] Uninstall Panel/Wings"
echo -e " [5] Setup Cloudflare Tunnel"
echo -e " [6] View System Info"
echo -e " [0] Exit"
echo ""
read -p "👉 Select an option [0-6]: " option
echo ""

case $option in
# ==============================
1)
    echo -e "\e[32m🧩 Starting Pterodactyl Panel Installation...\e[0m"
    sleep 2
    apt update -y && apt upgrade -y
    apt install -y nginx mariadb-server redis-server unzip git curl tar composer \
      php8.1 php8.1-{cli,gd,xml,mbstring,zip,bcmath,sqlite3,curl,intl,pgsql,common,fpm}

    cd /var/www/
    mkdir -p pterodactyl && cd pterodactyl
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz && chmod -R 755 storage/* bootstrap/cache
    cp .env.example .env

    php artisan key:generate --force
    read -p "🌐 Domain (e.g., panel.example.com): " DOMAIN
    read -p "📧 Admin Email: " EMAIL
    read -p "👤 Admin Username: " USERNAME
    read -p "🧠 Admin Name: " NAME
    read -p "🔑 Admin Password: " PASSWORD

    echo "⚙️ Configuring Database..."
    mysql -u root -e "CREATE DATABASE panel;"
    mysql -u root -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$PASSWORD';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1';"
    mysql -u root -e "FLUSH PRIVILEGES;"

    sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|g" .env
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=panel|g" .env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=pterodactyl|g" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$PASSWORD|g" .env

    php artisan migrate --seed --force
    php artisan p:user:make --email=$EMAIL --username=$USERNAME --name="$NAME" --password=$PASSWORD --admin=1

    echo ""
    echo -e "\e[32m✅ Installation Complete!\e[0m"
    echo "🌍 URL: https://$DOMAIN"
    echo "👤 Admin: $USERNAME ($EMAIL)"
    echo "🔒 Password: $PASSWORD"
    echo ""
    echo -e "\e[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "  🎉  Ptero Installation By Okami - Done!"
    echo -e "\e[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    ;;
# ==============================
2)
    echo -e "\e[33m⚙️ Installing Wings...\e[0m"
    apt install -y docker.io
    systemctl enable --now docker
    curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x /usr/local/bin/wings
    echo -e "\e[32m✅ Wings installation successful!\e[0m"
    ;;
# ==============================
3)
    echo -e "\e[34m🪄 Updating Pterodactyl Panel...\e[0m"
    cd /var/www/pterodactyl
    php artisan down
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    composer install --no-dev --optimize-autoloader
    php artisan migrate --seed --force
    php artisan up
    echo -e "\e[32m✅ Panel updated successfully!\e[0m"
    ;;
# ==============================
4)
    echo "⚠️ This will remove panel and wings. Continue?"
    read -p "(yes/no): " confirm
    if [[ "$confirm" == "yes" ]]; then
        systemctl stop wings 2>/dev/null
        rm -rf /var/www/pterodactyl /etc/pterodactyl /usr/local/bin/wings
        echo -e "\e[31m🧹 Uninstalled completely.\e[0m"
    else
        echo "❌ Cancelled."
    fi
    ;;
# ==============================
5)
    echo -e "\e[35m☁️ Installing Cloudflare Tunnel...\e[0m"
    curl -fsSL https://pkg.cloudflare.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloudflare.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloudflare.gpg] https://pkg.cloudflare.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare.list
    apt update && apt install -y cloudflared
    read -p "🌐 Enter Cloudflare Tunnel Token: " token
    cloudflared service install $token
    echo -e "\e[32m✅ Cloudflare Tunnel configured successfully!\e[0m"
    ;;
# ==============================
6)
    echo -e "\e[36m🧠 System Information:\e[0m"
    uname -a
    free -h
    df -h
    ;;
# ==============================
0)
    echo -e "\e[31m👋 Exiting Ptero Installation By Okami...\e[0m"
    exit 0
    ;;
*)
    echo -e "\e[31m❌ Invalid choice!\e[0m"
    ;;
esac
