#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
source ./env

# Set variables
REGION=$EXPOSE_REGION
VPC_ID=$EXPOSE_VPC_ID
PUBLIC_SUBNET1_ID=$EXPOSE_PUBLIC_SUBNET1_ID
PUBLIC_SUBNET2_ID=$EXPOSE_PUBLIC_SUBNET2_ID
RESOURCE_REGION=$RESOURCE_REGION
VPC_ENDPOINT_ID=$RESOURCE_VPC_ENDPOINT_ID

# Target IP addresses
TARGET_IP_1="10.1.128.66"
TARGET_IP_2="10.1.144.66"
TARGET_PORT=443

# Wait for VPC Endpoint creation to complete
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Waiting for VPC Endpoint creation to complete..."
while true; do
    STATUS=$(aws ec2 describe-vpc-endpoints \
        --region $RESOURCE_REGION \
        --vpc-endpoint-ids $VPC_ENDPOINT_ID \
        --query "VpcEndpoints[0].State" \
        --output text)

    echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Current VPC Endpoint status: $STATUS"

    if [ "$STATUS" == "available" ]; then
        echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC Endpoint creation completed"
        break
    elif [ "$STATUS" == "failed" ]; then
        echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC Endpoint creation failed"
        exit 1
    fi

    echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Continuing to wait for VPC Endpoint creation to complete..."
    sleep 5
done

# Get default security group
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Getting VPC default security group..."
DEFAULT_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=default" \
  --region $REGION \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Default security group ID: $DEFAULT_SG_ID"

# Add security group rule to allow all IPs to access port 443
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Adding security group inbound rule..."
aws ec2 authorize-security-group-ingress \
  --group-id $DEFAULT_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region $REGION
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Security group inbound rule added successfully"

# Create target group
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating target group..."
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
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Target group created successfully: $TG_ARN"

# Register target IPs (specified as other private IP addresses)
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Registering target IP addresses (other private IP addresses)..."
aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets Id=$TARGET_IP_1,Port=$TARGET_PORT,AvailabilityZone=all Id=$TARGET_IP_2,Port=$TARGET_PORT,AvailabilityZone=all \
  --region $REGION
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Target IPs registered successfully"

# Create NLB
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating NLB..."
NLB_ARN=$(aws elbv2 create-load-balancer \
  --name service-peering-nlb \
  --type network \
  --scheme internet-facing \
  --subnets $PUBLIC_SUBNET1_ID $PUBLIC_SUBNET2_ID \
  --security-groups $DEFAULT_SG_ID \
  --region $REGION \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB created successfully: $NLB_ARN"

# Wait for NLB to become active
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Waiting for NLB to become active..."
while true; do
  NLB_STATE=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $NLB_ARN \
    --region $REGION \
    --query 'LoadBalancers[0].State.Code' \
    --output text)

  echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Current NLB status: $NLB_STATE"

  if [ "$NLB_STATE" == "active" ]; then
    echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB is now active"
    break
  elif [ "$NLB_STATE" == "failed" ]; then
    echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB creation failed"
    exit 1
  fi

  echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Continuing to wait for NLB to become active..."
  sleep 5
done

# Create listener
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Creating NLB listener..."
LISTENER_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn $NLB_ARN \
  --protocol TCP \
  --port 443 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --region $REGION \
  --query 'Listeners[0].ListenerArn' \
  --output text)
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB listener created successfully: $LISTENER_ARN"

# Get NLB DNS name
NLB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $NLB_ARN \
  --region $REGION \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

# Update environment variables file
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Updating environment variables file..."
cat >> ./env << EOF
export NLB_DEFAULT_SG_ID="$DEFAULT_SG_ID"
export NLB_TARGET_GROUP_ARN="$TG_ARN"
export NLB_ARN="$NLB_ARN"
export NLB_LISTENER_ARN="$LISTENER_ARN"
export NLB_DNS="$NLB_DNS"
EOF

echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB deployment completed"
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Default security group ID: $DEFAULT_SG_ID"
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Target group ARN: $TG_ARN"
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB ARN: $NLB_ARN"
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB listener ARN: $LISTENER_ARN"
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] NLB DNS name: $NLB_DNS"
echo -e "[${GREEN}6.expose_nlb_deploy.sh${NC}] [${YELLOW}$REGION${NC}] Required resource information has been saved to ./env"
