#!/bin/bash
set -e

# Default variables (override via env in GitHub Actions)
AMI_ID="ami-0d9a665f802ae6227"      # replace with real Ubuntu AMI in your region
INSTANCE_TYPE="t3.micro"
KEY_NAME="Final"        # MUST match an EC2 Key Pair in your account
SECURITY_GROUP="sg-07c0a6afcab5f0695"
SUBNET_ID="subnet-08d70d957419c303d"            # optional
REGION="us-east-2"

# Create a small user-data script that installs Docker and runs nginx
cat > userdata.sh <<'EOF'
#!/bin/bash
apt-get update -y
apt-get install -y docker.io git
systemctl start docker
docker run -d -p 80:80 nginx
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
