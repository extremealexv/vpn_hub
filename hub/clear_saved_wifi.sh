#!/bin/bash
# Clears all saved Wi-Fi networks except the Hotspot
echo "Clearing all saved Wi-Fi networks except 'Hotspot'..."
nmcli -t -f UUID,TYPE,NAME con show | grep 802-11-wireless | grep -v "Hotspot" | cut -d: -f1 | while read uuid; do
    echo "Deleting connection $uuid"
    nmcli con delete "$uuid"
done
echo "Done!"
