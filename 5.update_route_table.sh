#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
source ./env

echo -e "[${GREEN}5.update_route_table.sh${NC}] Starting to update route tables to enable traffic through VPC peering connection..."

# Get VPC CIDR blocks
echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Getting resource VPC CIDR block..."
RESOURCE_VPC_CIDR=$(aws ec2 describe-vpcs \
    --region $RESOURCE_REGION \
    --vpc-ids $RESOURCE_VPC_ID \
    --query 'Vpcs[0].CidrBlock' \
    --output text)

echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Getting expose VPC CIDR block..."
EXPOSE_VPC_CIDR=$(aws ec2 describe-vpcs \
    --region $EXPOSE_REGION \
    --vpc-ids $EXPOSE_VPC_ID \
    --query 'Vpcs[0].CidrBlock' \
    --output text)

echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Resource VPC CIDR: $RESOURCE_VPC_CIDR"
echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Expose VPC CIDR: $EXPOSE_VPC_CIDR"

# Update resource VPC route table
echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Updating resource VPC route table ($RESOURCE_ROUTE_TABLE_ID), adding route to expose VPC..."
aws ec2 create-route \
    --region $RESOURCE_REGION \
    --route-table-id $RESOURCE_ROUTE_TABLE_ID \
    --destination-cidr-block $EXPOSE_VPC_CIDR \
    --vpc-peering-connection-id $VPC_PEERING_ID

echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Resource VPC route table updated successfully"

# Update expose VPC public route table
echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Updating expose VPC public route table ($EXPOSE_PUBLIC_ROUTE_TABLE_ID), adding route to resource VPC..."
aws ec2 create-route \
    --region $EXPOSE_REGION \
    --route-table-id $EXPOSE_PUBLIC_ROUTE_TABLE_ID \
    --destination-cidr-block $RESOURCE_VPC_CIDR \
    --vpc-peering-connection-id $VPC_PEERING_ID

echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Expose VPC public route table updated successfully"

# Update expose VPC private route table
echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Updating expose VPC private route table ($EXPOSE_PRIVATE_ROUTE_TABLE_ID), adding route to resource VPC..."
aws ec2 create-route \
    --region $EXPOSE_REGION \
    --route-table-id $EXPOSE_PRIVATE_ROUTE_TABLE_ID \
    --destination-cidr-block $RESOURCE_VPC_CIDR \
    --vpc-peering-connection-id $VPC_PEERING_ID
echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Expose VPC private route table updated successfully"

echo -e "[${GREEN}5.update_route_table.sh${NC}] Route tables update completed! The two VPCs can now communicate with each other through the VPC peering connection."
