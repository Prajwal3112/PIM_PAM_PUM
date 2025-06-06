#!/bin/bash

# PIM, PAM and PUM Installer Script
# PIM => Vault : A tool for managing secrets and sensitive data
# PAM => CyberSentinel : An open-source PAM tool for secure access management
# PUM => Keycloak : An identity and access management tool

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

# Function to log error
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Function to detect IP address
get_ip_address() {
    # Try to get IP address using different methods
    IP=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    
    if [ -z "$IP" ]; then
        IP=$(hostname -I | awk '{print $1}')
    fi
    
    if [ -z "$IP" ]; then
        warning "Could not detect IP automatically. Using localhost."
        IP="localhost"
    fi
    
    echo "$IP"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Welcome message
echo -e "\n${GREEN}===========================================================${NC}"
echo -e "${GREEN}    PIM (Vault), PAM (CyberSentinel) & PUM (Keycloak) Installer${NC}"
echo -e "${GREEN}===========================================================${NC}\n"

# Detect the IP address
IP_ADDRESS=$(get_ip_address)
log "Detected IP address: $IP_ADDRESS"

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root. Please use 'sudo' or run as root user."
fi

# Install Docker and Docker Compose
install_docker() {
    log "Starting Docker installation..."
    
    # Check if Docker is already installed
    if command_exists docker && command_exists docker-compose; then
        success "Docker and Docker Compose are already installed!"
        return
    fi
    
    # Update package lists
    log "Updating package lists..."
    apt update || error "Failed to update package lists."
    
    # Install prerequisites
    log "Installing prerequisites..."
    apt install -y apt-transport-https ca-certificates curl software-properties-common || error "Failed to install prerequisites."
    
    # Add Docker's official GPG key
    log "Adding Docker's GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - || error "Failed to add Docker's GPG key."
    
    # Add Docker repository
    log "Adding Docker repository..."
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" || error "Failed to add Docker repository."
    
    # Install Docker
    log "Installing Docker..."
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io || error "Failed to install Docker."
    
    # Install Docker Compose
    log "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || error "Failed to download Docker Compose."
    chmod +x /usr/local/bin/docker-compose || error "Failed to set permissions for Docker Compose."
    
    success "Docker and Docker Compose have been successfully installed!"
}

# Setup directory and docker-compose file
setup_docker_compose() {
    log "Setting up project directory and Docker Compose file..."
    
    # Create project directory
    mkdir -p /opt/vault-keycloak || error "Failed to create project directory."
    cd /opt/vault-keycloak || error "Failed to change to project directory."
    
    # Create docker-compose.yml file
    log "Creating docker-compose.yml file..."
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  vault:
    image: hashicorp/vault:latest
    container_name: vault
    ports:
      - "8200:8200"
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=vault-token 
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
    cap_add:
      - IPC_LOCK
    volumes:
      - vault-data:/vault/data
    command: server -dev
    restart: unless-stopped
    networks:
      - vault-keycloak-network

  postgres:
    image: postgres:15
    container_name: keycloak-postgres
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: keycloak_password
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - vault-keycloak-network
    restart: unless-stopped

  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: keycloak
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: keycloak_password
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin_password
    command: start-dev
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    networks:
      - vault-keycloak-network
    restart: unless-stopped

networks:
  vault-keycloak-network:
    driver: bridge

volumes:
  vault-data:
  postgres-data:
EOF
    
    success "Docker Compose file created successfully!"
}

# Start the services
start_services() {
    log "Starting services with Docker Compose..."
    cd /opt/vault-keycloak || error "Project directory not found."
    
    docker-compose up -d || error "Failed to start services."
    
    # Verify services are running
    log "Checking if services are running..."
    docker-compose ps
    
    # Check if vault and keycloak containers are running
    if ! docker ps | grep -q vault || ! docker ps | grep -q keycloak; then
        error "One or more containers failed to start. Please check Docker logs."
    fi
    
    success "Services started successfully!"
}

# Install JumpServer
install_jumpserver() {
    log "Installing CyberSentinel..."
    
    cd /opt || error "Failed to navigate to /opt directory."
    
    log "Cloning CyberSentinel repository..."
    git clone https://github.com/jumpserver/jumpserver.git > /dev/null 2>&1 || error "Failed to clone CyberSentinel repository."
    
    log "Running CyberSentinel quick start script (this may take a while)..."
    
    # Create a progress indicator
    progress_pid=0
    show_progress() {
        local spin='-\|/'
        local i=0
        while true; do
            printf "\r[%c] Installing CyberSentinel... " "${spin:i++%4:1}"
            sleep 0.5
        done
    }
    
    # Start progress indicator in background
    show_progress &
    progress_pid=$!
    
    # Trap to ensure we kill the progress indicator when the script exits or is interrupted
    trap "kill $progress_pid 2>/dev/null" EXIT
    
    # Run the JumpServer installation with all output redirected
    curl -sSL https://github.com/jumpserver/jumpserver/releases/download/v4.0.0/quick_start.sh | bash > /opt/CyberSentinel_install.log 2>&1
    
    # Check if the installation was successful
    if [ $? -ne 0 ]; then
        kill $progress_pid 2>/dev/null
        printf "\r%s\n" "                                              "
        error "Failed to run CyberSentinel quick start script. Check logs at /opt/CyberSentinel_install.log"
    fi
    
    # Stop the progress indicator
    kill $progress_pid 2>/dev/null
    wait $progress_pid 2>/dev/null
    printf "\r%s\n" "                                              "
    
    success "CyberSentinel installation completed! Detailed logs available at /opt/CyberSentinel_install.log"
}

# Configure Vault
configure_vault() {
    log "Configuring Vault with OIDC auth..."
    
    # Wait for Vault to be ready
    log "Waiting for Vault to be ready..."
    sleep 10
    
    # Create a Vault configuration script
    cat > /opt/vault-keycloak/vault-config.sh << EOF
#!/bin/sh
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='vault-token'

# Enable OIDC auth method
vault auth enable oidc

# Configure OIDC
vault write auth/oidc/config \\
    oidc_discovery_url="http://keycloak:8080/realms/master" \\
    oidc_client_id="vault" \\
    oidc_client_secret="$1" \\
    default_role="default"

# Create the default role
vault write auth/oidc/role/default \\
    bound_audiences="vault" \\
    allowed_redirect_uris="http://$IP_ADDRESS:8200/ui/vault/auth/oidc/oidc/callback" \\
    user_claim="sub" \\
    policies="default,oidc-identity-policy"

# Create a policy for OIDC users
vault policy write oidc-user - << POLICY
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
POLICY

# Create identity policy
vault policy write oidc-identity-policy - << POLICY
# Allow viewing auth methods
path "sys/auth" {
  capabilities = ["read", "list"]
}

# Allow viewing auth method configurations
path "sys/auth/*" {
  capabilities = ["read", "list"]
}

# Allow viewing policies
path "sys/policies/acl" {
  capabilities = ["read", "list"]
}

path "sys/policies/acl/*" {
  capabilities = ["read"]
}

# Access to identity management
path "identity/*" {
  capabilities = ["read", "list"]
}

# Additional UI paths
path "sys/mounts" {
  capabilities = ["read", "list"]
}

# Allow listing and reading all identities
path "identity/entity/id" {
  capabilities = ["read", "list"]
}

path "identity/entity/id/*" {
  capabilities = ["read"]
}

# Include all capabilities from the default policy
# Token self-management
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

# Access to UI-specific APIs
path "sys/internal/ui/*" {
  capabilities = ["read"]
}
# Allow managing secret engines
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/mounts" {
  capabilities = ["read", "create", "delete", "update", "list"]
}

# Allow managing all secrets
path "+/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow managing auth methods
path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "sudo"]
}

# Allow viewing and managing policies
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# System management
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Identity management
path "identity/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
POLICY

echo "Vault configuration completed successfully!"
EOF
    
    # Make the script executable
    chmod +x /opt/vault-keycloak/vault-config.sh
    
    # Note: We'll execute this script after getting the client secret from Keycloak
    log "Vault configuration script created. It will be executed after Keycloak configuration."
}

# Show Keycloak configuration steps
show_keycloak_config_steps() {
    echo -e "\n${YELLOW}===========================================================${NC}"
    echo -e "${YELLOW}    Keycloak Configuration for Vault Integration${NC}"
    echo -e "${YELLOW}===========================================================${NC}\n"
    
    echo -e "Please complete the following steps to configure Keycloak:\n"
    echo -e "1. Access Keycloak Admin Console at: ${GREEN}http://$IP_ADDRESS:8080/admin/master/console/${NC}"
    echo -e "   Login with: ${GREEN}admin / admin_password${NC}"
    echo -e "\n2. Create a new client in Keycloak for Vault:"
    echo -e "   a. Go to 'Clients' in the left sidebar and click 'Create'"
    echo -e "   b. Set the following:"
    echo -e "      - Client ID: ${GREEN}vault${NC}"
    echo -e "      - Client Protocol: ${GREEN}openid-connect${NC}"
    echo -e "      - Root URL: ${GREEN}http://$IP_ADDRESS:8200${NC}"
    echo -e "   c. Click Save"
    echo -e "\n3. In the client settings:"
    echo -e "   a. Set Access Type to ${GREEN}confidential${NC}"
    echo -e "   b. Set Valid Redirect URIs to ${GREEN}http://$IP_ADDRESS:8200/ui/vault/auth/oidc/oidc/callback${NC}"
    echo -e "   c. Set Web Origins to ${GREEN}+${NC}"
    echo -e "   d. Click Save"
    echo -e "\n4. Go to the 'Credentials' tab and copy the 'Secret' value."
    echo -e "   You will need this value in the next step.\n"
}

# Customize JumpServer logos
customize_jumpserver_logos() {
    log "Customizing CyberSentinel logos..."
    
    # Create temporary directory for logo downloads
    mkdir -p /tmp/cybersentinel_logos || error "Failed to create temporary directory for logos."
    cd /tmp/cybersentinel_logos || error "Failed to change to temporary logo directory."
    
    # Download logo files from GitHub repository
    log "Downloading logo files from GitHub repository..."
    
    # Replace YOUR_USERNAME with your actual GitHub username
    GITHUB_REPO="https://raw.githubusercontent.com/Prajwal3112/PIM_PAM_PUM/main"
    
    # Download each logo file
    curl -s -o 125_x_18.png "${GITHUB_REPO}/125_x_18.png" || error "Failed to download 125_x_18.png"
    curl -s -o 30_x_40.png "${GITHUB_REPO}/30_x_40.png" || error "Failed to download 30_x_40.png"
    curl -s -o front_logo.png "${GITHUB_REPO}/front_logo.png" || error "Failed to download front_logo.png"
    curl -s -o favicon_logo.ico "${GITHUB_REPO}/favicon_logo.ico" || error "Failed to download favicon_logo.ico"
    
    # Wait for JumpServer containers to be ready
    log "Waiting for CyberSentinel containers to be ready..."
    for i in {1..30}; do
        if docker ps | grep -q "jms_core"; then
            break
        fi
        log "Waiting for CyberSentinel containers to start (${i}/30)..."
        sleep 10
    done
    
    if ! docker ps | grep -q "jms_core"; then
        warning "CyberSentinel core container not found. Logo customization will be skipped."
        return
    fi
    
    # Copy logo files to JumpServer container
    log "Copying logo files to CyberSentinel container..."
    docker cp 125_x_18.png jms_core:/opt/jumpserver/apps/static/img/logo_text_white.png || warning "Failed to copy logo_text_white.png"
    docker cp 30_x_40.png jms_core:/opt/jumpserver/apps/static/img/logo.png || warning "Failed to copy logo.png"
    docker cp front_logo.png jms_core:/opt/jumpserver/apps/static/img/login_image.png || warning "Failed to copy login_image.png"
    docker cp favicon_logo.ico jms_core:/opt/jumpserver/apps/static/img/facio.ico || warning "Failed to copy facio.ico"
    
    # Restart JumpServer containers
    log "Restarting CyberSentinel containers to apply changes..."
    docker restart jms_core jms_lion jms_web jms_chen jms_koko jms_celery jms_redis || warning "Failed to restart some JumpServer containers"
    
    # Clean up temporary files
    cd / && rm -rf /tmp/cybersentinel_logos
    
    success "CyberSentinel logo customization completed!"
}

# Main installation flow
main() {
    # Install Docker and Docker Compose
    install_docker
    
    # Setup Docker Compose
    setup_docker_compose
    
    # Start services
    start_services
    
    # Prepare Vault configuration
    configure_vault
    
    # Install JumpServer
    install_jumpserver
    
    # Customize JumpServer logos
    customize_jumpserver_logos
    
    # Show Keycloak configuration steps
    show_keycloak_config_steps
    
    # Prompt for client secret
    echo -e "\n${YELLOW}Have you completed the Keycloak configuration steps above? (yes/no)${NC}"
    read -p "> " keycloak_done
    
    if [[ "$keycloak_done" =~ ^[Yy][Ee][Ss]$ ]]; then
        read -p "Please enter the Keycloak client secret for Vault: " client_secret
        
        if [ -z "$client_secret" ]; then
            error "Client secret cannot be empty. Please try again by running the vault configuration script manually."
        fi
        
        # Run Vault configuration with the provided client secret
        log "Configuring Vault with provided client secret..."
        docker exec -i vault sh < /opt/vault-keycloak/vault-config.sh "$client_secret" || error "Failed to configure Vault."
        
        success "Vault configuration completed!"
    else
        warning "Vault configuration skipped. You can run it later with:"
        echo -e "  - Edit ${YELLOW}/opt/vault-keycloak/vault-config.sh${NC} and replace '\$1' with your client secret"
        echo -e "  - Run: ${YELLOW}docker exec -i vault sh < /opt/vault-keycloak/vault-config.sh${NC}"
    fi
    
    # Show access information
    echo -e "\n${GREEN}===========================================================${NC}"
    echo -e "${GREEN}    Installation Complete! Access Information${NC}"
    echo -e "${GREEN}===========================================================${NC}\n"
    
    echo -e "PIM (Vault):"
    echo -e "  - URL: ${BLUE}http://$IP_ADDRESS:8200${NC}"
    echo -e "  - Token: ${BLUE}vault-token${NC} (for direct token login)"
    echo -e "\nPUM (Keycloak):"
    echo -e "  - URL: ${BLUE}http://$IP_ADDRESS:8080${NC}"
    echo -e "  - Admin Console: ${BLUE}http://$IP_ADDRESS:8080/admin/master/console/${NC}"
    echo -e "  - Username: ${BLUE}admin${NC}"
    echo -e "  - Password: ${BLUE}admin_password${NC}"
    echo -e "\nPAM (CyberSentinel):"
    echo -e "  - Username: ${BLUE}admin${NC}"
    echo -e "  - Password: ${BLUE}ChangeMe${NC}"
    echo -e "  - Check CyberSentinel documentation for access details."
    echo -e "  - Typically available at: ${BLUE}http://$IP_ADDRESS:80${NC}"
    
    echo -e "\n${GREEN}===========================================================${NC}"
    echo -e "${YELLOW}Note: For security, please change all default passwords after installation.${NC}"
    echo -e "${GREEN}===========================================================${NC}\n"
}

# Run the main function
main
