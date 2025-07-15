#!/bin/bash

set -e
set -x

echo "🔍 Verifying Pritunl and MongoDB setup..."

# Check MongoDB service
echo "🔄 Checking MongoDB service status..."
systemctl is-active --quiet mongod && echo "✅ MongoDB is running" || echo "❌ MongoDB is NOT running"

# Check MongoDB authorization enabled
echo "🔐 Verifying MongoDB authorization..."
grep -q 'authorization: enabled' /etc/mongod.conf && echo "✅ MongoDB authorization is enabled" || echo "❌ MongoDB authorization NOT enabled"

# Check Pritunl service
echo "🔄 Checking Pritunl service status..."
systemctl is-active --quiet pritunl && echo "✅ Pritunl is running" || echo "❌ Pritunl is NOT running"

# Check MongoDB URI in Pritunl config
echo "🔧 Checking MongoDB URI in Pritunl config..."
grep -q 'mongodb://pritunl:' /etc/pritunl.conf && echo "✅ MongoDB URI configured in Pritunl" || echo "❌ MongoDB URI missing or incorrect"


# SSH Hardening
echo "🔐 Verifying SSH Hardening..."
grep -q '^Port 22022' /etc/ssh/sshd_config && echo "✅ SSH Port changed to 22022" || echo "❌ SSH port NOT changed"
grep -q '^PermitRootLogin no' /etc/ssh/sshd_config && echo "✅ Root login disabled" || echo "❌ Root login still allowed"
grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config && echo "✅ Password auth disabled" || echo "❌ Password auth still enabled"

# Kernel Hardening Checks
echo "🔍 Checking kernel sysctl settings..."
sysctl net.ipv4.tcp_syncookies | grep -q '= 1' && echo "✅ Syncookies enabled"
sysctl net.ipv4.ip_forward | grep -q '= 1' && echo "✅ IP forwarding enabled"
sysctl net.ipv6.conf.all.disable_ipv6 | grep -q '= 1' && echo "✅ IPv6 disabled"

# Check Firewall Rules
echo "🚦 Checking firewalld status and rules..."
systemctl is-active --quiet firewalld && echo "✅ firewalld is running" || echo "❌ firewalld is NOT running"
echo "📜 Allowed ports:"
firewall-cmd --list-ports

# SSH port listening
echo "📡 Checking SSH listening port..."
ss -tulpn | grep :22022 && echo "✅ SSH is listening on port 22022" || echo "❌ SSH not listening on 22022"

echo "🎯 Verification completed."
