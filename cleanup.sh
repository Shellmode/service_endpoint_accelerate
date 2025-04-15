#!/bin/bash

# 设置 -e 标志，使任何命令失败时脚本立即退出
set -e

source ./env
echo -e "[${GREEN}cleanup.sh${NC}] 环境变量加载成功。"
echo -e "[${GREEN}cleanup.sh${NC}] 开始清理所有资源..."

# 1. 删除 NLB 相关资源
echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 正在删除 NLB 相关资源..."
if [ ! -z "$NLB_LISTENER_ARN" ]; then
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 删除 NLB Listener: $NLB_LISTENER_ARN"
    aws elbv2 delete-listener --listener-arn $NLB_LISTENER_ARN --region $EXPOSE_REGION
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] NLB Listener 删除操作完成"
fi

if [ ! -z "$NLB_ARN" ]; then
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 删除 NLB: $NLB_ARN"
    aws elbv2 delete-load-balancer --load-balancer-arn $NLB_ARN --region $EXPOSE_REGION
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] NLB 删除操作已启动"

    # 等待 NLB 完全删除
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 等待 NLB 完全删除..."
    MAX_ATTEMPTS=30
    ATTEMPT=0
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        NLB_EXISTS=$(aws elbv2 describe-load-balancers \
            --region $EXPOSE_REGION \
            --query "LoadBalancers[?LoadBalancerArn=='$NLB_ARN'].LoadBalancerArn" \
            --output text 2>/dev/null || echo "")

        if [ -z "$NLB_EXISTS" ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] NLB 已完全删除"
            break
        fi

        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] NLB 仍在删除中，继续等待... (尝试 $((ATTEMPT+1))/$MAX_ATTEMPTS)"
        ATTEMPT=$((ATTEMPT+1))
        sleep 5
    done

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] NLB 删除超时，停止清理流程"
        exit 1
    fi
fi

if [ ! -z "$NLB_TARGET_GROUP_ARN" ]; then
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 删除 NLB Target Group: $NLB_TARGET_GROUP_ARN"
    aws elbv2 delete-target-group --target-group-arn $NLB_TARGET_GROUP_ARN --region $EXPOSE_REGION
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] NLB Target Group 删除操作完成"
fi

# 2. 删除 VPC Peering 连接
if [ ! -z "$VPC_PEERING_ID" ]; then
    echo -e "[${GREEN}cleanup.sh${NC}] 删除 VPC Peering 连接: $VPC_PEERING_ID"
    aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $VPC_PEERING_ID --region $EXPOSE_REGION
    echo -e "[${GREEN}cleanup.sh${NC}] VPC Peering 连接删除操作已启动"

    # 等待 VPC Peering 连接完全删除
    echo -e "[${GREEN}cleanup.sh${NC}] 等待 VPC Peering 连接完全删除..."
    MAX_ATTEMPTS=30
    ATTEMPT=0
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        PEERING_EXISTS=$(aws ec2 describe-vpc-peering-connections \
            --region $EXPOSE_REGION \
            --vpc-peering-connection-ids $VPC_PEERING_ID \
            --query "VpcPeeringConnections[0].VpcPeeringConnectionId" \
            --output text 2>/dev/null || echo "")

        if [ -z "$PEERING_EXISTS" ] || [ "$PEERING_EXISTS" == "None" ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] VPC Peering 连接已完全删除"
            break
        fi

        PEERING_STATE=$(aws ec2 describe-vpc-peering-connections \
            --region $EXPOSE_REGION \
            --vpc-peering-connection-ids $VPC_PEERING_ID \
            --query "VpcPeeringConnections[0].Status.Code" \
            --output text 2>/dev/null || echo "")

        echo -e "[${GREEN}cleanup.sh${NC}] 当前 VPC Peering 连接状态: $PEERING_STATE (尝试 $((ATTEMPT+1))/$MAX_ATTEMPTS)"

        if [ "$PEERING_STATE" == "deleted" ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] VPC Peering 连接已删除"
            break
        fi

        ATTEMPT=$((ATTEMPT+1))
        sleep 5
    done

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo -e "[${GREEN}cleanup.sh${NC}] VPC Peering 连接删除超时，停止清理流程"
        exit 1
    fi
fi

# 4. 删除 Expose VPC 资源
if [ ! -z "$EXPOSE_VPC_ID" ]; then
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 正在删除 Expose VPC 相关资源..."

    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] sleep 30s 等待资源删除完成"
    sleep 30

    # 删除子网
    for subnet_id in "$EXPOSE_PUBLIC_SUBNET1_ID" "$EXPOSE_PRIVATE_SUBNET1_ID" "$EXPOSE_PUBLIC_SUBNET2_ID" "$EXPOSE_PRIVATE_SUBNET2_ID"; do
        if [ ! -z "$subnet_id" ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 删除子网: $subnet_id"
            aws ec2 delete-subnet --subnet-id $subnet_id --region $EXPOSE_REGION
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 子网删除操作完成"
        fi
    done

    # 删除路由表
    for rt_id in "$EXPOSE_PUBLIC_ROUTE_TABLE_ID" "$EXPOSE_PRIVATE_ROUTE_TABLE_ID"; do
        if [ ! -z "$rt_id" ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 删除路由表: $rt_id"
            aws ec2 delete-route-table --route-table-id $rt_id --region $EXPOSE_REGION
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 路由表删除操作完成"
        fi
    done

    # 解绑并删除 Internet Gateway
    if [ ! -z "$EXPOSE_IGW_ID" ] && [ ! -z "$EXPOSE_VPC_ID" ]; then
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 解绑 Internet Gateway: $EXPOSE_IGW_ID"
        aws ec2 detach-internet-gateway --internet-gateway-id $EXPOSE_IGW_ID --vpc-id $EXPOSE_VPC_ID --region $EXPOSE_REGION
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 删除 Internet Gateway: $EXPOSE_IGW_ID"
        aws ec2 delete-internet-gateway --internet-gateway-id $EXPOSE_IGW_ID --region $EXPOSE_REGION
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Internet Gateway 删除操作完成"
    fi

    # 删除 VPC
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] 删除 Expose VPC: $EXPOSE_VPC_ID"
    aws ec2 delete-vpc --vpc-id $EXPOSE_VPC_ID --region $EXPOSE_REGION
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Expose VPC 删除操作完成"
fi

# 5. 删除 Resource VPC 资源
if [ ! -z "$RESOURCE_VPC_ID" ]; then
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 正在删除 Resource VPC 相关资源..."

    # 先删除 VPC Endpoint
    if [ ! -z "$RESOURCE_VPC_ENDPOINT_ID" ]; then
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 删除 VPC Endpoint: $RESOURCE_VPC_ENDPOINT_ID"
        aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $RESOURCE_VPC_ENDPOINT_ID --region $RESOURCE_REGION
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC Endpoint 删除操作已启动"

        # 等待 VPC Endpoint 完全删除
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 等待 VPC Endpoint 完全删除..."
        MAX_ATTEMPTS=30
        ATTEMPT=0
        while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
            ENDPOINT_EXISTS=$(aws ec2 describe-vpc-endpoints \
                --region $RESOURCE_REGION \
                --vpc-endpoint-ids $RESOURCE_VPC_ENDPOINT_ID \
                --query "VpcEndpoints[0].VpcEndpointId" \
                --output text 2>/dev/null || echo "")

            if [ -z "$ENDPOINT_EXISTS" ] || [ "$ENDPOINT_EXISTS" == "None" ]; then
                echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC Endpoint 已完全删除"
                break
            fi

            ENDPOINT_STATE=$(aws ec2 describe-vpc-endpoints \
                --region $RESOURCE_REGION \
                --vpc-endpoint-ids $RESOURCE_VPC_ENDPOINT_ID \
                --query "VpcEndpoints[0].State" \
                --output text 2>/dev/null || echo "")

            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 当前 VPC Endpoint 状态: $ENDPOINT_STATE (尝试 $((ATTEMPT+1))/$MAX_ATTEMPTS)"

            if [ "$ENDPOINT_STATE" == "deleted" ]; then
                echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC Endpoint 已删除"
                break
            fi

            ATTEMPT=$((ATTEMPT+1))
            sleep 5
        done

        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC Endpoint 删除超时，停止清理流程"
            exit 1
        fi
    fi

    # 删除子网
    for subnet_id in "$RESOURCE_SUBNET1_ID" "$RESOURCE_SUBNET2_ID"; do
        if [ ! -z "$subnet_id" ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 删除子网: $subnet_id"
            aws ec2 delete-subnet --subnet-id $subnet_id --region $RESOURCE_REGION
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 子网删除操作完成"
        fi
    done

    # 删除安全组
    if [ ! -z "$RESOURCE_SG_ID" ]; then
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 删除安全组: $RESOURCE_SG_ID"
        aws ec2 delete-security-group --group-id $RESOURCE_SG_ID --region $RESOURCE_REGION
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 安全组删除操作完成"
    fi

    # 删除路由表
    if [ ! -z "$RESOURCE_ROUTE_TABLE_ID" ]; then
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 删除路由表: $RESOURCE_ROUTE_TABLE_ID"
        aws ec2 delete-route-table --route-table-id $RESOURCE_ROUTE_TABLE_ID --region $RESOURCE_REGION
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 路由表删除操作完成"
    fi

    # 删除 VPC
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 删除 Resource VPC: $RESOURCE_VPC_ID"
    aws ec2 delete-vpc --vpc-id $RESOURCE_VPC_ID --region $RESOURCE_REGION
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Resource VPC 删除操作完成"
fi

echo -e "[${GREEN}cleanup.sh${NC}] 所有资源清理完成！"
