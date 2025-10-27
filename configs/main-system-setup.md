# Main System Configuration Setup

## 1. Ollama Configuration with Existing Models

### Configure Ollama to use your existing models directory:

```bash
# Stop Ollama if running
sudo systemctl stop ollama

# Copy the service configuration
sudo cp configs/ollama-service.txt /etc/systemd/system/ollama.service

# Reload systemd and start Ollama
sudo systemctl daemon-reload
sudo systemctl enable --now ollama

# Verify Ollama is using your models
ollama list
```

Your existing models from `/media/kubuntu/73cf9511-0af0-4ac4-9d83-ee21eb17ff5d/models` will be available immediately.

## 2. Virt-Manager Setup for Proxmox VM

### Install virt-manager and virtualization tools:

```bash
# Install virtualization packages
sudo apt update
sudo apt install -y virt-manager libvirt-daemon-system libvirt-clients bridge-utils qemu-kvm

# Add your user to libvirt group
sudo usermod -aG libvirt $USER

# Start and enable libvirt service
sudo systemctl enable --now libvirtd

# Log out and back in for group changes to take effect
```

### Import the Proxmox VM:

```bash
# Import the VM definition
sudo virsh define configs/proxmox-ve-vm.xml

# Verify VM was imported
virsh list --all
```

### Launch virt-manager GUI:

```bash
virt-manager
```

## 3. VM Configuration Details

The Proxmox VM configuration includes:
- **Name**: proxmox-ve
- **Memory**: 8GB RAM (adjustable)
- **CPUs**: 4 cores with host passthrough
- **Disk**: Your existing `/media/kubuntu/Data/vms/production/proxmox-ve.qcow2` (~471GB)
- **Network**: Virtio network adapter on default bridge
- **Graphics**: SPICE with QXL video
- **Features**: UEFI ready, virtio drivers, QEMU guest agent support

## 4. Adjusting VM Resources (Optional)

To modify CPU/RAM allocation, edit the VM in virt-manager or use virsh:

```bash
# Edit VM configuration
virsh edit proxmox-ve

# Or adjust memory/CPUs via commands:
virsh setmaxmem proxmox-ve 16G --config  # Set max RAM to 16GB
virsh setmem proxmox-ve 12G --config     # Set current RAM to 12GB  
virsh setvcpus proxmox-ve 8 --config     # Set to 8 CPU cores
```

## 5. Starting the Proxmox VM

```bash
# Start the VM
virsh start proxmox-ve

# Or use virt-manager GUI
virt-manager
```

## 6. Network Bridge Setup (Optional)

For better networking, you can create a bridge interface:

```bash
# Create bridge configuration
sudo tee /etc/netplan/01-netcfg.yaml >/dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:  # Replace with your interface name
      dhcp4: no
  bridges:
    br0:
      interfaces: [enp0s3]
      dhcp4: yes
      parameters:
        stp: false
        forward-delay: 0
EOF

# Apply network configuration
sudo netplan apply
```

Then update the VM to use the bridge in virt-manager.

## 7. Performance Optimizations

For better VM performance:

1. **Enable KVM nested virtualization** (if needed for Proxmox):
   ```bash
   echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm.conf
   # OR for AMD:
   echo 'options kvm_amd nested=1' | sudo tee /etc/modprobe.d/kvm.conf
   ```

2. **CPU pinning** for dedicated cores (advanced):
   ```bash
   # Edit VM and add CPU pinning in XML
   virsh edit proxmox-ve
   ```

3. **Hugepages** for large VMs:
   ```bash
   # Add to /etc/default/grub
   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash hugepages=2048"
   sudo update-grub
   ```

Your Proxmox VM is now ready to run with your existing disk image and will have access to all your configured virtual machines and containers!