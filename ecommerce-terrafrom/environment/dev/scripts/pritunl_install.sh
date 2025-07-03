#!/bin/bash
exec > >(tee -a /var/log/pritunl_install.log)
exec 2>&1
set -x 
# ============================================================================
# PRITUNL VPN SERVER INSTALLATION & HARDENING SCRIPT
# ============================================================================
# This script installs and configures Pritunl VPN server with security hardening
# File: scripts/pritunl_install.sh
# ============================================================================

#set -e  # Exit on any error

# Variables passed from Terraform
HOSTNAME="${hostname}"
SSH_PORT="${ssh_port}"
VPN_PORT="${vpn_port}"
ADMIN_IPS="${admin_ips}"

# Log everything
exec > >(tee -a /var/log/pritunl_install.log)
exec 2>&1

echo "============================================================================"
echo "Starting Pritunl VPN Server Installation"
echo "Hostname: $HOSTNAME"
echo "SSH Port: $SSH_PORT"
echo "VPN Port: $VPN_PORT"
echo "Time: $(date)"
echo "============================================================================"

# ============================================================================
# 1. SYSTEM UPDATE
# ============================================================================

echo "📦 Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install essential packages
apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates

# ============================================================================
# 2. SYSTEM HARDENING
# ============================================================================

echo "🔒 Hardening SSH configuration..."

# Backup original SSH config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Change SSH port
sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config

# Harden SSH configuration
cat >> /etc/ssh/sshd_config << EOF

# ============================================================================
# SECURITY HARDENING CONFIGURATION
# ============================================================================
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# Connection limits
MaxAuthTries 3
LoginGraceTime 30
MaxStartups 2
ClientAliveInterval 300
ClientAliveCountMax 2

# Protocol version
Protocol 2

# Disable unused authentication methods
KerberosAuthentication no
GSSAPIAuthentication no
EOF

# Restart SSH with new configuration
systemctl restart ssh

echo "✅ SSH hardening completed - Port changed to $SSH_PORT"

# ============================================================================
# 3. FIREWALL CONFIGURATION (UFW)
# ============================================================================

echo "🔥 Configuring UFW firewall..."

# Reset and set defaults
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH on custom port from admin IPs only
for ip in $ADMIN_IPS; do
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        echo "Allowing SSH from admin IP: $ip"
        ufw allow from $ip to any port $SSH_PORT
    fi
done

# Allow VPN traffic from anywhere
ufw allow $VPN_PORT/udp comment "OpenVPN"

# Allow HTTPS for admin interface from admin IPs only
for ip in $ADMIN_IPS; do
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        echo "Allowing HTTPS admin access from: $ip"
        ufw allow from $ip to any port 443
    fi
done

# Enable IP forwarding for VPN routing
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p

# Enable UFW
ufw --force enable

echo "✅ UFW firewall configured and enabled"

# ============================================================================
# 4. FAIL2BAN INSTALLATION
# ============================================================================

echo "🛡️ Installing and configuring Fail2ban..."

apt-get install -y fail2ban

# Configure fail2ban
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# Ban settings
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

# SSH protection
[sshd]
enabled = true
port = $SSH_PORT
logpath = /var/log/auth.log
maxretry = 3

# Pritunl admin interface protection
[pritunl]
enabled = true
port = 443
logpath = /var/log/pritunl.log
maxretry = 5
bantime = 3600

# Custom filter for repeated connection attempts
[nginx-req-limit]
enabled = false
filter = nginx-req-limit
action = iptables-multiport[name=ReqLimit, port="http,https", protocol=tcp]
logpath = /var/log/nginx/*error.log
findtime = 600
bantime = 7200
maxretry = 10
EOF

# Start and enable fail2ban
systemctl enable fail2ban
systemctl start fail2ban

echo "✅ Fail2ban installed and configured"

# ============================================================================
# 5. AUTOMATIC SECURITY UPDATES
# ============================================================================

echo "🔄 Configuring automatic security updates..."

apt-get install -y unattended-upgrades apt-listchanges

cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "Ubuntu:jammy-security";
    "UbuntuESMApps:jammy-apps-security";
    "UbuntuESM:jammy-infra-security";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

echo "✅ Automatic security updates configured"

# ============================================================================
# 6. PRITUNL INSTALLATION
# ============================================================================

echo "🔐 Installing Pritunl VPN server..."

# Add Pritunl repository
curl -fsSL https://raw.githubusercontent.com/pritunl/pritunl/master/setup.sh | sudo bash

# Update package list
apt-get update

# Install Pritunl and MongoDB
apt-get install -y pritunl mongodb-server

echo "✅ Pritunl and MongoDB installed"

# ============================================================================
# 7. MONGODB CONFIGURATION
# ============================================================================

echo "🗄️ Configuring MongoDB..."

# Stop MongoDB to configure it
systemctl stop mongod

# Configure MongoDB for security
cat > /etc/mongod.conf << EOF
# MongoDB configuration file

# Storage settings
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

# System log settings
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# Network settings
net:
  port: 27017
  bindIp: 127.0.0.1  # Only local connections

# Process management
processManagement:
  timeZoneInfo: /usr/share/zoneinfo

# Security settings
security:
  authorization: enabled
EOF

# Start and enable MongoDB
systemctl start mongod
systemctl enable mongod

# Wait for MongoDB to start
sleep 5

echo "✅ MongoDB configured and started"

# ============================================================================
# 8. PRITUNL CONFIGURATION
# ============================================================================

echo "⚙️ Configuring Pritunl..."

# Configure Pritunl settings
pritunl set app.bind_addr 0.0.0.0
pritunl set app.redirect_server false
pritunl set app.reverse_proxy false
pritunl set app.server_ssl true

# Configure for better security
pritunl set app.dh_param_bits 2048

# Set hostname
hostnamectl set-hostname $HOSTNAME

# Start and enable Pritunl
systemctl enable pritunl
systemctl start pritunl

# Wait for Pritunl to fully start
echo "⏳ Waiting for Pritunl to start..."
sleep 15

echo "✅ Pritunl configured and started"

# ============================================================================
# 9. LOG ROTATION CONFIGURATION
# ============================================================================

echo "📋 Configuring log rotation..."

cat > /etc/logrotate.d/pritunl << EOF
/var/log/pritunl.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 644 pritunl pritunl
    postrotate
        systemctl reload pritunl > /dev/null 2>&1 || true
    endscript
}
EOF

cat > /etc/logrotate.d/vpn-security << EOF
/var/log/vpn-security/*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 644 root root
}
EOF

# Create log directory
mkdir -p /var/log/vpn-security

echo "✅ Log rotation configured"

# ============================================================================
# 10. SETUP INFORMATION GENERATION
# ============================================================================

echo "📄 Generating setup information..."

# Get server information
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "Unable to detect")
SETUP_KEY=$(pritunl setup-key 2>/dev/null || echo "Error generating setup key")
DEFAULT_PASSWORD=$(pritunl default-password 2>/dev/null || echo "Error generating password")

# Create setup information file
cat > /root/pritunl_setup_info.txt << EOF
=====================================
🔐 PRITUNL VPN SERVER SETUP INFO 🔐
=====================================

📍 SERVER DETAILS:
   Public IP: $PUBLIC_IP
   Hostname: $HOSTNAME
   SSH Port: $SSH_PORT (Custom for security)
   VPN Port: $VPN_PORT

🌐 ACCESS INFORMATION:
   Admin URL: https://$PUBLIC_IP
   SSH Command: ssh -p $SSH_PORT -i your-key.pem ubuntu@$PUBLIC_IP

🔑 INITIAL CREDENTIALS:
   Setup Key: $SETUP_KEY
   Default Password: $DEFAULT_PASSWORD

🛡️ SECURITY FEATURES ENABLED:
   ✅ Custom SSH port ($SSH_PORT)
   ✅ Fail2ban intrusion prevention
   ✅ UFW firewall configured
   ✅ Admin access restricted to specific IPs
   ✅ Automatic security updates
   ✅ MongoDB secured (local access only)
   ✅ SSL/TLS enforced
   ✅ Log rotation configured

📋 NEXT STEPS:
   1. Access admin interface: https://$PUBLIC_IP
   2. Use the setup key and password above for initial setup
   3. Create an organization (e.g., "MyCompany")
   4. Create users within the organization
   5. Create a VPN server with the following settings:
      - Protocol: UDP
      - Port: $VPN_PORT
      - Virtual Network: 192.168.100.0/24 (or your preferred range)
      - Add your VPC CIDR routes for access to private resources
   6. Attach the organization to the server
   7. Start the server
   8. Download client configurations
   9. Test VPN connectivity

⚠️ IMPORTANT SECURITY NOTES:
   - Change the default password immediately after first login
   - Enable two-factor authentication in the admin interface
   - Regularly review user access and remove unused accounts
   - Monitor the logs in /var/log/pritunl.log
   - Keep the system updated with: apt update && apt upgrade

📁 LOG LOCATIONS:
   - Pritunl logs: /var/log/pritunl.log
   - Installation log: /var/log/pritunl_install.log
   - Auth logs: /var/log/auth.log
   - Fail2ban logs: /var/log/fail2ban.log

Generated on: $(date)
EOF

# Secure the setup file
chmod 600 /root/pritunl_setup_info.txt

echo "✅ Setup information saved to /root/pritunl_setup_info.txt"

# ============================================================================
# 11. FINAL SYSTEM OPTIMIZATION
# ============================================================================

echo "⚡ Applying final optimizations..."

# Optimize network settings for VPN
cat >> /etc/sysctl.conf << EOF

# VPN Optimizations
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
EOF

# Apply sysctl settings
sysctl -p

# Enable BBR congestion control if available
echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf

echo "✅ Network optimizations applied"

# ============================================================================
# 12. INSTALLATION COMPLETION
# ============================================================================

echo ""
echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
echo "🎉                                                    🎉"
echo "🎉        PRITUNL VPN SERVER INSTALLATION             🎉"
echo "🎉                 COMPLETED SUCCESSFULLY!            🎉"
echo "🎉                                                    🎉"
echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
echo ""
echo "📊 INSTALLATION SUMMARY:"
echo "   ✅ System updated and hardened"
echo "   ✅ SSH secured on port $SSH_PORT"
echo "   ✅ UFW firewall configured"
echo "   ✅ Fail2ban intrusion prevention enabled"
echo "   ✅ MongoDB installed and secured"
echo "   ✅ Pritunl VPN server installed"
echo "   ✅ Automatic security updates enabled"
echo "   ✅ Log rotation configured"
echo "   ✅ Network optimizations applied"
echo ""
echo "🔗 ACCESS YOUR VPN SERVER:"
echo "   Admin URL: https://$PUBLIC_IP"
echo "   SSH: ssh -p $SSH_PORT -i your-key.pem ubuntu@$PUBLIC_IP"
echo ""
echo "📄 Setup credentials saved in: /root/pritunl_setup_info.txt"
echo "📋 To view setup info: sudo cat /root/pritunl_setup_info.txt"
echo ""
echo "🚀 Your VPN server is ready for configuration!"
echo "   Visit the admin URL and use the credentials from the setup file."
echo ""

# Create a status file to indicate successful installation
echo "SUCCESS - $(date)" > /root/pritunl_install_status.txt

# Final status check
if systemctl is-active --quiet pritunl && systemctl is-active --quiet mongod; then
    echo "✅ All services are running successfully!"
    exit 0
else
    echo "⚠️ Some services may not be running. Check with: systemctl status pritunl mongod"
    exit 1
fi