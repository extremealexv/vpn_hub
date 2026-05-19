from fastapi import FastAPI, Request, BackgroundTasks
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
import subprocess
import os

WIFI_IFACE = os.environ.get("hub_wifi_iface", "wlan0")
VIRT_IFACE = os.environ.get("hub_virt_wifi_iface", "wlan1")

def ensure_virt_iface():
    if not os.path.exists(f"/sys/class/net/{VIRT_IFACE}"):
        subprocess.run(["iw", "dev", WIFI_IFACE, "interface", "add", VIRT_IFACE, "type", "managed"])
        subprocess.run(["ip", "link", "set", VIRT_IFACE, "up"])

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
        "internet": internet_status
    }

@app.get("/api/wifi/scan")
async def scan_wifi():
    try:
        ensure_virt_iface()
        # Rescan
        subprocess.run(["nmcli", "dev", "wifi", "rescan", "ifname", VIRT_IFACE], capture_output=True)
        output = subprocess.check_output(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "ifname", VIRT_IFACE]).decode()
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
        return JSONResponse(status_code=500, content={"status": "error", "message": str(e)})

@app.post("/api/wifi/connect")
async def connect_wifi(req: WifiConnectRequest):
    ensure_virt_iface()
    cmd = ["nmcli", "dev", "wifi", "connect", req.ssid, "ifname", VIRT_IFACE]
    if req.password:
        cmd.extend(["password", req.password])
    
    result = run_cmd(cmd)
    if "Error" in result or "failed" in result.lower():
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
