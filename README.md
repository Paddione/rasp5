# rasp5

# rasp5

DYNDNS:

crontab -e
*/20 * * * * curl -sSL "https://ipv64.net/update.php?key=2k7Nx95FfBjVlCYgdnWSiLoQw1sXDzMR&domain=korczewski.de"


createvm.sh

#!/bin/bash

# 1. Download Ubuntu Server 22.04 to Proxmox
wget https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img

# 2. Create a new VM
qm create 9000 --memory 16000 --cores 4 --name ubuntu-k3s-template --net0 virtio,bridge=vmbr0

# 3. Import the disk
qm importdisk 9000 ubuntu-22.04-server-cloudimg-amd64.img local-lvm

# 4. Configure the VM to use the imported disk
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0

# 5. Configure cloud-init
qm set 9000 --ciuser patrick
qm set 9000 --cipassword "170591pk"
qm set 9000 --sshkeys ~/.ssh/id_ed25519.pub

# 6. Resize the disk to 32GB
qm resize 9000 scsi0 32G

# Create the template
qm template 9000

# Now to create a new VM from template:
qm clone 9000 101 --name k3s-node1 --full****


ln -s /var/lib/rancher/k3s/server/manifests/ /home/patrick/rasp5/
sudo chown -h patrick:patrick /home/ubuntu/patrick/rasp5/
