#!/bin/bash

# -------------------------
# Install Filebeat + Grafana on Ubuntu 22.04 EC2
# Based on SQAE112 - Assignment #4.1
# -------------------------

# === CONFIGURATION ===
ELASTIC_IP="34.227.61.153"   # â† Replace with your Elasticsearch EC2 IP
ELASTIC_PORT="9200"
KIBANA_PORT="5601"
ELASTIC_USERNAME="elastic"  # Optional: if security enabled
ELASTIC_PASSWORD="nC*et_nOP2yaUsCPFwpG" # Optional: if security enabled

USE_SECURITY=true          # Set to true if xpack.security.enabled is enabled

# === Update System ===
sudo apt update && sudo apt upgrade -y

# === FILEBEAT INSTALLATION ===
echo "[1] Installing Filebeat..."
sudo apt install -y wget curl gnupg apt-transport-https

# Add Elastic GPG key (recommended method)
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/elastic.gpg > /dev/null

# Add Elastic repo
echo "deb [signed-by=/etc/apt/trusted.gpg.d/elastic.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

# Install Filebeat
sudo apt update
sudo apt install -y filebeat

# Enable system module
sudo filebeat modules enable system

# Configure system module
sudo tee /etc/filebeat/modules.d/system.yml > /dev/null <<EOF
- module: system
  syslog:
    enabled: true
  auth:
    enabled: true
EOF

# Configure Filebeat.yml
echo "[2] Configuring Filebeat..."

sudo tee /etc/filebeat/filebeat.yml > /dev/null <<EOF
filebeat.inputs:
- type: filestream
  enabled: false

filebeat.config.modules:
  path: \${path.config}/modules.d/*.yml
  reload.enabled: false

setup.kibana:
  host: "http://${ELASTIC_IP}:${KIBANA_PORT}"

output.elasticsearch:
  hosts: ["http://${ELASTIC_IP}:${ELASTIC_PORT}"]
EOF

if [ "$USE_SECURITY" = true ]; then
  echo "  Configuring with security..."
  sudo tee -a /etc/filebeat/filebeat.yml > /dev/null <<EOF
  username: "${ELASTIC_USERNAME}"
  password: "${ELASTIC_PASSWORD}"
  ssl.verification_mode: "none"
EOF
fi

# Restart Filebeat
sudo systemctl enable filebeat
sudo systemctl restart filebeat

# Test Filebeat
echo "[3] Testing Filebeat Config and Output..."
sudo filebeat test config
sudo filebeat test output

# Load dashboards into Kibana
sudo filebeat setup --dashboards

# === GRAFANA INSTALLATION ===
echo "[4] Installing Grafana..."
sudo apt-get install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"

# Add Grafana GPG key
wget -q -O - https://packages.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/grafana.gpg > /dev/null

# Install Grafana
sudo apt update
sudo apt install -y grafana

# Start and enable Grafana
sudo systemctl daemon-reexec
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

# Check status
echo "[5] Grafana status:"
sudo systemctl status grafana-server --no-pager

# Install Elasticsearch data source plugin (optional, built-in)
echo "[6] Installing Elasticsearch plugin (may be built-in)..."
sudo grafana-cli plugins install grafana-elasticsearch-datasource || echo "Plugin already exists or not required."

# Restart Grafana
sudo systemctl restart grafana-server

echo ""
echo "ðŸŽ‰ Installation complete!"
echo "âž¡ï¸  Access Grafana at: http://$(curl -s http://checkip.amazonaws.com):3000 (admin / admin)"
echo "âž¡ï¸  Filebeat should be sending logs to Elasticsearch: http://${ELASTIC_IP}:${ELASTIC_PORT}"
echo ""

