# Enhanced ZFS Ubuntu Installation Scripts

A collection of advanced ZFS installation scripts for Ubuntu with modern package management, hardware optimization, and comprehensive system configuration.

## 🚀 Scripts Overview

### 1. `zfs-install-complete.sh` - **Recommended**
**The most comprehensive and modern ZFS installer**

**Features:**
- ✅ **Modern Package Management** - nala with jammy-backports fallback
- ✅ **Interactive GUI** - whiptail-based configuration dialogs
- ✅ **Hardware Detection** - CPU, RAM, GPU detection with ZFS optimization
- ✅ **Multi-Ubuntu Support** - Ubuntu 20.04, 22.04, 24.04, 25.04
- ✅ **Desktop Environment Choice** - KDE, GNOME, XFCE, or minimal
- ✅ **ZFSBootMenu Integration** - Advanced ZFS boot management
- ✅ **User Account Creation** - Full user configuration
- ✅ **System Configuration** - Hostname, timezone, locale, keyboard
- ✅ **ZFS Encryption** - Optional passphrase-based encryption
- ✅ **Advanced ZFS Layout** - Separate boot pool and root pool
- ✅ **SSH Server** - Optional SSH configuration
- ✅ **Comprehensive Logging** - Full installation logging

### 2. `zfs-install-deps-fixed.sh` - **Simple & Reliable**
**Lightweight ZFS installer focused on existing systems**

**Features:**
- ✅ **Modern Package Management** - nala support with backports
- ✅ **Hardware Detection** - Basic hardware optimization
- ✅ **Existing Pool Support** - Works with pre-existing ZFS pools
- ✅ **ZFSBootMenu** - Native UEFI boot entries
- ✅ **Error Resilient** - Handles existing installations gracefully

### 3. `zfsinstall-enhanced.sh` - **Full-Featured Original**
**Comprehensive ZFS installer with all enterprise features**

**Features:**
- ✅ **Complete ZFS Stack** - Advanced pool and dataset management
- ✅ **Multi-disk RAID** - Support for mirrors, RAIDZ1/2/3
- ✅ **Timeshift Integration** - System snapshot management
- ✅ **Multiple Installation Methods** - debootstrap, timeshift restore
- ✅ **Enterprise Features** - Advanced partitioning, encryption, etc.

## 📋 Quick Start

### Recommended: Complete Enhanced Installer

```bash
# Download and run the complete installer
wget https://raw.githubusercontent.com/wlfogle/zfs-installer-enhanced/main/zfs-install-complete.sh
chmod +x zfs-install-complete.sh
sudo ./zfs-install-complete.sh
```

### For Existing Systems

```bash
# Use the simple installer for existing ZFS setups
wget https://raw.githubusercontent.com/wlfogle/zfs-installer-enhanced/main/zfs-install-deps-fixed.sh
chmod +x zfs-install-deps-fixed.sh
RUN_ZFS=1 ./zfs-install-deps-fixed.sh
```

## 🔧 Environment Variables for Automation

### Complete Installer Automation
```bash
export ZFS_UBUNTU_VERSION="22.04"
export ZFS_USERNAME="myuser"
export ZFS_USER_PASSWORD="mypassword"
export ZFS_USER_FULLNAME="My User"
export ZFS_HOSTNAME="my-zfs-system"
export ZFS_TIMEZONE="America/New_York"
export ZFS_LOCALE="en_US.UTF-8"
export ZFS_KEYBOARD_LAYOUT="us"
export ZFS_DESKTOP_ENVIRONMENT="kde"  # kde, gnome, xfce, minimal
export ZFS_USE_ZFSBOOTMENU="1"
export ZFS_ENABLE_SSH="1"
export ZFS_AUTOMATED="1"

sudo ./zfs-install-complete.sh
```

## 🖥️ Hardware Requirements

- **EFI Boot Mode** - UEFI system required
- **Minimum RAM** - 4GB (8GB+ recommended for compilation)
- **Storage** - NVMe SSD recommended for best performance
- **Network** - Internet connection required for package downloads

## 🏗️ What Gets Installed

### Base System
- Ubuntu LTS with latest packages
- ZFS filesystem as root
- Modern package management (nala)
- Essential development tools

### ZFS Configuration
- **Root Pool** (rpool) - Main system storage
- **Boot Pool** (bpool) - Separate boot storage  
- **Datasets** - Organized ZFS dataset hierarchy
- **Compression** - LZ4 compression enabled
- **Optimization** - Hardware-specific tuning

### Boot Management
- **ZFSBootMenu** - Advanced ZFS boot manager (recommended)
- **GRUB** - Traditional bootloader (alternative)
- **UEFI Integration** - Native UEFI boot entries

### Desktop Environment
Choose from:
- **KDE Plasma** - Feature-rich desktop
- **GNOME** - Ubuntu's default desktop
- **XFCE** - Lightweight desktop
- **Minimal** - Server installation only

## 🔒 Security Features

- **ZFS Encryption** - AES-256-GCM encryption
- **SSH Configuration** - Secure remote access
- **Firewall Setup** - UFW firewall configuration
- **User Accounts** - Proper sudo user creation

## 📊 Performance Features

- **Hardware Detection** - Automatic CPU/RAM optimization
- **ARC Tuning** - Memory-based ARC size optimization
- **SSD Optimization** - Solid state drive optimizations
- **Compression** - Transparent compression for better performance

**⚠️ Important:** These scripts will modify disk partitions and install a complete operating system. Always backup your data before running on production systems!
