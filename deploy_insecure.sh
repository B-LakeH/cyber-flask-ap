#!/bin/bash

# Exit on error
set -e

# Configuration
KEY_NAME="flask-app-key"
SECURITY_GROUP_NAME="flask-app-sg"
INSTANCE_TYPE="t2.micro"
REPO_URL="https://github.com/yourusername/your-flask-app.git"  # Replace with your actual repo URL

# Create a new key pair
echo "Creating a new key pair..."
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > $KEY_NAME.pem
chmod 400 $KEY_NAME.pem

# Create security group with wide-open inbound rules
echo "Creating security group..."
aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME --description "Insecure security group for testing"
aws ec2 authorize-security-group-ingress \
    --group-name $SECURITY_GROUP_NAME \
    --protocol -1 \
    --cidr 0.0.0.0/0 \
    --port 0-65535

# Get the latest Amazon Linux 2 AMI ID
AMI_ID=$(aws ssm get-parameter --name "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2" --query 'Parameter.Value' --output text)

# Launch the instance
echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-groups $SECURITY_GROUP_NAME \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=FlaskApp}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Get the public IP address
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "Instance is running at $PUBLIC_IP"
echo "Waiting for SSH to be available..."

# Wait for SSH to be available
until ssh -i "$KEY_NAME.pem" -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" ec2-user@$PUBLIC_IP "echo 'SSH is ready'" &>/dev/null
do
    echo "Waiting for SSH..."
    sleep 5
done

# Install dependencies and deploy the application
echo "Deploying application..."
ssh -i "$KEY_NAME.pem" ec2-user@$PUBLIC_IP << 'EOF'
    # Update packages and install required software
    sudo yum update -y
    sudo yum install -y git python3 python3-pip
    
    # Clone the repository
    git clone $REPO_URL app
    cd app
    
    # Install Python dependencies
    pip3 install -r requirements.txt
    
    # Run the Flask app on port 80 (requires root privileges)
    sudo python3 app.py --host=0.0.0.0 --port=80 &
EOF

echo "Deployment complete!"
echo "Application should be available at: http://$PUBLIC_IP"
echo "To connect to the instance: ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP"
