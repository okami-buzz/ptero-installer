#!/bin/bash
# ==========================================
# 🚀 Ptero Installation by Okami
# Made by Abinash (Okami)
# ==========================================

clear
echo "=========================================="
echo "🚀 PTERO INSTALLATION BY OKAMI"
echo "=========================================="
echo ""
echo "1) Install Panel (Auto SSL + Admin Creation)"
echo "2) Install Wings"
echo "3) Install Cloudflare"
echo "4) Update Panel"
echo "5) Uninstall Panel"
echo "6) Uninstall Wings"
echo "7) System Information"
echo "0) Exit"
echo ""
read -p "Select an option [0-7]: " option

case $option in
1)
    echo "=========================================="
    echo "🔧 Starting Pterodactyl Panel Installation"
    echo "=========================================="
    sleep 2

    sudo apt update -y && sudo apt upgrade -y
    sudo apt install -y curl apt-transport-https ca-certificates gnupg lsb-release unzip git tar redis-server nginx mariadb-server software-properties-common

    # PHP setup
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
    sudo apt update -y
    sudo apt install -y php8.1 php8.1-{cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,common}

    cd /var/www/
    mkdir -p pterodactyl
    cd pterodactyl

    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache
    cp .env.example .env

    echo ""
    echo "💡 Enter the details below for your panel setup:"
    read -p "Panel URL (example: panel.yourdomain.com): " panel_url
    read -p "Admin Email: " admin_email
    read -p "Admin Username: " admin_user
    read -p "Admin First Name: " first_name
    read -p "Admin Last Name: " last_name
    read -s -p "Admin Password: " admin_pass
    echo ""

    php artisan key:generate --force
    php artisan p:environment:setup <<EOF
https
$panel_url
us
EOF

    php artisan p:environment:database
    php artisan migrate --seed --force
    php artisan p:user:make <<EOF
$admin_email
$admin_user
$first_name
$last_name
$admin_pass
1
EOF

    chown -R www-data:www-data /var/www/pterodactyl/*
    sudo systemctl enable --now redis-server

    # Nginx config
    cat > /etc/nginx/sites-available/pterodactyl.conf <<NGINX
server {
    listen 80;
    server_name $panel_url;

    root /var/www/pterodactyl/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX

    ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
    nginx -t && systemctl restart nginx

    echo "✅ Installing Certbot (SSL)"
    apt install -y certbot python3-certbot-nginx
    certbot --nginx -d $panel_url --non-interactive --agree-tos -m $admin_email

    echo ""
    echo "🎉 Panel Installed Successfully!"
    echo "🔗 Visit: https://$panel_url"
    echo "👤 Admin Login: $admin_user | 📧 $admin_email"
    ;;
2)
    echo "=========================================="
    echo "🐦 Installing Pterodactyl Wings"
    echo "=========================================="
    sleep 2

    curl -sSL https://get.docker.com/ | CHANNEL=stable bash
    systemctl enable --now docker

    curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x /usr/local/bin/wings

    echo "✅ Wings installed! Configure it from the panel's node settings."
    ;;
3)
    echo "=========================================="
    echo "☁️ Installing Cloudflare Tunnel"
    echo "=========================================="
    sleep 2
    curl -fsSL https://pkg.cloudflare.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloudflare-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-archive-keyring.gpg] https://pkg.cloudflare.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare.list
    sudo apt update && sudo apt install -y cloudflared
    echo "✅ Cloudflare installed successfully!"
    ;;
4)
    echo "=========================================="
    echo "🔁 Updating Panel..."
    echo "=========================================="
    cd /var/www/pterodactyl
    php artisan down
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    php artisan migrate --seed --force
    php artisan up
    echo "✅ Panel updated successfully!"
    ;;
5)
    echo "🗑️ Removing Pterodactyl Panel..."
    sudo rm -rf /var/www/pterodactyl /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    systemctl restart nginx
    echo "✅ Panel removed successfully!"
    ;;
6)
    echo "🗑️ Removing Wings..."
    sudo systemctl stop wings
    sudo rm -f /usr/local/bin/wings
    echo "✅ Wings removed successfully!"
    ;;
7)
    echo "=========================================="
    echo "💻 System Information"
    echo "=========================================="
    uname -a
    free -h
    df -h
    ;;
0)
    echo "👋 Exiting..."
    exit 0
    ;;
*)
    echo "❌ Invalid option!"
    ;;
esac
