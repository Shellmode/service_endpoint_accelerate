#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
source ./env

# 设置变量
REGION=$EXPOSE_REGION
VPC_NAME=$EXPOSE_VPC_NAME

VPC_CIDR="10.2.0.0/16"
PUBLIC_SUBNET1_CIDR="10.2.0.0/20"
PRIVATE_SUBNET1_CIDR="10.2.16.0/20"
PUBLIC_SUBNET2_CIDR="10.2.32.0/20"
PRIVATE_SUBNET2_CIDR="10.2.48.0/20"

# 获取可用区
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 获取可用区..."
AZ1=$(aws ec2 describe-availability-zones --region $REGION --query "AvailabilityZones[0].ZoneName" --output text)
AZ2=$(aws ec2 describe-availability-zones --region $REGION --query "AvailabilityZones[1].ZoneName" --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 使用可用区: $AZ1 和 $AZ2"

# 创建 VPC
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 创建 VPC: $VPC_NAME..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
  --query 'Vpc.VpcId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC 创建成功: $VPC_ID"

# 启用 VPC 的 DNS 支持和 DNS 主机名
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 启用 VPC 的 DNS 支持和 DNS 主机名..."
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-support "{\"Value\":true}" \
  --region $REGION
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames "{\"Value\":true}" \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC DNS 设置已更新"

# 创建互联网网关
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 创建互联网网关..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --region $REGION \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$VPC_NAME-igw}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 互联网网关创建成功: $IGW_ID"

# 将互联网网关附加到 VPC
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 将互联网网关附加到 VPC..."
aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 互联网网关已附加到 VPC"

# 创建公共子网1
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 创建公共子网1: $PUBLIC_SUBNET1_CIDR 在 $AZ1..."
PUBLIC_SUBNET1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET1_CIDR \
  --availability-zone $AZ1 \
  --region $REGION \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-public-subnet-1}]" \
  --query 'Subnet.SubnetId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 公共子网1创建成功: $PUBLIC_SUBNET1_ID"

# 创建私有子网1
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 创建私有子网1: $PRIVATE_SUBNET1_CIDR 在 $AZ1..."
PRIVATE_SUBNET1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET1_CIDR \
  --availability-zone $AZ1 \
  --region $REGION \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-private-subnet-1}]" \
  --query 'Subnet.SubnetId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 私有子网1创建成功: $PRIVATE_SUBNET1_ID"

# 创建公共子网2
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 创建公共子网2: $PUBLIC_SUBNET2_CIDR 在 $AZ2..."
PUBLIC_SUBNET2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET2_CIDR \
  --availability-zone $AZ2 \
  --region $REGION \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-public-subnet-2}]" \
  --query 'Subnet.SubnetId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 公共子网2创建成功: $PUBLIC_SUBNET2_ID"

# 创建私有子网2
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 创建私有子网2: $PRIVATE_SUBNET2_CIDR 在 $AZ2..."
PRIVATE_SUBNET2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET2_CIDR \
  --availability-zone $AZ2 \
  --region $REGION \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-private-subnet-2}]" \
  --query 'Subnet.SubnetId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 私有子网2创建成功: $PRIVATE_SUBNET2_ID"

# 创建公共路由表
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 创建公共路由表..."
PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$VPC_NAME-public-rt}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 公共路由表创建成功: $PUBLIC_ROUTE_TABLE_ID"

# 创建私有路由表
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 创建私有路由表..."
PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$VPC_NAME-private-rt}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 私有路由表创建成功: $PRIVATE_ROUTE_TABLE_ID"

# 添加公共路由表的默认路由到互联网网关
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 添加公共路由表的默认路由到互联网网关..."
aws ec2 create-route \
  --route-table-id $PUBLIC_ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 公共路由表默认路由添加成功"

# 关联公共路由表到公共子网
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 关联公共路由表到公共子网1..."
aws ec2 associate-route-table \
  --route-table-id $PUBLIC_ROUTE_TABLE_ID \
  --subnet-id $PUBLIC_SUBNET1_ID \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 公共路由表关联到公共子网1成功"

echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 关联公共路由表到公共子网2..."
aws ec2 associate-route-table \
  --route-table-id $PUBLIC_ROUTE_TABLE_ID \
  --subnet-id $PUBLIC_SUBNET2_ID \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 公共路由表关联到公共子网2成功"

# 关联私有路由表到私有子网
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 关联私有路由表到私有子网1..."
aws ec2 associate-route-table \
  --route-table-id $PRIVATE_ROUTE_TABLE_ID \
  --subnet-id $PRIVATE_SUBNET1_ID \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 私有路由表关联到私有子网1成功"

echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 关联私有路由表到私有子网2..."
aws ec2 associate-route-table \
  --route-table-id $PRIVATE_ROUTE_TABLE_ID \
  --subnet-id $PRIVATE_SUBNET2_ID \
  --region $REGION
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 私有路由表关联到私有子网2成功"

# 更新环境变量文件
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 更新环境变量文件..."
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

echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC 创建完成"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC ID: $VPC_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 互联网网关 ID: $IGW_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 公共子网1 ID: $PUBLIC_SUBNET1_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 私有子网1 ID: $PRIVATE_SUBNET1_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 公共子网2 ID: $PUBLIC_SUBNET2_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 私有子网2 ID: $PRIVATE_SUBNET2_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 公共路由表 ID: $PUBLIC_ROUTE_TABLE_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 私有路由表 ID: $PRIVATE_ROUTE_TABLE_ID"
echo -e "[${GREEN}3.expose_vpc_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 所需资源信息已保存到 ./env"
