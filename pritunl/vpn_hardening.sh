#!/bin/bash

set -e

echo "🔒 Starting VPN Server Hardening on Amazon Linux 2023..."

### 1. SSH Hardening
echo "🔧 Configuring SSH settings..."

sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#LoginGraceTime.*/LoginGraceTime 30/' /etc/ssh/sshd_config
sudo sed -i 's/^#MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
sudo sed -i 's/^#MaxSessions.*/MaxSessions 2/' /etc/ssh/sshd_config

sudo systemctl restart sshd
echo "✅ SSH hardened."

### 2. Iptables Basic Rules
echo "🧱 Applying iptables rules..."

# Flush existing rules
sudo iptables -F
sudo iptables -X

# Default policy
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Allow loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Allow established sessions
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (port 22)
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS (ports 80/443) for nginx
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow Pritunl (OpenVPN default ports)
sudo iptables -A INPUT -p udp --dport 1194 -j ACCEPT

# Save rules
sudo iptables-save | sudo tee /etc/iptables.rules

# Load iptables on boot
cat << 'EOF' | sudo tee /etc/systemd/system/iptables-restore.service
[Unit]
Description=Restore iptables rules
DefaultDependencies=no
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/iptables-restore /etc/iptables.rules
ExecReload=/usr/sbin/iptables-restore /etc/iptables.rules
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl enable --now iptables-restore.service
echo "✅ iptables rules applied and persistent."

### 3. Disable IPv6 (optional)
echo "🚫 Disabling IPv6 (optional)..."

sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

sudo sysctl -p

### 4. Kernel Hardening (Sysctl)
echo "🛡️ Applying basic sysctl hardening..."

sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
EOF

sudo sysctl -p
echo "✅ Kernel hardening applied."

### 5. Final Check
echo "🔍 Final Listening Ports Check:"
sudo lsof -i -P -n | grep LISTEN

echo "🎉 Server hardening completed successfully."
