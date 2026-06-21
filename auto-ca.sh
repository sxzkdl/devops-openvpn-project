#!/bin/bash
rm -rf ~/openvpn-ca-auto

sudo apt update && sudo apt install easy-rsa -y

make-cadir ~/openvpn-ca-auto
cd ~/openvpn-ca-auto

cat << 'EOF' >> vars
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "California"
set_var EASYRSA_REQ_CITY       "SanFrancisco"
set_var EASYRSA_REQ_ORG        "MyFirstProject"
set_var EASYRSA_REQ_EMAIL      "admin@ca-server.local"
set_var EASYRSA_REQ_OU         "IT"
set_var EASYRSA_ALGO           "ec"
set_var EASYRSA_DIGEST         "sha512"
EOF

./easyrsa init-pki
./easyrsa --batch build-ca nopass

echo "-----------------------------------------------------"
echo "Success: Certificate Authority (CA) has been created!"
echo "-----------------------------------------------------"
