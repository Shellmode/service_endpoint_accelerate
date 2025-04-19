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

Upon successful deployment, the script will output the NLB DNS name for client access:

```bash
===== Deployment completed successfully =====
Thu Apr 17 11:47:44 CST 2025: All scripts have been executed
NLB URL: https://service-peering-nlb-1234567890.elb.ap-southeast-1.amazonaws.com
```

## Deployment Process

The solution is deployed through a series of scripts executed in sequence:

1. `1.resource_vpc_deploy.sh`: Creates the VPC in the service endpoint region
2. `2.resource_endpoint_deploy.sh`: Sets up the VPC endpoint for the target service
3. `3.expose_vpc_deploy.sh`: Creates the VPC in the client-proximate region
4. `4.vpc_peering.sh`: Establishes VPC peering between the two VPCs
5. `5.update_route_table.sh`: Updates route tables to enable traffic flow
6. `6.expose_nlb_deploy.sh`: Deploys the NLB in the client-proximate region

## How to Use the Deployed NLB for Acceleration in Code

### Option 1: Modify endpoint_url and Skip TLS Certificate Verification

Principle:
* The SDK accesses the NLB address as the service endpoint
* TLS certificate verification needs to be skipped because the NLB only forwards network traffic, but the SDK accesses an HTTPS address on the NLB, which would fail TLS certificate validation

Python demo:

```python
import urllib3
import boto3
urllib3.disable_warnings()

...
sm_client = boto3.client(
    'sagemaker-runtime',
    region_name="ap-southeast-3", # region where the SageMaker endpoint is located
    endpoint_url="https://service-peering-nlb-1234567890.elb.ap-southeast-1.amazonaws.com", # accelerated NLB URL
    verify = False # skip TLS certificate verification
)
...
```

Golang demo:

```go
http.DefaultTransport.(*http.Transport).TLSClientConfig = &tls.Config{InsecureSkipVerify: true}
// Create AWS session
sess := session.Must(session.NewSession(&aws.Config{
  Region:   aws.String("ap-southeast-3"),
  Endpoint: aws.String("https://service-peering-nlb-1234567890.elb.ap-southeast-1.amazonaws.com"),
}))

// Create SageMaker Runtime client
sagemakerClient := sagemakerruntime.New(sess)
```

### Option 2: Modify Host

Directly modify the host of the original service endpoint to the NLB's IP address (it's recommended to bind an EIP to the NLB in this case), for example:

```bash
cat /etc/hosts

xx.xx.yy.yy runtime.sagemaker.ap-southeast-3.amazonaws.com
```

With this method, you don't need to skip TLS certificate verification in your code.

## Cleanup

To remove all created resources:

```bash
./cleanup.sh
```

This script will delete all resources created during deployment, using the information stored in the `env` file.

## Notes

- This solution is designed for scenarios where clients are in fixed locations
- It leverages AWS's global backbone network for improved performance
- The solution can be adapted for different AWS services by modifying the `RESOURCE_SERVICE_NAME` parameter
