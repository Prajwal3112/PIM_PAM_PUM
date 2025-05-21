#!/bin/bash

# Uninstallation script for PIM, PAM and PUM services
# This will remove all services and directories created by the install-pim-pam-pum.sh script

# Text formatting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to log progress
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to log success
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to log warning
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Confirm with user
echo -e "${RED}WARNING: This will completely remove all PIM, PAM and PUM services and data.${NC}"
echo -e "${RED}All configurations and stored data will be lost.${NC}"
read -p "Are you sure you want to proceed? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Stop and remove Vault and Keycloak
log "Stopping and removing Vault and Keycloak..."
if [ -d "/opt/vault-keycloak" ]; then
    cd /opt/vault-keycloak
    docker-compose down -v
    success "Vault and Keycloak containers removed."
else
    warning "Vault-Keycloak directory not found, skipping."
fi

# Stop and remove JumpServer
log "Stopping and removing CyberSentinel Privilege Management..."
if [ -d "/opt/jumpserver" ]; then
    cd /opt/jumpserver
    if [ -f "./jmsctl.sh" ]; then
        ./jmsctl.sh stop
        ./jmsctl.sh down -v
        success "CyberSentinel containers removed."
    else
        warning "CyberSentinel control script not found, skipping."
    fi
else
    warning "CyberSentinel directory not found, skipping."
fi

# Remove Docker images
log "Removing Docker images..."
docker rmi hashicorp/vault:latest quay.io/keycloak/keycloak:latest postgres:15 2>/dev/null || true
success "Docker images removed."

# Remove directories
log "Removing installation directories..."
rm -rf /opt/vault-keycloak
rm -rf /opt/jumpserver
rm -rf /opt/CyberSentinel_install.log
success "Installation and other directories removed."

# Ask if user wants to remove Docker as well
read -p "Do you want to remove Docker and Docker Compose as well? (yes/no): " remove_docker

if [[ "$remove_docker" == "yes" ]]; then
    log "Removing Docker and Docker Compose..."
    apt remove -y docker-ce docker-ce-cli containerd.io
    apt autoremove -y
    rm -rf /var/lib/docker
    rm -rf /etc/docker
    rm -f /usr/local/bin/docker-compose
    success "Docker and Docker Compose removed."
fi

echo -e "\n${GREEN}===========================================================${NC}"
echo -e "${GREEN}    Uninstallation Complete!${NC}"
echo -e "${GREEN}===========================================================${NC}\n"
echo -e "All PIM, PAM and PUM services have been removed from your system."
