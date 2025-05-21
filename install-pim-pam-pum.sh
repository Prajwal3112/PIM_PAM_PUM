#!/bin/bash

# CYBERSENTINEL Master Installer Script
# Complete Security Management Suite

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
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ██████╗██╗   ██╗██████╗ ███████╗██████╗ ███████╗███████╗███╗   ██╗████████╗██╗███╗   ██╗███████╗██╗     "
    echo " ██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗██╔════╝██╔════╝████╗  ██║╚══██╔══╝██║████╗  ██║██╔════╝██║     "
    echo " ██║      ╚████╔╝ ██████╔╝█████╗  ██████╔╝███████╗█████╗  ██╔██╗ ██║   ██║   ██║██╔██╗ ██║█████╗  ██║     "
    echo " ██║       ╚██╔╝  ██╔══██╗██╔══╝  ██╔══██╗╚════██║██╔══╝  ██║╚██╗██║   ██║   ██║██║╚██╗██║██╔══╝  ██║     "
    echo " ╚██████╗   ██║   ██████╔╝███████╗██║  ██║███████║███████╗██║ ╚████║   ██║   ██║██║ ╚████║███████╗███████╗"
    echo "  ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝"
    echo ""
    echo -e "${NC}${GREEN}                           Complete Security Management Suite${NC}"
    echo -e "${YELLOW}                                   Master Installation${NC}"
    echo ""
    echo -e "${CYAN}===========================================================================${NC}"
    echo ""
}

# Function to log progress
log() {
    echo -e "${BLUE}[CYBERSENTINEL]${NC} $1"
}

# Function to log success
success() {
    echo -e "${GREEN}[CYBERSENTINEL]${NC} $1"
}

# Function to log warning
warning() {
    echo -e "${YELLOW}[CYBERSENTINEL]${NC} $1"
}

# Function to log error
error() {
    echo -e "${RED}[CYBERSENTINEL]${NC} $1"
    exit 1
}

# Function to detect IP address
get_ip_address() {
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

# Install Docker and Docker Compose
install_docker() {
    log "Initializing Core Components..."
    
    if command_exists docker && command_exists docker-compose; then
        success "Core Components are already installed!"
        return
    fi
    
    log "Updating system packages..."
    apt update || error "Failed to update package lists."
    
    log "Installing prerequisites..."
    apt install -y apt-transport-https ca-certificates curl software-properties-common git || error "Failed to install prerequisites."
    
    log "Adding security keys..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - || error "Failed to add security keys."
    
    log "Configuring repositories..."
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" || error "Failed to add repository."
    
    log "Installing containerization platform..."
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io || error "Failed to install containerization platform."
    
    log "Installing orchestration tools..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || error "Failed to download orchestration tools."
    chmod +x /usr/local/bin/docker-compose || error "Failed to set permissions for orchestration tools."
    
    success "Core Components installed successfully!"
}

# Setup Identity Management System (Keycloak)
setup_identity_management() {
    log "Setting up Identity Management System..."
    
    mkdir -p /opt/cybersentinel || error "Failed to create project directory."
    cd /opt/cybersentinel || error "Failed to change to project directory."
    
    cat > docker-compose-identity.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15
    container_name: cybersentinel-identity-db
    environment:
      POSTGRES_DB: identity
      POSTGRES_USER: identity_user
      POSTGRES_PASSWORD: identity_secure_pass
    volumes:
      - identity-db-data:/var/lib/postgresql/data
    networks:
      - cybersentinel-network
    restart: unless-stopped

  identity-manager:
    image: quay.io/keycloak/keycloak:latest
    container_name: cybersentinel-identity
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/identity
      KC_DB_USERNAME: identity_user
      KC_DB_PASSWORD: identity_secure_pass
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin_password
    command: start-dev
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    networks:
      - cybersentinel-network
    restart: unless-stopped

networks:
  cybersentinel-network:
    driver: bridge

volumes:
  identity-db-data:
EOF
    
    success "Identity Management configuration created!"
}

# Start Identity Management System
start_identity_management() {
    log "Starting Identity Management System..."
    cd /opt/cybersentinel || error "Project directory not found."
    
    docker-compose -f docker-compose-identity.yml up -d || error "Failed to start Identity Management System."
    
    log "Waiting for Identity Management System to initialize..."
    for i in {1..60}; do
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            break
        fi
        if [ $i -eq 60 ]; then
            error "Identity Management System failed to start properly."
        fi
        sleep 5
        echo -n "."
    done
    echo ""
    
    success "Identity Management System is running!"
}

# Show Identity Management configuration steps
show_identity_config_steps() {
    echo -e "\n${CYAN}===========================================================================${NC}"
    echo -e "${CYAN}                    Identity Management Configuration${NC}"
    echo -e "${CYAN}===========================================================================${NC}\n"
    
    echo -e "Please complete the following steps:\n"
    echo -e "1. Access Identity Management Console at: ${GREEN}http://$IP_ADDRESS:8080/admin/master/console/${NC}"
    echo -e "   Login with: ${GREEN}admin / admin_password${NC}"
    echo -e "\n2. Create a new client for Secret Manager:"
    echo -e "   a. Go to 'Clients' → 'Create client'"
    echo -e "   b. Set the following:"
    echo -e "      - Client ID: ${GREEN}vault${NC}"
    echo -e "      - Client type: ${GREEN}OpenID Connect${NC}"
    echo -e "   c. Click Next"
    echo -e "\n3. Configure client settings:"
    echo -e "   a. Enable 'Client authentication'"
    echo -e "   b. Enable 'Authorization'"
    echo -e "   c. Set Valid redirect URIs: ${GREEN}http://$IP_ADDRESS:8200/ui/vault/auth/oidc/oidc/callback${NC}"
    echo -e "   d. Set Valid post logout redirect URIs: ${GREEN}http://$IP_ADDRESS:8200${NC}"
    echo -e "   e. Set Web origins: ${GREEN}+${NC}"
    echo -e "   f. Click Save"
    echo -e "\n4. Go to 'Credentials' tab and copy the 'Client secret' value."
    echo -e "\n5. Create a user account:"
    echo -e "   a. Go to 'Users' → 'Create new user'"
    echo -e "   b. Set username and email"
    echo -e "   c. Click Create"
    echo -e "   d. Go to 'Credentials' tab and set a password\n"
    
    echo -e "${YELLOW}Press Enter when you have completed all steps above...${NC}"
    read -p ""
}

# Get client secret from user
get_client_secret() {
    echo -e "\n${YELLOW}Please enter the client secret from step 4 above:${NC}"
    read -p "> " client_secret
    
    if [ -z "$client_secret" ]; then
        error "Client secret cannot be empty. Please restart the installation."
    fi
    
    # Store client secret
    echo "$client_secret" > /opt/cybersentinel/.client_secret
    chmod 600 /opt/cybersentinel/.client_secret
    
    success "Client secret configured!"
}

# Setup Secret Management System (Vault)
setup_secret_management() {
    log "Setting up Secret Management System..."
    
    cd /opt/cybersentinel || error "Project directory not found."
    
    # Read the stored client secret
    client_secret=$(cat /opt/cybersentinel/.client_secret)
    
    cat > docker-compose-secrets.yml << EOF
version: '3.8'

services:
  secret-manager:
    image: hashicorp/vault:latest
    container_name: cybersentinel-secrets
    ports:
      - "8200:8200"
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=vault-token 
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
    cap_add:
      - IPC_LOCK
    volumes:
      - secret-data:/vault/data
    command: server -dev
    restart: unless-stopped
    networks:
      - cybersentinel-network

networks:
  cybersentinel-network:
    external: true

volumes:
  secret-data:
EOF
    
    success "Secret Management configuration created!"
}

# Start Secret Management System
start_secret_management() {
    log "Starting Secret Management System..."
    cd /opt/cybersentinel || error "Project directory not found."
    
    docker-compose -f docker-compose-secrets.yml up -d || error "Failed to start Secret Management System."
    
    log "Waiting for Secret Management System to initialize..."
    sleep 15
    
    success "Secret Management System is running!"
}

# Configure Secret Management with Identity Management
configure_secret_identity_integration() {
    log "Configuring Secret-Identity Integration..."
    
    client_secret=$(cat /opt/cybersentinel/.client_secret)
    
    cat > /opt/cybersentinel/vault-config.sh << EOF
#!/bin/sh
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='vault-token'

# Enable OIDC auth method
vault auth enable oidc

# Configure OIDC
vault write auth/oidc/config \\
    oidc_discovery_url="http://$IP_ADDRESS:8080/realms/master" \\
    oidc_client_id="vault" \\
    oidc_client_secret="$client_secret" \\
    default_role="admin"

# Create the admin role
vault write auth/oidc/role/admin \\
    bound_audiences="vault" \\
    allowed_redirect_uris="http://$IP_ADDRESS:8200/ui/vault/auth/oidc/oidc/callback" \\
    user_claim="sub" \\
    policies="admin-policy"

# Create admin policy
vault policy write admin-policy - << POLICY
# Full access to everything
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
POLICY

# Enable secrets engine
vault secrets enable -path=secret kv-v2

echo "Secret-Identity integration completed successfully!"
EOF
    
    chmod +x /opt/cybersentinel/vault-config.sh
    
    # Execute the configuration
    docker exec -i cybersentinel-secrets sh < /opt/cybersentinel/vault-config.sh || error "Failed to configure Secret-Identity integration."
    
    success "Secret-Identity integration configured!"
}

# Install Access Management System (JumpServer)
install_access_management() {
    log "Setting up Access Management System..."
    
    cd /opt || error "Failed to navigate to /opt directory."
    
    log "Downloading Access Management components..."
    git clone https://github.com/jumpserver/jumpserver.git > /dev/null 2>&1 || error "Failed to download Access Management components."
    
    log "Installing Access Management System (this may take several minutes)..."
    
    # Create a progress indicator
    progress_pid=0
    show_progress() {
        local spin='-\|/'
        local i=0
        while true; do
            printf "\r[%c] Installing Access Management System... " "${spin:i++%4:1}"
            sleep 0.5
        done
    }
    
    # Start progress indicator in background
    show_progress &
    progress_pid=$!
    
    # Trap to ensure we kill the progress indicator when the script exits or is interrupted
    trap "kill $progress_pid 2>/dev/null" EXIT
    
    # Run the JumpServer installation with all output redirected
    curl -sSL https://github.com/jumpserver/jumpserver/releases/download/v4.0.0/quick_start.sh | bash > /opt/cybersentinel_access_install.log 2>&1
    
    # Check if the installation was successful
    if [ $? -ne 0 ]; then
        kill $progress_pid 2>/dev/null
        printf "\r%s\n" "                                              "
        error "Failed to install Access Management System. Check logs at /opt/cybersentinel_access_install.log"
    fi
    
    # Stop the progress indicator
    kill $progress_pid 2>/dev/null
    wait $progress_pid 2>/dev/null
    printf "\r%s\n" "                                              "
    
    success "Access Management System installation completed!"
}

# Customize Access Management UI
customize_access_management_ui() {
    log "Customizing Access Management interface..."
    
    # Create temporary directory for logo downloads
    mkdir -p /tmp/cybersentinel_ui || error "Failed to create temporary directory for UI assets."
    cd /tmp/cybersentinel_ui || error "Failed to change to temporary UI directory."
    
    log "Downloading UI assets..."
    
    GITHUB_REPO="https://raw.githubusercontent.com/Prajwal3112/PIM_PAM_PUM/main"
    
    curl -s -o 125_x_18.png "${GITHUB_REPO}/125_x_18.png" || error "Failed to download UI asset 1"
    curl -s -o 30_x_40.png "${GITHUB_REPO}/30_x_40.png" || error "Failed to download UI asset 2"
    curl -s -o front_logo.png "${GITHUB_REPO}/front_logo.png" || error "Failed to download UI asset 3"
    curl -s -o favicon_logo.ico "${GITHUB_REPO}/favicon_logo.ico" || error "Failed to download UI asset 4"
    
    # Wait for Access Management containers to be ready
    log "Waiting for Access Management containers to be ready..."
    for i in {1..30}; do
        if docker ps | grep -q "jms_core"; then
            break
        fi
        log "Waiting for Access Management containers to start (${i}/30)..."
        sleep 10
    done
    
    if ! docker ps | grep -q "jms_core"; then
        warning "Access Management core container not found. UI customization will be skipped."
        return
    fi
    
    log "Applying UI customizations..."
    docker cp 125_x_18.png jms_core:/opt/jumpserver/apps/static/img/logo_text_white.png || warning "Failed to apply UI customization 1"
    docker cp 30_x_40.png jms_core:/opt/jumpserver/apps/static/img/logo.png || warning "Failed to apply UI customization 2"
    docker cp front_logo.png jms_core:/opt/jumpserver/apps/static/img/login_image.png || warning "Failed to apply UI customization 3"
    docker cp favicon_logo.ico jms_core:/opt/jumpserver/apps/static/img/facio.ico || warning "Failed to apply UI customization 4"
    
    log "Restarting Access Management services..."
    docker restart jms_core jms_lion jms_web jms_chen jms_koko jms_celery jms_redis || warning "Failed to restart some Access Management services"
    
    cd / && rm -rf /tmp/cybersentinel_ui
    
    success "Access Management UI customization completed!"
}

# Create unified docker-compose file
create_unified_compose() {
    log "Creating unified system configuration..."
    
    cd /opt/cybersentinel || error "Project directory not found."
    
    client_secret=$(cat /opt/cybersentinel/.client_secret)
    
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  postgres:
    image: postgres:15
    container_name: cybersentinel-identity-db
    environment:
      POSTGRES_DB: identity
      POSTGRES_USER: identity_user
      POSTGRES_PASSWORD: identity_secure_pass
    volumes:
      - identity-db-data:/var/lib/postgresql/data
    networks:
      - cybersentinel-network
    restart: unless-stopped

  identity-manager:
    image: quay.io/keycloak/keycloak:latest
    container_name: cybersentinel-identity
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/identity
      KC_DB_USERNAME: identity_user
      KC_DB_PASSWORD: identity_secure_pass
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin_password
    command: start-dev
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    networks:
      - cybersentinel-network
    restart: unless-stopped

  secret-manager:
    image: hashicorp/vault:latest
    container_name: cybersentinel-secrets
    ports:
      - "8200:8200"
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=vault-token 
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
    cap_add:
      - IPC_LOCK
    volumes:
      - secret-data:/vault/data
    command: server -dev
    restart: unless-stopped
    networks:
      - cybersentinel-network

networks:
  cybersentinel-network:
    driver: bridge

volumes:
  identity-db-data:
  secret-data:
EOF
    
    success "Unified system configuration created!"
}

# Show final access information
show_access_information() {
    echo -e "\n${CYAN}===========================================================================${NC}"
    echo -e "${CYAN}                        CYBERSENTINEL Installation Complete!${NC}"
    echo -e "${CYAN}===========================================================================${NC}\n"
    
    echo -e "${GREEN}Identity Management System:${NC}"
    echo -e "  - URL: ${BLUE}http://$IP_ADDRESS:8080${NC}"
    echo -e "  - Admin Console: ${BLUE}http://$IP_ADDRESS:8080/admin/master/console/${NC}"
    echo -e "  - Username: ${BLUE}admin${NC}"
    echo -e "  - Password: ${BLUE}admin_password${NC}"
    echo -e "\n${GREEN}Secret Management System:${NC}"
    echo -e "  - URL: ${BLUE}http://$IP_ADDRESS:8200${NC}"
    echo -e "  - Token: ${BLUE}vault-token${NC} (for direct token login)"
    echo -e "  - OIDC Login: Available via Identity Management System"
    echo -e "\n${GREEN}Access Management System:${NC}"
    echo -e "  - Username: ${BLUE}admin${NC}"
    echo -e "  - Password: ${BLUE}ChangeMe${NC}"
    echo -e "  - Typically available at: ${BLUE}http://$IP_ADDRESS:80${NC}"
    
    echo -e "\n${CYAN}===========================================================================${NC}"
    echo -e "${YELLOW}Security Note: Change all default passwords after installation!${NC}"
    echo -e "${CYAN}===========================================================================${NC}\n"
}

# Main installation flow
main() {
    show_banner
    
    # Check if script is run as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root. Please use 'sudo' or run as root user."
    fi
    
    # Detect the IP address
    IP_ADDRESS=$(get_ip_address)
    log "Detected IP address: $IP_ADDRESS"
    
    # Install Docker and Docker Compose
    install_docker
    
    # Setup and start Identity Management
    setup_identity_management
    start_identity_management
    
    # Show configuration steps and get client secret
    show_identity_config_steps
    get_client_secret
    
    # Setup and configure Secret Management
    setup_secret_management
    start_secret_management
    configure_secret_identity_integration
    
    # Install and customize Access Management
    install_access_management
    customize_access_management_ui
    
    # Create unified configuration
    create_unified_compose
    
    # Show access information
    show_access_information
}

# Run the main function
main
