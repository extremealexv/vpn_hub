from fastapi import FastAPI, Request, BackgroundTasks
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
import subprocess
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

WIFI_IFACE = os.environ.get("hub_wifi_iface", "wlan0")
def get_upstream_iface():
    try:
        output = subprocess.check_output(["iw", "dev"]).decode()
        for line in output.split("\n"):
            line = line.strip()
            if line.startswith("Interface ") and WIFI_IFACE not in line:
                return line.split(" ")[1]
    except:
        pass
    return os.environ.get("hub_upstream_wifi_iface", "wlan1")
app = FastAPI(title="VPN Hub Management")

app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

class WifiConnectRequest(BaseModel):
    ssid: str
    password: str = ""

def run_cmd(cmd: list) -> str:
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr.strip()}"
    except Exception as e:
        return f"Error: {str(e)}"

def get_interfaces_ips():
    ips = {}
    try:
        output = subprocess.check_output(["ip", "-4", "-o", "addr", "show"]).decode()
        for line in output.split("\n"):
            if not line.strip(): continue
            parts = line.split()
            if len(parts) >= 4:
                iface = parts[1]
                ip_cidr = parts[3]
                ip = ip_cidr.split('/')[0]
                if iface != "lo":
                    ips[iface] = ip
    except:
        pass
    return ips

def get_connected_clients():
    clients = []
    try:
        output = subprocess.check_output(["ip", "neighbor", "show", "dev", WIFI_IFACE]).decode()
        for line in output.split("\n"):
            parts = line.split()
            if len(parts) >= 3 and "FAILED" not in parts:
                ip = parts[0]
                try:
                    mac_idx = parts.index("lladdr") + 1
                    mac = parts[mac_idx]
                    clients.append({"ip": ip, "mac": mac})
                except ValueError:
                    pass
    except:
        pass
    
    hostnames = {}
    lease_dirs = ["/var/lib/NetworkManager", "/var/lib/misc"]
    for d in lease_dirs:
        if not os.path.exists(d): continue
        for f in os.listdir(d):
            if f.endswith(".leases"):
                try:
                    with open(os.path.join(d, f), 'r') as file:
                        for line in file:
                            parts = line.split()
                            if len(parts) >= 4:
                                hostnames[parts[1].lower()] = parts[3]
                except:
                    pass
                    
    for c in clients:
        c['hostname'] = hostnames.get(c['mac'].lower(), "Unknown Device")
        
    return clients

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/api/status")
async def get_status():
    # Check VPN
    vpn_status = "Disconnected"
    try:
        wg_show = subprocess.check_output(["wg", "show", "wg0"], stderr=subprocess.DEVNULL).decode()
        if "latest handshake" in wg_show:
            vpn_status = "Connected"
    except:
        pass

    # Check Upstream Wi-Fi
    upstream_status = "Disconnected"
    upstream_ssid = ""
    try:
        nmcli_conn = subprocess.check_output(["nmcli", "-t", "-f", "NAME,DEVICE,STATE,TYPE", "con", "show", "--active"], stderr=subprocess.DEVNULL).decode()
        for line in nmcli_conn.split("\n"):
            parts = line.split(":")
            if len(parts) >= 4 and parts[3] == "802-11-wireless" and parts[2] == "activated" and parts[0] != "Hotspot":
                upstream_status = "Connected"
                upstream_ssid = parts[0]
                break
    except:
        pass

    # Basic internet check
    internet_status = "Disconnected"
    try:
        if subprocess.call(["ping", "-c", "1", "-W", "2", "8.8.8.8"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
            internet_status = "Connected"
    except:
        pass

    return {
        "vpn": vpn_status,
        "upstream_wifi": upstream_status,
        "upstream_ssid": upstream_ssid,
        "internet": internet_status,
        "interfaces": get_interfaces_ips(),
        "clients": get_connected_clients()
    }

def trigger_rescan():
    try:
        subprocess.run(["nmcli", "dev", "wifi", "rescan", "ifname", get_upstream_iface()], capture_output=True)
    except Exception as e:
        logger.error(f"Rescan failed: {e}")

@app.get("/api/wifi/scan")
async def scan_wifi(background_tasks: BackgroundTasks):
    try:
        # Schedule rescan to happen AFTER the HTTP response is sent, so the AP drop doesn't break the UI
        background_tasks.add_task(trigger_rescan)
        
        upstream_iface = get_upstream_iface()
        output = subprocess.check_output(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "ifname", upstream_iface]).decode()
        networks = []
        seen_ssids = set()
        for line in output.split('\n'):
            parts = line.split(':')
            if len(parts) >= 3:
                ssid = parts[0].replace('\\:', ':')
                signal = parts[1]
                security = parts[2]
                if ssid and ssid not in seen_ssids:
                    seen_ssids.add(ssid)
                    networks.append({"ssid": ssid, "signal": signal, "security": security})
        # Sort by signal strength
        networks = sorted(networks, key=lambda x: int(x['signal']), reverse=True)
        return {"status": "success", "networks": networks}
    except Exception as e:
        logger.error(f"Scan API Exception: {str(e)}")
        return JSONResponse(status_code=500, content={"status": "error", "message": str(e)})

@app.post("/api/wifi/connect")
async def connect_wifi(req: WifiConnectRequest):
    upstream_iface = get_upstream_iface()
    cmd = ["nmcli", "dev", "wifi", "connect", req.ssid, "ifname", upstream_iface]
    if req.password:
        cmd.extend(["password", req.password])
    
    result = run_cmd(cmd)
    if "Error" in result or "failed" in result.lower():
        if "Secrets were required" in result or "Connection activation failed" in result:
             return JSONResponse(status_code=400, content={"status": "error", "message": f"Connection failed. The network might be out of range, rejecting the device, or requires a password. Details: {result}"})
        return JSONResponse(status_code=400, content={"status": "error", "message": result})
    return {"status": "success", "message": "Connected to Wi-Fi"}

@app.post("/api/vpn/toggle")
async def toggle_vpn():
    status = await get_status()
    if status["vpn"] == "Connected":
        res = run_cmd(["systemctl", "stop", "wg-quick@wg0"])
    else:
        res = run_cmd(["systemctl", "start", "wg-quick@wg0"])
    
    if "Error" in res:
        return JSONResponse(status_code=400, content={"status": "error", "message": res})
    return {"status": "success", "message": "Toggled VPN state"}

@app.post("/api/system/reboot")
async def reboot_system():
    run_cmd(["reboot"])
    return {"status": "success"}
