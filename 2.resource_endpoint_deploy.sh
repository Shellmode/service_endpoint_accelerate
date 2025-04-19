#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
source ./env

REGION=$RESOURCE_REGION
VPC_ID=$RESOURCE_VPC_ID
SERVICE_NAME=$RESOURCE_SERVICE_NAME
SUBNET1_ID=$RESOURCE_SUBNET1_ID
SUBNET2_ID=$RESOURCE_SUBNET2_ID
SG_ID=$RESOURCE_SG_ID
VPC_ENDPOINT_NAME=$RESOURCE_VPC_ENDPOINT_NAME

# Create VPC Endpoint
echo -e "[${GREEN}2.resource_endpoint_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating VPC endpoint..."
aws ec2 create-vpc-endpoint \
    --region $REGION \
    --vpc-id $VPC_ID \
    --service-name $SERVICE_NAME \
    --vpc-endpoint-type Interface \
    --subnet-ids $SUBNET1_ID $SUBNET2_ID \
    --security-group-ids $SG_ID \
    --private-dns-enabled \
    --ip-address-type ipv4 \
    --dns-options "DnsRecordIpType=ipv4" \
    --tag-specifications "ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=$VPC_ENDPOINT_NAME}]" \
    --subnet-configurations "[{\"SubnetId\":\"$SUBNET1_ID\",\"Ipv4\":\"10.1.128.66\"},{\"SubnetId\":\"$SUBNET2_ID\",\"Ipv4\":\"10.1.144.66\"}]"

# Get VPC Endpoint ID
VPC_ENDPOINT_ID=$(aws ec2 describe-vpc-endpoints \
    --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=service-name,Values=$SERVICE_NAME" \
    --query "VpcEndpoints[0].VpcEndpointId" \
    --output text)

# Don't wait for VPC Endpoint creation to complete, just record the ID
echo -e "[${GREEN}2.resource_endpoint_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC Endpoint is being created, ID: $VPC_ENDPOINT_ID"

# Update environment variables file
echo -e "[${GREEN}2.resource_endpoint_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Updating environment variables file..."
# Append to env
cat >> ./env << EOF
export RESOURCE_VPC_ENDPOINT_ID="$VPC_ENDPOINT_ID"
EOF

echo -e "[${GREEN}2.resource_endpoint_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC Endpoint creation has been initiated"
echo -e "[${GREEN}2.resource_endpoint_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC Endpoint ID: $VPC_ENDPOINT_ID"
