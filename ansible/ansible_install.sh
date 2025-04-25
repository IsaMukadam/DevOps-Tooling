#!/usr/bin/env bash

# Exit script on any error
set -e

# Update system and install required dependencies
echo "Updating system and installing required dependencies..."
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y software-properties-common

# Add Ansible's official PPA repository
echo "Adding Ansible PPA repository..."
sudo add-apt-repository --yes --update ppa:ansible/ansible

# Install Ansible
echo "Installing Ansible..."
sudo apt install -y ansible

# Verify installation
echo "Verifying Ansible installation..."
ansible --version

# Completion message
echo "Ansible installation complete!"
