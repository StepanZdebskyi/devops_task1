#!/bin/bash

set -e

#--- Install yum-cron or dnf-automatic ---

echo "--- Automatic updates setup ---"

if command -v dnf &> /dev/null; then
    if ! command -v dnf-automatic &> /dev/null; then
        echo "dnf-automatic not found. Installing..."
        sudo dnf install -y dnf-automatic
    else
        echo "dnf-automatic is already installed."
    fi
elif command -v yum &> /dev/null; then
    if ! command -v yum-cron &> /dev/null; then
        echo "yum-cron not found. Installing..."
        sudo yum install -y yum-cron
    else
        echo "yum-cron is already installed."
    fi
else
    echo "Neither dnf nor yum package manager found. Cannot install automatic updates tool."
    exit 1
fi

#--- Automatic env updates setup ---

echo "Checking if automatic updates are enabled in config file..."
if [ -f /etc/yum/yum.conf ]; then
    if grep -q "^update_cmd = security" /etc/yum/yum.conf && grep -q "^apply_updates = yes" /etc/yum/yum.conf; then
        echo "Automatic updates are already enabled in yum.conf. No action needed."
        exit 0
    else
        echo "Enabling automatic updates in yum.conf..."
        sudo sed -i.bak '/^\[main\]/a update_cmd = security\napply_updates = yes' /etc/yum/yum.conf
        echo "Automatic updates enabled in yum.conf."
    fi
elif [ -f /etc/dnf/dnf.conf ]; then
    if grep -q "^upgrade_type = security" /etc/dnf/dnf.conf && grep -q "^apply_updates = yes" /etc/dnf/dnf.conf; then
        echo "Automatic updates are already enabled in dnf.conf. No action needed." 
        exit 0
    else
        echo "Enabling automatic updates in dnf.conf..."
        sudo sed -i.bak '/^\[main\]/a upgrade_type = security\napply_updates = yes' /etc/dnf/dnf.conf
        echo "Automatic updates enabled in dnf.conf."
    fi
else
    echo "Neither yum.conf nor dnf.conf found. Cannot configure automatic updates."
    exit 1
fi

echo "Starting and enabling the automatic updates service..."
if command -v dnf &> /dev/null; then    
    sudo systemctl enable dnf-automatic.timer
    sudo systemctl start dnf-automatic.timer
elif command -v yum &> /dev/null; then
    sudo systemctl enable yum-cron
    sudo systemctl start yum-cron
else
    echo "Neither dnf nor yum package manager found. Cannot start automatic updates service."
    exit 1
fi  

echo "Env automatic updates setup completed."