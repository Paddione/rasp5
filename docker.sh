#!/bin/bash

# Update system
echo "Updating system..."
apt update && apt upgrade -y

# Install prerequisites
echo "Installing prerequisites..."
apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
echo "Adding Docker GPG key..."
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository for Debian
echo "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update apt index
apt update

# Install Docker
echo "Installing Docker..."
apt install -y docker.io docker-compose

# Start and enable Docker
echo "Enabling Docker..."
systemctl enable docker
systemctl start docker

# Add user to docker group
echo "Adding patrick to docker group..."
usermod -aG docker patrick

echo "Docker installation complete! Please log out and back in for group changes to take effect."
