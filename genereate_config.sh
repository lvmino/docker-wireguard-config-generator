#!/bin/bash

# Define variables
WG_CONFIG="/mnt/f/wireguard/config/wg0.conf" # Path to WireGuard config file within the Docker volume
PEER_DIR="/mnt/f/wireguard/config" # Base directory for peer configurations
SERVER_ENDPOINT="**********:51820" # Server's public IP and port
DNS_SERVER="1.1.1.1" # DNS server for the peer

# Container name
CONTAINER_NAME="wireguard" # Name of the WireGuard Docker container

# Function to retrieve the server's public key from the Docker container
get_server_public_key() {
  docker exec -it $CONTAINER_NAME wg show wg0 public-key 2>/dev/null
}

# Attempt to retrieve the server's public key
SERVER_PUBLIC_KEY=$(get_server_public_key)

# Check if the server's public key was retrieved
if [ -z "$SERVER_PUBLIC_KEY" ]; then
  echo "Error: Unable to retrieve server public key from the Docker container."
  exit 1
fi

# Prompt for peer name
echo "Enter the peer name:"
read PEER_NAME

# Create a directory for the peer if it doesn't exist
PEER_PATH="$PEER_DIR/$PEER_NAME"
mkdir -p $PEER_PATH

# Define peer IP (increment as needed)
PEER_IP="10.13.13.$((RANDOM % 254 + 2))/32" # Randomized last octet for unique peer IP

# Generate keys for the peer
PEER_PRIVATE_KEY=$(wg genkey)
PEER_PUBLIC_KEY=$(echo $PEER_PRIVATE_KEY | wg pubkey)

# Add new peer to the server configuration
echo -e "\n[Peer]" | tee -a $WG_CONFIG
echo "PublicKey = $PEER_PUBLIC_KEY" | tee -a $WG_CONFIG
echo "AllowedIPs = $PEER_IP" | tee -a $WG_CONFIG

# Restart WireGuard container to apply changes
docker restart $CONTAINER_NAME

# Create peer configuration file
PEER_CONFIG="$PEER_PATH/$PEER_NAME.conf"
echo "[Interface]" > $PEER_CONFIG
echo "PrivateKey = $PEER_PRIVATE_KEY" >> $PEER_CONFIG
echo "Address = ${PEER_IP%/32}" >> $PEER_CONFIG # Remove /32 for interface IP
echo "DNS = $DNS_SERVER" >> $PEER_CONFIG

echo "[Peer]" >> $PEER_CONFIG
echo "PublicKey = $SERVER_PUBLIC_KEY" >> $PEER_CONFIG
echo "Endpoint = $SERVER_ENDPOINT" >> $PEER_CONFIG
echo "AllowedIPs = 0.0.0.0/0, ::/0" >> $PEER_CONFIG
echo "PersistentKeepalive = 25" >> $PEER_CONFIG

# Output the peer configuration
echo "New peer configuration created: $PEER_CONFIG"
cat $PEER_CONFIG
