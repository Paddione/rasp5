#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (sudo)"
   exit 1
fi

# Function to check if we're running on Ubuntu
check_ubuntu() {
    if ! grep -q 'Ubuntu' /etc/os-release; then
        echo "This script is intended for Ubuntu only!"
        exit 1
    fi
}

check_ubuntu

# Install prerequisites for Ubuntu
echo "Installing prerequisites..."
apt update && apt upgrade -y
apt install -y \
    curl \
    open-iscsi \
    nfs-common \
    apt-transport-https \
    ca-certificates \
    vim \
    net-tools \
    htop \
    iotop \
    git \
    jq \
    sudo \
    gnupg2 \
    apparmor \
    apparmor-utils

# Enable required services for Ubuntu
systemctl enable --now iscsid
systemctl enable --now apparmor

# Raspberry Pi specific configuration (if needed)
if [ -f /boot/firmware/cmdline.txt ]; then
    if ! grep -q "cgroup_enable=cpuset" /boot/firmware/cmdline.txt; then
        sed -i '$ s/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' /boot/firmware/cmdline.txt
    fi
fi

# Configure sysctl
cat > /etc/sysctl.d/k3s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
vm.max_map_count = 262144
EOF
sysctl --system

# Load required modules
cat > /etc/modules-load.d/k3s.conf << EOF
br_netfilter
overlay
EOF
modprobe br_netfilter
modprobe overlay

# Create Traefik config
mkdir -p /var/lib/rancher/k3s/server/manifests
cat > /var/lib/rancher/k3s/server/manifests/traefik-config.yaml << EOF
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    additionalArguments:
      - "--certificatesresolvers.le.acme.email=patrick@korczewski.de"
      - "--certificatesresolvers.le.acme.storage=/data/acme.json"
      - "--certificatesresolvers.le.acme.tlschallenge=true"
      - "--certificatesresolvers.le.acme.server=https://acme-v02.api.letsencrypt.org/directory"
    ports:
      websecure:
        tls:
          enabled: true
          certResolver: "le"
    ingressRoute:
      dashboard:
        enabled: true
        annotations:
          kubernetes.io/ingress.class: traefik
EOF

# Install K3s
export INSTALL_K3S_EXEC="server \
    --node-name $(hostname) \
    --tls-san $(hostname -I | awk '{print $1}') \
    --write-kubeconfig-mode 644"

curl -sfL https://get.k3s.io | sh -

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
sleep 30

# Get current user (assuming script is run with sudo)
CURRENT_USER=$(logname || echo $SUDO_USER)
USER_HOME=$(eval echo ~$CURRENT_USER)

# Configure kubectl for user
mkdir -p $USER_HOME/.kube
cp /etc/rancher/k3s/k3s.yaml $USER_HOME/.kube/config
chown -R $CURRENT_USER:$CURRENT_USER $USER_HOME/.kube
echo "export KUBECONFIG=$USER_HOME/.kube/config" >> $USER_HOME/.bashrc

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Create Traefik dashboard ingress
cat > /var/lib/rancher/k3s/server/manifests/traefik-dashboard-ingress.yaml << EOF
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: kube-system
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(\`traefik.example.com\`)
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
  tls:
    certResolver: le
EOF

# Create wildcard DNS ingress
cat > /var/lib/rancher/k3s/server/manifests/wildcard-ingress.yaml << EOF
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: wildcard-route
  namespace: kube-system
spec:
  entryPoints:
    - websecure
  routes:
    - match: HostRegexp(\`{subdomain:[a-zA-Z0-9-]+}.example.com\`)
      kind: Rule
      services:
        - name: whoami
          namespace: kube-system
          port: 80
  tls:
    certResolver: le
EOF

# Set up aliases
cat >> $USER_HOME/.bashrc << EOF

# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgn='kubectl get nodes'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kgpv='kubectl get pv'
alias kgpvc='kubectl get pvc'
alias kns='kubectl config set-context --current --namespace'
EOF

# Save token for later use
NODE_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
echo $NODE_TOKEN > $USER_HOME/node-token.txt
chown $CURRENT_USER:$CURRENT_USER $USER_HOME/node-token.txt

echo "Installation complete!"
echo "Node token saved to $USER_HOME/node-token.txt"
echo "IMPORTANT: Before rebooting, make sure to:"
echo "1. Replace 'your.email@example.com' with your actual email in /var/lib/rancher/k3s/server/manifests/traefik-config.yaml"
echo "2. Replace 'example.com' with your actual domain in the Traefik ingress configurations"
echo "System will reboot in 30 seconds... Press Ctrl+C to cancel"
sleep 30
reboot
