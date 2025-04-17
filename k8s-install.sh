#!/bin/bash

# Single-Node Kubernetes Cluster Installation Script
# This script installs a lightweight single-node Kubernetes cluster using Minikube
# Author: Claude
# Date: 2025-04-17

set -e

echo "====================================================="
echo "Single-Node Kubernetes Cluster Installation Script"
echo "====================================================="

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or with sudo"
  exit 1
fi

# Detect OS
OS="$(. /etc/os-release && echo "$ID")"
echo "Detected OS: $OS"

# Install dependencies based on OS
echo "Installing dependencies..."
case "$OS" in
  ubuntu|debian)
    apt update
    apt install -y apt-transport-https ca-certificates curl software-properties-common
    ;;
  centos|rhel|fedora)
    yum install -y curl
    ;;
  *)
    echo "Unsupported OS: $OS"
    echo "This script supports Ubuntu, Debian, CentOS, RHEL, and Fedora"
    exit 1
    ;;
esac

# Install Docker
echo "Installing Docker..."
if ! command -v docker &> /dev/null; then
  case "$OS" in
    ubuntu|debian)
      curl -fsSL https://get.docker.com -o get-docker.sh
      sh get-docker.sh
      usermod -aG docker $SUDO_USER
      systemctl enable docker
      systemctl start docker
      ;;
    centos|rhel|fedora)
      curl -fsSL https://get.docker.com -o get-docker.sh
      sh get-docker.sh
      usermod -aG docker $SUDO_USER
      systemctl enable docker
      systemctl start docker
      ;;
  esac
else
  echo "Docker is already installed"
fi

# Install kubectl
echo "Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  mv kubectl /usr/local/bin/
  echo "kubectl installed successfully"
else
  echo "kubectl is already installed"
fi

# Install Minikube
echo "Installing Minikube..."
if ! command -v minikube &> /dev/null; then
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  chmod +x minikube-linux-amd64
  mv minikube-linux-amd64 /usr/local/bin/minikube
  echo "Minikube installed successfully"
else
  echo "Minikube is already installed"
fi

# Set up Minikube
echo "Setting up Minikube single-node cluster..."
# If script is run as root but there's a sudo user, run minikube as that user
if [ -n "$SUDO_USER" ]; then
  su - $SUDO_USER -c "minikube start --driver=docker --cpus=2 --memory=4g"
else
  minikube start --driver=docker --cpus=2 --memory=4g
fi

# Verify installation
echo "Verifying installation..."
if [ -n "$SUDO_USER" ]; then
  su - $SUDO_USER -c "kubectl get nodes"
  su - $SUDO_USER -c "kubectl cluster-info"
else
  kubectl get nodes
  kubectl cluster-info
fi

echo "====================================================="
echo "Installation completed successfully!"
echo "You now have a single-node Kubernetes cluster with kubectl configured."
echo ""
echo "To use kubectl as a regular user, run:"
echo "  mkdir -p \$HOME/.kube"
echo "  sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
echo "  sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
echo ""
echo "To confirm everything is working, run:"
echo "  kubectl get nodes"
echo "====================================================="

exit 0
