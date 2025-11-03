#!/bin/bash

# AWS ECS Setup Script
# This script sets up the required AWS resources for ECS deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env file not found. Copy .env.example to .env and update values.${NC}"
    exit 1
fi

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       AWS ECS Setup Script                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Verifying AWS credentials...${NC}"
aws sts get-caller-identity || {
    echo -e "${RED}AWS credentials not configured. Run 'aws configure'${NC}"
    exit 1
}
echo -e "${GREEN}✓ AWS credentials verified${NC}\n"

# Get AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}AWS Account ID: ${AWS_ACCOUNT_ID}${NC}\n"

echo -e "${YELLOW}Step 2: Creating ECR repository...${NC}"
aws ecr describe-repositories --repository-names ${ECR_REPOSITORY} --region ${AWS_REGION} &> /dev/null || \
aws ecr create-repository \
    --repository-name ${ECR_REPOSITORY} \
    --region ${AWS_REGION} \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256

echo -e "${GREEN}✓ ECR repository created/verified${NC}\n"

echo -e "${YELLOW}Step 3: Creating ECS cluster...${NC}"
aws ecs describe-clusters --clusters ${ECS_CLUSTER} --region ${AWS_REGION} &> /dev/null || \
aws ecs create-cluster \
    --cluster-name ${ECS_CLUSTER} \
    --region ${AWS_REGION} \
    --capacity-providers FARGATE FARGATE_SPOT \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1

echo -e "${GREEN}✓ ECS cluster created/verified${NC}\n"

echo -e "${YELLOW}Step 4: Creating IAM roles...${NC}"

# Create ECS Task Execution Role
cat > /tmp/ecs-task-execution-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam get-role --role-name ecsTaskExecutionRole &> /dev/null || \
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document file:///tmp/ecs-task-execution-trust-policy.json

aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Create ECS Task Role
aws iam get-role --role-name ecsTaskRole &> /dev/null || \
aws iam create-role \
    --role-name ecsTaskRole \
    --assume-role-policy-document file:///tmp/ecs-task-execution-trust-policy.json

echo -e "${GREEN}✓ IAM roles created/verified${NC}\n"

echo -e "${YELLOW}Step 5: Creating CloudWatch log group...${NC}"
aws logs create-log-group \
    --log-group-name /ecs/demo-app \
    --region ${AWS_REGION} 2>/dev/null || echo "Log group already exists"

echo -e "${GREEN}✓ CloudWatch log group created/verified${NC}\n"

echo -e "${YELLOW}Step 6: Getting default VPC information...${NC}"
DEFAULT_VPC=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query 'Vpcs[0].VpcId' \
    --output text \
    --region ${AWS_REGION})

if [ "$DEFAULT_VPC" != "None" ]; then
    echo -e "${GREEN}Default VPC: ${DEFAULT_VPC}${NC}"
    
    # Get subnets
    SUBNETS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${DEFAULT_VPC}" \
        --query 'Subnets[*].SubnetId' \
        --output text \
        --region ${AWS_REGION})
    
    echo -e "${GREEN}Subnets: ${SUBNETS}${NC}"
    
    # Create security group if it doesn't exist
    SG_NAME="ecs-demo-sg"
    SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${SG_NAME}" "Name=vpc-id,Values=${DEFAULT_VPC}" \
        --query 'SecurityGroups[0].GroupId' \
        --output text \
        --region ${AWS_REGION} 2>/dev/null)
    
    if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
        SG_ID=$(aws ec2 create-security-group \
            --group-name ${SG_NAME} \
            --description "Security group for ECS demo app" \
            --vpc-id ${DEFAULT_VPC} \
            --region ${AWS_REGION} \
            --query 'GroupId' \
            --output text)
        
        # Add inbound rule for port 3000
        aws ec2 authorize-security-group-ingress \
            --group-id ${SG_ID} \
            --protocol tcp \
            --port 3000 \
            --cidr 0.0.0.0/0 \
            --region ${AWS_REGION}
        
        echo -e "${GREEN}Security group created: ${SG_ID}${NC}"
    else
        echo -e "${GREEN}Security group exists: ${SG_ID}${NC}"
    fi
    
    echo -e "\n${YELLOW}Update your .env file with these values:${NC}"
    echo "VPC_ID=${DEFAULT_VPC}"
    echo "SUBNET_1=$(echo $SUBNETS | cut -d' ' -f1)"
    echo "SUBNET_2=$(echo $SUBNETS | cut -d' ' -f2)"
    echo "SECURITY_GROUP=${SG_ID}"
else
    echo -e "${RED}No default VPC found. Please create a VPC or specify an existing one.${NC}"
fi

echo -e "\n${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Setup Complete!                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Update .env file with VPC and subnet information"
echo "2. Run ./scripts/build-push.sh to build and push Docker image"
echo "3. Run ./scripts/deploy-ecs.sh to deploy to ECS"
