#!/bin/bash

# Build and Push Docker Image to ECR

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
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║    Build and Push Docker Image             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Get AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}"

echo -e "${YELLOW}Step 1: Logging into ECR...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

echo -e "${GREEN}✓ Logged into ECR${NC}\n"

echo -e "${YELLOW}Step 2: Building Docker image...${NC}"
docker build -t ${ECR_REPOSITORY}:latest .

echo -e "${GREEN}✓ Docker image built${NC}\n"

echo -e "${YELLOW}Step 3: Tagging image...${NC}"
docker tag ${ECR_REPOSITORY}:latest ${ECR_URI}:latest
docker tag ${ECR_REPOSITORY}:latest ${ECR_URI}:$(date +%Y%m%d-%H%M%S)

echo -e "${GREEN}✓ Image tagged${NC}\n"

echo -e "${YELLOW}Step 4: Pushing image to ECR...${NC}"
docker push ${ECR_URI}:latest
docker push ${ECR_URI}:$(date +%Y%m%d-%H%M%S)

echo -e "${GREEN}✓ Image pushed to ECR${NC}\n"

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Build and Push Complete!             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo -e "\n${GREEN}Image URI: ${ECR_URI}:latest${NC}"
echo -e "\n${YELLOW}Next step: Run ./scripts/deploy-ecs.sh to deploy to ECS${NC}"
