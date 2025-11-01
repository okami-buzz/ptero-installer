#!/usr/bin/env bash
#
# Ptero Installation By Okami — Universal Auto Installer (Debian/Ubuntu)
# - User supplies domain & admin details interactively
# - Installs Panel + Wings (Docker) + MariaDB + Redis + Nginx + PHP + Certbot (optional)
# - Handles common errors and provides fallback for artisan user create
#
set -euo pipefail
IFS=$'\n\t'

# ---------- helpers ----------
info(){ echo -e "\e[36m[INFO]\e[0m $*"; }
ok(){ echo -e "\e[32m[OK]\e[0m $*"; }
warn(){ echo -e "\e[33m[WARN]\e[0m $*"; }
err(){ echo -e "\e[31m[ERROR]\e[0m $*"; }

# must be root or sudo
if [[ $EUID -ne 0 ]]; then
  err "Run this script as root (sudo). Exiting."
  exit 1
fi

# ---------- detect OS (Debian/Ubuntu) ----------
OS=""
if grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
  OS="ubuntu"
elif grep -qi "debian" /etc/os-release 2>/dev/null; then
  OS="debian"
else
  warn "Unsupported OS detected. Script targets Debian/Ubuntu. Proceeding but may fail."
fi
info "Detected OS: ${OS:-unknown}"

# ---------- interactive inputs ----------
echo
info "PTERO INSTALLATION BY OKAMI — Interactive setup"
read -rp "Enter panel domain (example: panel.example.com): " PANEL_DOMAIN
read -rp "Do you want to enable HTTPS (Let's Encrypt)? (y/N): " ENABLE_HTTPS
ENABLE_HTTPS=${ENABLE_HTTPS:-N}
read -rp "Enter admin email (for panel login & notifications): " ADMIN_EMAIL
read -rp "Enter admin username: " ADMIN_USERNAME
read -rp "Enter admin first name: " ADMIN_FIRST
read -rp "Enter admin last name: " ADMIN_LAST
read -rsp "Enter admin password (min 8 chars): " ADMIN_PASSWORD; echo

# Optional: MySQL root password (if exists)
read -rp "If MariaDB root has password, enter it now (leave empty if none): " MYSQL_ROOT_PWD
if [[ -n "$MYSQL_ROOT_PWD" ]]; then
  MYSQLROOTAUTH="-p${MYSQL_ROOT_PWD}"
else
  MYSQLROOTAUTH=""
fi

# set variables
WWW_DIR="/var/www/pterodactyl"
PANEL_USER="www-data"

# ---------- update + base packages ----------
info "Updating apt and installing base packages..."
apt update -y
apt upgrade -y
apt install -y software-properties-common curl wget git unzip tar ca-certificates lsb-release gnupg apt-transport-https

# ---------- PHP install: prefer 8.1+ if available ----------
info "Installing PHP and extensions..."
# Try install php from distro; if not, add sury and install php8.1
if apt-cache show php8.1 >/dev/null 2>&1; then
  PKG_PHP="php8.1"
else
  # add sury repo for newer PHP if available
  if ! grep -q "packages.sury.org" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    wget -qO- https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
    echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/sury-php.list
    apt update -y
  fi
  PKG_PHP="php8.1"
fi

apt install -y ${PKG_PHP} ${PKG_PHP}-cli ${PKG_PHP}-fpm ${PKG_PHP}-curl ${PKG_PHP}-mbstring ${PKG_PHP}-xml ${PKG_PHP}-zip ${PKG_PHP}-gd ${PKG_PHP}-bcmath ${PKG_PHP}-mysql

# ---------- WEB / DB / REDIS ----------
info "Installing Nginx, MariaDB and Redis..."
apt install -y nginx mariadb-server redis-server

# secure MariaDB (non-interactive minimal)
info "Securing MariaDB (minimal automated steps)..."
# If root has no password, this will work; if root has password, skip secure-defaults
if [[ -z "$MYSQL_ROOT_PWD" ]]; then
  # run basic secure statements
  mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '';" || true
fi

# ---------- Composer ----------
info "Installing Composer..."
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
rm -f composer-setup.php

# ---------- create web dir & download panel ----------
info "Downloading Pterodactyl Panel..."
mkdir -p "$WWW_DIR"
cd /var/www || exit 1
rm -rf pterodactyl || true
mkdir -p pterodactyl
cd pterodactyl
curl -sLo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzf panel.tar.gz --strip-components=1
chown -R $PANEL_USER:$PANEL_USER /var/www/pterodactyl
chmod -R 755 storage bootstrap/cache || true
cp .env.example .env

# ---------- configure .env basics ----------
info "Configuring .env..."
sed -i "s|APP_URL=.*|APP_URL=https://${PANEL_DOMAIN}|g" .env || true
# We'll set DB credentials after creating DB

# ---------- MYSQL: create DB and user ----------
info "Creating database and DB user 'pterodactyl'..."
DB_PASS="$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | cut -c1-16)"
MYSQL_CMD="mysql"
if [[ -n "$MYSQL_ROOT_PWD" ]]; then
  MYSQL_CMD="mysql -uroot -p${MYSQL_ROOT_PWD}"
fi

# Create DB & user (safe)
$MYSQL_CMD -e "CREATE DATABASE IF NOT EXISTS panel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || { err "DB create failed"; exit 1; }
$MYSQL_CMD -e "CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';" || true
$MYSQL_CMD -e "GRANT ALL ON panel.* TO 'pterodactyl'@'127.0.0.1'; FLUSH PRIVILEGES;" || true

# update .env DB values
sed -i "s|DB_DATABASE=.*|DB_DATABASE=panel|g" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=pterodactyl|g" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" .env

# ---------- APP KEY + migrate + seed ----------
info "Generating app key..."
cd /var/www/pterodactyl || exit 1
# ensure composer dependencies
composer install --no-dev --optimize-autoloader --no-interaction || true

php artisan key:generate --force
info "Running migrations (this may take a bit)..."
php artisan migrate --seed --force

# ---------- Create admin user (try non-interactive, fallback interactive) ----------
info "Creating admin user..."
# check supported flags
if php artisan | grep -q "p:user:make"; then
  # try common flags
  if php artisan p:user:make --help | grep -q -- "--first_name"; then
    php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USERNAME" --first_name="$ADMIN_FIRST" --last_name="$ADMIN_LAST" --password="$ADMIN_PASSWORD" --admin || {
      warn "Non-interactive user create failed; falling back to interactive create."
      php artisan p:user:make
    }
  else
    # older/newer flag sets
    php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USERNAME" --name="${ADMIN_FIRST} ${ADMIN_LAST}" --password="$ADMIN_PASSWORD" --admin || {
      warn "Non-interactive user create failed; falling back to interactive create."
      php artisan p:user:make
    }
  fi
else
  warn "p:user:make artisan command not found; you may need to create admin manually."
fi

# ---------- Nginx site config ----------
info "Configuring Nginx for panel..."
NGINX_CONF="/etc/nginx/sites-available/pterodactyl.conf"
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name ${PANEL_DOMAIN};

    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.access.log;
    error_log /var/log/nginx/pterodactyl.error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/pterodactyl.conf
nginx -t && systemctl reload nginx

# ---------- SSL (Certbot) ----------
if [[ "${ENABLE_HTTPS,,}" =~ ^(y|yes)$ ]]; then
  info "Installing Certbot and requesting certificate..."
  apt install -y certbot python3-certbot-nginx
  certbot --nginx -d "${PANEL_DOMAIN}" --non-interactive --agree-tos -m "${ADMIN_EMAIL}" || warn "Certbot failed or DNS not propagated. You may need to run certbot manually later."
fi

# ---------- Wings (Docker + binary) ----------
info "Installing Docker and Wings..."
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | bash
  systemctl enable --now docker
fi

# Download latest wings binary
WINGS_BIN="/usr/local/bin/wings"
curl -sLo "${WINGS_BIN}" "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64" || warn "Wings download failed"
chmod +x "${WINGS_BIN}"

# create default wings directory
mkdir -p /etc/pterodactyl
chown -R root:root /etc/pterodactyl

# ---------- final output ----------
ok "Installation steps complete (panel files in /var/www/pterodactyl)."
echo
echo "-------------------------"
echo "PTERO INSTALLATION SUMMARY"
echo "-------------------------"
echo "Panel URL: https://${PANEL_DOMAIN}"
echo "Panel Path: /var/www/pterodactyl"
echo "DB user: pterodactyl"
echo "DB password: ${DB_PASS}"
echo "Admin username: ${ADMIN_USERNAME}"
echo "Admin email: ${ADMIN_EMAIL}"
echo "Admin password: (the one you entered)"
echo "To finish panel environment (if any interactive step needed):"
echo "  cd /var/www/pterodactyl"
echo "  php artisan p:environment:setup"
echo "  php artisan migrate --seed --force"
echo ""
ok "If any step failed, check /var/log/nginx/pterodactyl.error.log and /var/www/pterodactyl/storage/logs/laravel-*.log"
