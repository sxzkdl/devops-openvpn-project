#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo!"
  exit 1
fi

echo "-----------------------------------------"
echo "Starting VPN Security & Service Setup..."
echo "-----------------------------------------"

echo "Installing custom configuration deb-package..."
dpkg -i /home/$SUDO_USER/build/openvpn-config-custom.deb

echo "Enabling IP Forwarding..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn.conf
sysctl --system

echo "Configuring UFW Firewall..."
apt install ufw -y
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp        
ufw allow 1194/udp       

INTERFACE=$(ip route show default | awk '{print $5}')

sed -i "1i # OpenVPN NAT Rules\n*nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -s 10.8.0.0/24 -o $INTERFACE -j MASQUERADE\nCOMMIT\n" /etc/ufw/before.rules

echo "y" | ufw enable

echo "Starting OpenVPN service..."
systemctl start openvpn-server@server
systemctl enable openvpn-server@server

echo "-------------------------------------------------"
echo "Success: VPN Server has been secured and started!"
echo "-------------------------------------------------"
