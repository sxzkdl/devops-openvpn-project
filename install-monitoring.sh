#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run with sudo!" >&2
  exit 1
fi

echo "--- 1. Creating system users ---"
useradd --no-create-home --shell /bin/false prometheus || true
useradd --no-create-home --shell /bin/false alertmanager || true

echo "--- 2. Creating directories ---"
mkdir -p /etc/prometheus /var/lib/prometheus /etc/alertmanager /var/lib/alertmanager

echo "--- 3. Downloading and installing Prometheus ---"
PROM_VERSION="2.45.0"
wget -q https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz

tar -xf prometheus-${PROM_VERSION}.linux-amd64.tar.gz

sudo rm -rf /etc/prometheus/consoles /etc/prometheus/console_libraries

mv prometheus-${PROM_VERSION}.linux-amd64/prometheus /usr/local/bin/
mv prometheus-${PROM_VERSION}.linux-amd64/promtool /usr/local/bin/
mv prometheus-${PROM_VERSION}.linux-amd64/consoles /etc/prometheus/
mv prometheus-${PROM_VERSION}.linux-amd64/console_libraries /etc/prometheus/

rm -rf prometheus-${PROM_VERSION}.linux-amd64*

echo "--- 4. Creating prometheus.yml config ---"

cat <<EOF > /etc/prometheus/prometheus.yml 
global:
  scrape_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - 'localhost:9093'

rule_files:
  - "alert.rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_endpoints'
    static_configs:
      - targets:
          - 'localhost:9100'
          - '10.128.0.2:9100'   
          - '10.128.0.3:9100'  
EOF

echo "--- 5. Creating alert.rules.yml ---"
cat << 'EOF' > /etc/prometheus/alert.rules.yml
groups:
  - name: vpn_infrastructure_alerts
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} is down!"

      - alert: DiskSpaceLow
        expr: node_filesystem_free_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on instance {{ \$labels.instance }} (less than 10% free)"
EOF

echo "--- 6. Downloading and installing Alertmanager ---"
AM_VERSION="0.25.0"
wget -q https://github.com/prometheus/alertmanager/releases/download/v${AM_VERSION}/alertmanager-${AM_VERSION}.linux-amd64.tar.gz

tar -xf alertmanager-${AM_VERSION}.linux-amd64.tar.gz
mv alertmanager-${AM_VERSION}.linux-amd64/alertmanager /usr/local/bin/
mv alertmanager-${AM_VERSION}.linux-amd64/amtool /usr/local/bin/
rm -rf alertmanager-${AM_VERSION}.linux-amd64*

echo "--- 7. Configuring alertmanager.yml ---"
cat <<EOF > /etc/alertmanager/alertmanager.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'your-devops-alerts@gmail.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password' 

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email-receiver'

receivers:
  - name: 'email-receiver'
    email_configs:
      - to: 'your-email@gmail.com' 
        send_resolved: true
EOF

echo "--- 8. Creating systemd service files ---"
cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus/

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/alertmanager.service
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
ExecStart=/usr/local/bin/alertmanager --config.file=/etc/alertmanager/alertmanager.yml --storage.path=/var/lib/alertmanager/

[Install]
WantedBy=multi-user.target
EOF

echo "--- 9. Setting permissions and starting services ---"
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager

systemctl daemon-reload
systemctl enable --now prometheus alertmanager

echo "Success! Prometheus and Alertmanager have been installed and started successfully!"
