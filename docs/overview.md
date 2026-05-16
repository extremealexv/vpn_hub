# VPN Hub Product Overview

The VPN Hub project is an automated, fully reusable Travel VPN system designed to provide secure, encrypted internet access for all your devices while traveling. It effectively solves the "Captive Portal" problem (where hotel/airport Wi-Fi requires a web login) by introducing a sleek Management UI.

The system consists of two primary components: the **VPN Server** and the **VPN Hub**.

## 1. VPN Server (Home Base)
The Server resides securely in your home network and acts as the exit node for all your traffic.
- **WireGuard Server:** Hosts the secure VPN tunnel endpoint on a designated UDP port.
- **NAT Gateway:** Utilizes `iptables` rules to automatically masquerade incoming VPN traffic, making it appear as if it originates from your home network. This bypasses geographic restrictions (e.g., streaming services) and secures your traffic from untrusted public networks.
- **Client Configuration Generation:** Automatically generates the WireGuard client configuration file (`client_wg0.conf`) containing the cryptographic keys needed by the Hub.

## 2. VPN Hub (Portable Router)
The Hub is the physical device (e.g., Orange Pi) that travels with you. 
- **Wi-Fi Hotspot:** Uses `NetworkManager` to broadcast a persistent secure Wi-Fi Hotspot (e.g., `VPN_Hub_AP`). You connect all your personal devices (phone, laptop, tablet) to this Hotspot once.
- **WireGuard Client:** Establishes the secure tunnel back to your Home Server. When active, all traffic from connected devices is routed through the tunnel.
- **Virtual Interface (`wlan1`):** Automatically provisions a secondary virtual Wi-Fi interface. This allows the Hub to scan and connect to upstream hotel Wi-Fi networks without dropping the active Hotspot on `wlan0`.

## 3. Management UI (Captive Portal Solver)
When traveling, public Wi-Fi often requires logging into a Captive Portal. Headless Linux devices struggle with this. To solve this, the Hub hosts a lightweight, modern FastAPI web server on port 80.
- **Access:** Connect your phone to `VPN_Hub_AP` and navigate to `http://10.42.0.1` (the default gateway).
- **Wi-Fi Management:** Scan for surrounding hotel/cafe networks and connect to them directly from the UI.
- **Captive Portals:** Once the Hub connects to the hotel Wi-Fi, your phone (already connected to the Hub) can open the hotel's Captive Portal page and complete the login.
- **VPN Toggle:** After authenticating with the public network, simply click "Toggle VPN" in the UI to bring up the secure WireGuard tunnel. All your devices are now securely routed home!
