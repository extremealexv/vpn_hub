import customtkinter as ctk
import subprocess
import os
import sys
import ctypes
import threading
import time

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class VPNApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("VPN Hub - Windows Client")
        self.geometry("400x320")
        self.resizable(False, False)

        self.wireguard_path = r"C:\Program Files\WireGuard\wireguard.exe"
        
        # When compiled with PyInstaller, the conf file should be in the same folder as the exe
        if getattr(sys, 'frozen', False):
            base_path = os.path.dirname(sys.executable)
        else:
            base_path = os.path.dirname(os.path.abspath(__file__))
            
        self.conf_path = os.path.join(base_path, "windows_wg0.conf")
        self.tunnel_name = "windows_wg0"
        self.is_connected = False

        self.setup_ui()
        self.check_status_loop()

    def setup_ui(self):
        self.title_label = ctk.CTkLabel(self, text="VPN Hub", font=ctk.CTkFont(size=28, weight="bold"))
        self.title_label.pack(pady=(30, 5))
        
        self.subtitle_label = ctk.CTkLabel(self, text="Windows Client", font=ctk.CTkFont(size=12), text_color="gray")
        self.subtitle_label.pack(pady=(0, 20))

        self.status_label = ctk.CTkLabel(self, text="Status: Checking...", font=ctk.CTkFont(size=14))
        self.status_label.pack(pady=(0, 25))

        self.toggle_btn = ctk.CTkButton(self, text="Connect", font=ctk.CTkFont(size=16, weight="bold"), height=50, width=200, command=self.toggle_vpn)
        self.toggle_btn.pack()
        
        self.log_label = ctk.CTkLabel(self, text="", text_color="gray", font=ctk.CTkFont(size=12))
        self.log_label.pack(pady=(20, 0))

    def check_is_connected(self):
        try:
            # Check if the service is running (WireGuard creates a service named WireGuardTunnel$Name)
            output = subprocess.check_output(["sc", "query", f"WireGuardTunnel${self.tunnel_name}"], stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW).decode()
            if "RUNNING" in output:
                return True
        except subprocess.CalledProcessError:
            pass
        return False

    def update_ui(self):
        self.is_connected = self.check_is_connected()
        if self.is_connected:
            self.status_label.configure(text="Status: Connected", text_color="#2ecc71")
            self.toggle_btn.configure(text="Disconnect", fg_color="#e74c3c", hover_color="#c0392b")
        else:
            self.status_label.configure(text="Status: Disconnected", text_color="gray")
            self.toggle_btn.configure(text="Connect", fg_color="#3498db", hover_color="#2980b9")

    def check_status_loop(self):
        self.update_ui()
        self.after(3000, self.check_status_loop)

    def toggle_vpn(self):
        if not os.path.exists(self.wireguard_path):
            self.log_label.configure(text="Error: WireGuard for Windows is not installed.")
            return
            
        if not os.path.exists(self.conf_path):
            self.log_label.configure(text="Error: windows_wg0.conf missing in app folder.")
            return

        self.toggle_btn.configure(state="disabled")
        
        def run():
            try:
                if self.is_connected:
                    self.log_label.configure(text="Disconnecting...")
                    subprocess.run([self.wireguard_path, "/uninstalltunnelservice", self.tunnel_name], creationflags=subprocess.CREATE_NO_WINDOW)
                else:
                    self.log_label.configure(text="Connecting...")
                    subprocess.run([self.wireguard_path, "/installtunnelservice", self.conf_path], creationflags=subprocess.CREATE_NO_WINDOW)
            except Exception as e:
                self.log_label.configure(text=f"Error: {e}")
                
            time.sleep(1.5)
            self.update_ui()
            self.log_label.configure(text="")
            self.toggle_btn.configure(state="normal")
            
        threading.Thread(target=run, daemon=True).start()

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

if __name__ == "__main__":
    if not is_admin():
        # Re-run the program with admin rights
        ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, " ".join(sys.argv), None, 1)
        sys.exit()
        
    app = VPNApp()
    app.mainloop()
