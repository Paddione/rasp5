#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root (sudo)"
  exit 1
fi

# Install required packages
echo "Installing required packages..."
apt update
apt install -y lvm2 samba samba-common-bin

# Create physical volumes
echo "Creating physical volumes..."
pvcreate /dev/sda
pvcreate /dev/sdb

# Create volume group
echo "Creating volume group..."
vgcreate storage_pool /dev/sda /dev/sdb

# Create logical volume using all space
echo "Creating logical volume..."
lvcreate -l 100%FREE -n combined_storage storage_pool

# Format the logical volume
echo "Formatting logical volume..."
mkfs.ext4 /dev/storage_pool/combined_storage

# Create mount point
echo "Creating mount point..."
mkdir -p /mnt/combined_storage

# Add to fstab for permanent mount
echo "Adding to fstab..."
echo "/dev/storage_pool/combined_storage /mnt/combined_storage ext4 defaults 0 0" >> /etc/fstab

# Mount the volume
echo "Mounting volume..."
mount -a

# Configure Samba
echo "Configuring Samba..."
cat > /etc/samba/smb.conf << EOL
[global]
workgroup = WORKGROUP
server string = Raspberry Pi Samba Server
log file = /var/log/samba/log.%m
max log size = 1000
logging = file
panic action = /usr/share/samba/panic-action %d
server role = standalone server
obey pam restrictions = yes
unix password sync = yes
passwd program = /usr/bin/passwd %u
passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
pam password change = yes
map to guest = bad user
socket options = TCP_NODELAY IPTOS_LOWDELAY
read raw = yes
write raw = yes
max xmit = 65535
dead time = 15
getwd cache = yes

[CombinedStorage]
path = /mnt/combined_storage
browseable = yes
read only = no
create mask = 0775
directory mask = 0775
valid users = patrick
force user = patrick
force group = patrick
EOL

# Set ownership and permissions
echo "Setting permissions..."
chown -R patrick:patrick /mnt/combined_storage
chmod -R 0775 /mnt/combined_storage

# Create Samba user (will prompt for password)
echo "Creating Samba user..."
smbpasswd -a patrick

# Restart Samba
echo "Restarting Samba..."
systemctl restart smbd
systemctl restart nmbd

# Enable Samba at boot
systemctl enable smbd
systemctl enable nmbd

echo "Setup complete!"
echo "You can now access your share at:"
echo "Windows: \\\\$(hostname -I | cut -d' ' -f1)\\CombinedStorage"
echo "Linux: smb://$(hostname -I | cut -d' ' -f1)/CombinedStorage"
