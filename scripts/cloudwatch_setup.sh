#!/bin/bash
set -e

#---CloudWatch Agent installation and setup---

echo "---CloudWatch Agent installation and setup---"

echo "Checking if CloudWatch Agent is installed..."
if ! command -v amazon-cloudwatch-agent &> /dev/null; then
    echo "CloudWatch Agent not found. Installing..."
    if command -v dnf &> /dev/null; then
        sudo dnf install -y amazon-cloudwatch-agent
    elif command -v yum &> /dev/null; then
        sudo yum install -y amazon-cloudwatch-agent
    else
        echo "Neither dnf nor yum package manager found. Cannot install CloudWatch Agent."      
        exit 1
    fi
else
    echo "CloudWatch Agent is already installed."
fi

#---CloudWatch Agent configuration---
CLOUDWATCH_CUSTOM_CONFIG="/opt/devops_task1/configs/cloudwatch_agent.json"
CLOUDWATCH_AGENT_CONFIG="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"

if [ ! -f "$CLOUDWATCH_CUSTOM_CONFIG" ]; then
    echo "ERROR: CloudWatch Agent config file not found at ${CLOUDWATCH_CUSTOM_CONFIG}. Aborting."
    exit 1
else 
    echo "CloudWatch Agent config file found at ${CLOUDWATCH_CUSTOM_CONFIG}."

    echo "Copying config file to ${CLOUDWATCH_AGENT_CONFIG}..."
    sudo cp "${CLOUDWATCH_CUSTOM_CONFIG}" "${CLOUDWATCH_AGENT_CONFIG}"

    echo "Applying CloudWatch Agent configuration..."
    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
        -a fetch-config \
        -m ec2 \
        -c file:"$CLOUDWATCH_AGENT_CONFIG" \

    echo "Starting CloudWatch Agent service..."
    if ! systemctl is-active --quiet amazon-cloudwatch-agent; then
        sudo systemctl start amazon-cloudwatch-agent
        echo "CloudWatch Agent service started."
    else
        echo "CloudWatch Agent service is already running. Restarting it..."
        sudo systemctl restart amazon-cloudwatch-agent
    fi

    echo "Enabling CloudWatch Agent to start on boot..."
    sudo systemctl enable amazon-cloudwatch-agent

    echo "CloudWatch Agent configuration applied and agent started."
fi