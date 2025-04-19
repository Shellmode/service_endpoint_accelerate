#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
source ./env

# Set variables
REGION=$EXPOSE_REGION
VPC_NAME=$EXPOSE_VPC_NAME

VPC_CIDR="10.2.0.0/16"
PUBLIC_SUBNET1_CIDR="10.2.0.0/20"
PRIVATE_SUBNET1_CIDR="10.2.16.0/20"
PUBLIC_SUBNET2_CIDR="10.2.32.0/20"
PRIVATE_SUBNET2_CIDR="10.2.48.0/20"

# Get availability zones
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Getting availability zones..."
AZ1=$(aws ec2 describe-availability-zones --region $REGION --query "AvailabilityZones[0].ZoneName" --output text)
AZ2=$(aws ec2 describe-availability-zones --region $REGION --query "AvailabilityZones[1].ZoneName" --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Using availability zones: $AZ1 and $AZ2"

# Create VPC
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating VPC: $VPC_NAME..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
  --query 'Vpc.VpcId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC created successfully: $VPC_ID"

# Enable DNS support and DNS hostnames for the VPC
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Enabling DNS support and DNS hostnames for the VPC..."
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-support "{\"Value\":true}" \
  --region $REGION
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames "{\"Value\":true}" \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC DNS settings updated"

# Create internet gateway
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating internet gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --region $REGION \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$VPC_NAME-igw}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Internet gateway created successfully: $IGW_ID"

# Attach internet gateway to VPC
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Attaching internet gateway to VPC..."
aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Internet gateway attached to VPC"

# Create public subnet 1
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating public subnet 1: $PUBLIC_SUBNET1_CIDR in $AZ1..."
PUBLIC_SUBNET1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET1_CIDR \
  --availability-zone $AZ1 \
  --region $REGION \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-public-subnet-1}]" \
  --query 'Subnet.SubnetId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Public subnet 1 created successfully: $PUBLIC_SUBNET1_ID"

# Create private subnet 1
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating private subnet 1: $PRIVATE_SUBNET1_CIDR in $AZ1..."
PRIVATE_SUBNET1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET1_CIDR \
  --availability-zone $AZ1 \
  --region $REGION \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-private-subnet-1}]" \
  --query 'Subnet.SubnetId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Private subnet 1 created successfully: $PRIVATE_SUBNET1_ID"

# Create public subnet 2
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating public subnet 2: $PUBLIC_SUBNET2_CIDR in $AZ2..."
PUBLIC_SUBNET2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET2_CIDR \
  --availability-zone $AZ2 \
  --region $REGION \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-public-subnet-2}]" \
  --query 'Subnet.SubnetId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Public subnet 2 created successfully: $PUBLIC_SUBNET2_ID"

# Create private subnet 2
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating private subnet 2: $PRIVATE_SUBNET2_CIDR in $AZ2..."
PRIVATE_SUBNET2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET2_CIDR \
  --availability-zone $AZ2 \
  --region $REGION \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-private-subnet-2}]" \
  --query 'Subnet.SubnetId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Private subnet 2 created successfully: $PRIVATE_SUBNET2_ID"

# Create public route table
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating public route table..."
PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$VPC_NAME-public-rt}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Public route table created successfully: $PUBLIC_ROUTE_TABLE_ID"

# Create private route table
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating private route table..."
PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$VPC_NAME-private-rt}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Private route table created successfully: $PRIVATE_ROUTE_TABLE_ID"

# Add default route to internet gateway in public route table
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Adding default route to internet gateway in public route table..."
aws ec2 create-route \
  --route-table-id $PUBLIC_ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Default route added successfully to public route table"

# Associate public route table with public subnets
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Associating public route table with public subnet 1..."
aws ec2 associate-route-table \
  --route-table-id $PUBLIC_ROUTE_TABLE_ID \
  --subnet-id $PUBLIC_SUBNET1_ID \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Public route table associated with public subnet 1 successfully"

echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Associating public route table with public subnet 2..."
aws ec2 associate-route-table \
  --route-table-id $PUBLIC_ROUTE_TABLE_ID \
  --subnet-id $PUBLIC_SUBNET2_ID \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Public route table associated with public subnet 2 successfully"

# Associate private route table with private subnets
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Associating private route table with private subnet 1..."
aws ec2 associate-route-table \
  --route-table-id $PRIVATE_ROUTE_TABLE_ID \
  --subnet-id $PRIVATE_SUBNET1_ID \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Private route table associated with private subnet 1 successfully"

echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Associating private route table with private subnet 2..."
aws ec2 associate-route-table \
  --route-table-id $PRIVATE_ROUTE_TABLE_ID \
  --subnet-id $PRIVATE_SUBNET2_ID \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Private route table associated with private subnet 2 successfully"

# Update environment variables file
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Updating environment variables file..."
cat >> ./env << EOF
export EXPOSE_VPC_ID="$VPC_ID"
export EXPOSE_PUBLIC_SUBNET1_ID="$PUBLIC_SUBNET1_ID"
export EXPOSE_PRIVATE_SUBNET1_ID="$PRIVATE_SUBNET1_ID"
export EXPOSE_PUBLIC_SUBNET2_ID="$PUBLIC_SUBNET2_ID"
export EXPOSE_PRIVATE_SUBNET2_ID="$PRIVATE_SUBNET2_ID"
export EXPOSE_PUBLIC_ROUTE_TABLE_ID="$PUBLIC_ROUTE_TABLE_ID"
export EXPOSE_PRIVATE_ROUTE_TABLE_ID="$PRIVATE_ROUTE_TABLE_ID"
export EXPOSE_IGW_ID="$IGW_ID"
EOF

echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC creation completed"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC ID: $VPC_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Internet Gateway ID: $IGW_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Public Subnet 1 ID: $PUBLIC_SUBNET1_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Private Subnet 1 ID: $PRIVATE_SUBNET1_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Public Subnet 2 ID: $PUBLIC_SUBNET2_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Private Subnet 2 ID: $PRIVATE_SUBNET2_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Public Route Table ID: $PUBLIC_ROUTE_TABLE_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Private Route Table ID: $PRIVATE_ROUTE_TABLE_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Required resource information has been saved to ./env"
