#!/bin/bash

set -e

DOMAIN="vpn.ninz.store"
EMAIL="tecnotes2@gmail.com"  # ✅ Replace with your actual email
PRITUNL_PORT="9700"

echo "🔄 Stopping pritunl to configure letsencrypt & nginx reverse proxy..."
sudo systemctl stop pritunl

echo "📦 Installing NGINX and Certbot..."
sudo dnf -y install nginx certbot python3-certbot-nginx

echo "🚀 Starting and enabling NGINX..."
sudo systemctl enable --now nginx

echo "🔧 Creating temporary NGINX config for HTTP challenge..."
sudo tee /etc/nginx/conf.d/$DOMAIN.conf > /dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PRITUNL_PORT;
    }
}
EOF

echo "🔁 Reloading NGINX..."
sudo nginx -t && sudo systemctl reload nginx

echo "📜 Requesting Let's Encrypt certificate for $DOMAIN..."
sudo certbot --nginx --non-interactive --agree-tos -m $EMAIL -d $DOMAIN

echo "🔐 SSL certificate issued. Updating NGINX reverse proxy config..."
sudo tee /etc/nginx/conf.d/$DOMAIN.conf > /dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://127.0.0.1:$PRITUNL_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

echo "🔁 Reloading NGINX with SSL config..."
sudo nginx -t && sudo systemctl reload nginx

echo "🛠️ Configuring Pritunl for Reverse Proxy mode..."
sudo pritunl set app.reverse_proxy true
sudo pritunl set app.redirect_server false
sudo pritunl set app.server_ssl false
sudo pritunl set app.server_port $PRITUNL_PORT

echo "🔄 Restarting Pritunl to apply changes..."
sudo systemctl restart pritunl
sudo systemctl status pritunl --no-pager

echo "✅ Final port checks:"
sudo lsof -i :80   | grep LISTEN || echo "❌ Port 80 not listening!"
sudo lsof -i :443  | grep LISTEN || echo "❌ Port 443 not listening!"
sudo lsof -i :$PRITUNL_PORT | grep LISTEN || echo "❌ Pritunl not listening on $PRITUNL_PORT!"

echo "🎉 Setup completed successfully for $DOMAIN"