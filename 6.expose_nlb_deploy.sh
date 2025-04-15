#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
source ./env

# 设置变量
REGION=$EXPOSE_REGION
VPC_ID=$EXPOSE_VPC_ID
PUBLIC_SUBNET1_ID=$EXPOSE_PUBLIC_SUBNET1_ID
PUBLIC_SUBNET2_ID=$EXPOSE_PUBLIC_SUBNET2_ID
RESOURCE_REGION=$RESOURCE_REGION
VPC_ENDPOINT_ID=$RESOURCE_VPC_ENDPOINT_ID

# 目标 IP 地址
TARGET_IP_1="10.1.128.66"
TARGET_IP_2="10.1.144.66"
TARGET_PORT=443

# 等待 VPC Endpoint 创建完成
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 等待 VPC Endpoint 创建完成..."
while true; do
    STATUS=$(aws ec2 describe-vpc-endpoints \
        --region $RESOURCE_REGION \
        --vpc-endpoint-ids $VPC_ENDPOINT_ID \
        --query "VpcEndpoints[0].State" \
        --output text)

    echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 当前 VPC Endpoint 状态: $STATUS"

    if [ "$STATUS" == "available" ]; then
        echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC Endpoint 已创建完成"
        break
    elif [ "$STATUS" == "failed" ]; then
        echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC Endpoint 创建失败"
        exit 1
    fi

    echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] 继续等待 VPC Endpoint 创建完成..."
    sleep 5
done

# 获取默认安全组
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 获取 VPC 默认安全组..."
DEFAULT_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=default" \
  --region $REGION \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 默认安全组 ID: $DEFAULT_SG_ID"

# 添加安全组规则，允许所有 IP 访问 443 端口
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 添加安全组入站规则..."
aws ec2 authorize-security-group-ingress \
  --group-id $DEFAULT_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region $REGION
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 安全组入站规则添加成功"

# 创建目标组
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 创建目标组..."
TG_ARN=$(aws elbv2 create-target-group \
  --name service-peering-tg \
  --protocol TCP \
  --port 443 \
  --vpc-id $VPC_ID \
  --target-type ip \
  --health-check-protocol TCP \
  --health-check-port 443 \
  --health-check-enabled \
  --health-check-interval-seconds 10 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 2 \
  --region $REGION \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 目标组创建成功: $TG_ARN"

# 注册目标 IP（指定为其他私有 IP 地址）
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 注册目标 IP 地址（其他私有 IP 地址）..."
aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets Id=$TARGET_IP_1,Port=$TARGET_PORT,AvailabilityZone=all Id=$TARGET_IP_2,Port=$TARGET_PORT,AvailabilityZone=all \
  --region $REGION
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 目标 IP 注册成功"

# 创建 NLB
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 创建 NLB..."
NLB_ARN=$(aws elbv2 create-load-balancer \
  --name service-peering-nlb \
  --type network \
  --scheme internet-facing \
  --subnets $PUBLIC_SUBNET1_ID $PUBLIC_SUBNET2_ID \
  --security-groups $DEFAULT_SG_ID \
  --region $REGION \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB 创建成功: $NLB_ARN"

# 等待 NLB 变为活动状态
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 等待 NLB 变为活动状态..."
while true; do
  NLB_STATE=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $NLB_ARN \
    --region $REGION \
    --query 'LoadBalancers[0].State.Code' \
    --output text)

  echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 当前 NLB 状态: $NLB_STATE"

  if [ "$NLB_STATE" == "active" ]; then
    echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB 已变为活动状态"
    break
  elif [ "$NLB_STATE" == "failed" ]; then
    echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB 创建失败"
    exit 1
  fi

  echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 继续等待 NLB 变为活动状态..."
  sleep 5
done

# 创建监听器
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 创建 NLB 监听器..."
LISTENER_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn $NLB_ARN \
  --protocol TCP \
  --port 443 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --region $REGION \
  --query 'Listeners[0].ListenerArn' \
  --output text)
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB 监听器创建成功: $LISTENER_ARN"

# 获取 NLB DNS 名称
NLB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $NLB_ARN \
  --region $REGION \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

# 更新环境变量文件
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 更新环境变量文件..."
cat >> ./env << EOF
export NLB_DEFAULT_SG_ID="$DEFAULT_SG_ID"
export NLB_TARGET_GROUP_ARN="$TG_ARN"
export NLB_ARN="$NLB_ARN"
export NLB_LISTENER_ARN="$LISTENER_ARN"
export NLB_DNS="$NLB_DNS"
EOF

echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB 部署完成"
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 默认安全组 ID: $DEFAULT_SG_ID"
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 目标组 ARN: $TG_ARN"
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB ARN: $NLB_ARN"
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB 监听器 ARN: $LISTENER_ARN"
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB DNS 名称: $NLB_DNS"
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] 所需资源信息已保存到 ./env"
