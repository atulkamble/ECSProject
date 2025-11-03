```
// Create IAM Role for ECS 

ECSClusterRole

// create ECS Cluster 

// on terminal 

aws ecs list-clusters

aws ecs describe-clusters --clusters tough-bird-qu9zk2

# Check service status
aws ecs describe-services --cluster demo-cluster --services demo-service

# View logs
aws logs tail /ecs/demo-app --follow

# Test the application
curl http://<PUBLIC_IP>:3000/health
```
