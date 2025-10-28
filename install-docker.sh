#!/bin/bash

# Docker and Docker Compose Installation Script
# Supports Ubuntu, Debian, CentOS, RHEL, Fedora

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_warning "This script is running as root. This is not recommended."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Detect distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect Linux distribution"
        exit 1
    fi
}

# Install Docker based on distribution
install_docker() {
    case $DISTRO in
        ubuntu|debian)
            install_docker_debian
            ;;
        centos|rhel|fedora)
            install_docker_redhat
            ;;
        *)
            print_error "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
}

# Install Docker on Debian/Ubuntu
install_docker_debian() {
    print_status "Installing Docker on $DISTRO..."
    
    # Update package index
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Set up the stable repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index again
    sudo apt-get update
    
    # Install Docker Engine
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    
    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
}

# Install Docker on CentOS/RHEL/Fedora
install_docker_redhat() {
    print_status "Installing Docker on $DISTRO..."
    
    # Install prerequisites
    if [[ $DISTRO == "centos" || $DISTRO == "rhel" ]]; then
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io
    elif [[ $DISTRO == "fedora" ]]; then
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo dnf install -y docker-ce docker-ce-cli containerd.io
    fi
    
    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
}

# Install Docker Compose
install_docker_compose() {
    print_status "Installing Docker Compose..."
    
    # Get latest Docker Compose version
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    # Download and install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # Make binary executable
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Create symbolic link for compatibility
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
}

# Configure Docker to run without sudo
configure_docker_sudo() {
    print_status "Configuring Docker to run without sudo..."
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    print_warning "You need to log out and log back in for group changes to take effect."
    print_warning "Alternatively, you can run: newgrp docker"
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    # Check Docker version
    if command -v docker &> /dev/null; then
        docker --version
    else
        print_error "Docker installation failed"
        exit 1
    fi
    
    # Check Docker Compose version
    if command -v docker-compose &> /dev/null; then
        docker-compose --version
    else
        print_error "Docker Compose installation failed"
        exit 1
    fi
    
    # Test Docker service
    if sudo systemctl is-active --quiet docker; then
        print_status "Docker service is running"
    else
        print_error "Docker service is not running"
        exit 1
    fi
}

# Main installation process
main() {
    print_status "Starting Docker and Docker Compose installation..."
    
    # Detect distribution
    detect_distro
    print_status "Detected distribution: $DISTRO"
    
    # Install Docker
    install_docker
    
    # Install Docker Compose
    install_docker_compose
    
    # Configure Docker to run without sudo
    configure_docker_sudo
    
    # Verify installation
    verify_installation
    
    print_status "Installation completed successfully!"
    print_warning "Please log out and log back in to use Docker without sudo privileges."
    echo
    print_status "Useful commands:"
    echo "  docker --version"
    echo "  docker-compose --version"
    echo "  sudo systemctl status docker"
    echo "  docker run hello-world"
}

# Run main function
main