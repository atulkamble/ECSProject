# AWS ECS Deployment Guide

## Complete Step-by-Step Deployment

### Prerequisites Setup

#### 1. Install AWS CLI

**macOS:**
```bash
brew install awscli
```

**Verify installation:**
```bash
aws --version
```

#### 2. Install Docker

**macOS:**
```bash
brew install --cask docker
```

Or download from [Docker Desktop](https://www.docker.com/products/docker-desktop)

**Verify installation:**
```bash
docker --version
```

#### 3. Configure AWS Credentials

```bash
aws configure
```

Enter your credentials:
- **AWS Access Key ID**: Your AWS access key
- **AWS Secret Access Key**: Your AWS secret key
- **Default region**: us-east-1 (or your preferred region)
- **Default output format**: json

**Verify credentials:**
```bash
aws sts get-caller-identity
```

---

## Deployment Steps

### Step 1: Prepare the Project

```bash
# Navigate to project directory
cd /Users/atul/Downloads/ECSProject

# Copy environment template
cp .env.example .env

# Edit .env file with your AWS details
# You'll need to update AWS_ACCOUNT_ID and AWS_REGION
```

Get your AWS Account ID:
```bash
aws sts get-caller-identity --query Account --output text
```

### Step 2: Test Locally (Optional but Recommended)

```bash
# Install Node.js dependencies
cd app
npm install

# Run the application
npm start
```

Visit `http://localhost:3000` to verify the app works.

**Or use Docker:**
```bash
# Build and run with Docker Compose
docker-compose up

# Access at http://localhost:3000
```

### Step 3: Run AWS Setup Script

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run setup
./scripts/setup-aws.sh
```

This script will:
- ✓ Create ECR repository
- ✓ Create ECS cluster
- ✓ Create IAM roles
- ✓ Create CloudWatch log group
- ✓ Create security group
- ✓ Display VPC and subnet information

**Update .env file** with the VPC, subnet, and security group information displayed.

### Step 4: Build and Push Docker Image

```bash
./scripts/build-push.sh
```

This will:
- ✓ Login to ECR
- ✓ Build Docker image
- ✓ Tag image with latest and timestamp
- ✓ Push to ECR

### Step 5: Deploy to ECS

```bash
./scripts/deploy-ecs.sh
```

This will:
- ✓ Register task definition
- ✓ Create or update ECS service
- ✓ Wait for service to stabilize
- ✓ Display public IP addresses

---

## Manual Deployment (Alternative)

### 1. Create ECR Repository

```bash
aws ecr create-repository \
    --repository-name ecs-demo-app \
    --region us-east-1
```

### 2. Login to ECR

```bash
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin \
    <YOUR_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
```

### 3. Build and Push Image

```bash
# Build
docker build -t ecs-demo-app .

# Tag
docker tag ecs-demo-app:latest \
    <YOUR_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/ecs-demo-app:latest

# Push
docker push <YOUR_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/ecs-demo-app:latest
```

### 4. Create ECS Cluster

```bash
aws ecs create-cluster \
    --cluster-name demo-cluster \
    --region us-east-1
```

### 5. Create IAM Roles

**Task Execution Role:**
```bash
# Create trust policy file
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document file://trust-policy.json

# Attach policy
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

### 6. Register Task Definition

```bash
# Update infrastructure/task-definition.json with your AWS_ACCOUNT_ID and AWS_REGION
# Then register:
aws ecs register-task-definition \
    --cli-input-json file://infrastructure/task-definition.json
```

### 7. Create ECS Service

```bash
aws ecs create-service \
    --cluster demo-cluster \
    --service-name demo-service \
    --task-definition ecs-demo-app:1 \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx,subnet-yyy],securityGroups=[sg-xxx],assignPublicIp=ENABLED}"
```

---

## Verification Commands

### Check Cluster Status
```bash
aws ecs describe-clusters --clusters demo-cluster
```

### Check Service Status
```bash
aws ecs describe-services \
    --cluster demo-cluster \
    --services demo-service
```

### List Running Tasks
```bash
aws ecs list-tasks --cluster demo-cluster
```

### Get Task Details
```bash
aws ecs describe-tasks \
    --cluster demo-cluster \
    --tasks <TASK_ARN>
```

### View Logs
```bash
aws logs tail /ecs/demo-app --follow
```

### Get Public IP of Tasks
```bash
# Get task ARN
TASK_ARN=$(aws ecs list-tasks --cluster demo-cluster --service demo-service --query 'taskArns[0]' --output text)

# Get ENI ID
ENI_ID=$(aws ecs describe-tasks --cluster demo-cluster --tasks $TASK_ARN --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)

# Get Public IP
aws ec2 describe-network-interfaces \
    --network-interface-ids $ENI_ID \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text
```

---

## Testing the Deployment

### Test Health Endpoint
```bash
curl http://<PUBLIC_IP>:3000/health
```

### Test Root Endpoint
```bash
curl http://<PUBLIC_IP>:3000/
```

### Test API Info
```bash
curl http://<PUBLIC_IP>:3000/api/info
```

### Test Echo Endpoint
```bash
curl -X POST http://<PUBLIC_IP>:3000/api/echo \
    -H "Content-Type: application/json" \
    -d '{"message": "Hello ECS!"}'
```

---

## Update Deployment

### Deploy New Version
```bash
# Make code changes
# Build and push new image
./scripts/build-push.sh

# Force new deployment
aws ecs update-service \
    --cluster demo-cluster \
    --service demo-service \
    --force-new-deployment
```

### Scale Service
```bash
aws ecs update-service \
    --cluster demo-cluster \
    --service demo-service \
    --desired-count 3
```

---

## Monitoring

### View Service Events
```bash
aws ecs describe-services \
    --cluster demo-cluster \
    --services demo-service \
    --query 'services[0].events[0:5]'
```

### CloudWatch Metrics
```bash
# CPU Utilization
aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name CPUUtilization \
    --dimensions Name=ClusterName,Value=demo-cluster Name=ServiceName,Value=demo-service \
    --start-time 2024-01-01T00:00:00Z \
    --end-time 2024-01-01T23:59:59Z \
    --period 3600 \
    --statistics Average
```

---

## Troubleshooting

### Common Issues

**1. Task fails to start**
```bash
# Check stopped tasks
aws ecs describe-tasks \
    --cluster demo-cluster \
    --tasks <TASK_ARN> \
    --query 'tasks[0].stoppedReason'
```

**2. Cannot pull image**
```bash
# Verify ECR permissions
aws ecr get-login-password --region us-east-1

# Check task execution role has ECR permissions
```

**3. Health check fails**
```bash
# Check container logs
aws logs tail /ecs/demo-app --follow

# Verify security group allows traffic on port 3000
```

**4. Service stuck in pending**
```bash
# Check service events
aws ecs describe-services \
    --cluster demo-cluster \
    --services demo-service \
    --query 'services[0].events'
```

---

## Clean Up Resources

### Delete Service
```bash
aws ecs delete-service \
    --cluster demo-cluster \
    --service demo-service \
    --force
```

### Wait for Service Deletion
```bash
aws ecs wait services-inactive \
    --cluster demo-cluster \
    --services demo-service
```

### Delete Cluster
```bash
aws ecs delete-cluster --cluster demo-cluster
```

### Delete ECR Repository
```bash
aws ecr delete-repository \
    --repository-name ecs-demo-app \
    --force
```

### Delete CloudWatch Logs
```bash
aws logs delete-log-group --log-group-name /ecs/demo-app
```

### Delete Security Group
```bash
aws ec2 delete-security-group --group-id <SG_ID>
```

---

## Cost Estimation

**Fargate Pricing (us-east-1):**
- vCPU: $0.04048 per vCPU per hour
- Memory: $0.004445 per GB per hour

**For this configuration (0.25 vCPU, 0.5 GB RAM, 2 tasks):**
- Per task per hour: ~$0.012
- Per task per month: ~$8.64
- For 2 tasks per month: ~$17.28

**Additional costs:**
- ECR storage: $0.10 per GB per month
- Data transfer: Varies by usage
- CloudWatch Logs: $0.50 per GB ingested

---

## Next Steps

1. **Add Load Balancer**: Distribute traffic across tasks
2. **Configure Auto Scaling**: Scale based on CPU/memory/requests
3. **Set up CI/CD**: Automate deployments with GitHub Actions
4. **Add Database**: Connect to RDS or DynamoDB
5. **Implement Monitoring**: Set up CloudWatch dashboards and alarms
6. **Enable Container Insights**: Get detailed container metrics
7. **Configure Service Discovery**: Use AWS Cloud Map
8. **Implement Blue/Green Deployments**: Use CodeDeploy

---

## Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Fargate Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [ECR Documentation](https://docs.aws.amazon.com/ecr/)
