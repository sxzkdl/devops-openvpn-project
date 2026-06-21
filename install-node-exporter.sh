#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run with sudo!" >&2
  exit 1
fi

echo "--- 1. Creating system user ---"
useradd --no-create-home --shell /bin/false node_exporter || true

echo "--- 2. Downloading and installing Node Exporter ---"
VERSION="1.6.0"
wget -q https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.linux-amd64.tar.gz

tar -xf node_exporter-${VERSION}.linux-amd64.tar.gz
mv node_exporter-${VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-${VERSION}.linux-amd64*

echo "--- 3. Creating systemd service file ---"
cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

echo "--- 4. Starting Node Exporter ---"
systemctl daemon-reload
systemctl enable --now node_exporter

echo "Success! Node Exporter is running on port 9100."
