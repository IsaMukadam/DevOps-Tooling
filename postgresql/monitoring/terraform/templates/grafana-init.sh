#!/bin/bash

# Exit on any error
set -e

# Function to check if a service is ready
wait_for_service() {
    local service=$1
    local max_attempts=30
    local attempt=1
    
    while ! systemctl is-active --quiet $service; do
        if [ $attempt -eq $max_attempts ]; then
            echo "$service failed to start after $max_attempts attempts"
            return 1
        fi
        echo "Waiting for $service to start (attempt $attempt/$max_attempts)..."
        sleep 10
        ((attempt++))
    done
    echo "$service is running"
}

# Function to wait for Prometheus
wait_for_prometheus() {
    local prometheus_host=$1
    local max_attempts=30
    local attempt=1
    
    while ! curl -s "http://$prometheus_host:9090/-/healthy" > /dev/null; do
        if [ $attempt -eq $max_attempts ]; then
            echo "Prometheus not ready after $max_attempts attempts"
            return 1
        fi
        echo "Waiting for Prometheus to be ready (attempt $attempt/$max_attempts)..."
        sleep 10
        ((attempt++))
    done
    echo "Prometheus is ready"
}

# Update and install Grafana
apt-get update
apt-get install -y apt-transport-https software-properties-common wget curl jq
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list
apt-get update
apt-get install -y grafana

# Wait for Prometheus to be ready
wait_for_prometheus "${prometheus_host}"

# Create Grafana directories
mkdir -p /etc/grafana/provisioning/{datasources,dashboards}

# Configure Grafana datasource
cat > /etc/grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://${prometheus_host}:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
EOF

# Configure Grafana for auto-restart and set admin password
cat > /etc/grafana/grafana.ini << EOF
[security]
admin_password = ${grafana_password}

[service_account]
auto_assign_org_role = Editor

[server]
root_url = http://localhost:3000

[users]
default_theme = dark

[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning

[metrics]
enabled = false

[analytics]
enabled = false

[snapshots]
external_enabled = false

[unified_alerting]
enabled = false

[panels]
disable_sanitize_html = false

[auth]
disable_login_form = false

[quota]
enabled = true
org_user = 5
org_dashboard = 20
org_data_source = 5
org_alert_rule = 20
EOF

# Create systemd override for auto-restart
mkdir -p /etc/systemd/system/grafana-server.service.d/
cat > /etc/systemd/system/grafana-server.service.d/override.conf << EOF
[Service]
Restart=always
RestartSec=10
StartLimitInterval=0
EOF

# Add health check script
cat > /usr/local/bin/check-grafana.sh << 'EOF'
#!/bin/bash
if ! curl -s http://localhost:3000/api/health > /dev/null; then
    systemctl restart grafana-server
    exit 1
fi
EOF

chmod +x /usr/local/bin/check-grafana.sh

# Add health check to cron
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/check-grafana.sh") | crontab -

# Start and enable Grafana
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server
wait_for_service grafana-server

# Signal successful completion
touch /var/lib/grafana-ready