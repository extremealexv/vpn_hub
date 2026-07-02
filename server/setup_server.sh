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

if [ ! -f windows_private.key ]; then
    wg genkey | tee windows_private.key | wg pubkey > windows_public.key
    chmod 600 windows_*.key
fi

SERVER_PRIV=$(cat server_private.key)
SERVER_PUB=$(cat server_public.key)
CLIENT_PRIV=$(cat client_private.key)
CLIENT_PUB=$(cat client_public.key)
WINDOWS_PRIV=$(cat windows_private.key)
WINDOWS_PUB=$(cat windows_public.key)

# VPN network config: Server 10.8.0.1, Hub 10.8.0.2, Windows 10.8.0.3
VPN_SUBNET="10.8.0.0/24"
SERVER_IP="10.8.0.1"
CLIENT_IP="10.8.0.2"
WINDOWS_IP="10.8.0.3"

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

# Firewall rules for NAT and MTU
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $DEFAULT_IFACE -j MASQUERADE; iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $DEFAULT_IFACE -j MASQUERADE; iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = $CLIENT_IP/32

[Peer]
PublicKey = $WINDOWS_PUB
AllowedIPs = $WINDOWS_IP/32
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

log_info "Creating Windows wg0.conf..."
cat <<EOF > /etc/vpn_hub/server/windows_wg0.conf
[Interface]
Address = $WINDOWS_IP/24
PrivateKey = $WINDOWS_PRIV
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $nat_name:$vpn_port
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

chmod 600 /etc/vpn_hub/server/windows_wg0.conf
cp /etc/vpn_hub/server/windows_wg0.conf /home/$user/windows_wg0.conf
chown $user:$user /home/$user/windows_wg0.conf

log_info "Starting and enabling wg-quick@wg0..."
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

log_info "VPN Server setup completed successfully."
