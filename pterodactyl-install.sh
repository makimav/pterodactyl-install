#!/bin/bash

clear

GREEN_TEXT="\033[0;32m"
GREEN="\033[0;42m"
RED="\033[0;41m"
NC="\033[0m"
type=$1
printf "${GREEN_TEXT}[*]${NC} Starting script..."

if [ -z "$type" ]; then
  printf " ${RED} FAIL ${NC}\n"
  printf "Please specify type of installation.\n"
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  printf " ${RED} FAIL ${NC}\n"
  printf "Please run the script as root.\n"
  exit
fi

sleep 1
printf " ${GREEN} DONE ${NC}\n"

if [ "$type" == "panel" ] || [ "$type" == "full" ]; then
  printf "${GREEN_TEXT}[*]${NC} Opening ports..."
  iptables --flush
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Installing updates..."
  apt -qq update 1>/dev/null 2>/dev/null
  apt -qq -y upgrade 1>/dev/null 2>/dev/null
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Adding extra repositories..."
  apt -qq -y install software-properties-common curl jq apt-transport-https ca-certificates gnupg 1>/dev/null 2>/dev/null
  LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php 1>/dev/null 2>/dev/null
  rm -f /usr/share/keyrings/redis-archive-keyring.gpg
  curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -q -o /usr/share/keyrings/redis-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list 1>/dev/null 2>/dev/null
  curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash 1>/dev/null 2>/dev/null
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Installing updates again..."
  apt -qq -y upgrade 1>/dev/null 2>/dev/null
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Installing required software..."
  apt -qq -y install php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server 1>/dev/null 2>/dev/null
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Installing composer..."
  curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer 1>/dev/null 2>/dev/null
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Downloading Pterodactyl panel..."
  mkdir -p /var/www/pterodactyl
  cd /var/www/pterodactyl
  curl -s -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
  tar -xzvf panel.tar.gz 1>/dev/null 2>/dev/null
  chmod -R 755 storage/* bootstrap/cache/
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Configuring database..."
  mysql -B -s -u root -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY 'admin';" 1>/dev/null 2>/dev/null
  mysql -B -s -u root -e "CREATE DATABASE panel;" 1>/dev/null 2>/dev/null
  mysql -B -s -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;" 1>/dev/null 2>/dev/null
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Installing packages..."
  cp .env.example .env
  COMPOSER_ALLOW_SUPERUSER=1 composer install -q --no-dev --optimize-autoloader
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Generating encryption key..."
  php artisan key:generate --force -q -n
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Getting server public ip..."
  ip=$(curl -s ipinfo.io | jq -r ".ip")
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Configuring Pterodactyl panel..."
  php artisan p:environment:setup --author="admin@admin.com" --url="http://$ip" --timezone="UTC" --cache="redis" --session="redis" --queue="redis" --redis-host="localhost" --redis-pass="null" --redis-port="6379" --settings-ui=true --telemetry=false -q -n
  php artisan p:environment:database --host="127.0.0.1" --port="3306" --database="panel" --username="pterodactyl" --password="admin" -q -n
  php artisan p:environment:mail --driver=sendmail --email="no-reply@example.com" --from "Hosting" -q -n
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Migrating database..."
  php artisan migrate --seed --force -q -n
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Creating admin user..."
  php artisan p:user:make --email="admin@admin.com" --username="admin" --name-first="admin" --name-last="admin" --password="admin" --admin=1 -q -n
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Adding jobs..."
  chown -R www-data:www-data /var/www/pterodactyl/*
  echo -e "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1" | crontab -
  cat >/etc/systemd/system/pteroq.service <<EOF
# Pterodactyl Queue Worker File
# ----------------------------------

[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
# On some systems the user and group might be different.
# Some systems use \`apache\` or \`nginx\` as the user and group.
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
  systemctl enable --now -q redis-server
  systemctl enable --now -q pteroq.service
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Configuring nginx..."
  rm /etc/nginx/sites-enabled/default
  cat >/etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    # Replace the example <domain> with your domain name or IP address
    listen 80;
    server_name $ip;

    root /var/www/pterodactyl/public;
    index index.html index.htm index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
  ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
  systemctl restart nginx
  printf " ${GREEN} DONE ${NC}\n"
  printf "Pterodactyl panel was installed successfuly!\n"
fi

if [ "$type" == "node" ] || [ "$type" == "full" ]; then
  printf "${GREEN_TEXT}[*]${NC} Opening ports..."
  iptables --flush
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Installing updates..."
  apt -qq update 1>/dev/null 2>/dev/null
  apt -qq -y upgrade 1>/dev/null 2>/dev/null
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Installing docker..."
  curl -sSL https://get.docker.com/ | CHANNEL=stable bash 1>/dev/null 2>/dev/null
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Enabling docker..."
  systemctl enable --now -q docker
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Downloading node..."
  mkdir -p /etc/pterodactyl
  curl -s -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
  chmod u+x /usr/local/bin/wings
  printf " ${GREEN} DONE ${NC}\n"

  printf "${GREEN_TEXT}[*]${NC} Adding jobs..."
  cat >/etc/systemd/system/wings.service <<EOF
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
  systemctl enable -q wings
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Getting server ips..."
  local_ip=$(hostname -I | awk '{print $1}')
  public_ip=$(curl -s ipinfo.io | jq -r ".ip")
  printf " ${GREEN} DONE ${NC}\n"
  printf "Pterodactyl node was installed successfuly!\n"
  printf "Data for node allocations:\n"
  printf "IP Address: ${local_ip}\n"
  printf "IP Alias: ${public_ip}\n"
fi

if [ "$type" == "full" ]; then
  printf "${GREEN_TEXT}[*]${NC} Finding server location..."
  node_ip=$(curl -s ipinfo.io | jq -r ".ip")
  country=$(curl -s ipinfo.io | jq -r ".country" | tr "[:upper:]" "[:lower:]")
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Creating location..."
  created_location=$(php artisan p:location:make --short="$country" -n)
  location_id=$(echo "$created_location" | grep -oP "ID of \K\d+")
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Creating node..."
  total_memory_kb=$(free -k | awk "/^Mem:/{print \$2}")
  total_memory_mb=$((total_memory_kb / 1024))
  total_disk=$(df --output=size -BG / | tail -n1 | tr -d "G")
  created_node=$(php artisan p:node:make --name="main" --locationId="$location_id" --fqdn="$node_ip" --public=1 --scheme=http --proxy=0 --maintenance=0 --maxMemory="$(((total_memory_mb + 127) / 128 * 128))" --overallocateMemory=0 --maxDisk="$((total_disk * 1000))" --overallocateDisk=0 --uploadSize=1024 --daemonListeningPort=8080 --daemonSFTPPort=2022 --daemonBase="/var/lib/pterodactyl/volumes" -n)
  node_id=$(echo "$created_node" | grep -oP "id of \K\d+")
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Linking panel and node..."
  config=$(php artisan p:node:configuration $node_id -n)
  echo "$config" > /etc/pterodactyl/config.yml
  printf " ${GREEN} DONE ${NC}\n"
  printf "${GREEN_TEXT}[*]${NC} Enabling node..."
  systemctl restart wings
  printf " ${GREEN} DONE ${NC}\n"
  printf "Pterodactyl panel and node was linked successfuly!\n"
fi
