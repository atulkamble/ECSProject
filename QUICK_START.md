# Quick Start Guide

Get your application running on AWS ECS in 5 minutes!

## Prerequisites

- AWS Account
- AWS CLI installed (`brew install awscli`)
- Docker installed (`brew install --cask docker`)

## 5-Minute Deployment

### 1. Configure AWS (1 minute)

```bash
aws configure
# Enter your AWS credentials
```

### 2. Setup Environment (1 minute)

```bash
cd /Users/atul/Downloads/ECSProject

# Copy environment file
cp .env.example .env

# Get your AWS Account ID
aws sts get-caller-identity --query Account --output text

# Edit .env and update:
# - AWS_ACCOUNT_ID (from above)
# - AWS_REGION (e.g., us-east-1)
```

### 3. Run Setup Script (1 minute)

```bash
chmod +x scripts/*.sh
./scripts/setup-aws.sh
```

**Important**: After this completes, update your `.env` file with the VPC, subnet, and security group information displayed.

### 4. Build and Push (1 minute)

```bash
./scripts/build-push.sh
```

### 5. Deploy to ECS (1 minute)

```bash
./scripts/deploy-ecs.sh
```

## Access Your Application

The deploy script will display the public IP addresses. Access your app at:

```
http://<PUBLIC_IP>:3000
```

### Test Endpoints

```bash
# Health check
curl http://<PUBLIC_IP>:3000/health

# Application info
curl http://<PUBLIC_IP>:3000/

# API info
curl http://<PUBLIC_IP>:3000/api/info
```

## What's Next?

- View the full [README.md](README.md) for detailed documentation
- Check [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for manual deployment steps
- Monitor your application in the AWS Console

## Troubleshooting

**If deployment fails:**

1. Check AWS credentials:
   ```bash
   aws sts get-caller-identity
   ```

2. Verify Docker is running:
   ```bash
   docker ps
   ```

3. Check service status:
   ```bash
   aws ecs describe-services --cluster demo-cluster --services demo-service
   ```

4. View logs:
   ```bash
   aws logs tail /ecs/demo-app --follow
   ```

## Clean Up

When you're done testing:

```bash
# Delete service
aws ecs delete-service --cluster demo-cluster --service demo-service --force

# Delete cluster
aws ecs delete-cluster --cluster demo-cluster

# Delete ECR repository
aws ecr delete-repository --repository-name ecs-demo-app --force
```

---

For detailed information, see the complete [README.md](README.md).
