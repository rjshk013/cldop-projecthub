#!/bin/bash

set -e

# ========== Configuration ==========
MONGO_ADMIN="admin"
MONGO_ADMIN_PASS="MongoRootPass@123"
PRITUNL_DB="pritunl"
PRITUNL_USER="pritunluser"
PRITUNL_PASS="PritunlStrongPassword!"
ENCODED_PASS=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$PRITUNL_PASS'))")

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

echo "📦 Installing Pritunl, MongoDB, WireGuard tools..."

# Update and install packages
sudo dnf -y update
sudo dnf -y install pritunl pritunl-openvpn wireguard-tools mongodb-org

echo "🚀 Enabling and starting MongoDB..."
sudo systemctl enable --now mongod

echo "⏳ Waiting for MongoDB to initialize..."
sleep 5

echo "🔐 Creating MongoDB users..."

# Create MongoDB admin and Pritunl users
mongosh <<EOF
use admin
db.createUser({
  user: "$MONGO_ADMIN",
  pwd: "$MONGO_ADMIN_PASS",
  roles: [ { role: "root", db: "admin" } ]
})

use $PRITUNL_DB
db.createUser({
  user: "$PRITUNL_USER",
  pwd: "$PRITUNL_PASS",
  roles: [ { role: "readWrite", db: "$PRITUNL_DB" } ]
})
EOF

echo "🔒 Enabling MongoDB authentication..."

# Enable authorization in mongod.conf
sudo sed -i '/#security:/a\security:\n  authorization: "enabled"' /etc/mongod.conf

echo "🔁 Restarting MongoDB to apply authentication settings..."
sudo systemctl restart mongod
sleep 5

echo "🛠️ Updating Pritunl config with secure MongoDB URI..."

# Backup original config
sudo cp /etc/pritunl.conf /etc/pritunl.conf.bak

# Update Pritunl config with secure MongoDB URI
sudo jq ".mongodb_uri = \"mongodb://${PRITUNL_USER}:${ENCODED_PASS}@127.0.0.1:27017/${PRITUNL_DB}\"" /etc/pritunl.conf.bak | sudo tee /etc/pritunl.conf > /dev/null

echo "🔁 Restarting Pritunl..."
sudo systemctl enable --now pritunl
sudo systemctl restart pritunl

echo "✅ Pritunl installed and connected securely to MongoDB with authentication."
