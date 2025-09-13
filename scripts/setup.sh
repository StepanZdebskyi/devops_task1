#!/bin/bash

set -e

#---SSM Agent installation---
echo "Checking if SSM Agent is installed..."
if ! command -v amazon-ssm-agent &> /dev/null; then
    echo "SSM Agent not found. Installing..."
    if command -v dnf &> /dev/null; then
        sudo dnf install -y amazon-ssm-agent
    elif command -v yum &> /dev/null; then
        sudo yum install -y amazon-ssm-agent
    else
        echo "Neither dnf nor yum package manager found. Cannot install SSM Agent."
        exit 1
    fi
else
    echo "SSM Agent is already installed. Launching it..."
    sudo systemctl enable amazon-ssm-agent
    sudo systemctl start amazon-ssm-agent
fi

#---Nginx installation---
echo "Checking if Nginx is installed..."
if ! command -v nginx &> /dev/null; then
    echo "Nginx not found. Installing..."
    if command -v dnf &> /dev/null; then
        sudo dnf install -y nginx
    elif command -v yum &> /dev/null; then
        sudo yum install -y nginx
    else
        echo "Neither dnf nor yum package manager found. Cannot install Nginx."
        exit 1
    fi
else
    echo "Nginx is already installed."
fi

#---Customising Nginx log format---
NGINX_CONF="/etc/nginx/nginx.conf"
echo "Customising Nginx log format to include client IP, request time, upstream response time..."

NEW_LOG_FORMAT="    log_format  main  '\\\$http_x_forwarded_for - \\\$remote_addr - \\\$remote_user [\\\$time_local] \"\\\$request\" ' \\
                      '\\\$status \\\$body_bytes_sent \"\\\$http_referer\"' \\
                      '\"\\\$http_user_agent\"' 'rt=\"\\\$request_time\"' 'ut=\"\\\$upstream_response_time\"';"

# A search pattern to find the existing 'log_format main' directive.
SEARCH_PATTERN="^[[:space:]]*log_format[[:space:]]\+main"

# 1. Check if the configuration file exists.
if [ ! -f "$NGINX_CONF" ]; then
    echo "ERROR: Nginx config file not found at ${NGINX_CONF}. Aborting."
    exit 1
fi

# 2. Check if the 'log_format main' directive exists before trying to change it.
if ! grep -q "${SEARCH_PATTERN}" "${NGINX_CONF}"; then
    echo "ERROR: 'log_format main' directive not found in ${NGINX_CONF}."
    echo "Cannot perform replacement. Please check the configuration file."
    exit 1
fi

echo "Found existing 'log_format main'. Replacing it with the new custom format."
sudo sed -i.bak "/${SEARCH_PATTERN}/c\\${NEW_LOG_FORMAT}" "${NGINX_CONF}"
echo "Nginx configuration file updated."
echo "A backup of the original has been created at ${NGINX_CONF}.bak"

echo "Testing new Nginx configuration syntax..."
if sudo nginx -t; then
    echo "Configuration test successful."
    echo "Reloading Nginx to apply changes..."
    sudo systemctl reload nginx
    echo "Nginx has been reloaded successfully."
else
    # If the test fails, restore the backup to prevent downtime.
    echo "CRITICAL: Nginx configuration test failed!"
    echo "Restoring original configuration from backup to prevent service disruption."
    sudo mv "${NGINX_CONF}.bak" "${NGINX_CONF}"
    echo "Original configuration restored. Please review the NEW_LOG_FORMAT variable in this script for errors."
    exit 1
fi

echo "Nginx log format updated successfully."

#---Replacing default Nginx web page---
echo "Replacing default Nginx web page with a custom one..."
DEFAULT_HTML_PATH="/usr/share/nginx/html/index.html"
CUSTOM_HTML_PATH="/opt/devops_task1/web/index.html"

if [ -f "$CUSTOM_HTML_PATH" ]; then
    sudo cp "$CUSTOM_HTML_PATH" "$DEFAULT_HTML_PATH"
    echo "Default Nginx web page replaced successfully."
else
    echo "Custom HTML file not found at $CUSTOM_HTML_PATH. Skipping replacement."
fi  

#---Launching Nginx service---
echo "Enabling and starting Nginx service..."
sudo systemctl enable nginx
sudo systemctl start nginx
echo "Setup script completed successfully."

