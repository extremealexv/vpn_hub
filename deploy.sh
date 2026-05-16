#!/bin/bash
# deploy.sh

if [ ! -f .sbc.conf ]; then
    echo "Error: .sbc.conf not found in the current directory."
    exit 1
fi

# Source the configuration file securely
while IFS='=' read -r key value; do
    [[ $key =~ ^#.*$ ]] && continue
    [[ -z $key ]] && continue
    value=$(echo "$value" | tr -d '\r')
    export "$key=$value"
done < .sbc.conf

# removed sshpass dependency

TARGET=$1
if [ -z "$TARGET" ]; then
    echo "Usage: ./deploy.sh [server|hub|all]"
    exit 1
fi

deploy_server() {
    echo "Deploying to VPN Server ($vpn_server_ip)..."
    python3 run_ssh.py "$password" ssh -o StrictHostKeyChecking=no "$user@$vpn_server_ip" "echo '$password' | sudo -S mkdir -p /etc/vpn_hub/shared /etc/vpn_hub/server"
    python3 run_ssh.py "$password" scp -o StrictHostKeyChecking=no .sbc.conf "$user@$vpn_server_ip":~/.sbc.conf
    python3 run_ssh.py "$password" ssh -o StrictHostKeyChecking=no "$user@$vpn_server_ip" "echo '$password' | sudo -S mv ~/.sbc.conf /etc/vpn_hub/"
    
    python3 run_ssh.py "$password" ssh -o StrictHostKeyChecking=no "$user@$vpn_server_ip" "mkdir -p ~/shared ~/server"
    python3 run_ssh.py "$password" scp -o StrictHostKeyChecking=no -r shared/* "$user@$vpn_server_ip":~/shared/
    python3 run_ssh.py "$password" scp -o StrictHostKeyChecking=no -r server/* "$user@$vpn_server_ip":~/server/
    python3 run_ssh.py "$password" ssh -o StrictHostKeyChecking=no "$user@$vpn_server_ip" "echo '$password' | sudo -S bash -c 'cp -r /home/$user/shared/* /etc/vpn_hub/shared/ && cp -r /home/$user/server/* /etc/vpn_hub/server/ && chmod +x /etc/vpn_hub/server/*.sh /etc/vpn_hub/shared/*.sh && /etc/vpn_hub/server/setup_server.sh'"
    
    echo "Fetching client_wg0.conf from server..."
    mkdir -p hub
    python3 run_ssh.py "$password" scp -o StrictHostKeyChecking=no "$user@$vpn_server_ip":~/client_wg0.conf hub/client_wg0.conf
}

deploy_hub() {
    echo "Deploying to VPN Hub ($vpn_hub_ip)..."
    python3 run_ssh.py "$password" ssh -o StrictHostKeyChecking=no "$user@$vpn_hub_ip" "echo '$password' | sudo -S mkdir -p /etc/vpn_hub/shared /etc/vpn_hub/hub"
    python3 run_ssh.py "$password" scp -o StrictHostKeyChecking=no .sbc.conf "$user@$vpn_hub_ip":~/.sbc.conf
    python3 run_ssh.py "$password" ssh -o StrictHostKeyChecking=no "$user@$vpn_hub_ip" "echo '$password' | sudo -S mv ~/.sbc.conf /etc/vpn_hub/"
    
    python3 run_ssh.py "$password" ssh -o StrictHostKeyChecking=no "$user@$vpn_hub_ip" "mkdir -p ~/shared ~/hub"
    python3 run_ssh.py "$password" scp -o StrictHostKeyChecking=no -r shared/* "$user@$vpn_hub_ip":~/shared/
    python3 run_ssh.py "$password" scp -o StrictHostKeyChecking=no -r hub/* "$user@$vpn_hub_ip":~/hub/
    python3 run_ssh.py "$password" ssh -o StrictHostKeyChecking=no "$user@$vpn_hub_ip" "echo '$password' | sudo -S bash -c 'cp -r /home/$user/shared/* /etc/vpn_hub/shared/ && cp -r /home/$user/hub/* /etc/vpn_hub/hub/ && chmod +x /etc/vpn_hub/hub/*.sh /etc/vpn_hub/shared/*.sh && /etc/vpn_hub/hub/setup_hub.sh'"
}

if [ "$TARGET" == "server" ]; then
    deploy_server
elif [ "$TARGET" == "hub" ]; then
    deploy_hub
elif [ "$TARGET" == "all" ]; then
    deploy_server
    deploy_hub
else
    echo "Invalid target: $TARGET"
fi
