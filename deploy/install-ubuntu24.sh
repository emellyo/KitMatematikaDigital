#!/usr/bin/env bash
set -euo pipefail

APP_NAME="kitmatematika"
APP_USER="kitmatematika"
APP_DIR="/var/www/${APP_NAME}"
APP_BIN="${APP_DIR}/KitMatematikaDigital"
APP_PORT="5000"
ARCHIVE="/tmp/${APP_NAME}.tar.gz"
DOMAIN="${1:-_}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo."
  exit 1
fi

if [[ ! -f "${ARCHIVE}" ]]; then
  echo "Missing ${ARCHIVE}. Upload the publish archive first."
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx tar

if ! id -u "${APP_USER}" >/dev/null 2>&1; then
  useradd --system --create-home --shell /usr/sbin/nologin "${APP_USER}"
fi

mkdir -p "${APP_DIR}"
systemctl stop "${APP_NAME}" >/dev/null 2>&1 || true
rm -rf "${APP_DIR:?}/"*
tar -xzf "${ARCHIVE}" -C "${APP_DIR}"
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"
chmod +x "${APP_BIN}"

cat >/etc/systemd/system/${APP_NAME}.service <<SERVICE
[Unit]
Description=Kit Matematika Digital
After=network.target

[Service]
WorkingDirectory=${APP_DIR}
ExecStart=${APP_BIN}
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=${APP_NAME}
User=${APP_USER}
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://127.0.0.1:${APP_PORT}
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
SERVICE

cat >/etc/nginx/sites-available/${APP_NAME} <<NGINX
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINX

ln -sfn /etc/nginx/sites-available/${APP_NAME} /etc/nginx/sites-enabled/${APP_NAME}
rm -f /etc/nginx/sites-enabled/default

systemctl daemon-reload
systemctl enable "${APP_NAME}"
systemctl restart "${APP_NAME}"
nginx -t
systemctl reload nginx

echo "Deployment complete."
echo "App status: systemctl status ${APP_NAME} --no-pager"
echo "Logs: journalctl -u ${APP_NAME} -f"
