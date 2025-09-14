#!/bin/bash

set -e

echo "---Logs scheduling setup---"

#---Install cronie---

echo "Checking if cronie is installed..."
if ! command -v crontab &> /dev/null; then
    echo "cronie not found. Installing..."
    if command -v dnf &> /dev/null; then
        sudo dnf install -y cronie
    elif command -v yum &> /dev/null; then
        sudo yum install -y cronie
    else
        echo "Neither dnf nor yum package manager found. Cannot install cronie."
        exit 1
    fi
else
    echo "cronie is already installed."
fi

#---Schedule the s3 logging execution every 24 hours at midnight---
#CRON_JOB="0 0 * * * /bin/bash /opt/devops_task1/scripts/s3_bucket_logs.sh >> /var/log/cron_s3_logs.log 2>&1"

#For testing purposes, we will set the cron job to run every 3 minutes
CRON_JOB="*/3 * * * * /bin/bash /opt/devops_task1/scripts/s3_bucket_logs.sh >> /var/log/cron_s3_logs.log 2>&1"

# Check if the cron job already exists
(crontab -l | grep -F "$CRON_JOB") && echo "Cron job already exists. No action needed." && exit 0       

# Add the cron job - handle case when crontab is empty or does not exist
if crontab -l 2>/dev/null | grep -q .; then
    # There are existing jobs, append the new one
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Cron job added to execute s3_bucket_logs.sh every 3 minutes."
else
    # No existing jobs, create new crontab with the job
    echo "$CRON_JOB" | crontab -
    echo "First cron job added to execute s3_bucket_logs.sh every 3 minutes."
fi

# Start the cron service
echo "Starting cron service..."
if command -v systemctl &> /dev/null; then
    sudo systemctl enable crond
    sudo systemctl start crond
elif command -v service &> /dev/null; then
    sudo service crond start
else
    echo "Neither systemctl nor service command found. Cannot start cron service."
    exit 1
fi

echo "Cron job scheduling completed."


