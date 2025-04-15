#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
source ./env

echo -e "[${GREEN}4.vpc_peering.sh${NC}] 开始创建VPC对等连接..."
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 资源VPC区域: $RESOURCE_REGION, VPC ID: $RESOURCE_VPC_ID"
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 暴露VPC区域: $EXPOSE_REGION, VPC ID: $EXPOSE_VPC_ID"

# 请求VPC对等连接
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 请求VPC对等连接..."
PEERING_ID=$(aws ec2 create-vpc-peering-connection \
    --region $RESOURCE_REGION \
    --vpc-id $RESOURCE_VPC_ID \
    --peer-vpc-id $EXPOSE_VPC_ID \
    --peer-region $EXPOSE_REGION \
    --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
    --output text)
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC对等连接请求已创建，对等连接ID: $PEERING_ID"

# 等待VPC对等连接请求传播
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 等待VPC对等连接请求传播..."
while true; do
    STATUS=$(aws ec2 describe-vpc-peering-connections \
        --region $RESOURCE_REGION \
        --vpc-peering-connection-ids $PEERING_ID \
        --query 'VpcPeeringConnections[0].Status.Code' \
        --output text)

    echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 当前VPC对等连接状态: $STATUS"

    if [ "$STATUS" == "pending-acceptance" ]; then
        echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC对等连接请求已准备好接受"
        break
    elif [ "$STATUS" == "failed" ]; then
        echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC对等连接请求失败"
        exit 1
    fi

    echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 继续等待VPC对等连接请求传播..."
    sleep 5
done

# 接受VPC对等连接
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 接受VPC对等连接..."
aws ec2 accept-vpc-peering-connection \
    --region $EXPOSE_REGION \
    --vpc-peering-connection-id $PEERING_ID

# 等待VPC对等连接变为活动状态
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 等待VPC对等连接变为活动状态..."
while true; do
    STATUS=$(aws ec2 describe-vpc-peering-connections \
        --region $RESOURCE_REGION \
        --vpc-peering-connection-ids $PEERING_ID \
        --query 'VpcPeeringConnections[0].Status.Code' \
        --output text)

    echo -e "[${GREEN}4.vpc_peering.sh${NC}] 当前VPC对等连接状态: $STATUS"

    if [ "$STATUS" == "active" ]; then
        echo -e "[${GREEN}4.vpc_peering.sh${NC}] 对等连接已成功建立!"
        break
    elif [ "$STATUS" == "failed" ]; then
        echo -e "[${GREEN}4.vpc_peering.sh${NC}] 对等连接失败"
        exit 1
    fi

    echo -e "[${GREEN}4.vpc_peering.sh${NC}] 继续等待VPC对等连接变为活动状态..."
    sleep 5
done

# 更新环境变量文件，添加对等连接ID
echo -e "[${GREEN}4.vpc_peering.sh${NC}] 更新环境变量文件..."
cat >> ./env << EOF
export VPC_PEERING_ID="$PEERING_ID"
export RESOURCE_VPC_PEERING_ID="$PEERING_ID"
export EXPOSE_VPC_PEERING_ID="$PEERING_ID"
EOF

# 显示对等连接详情
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC对等连接详情:"
aws ec2 describe-vpc-peering-connections \
    --region $RESOURCE_REGION \
    --vpc-peering-connection-ids $PEERING_ID

echo -e "[${GREEN}4.vpc_peering.sh${NC}] VPC对等连接ID已保存到环境变量文件:"
echo -e "[${GREEN}4.vpc_peering.sh${NC}] VPC_PEERING_ID=$PEERING_ID"
echo -e "[${GREEN}4.vpc_peering.sh${NC}] 请记得更新两个VPC的路由表以允许流量通过对等连接"
