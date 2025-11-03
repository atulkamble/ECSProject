# AWS ECS Project - Complete Guide

This project demonstrates how to deploy a containerized Node.js application to AWS ECS (Elastic Container Service).

## Project Structure

```
ECSProject/
├── app/
│   ├── index.js              # Main application
│   ├── package.json          # Node.js dependencies
│   └── .dockerignore         # Docker ignore patterns
├── infrastructure/
│   ├── task-definition.json  # ECS task definition
│   ├── service.json          # ECS service definition
│   └── ecs-params.yml        # ECS CLI parameters
├── Dockerfile                # Container configuration
├── docker-compose.yml        # Local development
├── .env.example              # Environment variables template
├── scripts/
│   ├── setup-aws.sh         # AWS setup script
│   ├── build-push.sh        # Build and push Docker image
│   └── deploy-ecs.sh        # Deploy to ECS
└── README.md                # This file
```

## Prerequisites

- AWS Account
- AWS CLI installed and configured
- Docker installed
- Node.js 18+ (for local development)
- ECS CLI (optional, for simplified deployment)

## Quick Start

### 1. Local Development

```bash
# Install dependencies
cd app
npm install

# Run locally
npm start

# Or use Docker Compose
docker-compose up
```

### 2. AWS Setup

```bash
# Configure AWS CLI
aws configure

# Run setup script
chmod +x scripts/setup-aws.sh
./scripts/setup-aws.sh
```

### 3. Build and Push Docker Image

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh
```

### 4. Deploy to ECS

```bash
chmod +x scripts/deploy-ecs.sh
./scripts/deploy-ecs.sh
```

## Detailed Steps

### Step 1: Configure AWS CLI

```bash
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

### Step 2: Create ECR Repository

```bash
# Create repository
aws ecr create-repository \
    --repository-name ecs-demo-app \
    --region us-east-1

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin \
    <your-account-id>.dkr.ecr.us-east-1.amazonaws.com
```

### Step 3: Build Docker Image

```bash
# Build the image
docker build -t ecs-demo-app .

# Tag the image
docker tag ecs-demo-app:latest \
    <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-demo-app:latest

# Push to ECR
docker push <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-demo-app:latest
```

### Step 4: Create ECS Cluster

```bash
# Create cluster
aws ecs create-cluster \
    --cluster-name demo-cluster \
    --region us-east-1
```

### Step 5: Register Task Definition

```bash
# Register task definition
aws ecs register-task-definition \
    --cli-input-json file://infrastructure/task-definition.json \
    --region us-east-1
```

### Step 6: Create ECS Service

```bash
# Create service (requires VPC and security groups)
aws ecs create-service \
    --cluster demo-cluster \
    --service-name demo-service \
    --task-definition ecs-demo-app:1 \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
    --region us-east-1
```

### Step 7: Verify Deployment

```bash
# Check cluster status
aws ecs describe-clusters --clusters demo-cluster

# Check service status
aws ecs describe-services \
    --cluster demo-cluster \
    --services demo-service

# List running tasks
aws ecs list-tasks --cluster demo-cluster

# Get task details
aws ecs describe-tasks \
    --cluster demo-cluster \
    --tasks <task-arn>
```

## Environment Variables

Copy `.env.example` to `.env` and update:

```bash
cp .env.example .env
```

Required variables:
- `AWS_ACCOUNT_ID`: Your AWS account ID
- `AWS_REGION`: AWS region (e.g., us-east-1)
- `ECR_REPOSITORY`: ECR repository name
- `ECS_CLUSTER`: ECS cluster name
- `ECS_SERVICE`: ECS service name

## Useful Commands

### Docker Commands

```bash
# Build image
docker build -t ecs-demo-app .

# Run locally
docker run -p 3000:3000 ecs-demo-app

# View running containers
docker ps

# Stop container
docker stop <container-id>
```

### AWS ECS Commands

```bash
# Update service with new image
aws ecs update-service \
    --cluster demo-cluster \
    --service demo-service \
    --force-new-deployment

# Scale service
aws ecs update-service \
    --cluster demo-cluster \
    --service demo-service \
    --desired-count 3

# View logs (requires CloudWatch Logs configuration)
aws logs tail /ecs/demo-app --follow

# Delete service
aws ecs delete-service \
    --cluster demo-cluster \
    --service demo-service \
    --force

# Delete cluster
aws ecs delete-cluster --cluster demo-cluster
```

### Monitoring

```bash
# View service events
aws ecs describe-services \
    --cluster demo-cluster \
    --services demo-service \
    --query 'services[0].events' \
    --output table

# View task logs
aws ecs describe-tasks \
    --cluster demo-cluster \
    --tasks <task-arn>
```

## Troubleshooting

### Common Issues

1. **Task fails to start**: Check CloudWatch logs and task definition
2. **Cannot pull image**: Verify ECR permissions and login
3. **Service stuck in pending**: Check VPC, subnets, and security groups
4. **Health check fails**: Verify application port and health endpoint

### Debug Commands

```bash
# Get task failure reason
aws ecs describe-tasks \
    --cluster demo-cluster \
    --tasks <task-arn> \
    --query 'tasks[0].stoppedReason'

# Check CloudWatch logs
aws logs get-log-events \
    --log-group-name /ecs/demo-app \
    --log-stream-name ecs/demo-app/<task-id>
```

## Clean Up

```bash
# Delete service
aws ecs delete-service --cluster demo-cluster --service demo-service --force

# Wait for service deletion
aws ecs wait services-inactive --cluster demo-cluster --services demo-service

# Delete cluster
aws ecs delete-cluster --cluster demo-cluster

# Delete ECR repository
aws ecr delete-repository --repository-name ecs-demo-app --force

# Delete CloudWatch log group
aws logs delete-log-group --log-group-name /ecs/demo-app
```

## Cost Optimization

- Use Fargate Spot for non-critical workloads
- Right-size your task CPU and memory
- Use Auto Scaling for variable workloads
- Enable Container Insights only when needed
- Use ECR lifecycle policies to clean old images

## Security Best Practices

- Use IAM roles for task execution
- Store secrets in AWS Secrets Manager or Parameter Store
- Enable VPC Flow Logs
- Use private subnets with NAT Gateway
- Implement least privilege security groups
- Enable ECR image scanning

## Next Steps

- Add Application Load Balancer
- Implement Auto Scaling
- Set up CI/CD pipeline with GitHub Actions
- Add monitoring with CloudWatch
- Implement blue/green deployments
- Add database integration (RDS)

## Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)

## License

MIT
