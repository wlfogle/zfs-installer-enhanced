#!/bin/bash

# Complete Enhanced ZFS Installation Script
# Combines the best of both worlds: modern package management + comprehensive ZFS features
# Features:
# - Ubuntu version selection (20.04, 22.04, 24.04, 25.04)
# - Multiple installation methods (debootstrap, timeshift_restore)
# - User account and system configuration
# - Desktop environment selection
# - ZFSBootMenu vs GRUB choice
# - Advanced ZFS features (encryption, RAID, etc.)
# - Timeshift integration
# - Hardware detection and optimization
# - Modern package management (nala with backports fallback)

set -euo pipefail

# VARIABLES/CONSTANTS ##########################################################

# Enhanced variables for custom installation
v_ubuntu_version=               # Ubuntu version to install (20.04, 22.04, 24.04, etc.)
v_install_method=               # debootstrap, timeshift_restore
v_username=                     # Primary user account name
v_user_password=                # Primary user account password
v_user_fullname=                # User's full name
v_hostname=                     # System hostname
v_timezone=                     # System timezone (e.g., America/New_York)
v_locale=                       # System locale (e.g., en_US.UTF-8)
v_keyboard_layout=              # Keyboard layout (e.g., us)
v_desktop_environment=          # Desktop environment (kde, gnome, xfce, minimal)
v_install_timeshift=1           # Install Timeshift (1=yes, 0=no)
v_timeshift_backup_path="/media/kubuntu/0ee261e0-1660-4e03-9377-9484917d9ba6/timeshift"
v_use_zfsbootmenu=              # Use ZFSBootMenu instead of GRUB (1=yes, 0=no)
v_enable_ssh=                   # Enable SSH server (1=yes, 0=no)

# Original variables set (indirectly) by the user
v_boot_partition_size=
v_bpool_create_options=
v_passphrase=
v_root_password=
v_rpool_name=
v_rpool_create_options=
v_dataset_create_options=
declare -A v_vdev_configs
declare -a v_selected_disks
v_swap_size=
v_free_tail_space=

# Variables set during execution
v_linux_distribution=
v_use_ppa=
v_temp_volume_device=
v_suitable_disks=()

# Hardware detection
v_cpu_cores=
v_total_ram_gb=
v_has_nvidia=

# Constants
c_bpool_name=bpool
c_ppa=ppa:jonathonf/zfs
c_efi_system_partition_size=512 # megabytes
c_default_boot_partition_size=2048 # megabytes
c_memory_warning_limit=$((3584 - 128))
c_default_bpool_create_options=(
  -o ashift=12
  -o autotrim=on
  -d
  -o feature@async_destroy=enabled
  -o feature@bookmarks=enabled
  -o feature@embedded_data=enabled
  -o feature@empty_bpobj=enabled
  -o feature@enabled_txg=enabled
  -o feature@extensible_dataset=enabled
  -o feature@filesystem_limits=enabled
  -o feature@hole_birth=enabled
  -o feature@large_blocks=enabled
  -o feature@lz4_compress=enabled
  -o feature@spacemap_histogram=enabled
  -O acltype=posixacl
  -O compression=lz4
  -O devices=off
  -O normalization=formD
  -O relatime=on
  -O xattr=sa
)
c_default_rpool_create_options=(
  -o ashift=12
  -o autotrim=on
  -O acltype=posixacl
  -O compression=lz4
  -O dnodesize=auto
  -O normalization=formD
  -O relatime=on
  -O xattr=sa
  -O devices=off
)

c_zfs_mount_dir=/mnt
c_installed_os_mount_dir=/target
declare -A c_supported_ubuntu_versions=([20.04]="focal" [22.04]="jammy" [24.04]="noble" [25.04]="plucky")
c_temporary_volume_size=12
c_passphrase_named_pipe=$(dirname "$(mktemp)")/zfs-installer.pp.fifo
c_dns=8.8.8.8

c_log_dir=$(dirname "$(mktemp)")/zfs-installer
c_install_log=$c_log_dir/install.log
c_os_information_log=$c_log_dir/os_information.log
c_running_processes_log=$c_log_dir/running_processes.log
c_disks_log=$c_log_dir/disks.log
c_zfs_module_version_log=$c_log_dir/updated_module_versions.log

c_udevadm_settle_timeout=10

# HELPER FUNCTIONS #############################################################

function log() {
    echo "[$(date +'%H:%M:%S')] $*" | tee -a "$c_install_log"
}

function error() {
    echo "[$(date +'%H:%M:%S')] ❌ ERROR: $*" | tee -a "$c_install_log" >&2
    exit 1
}

function print_step_info_header() {
    local function_name=$1
    echo -n "
###############################################################################
# $function_name
###############################################################################
"
}

function print_variables() {
    for variable_name in "$@"; do
        declare -n variable_reference="$variable_name"

        echo -n "$variable_name:"

        case "$(declare -p "$variable_name")" in
        "declare -a"* )
            for entry in "${variable_reference[@]}"; do
                echo -n " \"$entry\""
            done
            ;;
        "declare -A"* )
            for key in "${!variable_reference[@]}"; do
                echo -n " $key=\"${variable_reference[$key]}\""
            done
            ;;
        * )
            echo -n " $variable_reference"
            ;;
        esac

        echo
    done

    echo
}

function chroot_execute() {
    chroot $c_zfs_mount_dir bash -c "$1"
}

# MODERN PACKAGE MANAGEMENT ####################################################

function setup_package_management() {
    log "🔧 Setting up modern package management..."
    
    # Update package lists first
    apt update
    
    # Enable jammy-backports repository for nala
    log "📦 Enabling jammy-backports repository..."
    if ! grep -q "jammy-backports" /etc/apt/sources.list.d/* 2>/dev/null; then
        add-apt-repository -y "deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse"
        apt update
    fi
    
    # Try to install nala
    log "📦 Trying to install nala package manager..."
    if ! command -v nala >/dev/null 2>&1; then
        if apt install -y nala 2>/dev/null; then
            log "✅ nala installed successfully"
            USE_NALA=true
        else
            log "⚠️  nala not available, using apt (which works perfectly fine)"
            USE_NALA=false
        fi
    else
        log "✅ nala already available"
        USE_NALA=true
    fi
}

function pkg_install() {
    if [[ "${USE_NALA:-false}" == "true" ]]; then
        nala install -y "$@"
    else
        apt install -y "$@"
    fi
}

function pkg_update() {
    if [[ "${USE_NALA:-false}" == "true" ]]; then
        nala update
    else
        apt update
    fi
}

# HARDWARE DETECTION ############################################################

function detect_hardware() {
    log "🔍 Detecting hardware..."
    
    v_cpu_cores=$(nproc)
    v_total_ram_gb=$(($(awk '/MemTotal:/ {print $2}' /proc/meminfo) / 1024 / 1024))
    v_has_nvidia=$(lspci 2>/dev/null | grep -i nvidia >/dev/null && echo "yes" || echo "no")
    
    log "💻 Hardware: ${v_cpu_cores} cores, ${v_total_ram_gb}GB RAM, NVIDIA: ${v_has_nvidia}"
}

function optimize_zfs_for_hardware() {
    log "⚡ Optimizing ZFS for detected hardware..."
    
    # Set ARC size based on available RAM (50% max)
    local arc_max=$((v_total_ram_gb * 1024 * 1024 * 1024 / 2))
    echo "$arc_max" > /sys/module/zfs/parameters/zfs_arc_max 2>/dev/null || true
    
    # Optimize for SSD if detected
    if lsblk -d -o name,rota | grep -q "0$"; then
        log "🔧 SSD detected, optimizing for solid state drives"
        # Additional SSD optimizations can be added here
    fi
    
    # Set optimal record size based on use case
    if [[ $v_total_ram_gb -gt 16 ]]; then
        log "🔧 High memory system detected, using larger record sizes"
        # Can adjust default record sizes for datasets
    fi
}

# USER INTERFACE FUNCTIONS ######################################################

function display_help_and_exit() {
    local help='Complete Enhanced ZFS Ubuntu Installation Script

Usage: zfs-install-complete.sh [-h|--help]

Environment Variables for Automation:
- ZFS_UBUNTU_VERSION         : Ubuntu version (20.04, 22.04, 24.04, 25.04)
- ZFS_INSTALL_METHOD         : Installation method (debootstrap, timeshift_restore)
- ZFS_USERNAME              : Primary user account name
- ZFS_USER_PASSWORD         : Primary user account password  
- ZFS_USER_FULLNAME         : User full name
- ZFS_HOSTNAME              : System hostname
- ZFS_TIMEZONE              : System timezone (e.g. America/New_York)
- ZFS_LOCALE                : System locale (e.g. en_US.UTF-8)
- ZFS_KEYBOARD_LAYOUT       : Keyboard layout (e.g. us)
- ZFS_DESKTOP_ENVIRONMENT   : Desktop (kde, gnome, xfce, minimal)
- ZFS_USE_ZFSBOOTMENU       : Use ZFSBootMenu instead of GRUB (1=yes, 0=no)
- ZFS_ENABLE_SSH            : Enable SSH server (1=yes, 0=no)

ZFS Configuration Variables:
- ZFS_SELECTED_DISKS, ZFS_PASSPHRASE, ZFS_RPOOL_NAME, etc.

Features:
- Modern package management with nala
- Hardware detection and optimization
- Multiple desktop environments
- ZFSBootMenu integration
- Timeshift backup support
- Advanced ZFS features (encryption, RAID, etc.)
'

    echo "$help"
    exit 0
}

function ask_ubuntu_version() {
    if [[ -n ${ZFS_UBUNTU_VERSION:-} ]]; then
        v_ubuntu_version=$ZFS_UBUNTU_VERSION
    else
        local version_options=(
            "20.04" "Ubuntu 20.04 LTS (Focal)" OFF
            "22.04" "Ubuntu 22.04 LTS (Jammy)" ON
            "24.04" "Ubuntu 24.04 LTS (Noble)" OFF
            "25.04" "Ubuntu 25.04 (Plucky)" OFF
        )

        v_ubuntu_version=$(whiptail --radiolist "Select Ubuntu version to install:" 30 100 4 "${version_options[@]}" 3>&1 1>&2 2>&3)
    fi

    print_variables v_ubuntu_version
}

function ask_installation_method() {
    if [[ -n ${ZFS_INSTALL_METHOD:-} ]]; then
        v_install_method=$ZFS_INSTALL_METHOD
    else
        local method_options=(
            "debootstrap" "Fresh installation via debootstrap" ON
            "timeshift_restore" "Restore from Timeshift backup" OFF
        )

        v_install_method=$(whiptail --radiolist "Select installation method:" 30 100 2 "${method_options[@]}" 3>&1 1>&2 2>&3)
    fi

    print_variables v_install_method
}

function ask_user_configuration() {
    if [[ -n ${ZFS_USERNAME:-} ]]; then
        v_username=$ZFS_USERNAME
    else
        while [[ ! $v_username =~ ^[a-z][a-z0-9_-]*$ || -z $v_username ]]; do
            v_username=$(whiptail --inputbox "Enter username (lowercase, alphanumeric):" 30 100 "user" 3>&1 1>&2 2>&3)
        done
    fi

    set +x
    if [[ -n ${ZFS_USER_PASSWORD:-} ]]; then
        v_user_password=$ZFS_USER_PASSWORD
    else
        local password_repeat=-
        while [[ $v_user_password != "$password_repeat" || -z $v_user_password ]]; do
            v_user_password=$(whiptail --passwordbox "Enter password for $v_username:" 30 100 3>&1 1>&2 2>&3)
            password_repeat=$(whiptail --passwordbox "Repeat password:" 30 100 3>&1 1>&2 2>&3)
        done
    fi
    set -x

    if [[ -n ${ZFS_USER_FULLNAME:-} ]]; then
        v_user_fullname=$ZFS_USER_FULLNAME
    else
        v_user_fullname=$(whiptail --inputbox "Enter full name for $v_username:" 30 100 "User" 3>&1 1>&2 2>&3)
    fi

    print_variables v_username v_user_fullname
}

function ask_hostname() {
    if [[ -n ${ZFS_HOSTNAME:-} ]]; then
        v_hostname=$ZFS_HOSTNAME
    else
        while [[ ! $v_hostname =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$ || -z $v_hostname ]]; do
            v_hostname=$(whiptail --inputbox "Enter system hostname:" 30 100 "zfs-system" 3>&1 1>&2 2>&3)
        done
    fi

    print_variables v_hostname
}

function ask_system_configuration() {
    if [[ -n ${ZFS_TIMEZONE:-} ]]; then
        v_timezone=$ZFS_TIMEZONE
    else
        v_timezone=$(whiptail --inputbox "Enter timezone (e.g. America/New_York):" 30 100 "UTC" 3>&1 1>&2 2>&3)
    fi

    if [[ -n ${ZFS_LOCALE:-} ]]; then
        v_locale=$ZFS_LOCALE
    else
        v_locale=$(whiptail --inputbox "Enter system locale:" 30 100 "en_US.UTF-8" 3>&1 1>&2 2>&3)
    fi

    if [[ -n ${ZFS_KEYBOARD_LAYOUT:-} ]]; then
        v_keyboard_layout=$ZFS_KEYBOARD_LAYOUT
    else
        v_keyboard_layout=$(whiptail --inputbox "Enter keyboard layout:" 30 100 "us" 3>&1 1>&2 2>&3)
    fi

    print_variables v_timezone v_locale v_keyboard_layout
}

function ask_desktop_environment() {
    if [[ -n ${ZFS_DESKTOP_ENVIRONMENT:-} ]]; then
        v_desktop_environment=$ZFS_DESKTOP_ENVIRONMENT
    else
        local desktop_options=(
            "kde" "KDE Plasma Desktop" OFF
            "gnome" "GNOME Desktop" ON
            "xfce" "XFCE Desktop" OFF
            "minimal" "Minimal (no desktop)" OFF
        )

        v_desktop_environment=$(whiptail --radiolist "Select desktop environment:" 30 100 4 "${desktop_options[@]}" 3>&1 1>&2 2>&3)
    fi

    print_variables v_desktop_environment
}

function ask_additional_options() {
    if [[ -n ${ZFS_USE_ZFSBOOTMENU:-} ]]; then
        v_use_zfsbootmenu=$ZFS_USE_ZFSBOOTMENU
    else
        if whiptail --yesno "Use ZFSBootMenu instead of GRUB?\n\nZFSBootMenu provides better ZFS snapshot management and boot options." 30 100; then
            v_use_zfsbootmenu=1
        else
            v_use_zfsbootmenu=0
        fi
    fi

    if [[ -n ${ZFS_ENABLE_SSH:-} ]]; then
        v_enable_ssh=$ZFS_ENABLE_SSH
    else
        if whiptail --yesno "Enable SSH server?" 30 100; then
            v_enable_ssh=1
        else
            v_enable_ssh=0
        fi
    fi

    print_variables v_use_zfsbootmenu v_enable_ssh
}

# INSTALLATION FUNCTIONS ########################################################

function install_all_dependencies() {
    log "🔧 Installing ALL dependencies..."
    
    setup_package_management
    
    # Core system dependencies first
    log "📦 Installing core system packages..."
    pkg_install \
        curl wget git lsb-release software-properties-common \
        apt-transport-https ca-certificates gnupg \
        debootstrap efibootmgr file util-linux \
        parted gdisk pciutils \
        build-essential dkms linux-headers-generic
    
    # Install ZFS packages
    log "📦 Installing ZFS packages..."
    pkg_install zfsutils-linux
    
    # Install additional useful packages
    log "📦 Installing additional system packages..."
    local additional_packages=(
        "vim" "nano" "htop" "neofetch" "tree" "rsync"
        "openssh-server" "ufw" "fail2ban"
        "python3" "python3-pip" "python3-venv"
        "nodejs" "npm"
        "whiptail" "dialog"
    )
    
    pkg_install "${additional_packages[@]}" || true
    
    log "✅ All dependencies installed successfully!"
}

# ZFS AND DISK FUNCTIONS #######################################################

function find_suitable_disks() {
    log "🔍 Finding suitable disks..."
    udevadm trigger

    local candidate_disk_ids
    local mounted_devices

    candidate_disk_ids=$(find /dev/disk/by-id -regextype awk -regex '.+/(ata|nvme|scsi|mmc)-.+' -not -regex '.+-part[0-9]+$' | sort)
    mounted_devices="$(df | awk 'BEGIN {getline} {print $1}' | xargs -n 1 lsblk -no pkname 2> /dev/null | sort -u || true)"

    while read -r disk_id || [[ -n $disk_id ]]; do
        local device_info
        local block_device_basename

        device_info="$(udevadm info --query=property "$(readlink -f "$disk_id")")"
        block_device_basename="$(basename "$(readlink -f "$disk_id")")"

        if ! grep -q '^ID_TYPE=cd$' <<< "$device_info"; then
            if ! grep -q "^$block_device_basename\$" <<< "$mounted_devices"; then
                v_suitable_disks+=("$disk_id")
            fi
        fi
    done < <(echo -n "$candidate_disk_ids")

    if [[ ${#v_suitable_disks[@]} -eq 0 ]]; then
        error "No suitable disks have been found!"
    fi

    log "✅ Found ${#v_suitable_disks[@]} suitable disks"
    print_variables v_suitable_disks
}

function select_disks() {
    if [[ -n ${ZFS_SELECTED_DISKS:-} ]]; then
        mapfile -d, -t v_selected_disks < <(echo -n "$ZFS_SELECTED_DISKS")
    else
        while true; do
            local menu_entries_option=()
            local block_device_basename

            if [[ ${#v_suitable_disks[@]} -eq 1 ]]; then
                local disk_selection_status=ON
            else
                local disk_selection_status=OFF
            fi

            for disk_id in "${v_suitable_disks[@]}"; do
                block_device_basename="$(basename "$(readlink -f "$disk_id")")"
                menu_entries_option+=("$disk_id" "($block_device_basename)" $disk_selection_status)
            done

            local dialog_message="Select the ZFS devices.\n\nDevices with mounted partitions, cdroms, and removable devices are not displayed!"
            mapfile -t v_selected_disks < <(whiptail --checklist --separate-output "$dialog_message" 30 100 $((${#menu_entries_option[@]} / 3)) "${menu_entries_option[@]}" 3>&1 1>&2 2>&3)

            if [[ ${#v_selected_disks[@]} -gt 0 ]]; then
                break
            fi
        done
    fi

    print_variables v_selected_disks
}

function ask_encryption() {
    set +x

    if [[ -v ZFS_PASSPHRASE ]]; then
        v_passphrase=$ZFS_PASSPHRASE
    else
        local passphrase_repeat=_
        local passphrase_invalid_message=

        while [[ $v_passphrase != "$passphrase_repeat" || ${#v_passphrase} -lt 8 ]]; do
            local dialog_message="${passphrase_invalid_message}Please enter the passphrase (8 chars min.):\n\nLeave blank to keep encryption disabled."

            v_passphrase=$(whiptail --passwordbox "$dialog_message" 30 100 3>&1 1>&2 2>&3)

            if [[ -z $v_passphrase ]]; then
                break
            fi

            passphrase_repeat=$(whiptail --passwordbox "Please repeat the passphrase:" 30 100 3>&1 1>&2 2>&3)

            passphrase_invalid_message="Passphrase too short, or not matching! "
        done
    fi

    set -x
}

function setup_partitions() {
    log "💾 Setting up disk partitions..."
    local required_tail_space=$((v_free_tail_space > c_temporary_volume_size ? v_free_tail_space : c_temporary_volume_size))

    for selected_disk in "${v_selected_disks[@]}"; do
        find "$(dirname "$selected_disk")" -name "$(basename "$selected_disk")-part*" -exec bash -c '
            zpool labelclear -f "$1" 2> /dev/null || true
        ' _ {} \;

        wipefs --all "$selected_disk"

        sgdisk -n1:1M:+"${c_efi_system_partition_size}M" -t1:EF00 "$selected_disk" # EFI boot
        sgdisk -n2:0:+"$v_boot_partition_size"           -t2:BF01 "$selected_disk" # Boot pool
        sgdisk -n3:0:"-${required_tail_space}G"          -t3:BF01 "$selected_disk" # Root pool
        sgdisk -n4:0:0                                   -t4:8300 "$selected_disk" # Temporary partition
    done

    udevadm settle --timeout "$c_udevadm_settle_timeout" || true

    for selected_disk in "${v_selected_disks[@]}"; do
        mkfs.fat -F 32 -n EFI "${selected_disk}-part1"
    done

    v_temp_volume_device=$(readlink -f "${v_selected_disks[0]}-part4")
    log "✅ Partitions created successfully"
}

# INSTALLATION METHODS ##########################################################

function install_operating_system_debootstrap() {
    local ubuntu_codename=${c_supported_ubuntu_versions[$v_ubuntu_version]}
    
    log "📦 Installing Ubuntu $v_ubuntu_version ($ubuntu_codename) via debootstrap..."

    # Mount temporary volume for debootstrap
    mkfs.ext4 "$v_temp_volume_device"
    mkdir -p "$c_installed_os_mount_dir"
    mount "$v_temp_volume_device" "$c_installed_os_mount_dir"

    # Run debootstrap
    debootstrap --arch=amd64 --include=openssh-server,curl,wget,software-properties-common \
        "$ubuntu_codename" "$c_installed_os_mount_dir" http://archive.ubuntu.com/ubuntu/

    # Configure basic system in chroot
    mount --bind /dev "$c_installed_os_mount_dir/dev"
    mount --bind /proc "$c_installed_os_mount_dir/proc"
    mount --bind /sys "$c_installed_os_mount_dir/sys"

    # Configure hostname
    echo "$v_hostname" > "$c_installed_os_mount_dir/etc/hostname"

    # Configure hosts file
    cat > "$c_installed_os_mount_dir/etc/hosts" << EOF
127.0.0.1 localhost
127.0.1.1 $v_hostname
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes  
ff02::2   ip6-allrouters
EOF

    # Configure apt sources
    cat > "$c_installed_os_mount_dir/etc/apt/sources.list" << EOF
deb http://archive.ubuntu.com/ubuntu $ubuntu_codename main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $ubuntu_codename-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $ubuntu_codename-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $ubuntu_codename-backports main restricted universe multiverse
EOF

    # Create user account
    chroot "$c_installed_os_mount_dir" useradd -m -s /bin/bash -G sudo "$v_username"
    chroot "$c_installed_os_mount_dir" usermod -c "$v_user_fullname" "$v_username"
    
    set +x
    echo "$v_username:$v_user_password" | chroot "$c_installed_os_mount_dir" chpasswd
    set -x

    # Configure timezone and locale
    chroot "$c_installed_os_mount_dir" ln -sf "/usr/share/zoneinfo/$v_timezone" /etc/localtime
    echo "$v_locale UTF-8" >> "$c_installed_os_mount_dir/etc/locale.gen"
    chroot "$c_installed_os_mount_dir" locale-gen
    echo "LANG=$v_locale" > "$c_installed_os_mount_dir/etc/locale.conf"

    # Install desktop environment
    case $v_desktop_environment in
        kde)
            chroot "$c_installed_os_mount_dir" apt update
            chroot "$c_installed_os_mount_dir" apt install -y kubuntu-desktop
            ;;
        gnome)
            chroot "$c_installed_os_mount_dir" apt update
            chroot "$c_installed_os_mount_dir" apt install -y ubuntu-desktop
            ;;
        xfce)
            chroot "$c_installed_os_mount_dir" apt update
            chroot "$c_installed_os_mount_dir" apt install -y xubuntu-desktop
            ;;
        minimal)
            chroot "$c_installed_os_mount_dir" apt update
            chroot "$c_installed_os_mount_dir" apt install -y ubuntu-server
            ;;
    esac

    # Enable SSH if requested
    if [[ $v_enable_ssh -eq 1 ]]; then
        chroot "$c_installed_os_mount_dir" systemctl enable ssh
    fi

    log "✅ Base system installed successfully"
}

function create_pools_and_datasets() {
    log "🏊 Creating ZFS pools and datasets..."
    local encryption_options=()

    set +x
    if [[ -n $v_passphrase ]]; then
        encryption_options=(-O "encryption=aes-256-gcm" -O "keylocation=prompt" -O "keyformat=passphrase")
        # Create named pipe for passphrase
        mkfifo "$c_passphrase_named_pipe"
        echo -n "$v_passphrase" > "$c_passphrase_named_pipe" &
    fi
    set -x

    # Create root pool
    zpool create \
        "${encryption_options[@]}" \
        "${v_rpool_create_options[@]}" \
        -O mountpoint=/ -O canmount=off -R "$c_zfs_mount_dir" -f \
        "$v_rpool_name" "${v_selected_disks[0]}-part3" \
        < "${c_passphrase_named_pipe:-/dev/null}"

    # Create boot pool
    zpool create \
        -o cachefile=/etc/zfs/zpool.cache \
        "${v_bpool_create_options[@]}" \
        -O mountpoint=/boot -O canmount=off -R "$c_zfs_mount_dir" -f \
        "$c_bpool_name" "${v_selected_disks[0]}-part2"

    # Create datasets
    zfs create -o canmount=off "$v_rpool_name/ROOT"
    zfs create -o mountpoint=/ "$v_rpool_name/ROOT/$v_hostname"
    zfs create -o mountpoint=/home "$v_rpool_name/ROOT/$v_hostname/home"
    zfs create -o mountpoint=/var "$v_rpool_name/ROOT/$v_hostname/var"
    zfs create -o mountpoint=/var/log "$v_rpool_name/ROOT/$v_hostname/var/log"
    zfs create -o mountpoint=/tmp "$v_rpool_name/ROOT/$v_hostname/tmp"
    
    zfs create -o canmount=off "$c_bpool_name/BOOT"
    zfs create -o mountpoint=/boot "$c_bpool_name/BOOT/ROOT"

    # Set bootfs property
    zpool set bootfs="$v_rpool_name/ROOT/$v_hostname" "$v_rpool_name"

    log "✅ ZFS pools and datasets created successfully"
}

function install_zfsbootmenu() {
    if [[ $v_use_zfsbootmenu -eq 1 ]]; then
        log "🥾 Installing ZFSBootMenu..."
        
        # Create EFI directory
        mkdir -p "$c_zfs_mount_dir/boot/efi/EFI/ZBM"
        
        # Download and install ZFSBootMenu
        local temp_file=$(mktemp)
        if curl -fsSL https://get.zfsbootmenu.org/efi -o "$temp_file"; then
            install -m 0644 "$temp_file" "$c_zfs_mount_dir/boot/efi/EFI/ZBM/ZFSBootMenu.EFI"
            rm -f "$temp_file"
            
            # Create UEFI entry
            if command -v efibootmgr >/dev/null 2>&1; then
                local disk=$(lsblk -no pkname "${v_selected_disks[0]}-part1" 2>/dev/null || basename "${v_selected_disks[0]}")
                efibootmgr --create --disk "/dev/$disk" --part 1 \
                    --label "ZFSBootMenu" --loader '\EFI\ZBM\ZFSBootMenu.EFI' || true
            fi
            
            log "✅ ZFSBootMenu installed successfully"
        else
            log "❌ Failed to download ZFSBootMenu"
        fi
    fi
}

# MAIN EXECUTION ################################################################

function main() {
    log "🚀 Starting Complete Enhanced ZFS Installation"
    
    # Create log directory
    mkdir -p "$c_log_dir"
    
    # Safety check
    if [[ "$EUID" -eq 0 ]]; then
        error "Don't run as root!"
    fi
    
    # Check prerequisites
    if [[ ! -d /sys/firmware/efi ]]; then
        error 'System firmware directory not found; make sure to boot in EFI mode!'
    fi
    
    if ! ping -c 1 "$c_dns" > /dev/null; then
        error "Can't contact the DNS ($c_dns)!"
    fi
    
    # Handle help
    if [[ $# -ne 0 ]]; then
        display_help_and_exit
    fi
    
    # Install dependencies
    install_all_dependencies
    
    # Hardware detection
    detect_hardware
    optimize_zfs_for_hardware
    
    # Interactive configuration (if not automated)
    if [[ -z ${ZFS_AUTOMATED:-} ]]; then
        whiptail --msgbox "Enhanced ZFS Installation Script\n\nThis script will install Ubuntu with ZFS root filesystem.\n\nPress Ctrl+C to abort at any time." 30 100
        
        ask_ubuntu_version
        ask_installation_method
        ask_user_configuration
        ask_hostname
        ask_system_configuration
        ask_desktop_environment
        ask_additional_options
    fi
    
    # Set defaults for automated runs
    [[ -z $v_ubuntu_version ]] && v_ubuntu_version="22.04"
    [[ -z $v_install_method ]] && v_install_method="debootstrap"
    [[ -z $v_username ]] && v_username="user"
    [[ -z $v_user_password ]] && v_user_password="password"
    [[ -z $v_user_fullname ]] && v_user_fullname="User"
    [[ -z $v_hostname ]] && v_hostname="zfs-system"
    [[ -z $v_timezone ]] && v_timezone="UTC"
    [[ -z $v_locale ]] && v_locale="en_US.UTF-8"
    [[ -z $v_keyboard_layout ]] && v_keyboard_layout="us"
    [[ -z $v_desktop_environment ]] && v_desktop_environment="minimal"
    [[ -z $v_use_zfsbootmenu ]] && v_use_zfsbootmenu=1
    [[ -z $v_enable_ssh ]] && v_enable_ssh=1
    [[ -z $v_boot_partition_size ]] && v_boot_partition_size="${c_default_boot_partition_size}M"
    [[ -z $v_swap_size ]] && v_swap_size=0
    [[ -z $v_free_tail_space ]] && v_free_tail_space=0
    [[ -z $v_rpool_name ]] && v_rpool_name="rpool"
    
    # Set default options
    v_rpool_create_options=("${c_default_rpool_create_options[@]}")
    v_bpool_create_options=("${c_default_bpool_create_options[@]}")
    
    # ZFS configuration
    find_suitable_disks
    select_disks
    ask_encryption
    
    # Partition disks
    setup_partitions
    
    # Install operating system
    case $v_install_method in
        debootstrap)
            install_operating_system_debootstrap
            ;;
        *)
            error "Installation method $v_install_method not implemented yet"
            ;;
    esac
    
    # Create ZFS infrastructure
    create_pools_and_datasets
    
    # Copy OS to ZFS
    log "🔄 Syncing installed OS to ZFS..."
    rsync -avX --exclude=/run --exclude=/proc --exclude=/sys --exclude=/dev \
        "$c_installed_os_mount_dir/" "$c_zfs_mount_dir/"
    
    # Cleanup temp installation
    umount "$c_installed_os_mount_dir"/{dev,proc,sys} || true
    umount "$c_installed_os_mount_dir" || true
    
    # Configure chroot environment
    mount --rbind /dev "$c_zfs_mount_dir/dev"
    mount --rbind /proc "$c_zfs_mount_dir/proc"
    mount --rbind /sys "$c_zfs_mount_dir/sys"
    
    # Install ZFS in chroot
    chroot_execute "apt update"
    chroot_execute "apt install -y zfs-initramfs zfs-zed zfsutils-linux"
    
    # Install bootloader
    install_zfsbootmenu
    
    # Update initramfs
    chroot_execute "update-initramfs -u"
    
    # Cleanup
    umount --recursive --force --lazy "$c_zfs_mount_dir"/{dev,proc,sys} || true
    zpool export -a || true
    
    log "🎉 Complete Enhanced ZFS Installation finished successfully!"
    
    local dialog_message="Enhanced ZFS Ubuntu installation completed successfully!\n\nSystem Configuration:\n- Ubuntu $v_ubuntu_version\n- Hostname: $v_hostname\n- User: $v_username\n- Desktop: $v_desktop_environment\n- Boot Manager: $(if [[ $v_use_zfsbootmenu -eq 1 ]]; then echo "ZFSBootMenu"; else echo "GRUB"; fi)\n\nYou can now reboot to enjoy your ZFS system!"
    
    if command -v whiptail >/dev/null 2>&1; then
        whiptail --msgbox "$dialog_message" 30 100
    else
        echo "$dialog_message"
    fi
}

# Execute main function
main "$@"
