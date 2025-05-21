#!/bin/bash

# CYBERSENTINEL - PIM, PAM and PUM Installer Script
# PIM => Vault : A tool for managing secrets and sensitive data
# PAM => CyberSentinel : An open-source PAM tool for secure access management
# PUM => Keycloak : An identity and access management tool

# Text formatting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to display CYBERSENTINEL banner
show_banner() {
    echo -e "\n${CYAN}${BOLD}"
    echo "  ██████╗██╗   ██╗██████╗ ███████╗██████╗ ███████╗███████╗███╗   ██╗████████╗██╗███╗   ██╗███████╗██╗     "
    echo " ██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗██╔════╝██╔════╝████╗  ██║╚══██╔══╝██║████╗  ██║██╔════╝██║     "
    echo " ██║      ╚████╔╝ ██████╔╝█████╗  ██████╔╝███████╗█████╗  ██╔██╗ ██║   ██║   ██║██╔██╗ ██║█████╗  ██║     "
    echo " ██║       ╚██╔╝  ██╔══██╗██╔══╝  ██╔══██╗╚════██║██╔══╝  ██║╚██╗██║   ██║   ██║██║╚██╗██║██╔══╝  ██║     "
    echo " ╚██████╗   ██║   ██████╔╝███████╗██║  ██║███████║███████╗██║ ╚████║   ██║   ██║██║ ╚████║███████╗███████╗"
    echo "  ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝"
    echo -e "${NC}\n"
    echo -e "${GREEN}${BOLD}    PIM (Vault), PAM (CyberSentinel) & PUM (Keycloak) Integrated Security Suite${NC}"
    echo -e "${GREEN}====================================================================================${NC}\n"
}

# Function to log progress
log() {
    echo -e "${BLUE}[CYBERSENTINEL INFO]${NC} $1"
}

# Function to log success
success() {
    echo -e "${GREEN}[CYBERSENTINEL SUCCESS]${NC} $1"
}

# Function to log warning
warning() {
    echo -e "${YELLOW}[CYBERSENTINEL WARNING]${NC} $1"
}

# Function to log error
error() {
    echo -e "${RED}[CYBERSENTINEL ERROR]${NC} $1"
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

# Function to wait for service availability
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=0
    
    log "Waiting for $service_name to be available at $url..."
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "$url" >/dev/null 2>&1; then
            success "$service_name is now available!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        log "Waiting for $service_name... (${attempt}/${max_attempts})"
        sleep 10
    done
    
    error "$service_name did not become available within the expected time."
}

# Welcome message
show_banner

# Detect the IP address
IP_ADDRESS=$(get_ip_address)
log "Detected IP address: $IP_ADDRESS"

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root. Please use 'sudo' or run as root user."
fi

# Install Docker and Docker Compose
install_docker() {
    log "Starting Docker installation for CYBERSENTINEL..."
    
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
    apt install -y apt-transport-https ca-certificates curl software-properties-common git || error "Failed to install prerequisites."
    
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

# Setup directory and initial docker-compose for Keycloak only
setup_keycloak_compose() {
    log "Setting up CYBERSENTINEL project directory and Keycloak configuration..."
    
    # Create project directory
    mkdir -p /opt/cybersentinel-suite || error "Failed to create project directory."
    cd /opt/cybersentinel-suite || error "Failed to change to project directory."
    
    # Create docker-compose.yml file for Keycloak only (initial phase)
    log "Creating Keycloak-only docker-compose.yml file..."
    cat > docker-compose-keycloak.yml << 'EOF'
version: '3.8'

services:
  postgres-keycloak:
    image: postgres:15
    container_name: cybersentinel-keycloak-postgres
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: cybersentinel_keycloak_password
    volumes:
      - postgres-keycloak-data:/var/lib/postgresql/data
    networks:
      - cybersentinel-network
    restart: unless-stopped

  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: cybersentinel-keycloak
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres-keycloak:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: cybersentinel_keycloak_password
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: CyberSentinel2024!
      KC_HOSTNAME_STRICT: false
      KC_HOSTNAME_STRICT_HTTPS: false
      KC_HTTP_ENABLED: true
    command: start-dev
    ports:
      - "8080:8080"
    depends_on:
      - postgres-keycloak
    networks:
      - cybersentinel-network
    restart: unless-stopped

networks:
  cybersentinel-network:
    driver: bridge

volumes:
  postgres-keycloak-data:
EOF
    
    success "Keycloak Docker Compose configuration created!"
}

# Start Keycloak service
start_keycloak() {
    log "Starting Keycloak service for CYBERSENTINEL..."
    cd /opt/cybersentinel-suite || error "Project directory not found."
    
    docker-compose -f docker-compose-keycloak.yml up -d || error "Failed to start Keycloak service."
    
    # Verify Keycloak is running
    log "Checking if Keycloak service is running..."
    docker-compose -f docker-compose-keycloak.yml ps
    
    if ! docker ps | grep -q cybersentinel-keycloak; then
        error "Keycloak container failed to start. Please check Docker logs."
    fi
    
    success "Keycloak service started successfully!"
    
    # Wait for Keycloak to be fully available
    wait_for_service "http://localhost:8080" "Keycloak"
}

# Show Keycloak configuration steps and collect client secret
configure_keycloak_and_get_secret() {
    echo -e "\n${CYAN}${BOLD}===========================================================${NC}"
    echo -e "${CYAN}${BOLD}    CYBERSENTINEL - Keycloak Configuration Required${NC}"
    echo -e "${CYAN}${BOLD}===========================================================${NC}\n"
    
    echo -e "Step 1: Configure Keycloak for Vault Integration\n"
    echo -e "Please complete the following steps in Keycloak:\n"
    echo -e "1. Access Keycloak Admin Console at: ${GREEN}http://$IP_ADDRESS:8080/admin/master/console/${NC}"
    echo -e "   Login with: ${GREEN}admin / CyberSentinel2024!${NC}"
    echo -e "\n2. Create a new client for Vault:"
    echo -e "   a. Go to 'Clients' in the left sidebar and click 'Create client'"
    echo -e "   b. Set the following:"
    echo -e "      - Client type: ${GREEN}OpenID Connect${NC}"
    echo -e "      - Client ID: ${GREEN}vault${NC}"
    echo -e "   c. Click Next"
    echo -e "\n3. In Client authentication settings:"
    echo -e "   a. Enable ${GREEN}Client authentication${NC}"
    echo -e "   b. Click Next"
    echo -e "\n4. In Login settings:"
    echo -e "   a. Set Valid redirect URIs to: ${GREEN}http://$IP_ADDRESS:8200/ui/vault/auth/oidc/oidc/callback${NC}"
    echo -e "   b. Set Web origins to: ${GREEN}+${NC}"
    echo -e "   c. Click Save"
    echo -e "\n5. Go to the 'Credentials' tab and copy the 'Client secret' value."
    echo -e "\n6. Create a user for Vault access:"
    echo -e "   a. Go to 'Users' in the left sidebar and click 'Create new user'"
    echo -e "   b. Fill in username (e.g., 'vaultuser') and save"
    echo -e "   c. Go to 'Credentials' tab and set a password for this user"
    
    echo -e "\n${YELLOW}${BOLD}===========================================================${NC}"
    echo -e "${YELLOW}${BOLD}Waiting for Keycloak configuration completion...${NC}"
    echo -e "${YELLOW}${BOLD}===========================================================${NC}\n"
    
    # Wait for user confirmation
    while true; do
        echo -e "${YELLOW}Have you completed the Keycloak configuration steps above? (yes/no)${NC}"
        read -p "CYBERSENTINEL > " keycloak_done
        
        if [[ "$keycloak_done" =~ ^[Yy][Ee][Ss]$ ]]; then
            break
        elif [[ "$keycloak_done" =~ ^[Nn][Oo]$ ]]; then
            warning "Please complete the Keycloak configuration before continuing."
        else
            warning "Please enter 'yes' or 'no'."
        fi
    done
    
    # Get client secret
    while true; do
        echo -e "\n${YELLOW}Please enter the Keycloak client secret for Vault:${NC}"
        read -p "CYBERSENTINEL > " client_secret
        
        if [ -n "$client_secret" ]; then
            echo "$client_secret" > /opt/cybersentinel-suite/vault-client-secret.txt
            success "Client secret stored securely!"
            break
        else
            error "Client secret cannot be empty. Please try again."
        fi
    done
}

# Setup complete docker-compose with Vault
setup_complete_compose() {
    log "Setting up complete CYBERSENTINEL docker-compose configuration..."
    
    cd /opt/cybersentinel-suite || error "Project directory not found."
    
    # Read the stored client secret
    CLIENT_SECRET=$(cat /opt/cybersentinel-suite/vault-client-secret.txt)
    
    # Create complete docker-compose.yml file
    log "Creating complete docker-compose.yml file..."
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  postgres-keycloak:
    image: postgres:15
    container_name: cybersentinel-keycloak-postgres
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: cybersentinel_keycloak_password
    volumes:
      - postgres-keycloak-data:/var/lib/postgresql/data
    networks:
      - cybersentinel-network
    restart: unless-stopped

  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: cybersentinel-keycloak
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres-keycloak:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: cybersentinel_keycloak_password
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: CyberSentinel2024!
      KC_HOSTNAME_STRICT: false
      KC_HOSTNAME_STRICT_HTTPS: false
      KC_HTTP_ENABLED: true
    command: start-dev
    ports:
      - "8080:8080"
    depends_on:
      - postgres-keycloak
    networks:
      - cybersentinel-network
    restart: unless-stopped

  vault:
    image: hashicorp/vault:latest
    container_name: cybersentinel-vault
    ports:
      - "8200:8200"
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=cybersentinel-vault-token
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
    cap_add:
      - IPC_LOCK
    volumes:
      - vault-data:/vault/data
      - ./vault-config.sh:/vault/config/vault-config.sh
    command: server -dev
    restart: unless-stopped
    networks:
      - cybersentinel-network
    depends_on:
      - keycloak

networks:
  cybersentinel-network:
    driver: bridge

volumes:
  postgres-keycloak-data:
  vault-data:
EOF
    
    success "Complete Docker Compose configuration created!"
}

# Start Vault service
start_vault() {
    log "Starting Vault service for CYBERSENTINEL..."
    cd /opt/cybersentinel-suite || error "Project directory not found."
    
    # Stop the Keycloak-only composition and start the complete one
    docker-compose -f docker-compose-keycloak.yml down
    docker-compose up -d || error "Failed to start complete services."
    
    # Verify services are running
    log "Checking if all services are running..."
    docker-compose ps
    
    if ! docker ps | grep -q cybersentinel-vault || ! docker ps | grep -q cybersentinel-keycloak; then
        error "One or more containers failed to start. Please check Docker logs."
    fi
    
    success "All services started successfully!"
    
    # Wait for Vault to be ready
    wait_for_service "http://localhost:8200" "Vault"
}

# Configure Vault with Keycloak OIDC
configure_vault_oidc() {
    log "Configuring Vault with Keycloak OIDC integration..."
    
    # Read the stored client secret
    CLIENT_SECRET=$(cat /opt/cybersentinel-suite/vault-client-secret.txt)
    
    # Create a comprehensive Vault configuration script
    cat > /opt/cybersentinel-suite/vault-config.sh << EOF
#!/bin/sh
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='cybersentinel-vault-token'

echo "CYBERSENTINEL: Configuring Vault with Keycloak OIDC..."

# Enable secret engine
vault secrets enable -path=secret kv-v2

# Enable OIDC auth method
vault auth enable oidc

# Configure OIDC with Keycloak
vault write auth/oidc/config \\
    oidc_discovery_url="http://cybersentinel-keycloak:8080/realms/master" \\
    oidc_client_id="vault" \\
    oidc_client_secret="$CLIENT_SECRET" \\
    default_role="cybersentinel-vault-role"

# Create comprehensive admin policy for OIDC users
vault policy write cybersentinel-admin-policy - << POLICY
# Full access to all secret engines
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# System management capabilities
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Identity management
path "identity/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Auth method management
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Policy management
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Secret engine management
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
POLICY

# Create the OIDC role with admin privileges
vault write auth/oidc/role/cybersentinel-vault-role \\
    bound_audiences="vault" \\
    allowed_redirect_uris="http://$IP_ADDRESS:8200/ui/vault/auth/oidc/oidc/callback" \\
    user_claim="sub" \\
    groups_claim="groups" \\
    policies="cybersentinel-admin-policy"

# Create a sample secret for testing
vault kv put secret/cybersentinel/demo \\
    message="Welcome to CyberSentinel Vault Integration!" \\
    created_by="CYBERSENTINEL" \\
    timestamp="\$(date)"

echo "CYBERSENTINEL: Vault configuration completed successfully!"
echo "Users can now log in to Vault using Keycloak OIDC authentication."
EOF
    
    # Make the script executable
    chmod +x /opt/cybersentinel-suite/vault-config.sh
    
    # Execute Vault configuration
    log "Executing Vault configuration with stored client secret..."
    docker exec -i cybersentinel-vault sh < /opt/cybersentinel-suite/vault-config.sh || error "Failed to configure Vault."
    
    success "Vault OIDC configuration completed successfully!"
}

# Install JumpServer
install_jumpserver() {
    log "Installing CyberSentinel JumpServer (PAM Solution)..."
    
    cd /opt || error "Failed to navigate to /opt directory."
    
    log "Cloning CyberSentinel JumpServer repository..."
    git clone https://github.com/jumpserver/jumpserver.git > /dev/null 2>&1 || error "Failed to clone CyberSentinel repository."
    
    log "Running CyberSentinel JumpServer installation (this may take a while)..."
    
    # Create a progress indicator
    progress_pid=0
    show_progress() {
        local spin='-\|/'
        local i=0
        while true; do
            printf "\r[%c] CYBERSENTINEL: Installing JumpServer... " "${spin:i++%4:1}"
            sleep 0.5
        done
    }
    
    # Start progress indicator in background
    show_progress &
    progress_pid=$!
    
    # Trap to ensure we kill the progress indicator when the script exits or is interrupted
    trap "kill $progress_pid 2>/dev/null" EXIT
    
    # Run the JumpServer installation with all output redirected
    curl -sSL https://github.com/jumpserver/jumpserver/releases/download/v4.0.0/quick_start.sh | bash > /opt/cybersentinel_jumpserver_install.log 2>&1
    
    # Check if the installation was successful
    if [ $? -ne 0 ]; then
        kill $progress_pid 2>/dev/null
        printf "\r%s\n" "                                              "
        error "Failed to install CyberSentinel JumpServer. Check logs at /opt/cybersentinel_jumpserver_install.log"
    fi
    
    # Stop the progress indicator
    kill $progress_pid 2>/dev/null
    wait $progress_pid 2>/dev/null
    printf "\r%s\n" "                                              "
    
    success "CyberSentinel JumpServer installation completed! Logs at /opt/cybersentinel_jumpserver_install.log"
}

# Customize JumpServer logos for CYBERSENTINEL branding
customize_jumpserver_logos() {
    log "Customizing CyberSentinel JumpServer with CYBERSENTINEL branding..."
    
    # Create temporary directory for logo downloads
    mkdir -p /tmp/cybersentinel_logos || error "Failed to create temporary directory for logos."
    cd /tmp/cybersentinel_logos || error "Failed to change to temporary logo directory."
    
    # Download logo files from GitHub repository
    log "Downloading CYBERSENTINEL logo files..."
    
    GITHUB_REPO="https://raw.githubusercontent.com/Prajwal3112/PIM_PAM_PUM/main"
    
    # Download each logo file
    curl -s -o 125_x_18.png "${GITHUB_REPO}/125_x_18.png" || error "Failed to download 125_x_18.png"
    curl -s -o 30_x_40.png "${GITHUB_REPO}/30_x_40.png" || error "Failed to download 30_x_40.png"
    curl -s -o front_logo.png "${GITHUB_REPO}/front_logo.png" || error "Failed to download front_logo.png"
    curl -s -o favicon_logo.ico "${GITHUB_REPO}/favicon_logo.ico" || error "Failed to download favicon_logo.ico"
    
    # Wait for JumpServer containers to be ready
    log "Waiting for CyberSentinel JumpServer containers to be ready..."
    for i in {1..30}; do
        if docker ps | grep -q "jms_core"; then
            break
        fi
        log "Waiting for JumpServer containers to start (${i}/30)..."
        sleep 10
    done
    
    if ! docker ps | grep -q "jms_core"; then
        warning "JumpServer core container not found. Logo customization will be skipped."
        return
    fi
    
    # Copy logo files to JumpServer container
    log "Applying CYBERSENTINEL branding to JumpServer..."
    docker cp 125_x_18.png jms_core:/opt/jumpserver/apps/static/img/logo_text_white.png || warning "Failed to copy logo_text_white.png"
    docker cp 30_x_40.png jms_core:/opt/jumpserver/apps/static/img/logo.png || warning "Failed to copy logo.png"
    docker cp front_logo.png jms_core:/opt/jumpserver/apps/static/img/login_image.png || warning "Failed to copy login_image.png"
    docker cp favicon_logo.ico jms_core:/opt/jumpserver/apps/static/img/facio.ico || warning "Failed to copy facio.ico"
    
    # Restart JumpServer containers to apply branding changes
    log "Restarting JumpServer containers to apply CYBERSENTINEL branding..."
    docker restart jms_core jms_lion jms_web jms_chen jms_koko jms_celery jms_redis || warning "Failed to restart some JumpServer containers"
    
    # Clean up temporary files
    cd / && rm -rf /tmp/cybersentinel_logos
    
    success "CYBERSENTINEL branding applied to JumpServer successfully!"
}

# Show final access information
show_access_information() {
    echo -e "\n${CYAN}${BOLD}===========================================================${NC}"
    echo -e "${CYAN}${BOLD}    CYBERSENTINEL - Installation Complete!${NC}"
    echo -e "${CYAN}${BOLD}===========================================================${NC}\n"
    
    echo -e "${GREEN}${BOLD}Congratulations! CYBERSENTINEL Security Suite is now ready!${NC}\n"
    
    echo -e "${BLUE}${BOLD}PIM (Privileged Identity Management) - Vault:${NC}"
    echo -e "  - URL: ${GREEN}http://$IP_ADDRESS:8200${NC}"
    echo -e "  - Root Token: ${GREEN}cybersentinel-vault-token${NC} (for admin access)"
    echo -e "  - OIDC Login: Available via Keycloak integration"
    echo -e "  - Test Secret: ${GREEN}secret/cybersentinel/demo${NC}"
    
    echo -e "\n${BLUE}${BOLD}PUM (Privileged User Management) - Keycloak:${NC}"
    echo -e "  - URL: ${GREEN}http://$IP_ADDRESS:8080${NC}"
    echo -e "  - Admin Console: ${GREEN}http://$IP_ADDRESS:8080/admin/master/console/${NC}"
    echo -e "  - Username: ${GREEN}admin${NC}"
    echo -e "  - Password: ${GREEN}CyberSentinel2024!${NC}"
    
    echo -e "\n${BLUE}${BOLD}PAM (Privileged Access Management) - JumpServer:${NC}"
    echo -e "  - URL: ${GREEN}http://$IP_ADDRESS:80${NC}"
    echo -e "  - Username: ${GREEN}admin${NC}"
    echo -e "  - Password: ${GREEN}ChangeMe${NC} (Please change after first login)"
    echo -e "  - Enhanced with CYBERSENTINEL branding"
    
    echo -e "\n${YELLOW}${BOLD}Integration Features:${NC}"
    echo -e "  - Vault integrated with Keycloak for SSO authentication"
    echo -e "  - All services running in isolated Docker network"
    echo -e "  - Comprehensive admin policies configured"
    echo -e "  - CYBERSENTINEL branding applied to JumpServer"
    
    echo -e "\n${RED}${BOLD}Security Recommendations:${NC}"
    echo -e "  - Change all default passwords immediately"
    echo -e "  - Configure SSL/TLS certificates for production use"
    echo -e "  - Set up proper firewall rules"
    echo -e "  - Regular backup of configuration and data"
    echo -e "  - Monitor logs for security events"
    
    echo -e "\n${CYAN}${BOLD}===========================================================${NC}"
    echo -e "${GREEN}${BOLD}Thank you for choosing CYBERSENTINEL Security Suite!${NC}"
    echo -e "${CYAN}${BOLD}===========================================================${NC}\n"
}

# Main installation flow
main() {
    # Show banner
    show_banner
    
    log "Starting CYBERSENTINEL Security Suite installation..."
    
    # Step 1: Install Docker and Docker Compose
    install_docker
    
    # Step 2: Setup and start Keycloak first
    setup_keycloak_compose
    start_keycloak
    
    # Step 3: Configure Keycloak and get client secret
    configure_keycloak_and_get_secret
    
    # Step 4: Setup complete compose with Vault
    setup_complete_compose
    
    # Step 5: Start Vault service
    start_vault
    
    # Step 6: Configure Vault with Keycloak OIDC
    configure_vault_oidc
    
    # Step 7: Install JumpServer
    install_jumpserver
    
    # Step 8: Apply CYBERSENTINEL branding to JumpServer
    customize_jumpserver_logos
    
    # Step 9: Show final access information
    show_access_information
}

# Run the main function
main
