#!/bin/bash

# ZFS Installer Demo Script
# This script demonstrates how to use the ZFS installation scripts

set -euo pipefail

echo "🚀 ZFS Installer Demo Script"
echo "=============================="
echo ""

# Show available scripts
echo "📋 Available ZFS Installation Scripts:"
echo ""
echo "1. zfs-install-complete.sh    - Complete modern installer (RECOMMENDED)"
echo "2. zfs-install-deps-fixed.sh  - Simple installer for existing systems"
echo "3. zfsinstall-enhanced.sh     - Full enterprise installer"
echo ""

# Interactive mode demo
echo "🎯 Interactive Installation Demo:"
echo ""
echo "# For new ZFS installations:"
echo "sudo ./zfs-install-complete.sh"
echo ""

# Automated mode demo
echo "🤖 Automated Installation Demo:"
echo ""
cat << 'EOF'
# Set environment variables for automated installation
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

# Run automated installation
sudo ./zfs-install-complete.sh
EOF

echo ""

# Existing system demo
echo "🔧 Existing ZFS System Demo:"
echo ""
echo "# For existing ZFS pools (adds modern package management):"
echo "RUN_ZFS=1 ./zfs-install-deps-fixed.sh"
echo ""

# Download demo
echo "⬇️  Download and Run Demo:"
echo ""
cat << 'EOF'
# Download from GitHub
wget https://raw.githubusercontent.com/wlfogle/zfs-installer-enhanced/main/zfs-install-complete.sh
chmod +x zfs-install-complete.sh

# Run with default settings
sudo ./zfs-install-complete.sh
EOF

echo ""
echo "⚠️  IMPORTANT: These scripts will modify disk partitions!"
echo "   Always backup your data before running on production systems."
echo ""
echo "📖 For more information, see: https://github.com/wlfogle/zfs-installer-enhanced"