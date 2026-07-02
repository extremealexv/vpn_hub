@echo off
echo Building VPN Hub Windows Client...
pip install -r requirements.txt
pyinstaller --noconfirm --onedir --windowed --name "VPNHubClient" --add-data "%localappdata%\Programs\Python\Python310\Lib\site-packages\customtkinter;customtkinter/" "app.py"
echo Build complete! You can find the executable in the dist/VPNHubClient/ folder.
pause
