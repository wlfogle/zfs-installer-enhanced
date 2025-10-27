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

### 3. `zfsinstall-ai-enhanced.sh` - **AI-Powered Gaming & AI System** ⭐
**Complete AI-enhanced ZFS installer with Garuda-style gaming environment**

**Features:**
- 🤖 **AI Hardware Detection** - AVX2/AVX512, detailed GPU detection
- ⚡ **Smart Optimizations** - Hardware-aware ZFS tuning
- 🧠 **ML/AI Stack** - CUDA, PyTorch, Miniforge with optimizations
- 🎮 **Complete Gaming Stack** - Steam, Lutris, Wine, Proton ecosystem
- 🍷 **Windows Compatibility** - ProtonPlus, PortProton, ProtonTricks
- 🕹️ **Emulation Suite** - RetroArch, Dolphin, PCSX2, RPCS3, and more
- 🎯 **Gaming Optimizations** - Low-latency audio, kernel parameters
- 🚀 **Parallel Processing** - Concurrent downloads and installations
- 🛡️ **Security & Privacy** - Comprehensive system hardening
- 🐳 **Docker + GPU** - Container runtime with NVIDIA support
- 📊 **Progress Tracking** - Real-time installation progress

### 4. `zfsinstall-enhanced.sh` - **Full-Featured Original**
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

### AI-Enhanced Installation (RECOMMENDED for ML/AI workloads)

```bash
# AI-powered installer with hardware optimization
wget https://raw.githubusercontent.com/wlfogle/zfs-installer-enhanced/main/zfsinstall-ai-enhanced.sh
chmod +x zfsinstall-ai-enhanced.sh
# For existing systems (adds AI/ML stack + optimizations)
sudo ./zfsinstall-ai-enhanced.sh
# For new ZFS installations
RUN_ZFS=1 sudo ./zfsinstall-ai-enhanced.sh
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

## 🤖 AI-Enhanced Features (NEW!)

The `zfsinstall-ai-enhanced.sh` script includes cutting-edge AI-powered optimizations:

### 🔍 **Advanced Hardware Detection**
- **CPU Instructions** - AVX2, AVX512 detection for optimal software selection
- **GPU Detection** - NVIDIA, Intel, AMD graphics with driver optimization
- **Storage Analysis** - NVMe vs SSD detection for I/O scheduler tuning
- **Memory Profiling** - RAM-based ARC and application tuning

### ⚡ **Smart Performance Optimizations**
- **ZFS Compression** - ZSTD for AVX2+ CPUs, LZ4 fallback
- **I/O Schedulers** - `none` for NVMe, `mq-deadline` for SATA
- **CPU Governors** - Performance mode for compute workloads
- **Network Stack** - TCP buffer and queue optimizations

### 🧠 **AI/ML Stack Integration**
- **CUDA Toolkit** - Automatic installation for NVIDIA GPUs
- **PyTorch** - CPU/GPU variants based on hardware
- **Miniforge** - Optimized conda environment with libmamba
- **Intel Extensions** - AVX2+ optimizations for Intel CPUs
- **Docker + GPU** - NVIDIA container runtime support

### 🚀 **Parallel Processing**
- **Concurrent Downloads** - Multiple package downloads with retry logic
- **Smart Package Management** - Individual fallback with progress tracking
- **Error Recovery** - Automatic retry with exponential backoff

### 🎮 **Complete Gaming Ecosystem (Garuda-inspired)**

#### Gaming Platforms & Launchers
- **Steam** - Official Steam client with all dependencies
- **Lutris** - Universal gaming platform for Windows/Linux games
- **Heroic Games Launcher** - Epic Games Store and GOG client
- **Bottles** - Advanced Wine prefix manager
- **GameHub** - Unified game library manager

#### Windows Game Compatibility
- **Wine Staging** - Latest Wine with experimental features
- **ProtonPlus** - Advanced Proton version manager
- **PortProton** - Complete Wine prefix management solution
- **ProtonTricks** - Winetricks for Steam Play/Proton games
- **Winetricks** - Windows component installer

#### Gaming Performance Tools
- **MangoHUD** - In-game performance overlay
- **GameMode** - Automatic system optimization for games
- **Goverlay** - GUI for MangoHUD and other overlays
- **CoreCtrl** - Hardware control and monitoring
- **Performance Governors** - Automatic CPU scaling for games

#### Complete Emulation Suite
- **RetroArch** - Multi-system emulator with advanced features
- **Dolphin** - GameCube/Wii emulator
- **PCSX2** - PlayStation 2 emulator
- **PPSSPP** - PlayStation Portable emulator
- **RPCS3** - PlayStation 3 emulator
- **Citra/Yuzu** - Nintendo 3DS/Switch emulators
- **MAME** - Arcade machine emulator

#### Gaming Optimizations
- **Low-latency Audio** - PulseAudio optimization for gaming
- **Kernel Parameters** - Gaming-focused system tuning
- **GPU Optimization** - NVIDIA/AMD-specific gaming profiles
- **Network Tuning** - Reduced latency for online gaming
- **Memory Management** - Gaming-optimized vm parameters
- **I/O Scheduling** - Game loading optimization

## 📈 **Script Comparison**

| Feature | Complete | Simple | AI-Enhanced ⭐ | Enhanced |
|---------|----------|--------|----------------|----------|
| Modern Package Mgmt | ✅ | ✅ | ✅ | ❌ |
| Interactive GUI | ✅ | ❌ | ❌ | ✅ |
| Hardware Detection | ✅ | ✅ | 🤖 **AI-Powered** | ❌ |
| Desktop Choice | ✅ | ❌ | ❌ | ✅ |
| Multi-disk RAID | ❌ | ❌ | ❌ | ✅ |
| Existing Pool Support | ❌ | ✅ | ✅ | ❌ |
| AI/ML Stack | ❌ | ❌ | ✅ | ❌ |
| Performance Tuning | ❌ | ❌ | ✅ | ❌ |
| Parallel Processing | ❌ | ❌ | ✅ | ❌ |
| CUDA/GPU Support | ❌ | ❌ | ✅ | ❌ |
| Docker Integration | ❌ | ❌ | ✅ | ❌ |
| Progress Tracking | ❌ | ❌ | ✅ | ❌ |
| Timeshift Integration | ❌ | ❌ | ❌ | ✅ |
| Encryption Support | ✅ | ❌ | ❌ | ✅ |

### 🎯 **Recommended Usage**

- **AI/ML Workloads** → Use `zfsinstall-ai-enhanced.sh` ⭐
- **New Installations** → Use `zfs-install-complete.sh`
- **Existing ZFS Systems** → Use `zfs-install-deps-fixed.sh`
- **Enterprise/Advanced** → Use `zfsinstall-enhanced.sh`

**⚠️ Important:** These scripts will modify disk partitions and install a complete operating system. Always backup your data before running on production systems!
