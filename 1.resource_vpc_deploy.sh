#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
source ./env

# Set variables
REGION=$RESOURCE_REGION
VPC_NAME=$RESOURCE_VPC_NAME

VPC_CIDR="10.1.0.0/16"
SUBNET1_CIDR="10.1.128.0/20"
SUBNET2_CIDR="10.1.144.0/20"
ENDPOINT_IP1="10.1.128.66"
ENDPOINT_IP2="10.1.144.66"

# Get availability zones
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Getting availability zones..."
AZ1=$(aws ec2 describe-availability-zones --region $REGION --query "AvailabilityZones[0].ZoneName" --output text)
AZ2=$(aws ec2 describe-availability-zones --region $REGION --query "AvailabilityZones[1].ZoneName" --output text)
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Using availability zones: $AZ1 and $AZ2"

# Create VPC
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating VPC: $VPC_NAME..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
  --query 'Vpc.VpcId' \
  --output text)
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC created successfully: $VPC_ID"

# Enable DNS support and DNS hostnames for the VPC
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Enabling DNS support and DNS hostnames for the VPC..."
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-support "{\"Value\":true}" \
  --region $REGION
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames "{\"Value\":true}" \
  --region $REGION
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC DNS settings updated"

# Create subnet 1
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating subnet 1: $SUBNET1_CIDR in $AZ1..."
SUBNET1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET1_CIDR \
  --availability-zone $AZ1 \
  --region $REGION \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-subnet-1}]" \
  --query 'Subnet.SubnetId' \
  --output text)
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Subnet 1 created successfully: $SUBNET1_ID"

# Create subnet 2
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating subnet 2: $SUBNET2_CIDR in $AZ2..."
SUBNET2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET2_CIDR \
  --availability-zone $AZ2 \
  --region $REGION \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-subnet-2}]" \
  --query 'Subnet.SubnetId' \
  --output text)
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Subnet 2 created successfully: $SUBNET2_ID"

# Create route table
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating route table..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$VPC_NAME-rt}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Route table created successfully: $ROUTE_TABLE_ID"

# Associate route table with subnet 1
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Associating route table with subnet 1..."
aws ec2 associate-route-table \
  --route-table-id $ROUTE_TABLE_ID \
  --subnet-id $SUBNET1_ID \
  --region $REGION \
  --no-cli-pager
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Route table associated with subnet 1 successfully"

# Associate route table with subnet 2
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Associating route table with subnet 2..."
aws ec2 associate-route-table \
  --route-table-id $ROUTE_TABLE_ID \
  --subnet-id $SUBNET2_ID \
  --region $REGION \
  --no-cli-pager
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Route table associated with subnet 2 successfully"

# Create security group
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating security group..."
SG_ID=$(aws ec2 create-security-group \
  --group-name "$VPC_NAME-sg" \
  --description "Security group for $VPC_NAME VPC" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$VPC_NAME-sg}]" \
  --query 'GroupId' \
  --output text)
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Security group created successfully: $SG_ID"

# Add security group rules
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Adding security group rules..."
# Rule 1: Allow access to port 443 from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region $REGION \
  --no-cli-pager
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Security group rule 1 added successfully: Allow access to port 443 from anywhere"

# Rule 2: Allow all traffic within the security group
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol all \
  --source-group $SG_ID \
  --region $REGION \
  --no-cli-pager
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Security group rule 2 added successfully: Allow all traffic within the security group"

# Update environment variables file
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Updating environment variables file..."
# Append to env
cat >> ./env << EOF
export RESOURCE_VPC_ID="$VPC_ID"
export RESOURCE_SUBNET1_ID="$SUBNET1_ID"
export RESOURCE_SUBNET2_ID="$SUBNET2_ID"
export RESOURCE_SG_ID="$SG_ID"
export RESOURCE_ROUTE_TABLE_ID="$ROUTE_TABLE_ID"
EOF

echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC creation completed"
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC ID: $VPC_ID"
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Subnet 1 ID: $SUBNET1_ID"
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Subnet 2 ID: $SUBNET2_ID"
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Route table ID: $ROUTE_TABLE_ID"
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Security group ID: $SG_ID"
echo -e "[${GREEN}1.resource_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Required resource information has been saved to ./env"
