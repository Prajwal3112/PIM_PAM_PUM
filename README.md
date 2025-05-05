# PIM, PAM and PUM Installation Script

This repository contains a script to automate the installation of the following security tools:

- **PIM (Privileged Identity Management)**: HashiCorp Vault - For managing secrets and sensitive data
- **PAM (Privileged Access Management)**: JumpServer - For secure access management
- **PUM (Privileged User Management)**: Keycloak - For identity and access management

## Quick Installation

Run the following command as root or with sudo privileges:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/PIM-PAM-PUM/main/install-pim-pam-pum.sh | sudo bash
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

If you prefer to install services manually, check the detailed installation steps in the [MANUAL_INSTALL.md](MANUAL_INSTALL.md) file.

## Post-Installation

After installation:

1. Change all default passwords
2. Configure additional security measures
3. Set up users and permissions in each system

## Troubleshooting

If you encounter issues:

1. Check Docker container status: `docker ps -a`
2. View container logs: `docker logs vault` or `docker logs keycloak`
3. Ensure all ports are accessible (8200 for Vault, 8080 for Keycloak)
