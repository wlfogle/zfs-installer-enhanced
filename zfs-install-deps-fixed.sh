#!/bin/bash
set -euo pipefail

# Constants
ZPOOL_NAME="rpool"
ZFS_DATASET="$ZPOOL_NAME/ROOT/kubuntu"
LOG_FILE="/tmp/zfs-install-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "[$(date +'%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date +'%H:%M:%S')] ❌ ERROR: $*" | tee -a "$LOG_FILE" >&2
    exit 1
}

# Install ALL dependencies at the start
install_all_dependencies() {
    log "🔧 Installing ALL dependencies (including nala)..."
    
    # Update package lists first
    sudo apt update
    
    # Enable jammy-backports repository for nala
    log "📦 Enabling jammy-backports repository..."
    if ! grep -q "jammy-backports" /etc/apt/sources.list.d/* 2>/dev/null; then
        sudo add-apt-repository -y "deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse"
        sudo apt update
    fi
    
    # Core system dependencies first
    log "📦 Installing core system packages..."
    sudo apt install -y \
        curl wget git lsb-release software-properties-common \
        apt-transport-https ca-certificates gnupg \
        debootstrap efibootmgr file util-linux \
        parted gdisk pciutils \
        build-essential dkms linux-headers-generic
    
    # Try to install nala if available, otherwise use apt
    log "📦 Trying to install nala package manager..."
    
    if ! command -v nala >/dev/null 2>&1; then
        # Try to install nala from universe repo or PPA
        if ! sudo apt install -y nala 2>/dev/null; then
            log "⚠️  nala not available, using apt (which works perfectly fine)"
            USE_APT=true
        else
            log "✅ nala installed successfully"
        fi
    else
        log "✅ nala already available"
    fi
    
    # Install ZFS packages
    log "📦 Installing ZFS packages..."
    if command -v nala >/dev/null 2>&1 && [ "${USE_APT:-false}" != "true" ]; then
        sudo nala install -y zfsutils-linux
    else
        sudo apt install -y zfsutils-linux
    fi
    
    # Install additional useful packages
    log "📦 Installing additional system packages..."
    local additional_packages=(
        "vim" "nano" "htop" "neofetch" "tree" "rsync"
        "openssh-server" "ufw" "fail2ban"
        "python3" "python3-pip" "python3-venv"
        "nodejs" "npm"
    )
    
    if command -v nala >/dev/null 2>&1 && [ "${USE_APT:-false}" != "true" ]; then
        sudo nala install -y "${additional_packages[@]}" || true
    else
        sudo apt install -y "${additional_packages[@]}" || true
    fi
    
    log "✅ All dependencies installed successfully!"
}

# Hardware detection
detect_hardware() {
    log "🔍 Detecting hardware..."
    
    CPU_CORES=$(nproc)
    TOTAL_RAM_GB=$(($(awk '/MemTotal:/ {print $2}' /proc/meminfo) / 1024 / 1024))
    HAS_NVIDIA=$(lspci 2>/dev/null | grep -i nvidia >/dev/null && echo "yes" || echo "no")
    
    log "💻 Hardware: ${CPU_CORES} cores, ${TOTAL_RAM_GB}GB RAM, NVIDIA: ${HAS_NVIDIA}"
}

# Check existing ZFS pools
check_zfs_pools() {
    log "🔍 Checking for existing ZFS pools..."
    
    if command -v zpool >/dev/null 2>&1; then
        local existing_pools=($(zpool list -H -o name 2>/dev/null || true))
        if [ ${#existing_pools[@]} -gt 0 ]; then
            log "🎯 Found existing pools: ${existing_pools[*]}"
            return 0
        fi
    fi
    
    log "ℹ️  No existing ZFS pools found"
    return 1
}

# Create ZFS pool on nvme0n1
create_zfs_pool() {
    log "🆕 Creating ZFS pool on /dev/nvme0n1..."
    
    # Verify disk exists
    if [ ! -b "/dev/nvme0n1" ]; then
        error "Disk /dev/nvme0n1 not found!"
    fi
    
    # Create pool with optimizations
    sudo zpool create -f \
        -o ashift=12 \
        -o autotrim=on \
        -O normalization=formD \
        -O mountpoint=none \
        -O atime=off \
        -O compression=zstd \
        -O recordsize=128k \
        "$ZPOOL_NAME" /dev/nvme0n1
    
    log "✅ ZFS pool '$ZPOOL_NAME' created successfully"
}

# Create ZFS datasets
create_datasets() {
    log "📁 Creating ZFS datasets..."
    
    # Create dataset hierarchy (skip if already exists)
    sudo zfs create "$ZPOOL_NAME/ROOT" 2>/dev/null || log "ℹ️  Dataset $ZPOOL_NAME/ROOT already exists"
    sudo zfs create -o mountpoint=/mnt "$ZFS_DATASET" 2>/dev/null || log "ℹ️  Dataset $ZFS_DATASET already exists"
    sudo zfs create -o mountpoint=/mnt/boot "$ZPOOL_NAME/BOOT" 2>/dev/null || log "ℹ️  Dataset $ZPOOL_NAME/BOOT already exists"
    
    # Don't create separate datasets for /home, /var, etc. initially
    # Let them be part of the root filesystem for simplicity
    
    log "✅ ZFS datasets created/verified"
}

# Install base system
install_base_system() {
    log "📦 Installing base Ubuntu system..."
    
    # Mount datasets
    sudo zfs mount "$ZFS_DATASET" || true
    sudo zfs mount "$ZPOOL_NAME/BOOT" || true
    
    # Create directories
    sudo mkdir -p /mnt/boot/efi
    
    # Mount EFI partition
    sudo mount /dev/nvme1n1p6 /mnt/boot/efi || true
    
    # Check if base system is already installed
    if [ -f "/mnt/bin/bash" ]; then
        log "ℹ️  Base system already installed, skipping debootstrap"
        
        # If we have separate datasets that are empty, populate them from the root
        if [ -d "/mnt/var" ] && [ -z "$(ls -A /mnt/var 2>/dev/null | grep -v '^log$')" ]; then
            log "🔄 Populating empty /var dataset..."
            # Temporarily unmount var dataset
            sudo zfs unmount "$ZFS_DATASET/var" || true
            # Copy var contents to dataset
            if [ -d "/mnt/var.backup" ]; then
                sudo cp -a /mnt/var.backup/* /mnt/var/ 2>/dev/null || true
            fi
            # Remount
            sudo zfs mount "$ZFS_DATASET/var" || true
        fi
    else
        # Install base system
        log "📦 Running debootstrap..."
        sudo debootstrap --arch=amd64 jammy /mnt http://archive.ubuntu.com/ubuntu/
        
        # If we have separate datasets, we need to handle them after debootstrap
        if sudo zfs list "$ZFS_DATASET/var" >/dev/null 2>&1; then
            log "🔄 Moving /var contents to separate dataset..."
            sudo mv /mnt/var /mnt/var.backup
            sudo mkdir /mnt/var
            sudo zfs mount "$ZFS_DATASET/var"
            sudo cp -a /mnt/var.backup/* /mnt/var/ 2>/dev/null || true
        fi
    fi
    
    # Configure fstab (only if not already configured)
    if ! grep -q "$ZFS_DATASET" /mnt/etc/fstab 2>/dev/null; then
        echo "$ZFS_DATASET / zfs defaults 0 0" | sudo tee -a /mnt/etc/fstab
    fi
    
    # Bind mount
    sudo mount --rbind /dev /mnt/dev || true
    sudo mount --rbind /proc /mnt/proc || true
    sudo mount --rbind /sys /mnt/sys || true
    
    # Install packages in chroot
    sudo chroot /mnt apt update
    sudo chroot /mnt apt install -y \
        zfsutils-linux linux-image-generic linux-headers-generic \
        openssh-server sudo vim nano curl wget git || true
    
    # Configure locale
    sudo chroot /mnt locale-gen en_US.UTF-8 || true
    
    # Set hostname
    echo "zfs-system" | sudo tee /mnt/etc/hostname
    
    log "✅ Base system installed/configured"
}

# Install ZFSBootMenu
install_zfsbootmenu() {
    log "🥾 Installing ZFSBootMenu..."
    
    local esp="/mnt/boot/efi"
    sudo mkdir -p "$esp/EFI/ZBM"
    
    # Download ZFSBootMenu
    local temp_file=$(mktemp)
    if curl -fsSL https://get.zfsbootmenu.org/efi -o "$temp_file"; then
        sudo install -m 0644 "$temp_file" "$esp/EFI/ZBM/ZFSBootMenu.EFI"
        rm -f "$temp_file"
        
        # Create UEFI entry
        if command -v efibootmgr >/dev/null 2>&1; then
            local disk=$(lsblk -no pkname /dev/nvme1n1p6 2>/dev/null || echo "nvme1n1")
            sudo efibootmgr --create --disk "/dev/$disk" --part 6 \
                --label "ZFSBootMenu" --loader '\EFI\ZBM\ZFSBootMenu.EFI' || true
        fi
        
        log "✅ ZFSBootMenu installed"
    else
        log "❌ Failed to download ZFSBootMenu"
    fi
}

# Main execution
main() {
    log "🚀 Starting ZFS installation with all dependencies"
    
    # Safety check
    if [ "$EUID" -eq 0 ]; then
        error "Don't run as root!"
    fi
    
    # Install ALL dependencies first
    install_all_dependencies
    
    # Hardware detection
    detect_hardware
    
    # Only proceed with ZFS if requested
    if [ "${RUN_ZFS:-0}" = "1" ]; then
        log "🎯 ZFS installation requested"
        
        # Check existing pools or create new
        if ! check_zfs_pools || [ "$ZPOOL_NAME" != "$(zpool list -H -o name 2>/dev/null | head -1)" ]; then
            create_zfs_pool
        else
            log "✅ Using existing ZFS pool"
        fi
        
        # Create datasets
        create_datasets
        
        # Install system
        install_base_system
        
        # Install bootloader
        install_zfsbootmenu
        
        log "🎉 ZFS installation complete!"
        sudo zpool status "$ZPOOL_NAME"
        sudo zfs list -r "$ZPOOL_NAME"
        
    else
        log "ℹ️  Dependencies installed. Set RUN_ZFS=1 to install ZFS system."
        if check_zfs_pools; then
            log "📊 Current ZFS status:"
            sudo zpool status
        fi
    fi
    
    log "✅ Script complete! Log: $LOG_FILE"
}

main "$@"