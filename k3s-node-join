#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (sudo)"
   exit 1
fi

# Function to check if we're running on Debian
check_debian() {
    if ! grep -q 'Debian' /etc/os-release; then
        echo "This script is intended for Debian only!"
        exit 1
    fi
}

check_debian

# Install prerequisites for Debian
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
    gnupg2

# Enable services required for Debian
systemctl enable iscsid
systemctl start iscsid

# Raspberry Pi specific configuration for Debian
if [ -f /boot/cmdline.txt ]; then
    if ! grep -q "cgroup_enable=cpuset" /boot/cmdline.txt; then
        sed -i '$ s/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' /boot/cmdline.txt
    fi
fi

# Configure sysctl for Debian
cat > /etc/sysctl.d/k3s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
vm.max_map_count = 262144
EOF
sysctl --system

# Load modules
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

# Configure kubectl for user
mkdir -p /home/patrick/.kube
cp /etc/rancher/k3s/k3s.yaml /home/patrick/.kube/config
chown -R patrick:patrick /home/patrick/.kube
echo "export KUBECONFIG=/home/patrick/.kube/config" >> /home/patrick/.bashrc

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
    - match: Host(\`traefik.korczewski.de\`)
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
    - match: HostRegexp(\`{subdomain:[a-zA-Z0-9-]+}.korczewski.de\`)
      kind: Rule
      services:
        - name: whoami
          namespace: kube-system
          port: 80
  tls:
    certResolver: le
EOF

# Set up aliases
cat >> /home/patrick/.bashrc << EOF

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
echo $NODE_TOKEN > /home/patrick/node-token.txt
chown patrick:patrick /home/patrick/node-token.txt

echo "Installation complete!"
echo "Node token saved to /home/patrick/node-token.txt"
echo "System will reboot in 10 seconds..."
sleep 10
reboot
