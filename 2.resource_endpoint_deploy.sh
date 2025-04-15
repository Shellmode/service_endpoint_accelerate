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

# 创建 VPC Endpoint
echo -e "[${GREEN}2.resource_endpoint_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 创建 VPC endpoint..."
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

# 获取 VPC Endpoint ID
VPC_ENDPOINT_ID=$(aws ec2 describe-vpc-endpoints \
    --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=service-name,Values=$SERVICE_NAME" \
    --query "VpcEndpoints[0].VpcEndpointId" \
    --output text)

# 不等待 VPC Endpoint 创建完成，只记录 ID
echo -e "[${GREEN}2.resource_endpoint_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC Endpoint 正在创建中，ID: $VPC_ENDPOINT_ID"

# 更新环境变量文件
echo -e "[${GREEN}2.resource_endpoint_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 更新环境变量文件..."
# Append to env
cat >> ./env << EOF
export RESOURCE_VPC_ENDPOINT_ID="$VPC_ENDPOINT_ID"
EOF

echo -e "[${GREEN}2.resource_endpoint_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC Endpoint 创建已启动"
echo -e "[${GREEN}2.resource_endpoint_deploy.sh${NC}] [${YELLOW}$REGION${NC}] VPC Endpoint ID: $VPC_ENDPOINT_ID"
