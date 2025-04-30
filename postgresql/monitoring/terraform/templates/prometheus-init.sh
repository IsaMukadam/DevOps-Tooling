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

# Update and install required packages
apt-get update
apt-get install -y docker.io prometheus-postgres-exporter curl jq

# Create Prometheus configuration directory
mkdir -p /etc/prometheus /prometheus

# Configure Prometheus storage
cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'postgres'
    static_configs:
      - targets: ['localhost:9187']
    metrics_path: /metrics

EOF

# Create Prometheus systemd service with restart policy
cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus Server
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target
Wants=network-online.target

[Service]
User=root
Restart=always
RestartSec=10
StartLimitInterval=0
ExecStart=/usr/bin/docker run \
    --rm \
    --net=host \
    --name prometheus \
    -v /etc/prometheus:/etc/prometheus \
    -v /prometheus:/prometheus \
    --memory=512m \
    --memory-swap=512m \
    prom/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus \
    --storage.tsdb.retention.time=7d \
    --storage.tsdb.retention.size=4GB \
    --web.console.libraries=/usr/share/prometheus/console_libraries \
    --web.console.templates=/usr/share/prometheus/consoles

[Install]
WantedBy=multi-user.target
EOF

# Configure PostgreSQL exporter with credentials
cat > /etc/default/prometheus-postgres-exporter << EOF
DATA_SOURCE_NAME="postgresql://${postgres_host}:5432/postgres?sslmode=require"
EOF

# Start and enable services
systemctl daemon-reload
systemctl enable prometheus-postgres-exporter
systemctl start prometheus-postgres-exporter
wait_for_service prometheus-postgres-exporter

systemctl enable prometheus
systemctl start prometheus
wait_for_service prometheus

# Add health check script
cat > /usr/local/bin/check-prometheus.sh << 'EOF'
#!/bin/bash
if ! curl -s http://localhost:9090/-/healthy > /dev/null; then
    systemctl restart prometheus
    exit 1
fi
EOF

chmod +x /usr/local/bin/check-prometheus.sh

# Add health check to cron
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/check-prometheus.sh") | crontab -

# Signal successful completion
touch /var/lib/prometheus-ready