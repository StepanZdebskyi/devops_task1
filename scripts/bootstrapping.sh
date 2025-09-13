#!/bin/bash

#prevents partial execution of the script - partial instance setup
set -e

REPO_URL="https://github.com/StepanZdebskyi/devops_task1.git"
REPO_BRANCH="main"

#Scripts list to run

SCRIPTS_TO_RUN=(
  "setup.sh"
  "s3_bucket_logs.sh"
)

#Where to clone the repo
CLONE_DIR="/opt/devops_task1"

#Log file for bootstrapper
LOG_FILE="/var/log/bootstrapping.log"

#Redirect stdout and stderr to log file
exec > >(tee -a "$LOG_FILE" | logger -t bootstrapping -s 2>/dev/console) 2>&1

echo "---Starting EC2 instance bootstrapping process---"

#Installing the dependencies
echo "Updating system packages and installing git..."

if command -v dnf &> /dev/null; then
  sudo dnf update -y
  sudo dnf install -y git
elif command -v yum &> /dev/null; then
  sudo yum update -y
  sudo yum install -y git
else
  echo "Neither dnf nor yum package manager found. Exiting."
  exit 1
fi

#Clone the repository
echo "Cloning repository $REPO_URL (branch: $REPO_BRANCH) into $CLONE_DIR"

if [ -d "$CLONE_DIR" ]; then
  echo "Directory $CLONE_DIR already exists. Pulling latest changes..."
  git -C "$CLONE_DIR" pull origin "$REPO_BRANCH"
else
  git clone -b "$REPO_BRANCH" "$REPO_URL" "$CLONE_DIR"
fi

#Execute the scripts in order
for script in "${SCRIPTS_TO_RUN[@]}"; do
  SCRIPT_PATH="$CLONE_DIR/scripts/$script"
  echo "---"
  echo "Looking for script $SCRIPT_PATH"

    if [ -f "$SCRIPT_PATH" ]; then
        echo "Making script $script executable and running it..."
        chmod +x "$SCRIPT_PATH"
        "$SCRIPT_PATH"
        echo "Script $script executed successfully."
    else
        echo "Script $script not found in the repository. Exiting."
        exit 1
    fi
done

echo "---"
echo "Bootstrapping process completed successfully at $(date)."

