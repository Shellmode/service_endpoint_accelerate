#!/bin/bash

# deploy_all.sh - Script to run all deployment scripts in sequence
# Created on: $(date)

set -e  # Exit immediately if a command exits with a non-zero status

echo "===== Starting deployment process ====="
echo "$(date): Beginning deployment"
echo "Loading environment variables from env file"
cp ./env.template ./env
source ./env

# Function to run a script and check its exit status
run_script() {
    script=$1
    echo ""
    echo "===== Running $script ====="
    echo "$(date): Starting $script"

    if [ -x "$script" ]; then
        ./$script
        if [ $? -eq 0 ]; then
            echo "$(date): $script completed successfully"
        else
            echo "$(date): $script failed with exit code $?"
            exit 1
        fi
    else
        echo "Error: $script is not executable or does not exist"
        exit 1
    fi
}

# Run scripts in sequence
run_script "1.resource_vpc_deploy.sh"
run_script "2.resource_endpoint_deploy.sh"
run_script "3.expose_vpc_deploy.sh"
run_script "4.vpc_peering.sh"
run_script "5.update_route_table.sh"
run_script "6.expose_nlb_deploy.sh"

# Source environment variables again to get the updated NLB_DNS
source ./env

echo ""
echo "===== Deployment completed successfully ====="
echo "$(date): All scripts have been executed"

# Print NLB URL in green color
echo -e "\033[32mNLB URL: https://$NLB_DNS\033[0m"
