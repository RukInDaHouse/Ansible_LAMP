#!/bin/bash

# Define versions
NGINX_VER=1.20.1

rm -r /usr/local/src/nginx/ >>/dev/null 2>&1
mkdir -p /usr/local/src/nginx/modules

# Dependencies
apt-get update
apt-get install -y build-essential ca-certificates wget curl libpcre3 libpcre3-dev autoconf unzip automake libtool tar git libssl-dev zlib1g-dev uuid-dev lsb-release libxml2-dev libxslt1-dev cmake

# Download and extract of Nginx source code
cd /usr/local/src/nginx/ || exit 1
wget -qO- http://nginx.org/download/nginx-${NGINX_VER}.tar.gz | tar zxf -
cd nginx-${NGINX_VER} || exit 1

if [[ ! -e /etc/nginx/nginx.conf ]]; then
    mkdir -p /etc/nginx
    cd /etc/nginx || exit 1
    wget https://raw.githubusercontent.com/Angristan/nginx-autoinstall/master/conf/nginx.conf
fi

cd /usr/local/src/nginx/nginx-${NGINX_VER} || exit 1
NGINX_OPTIONS="
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --user=nginx \
    --group=nginx \
    --with-cc-opt=-Wno-deprecated-declarations \
    --with-cc-opt=-Wno-ignored-qualifiers"

NGINX_MODULES="--with-threads \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_mp4_module \
    --with-http_auth_request_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-http_sub_module"


./configure $NGINX_OPTIONS $NGINX_MODULES
make -j "$(nproc)"
make install

# remove debugging symbols
strip -s /usr/sbin/nginx

# Nginx installation from source does not add an init script for systemd and logrotate
# Using the official systemd script and logrotate conf from nginx.org
if [[ ! -e /lib/systemd/system/nginx.service ]]; then
    cd /lib/systemd/system/ || exit 1
    wget https://raw.githubusercontent.com/Angristan/nginx-autoinstall/master/conf/nginx.service
    # Enable nginx start at boot
    systemctl enable nginx
fi

# Nginx's cache directory is not created by default
if [[ ! -d /var/cache/nginx ]]; then
    mkdir -p /var/cache/nginx
fi

# We add the sites-* folders as some use them.
if [[ ! -d /etc/nginx/sites-available ]]; then
    mkdir -p /etc/nginx/sites-available
fi
if [[ ! -d /etc/nginx/sites-enabled ]]; then
    mkdir -p /etc/nginx/sites-enabled
fi
if [[ ! -d /etc/nginx/conf.d ]]; then
    mkdir -p /etc/nginx/conf.d
fi

# Restart Nginx
systemctl restart nginx
# Block Nginx from being installed via APT
if [[ $(lsb_release -si) == "Debian" ]] || [[ $(lsb_release -si) == "Ubuntu" ]]; then
    cd /etc/apt/preferences.d/ || exit 1
    echo -e 'Package: nginx*\nPin: release *\nPin-Priority: -1' >nginx-block
fi

# Removing temporary Nginx and modules files
rm -r /usr/local/src/nginx
exit
;;

