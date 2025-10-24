#!/bin/bash

set -e

echo "=== Checking for existing swap ==="
# [ ... Tu lógica de Swapfile existente ... ]

if swapon --summary | grep -q '/swapfile'; then
  echo "Swap already active. Skipping swap creation."
else
  if [ -f /swapfile ]; then
    echo "/swapfile exists but not active. Enabling..."
    sudo swapon /swapfile
  else
    echo "== Creating 2GB swap file =="
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  fi
fi

echo "== Updating System and Installing Tools =="
sudo dnf update -y

echo "== Adding Elasticsearch 8.x Repository =="
# [ ... Tu lógica de repositorio de Elastic existente ... ]
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
cat <<EOF | sudo tee /etc/yum.repos.d/elasticsearch.repo
[elasticsearch-8.x]
name=Elasticsearch repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF

echo "== Installing Elasticsearch and Kibana =="
sudo dnf install -y elasticsearch kibana

echo "== Setting Elasticsearch heap size to 1G =="
sudo tee /etc/elasticsearch/jvm.options.d/heap.options > /dev/null <<EOF
-Xms1g
-Xmx1g
EOF

echo "== Enabling and starting Elasticsearch =="
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable elasticsearch.service
sudo systemctl start elasticsearch.service

echo "== Setting elastic user password =="
# Genera la contraseña
ELASTIC_PASSWORD=$(sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -b -s)

echo "== Waiting for Elasticsearch to be ready =="
until curl -s -k -u elastic:"$ELASTIC_PASSWORD" "https://localhost:9200/_cluster/health" | grep -qE '"status"\s*:\s*"(yellow|green)"'; do
  echo "$(date) - Elasticsearch not ready yet. Waiting 5 seconds..."
  sleep 5
done
echo "Elasticsearch is ready."

echo "=== Configuring Kibana ==="
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable kibana.service
sudo systemctl start kibana.service

echo "== Generating Kibana enrollment token =="
ENROLLMENT_TOKEN=$(sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana)

echo "== Passing enrollment token =="
sudo /usr/share/kibana/bin/kibana-setup --enrollment-token $ENROLLMENT_TOKEN

# 🔑 LÓGICA CLAVE: Obtener la IP pública y configurar Kibana para URLs públicas
# Usamos el servicio de metadatos de AWS para obtener la IP pública
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

sudo sed -i '/^\s*#\?\s*server\.host:/d' /etc/kibana/kibana.yml
sudo sed -i '/^\s*#\?\s*server\.publicBaseUrl:/d' /etc/kibana/kibana.yml
echo 'server.host: "0.0.0.0"' | sudo tee -a /etc/kibana/kibana.yml

# Esto es clave para el requisito del profesor y elimina las advertencias
echo "server.publicBaseUrl: http://$PUBLIC_IP:5601" | sudo tee -a /etc/kibana/kibana.yml

sudo systemctl restart kibana.service

echo "== Waiting for Kibana to be ready =="
until curl -s "http://localhost:5601/api/status" | grep -qE '"overall"\s*:\s*{"level"\s*:\s*"available"}'; do
  echo "$(date) - Kibana not ready yet. Waiting 5 seconds..."
  sleep 5
done
echo "Kibana is ready."

echo "=== ALL DONE - INFORMACIÓN IMPORTANTE ==="
echo "======================================================="
echo "COPIA ESTOS VALORES PARA USARLOS EN EL SCRIPT DE UBUNTU:"
echo "ELASTIC_IP=$PUBLIC_IP"
echo "ELASTIC_PASSWORD=$ELASTIC_PASSWORD"
echo "======================================================="
