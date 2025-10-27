#!/bin/bash

# Enhanced ZFS Installation Script with custom configuration options
# Based on the original zfsinstall.sh with added features for:
# - Ubuntu version selection
# - User account configuration  
# - Hostname configuration
# - Timeshift integration
# - ZFSBootMenu support

# shellcheck disable=SC2016 # single quoted strings with characters used for interpolation

set -o errexit
set -o pipefail
set -o nounset

# VARIABLES/CONSTANTS ##########################################################

# Enhanced variables for custom installation
v_ubuntu_version=               # Ubuntu version to install (20.04, 22.04, 24.04, etc.)
v_install_method=               # debootstrap, iso, timeshift_restore
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

# Constants
c_hotswap_file=$PWD/install-zfs.hotswap.sh

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

# Enhanced dataset options for better ZFS layout
c_default_dataset_create_options='
ROOT                           mountpoint=/ com.ubuntu.zsys:bootfs=yes com.ubuntu.zsys:last-used=$(date +%s)
ROOT/srv                       com.ubuntu.zsys:bootfs=no
ROOT/usr                       canmount=off com.ubuntu.zsys:bootfs=no
ROOT/usr/local
ROOT/var                       canmount=off com.ubuntu.zsys:bootfs=no
ROOT/var/games
ROOT/var/lib
ROOT/var/lib/AccountsService
ROOT/var/lib/apt
ROOT/var/lib/dpkg
ROOT/var/lib/NetworkManager
ROOT/var/log
ROOT/var/mail
ROOT/var/snap
ROOT/var/spool
ROOT/var/www
ROOT/tmp                       com.ubuntu.zsys:bootfs=no

USERDATA                       mountpoint=/ canmount=off
USERDATA/root                  mountpoint=/root canmount=on com.ubuntu.zsys:bootfs-datasets=$v_rpool_name/ROOT
USERDATA/$v_username           mountpoint=/home/$v_username canmount=on com.ubuntu.zsys:bootfs-datasets=$v_rpool_name/ROOT
'

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

function invoke {
  local base_fx_name=$1
  local distro_specific_fx_name=$1_$v_linux_distribution
  local invoke_option=${2:-}

  if [[ ! $invoke_option =~ ^(|--optional)$ ]]; then
    >&2 echo "Invalid invoke() option: $invoke_option"
    exit 1
  fi

  hot_swap_script

  if declare -f "$distro_specific_fx_name" > /dev/null; then
    print_step_info_header "$distro_specific_fx_name"
    "$distro_specific_fx_name"
  elif declare -f "$base_fx_name" > /dev/null || [[ ! $invoke_option == "--optional" ]]; then
    print_step_info_header "$base_fx_name"
    "$base_fx_name"
  fi
}

function hot_swap_script {
  if [[ -f $c_hotswap_file ]]; then
    # shellcheck disable=1090
    source "$c_hotswap_file"
  fi
}

function print_step_info_header {
  local function_name=$1

  echo -n "
###############################################################################
# $function_name
###############################################################################
"
}

function print_variables {
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

function checked_add_apt_repository {
  local repository=$1
  local option=${2:-}

  local add_repo_command=(add-apt-repository --yes "$repository")

  if add-apt-repository --help | grep -q "\\--no-update"; then
    add_repo_command+=(--no-update)
  fi

  case $option in
  '')
    "${add_repo_command[@]}"
    ;;
  --chroot)
    chroot_execute "${add_repo_command[*]}"
    ;;
  *)
    >&2 echo "Unexpected checked_add_apt_repository option: $2"
    exit 1
  esac
}

function compose_pool_create_vdev_options {
  case $1 in
  rpool)
    local partition_suffix=-part3;;
  bpool)
    local partition_suffix=-part2;;
  -)
    local partition_suffix=;;
  *)
    >&2 echo "Wrong compose_pool_create_vdev_options() parameter: \`$1\`"
    exit 1
  esac

  local result=

  for device_indexes in "${!v_vdev_configs[@]}"; do
    local vdev_type=${v_vdev_configs[$device_indexes]}

    if [[ -z $vdev_type ]]; then
      mapfile -d, -t device_indexes < <(echo -n "$device_indexes")

      for device_index in "${device_indexes[@]}"; do
        result+=" ${v_selected_disks[$device_index]}$partition_suffix"
      done
    fi
  done

  for device_indexes in "${!v_vdev_configs[@]}"; do
    local vdev_type=${v_vdev_configs[$device_indexes]}

    if [[ -n $vdev_type ]]; then
      result+=" $vdev_type"

      mapfile -d, -t device_indexes < <(echo -n "$device_indexes")

      for device_index in "${device_indexes[@]}"; do
        result+=" ${v_selected_disks[$device_index]}$partition_suffix"
      done
    fi
  done

  echo -n "$result" | sed -e 's/^ //'
}

function chroot_execute {
  chroot $c_zfs_mount_dir bash -c "$1"
}

# NEW ENHANCED FUNCTIONS #######################################################

function display_help_and_exit {
  local help
  help='Enhanced ZFS Ubuntu Installation Script

Usage: zfsinstall-enhanced.sh [-h|--help]

This enhanced script provides additional customization options:

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
- ZFS_INSTALL_TIMESHIFT     : Install Timeshift (1=yes, 0=no)
- ZFS_USE_ZFSBOOTMENU       : Use ZFSBootMenu instead of GRUB (1=yes, 0=no)
- ZFS_ENABLE_SSH            : Enable SSH server (1=yes, 0=no)

Original ZFS Variables (see original script help for details):
- ZFS_SELECTED_DISKS, ZFS_PASSPHRASE, ZFS_RPOOL_NAME, etc.

New Features:
- Timeshift backup restoration from: '"$v_timeshift_backup_path"'
- ZFSBootMenu integration for advanced ZFS boot management
- Automated Ubuntu installation via debootstrap
- Custom user account and system configuration
'

  echo "$help"
  exit 0
}

function ask_ubuntu_version {
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

function ask_installation_method {
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

function ask_user_configuration {
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

function ask_hostname {
  if [[ -n ${ZFS_HOSTNAME:-} ]]; then
    v_hostname=$ZFS_HOSTNAME
  else
    while [[ ! $v_hostname =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$ || -z $v_hostname ]]; do
      v_hostname=$(whiptail --inputbox "Enter system hostname:" 30 100 "zfs-system" 3>&1 1>&2 2>&3)
    done
  fi

  print_variables v_hostname
}

function ask_system_configuration {
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

function ask_desktop_environment {
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

function ask_additional_options {
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

function install_operating_system_debootstrap {
  local ubuntu_codename=${c_supported_ubuntu_versions[$v_ubuntu_version]}
  
  echo "Installing Ubuntu $v_ubuntu_version ($ubuntu_codename) via debootstrap..."

  # Install debootstrap if not available
  if ! command -v debootstrap &> /dev/null; then
    apt update
    apt install -y debootstrap
  fi

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

  # Clean up mounts
  umount "$c_installed_os_mount_dir"/{dev,proc,sys}
}

function install_operating_system_timeshift_restore {
  echo "Restoring from Timeshift backup..."

  if [[ ! -d "$v_timeshift_backup_path" ]]; then
    echo "Error: Timeshift backup path not found: $v_timeshift_backup_path"
    exit 1
  fi

  # Find the latest snapshot
  local latest_snapshot
  latest_snapshot=$(ls -1t "$v_timeshift_backup_path/snapshots/" | head -n1)

  if [[ -z $latest_snapshot ]]; then
    echo "Error: No Timeshift snapshots found"
    exit 1
  fi

  echo "Restoring from snapshot: $latest_snapshot"

  # Mount temporary volume
  mkfs.ext4 "$v_temp_volume_device"
  mkdir -p "$c_installed_os_mount_dir"
  mount "$v_temp_volume_device" "$c_installed_os_mount_dir"

  # Restore files from Timeshift backup
  rsync -avX --progress \
    "$v_timeshift_backup_path/snapshots/$latest_snapshot/localhost/" \
    "$c_installed_os_mount_dir/"

  # Update hostname if different
  if [[ -n $v_hostname ]]; then
    echo "$v_hostname" > "$c_installed_os_mount_dir/etc/hostname"
    sed -i "s/127\.0\.1\.1.*/127.0.1.1 $v_hostname/" "$c_installed_os_mount_dir/etc/hosts"
  fi

  umount "$c_installed_os_mount_dir"
}

function install_timeshift {
  if [[ $v_install_timeshift -eq 1 ]]; then
    echo "Installing and configuring Timeshift..."
    
    chroot_execute "apt update"
    chroot_execute "apt install -y timeshift"
    
    # Configure Timeshift for ZFS
    mkdir -p "$c_zfs_mount_dir/etc/timeshift"
    cat > "$c_zfs_mount_dir/etc/timeshift/timeshift.json" << EOF
{
  "backup_device_uuid" : "",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "false",
  "include_btrfs_home_for_backup" : "false",
  "include_btrfs_home_for_restore" : "false",
  "stop_cron_emails" : "true",
  "schedule_monthly" : "false",
  "schedule_weekly" : "false", 
  "schedule_daily" : "true",
  "schedule_hourly" : "false",
  "schedule_boot" : "false",
  "count_monthly" : "2",
  "count_weekly" : "3",
  "count_daily" : "5",
  "count_hourly" : "6",
  "count_boot" : "5",
  "snapshot_size" : "0",
  "snapshot_count" : "0",
  "date_format" : "%Y-%m-%d %H:%M:%S",
  "exclude" : [
    "/root/cache/**"
  ],
  "exclude_apps" : []
}
EOF
  fi
}

function install_zfsbootmenu {
  if [[ $v_use_zfsbootmenu -eq 1 ]]; then
    echo "Installing ZFSBootMenu..."
    
    # Install dependencies
    chroot_execute "apt update"
    chroot_execute "apt install -y curl gpg"
    
    # Add ZFSBootMenu repository
    chroot_execute "curl -L https://get.zfsbootmenu.org/ascii-armored-key | gpg --dearmor -o /etc/apt/trusted.gpg.d/zfsbootmenu.gpg"
    chroot_execute "echo 'deb https://zbm.dev/ubuntu focal main' > /etc/apt/sources.list.d/zfsbootmenu.list"
    chroot_execute "apt update"
    chroot_execute "apt install -y zfsbootmenu"
    
    # Configure ZFSBootMenu
    cat > "$c_zfs_mount_dir/etc/zfsbootmenu/config.yaml" << EOF
Global:
  ManageImages: true
  BootMountPoint: /boot/efi
Components:
  Enabled: false
EFI:
  ImageDir: /boot/efi/EFI/zbm
  Versions: 3
Kernel:
  CommandLine: ro quiet loglevel=0 zbm.import_policy=hostid zbm.set_hostid
EOF

    # Generate ZFSBootMenu images
    chroot_execute "generate-zbm"
    
    # Set up EFI boot entry
    for ((i = 0; i < ${#v_selected_disks[@]}; i++)); do
      efibootmgr --create --disk "${v_selected_disks[i]}" --label "ZFSBootMenu-$((i + 1))" --loader '\EFI\zbm\vmlinuz.efi'
    done
  fi
}

# MODIFIED ORIGINAL FUNCTIONS ##################################################

function activate_debug {
  mkdir -p "$c_log_dir"
  exec 5> "$c_install_log"
  BASH_XTRACEFD="5"
  set -x
}

function set_distribution_data {
  v_linux_distribution="Ubuntu"
  v_linux_version="$v_ubuntu_version"
}

function store_os_distro_information {
  echo "Ubuntu $v_ubuntu_version" > "$c_os_information_log"
  echo "DESKTOP_SESSION=${v_desktop_environment:-unknown}" >> "$c_os_information_log"
}

function store_running_processes {
  ps ax --forest > "$c_running_processes_log"
}

function check_prerequisites {
  if [[ ! -d /sys/firmware/efi ]]; then
    echo 'System firmware directory not found; make sure to boot in EFI mode!'
    exit 1
  elif [[ $(id -u) -ne 0 ]]; then
    echo 'This script must be run with administrative privileges!'
    exit 1
  elif ! ping -c 1 "$c_dns" > /dev/null; then
    echo "Can't contact the DNS ($c_dns)!"
    exit 1
  fi

  set +x
  if [[ -v ZFS_PASSPHRASE && -n $ZFS_PASSPHRASE && ${#ZFS_PASSPHRASE} -lt 8 ]]; then
    echo "The passphase provided is too short; at least 8 chars required."
    exit 1
  fi
  set -x
}

function display_intro_banner {
  local dialog_message='Enhanced ZFS Installation Script

This script will:
- Install Ubuntu with ZFS root filesystem
- Configure custom user accounts and system settings
- Optionally install Timeshift for system snapshots
- Optionally use ZFSBootMenu for advanced boot management

Press Ctrl+C to abort at any time.
'

  if [[ -z ${ZFS_NO_INFO_MESSAGES:-} ]]; then
    whiptail --msgbox "$dialog_message" 30 100
  fi
}

function check_system_memory {
    local system_memory
    system_memory=$(free -m | perl -lane 'print @F[1] if $. == 2')

    if [[ $system_memory -lt $c_memory_warning_limit && -z ${ZFS_NO_INFO_MESSAGES:-} ]]; then
      local dialog_message='WARNING! ZFS module compilation may fail on systems with limited RAM.

On systems with relatively little RAM and many CPU threads, the compilation may crash.

Consider adding swap or reducing CPU threads if compilation fails.'

      whiptail --msgbox "$dialog_message" 30 100
    fi
}

function save_disks_log {
  ls -l /dev/disk/by-id | tail -n +2 | perl -lane 'print "@F[8..10]"' > "$c_disks_log"

  all_disk_ids=$(find /dev/disk/by-id -mindepth 1 -regextype awk -not -regex '.+-part[0-9]+$' | sort)

  while read -r disk_id || [[ -n $disk_id ]]; do
    cat >> "$c_disks_log" << LOG

## DEVICE: $disk_id ################################

$(udevadm info --query=property "$(readlink -f "$disk_id")")

LOG
  done < <(echo -n "$all_disk_ids")
}

function find_suitable_disks {
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
    local dialog_message='No suitable disks have been found!

If you'\''re running inside a VMWare virtual machine, you need to add set `disk.EnableUUID = "TRUE"` in the .vmx configuration file.'

    whiptail --msgbox "$dialog_message" 30 100
    exit 1
  fi

  print_variables v_suitable_disks
}

function create_passphrase_named_pipe {
  mkfifo "$c_passphrase_named_pipe"
}

function register_exit_hook {
  function _exit_hook {
    rm -f "$c_passphrase_named_pipe"

    set +x
    echo "
Enhanced ZFS installation configuration for unattended installation:

export ZFS_UBUNTU_VERSION=$v_ubuntu_version
export ZFS_INSTALL_METHOD=$v_install_method
export ZFS_USERNAME=$(printf %q "$v_username")
export ZFS_USER_PASSWORD=$(printf %q "$v_user_password")
export ZFS_USER_FULLNAME=$(printf %q "$v_user_fullname")
export ZFS_HOSTNAME=$(printf %q "$v_hostname")
export ZFS_TIMEZONE=$(printf %q "$v_timezone")
export ZFS_LOCALE=$(printf %q "$v_locale")
export ZFS_KEYBOARD_LAYOUT=$(printf %q "$v_keyboard_layout")
export ZFS_DESKTOP_ENVIRONMENT=$v_desktop_environment
export ZFS_USE_ZFSBOOTMENU=$v_use_zfsbootmenu
export ZFS_ENABLE_SSH=$v_enable_ssh
export ZFS_SELECTED_DISKS=$(IFS=,; echo -n "${v_selected_disks[*]}")
export ZFS_VDEV_CONFIGS='$(declare -p v_vdev_configs | perl -pe 's/.*?\((.+)\)/\1/')'
export ZFS_BOOT_PARTITION_SIZE=$v_boot_partition_size
export ZFS_PASSPHRASE=$(printf %q "$v_passphrase")
export ZFS_RPOOL_NAME=$v_rpool_name
export ZFS_SWAP_SIZE=$v_swap_size
export ZFS_FREE_TAIL_SPACE=$v_free_tail_space"

    set -x
  }
  trap _exit_hook EXIT
}

function prepare_standard_repositories {
  checked_add_apt_repository universe
}

function update_apt_index {
  apt update
}

function set_use_zfs_ppa {
  local zfs_package_version
  zfs_package_version=$(apt show zfsutils-linux 2> /dev/null | perl -ne 'print /^Version: (\d+\.\d+)/')

  if [[ ${ZFS_USE_PPA:-} == "1" ]] || dpkg --compare-versions "$zfs_package_version" lt 0.8; then
    v_use_ppa=1
  fi
}

function install_host_base_packages {
  apt install -y efibootmgr dialog software-properties-common
}

function select_disks {
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
        menu_entries_option+=("$disk_id ($block_device_basename) $disk_selection_status")
      done

      # shellcheck disable=2207
      menu_entries_option=($(printf '%s\n' "${menu_entries_option[@]}" | sort -k 2))

      local dialog_message="Select the ZFS devices.

Devices with mounted partitions, cdroms, and removable devices are not displayed!
"
      mapfile -t v_selected_disks < <(whiptail --checklist --separate-output "$dialog_message" 30 100 $((${#menu_entries_option[@]} / 3)) "${menu_entries_option[@]}" 3>&1 1>&2 2>&3)

      if [[ ${#v_selected_disks[@]} -gt 0 ]]; then
        break
      fi
    done
  fi

  print_variables v_selected_disks
}

function select_vdev_configs {
  if [[ -n ${ZFS_VDEV_CONFIGS:-} ]]; then
    eval declare -gA v_vdev_configs=\("$ZFS_VDEV_CONFIGS"\)
  elif [[ ${#v_selected_disks[@]} -eq 1 ]]; then
    v_vdev_configs[0]=
  else
    while true; do
      local all_vdev_disks_count
      all_vdev_disks_count=$(echo "${!v_vdev_configs[@]}" | perl -pe 's/[, ]/\n/g' | wc -l)

      if [[ $all_vdev_disks_count -eq ${#v_selected_disks[@]} ]]; then
        break
      fi

      local current_setup
      current_setup=$(compose_pool_create_vdev_options -)

      local dialog_message
      dialog_message="Choose the disk group type.

Current pool creation setup: ${current_setup:-(none)}"

      local vdev_types_option=(
        ""       Striping  OFF
        mirror   Mirroring OFF
        raidz    RAIDZ1    OFF
        raidz2   RAIDZ2    OFF
        raidz3   RAIDZ3    OFF
      )

      local current_vdev_type
      current_vdev_type=$(whiptail --radiolist "$dialog_message" 30 100 $((${#vdev_types_option[@]} / 3)) "${vdev_types_option[@]}" 3>&1 1>&2 2>&3)

      local dialog_message="Choose the disks for the current disk group."

      local current_vdev_disks_option=()

      for (( i = 0; i < ${#v_selected_disks[@]}; i++ )); do
        if ! echo "${!v_vdev_configs[@]}" | perl -pe 's/[, ]/\n/g' | grep "^$i$"; then
          local disk_basename
          disk_basename=$(basename "${v_selected_disks[i]}")
          current_vdev_disks_option+=("$i" "$disk_basename" OFF)
        fi
      done

      local current_vdev_indexes
      current_vdev_indexes=$(whiptail --checklist --separate-output "$dialog_message" 30 100 $((${#current_vdev_disks_option[@]} / 3)) "${current_vdev_disks_option[@]}" 3>&1 1>&2 2>&3)

      if [[ -n $current_vdev_indexes ]]; then
        current_vdev_indexes=${current_vdev_indexes//$'\n'/,}
        current_vdev_indexes=${current_vdev_indexes%,}
        v_vdev_configs[$current_vdev_indexes]=$current_vdev_type
      fi
    done
  fi
}

function ask_encryption {
  set +x

  if [[ -v ZFS_PASSPHRASE ]]; then
    v_passphrase=$ZFS_PASSPHRASE
  else
    local passphrase_repeat=_
    local passphrase_invalid_message=

    while [[ $v_passphrase != "$passphrase_repeat" || ${#v_passphrase} -lt 8 ]]; do
      local dialog_message="${passphrase_invalid_message}Please enter the passphrase (8 chars min.):

Leave blank to keep encryption disabled.
"

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

function ask_boot_partition_size {
  if [[ -n ${ZFS_BOOT_PARTITION_SIZE:-} ]]; then
    v_boot_partition_size=$ZFS_BOOT_PARTITION_SIZE
  else
   local boot_partition_size_invalid_message=

    while [[ ! $v_boot_partition_size =~ ^[0-9]+[MGmg]$ ]]; do
      v_boot_partition_size=$(whiptail --inputbox "${boot_partition_size_invalid_message}Enter the boot partition size.

Supported formats: '512M', '3G'" 30 100 ${c_default_boot_partition_size}M 3>&1 1>&2 2>&3)

      boot_partition_size_invalid_message="Invalid boot partition size! "
    done
  fi

  print_variables v_boot_partition_size
}

function ask_swap_size {
  if [[ -n ${ZFS_SWAP_SIZE:-} ]]; then
    v_swap_size=$ZFS_SWAP_SIZE
  else
   local swap_size_invalid_message=

    while [[ ! $v_swap_size =~ ^[0-9]+$ ]]; do
      v_swap_size=$(whiptail --inputbox "${swap_size_invalid_message}Enter the swap size in GiB (0 for no swap):" 30 100 2 3>&1 1>&2 2>&3)

      swap_size_invalid_message="Invalid swap size! "
    done
  fi

  print_variables v_swap_size
}

function ask_free_tail_space {
  if [[ -n ${ZFS_FREE_TAIL_SPACE:-} ]]; then
    v_free_tail_space=$ZFS_FREE_TAIL_SPACE
  else
    local tail_space_invalid_message=
    local tail_space_message="${tail_space_invalid_message}Enter the space in GiB to leave at the end of each disk (0 for none)."

    while [[ ! $v_free_tail_space =~ ^[0-9]+$ ]]; do
      v_free_tail_space=$(whiptail --inputbox "$tail_space_message" 30 100 0 3>&1 1>&2 2>&3)

      tail_space_invalid_message="Invalid size! "
    done
  fi

  print_variables v_free_tail_space
}

function ask_rpool_name {
  if [[ -n ${ZFS_RPOOL_NAME:-} ]]; then
    v_rpool_name=$ZFS_RPOOL_NAME
  else
    local rpool_name_invalid_message=

    while [[ ! $v_rpool_name =~ ^[a-z][a-zA-Z_:.-]+$ ]]; do
      v_rpool_name=$(whiptail --inputbox "${rpool_name_invalid_message}Insert the name for the root pool" 30 100 rpool 3>&1 1>&2 2>&3)

      rpool_name_invalid_message="Invalid pool name! "
    done
  fi

  print_variables v_rpool_name
}

function ask_pool_create_options {
  local bpool_create_options_message='Insert the create options for the boot pool

The mount-related options are automatically added, and must not be specified.'

  local raw_bpool_create_options=${ZFS_BPOOL_CREATE_OPTIONS:-$(whiptail --inputbox "$bpool_create_options_message" 30 100 -- "${c_default_bpool_create_options[*]}" 3>&1 1>&2 2>&3)}

  mapfile -d' ' -t v_bpool_create_options < <(echo -n "$raw_bpool_create_options")

  local rpool_create_options_message='Insert the create options for the root pool

The encryption/mount-related options are automatically added, and must not be specified.'

  local raw_rpool_create_options=${ZFS_RPOOL_CREATE_OPTIONS:-$(whiptail --inputbox "$rpool_create_options_message" 30 100 -- "${c_default_rpool_create_options[*]}" 3>&1 1>&2 2>&3)}

  mapfile -d' ' -t v_rpool_create_options < <(echo -n "$raw_rpool_create_options")

  print_variables v_bpool_create_options v_rpool_create_options
}

function ask_dataset_create_options {
  if [[ -n ${ZFS_DATASET_CREATE_OPTIONS:-} ]]; then
    v_dataset_create_options=$ZFS_DATASET_CREATE_OPTIONS
  else
    # Use the enhanced default with username
    v_dataset_create_options=$c_default_dataset_create_options
  fi

  print_variables v_dataset_create_options
}

function install_host_zfs_packages {
  if [[ $v_use_ppa == "1" ]]; then
    if [[ ${ZFS_SKIP_LIVE_ZFS_MODULE_INSTALL:-} != "1" ]]; then
      checked_add_apt_repository "$c_ppa"
      apt update

      echo "zfs-dkms zfs-dkms/note-incompatible-licenses note true" | debconf-set-selections
      apt install --yes libelf-dev zfs-dkms

      systemctl stop zfs-zed
      modprobe -r zfs
      modprobe zfs
      systemctl start zfs-zed
    fi
  fi

  apt install --yes zfsutils-linux

  zfs --version > "$c_zfs_module_version_log" 2>&1
}

function setup_partitions {
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
}

function install_operating_system {
  case $v_install_method in
    debootstrap)
      install_operating_system_debootstrap
      ;;
    timeshift_restore)
      install_operating_system_timeshift_restore
      ;;
    *)
      echo "Unknown installation method: $v_install_method"
      exit 1
      ;;
  esac
}

function create_pools_and_datasets {
  local encryption_options=()

  set +x
  if [[ -n $v_passphrase ]]; then
    encryption_options=(-O "encryption=aes-256-gcm" -O "keylocation=prompt" -O "keyformat=passphrase")
  fi
  set -x

  set +x
  echo -n "$v_passphrase" > "$c_passphrase_named_pipe" &
  set -x

  mapfile -d' ' -t rpool_create_vdev_options < <(compose_pool_create_vdev_options rpool)

  zpool create \
    "${encryption_options[@]}" \
    "${v_rpool_create_options[@]}" \
    -O mountpoint=/ -O canmount=off -R "$c_zfs_mount_dir" -f \
    "$v_rpool_name" "${rpool_create_vdev_options[@]}" \
    < "$c_passphrase_named_pipe"

  local interpolated_dataset_create_options
  interpolated_dataset_create_options=$(eval echo \""$v_dataset_create_options"\")

  echo "Interpolated dataset create options:"
  echo "$interpolated_dataset_create_options"
  echo

  while read -r dataset_metadata_line || [[ -n $dataset_metadata_line ]]; do
    if [[ $dataset_metadata_line =~ [^[:space:]] ]]; then
      local dataset_metadata_entries
      # shellcheck disable=2206
      dataset_metadata_entries=($dataset_metadata_line)

      local dataset=$v_rpool_name/${dataset_metadata_entries[0]}
      local options=("${dataset_metadata_entries[@]:1}")

      # shellcheck disable=2068
      zfs create ${options[@]/#/-o } "$dataset"
    fi
  done < <(echo "$interpolated_dataset_create_options")

  mapfile -d' ' -t bpool_create_vdev_options < <(compose_pool_create_vdev_options bpool)

  zpool create \
    -o cachefile=/etc/zfs/zpool.cache \
    "${v_bpool_create_options[@]}" \
    -O mountpoint=/boot -O canmount=off -R "$c_zfs_mount_dir" -f \
    "$c_bpool_name" "${bpool_create_vdev_options[@]}"

  zfs create -o canmount=off "$c_bpool_name/BOOT"
  zfs create -o mountpoint=/boot "$c_bpool_name/BOOT/ROOT"
}

function create_swap_volume {
  if [[ $v_swap_size -gt 0 ]]; then
    zfs create \
      -V "${v_swap_size}G" -b "$(getconf PAGESIZE)" \
      -o compression=zle -o logbias=throughput -o sync=always -o primarycache=metadata -o secondarycache=none -o com.sun:auto-snapshot=false \
      "$v_rpool_name/swap"

    mkswap -f "/dev/zvol/$v_rpool_name/swap"
  fi
}

function copy_zpool_cache {
  mkdir -p "$c_zfs_mount_dir/etc/zfs"
  cp /etc/zfs/zpool.cache "$c_zfs_mount_dir/etc/zfs/"
}

function sync_os_temp_installation_dir_to_rpool {
  local mount_dir_submounts
  mount_dir_submounts=$(mount | MOUNT_DIR="${c_installed_os_mount_dir%/}" perl -lane 'print $F[2] if $F[2] =~ /$ENV{MOUNT_DIR}\//')

  for mount_dir in $mount_dir_submounts; do
    umount "$mount_dir"
  done

  rsync -avX --exclude=/run --info=progress2 --no-inc-recursive --human-readable "$c_installed_os_mount_dir/" "$c_zfs_mount_dir" |
    perl -lane 'BEGIN { $/ = "\r"; $|++ } $F[1] =~ /(\d+)%$/ && print $1' |
    whiptail --gauge "Syncing the installed O/S to the root pool FS..." 30 100 0

  mkdir -p "$c_installed_os_mount_dir/run/systemd/resolve"
  touch "$c_installed_os_mount_dir/run/systemd/resolve/stub-resolv.conf"

  mkdir "$c_zfs_mount_dir/run"
  rsync -av --relative "$c_installed_os_mount_dir/run/./systemd/resolve" "$c_zfs_mount_dir/run"

  umount "$c_installed_os_mount_dir"
}

function remove_temp_partition_and_expand_rpool {
  if (( v_free_tail_space < c_temporary_volume_size )); then
    if [[ $v_free_tail_space -eq 0 ]]; then
      local resize_reference=100%
    else
      local resize_reference=-${v_free_tail_space}G
    fi

    zpool export -a

    for selected_disk in "${v_selected_disks[@]}"; do
      parted -s "$selected_disk" rm 4
      parted -s "$selected_disk" unit s resizepart 3 -- "$resize_reference"
    done

    set +x
    echo -n "$v_passphrase" > "$c_passphrase_named_pipe" &
    set -x

    zpool import -l -R "$c_zfs_mount_dir" "$v_rpool_name" < "$c_passphrase_named_pipe"
    zpool import -l -R "$c_zfs_mount_dir" "$c_bpool_name"

    for selected_disk in "${v_selected_disks[@]}"; do
      zpool online -e "$v_rpool_name" "$selected_disk-part3"
    done
  else
    for selected_disk in "${v_selected_disks[@]}"; do
      wipefs --all "$selected_disk-part4"
    done
  fi
}

function prepare_jail {
  for virtual_fs_dir in proc sys dev; do
    mount --rbind "/$virtual_fs_dir" "$c_zfs_mount_dir/$virtual_fs_dir"
  done

  chroot_execute "echo 'nameserver $c_dns' >> /etc/resolv.conf"
}

function install_jail_base_packages {
  if [[ $v_use_zfsbootmenu -eq 1 ]]; then
    chroot_execute "apt install --yes rsync software-properties-common"
  else
    chroot_execute "apt install --yes rsync grub-efi-amd64-signed shim-signed software-properties-common"
  fi
}

function install_jail_zfs_packages {
  if [[ $v_use_ppa == "1" ]]; then
    checked_add_apt_repository "$c_ppa" --chroot

    chroot_execute "apt update"

    chroot_execute 'echo "zfs-dkms zfs-dkms/note-incompatible-licenses note true" | debconf-set-selections'

    chroot_execute "apt install --yes libelf-dev zfs-initramfs zfs-dkms"
  else
    chroot_execute "apt install --yes zfs-initramfs zfs-zed zfsutils-linux"
  fi
}

function prepare_fstab {
  chroot_execute "true > /etc/fstab"

  for ((i = 0; i < ${#v_selected_disks[@]}; i++)); do
    if (( i == 0 )); then
      local mountpoint=/boot/efi
    else
      local mountpoint=/boot/efi$((i + 1))
    fi

    chroot_execute "echo /dev/disk/by-uuid/$(blkid -s UUID -o value "${v_selected_disks[i]}"-part1) $mountpoint vfat nofail,x-systemd.requires=zfs-mount.service,x-systemd.device-timeout=10 0 0 >> /etc/fstab"
  done

  if (( v_swap_size > 0 )); then
    chroot_execute "echo /dev/zvol/$v_rpool_name/swap none swap discard 0 0 >> /etc/fstab"
  fi
}

function prepare_efi_partition {
  if [[ $v_use_zfsbootmenu -eq 1 ]]; then
    chroot_execute "mkdir -p /boot/efi"
    chroot_execute "mount /boot/efi"
  else
    chroot_execute "mkdir -p /boot/efi"
    chroot_execute "mount /boot/efi"
    chroot_execute "grub-install"
  fi
}

function configure_and_update_grub {
  if [[ $v_use_zfsbootmenu -eq 0 ]]; then
    chroot_execute "perl -i -pe 's/GRUB_CMDLINE_LINUX_DEFAULT=\"\\K/init_on_alloc=0 /'        /etc/default/grub"
    chroot_execute "echo 'GRUB_DISABLE_OS_PROBER=true'                                    >> /etc/default/grub"
    chroot_execute "perl -i -pe 's/(GRUB_TIMEOUT_STYLE=hidden)/#\\$1/'                        /etc/default/grub"
    chroot_execute "perl -i -pe 's/^(GRUB_HIDDEN_.*)/#\\$1/'                                  /etc/default/grub"
    chroot_execute "perl -i -pe 's/GRUB_TIMEOUT=\\K0/5/'                                      /etc/default/grub"
    chroot_execute "perl -i -pe 's/GRUB_CMDLINE_LINUX_DEFAULT=.*\\Kquiet//'                   /etc/default/grub"
    chroot_execute "perl -i -pe 's/GRUB_CMDLINE_LINUX_DEFAULT=.*\\Ksplash//'                  /etc/default/grub"
    chroot_execute "perl -i -pe 's/#(GRUB_TERMINAL=console)/\\$1/'                            /etc/default/grub"
    chroot_execute 'echo "GRUB_RECORDFAIL_TIMEOUT=5"                                      >> /etc/default/grub'
    chroot_execute "update-grub"
  fi
}

function sync_efi_partitions {
  if [[ $v_use_zfsbootmenu -eq 0 ]]; then
    for ((i = 1; i < ${#v_selected_disks[@]}; i++)); do
      local synced_efi_partition_path="/boot/efi$((i + 1))"

      chroot_execute "mkdir -p $synced_efi_partition_path"
      chroot_execute "mount $synced_efi_partition_path"

      chroot_execute "rsync --archive --delete --verbose /boot/efi/ $synced_efi_partition_path"

      efibootmgr --create --disk "${v_selected_disks[i]}" --label "ubuntu-$((i + 1))" --loader '\EFI\ubuntu\grubx64.efi'

      chroot_execute "umount $synced_efi_partition_path"
    done
  fi

  chroot_execute "umount /boot/efi"
}

function update_initramfs {
  chroot_execute "update-initramfs -u"
}

function fix_filesystem_mount_ordering {
  chroot_execute "mkdir /etc/zfs/zfs-list.cache"
  chroot_execute "touch /etc/zfs/zfs-list.cache/$c_bpool_name /etc/zfs/zfs-list.cache/$v_rpool_name"

  chroot_execute "if [[ ! -f /etc/zfs/zed.d/history_event-zfs-list-cacher.sh ]]; then ln -s /usr/lib/zfs-linux/zed.d/history_event-zfs-list-cacher.sh /etc/zfs/zed.d/; fi"

  chroot_execute "mkdir /run/lock"

  chroot_execute "zed -F &"

  local success=

  if [[ ! -s $c_zfs_mount_dir/etc/zfs/zfs-list.cache/$c_bpool_name || ! -s $c_zfs_mount_dir/etc/zfs/zfs-list.cache/$v_rpool_name ]]; then
    local zfs_root_fs zfs_boot_fs

    zfs_root_fs=$(chroot_execute 'zfs list /     | awk "NR==2 {print \$1}"')
    zfs_boot_fs=$(chroot_execute 'zfs list /boot | awk "NR==2 {print \$1}"')

    chroot_execute "zfs set canmount=on $zfs_boot_fs"
    chroot_execute "zfs set canmount=on $zfs_root_fs"

    SECONDS=0

    while [[ $SECONDS -lt 5 ]]; do
      if [[ ! -s $c_zfs_mount_dir/etc/zfs/zfs-list.cache/$c_bpool_name || ! -s $c_zfs_mount_dir/etc/zfs/zfs-list.cache/$v_rpool_name ]]; then
        success=1
        break
      else
        sleep 0.25
      fi
    done
  else
    success=1
  fi

  chroot_execute "pkill zed"

  if [[ $success -ne 1 ]]; then
    echo "Error: The ZFS cache hasn't been updated by ZED!"
    exit 1
  fi

  chroot_execute "sed -Ei 's|$c_zfs_mount_dir/?|/|' /etc/zfs/zfs-list.cache/*"
}

function configure_remaining_settings {
  chroot_execute "echo RESUME=none > /etc/initramfs-tools/conf.d/resume"
}

function prepare_for_system_exit {
  for virtual_fs_dir in dev sys proc; do
    umount --recursive --force --lazy "$c_zfs_mount_dir/$virtual_fs_dir"
  done

  local max_unmount_wait=5
  echo -n "Waiting for virtual filesystems to unmount "

  SECONDS=0

  for virtual_fs_dir in dev sys proc; do
    while mountpoint -q "$c_zfs_mount_dir/$virtual_fs_dir" && [[ $SECONDS -lt $max_unmount_wait ]]; do
      sleep 0.5
      echo -n .
    done
  done

  echo

  for virtual_fs_dir in dev sys proc; do
    if mountpoint -q "$c_zfs_mount_dir/$virtual_fs_dir"; then
      echo "Re-issuing umount for $c_zfs_mount_dir/$virtual_fs_dir"
      umount --recursive --force --lazy "$c_zfs_mount_dir/$virtual_fs_dir"
    fi
  done

  zpool export -a
}

function display_exit_banner {
  local dialog_message="Enhanced ZFS Ubuntu installation completed successfully!

System Configuration:
- Ubuntu $v_ubuntu_version
- Hostname: $v_hostname  
- User: $v_username
- Desktop: $v_desktop_environment
- Boot Manager: $(if [[ $v_use_zfsbootmenu -eq 1 ]]; then echo "ZFSBootMenu"; else echo "GRUB"; fi)
- Timeshift: $(if [[ $v_install_timeshift -eq 1 ]]; then echo "Installed"; else echo "Not installed"; fi)

You can now reboot to enjoy your ZFS system!"

  if [[ -z ${ZFS_NO_INFO_MESSAGES:-} ]]; then
    whiptail --msgbox "$dialog_message" 30 100
  fi
}

# MAIN #########################################################################

if [[ $# -ne 0 ]]; then
  display_help_and_exit
fi

invoke "activate_debug"
invoke "set_distribution_data"
invoke "store_os_distro_information"
invoke "store_running_processes"
invoke "check_prerequisites"
invoke "display_intro_banner"
invoke "check_system_memory"
invoke "save_disks_log"
invoke "find_suitable_disks"
invoke "register_exit_hook"
invoke "create_passphrase_named_pipe"
invoke "prepare_standard_repositories"
invoke "update_apt_index"
invoke "set_use_zfs_ppa"
invoke "install_host_base_packages"

# Enhanced configuration prompts
invoke "ask_ubuntu_version"
invoke "ask_installation_method"
invoke "ask_user_configuration"
invoke "ask_hostname"
invoke "ask_system_configuration"
invoke "ask_desktop_environment"
invoke "ask_additional_options"

# Original ZFS configuration
invoke "select_disks"
invoke "select_vdev_configs"
invoke "ask_encryption"
invoke "ask_boot_partition_size"
invoke "ask_swap_size"
invoke "ask_free_tail_space"
invoke "ask_rpool_name"
invoke "ask_pool_create_options"
invoke "ask_dataset_create_options"

invoke "install_host_zfs_packages"
invoke "setup_partitions"

# Enhanced installation process
invoke "install_operating_system"

invoke "create_pools_and_datasets"
invoke "create_swap_volume"
invoke "copy_zpool_cache"
invoke "sync_os_temp_installation_dir_to_rpool"
invoke "remove_temp_partition_and_expand_rpool"

invoke "prepare_jail"
invoke "install_jail_base_packages"
invoke "install_jail_zfs_packages"

# Enhanced features
invoke "install_timeshift"
invoke "install_zfsbootmenu"

invoke "prepare_fstab"
invoke "prepare_efi_partition"
invoke "configure_and_update_grub"
invoke "sync_efi_partitions"
invoke "update_initramfs"
invoke "fix_filesystem_mount_ordering"
invoke "configure_remaining_settings"

invoke "prepare_for_system_exit"
invoke "display_exit_banner"