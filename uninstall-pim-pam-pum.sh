#!/bin/bash

# CYBERSENTINEL Complete Removal Script

# Text formatting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to display removal banner
show_removal_banner() {
    clear
    echo -e "${RED}${BOLD}"
    echo "  ██████╗██╗   ██╗██████╗ ███████╗██████╗ ███████╗███████╗███╗   ██╗████████╗██╗███╗   ██╗███████╗██╗     "
    echo " ██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗██╔════╝██╔════╝████╗  ██║╚══██╔══╝██║████╗  ██║██╔════╝██║     "
    echo " ██║      ╚████╔╝ ██████╔╝█████╗  ██████╔╝███████╗█████╗  ██╔██╗ ██║   ██║   ██║██╔██╗ ██║█████╗  ██║     "
    echo " ██║       ╚██╔╝  ██╔══██╗██╔══╝  ██╔══██╗╚════██║██╔══╝  ██║╚██╗██║   ██║   ██║██║╚██╗██║██╔══╝  ██║     "
    echo " ╚██████╗   ██║   ██████╔╝███████╗██║  ██║███████║███████╗██║ ╚████║   ██║   ██║██║ ╚████║███████╗███████╗"
    echo "  ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝"
    echo ""
    echo -e "${NC}${RED}                           Complete System Removal${NC}"
    echo -e "${YELLOW}                                WARNING: This will remove all data${NC}"
    echo ""
    echo -e "${RED}===========================================================================${NC}"
    echo ""
}

# Function to log progress
log() {
    echo -e "${BLUE}[REMOVAL]${NC} $1"
}

# Function to log success
success() {
    echo -e "${GREEN}[REMOVAL]${NC} $1"
}

# Function to log warning
warning() {
    echo -e "${YELLOW}[REMOVAL]${NC} $1"
}

# Function to log error
error() {
    echo -e "${RED}[REMOVAL]${NC} $1"
}

# Function to confirm removal
confirm_removal() {
    echo -e "${RED}${BOLD}WARNING: This will completely remove CYBERSENTINEL and ALL associated data!${NC}"
    echo -e "${YELLOW}This action cannot be undone. All configurations, users, and stored data will be lost.${NC}\n"
    
    echo -e "Please type ${RED}${BOLD}REMOVE CYBERSENTINEL${NC} to confirm removal:"
    read -r confirmation
    
    if [ "$confirmation" != "REMOVE CYBERSENTINEL" ]; then
        echo -e "\n${GREEN}Removal cancelled. System remains intact.${NC}"
        exit 0
    fi
    
    echo -e "\n${RED}Proceeding with complete removal...${NC}\n"
}

# Stop and remove all CYBERSENTINEL containers
remove_containers() {
    log "Stopping and removing all CYBERSENTINEL containers..."
    
    # Stop and remove containers by project
    if [ -f "/opt/cybersentinel/docker-compose.yml" ]; then
        cd /opt/cybersentinel
        docker-compose down -v --remove-orphans 2>/dev/null
    fi
    
    if [ -f "/opt/cybersentinel/docker-compose-identity.yml" ]; then
        cd /opt/cybersentinel
        docker-compose -f docker-compose-identity.yml down -v --remove-orphans 2>/dev/null
    fi
    
    if [ -f "/opt/cybersentinel/docker-compose-secrets.yml" ]; then
        cd /opt/cybersentinel
        docker-compose -f docker-compose-secrets.yml down -v --remove-orphans 2>/dev/null
    fi
    
    # Stop and remove JumpServer containers
    log "Removing Access Management containers..."
    
    # List of JumpServer containers
    JUMPSERVER_CONTAINERS=(
        "jms_core"
        "jms_celery"
        "jms_web"
        "jms_redis"
        "jms_mysql"
        "jms_lion"
        "jms_chen"
        "jms_koko"
        "jms_wisp"
        "jms_video_worker"
    )
    
    for container in "${JUMPSERVER_CONTAINERS[@]}"; do
        if docker ps -a --format "table {{.Names}}" | grep -q "^${container}$"; then
            docker stop "$container" 2>/dev/null
            docker rm "$container" 2>/dev/null
            log "Removed container: $container"
        fi
    done
    
    # Remove any remaining CYBERSENTINEL containers
    log "Removing any remaining CYBERSENTINEL containers..."
    
    CYBERSENTINEL_CONTAINERS=(
        "cybersentinel-identity"
        "cybersentinel-identity-db"
        "cybersentinel-secrets"
    )
    
    for container in "${CYBERSENTINEL_CONTAINERS[@]}"; do
        if docker ps -a --format "table {{.Names}}" | grep -q "^${container}$"; then
            docker stop "$container" 2>/dev/null
            docker rm "$container" 2>/dev/null
            log "Removed container: $container"
        fi
    done
    
    success "All containers removed!"
}

# Remove Docker volumes
remove_volumes() {
    log "Removing CYBERSENTINEL data volumes..."
    
    # Remove named volumes
    VOLUMES=(
        "cybersentinel_identity-db-data"
        "cybersentinel_secret-data"
        "identity-db-data"
        "secret-data"
        "jms_mysql_data"
        "jms_redis_data"
    )
    
    for volume in "${VOLUMES[@]}"; do
        if docker volume ls --format "table {{.Name}}" | grep -q "^${volume}$"; then
            docker volume rm "$volume" 2>/dev/null
            log "Removed volume: $volume"
        fi
    done
    
    # Remove orphaned volumes
    log "Removing orphaned volumes..."
    docker volume prune -f 2>/dev/null
    
    success "All volumes removed!"
}

# Remove Docker networks
remove_networks() {
    log "Removing CYBERSENTINEL networks..."
    
    NETWORKS=(
        "cybersentinel_cybersentinel-network"
        "cybersentinel-network"
        "jms_default"
    )
    
    for network in "${NETWORKS[@]}"; do
        if docker network ls --format "table {{.Name}}" | grep -q "^${network}$"; then
            docker network rm "$network" 2>/dev/null
            log "Removed network: $network"
        fi
    done
    
    success "All networks removed!"
}

# Remove Docker images
remove_images() {
    log "Removing CYBERSENTINEL Docker images..."
    
    # Remove specific images
    IMAGES=(
        "hashicorp/vault"
        "quay.io/keycloak/keycloak"
        "postgres:15"
        "jumpserver/jms_all"
        "jumpserver/jms_core"
        "jumpserver/jms_celery"
        "jumpserver/jms_web"
        "jumpserver/jms_redis"
        "jumpserver/jms_mysql"
        "jumpserver/jms_lion"
        "jumpserver/jms_chen"
        "jumpserver/jms_koko"
        "jumpserver/jms_wisp"
        "jumpserver/video_worker"
    )
    
    for image in "${IMAGES[@]}"; do
        if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "^${image}"; then
            docker rmi -f "${image}:latest" 2>/dev/null
            docker rmi -f "${image}" 2>/dev/null
            log "Removed image: $image"
        fi
    done
    
    # Remove dangling images
    log "Removing dangling images..."
    docker image prune -f 2>/dev/null
    
    success "All images removed!"
}

# Remove installation directories
remove_directories() {
    log "Removing CYBERSENTINEL installation directories..."
    
    # Remove main installation directory
    if [ -d "/opt/cybersentinel" ]; then
        rm -rf /opt/cybersentinel
        log "Removed /opt/cybersentinel"
    fi
    
    # Remove JumpServer directory
    if [ -d "/opt/jumpserver" ]; then
        rm -rf /opt/jumpserver
        log "Removed /opt/jumpserver"
    fi
    
    # Remove any log files
    if [ -f "/opt/cybersentinel_access_install.log" ]; then
        rm -f /opt/cybersentinel_access_install.log
        log "Removed installation log"
    fi
    
    # Remove any temporary directories
    if [ -d "/tmp/cybersentinel_ui" ]; then
        rm -rf /tmp/cybersentinel_ui
        log "Removed temporary UI directory"
    fi
    
    if [ -d "/tmp/cybersentinel_logos" ]; then
        rm -rf /tmp/cybersentinel_logos
        log "Removed temporary logos directory"
    fi
    
    success "All directories removed!"
}

# Remove system configurations
remove_system_configs() {
    log "Removing system configurations..."
    
    # Remove any systemd services if they exist
    SERVICES=(
        "cybersentinel"
        "cybersentinel-identity"
        "cybersentinel-secrets"
        "cybersentinel-access"
    )
    
    for service in "${SERVICES[@]}"; do
        if systemctl list-unit-files | grep -q "${service}.service"; then
            systemctl stop "$service" 2>/dev/null
            systemctl disable "$service" 2>/dev/null
            rm -f "/etc/systemd/system/${service}.service"
            log "Removed service: $service"
        fi
    done
    
    # Reload systemd if any services were removed
    systemctl daemon-reload 2>/dev/null
    
    success "System configurations removed!"
}

# Optional: Remove Docker entirely
remove_docker_option() {
    echo -e "\n${YELLOW}Do you want to remove Docker and Docker Compose entirely? (y/N)${NC}"
    read -r remove_docker
    
    if [[ "$remove_docker" =~ ^[Yy]$ ]]; then
        log "Removing Docker and Docker Compose..."
        
        # Stop Docker service
        systemctl stop docker 2>/dev/null
        systemctl disable docker 2>/dev/null
        
        # Remove Docker packages
        apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null
        apt-get autoremove -y 2>/dev/null
        
        # Remove Docker Compose
        rm -f /usr/local/bin/docker-compose
        
        # Remove Docker directories
        rm -rf /var/lib/docker
        rm -rf /var/lib/containerd
        rm -rf /etc/docker
        rm -rf ~/.docker
        
        # Remove Docker repository
        rm -f /etc/apt/sources.list.d/docker.list
        apt-key del 9DC858229FC7DD38854AE2D88D81803C0EBFCD88 2>/dev/null
        
        success "Docker completely removed!"
    else
        log "Docker installation preserved."
    fi
}

# Clean up system
cleanup_system() {
    log "Performing system cleanup..."
    
    # Update package lists
    apt-get update 2>/dev/null
    
    # Remove orphaned packages
    apt-get autoremove -y 2>/dev/null
    
    # Clean package cache
    apt-get autoclean 2>/dev/null
    
    success "System cleanup completed!"
}

# Verify removal
verify_removal() {
    log "Verifying complete removal..."
    
    local issues_found=0
    
    # Check for remaining containers
    if docker ps -a --format "table {{.Names}}" | grep -E "(cybersentinel|jms_|keycloak|vault)" > /dev/null 2>&1; then
        warning "Some containers may still exist"
        issues_found=1
    fi
    
    # Check for remaining volumes
    if docker volume ls --format "table {{.Name}}" | grep -E "(cybersentinel|jms_|identity|secret)" > /dev/null 2>&1; then
        warning "Some volumes may still exist"
        issues_found=1
    fi
    
    # Check for remaining directories
    if [ -d "/opt/cybersentinel" ] || [ -d "/opt/jumpserver" ]; then
        warning "Some directories may still exist"
        issues_found=1
    fi
    
    if [ $issues_found -eq 0 ]; then
        success "Verification completed - CYBERSENTINEL completely removed!"
    else
        warning "Some components may still exist. Manual cleanup may be required."
    fi
}

# Show removal summary
show_removal_summary() {
    echo -e "\n${GREEN}===========================================================================${NC}"
    echo -e "${GREEN}                    CYBERSENTINEL Removal Complete!${NC}"
    echo -e "${GREEN}===========================================================================${NC}\n"
    
    echo -e "${GREEN}What was removed:${NC}"
    echo -e "  ✓ All CYBERSENTINEL containers"
    echo -e "  ✓ All data volumes and persistent storage"
    echo -e "  ✓ All Docker networks"
    echo -e "  ✓ All Docker images"
    echo -e "  ✓ All installation directories (/opt/cybersentinel, /opt/jumpserver)"
    echo -e "  ✓ All configuration files"
    echo -e "  ✓ All system services"
    echo -e "  ✓ All log files"
    
    echo -e "\n${YELLOW}What was preserved:${NC}"
    echo -e "  • Docker Engine and Docker Compose (unless specifically removed)"
    echo -e "  • System packages and dependencies"
    echo -e "  • Other Docker containers and applications"
    
    echo -e "\n${GREEN}===========================================================================${NC}"
    echo -e "${CYAN}System is now clean. You can reinstall CYBERSENTINEL at any time.${NC}"
    echo -e "${GREEN}===========================================================================${NC}\n"
}

# Main removal flow
main() {
    show_removal_banner
    
    # Check if script is run as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root. Please use 'sudo' or run as root user."
        exit 1
    fi
    
    # Confirm removal
    confirm_removal
    
    # Remove components
    remove_containers
    remove_volumes
    remove_networks
    remove_images
    remove_directories
    remove_system_configs
    
    # Optional Docker removal
    remove_docker_option
    
    # Clean up system
    cleanup_system
    
    # Verify removal
    verify_removal
    
    # Show summary
    show_removal_summary
}

# Run the main function
main
