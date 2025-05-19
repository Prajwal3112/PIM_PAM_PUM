# PIM, PAM and PUM Installation Script

This repository contains a script to automate the installation of the following security tools:

- **PIM (Privileged Identity Management)**: HashiCorp Vault - For managing secrets and sensitive data
- **PAM (Privileged Access Management)**: CyberSentinel - For secure access management
- **PUM (Privileged User Management)**: Keycloak - For identity and access management

## Quick Installation

Run the following command as root or with sudo privileges:

```bash
curl -fsSL https://raw.githubusercontent.com/Prajwal3112/PIM_PAM_PUM/main/install-pim-pam-pum.sh | sudo bash
```

## What the script does

1. Installs Docker and Docker Compose
2. Creates necessary configuration files
3. Sets up and starts Vault and Keycloak with Docker Compose
4. Installs JumpServer
5. Guides you through Keycloak configuration
6. Configures Vault with OIDC authentication using Keycloak
7. Provides access URLs for all services

## System Requirements

- Ubuntu Linux (tested on 20.04 LTS and newer)
- At least 4GB RAM
- At least 20GB free disk space
- Root or sudo privileges
- Internet connection

## Manual Installation Steps

If you prefer to install services manually, check the detailed installation steps in the installation_of_all file. 'https://github.com/Prajwal3112/PIM_PAM_PUM/blob/main/installation_of_all'

## Post-Installation

After installation:

1. Change all default passwords
2. Configure additional security measures
3. Set up users and permissions in each system

# Uninstallation
To completely remove all services and directories created by this script, run the following commands as root or with sudo:
bash# Stop and remove Docker containers
cd /opt/vault-keycloak
docker-compose down -v

## Remove JumpServer containers
cd /opt/jumpserver
./jmsctl.sh stop
./jmsctl.sh down -v

## Remove Docker images related to our services
docker rmi hashicorp/vault:latest quay.io/keycloak/keycloak:latest postgres:15

## Remove directories created during installation
rm -rf /opt/vault-keycloak
rm -rf /opt/jumpserver

## Remove Docker and Docker Compose (optional)
apt remove -y docker-ce docker-ce-cli containerd.io
apt autoremove -y
rm -rf /var/lib/docker
rm -rf /etc/docker
rm -f /usr/local/bin/docker-compose

echo "Uninstallation completed. All services and directories have been removed."

Note: This will completely remove all data and configurations. Make sure to back up any important data before running these commands.

# How to Use the Uninstall Script
## Users can run the uninstallation script using:
```bash
curl -fsSL https://raw.githubusercontent.com/Prajwal3112/PIM_PAM_PUM/main/uninstall-pim-pam-pum.sh | sudo bash
```
## Or if they've already cloned your repository:
```bash
sudo bash uninstall-pim-pam-pum.sh
```

# Troubleshooting

If you encounter issues:

1. Check Docker container status: `docker ps -a`
2. View container logs: `docker logs vault` or `docker logs keycloak`
3. Ensure all ports are accessible (8200 for Vault, 8080 for Keycloak)
