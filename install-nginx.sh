#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
   echo "Skrip ini harus dijalankan sebagai root" 1>&2
   exit 1
fi

DOMAIN=$(cat /etc/vps-data/domain)

echo "=> Memulai Instalasi & Konfigurasi Nginx..."
apt install nginx -y >/dev/null 2>&1

echo "" > /etc/nginx/sites-available/default
cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 80;
    listen [::]:80;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name _;

    ssl_certificate /etc/vps-data/cert.crt;
    ssl_certificate_key /etc/vps-data/cert.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';

    root /var/www/html;

    # Lokasi untuk SSH WebSocket
    location / {
        if (\$http_upgrade != "websocket") {
            return 404;
        }
        proxy_pass http://127.0.0.1:7000;
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    
    # Lokasi untuk VMess WebSocket
    location /vmess {
        if (\$http_upgrade != "websocket") {
            return 404;
        }
        proxy_pass http://127.0.0.1:7001;
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # Lokasi untuk Trojan gRPC
    location /trojan-grpc {
        if (\$content_type !~ "application/grpc") {
            return 404;
        }
        
        client_max_body_size 0;
        client_body_buffer_size 512k;
        grpc_read_timeout 1h;
        grpc_send_timeout 1h;
        client_body_timeout 1h;

        grpc_socket_keepalive on;
        
        grpc_set_header Host \$host;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header X-Forwarded-Proto \$scheme;
        
        grpc_pass grpc://127.0.0.1:7002;
    }

    # Lokasi untuk VLESS gRPC
    location /vless-grpc {
        if (\$content_type !~ "application/grpc") {
            return 404;
        }

        client_max_body_size 0;
        client_body_buffer_size 512k;
        grpc_read_timeout 1h;
        grpc_send_timeout 1h;
        client_body_timeout 1h;

        grpc_socket_keepalive on;

        grpc_set_header Host \$host;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header X-Forwarded-Proto \$scheme;

        grpc_pass grpc://127.0.0.1:7003;
    }
}
EOF

systemctl daemon-reload >/dev/null 2>&1
nginx -t
systemctl enable nginx >/dev/null 2>&1
systemctl reload nginx >/dev/null 2>&1
systemctl restart nginx >/dev/null 2>&1
echo ""
echo "✅ Instalasi & Konfigurasi Nginx Selesai!"
