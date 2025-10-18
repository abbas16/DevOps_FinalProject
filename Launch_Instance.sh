#!/bin/bash
set -e

# variable
AMI_ID="ami-0d9a665f802ae6227"
INSTANCE_TYPE="t3.micro"
KEY_NAME="Final"
SECURITY_GROUP="sg-07c0a6afcab5f0695"
SUBNET_ID="subnet-08d70d957419c303d"
REGION="us-east-2"

# user-data
cat > userdata.sh <<'EOF'
#!/bin/bash
exec > /var/log/user-data.log 2>&1
# installs Docker and runs nginx
apt-get update -y
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
docker run -d -p 80:80 nginx
# run Grafana container
docker run -d \
-p 3000:3000 \
--name grafana \
-e "GF_SECURITY_ADMIN_USER=admin" \
-e "GF_SECURITY_ADMIN_PASSWORD=admin" \
grafana/grafana:latest
# Run Node Exporter container
docker run -d \
-p 9100:9100 \
--name node-exporter \
prom/node-exporter:latest
# Create Prometheus config
cat << 'EOPROM' > /home/ubuntu/prometheus.yml
global:
  scrape_interval: 5s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
EOPROM

# Run Prometheus container with config file
docker run -d \
  -p 9090:9090 \
  --name prometheus \
  -v /home/ubuntu/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:latest
EOF

# Launch instance
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SECURITY_GROUP" \
  ${SUBNET_ID:+--subnet-id $SUBNET_ID} \
  --user-data file://userdata.sh \
  --query 'Instances[0].InstanceId' --output text --region "$REGION")

echo "Launched instance: $INSTANCE_ID"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region "$REGION")
echo "Public IP: $PUBLIC_IP"
echo "Grafana Dashboard: $PUBLIC_IP:3000"
echo "Node Exporter: $PUBLIC_IP:9100/metrics"
echo "Prometheus: $PUBLIC_IP:9090"