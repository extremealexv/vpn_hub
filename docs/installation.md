# VPN Hub Installation Guide

Follow these steps to deploy the automated VPN Server and Hub.

## Step 1: Clone the Repository
Clone this repository to a control machine (your laptop or a local server) from which you will run the deployment script.
```bash
git clone https://github.com/extremealexv/vpn_hub
cd vpn_hub
```

## Step 2: Configure `.sbc.conf`
At the root of the project, you will find an `.sbc.conf.example` file. Copy or rename this file to `.sbc.conf` and edit it to define your environment variables. The deployment script will use this file to securely SSH into the target machines and provision them.

```bash
cp .sbc.conf.example .sbc.conf
nano .sbc.conf
```

Example `.sbc.conf` contents:
```ini
vpn_server_ip=192.168.1.60
vpn_hub_ip=192.168.1.231
user=orangepi
password=orangepi
nat_name=yourdomain.tech
vpn_port=8443
hub_wifi_iface=wlan0
hub_virt_wifi_iface=wlan1
```
*(Make sure the user and password are valid for both SBCs, or adjust the deployment scripts accordingly).*

## Step 3: Deploy the Server
Run the deployment script targeting the `server`:
```bash
./deploy.sh server
```
This will:
1. SSH into `vpn_server_ip`.
2. Install WireGuard and generate cryptographic keys.
3. Configure `iptables` NAT routing for full tunnel internet access.
4. Export the `client_wg0.conf` file back to your local `hub/` directory.

## Step 4: Deploy the Hub
Ensure the VPN Hub is connected to your local network via Ethernet (or a temporary Wi-Fi connection) so it is reachable at `vpn_hub_ip`. Run:
```bash
./deploy.sh hub
```
This will:
1. SSH into `vpn_hub_ip`.
2. Configure `NetworkManager` to broadcast the Hotspot (`VPN_Hub_AP`).
3. Setup the WireGuard client profile using the generated `client_wg0.conf`.
4. Install and start the FastAPI Management UI on port 80.

## Step 5: Connect and Use!
1. Unplug the Hub's Ethernet cable (simulate traveling).
2. On your phone or laptop, connect to the new Wi-Fi network:
   - **SSID:** `VPN_Hub_AP`
   - **Password:** `vpnhub123` *(configurable in `setup_hub.sh`)*
3. Open a web browser and navigate to the Management UI:
   - **URL:** `http://10.42.0.1`
4. Use the interface to **Scan Networks**, connect to the hotel's upstream Wi-Fi, and complete any Captive Portal logins.
5. Click **Connect VPN** to secure the tunnel. You are now safely connected to your home network!
