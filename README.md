# AWS Service Endpoint Acceleration Solution

This project provides a solution to accelerate AWS service endpoints across regions by leveraging AWS's backbone network. It establishes connectivity between a client located outside AWS and an AWS service endpoint in a different region through VPC peering and Network Load Balancer (NLB).

## Overview

When clients outside AWS need to access AWS services in distant regions, network latency can significantly impact performance. This solution addresses this challenge by:

1. Creating a VPC in the service endpoint region (e.g., Jakarta)
2. Setting up a VPC endpoint for the target service (e.g., SageMaker)
3. Creating another VPC in a region closer to the client (e.g., Singapore)
4. Establishing VPC peering between the two VPCs
5. Deploying an internet-facing NLB in the client-proximate region
6. Configuring routing to direct traffic through AWS's backbone network

## Architecture

```
Client (Singapore, non-AWS) → NLB (ap-southeast-1) → VPC Peering → VPC Endpoint → SageMaker (ap-southeast-3)
```

### Components:

- **Resource VPC**: Created in the service endpoint region (ap-southeast-3/Jakarta)
- **Resource VPC Endpoint**: Interface endpoint for the target AWS service
- **Expose VPC**: Created in the region closer to the client (ap-southeast-1/Singapore)
- **VPC Peering**: Connects the Resource VPC and Expose VPC
- **Network Load Balancer**: Deployed in the Expose VPC, accessible from the internet

## Use Case

This demo showcases acceleration for a client located in Singapore (non-AWS server) accessing a SageMaker endpoint in Jakarta (ap-southeast-3).

## Prerequisites

- AWS CLI configured with appropriate permissions
- Bash shell environment

## Deployment

1. Configure parameters in `env.template`:
   ```
   RESOURCE_REGION="ap-southeast-3"  # Region where the service endpoint is located
   RESOURCE_VPC_NAME="sagemaker-resource-vpc"  # VPC name for the resource region
   RESOURCE_SERVICE_NAME="com.amazonaws.$RESOURCE_REGION.sagemaker.runtime"  # Service endpoint to accelerate
   RESOURCE_VPC_ENDPOINT_NAME="sagemaker-vpc-endpoint"  # VPC endpoint name
   EXPOSE_REGION="ap-southeast-1"  # Region closer to the client
   EXPOSE_VPC_NAME="sagemaker-expose-vpc"  # VPC name for the expose region
   ```

2. Run the deployment script:
   ```bash
   ./deploy_all.sh
   ```

3. The deployment process will:
   - Create all necessary resources
   - Configure networking and security
   - Save resource IDs to the `env` file
   - Output the NLB DNS name for client access

## Cleanup

To remove all created resources:

```bash
./cleanup.sh
```

This script will delete all resources created during deployment, using the information stored in the `env` file.

## Deployment Process

The solution is deployed through a series of scripts executed in sequence:

1. `1.resource_vpc_deploy.sh`: Creates the VPC in the service endpoint region
2. `2.resource_endpoint_deploy.sh`: Sets up the VPC endpoint for the target service
3. `3.expose_vpc_deploy.sh`: Creates the VPC in the client-proximate region
4. `4.vpc_peering.sh`: Establishes VPC peering between the two VPCs
5. `5.update_route_table.sh`: Updates route tables to enable traffic flow
6. `6.expose_nlb_deploy.sh`: Deploys the NLB in the client-proximate region

## Notes

- This solution is designed for scenarios where clients are in fixed locations
- It leverages AWS's global backbone network for improved performance
- The solution can be adapted for different AWS services by modifying the `RESOURCE_SERVICE_NAME` parameter
