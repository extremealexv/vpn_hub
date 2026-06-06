#!/bin/bash
# hub/setup_hub.sh

source /etc/vpn_hub/shared/utils.sh
source /etc/vpn_hub/shared/config.sh

check_root

log_info "Updating system and installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wireguard network-manager python3-pip python3-venv iptables netfilter-persistent iptables-persistent

log_info "Configuring NetworkManager for AP Hotspot..."
# Remove old hotspot if exists
nmcli con delete Hotspot &>/dev/null

SSID=${hub_ssid:-"VPN_Hub_AP"}
WIFI_PASS=${hub_password:-"vpnhub123"}

WIFI_IFACE=${hub_wifi_iface:-"wlan0"}
VIRT_WIFI_IFACE=${hub_virt_wifi_iface:-"wlan1"}

nmcli dev wifi hotspot ifname "$WIFI_IFACE" ssid "$SSID" password "$WIFI_PASS" con-name Hotspot
nmcli con modify Hotspot connection.autoconnect yes
nmcli con modify Hotspot 802-11-wireless-security.wps-method 1
nmcli con modify Hotspot 802-11-wireless-security.pmf 1
nmcli con modify Hotspot 802-11-wireless.band bg

log_info "Setting up WireGuard client..."
if [ -f /etc/vpn_hub/hub/client_wg0.conf ]; then
    cp /etc/vpn_hub/hub/client_wg0.conf /etc/wireguard/wg0.conf
    chmod 600 /etc/wireguard/wg0.conf
else
    log_warn "client_wg0.conf not found! You must deploy it from the server manually."
fi

# Do not enable wg-quick on boot yet, let UI or watchdog manage it
systemctl disable wg-quick@wg0 &>/dev/null

log_info "Setting up Management UI..."
mkdir -p /opt/vpn_hub_ui
cp -r /etc/vpn_hub/hub/management_ui/* /opt/vpn_hub_ui/

cd /opt/vpn_hub_ui
python3 -m venv venv
./venv/bin/pip install -r requirements.txt

log_info "Creating systemd service for Management UI..."
cat <<EOF > /etc/systemd/system/vpn-hub-ui.service
[Unit]
Description=VPN Hub Management UI
After=network.target NetworkManager.service

[Service]
User=root
WorkingDirectory=/opt/vpn_hub_ui
EnvironmentFile=/etc/vpn_hub/.sbc.conf
ExecStartPre=-/usr/sbin/iw dev $WIFI_IFACE interface add $VIRT_WIFI_IFACE type managed
ExecStartPre=-/usr/bin/ip link set $VIRT_WIFI_IFACE up
ExecStartPre=-/usr/bin/nmcli dev set $VIRT_WIFI_IFACE managed yes
ExecStart=/opt/vpn_hub_ui/venv/bin/uvicorn main:app --host 0.0.0.0 --port 80
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vpn-hub-ui
systemctl restart vpn-hub-ui

log_info "VPN Hub setup completed successfully."
