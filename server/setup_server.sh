#!/bin/bash
# server/setup_server.sh

source /etc/vpn_hub/shared/utils.sh
source /etc/vpn_hub/shared/config.sh

check_root

log_info "Updating system and installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wireguard iptables netfilter-persistent iptables-persistent

log_info "Enabling IP forwarding..."
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sysctl -p

if [ ! -d /etc/wireguard ]; then
    mkdir -p /etc/wireguard
    chmod 700 /etc/wireguard
fi

log_info "Generating WireGuard keys..."
cd /etc/wireguard
if [ ! -f server_private.key ]; then
    wg genkey | tee server_private.key | wg pubkey > server_public.key
    wg genkey | tee client_private.key | wg pubkey > client_public.key
    chmod 600 *.key
fi

SERVER_PRIV=$(cat server_private.key)
SERVER_PUB=$(cat server_public.key)
CLIENT_PRIV=$(cat client_private.key)
CLIENT_PUB=$(cat client_public.key)

# VPN network config: Server 10.8.0.1, Hub 10.8.0.2
VPN_SUBNET="10.8.0.0/24"
SERVER_IP="10.8.0.1"
CLIENT_IP="10.8.0.2"

# Detect default interface for MASQUERADE
DEFAULT_IFACE=$(ip route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
if [ -z "$DEFAULT_IFACE" ]; then 
    DEFAULT_IFACE="eth0"
fi
log_info "Detected default route interface: $DEFAULT_IFACE"

log_info "Configuring server wg0..."
cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
Address = $SERVER_IP/24
ListenPort = $vpn_port
PrivateKey = $SERVER_PRIV

# Firewall rules for NAT
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $DEFAULT_IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $DEFAULT_IFACE -j MASQUERADE

[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = $CLIENT_IP/32
EOF

chmod 600 /etc/wireguard/wg0.conf

log_info "Creating client wg0.conf for the Hub..."
mkdir -p /etc/vpn_hub/server
cat <<EOF > /etc/vpn_hub/server/client_wg0.conf
[Interface]
Address = $CLIENT_IP/24
PrivateKey = $CLIENT_PRIV

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $nat_name:$vpn_port
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

chmod 600 /etc/vpn_hub/server/client_wg0.conf
cp /etc/vpn_hub/server/client_wg0.conf /home/$user/client_wg0.conf
chown $user:$user /home/$user/client_wg0.conf

log_info "Starting and enabling wg-quick@wg0..."
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

log_info "VPN Server setup completed successfully."
