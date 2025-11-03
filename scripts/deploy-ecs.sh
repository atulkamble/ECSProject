#!/bin/bash

# Deploy to AWS ECS

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
echo -e "${GREEN}║       Deploy to AWS ECS                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Get AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo -e "${YELLOW}Step 1: Updating task definition with current values...${NC}"

# Create temporary task definition with substituted values
cat infrastructure/task-definition.json | \
    sed "s/<AWS_ACCOUNT_ID>/${AWS_ACCOUNT_ID}/g" | \
    sed "s/<AWS_REGION>/${AWS_REGION}/g" > /tmp/task-definition.json

echo -e "${GREEN}✓ Task definition updated${NC}\n"

echo -e "${YELLOW}Step 2: Registering task definition...${NC}"
TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json file:///tmp/task-definition.json \
    --region ${AWS_REGION} \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo -e "${GREEN}✓ Task definition registered: ${TASK_DEF_ARN}${NC}\n"

echo -e "${YELLOW}Step 3: Checking if service exists...${NC}"
SERVICE_EXISTS=$(aws ecs describe-services \
    --cluster ${ECS_CLUSTER} \
    --services ${ECS_SERVICE} \
    --region ${AWS_REGION} \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "MISSING")

if [ "$SERVICE_EXISTS" == "ACTIVE" ]; then
    echo -e "${YELLOW}Service exists. Updating service...${NC}"
    aws ecs update-service \
        --cluster ${ECS_CLUSTER} \
        --service ${ECS_SERVICE} \
        --task-definition ${TASK_DEF_ARN} \
        --force-new-deployment \
        --region ${AWS_REGION}
    
    echo -e "${GREEN}✓ Service updated${NC}\n"
else
    echo -e "${YELLOW}Service doesn't exist. Creating new service...${NC}"
    
    if [ -z "$SUBNET_1" ] || [ -z "$SECURITY_GROUP" ]; then
        echo -e "${RED}Error: SUBNET_1 and SECURITY_GROUP must be set in .env${NC}"
        exit 1
    fi
    
    SUBNETS="\"${SUBNET_1}\""
    if [ ! -z "$SUBNET_2" ]; then
        SUBNETS="${SUBNETS},\"${SUBNET_2}\""
    fi
    
    aws ecs create-service \
        --cluster ${ECS_CLUSTER} \
        --service-name ${ECS_SERVICE} \
        --task-definition ${TASK_DEF_ARN} \
        --desired-count ${DESIRED_COUNT:-2} \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[\"${SECURITY_GROUP}\"],assignPublicIp=ENABLED}" \
        --region ${AWS_REGION}
    
    echo -e "${GREEN}✓ Service created${NC}\n"
fi

echo -e "${YELLOW}Step 4: Waiting for service to stabilize...${NC}"
echo -e "${YELLOW}This may take a few minutes...${NC}\n"

aws ecs wait services-stable \
    --cluster ${ECS_CLUSTER} \
    --services ${ECS_SERVICE} \
    --region ${AWS_REGION}

echo -e "${GREEN}✓ Service is stable${NC}\n"

echo -e "${YELLOW}Step 5: Getting task information...${NC}"
TASK_ARNS=$(aws ecs list-tasks \
    --cluster ${ECS_CLUSTER} \
    --service-name ${ECS_SERVICE} \
    --region ${AWS_REGION} \
    --query 'taskArns' \
    --output text)

if [ ! -z "$TASK_ARNS" ]; then
    echo -e "${GREEN}Running tasks:${NC}"
    for TASK_ARN in $TASK_ARNS; do
        TASK_ID=$(echo $TASK_ARN | cut -d'/' -f3)
        echo -e "  - ${TASK_ID}"
        
        # Get task details including network interface
        TASK_DETAILS=$(aws ecs describe-tasks \
            --cluster ${ECS_CLUSTER} \
            --tasks ${TASK_ARN} \
            --region ${AWS_REGION})
        
        # Extract ENI ID
        ENI_ID=$(echo $TASK_DETAILS | \
            jq -r '.tasks[0].attachments[0].details[] | select(.name=="networkInterfaceId") | .value')
        
        if [ ! -z "$ENI_ID" ]; then
            # Get public IP
            PUBLIC_IP=$(aws ec2 describe-network-interfaces \
                --network-interface-ids ${ENI_ID} \
                --region ${AWS_REGION} \
                --query 'NetworkInterfaces[0].Association.PublicIp' \
                --output text)
            
            if [ ! -z "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
                echo -e "    ${GREEN}Public IP: http://${PUBLIC_IP}:3000${NC}"
            fi
        fi
    done
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Deployment Complete!                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  View service: ${GREEN}aws ecs describe-services --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE}${NC}"
echo -e "  View logs:    ${GREEN}aws logs tail /ecs/demo-app --follow${NC}"
echo -e "  Scale:        ${GREEN}aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --desired-count 3${NC}"
