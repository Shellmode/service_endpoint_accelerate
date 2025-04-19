#!/bin/bash

# Set -e flag to make the script exit immediately if any command fails
set -e

source ./env
echo -e "[${GREEN}cleanup.sh${NC}] Environment variables loaded successfully."
echo -e "[${GREEN}cleanup.sh${NC}] Starting cleanup of all resources..."

# 1. Delete NLB related resources
echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Deleting NLB related resources..."
if [ ! -z "$NLB_LISTENER_ARN" ]; then
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Deleting NLB Listener: $NLB_LISTENER_ARN"
    aws elbv2 delete-listener --listener-arn $NLB_LISTENER_ARN --region $EXPOSE_REGION
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] NLB Listener deletion completed"
fi

if [ ! -z "$NLB_ARN" ]; then
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Deleting NLB: $NLB_ARN"
    aws elbv2 delete-load-balancer --load-balancer-arn $NLB_ARN --region $EXPOSE_REGION
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] NLB deletion initiated"

    # Wait for NLB to be completely deleted
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Waiting for NLB to be completely deleted..."
    MAX_ATTEMPTS=30
    ATTEMPT=0
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        NLB_EXISTS=$(aws elbv2 describe-load-balancers \
            --region $EXPOSE_REGION \
            --query "LoadBalancers[?LoadBalancerArn=='$NLB_ARN'].LoadBalancerArn" \
            --output text 2>/dev/null || echo "")

        if [ -z "$NLB_EXISTS" ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] NLB has been completely deleted"
            break
        fi

        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] NLB is still being deleted, continuing to wait... (Attempt $((ATTEMPT+1))/$MAX_ATTEMPTS)"
        ATTEMPT=$((ATTEMPT+1))
        sleep 5
    done

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] NLB deletion timed out, stopping cleanup process"
        exit 1
    fi
fi

if [ ! -z "$NLB_TARGET_GROUP_ARN" ]; then
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Deleting NLB Target Group: $NLB_TARGET_GROUP_ARN"
    aws elbv2 delete-target-group --target-group-arn $NLB_TARGET_GROUP_ARN --region $EXPOSE_REGION
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] NLB Target Group deletion completed"
fi

# 2. Delete VPC Peering connection
if [ ! -z "$VPC_PEERING_ID" ]; then
    echo -e "[${GREEN}cleanup.sh${NC}] Deleting VPC Peering connection: $VPC_PEERING_ID"
    aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $VPC_PEERING_ID --region $EXPOSE_REGION
    echo -e "[${GREEN}cleanup.sh${NC}] VPC Peering connection deletion initiated"

    # Wait for VPC Peering connection to be completely deleted
    echo -e "[${GREEN}cleanup.sh${NC}] Waiting for VPC Peering connection to be completely deleted..."
    MAX_ATTEMPTS=30
    ATTEMPT=0
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        PEERING_EXISTS=$(aws ec2 describe-vpc-peering-connections \
            --region $EXPOSE_REGION \
            --vpc-peering-connection-ids $VPC_PEERING_ID \
            --query "VpcPeeringConnections[0].VpcPeeringConnectionId" \
            --output text 2>/dev/null || echo "")

        if [ -z "$PEERING_EXISTS" ] || [ "$PEERING_EXISTS" == "None" ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] VPC Peering connection has been completely deleted"
            break
        fi

        PEERING_STATE=$(aws ec2 describe-vpc-peering-connections \
            --region $EXPOSE_REGION \
            --vpc-peering-connection-ids $VPC_PEERING_ID \
            --query "VpcPeeringConnections[0].Status.Code" \
            --output text 2>/dev/null || echo "")

        echo -e "[${GREEN}cleanup.sh${NC}] Current VPC Peering connection status: $PEERING_STATE (Attempt $((ATTEMPT+1))/$MAX_ATTEMPTS)"

        if [ "$PEERING_STATE" == "deleted" ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] VPC Peering connection has been deleted"
            break
        fi

        ATTEMPT=$((ATTEMPT+1))
        sleep 5
    done

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo -e "[${GREEN}cleanup.sh${NC}] VPC Peering connection deletion timed out, stopping cleanup process"
        exit 1
    fi
fi

# 4. Delete Expose VPC resources
if [ ! -z "$EXPOSE_VPC_ID" ]; then
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Deleting Expose VPC related resources..."

    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Sleeping for 30s to wait for resource deletion to complete"
    sleep 30

    # Delete subnets
    for subnet_id in "$EXPOSE_PUBLIC_SUBNET1_ID" "$EXPOSE_PRIVATE_SUBNET1_ID" "$EXPOSE_PUBLIC_SUBNET2_ID" "$EXPOSE_PRIVATE_SUBNET2_ID"; do
        if [ ! -z "$subnet_id" ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Deleting subnet: $subnet_id"
            aws ec2 delete-subnet --subnet-id $subnet_id --region $EXPOSE_REGION
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Subnet deletion completed"
        fi
    done

    # Delete route tables
    for rt_id in "$EXPOSE_PUBLIC_ROUTE_TABLE_ID" "$EXPOSE_PRIVATE_ROUTE_TABLE_ID"; do
        if [ ! -z "$rt_id" ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Deleting route table: $rt_id"
            aws ec2 delete-route-table --route-table-id $rt_id --region $EXPOSE_REGION
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Route table deletion completed"
        fi
    done

    # Detach and delete Internet Gateway
    if [ ! -z "$EXPOSE_IGW_ID" ] && [ ! -z "$EXPOSE_VPC_ID" ]; then
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Detaching Internet Gateway: $EXPOSE_IGW_ID"
        aws ec2 detach-internet-gateway --internet-gateway-id $EXPOSE_IGW_ID --vpc-id $EXPOSE_VPC_ID --region $EXPOSE_REGION
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Deleting Internet Gateway: $EXPOSE_IGW_ID"
        aws ec2 delete-internet-gateway --internet-gateway-id $EXPOSE_IGW_ID --region $EXPOSE_REGION
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Internet Gateway deletion completed"
    fi

    # Delete VPC
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Deleting Expose VPC: $EXPOSE_VPC_ID"
    aws ec2 delete-vpc --vpc-id $EXPOSE_VPC_ID --region $EXPOSE_REGION
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Expose VPC deletion completed"
fi

# 5. Delete Resource VPC resources
if [ ! -z "$RESOURCE_VPC_ID" ]; then
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Deleting Resource VPC related resources..."

    # First delete VPC Endpoint
    if [ ! -z "$RESOURCE_VPC_ENDPOINT_ID" ]; then
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Deleting VPC Endpoint: $RESOURCE_VPC_ENDPOINT_ID"
        aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $RESOURCE_VPC_ENDPOINT_ID --region $RESOURCE_REGION
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC Endpoint deletion initiated"

        # Wait for VPC Endpoint to be completely deleted
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Waiting for VPC Endpoint to be completely deleted..."
        MAX_ATTEMPTS=30
        ATTEMPT=0
        while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
            ENDPOINT_EXISTS=$(aws ec2 describe-vpc-endpoints \
                --region $RESOURCE_REGION \
                --vpc-endpoint-ids $RESOURCE_VPC_ENDPOINT_ID \
                --query "VpcEndpoints[0].VpcEndpointId" \
                --output text 2>/dev/null || echo "")

            if [ -z "$ENDPOINT_EXISTS" ] || [ "$ENDPOINT_EXISTS" == "None" ]; then
                echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC Endpoint has been completely deleted"
                break
            fi

            ENDPOINT_STATE=$(aws ec2 describe-vpc-endpoints \
                --region $RESOURCE_REGION \
                --vpc-endpoint-ids $RESOURCE_VPC_ENDPOINT_ID \
                --query "VpcEndpoints[0].State" \
                --output text 2>/dev/null || echo "")

            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Current VPC Endpoint status: $ENDPOINT_STATE (Attempt $((ATTEMPT+1))/$MAX_ATTEMPTS)"

            if [ "$ENDPOINT_STATE" == "deleted" ]; then
                echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC Endpoint has been deleted"
                break
            fi

            ATTEMPT=$((ATTEMPT+1))
            sleep 5
        done

        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC Endpoint deletion timed out, stopping cleanup process"
            exit 1
        fi
    fi

    # Delete subnets
    for subnet_id in "$RESOURCE_SUBNET1_ID" "$RESOURCE_SUBNET2_ID"; do
        if [ ! -z "$subnet_id" ]; then
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Deleting subnet: $subnet_id"
            aws ec2 delete-subnet --subnet-id $subnet_id --region $RESOURCE_REGION
            echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Subnet deletion completed"
        fi
    done

    # Delete security group
    if [ ! -z "$RESOURCE_SG_ID" ]; then
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Deleting security group: $RESOURCE_SG_ID"
        aws ec2 delete-security-group --group-id $RESOURCE_SG_ID --region $RESOURCE_REGION
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Security group deletion completed"
    fi

    # Delete route table
    if [ ! -z "$RESOURCE_ROUTE_TABLE_ID" ]; then
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Deleting route table: $RESOURCE_ROUTE_TABLE_ID"
        aws ec2 delete-route-table --route-table-id $RESOURCE_ROUTE_TABLE_ID --region $RESOURCE_REGION
        echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Route table deletion completed"
    fi

    # Delete VPC
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Deleting Resource VPC: $RESOURCE_VPC_ID"
    aws ec2 delete-vpc --vpc-id $RESOURCE_VPC_ID --region $RESOURCE_REGION
    echo -e "[${GREEN}cleanup.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Resource VPC deletion completed"
fi

echo -e "[${GREEN}cleanup.sh${NC}] All resources cleanup completed!"
