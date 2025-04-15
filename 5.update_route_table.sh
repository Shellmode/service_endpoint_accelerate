#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
source ./env

echo -e "[${GREEN}5.update_route_table.sh${NC}] 开始更新路由表以启用VPC对等连接的流量..."

# 获取VPC CIDR块
echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 获取资源VPC CIDR块..."
RESOURCE_VPC_CIDR=$(aws ec2 describe-vpcs \
    --region $RESOURCE_REGION \
    --vpc-ids $RESOURCE_VPC_ID \
    --query 'Vpcs[0].CidrBlock' \
    --output text)

echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 获取暴露VPC CIDR块..."
EXPOSE_VPC_CIDR=$(aws ec2 describe-vpcs \
    --region $EXPOSE_REGION \
    --vpc-ids $EXPOSE_VPC_ID \
    --query 'Vpcs[0].CidrBlock' \
    --output text)

echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 资源VPC CIDR: $RESOURCE_VPC_CIDR"
echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 暴露VPC CIDR: $EXPOSE_VPC_CIDR"

# 更新资源VPC的路由表
echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 更新资源VPC路由表 ($RESOURCE_ROUTE_TABLE_ID)，添加到暴露VPC的路由..."
aws ec2 create-route \
    --region $RESOURCE_REGION \
    --route-table-id $RESOURCE_ROUTE_TABLE_ID \
    --destination-cidr-block $EXPOSE_VPC_CIDR \
    --vpc-peering-connection-id $VPC_PEERING_ID

echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 资源VPC路由表更新成功"

# 更新暴露VPC的公共路由表
echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 更新暴露VPC公共路由表 ($EXPOSE_PUBLIC_ROUTE_TABLE_ID)，添加到资源VPC的路由..."
aws ec2 create-route \
    --region $EXPOSE_REGION \
    --route-table-id $EXPOSE_PUBLIC_ROUTE_TABLE_ID \
    --destination-cidr-block $RESOURCE_VPC_CIDR \
    --vpc-peering-connection-id $VPC_PEERING_ID

echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 暴露VPC公共路由表更新成功"

# 更新暴露VPC的私有路由表
echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 更新暴露VPC私有路由表 ($EXPOSE_PRIVATE_ROUTE_TABLE_ID)，添加到资源VPC的路由..."
aws ec2 create-route \
    --region $EXPOSE_REGION \
    --route-table-id $EXPOSE_PRIVATE_ROUTE_TABLE_ID \
    --destination-cidr-block $RESOURCE_VPC_CIDR \
    --vpc-peering-connection-id $VPC_PEERING_ID
echo -e "[${GREEN}5.update_route_table.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 暴露VPC私有路由表更新成功"

echo -e "[${GREEN}5.update_route_table.sh${NC}] 路由表更新完成！两个VPC现在可以通过VPC对等连接相互通信。"
