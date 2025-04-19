#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
source ./env

echo -e "[${GREEN}4.vpc_peering.sh${NC}] Starting VPC peering connection creation..."
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Resource VPC region: $RESOURCE_REGION, VPC ID: $RESOURCE_VPC_ID"
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Expose VPC region: $EXPOSE_REGION, VPC ID: $EXPOSE_VPC_ID"

# Request VPC peering connection
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Requesting VPC peering connection..."
PEERING_ID=$(aws ec2 create-vpc-peering-connection \
    --region $RESOURCE_REGION \
    --vpc-id $RESOURCE_VPC_ID \
    --peer-vpc-id $EXPOSE_VPC_ID \
    --peer-region $EXPOSE_REGION \
    --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
    --output text)
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC peering connection request created, peering ID: $PEERING_ID"

# Wait for VPC peering connection request to propagate
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Waiting for VPC peering connection request to propagate..."
while true; do
    STATUS=$(aws ec2 describe-vpc-peering-connections \
        --region $RESOURCE_REGION \
        --vpc-peering-connection-ids $PEERING_ID \
        --query 'VpcPeeringConnections[0].Status.Code' \
        --output text)

    echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Current VPC peering connection status: $STATUS"

    if [ "$STATUS" == "pending-acceptance" ]; then
        echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC peering connection request is ready for acceptance"
        break
    elif [ "$STATUS" == "failed" ]; then
        echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC peering connection request failed"
        exit 1
    fi

    echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Continuing to wait for VPC peering connection request to propagate..."
    sleep 5
done

# Accept VPC peering connection
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$EXPOSE_REGION${NC}] Accepting VPC peering connection..."
aws ec2 accept-vpc-peering-connection \
    --region $EXPOSE_REGION \
    --vpc-peering-connection-id $PEERING_ID

# Wait for VPC peering connection to become active
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] Waiting for VPC peering connection to become active..."
while true; do
    STATUS=$(aws ec2 describe-vpc-peering-connections \
        --region $RESOURCE_REGION \
        --vpc-peering-connection-ids $PEERING_ID \
        --query 'VpcPeeringConnections[0].Status.Code' \
        --output text)

    echo -e "[${GREEN}4.vpc_peering.sh${NC}] Current VPC peering connection status: $STATUS"

    if [ "$STATUS" == "active" ]; then
        echo -e "[${GREEN}4.vpc_peering.sh${NC}] Peering connection established successfully!"
        break
    elif [ "$STATUS" == "failed" ]; then
        echo -e "[${GREEN}4.vpc_peering.sh${NC}] Peering connection failed"
        exit 1
    fi

    echo -e "[${GREEN}4.vpc_peering.sh${NC}] Continuing to wait for VPC peering connection to become active..."
    sleep 5
done

# Update environment variables file with peering connection ID
echo -e "[${GREEN}4.vpc_peering.sh${NC}] Updating environment variables file..."
cat >> ./env << EOF
export VPC_PEERING_ID="$PEERING_ID"
export RESOURCE_VPC_PEERING_ID="$PEERING_ID"
export EXPOSE_VPC_PEERING_ID="$PEERING_ID"
EOF

# Display peering connection details
echo -e "[${GREEN}4.vpc_peering.sh${NC}] [${YELLOW}$RESOURCE_REGION${NC}] VPC peering connection details:"
aws ec2 describe-vpc-peering-connections \
    --region $RESOURCE_REGION \
    --vpc-peering-connection-ids $PEERING_ID

echo -e "[${GREEN}4.vpc_peering.sh${NC}] VPC peering connection ID saved to environment variables file:"
echo -e "[${GREEN}4.vpc_peering.sh${NC}] VPC_PEERING_ID=$PEERING_ID"
echo -e "[${GREEN}4.vpc_peering.sh${NC}] Remember to update route tables in both VPCs to allow traffic through the peering connection"
