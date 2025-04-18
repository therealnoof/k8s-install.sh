#!/bin/bash

# Single Node Kubernetes Installation Script for Ubuntu 22.04
# This script installs containerd, kubelet, kubeadm, and kubectl 
# and sets up a single-node Kubernetes cluster

# Set Kubernetes version as variable
# You can specify versions like "1.28.0", "1.29.1", etc.
K8S_VERSION="${1:-1.32.0}"
echo "Installing Kubernetes version: $K8S_VERSION"

# Exit on any error
set -e

echo "=== System Update ==="
# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

echo "=== Installing Prerequisites ==="
# Install required packages
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

echo "=== Setting up containerd ==="
# Load necessary modules
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

# Load modules immediately
echo "Loading kernel modules: overlay and br_netfilter"
sudo modprobe overlay
sudo modprobe br_netfilter

echo "=== Configuring sysctl parameters ==="
# Set up required sysctl parameters
# These parameters are needed for Kubernetes networking to function properly
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
# Ensures bridge traffic passes through iptables for Kubernetes network policies
net.bridge.bridge-nf-call-iptables  = 1
# Enables IP forwarding for container communication
net.ipv4.ip_forward                 = 1
# Similar to first setting but for IPv6 traffic
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl parameters
echo "Applying sysctl parameters"
sudo sysctl --system

echo "=== Installing containerd ==="
# Install containerd
sudo apt-get update
sudo apt-get install -y containerd

# Create default containerd configuration
echo "Configuring containerd"
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Configure containerd to use systemd cgroup driver to align with Kubernetes
echo "Setting containerd to use systemd cgroup driver"
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Restart containerd
echo "Restarting containerd service"
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "=== Disabling swap ==="
# Disable swap - Kubernetes requires this for predictable performance
# and proper resource management
echo "Disabling swap immediately"
sudo swapoff -a
# Make swap disable permanent across reboots
echo "Commenting out swap entries in /etc/fstab"
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "=== Installing Kubernetes components (kubelet, kubeadm, kubectl) ==="
# Add Kubernetes apt repository for the specified version
echo "Adding Kubernetes repository"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package list
sudo apt-get update

# Install specific version of kubernetes components
echo "Installing kubelet, kubeadm, and kubectl version $K8S_VERSION"
sudo apt-get install -y kubelet=${K8S_VERSION}-* kubeadm=${K8S_VERSION}-* kubectl=${K8S_VERSION}-*

# Hold the installed packages at current version to prevent automatic upgrades
# This is important because Kubernetes has strict version compatibility requirements
echo "Preventing automatic upgrades of Kubernetes components"
sudo apt-mark hold kubelet kubeadm kubectl

echo "=== Initializing Kubernetes cluster ==="
# Initialize the Kubernetes cluster
# The pod CIDR is set to be compatible with Flannel network plugin
echo "Running kubeadm init"
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Set up kubeconfig for the current user
# The three commands below are used to setup kube config for a user not root, the export line 112 sets this up for the root and points directly to the admin.conf
# echo "Setting up kubeconfig for current user"
# mkdir -p $HOME/.kube
# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
# sudo chown $(id -u):$(id -g) $HOME/.kube/config
# This variable export is here when you are installing this as the root user, comment it out if you are installing as another user
export KUBECONFIG=/etc/kubernetes/admin.conf

echo "=== Installing Flannel CNI network plugin ==="
# Apply Flannel CNI network plugin for pod-to-pod communication
echo "Applying Flannel network plugin"
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo "=== Configuring single-node setup ==="
# Remove the taint on the control plane node to allow scheduling of pods
# This is necessary for single-node setups
echo "Removing taint from control-plane node"
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

echo "=== Verifying installation ==="
# Wait for node to be ready
echo "Waiting for node to be ready..."
sleep 30

# Check node status
echo "Node status:"
kubectl get nodes

# Check all pods are running
echo "Pod status across all namespaces:"
kubectl get pods --all-namespaces

echo "=== Installation complete ==="
echo "Your single-node Kubernetes cluster with version $K8S_VERSION is now ready!"
echo "You can use kubectl to interact with your cluster."
