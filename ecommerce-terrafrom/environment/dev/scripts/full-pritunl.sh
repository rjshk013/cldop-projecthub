#!/bin/bash

set -e

### CONFIGURATION ###
# DOMAIN="vpn.ninz.store"
# EMAIL="admin@example.com"
PRITUNL_PORT="9700"
MONGO_USER="pritunl_admin"
MONGO_PASS="PritunlStrongPassword!"
ENCODED_PASS=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$MONGO_PASS'))")

echo "🔧 Setting up MongoDB and Pritunl repositories..."

# MongoDB repo (8.0 for Amazon Linux 2023)
sudo tee /etc/yum.repos.d/mongodb-org.repo > /dev/null << EOF
[mongodb-org]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/8.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-8.0.asc
EOF

# Pritunl repo for Amazon Linux 2023
sudo tee /etc/yum.repos.d/pritunl.repo > /dev/null << EOF
[pritunl]
name=Pritunl Repository
baseurl=https://repo.pritunl.com/stable/yum/amazonlinux/2023/
gpgcheck=1
enabled=1
gpgkey=https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc
EOF

echo "📦 Installing Pritunl, MongoDB..."
sudo dnf -y update
sudo dnf -y install pritunl pritunl-openvpn wireguard-tools mongodb-org

# Start services
sudo systemctl enable --now mongod pritunl

echo "⏳ Waiting for MongoDB to initialize..."
sleep 10

### MongoDB Hardening
echo "🔐 Securing MongoDB and creating user for Pritunl..."
mongo <<EOF
use admin
db.createUser({
  user: "$MONGO_USER",
  pwd: "$MONGO_PASS",
  roles: [ { role: "root", db: "admin" } ]
})
EOF

sudo sed -i 's/#security:/security:\n  authorization: enabled/' /etc/mongod.conf
sudo systemctl restart mongod

echo "⚙️ Updating /etc/pritunl.conf with MongoDB URI..."
sudo tee /etc/pritunl.conf > /dev/null << EOF
{
  "mongodb_uri": "mongodb://$MONGO_USER:$ENCODED_PASS@localhost:27017/admin"
}
EOF

echo "🔁 Restarting Pritunl with new MongoDB auth..."
sudo systemctl restart pritunl

### Configure Pritunl for Reverse Proxy
echo "🌐 Configuring Pritunl for NGINX reverse proxy..."
sudo pritunl set app.reverse_proxy true
sudo pritunl set app.redirect_server false
sudo pritunl set app.server_ssl false
sudo pritunl set app.server_port $PRITUNL_PORT

### VPN Server Hardening
echo "🔒 Applying production-grade hardening..."

## SSH Hardening
#sudo sed -i 's/^#Port.*/Port 22022/' /etc/ssh/sshd_config 
sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#LoginGraceTime.*/LoginGraceTime 30/' /etc/ssh/sshd_config
sudo sed -i 's/^#MaxAuthTries.*/MaxAuthTries 10/' /etc/ssh/sshd_config
sudo sed -i 's/^#MaxSessions.*/MaxSessions 6/' /etc/ssh/sshd_config
sudo systemctl restart sshd

## iptables basic
echo "🧱 Setting up iptables firewall rules..."
sudo iptables -F
sudo iptables -X
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 1194 -j ACCEPT
sudo iptables-save | sudo tee /etc/iptables.rules

# Load iptables on boot
sudo tee /etc/systemd/system/iptables-restore.service > /dev/null << 'EOF'
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

## IPv6 Disable
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sudo sysctl -p

## Kernel sysctl
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

### ✅ Final Verification
echo "🎯 Final Port Listening Check:"
sudo lsof -i :80 | grep LISTEN || echo "❌ Port 80 not listening!"
sudo lsof -i :443 | grep LISTEN || echo "❌ Port 443 not listening!"
sudo lsof -i :$PRITUNL_PORT | grep LISTEN || echo "❌ Pritunl port $PRITUNL_PORT not listening!"

echo "✅ Full VPN Server Setup with Hardening Completed Successfully!"
