# VPN Hub Pre-requisites

Before deploying the Travel VPN system, ensure you have the following hardware, software, and network configuration ready.

## 1. Hardware Requirements
You need **two** separate machines (typically SBCs like Orange Pi, Raspberry Pi, or any Linux machine):
* **VPN Server:** Remains at your home base. Acts as the gateway to your home network and the public internet.
* **VPN Hub (Travel Router):** Travels with you. Broadcasts a Wi-Fi Hotspot for your devices and tunnels all traffic back to the Server. Must have a Wi-Fi adapter capable of simultaneous AP/Station mode (or use a secondary USB Wi-Fi dongle).

## 2. Operating System & Kernel Requirements
Both machines must be running a **Debian or Ubuntu-based OS** (e.g., Ubuntu Server, Armbian, Raspberry Pi OS). 

> [!IMPORTANT]
> **Kernel Modules Required:** The kernel on both devices **MUST** have the `tun` and `wireguard` modules enabled. If you are using a custom or minimal SBC image (like certain Orange Pi builds), you may need to compile the kernel yourself to enable these modules (`CONFIG_TUN=y` and `CONFIG_WIREGUARD=m`). Official Ubuntu/Debian images typically include these by default.

## 3. Network Configuration

### Dynamic DNS (DDNS)
Unless your home internet has a static IP address, you must configure a **Dynamic DNS** (e.g., `vasilyev.tech`, `myhome.duckdns.org`). This ensures the Travel Hub can always locate your home Server even if your ISP changes your IP.

### Port Forwarding
Log into your home router and configure **Port Forwarding**:
* **Protocol:** UDP
* **Port:** `8443` (or the port defined in `.sbc.conf`)
* **Destination IP:** The static local IP of your VPN Server (e.g., `192.168.1.60`).

## 4. Software Dependencies
The deployment script automatically installs the necessary packages, but ensures the devices have internet access during initial setup. Packages installed include:
* `wireguard`
* `network-manager` (Crucial for the Hub's hotspot and Wi-Fi management)
* `iptables` and `netfilter-persistent` (For Server NAT routing)
* `python3`, `pip`, `venv` (For the Hub Management UI)
