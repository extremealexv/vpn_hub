@echo off
echo Building VPN Hub Windows Client...
pip install -r requirements.txt

FOR /F "tokens=*" %%g IN ('python -c "import customtkinter, os; print(os.path.dirname(customtkinter.__file__))"') do (SET CTK_PATH=%%g)

echo CustomTkinter located at: %CTK_PATH%
pyinstaller --noconfirm --onedir --windowed --name "VPNHubClient" --add-data "%CTK_PATH%;customtkinter/" "app.py"

echo Build complete! You can find the executable in the dist/VPNHubClient/ folder.
pause
