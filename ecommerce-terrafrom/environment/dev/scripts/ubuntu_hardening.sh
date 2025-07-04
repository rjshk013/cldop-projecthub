#!/bin/bash

set -e

echo "🛠️ Updating system packages..."
apt-get update -y
apt-get upgrade -y

echo "🐳 Installing Docker CE..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    ufw

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repo
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker packages
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable Docker
systemctl enable docker
systemctl start docker

echo "✅ Docker installed and running!"

echo "🔐 Basic server hardening..."

# Disable root login over SSH
#sudo sed -i 's/^#Port.*/Port 22022/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Disable password authentication (use SSH key auth only)
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# Disable empty passwords
sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# Restart SSH to apply changes
systemctl restart sshd

# Set up UFW firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS
ufw enable <<< "y"

echo "✅ Server hardened and ready to use."
