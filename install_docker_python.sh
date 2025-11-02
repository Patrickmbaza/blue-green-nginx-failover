#!/bin/bash

# install_docker_python.sh
# Comprehensive installation script for Docker, Docker Compose, and Python on Linux
# Supports: Ubuntu, Debian, CentOS, RHEL, Amazon Linux

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect OS and version
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        OS_VERSION=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        OS_VERSION=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        OS_VERSION=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS=Debian
        OS_VERSION=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | cut -d ' ' -f1)
        OS_VERSION=$(cat /etc/redhat-release | cut -d ' ' -f3)
    else
        OS=$(uname -s)
        OS_VERSION=$(uname -r)
    fi

    # Convert to lowercase for case matching
    OS_LOWER=$(echo "$OS" | tr '[:upper:]' '[:lower:]')
    
    print_info "Detected OS: $OS $OS_VERSION"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root or with sudo"
        exit 1
    fi
}

# Update system packages
update_system() {
    print_info "Updating system packages..."
    
    case $OS_LOWER in
        ubuntu|debian)
            apt-get update
            apt-get upgrade -y
            ;;
        centos|rhel|fedora|amazon*)
            if command -v dnf >/dev/null 2>&1; then
                dnf update -y
            else
                yum update -y
            fi
            ;;
        *)
            print_warning "Unsupported OS for automatic updates"
            ;;
    esac
    
    print_success "System updated successfully"
}

# Install dependencies
install_dependencies() {
    print_info "Installing dependencies..."
    
    case $OS_LOWER in
        ubuntu|debian)
            apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release \
                software-properties-common \
                git \
                wget
            ;;
        centos|rhel|fedora)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y \
                    yum-utils \
                    device-mapper-persistent-data \
                    lvm2 \
                    curl \
                    git \
                    wget
            else
                yum install -y \
                    yum-utils \
                    device-mapper-persistent-data \
                    lvm2 \
                    curl \
                    git \
                    wget
            fi
            ;;
        amazon*)
            yum install -y \
                docker \
                curl \
                git \
                wget
            ;;
        *)
            print_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    print_success "Dependencies installed successfully"
}

# Install Docker
install_docker() {
    print_info "Installing Docker..."
    
    # Check if Docker is already installed
    if command -v docker >/dev/null 2>&1; then
        print_warning "Docker is already installed"
        DOCKER_VERSION=$(docker --version)
        print_info "Docker version: $DOCKER_VERSION"
        return 0
    fi
    
    case $OS_LOWER in
        ubuntu|debian)
            # Add Docker's official GPG key
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # Set up the stable repository
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io
            ;;
        centos|rhel)
            # Add Docker repository
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y docker-ce docker-ce-cli containerd.io
            else
                yum install -y docker-ce docker-ce-cli containerd.io
            fi
            ;;
        fedora)
            dnf install -y docker-ce docker-ce-cli containerd.io
            ;;
        amazon*)
            # Amazon Linux has Docker in default repos
            yum install -y docker
            ;;
        *)
            print_error "Unsupported OS for Docker installation: $OS"
            exit 1
            ;;
    esac
    
    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group (if not root)
    if [ "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
        print_info "Added user $SUDO_USER to docker group"
        print_warning "User needs to logout and login again for group changes to take effect"
    fi
    
    # Verify Docker installation
    if docker --version >/dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version)
        print_success "Docker installed successfully: $DOCKER_VERSION"
    else
        print_error "Docker installation failed"
        exit 1
    fi
}

# Install Docker Compose
install_docker_compose() {
    print_info "Installing Docker Compose..."
    
    # Check if Docker Compose is already installed
    if command -v docker-compose >/dev/null 2>&1; then
        print_warning "Docker Compose is already installed"
        DOCKER_COMPOSE_VERSION=$(docker-compose --version)
        print_info "Docker Compose version: $DOCKER_COMPOSE_VERSION"
        return 0
    fi
    
    # Get latest Docker Compose version
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$COMPOSE_VERSION" ]; then
        COMPOSE_VERSION="2.24.1"  # Fallback version
        print_warning "Could not fetch latest version, using $COMPOSE_VERSION"
    fi
    
    # Download and install Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # Make binary executable
    chmod +x /usr/local/bin/docker-compose
    
    # Create symbolic link for legacy compatibility
    if [ ! -f /usr/bin/docker-compose ]; then
        ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
    
    # Verify installation
    if docker-compose --version >/dev/null 2>&1; then
        DOCKER_COMPOSE_VERSION=$(docker-compose --version)
        print_success "Docker Compose installed successfully: $DOCKER_COMPOSE_VERSION"
    else
        print_error "Docker Compose installation failed"
        exit 1
    fi
}

# Install Python and pip
install_python() {
    print_info "Installing Python and pip..."
    
    # Check if Python is already installed
    if command -v python3 >/dev/null 2>&1; then
        print_warning "Python3 is already installed"
        PYTHON_VERSION=$(python3 --version)
        print_info "Python version: $PYTHON_VERSION"
    else
        case $OS_LOWER in
            ubuntu|debian)
                apt-get install -y python3 python3-pip python3-venv
                ;;
            centos|rhel|fedora|amazon*)
                if command -v dnf >/dev/null 2>&1; then
                    dnf install -y python3 python3-pip
                else
                    yum install -y python3 python3-pip
                fi
                ;;
            *)
                print_error "Unsupported OS for Python installation: $OS"
                exit 1
                ;;
        esac
        
        if command -v python3 >/dev/null 2>&1; then
            PYTHON_VERSION=$(python3 --version)
            print_success "Python installed successfully: $PYTHON_VERSION"
        else
            print_error "Python installation failed"
            exit 1
        fi
    fi
    
    # Install/upgrade pip
    if command -v pip3 >/dev/null 2>&1; then
        python3 -m pip install --upgrade pip
        print_success "pip upgraded to latest version"
    fi
}

# Configure Docker to start on boot
configure_docker() {
    print_info "Configuring Docker..."
    
    # Enable Docker to start on boot
    systemctl enable docker
    
    # Configure Docker daemon (optional)
    if [ ! -d /etc/docker ]; then
        mkdir -p /etc/docker
    fi
    
    # Create basic daemon.json if it doesn't exist
    if [ ! -f /etc/docker/daemon.json ]; then
        cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
        print_success "Docker daemon configuration created"
    fi
    
    # Restart Docker to apply changes
    systemctl restart docker
    print_success "Docker configured successfully"
}

# Test installations
test_installations() {
    print_info "Testing installations..."
    
    echo "----------------------------------------"
    
    # Test Docker
    if docker --version >/dev/null 2>&1; then
        print_success "✓ Docker: $(docker --version)"
    else
        print_error "✗ Docker test failed"
    fi
    
    # Test Docker Compose
    if docker-compose --version >/dev/null 2>&1; then
        print_success "✓ Docker Compose: $(docker-compose --version)"
    else
        print_error "✗ Docker Compose test failed"
    fi
    
    # Test Python
    if python3 --version >/dev/null 2>&1; then
        print_success "✓ Python: $(python3 --version)"
    else
        print_error "✗ Python test failed"
    fi
    
    # Test pip
    if pip3 --version >/dev/null 2>&1; then
        print_success "✓ pip: $(pip3 --version | cut -d ' ' -f1-2)"
    else
        print_error "✗ pip test failed"
    fi
    
    echo "----------------------------------------"
}

# Run a simple Docker test
run_docker_test() {
    print_info "Running Docker test (hello-world)..."
    
    if docker run --rm hello-world >/dev/null 2>&1; then
        print_success "✓ Docker test container ran successfully"
    else
        print_warning "⚠ Docker test container failed (may be due to network issues)"
    fi
}

# Display post-installation instructions
show_post_install() {
    echo ""
    print_success "🎉 Installation completed successfully!"
    echo ""
    print_info "Post-installation steps:"
    echo "1. If you added a user to docker group, logout and login again:"
    echo "   $ logout"
    echo "   Then login again"
    echo ""
    echo "2. Verify Docker without sudo:"
    echo "   $ docker --version"
    echo ""
    echo "3. Test Docker Compose:"
    echo "   $ docker-compose --version"
    echo ""
    echo "4. Test Python:"
    echo "   $ python3 --version"
    echo "   $ pip3 --version"
    echo ""
    print_info "Useful commands:"
    echo "  - Start Docker: sudo systemctl start docker"
    echo "  - Stop Docker: sudo systemctl stop docker"
    echo "  - Docker status: sudo systemctl status docker"
    echo "  - View Docker logs: sudo journalctl -u docker"
    echo ""
    print_warning "If you encounter permission issues, make sure to:"
    echo "  1. Logout and login again after being added to docker group"
    echo "  2. Or run Docker commands with sudo"
}

# Main installation function
main() {
    echo "================================================"
    print_info "Docker, Docker Compose & Python Installation Script"
    print_info "Starting installation at: $(date)"
    echo "================================================"
    echo ""
    
    # Check if running as root
    check_root
    
    # Detect OS
    detect_os
    
    # Update system
    update_system
    
    # Install dependencies
    install_dependencies
    
    # Install Docker
    install_docker
    
    # Install Docker Compose
    install_docker_compose
    
    # Install Python
    install_python
    
    # Configure Docker
    configure_docker
    
    # Test installations
    test_installations
    
    # Run Docker test
    run_docker_test
    
    # Show post-installation instructions
    show_post_install
    
    echo ""
    print_success "Installation completed at: $(date)"
    echo "================================================"
}

# Handle script interruption
cleanup() {
    print_error "Installation interrupted"
    exit 1
}

trap cleanup INT TERM

# Run main function
main "$@"