#!/bin/bash
set -euo pipefail

# Constants
ZPOOL_NAME="rpool"
ZFS_DATASET="$ZPOOL_NAME/ROOT/kubuntu"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/zfs-install-$(date +%Y%m%d-%H%M%S).log"

# AI-enhanced logging and progress tracking
log() {
    echo "[$(date +'%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

progress() {
    local current=$1 total=$2 task=$3
    local percent=$((current * 100 / total))
    printf "\r\033[K[%3d%%] %s" "$percent" "$task"
    if [ "$current" -eq "$total" ]; then echo; fi
}

# Intelligent system detection
detect_hardware() {
    log "🔍 Detecting hardware capabilities..."
    
    # CPU info
    CPU_CORES=$(nproc)
    HAS_AVX2=$(grep -q avx2 /proc/cpuinfo && echo "yes" || echo "no")
    HAS_AVX512=$(grep -q avx512 /proc/cpuinfo && echo "yes" || echo "no")
    
    # GPU detection
    HAS_NVIDIA=$(lspci | grep -i nvidia >/dev/null && echo "yes" || echo "no")
    HAS_INTEL_GPU=$(lspci | grep -i "intel.*graphics\|intel.*display" >/dev/null && echo "yes" || echo "no")
    HAS_AMD_GPU=$(lspci | grep -i "amd.*radeon\|amd.*graphics" >/dev/null && echo "yes" || echo "no")
    
    # Memory info
    TOTAL_RAM_GB=$(($(awk '/MemTotal:/ {print $2}' /proc/meminfo) / 1024 / 1024))
    
    # Storage detection
    HAS_NVME=$(lsblk -d -o NAME,ROTA | grep -q "nvme.*0" && echo "yes" || echo "no")
    HAS_SSD=$(lsblk -d -o NAME,ROTA | grep -q "sd.*0" && echo "yes" || echo "no")
    
    log "CPU: ${CPU_CORES} cores, AVX2: ${HAS_AVX2}, AVX512: ${HAS_AVX512}"
    log "GPU: NVIDIA: ${HAS_NVIDIA}, Intel: ${HAS_INTEL_GPU}, AMD: ${HAS_AMD_GPU}"
    log "RAM: ${TOTAL_RAM_GB}GB, NVMe: ${HAS_NVME}, SSD: ${HAS_SSD}"
}

# Parallel download function with retry logic
parallel_download() {
    local -a urls=("$@")
    local -a pids=()
    local temp_dir
    temp_dir=$(mktemp -d)
    
    for i in "${!urls[@]}"; do
        {
            local url="${urls[$i]}"
            local filename="${temp_dir}/download_$i"
            local retries=3
            
            while [ $retries -gt 0 ]; do
                if curl -fsSL --connect-timeout 10 --max-time 300 "$url" -o "$filename"; then
                    echo "$filename"
                    break
                fi
                ((retries--))
                sleep 2
            done
        } &
        pids+=($!)
    done
    
    # Wait for all downloads
    for pid in "${pids[@]}"; do
        wait "$pid" || log "⚠️  Download failed for PID $pid"
    done
    
    echo "$temp_dir"
}

# Smart package installation with dependency resolution
smart_apt_install() {
    local packages=("$@")
    local failed_packages=()
    local success_count=0
    
    log "📦 Installing ${#packages[@]} packages..."
    
    # Update package lists if older than 1 hour
    if [ ! -f /var/lib/apt/periodic/update-success-stamp ] || \
       [ "$(find /var/lib/apt/periodic/update-success-stamp -mmin +60 2>/dev/null)" ]; then
        sudo apt update
    fi
    
    # Try to install all packages at once first
    if sudo apt install -y "${packages[@]}" 2>/dev/null; then
        log "✅ All packages installed successfully"
        return 0
    fi
    
    # If batch install fails, try individually
    for package in "${packages[@]}"; do
        if sudo apt install -y "$package" 2>/dev/null; then
            ((success_count++))
        else
            failed_packages+=("$package")
            log "❌ Failed to install: $package"
        fi
        progress $((success_count + ${#failed_packages[@]})) "${#packages[@]}" "Installing $package"
    done
    
    if [ ${#failed_packages[@]} -gt 0 ]; then
        log "⚠️  Failed packages: ${failed_packages[*]}"
    fi
}

# Optimized ZFS tuning based on hardware
optimize_zfs_for_hardware() {
    local pool_name="$1"
    
    log "⚡ Optimizing ZFS for detected hardware..."
    
    # ARC tuning based on RAM
    local arc_max_gb
    if [ "$TOTAL_RAM_GB" -gt 32 ]; then
        arc_max_gb=16
    else
        arc_max_gb=$((TOTAL_RAM_GB / 2))
    fi
    
    # L2ARC setup for SSD cache
    if [ "$HAS_SSD" = "yes" ] || [ "$HAS_NVME" = "yes" ]; then
        log "🚀 SSD detected - enabling aggressive L2ARC"
        sudo zfs set secondarycache=all "$pool_name" 2>/dev/null || true
    fi
    
    # Recordsize optimization for workload
    sudo zfs set recordsize=1M "$pool_name/ROOT" 2>/dev/null || true  # Better for large files
    
    # Compression algorithm based on CPU
    if [ "$HAS_AVX2" = "yes" ]; then
        sudo zfs set compression=zstd "$pool_name" 2>/dev/null || true
        log "🗜️  Using ZSTD compression (AVX2 detected)"
    else
        sudo zfs set compression=lz4 "$pool_name" 2>/dev/null || true
        log "🗜️  Using LZ4 compression"
    fi
    
    # Write ZFS module parameters
    sudo tee /etc/modprobe.d/zfs.conf >/dev/null <<EOF
# Optimized for ${CPU_CORES} cores, ${TOTAL_RAM_GB}GB RAM
options zfs zfs_arc_max=$((arc_max_gb * 1024 * 1024 * 1024))
options zfs zfs_arc_min=$((arc_max_gb * 256 * 1024 * 1024))
options zfs zfs_prefetch_disable=0
options zfs zfs_txg_timeout=5
options zfs zfs_vdev_scheduler=mq-deadline
EOF
}

# AI-optimized package lists based on hardware
get_gpu_packages() {
    local packages=()
    
    if [ "$HAS_NVIDIA" = "yes" ]; then
        packages+=(
            "ubuntu-drivers-common" "nvidia-settings" "nvidia-prime"
            "nvidia-persistenced" "nvidia-powerd" "libnvidia-gl:i386"
            "libvulkan1:i386" "nvidia-container-toolkit"
        )
    fi
    
    if [ "$HAS_INTEL_GPU" = "yes" ]; then
        packages+=(
            "intel-media-va-driver" "mesa-vulkan-drivers" 
            "mesa-vulkan-drivers:i386" "libgl1-mesa-dri:i386"
            "vulkan-tools" "intel-gpu-tools"
        )
    fi
    
    if [ "$HAS_AMD_GPU" = "yes" ]; then
        packages+=(
            "mesa-vulkan-drivers" "mesa-vulkan-drivers:i386"
            "libgl1-mesa-dri:i386" "vulkan-tools"
        )
    fi
    
    echo "${packages[@]}"
}

# Complete post-installation system fixes and enhancements
post_install_system_fixes() {
    log "🔧 Applying comprehensive post-installation fixes..."
    
    # Enable all Ubuntu repositories
    setup_complete_repositories
    
    # Install essential codecs and drivers
    install_multimedia_codecs
    
    # System tweaks and optimizations
    apply_system_tweaks
    
    # Security and privacy enhancements
    enhance_security_privacy
    
    # Development environment setup
    setup_development_environment
    
    # Gaming ecosystem (complete Garuda-style setup)
    install_complete_gaming_stack
    
    # Productivity and utility software
    install_productivity_suite
}

# Ultimate gaming ecosystem setup (Best features from all gaming distros)
install_complete_gaming_stack() {
    log "🎮 Installing ULTIMATE gaming ecosystem (All distros' best features)..."
    
    # Add all gaming repositories
    add_ultimate_gaming_repositories
    
    # Steam and gaming platforms (ChimeraOS + SteamOS inspired)
    install_ultimate_gaming_platforms
    
    # Wine, Proton, and Windows compatibility (Nobara + Garuda)
    install_ultimate_wine_proton_stack
    
    # Gaming utilities and tools (Pop!_OS + Garuda)
    install_ultimate_gaming_utilities
    
    # Complete emulation suite (Batocera + RetroPie inspired)
    install_ultimate_emulation_suite
    
    # Gaming-focused drivers and firmware (Nobara inspired)
    install_gaming_drivers_firmware
    
    # Streaming and remote gaming (ChimeraOS + SteamOS)
    install_streaming_gaming_stack
    
    # VR gaming support (All distros)
    install_vr_gaming_stack
    
    # Gaming development tools (Pop!_OS + Fedora)
    install_gaming_development_stack
    
    # Ultimate gaming optimizations (All distros combined)
    apply_ultimate_gaming_optimizations
    
    # Gaming-specific desktop environment tweaks
    apply_gaming_desktop_tweaks
}

add_ultimate_gaming_repositories() {
    log "🎮 Adding ULTIMATE gaming repositories (All distros)..."
    
    # Core gaming repositories
    sudo add-apt-repository -y ppa:lutris-team/lutris
    sudo add-apt-repository -y ppa:tkashkin/gamehub
    sudo add-apt-repository -y ppa:libretro/stable
    
    # Nobara-inspired repositories
    sudo add-apt-repository -y ppa:kisak/kisak-mesa  # Latest Mesa drivers
    sudo add-apt-repository -y ppa:oibaf/graphics-drivers  # Bleeding edge graphics
    
    # Wine and compatibility
    sudo mkdir -p /etc/apt/keyrings
    sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/winehq-archive.key] https://dl.winehq.org/wine-builds/ubuntu/ jammy main" | \
        sudo tee /etc/apt/sources.list.d/winehq.list
    
    # Gaming-focused kernel (Xanmod - used by many gaming distros)
    sudo wget -qO - https://dl.xanmod.org/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg
    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | \
        sudo tee /etc/apt/sources.list.d/xanmod-release.list
    
    # Multimedia codecs (essential for gaming)
    sudo add-apt-repository -y ppa:ubuntuhandbook1/ffmpeg6
    
    # Gaming utilities
    sudo add-apt-repository -y ppa:flexiondotorg/mangohud
    sudo add-apt-repository -y ppa:obsproject/obs-studio
    
    # VR and advanced gaming
    sudo add-apt-repository -y ppa:pipewire-debian/pipewire-upstream
    
    sudo apt update
}

install_ultimate_gaming_platforms() {
    log "🎮 Installing ULTIMATE gaming platforms (All distros)..."
    
    # Core gaming platforms (ChimeraOS + SteamOS inspired)
    local gaming_platforms=(
        # Steam ecosystem
        "steam-installer" "steam-devices" "gamemode" "steam-tweaks"
        
        # Epic Games, GOG, and others (Nobara style)
        "lutris" "gamehub" "heroic" "bottles" "legendary-gl" "rare"
        
        # Native Linux games (Pop!_OS selection)
        "0ad" "supertuxkart" "minetest" "wesnoth" "xonotic" "openttd"
        "warzone2100" "hedgewars" "extremetuxracer"
        
        # Game development (Fedora + Pop!_OS)
        "godot3" "blender" "krita" "gimp" "audacity"
        
        # Minecraft launchers
        "minecraft-launcher"
    )
    
    smart_apt_install "${gaming_platforms[@]}"
    
    # Install Steam with multiple methods (ChimeraOS approach)
    install_steam_ultimate
    
    # Install Epic Games alternatives
    install_epic_alternatives
    
    # Install ultimate Flatpak gaming ecosystem
    install_flatpak_gaming_ultimate
    
    # Install gaming-focused AppImages
    install_gaming_appimages
    
    # Configure Steam for optimal performance
    configure_steam_optimizations
}

install_steam_ultimate() {
    log "🚂 Installing Steam with ultimate compatibility..."
    
    # Method 1: Official Steam package
    if ! command -v steam >/dev/null 2>&1; then
        temp_dir=$(parallel_download \
            "https://steamcdn-a.akamaihd.net/client/installer/steam.deb" \
            "https://repo.steampowered.com/steam/archive/stable/steam.deb")
        
        for file in "$temp_dir"/download_*; do
            if [ -f "$file" ] && file "$file" | grep -q "Debian"; then
                sudo dpkg -i "$file" || true
                sudo apt-get install -f -y
                break
            fi
        done
        rm -rf "$temp_dir"
    fi
    
    # Steam dependencies for gaming distros
    local steam_deps=(
        "libgl1-mesa-dri:i386" "libgl1-mesa-glx:i386"
        "libgpg-error0:i386" "libxinerama1:i386"
        "libxrandr2:i386" "libxss1:i386" "libasound2:i386"
        "libpulse0:i386" "libnss3:i386" "libxcursor1:i386"
        "libxi6:i386" "libxcomposite1:i386" "libxtst6:i386"
        "libvulkan1:i386" "mesa-vulkan-drivers:i386"
    )
    
    smart_apt_install "${steam_deps[@]}"
    
    # Enable 32-bit architecture (essential for Steam)
    sudo dpkg --add-architecture i386
    sudo apt update
}

install_epic_alternatives() {
    log "🎮 Installing Epic Games alternatives..."
    
    # Legendary (CLI Epic Games launcher)
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --user legendary-gl
    fi
    
    # Rare (GUI for Legendary)
    sudo flatpak install -y flathub io.github.dummerle.rare || true
}

install_flatpak_gaming_ultimate() {
    log "📦 Installing ultimate Flatpak gaming collection..."
    
    local flatpak_games=(
        # Game launchers and platforms
        "com.valvesoftware.Steam"  # Steam
        "net.lutris.Lutris"        # Lutris
        "com.heroicgameslauncher.hgl"  # Heroic
        "com.usebottles.bottles"   # Bottles
        "io.github.dummerle.rare" # Rare (Epic)
        
        # Game stores and managers
        "com.github.tkashkin.gamehub"     # GameHub
        "io.itch.itch"                    # Itch.io
        "net.davidotek.pupgui2"           # ProtonUp-Qt
        
        # Minecraft ecosystem
        "org.prismlauncher.PrismLauncher" # Prism Launcher
        "org.polymc.PolyMC"              # PolyMC
        "net.minecraft.Minecraft"         # Official Minecraft
        
        # Gaming utilities
        "org.freedesktop.Platform.VulkanLayer.MangoHud"
        "com.github.Matoking.protontricks"  # ProtonTricks
        "io.github.fastrizwaan.WineZGUI"    # WineZGUI
        
        # Native Linux games
        "org.openttd.OpenTTD"           # OpenTTD
        "net.sourceforge.ExtremeTuxRacer"  # Extreme Tux Racer
        "org.hedgewars.Hedgewars"       # Hedgewars
        "io.xonotic.Xonotic"           # Xonotic
        "org.wesnoth.Wesnoth"          # Battle for Wesnoth
    )
    
    for app in "${flatpak_games[@]}"; do
        sudo flatpak install -y flathub "$app" 2>/dev/null || log "⚠️  Failed to install $app"
    done
}

install_gaming_appimages() {
    log "🖼️ Installing gaming AppImages..."
    
    local appimage_dir="$HOME/.local/bin"
    mkdir -p "$appimage_dir"
    
    # Download gaming AppImages
    local appimages=(
        "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        "https://github.com/DavidoTek/ProtonUp-Qt/releases/latest/download/ProtonUp-Qt-x86_64.AppImage"
    )
    
    temp_dir=$(parallel_download "${appimages[@]}")
    
    local count=0
    for url in "${appimages[@]}"; do
        local filename
        filename=$(basename "$url" .AppImage)
        local downloaded_file="$temp_dir/download_$count"
        
        if [ -f "$downloaded_file" ]; then
            install -m 755 "$downloaded_file" "$appimage_dir/$filename"
        fi
        ((count++))
    done
    
    rm -rf "$temp_dir"
}

configure_steam_optimizations() {
    log "⚡ Configuring Steam optimizations (ChimeraOS style)..."
    
    # Steam launch options optimization
    local steam_config_dir="$HOME/.steam/steam/config"
    mkdir -p "$steam_config_dir"
    
    # Optimal Steam settings
    tee "$steam_config_dir/config.vdf" >/dev/null <<EOF || true
"InstallConfigStore"
{
    "Software"
    {
        "Valve"
        {
            "Steam"
            {
                "DPIScaling"        "1"
                "H264HWAccel"        "1"
                "GameOverlayEnabled"     "1"
                "InGameOverlayShortcutKey"       "Shift+Tab"
                "SteamDefaultDialog"     "#app_details"
                "NoSavePersonalInfo"     "0"
                "MaxServerBrowserPingsPerMin"       "5000"
                "DownloadThrottleKbps"       "0"
                "AllowDownloadsDuringGameplay"       "0"
                "StreamingThrottleEnabled"       "1"
                "ClientBrowserAuth"      "1"
            }
        }
    }
}
EOF
    
    # Gaming mode environment variables
    sudo tee /etc/environment.d/99-gaming-steam.conf >/dev/null <<EOF
STEAM_FRAME_FORCE_CLOSE=1
STEAM_RUNTIME_PREFER_HOST_LIBRARIES=1
MESA_GL_VERSION_OVERRIDE=4.6
radeonsi_enable_nir=1
EOF
}

# Ultimate Wine and Proton stack (Nobara + Garuda inspired)
install_ultimate_wine_proton_stack() {
    log "🍷 Installing ULTIMATE Wine and Proton compatibility stack..."
    
    # Install Wine staging with all dependencies
    install_wine_complete
    
    # Advanced Proton managers
    install_ultimate_proton_tools
    
    # Gaming-specific Wine components
    install_wine_gaming_components
    
    # DXVK and VKD3D (Nobara style)
    install_dxvk_vkd3d_ultimate
    
    # Windows game compatibility fixes
    install_windows_compatibility_fixes
}

install_wine_complete() {
    log "🍷 Installing complete Wine stack..."
    
    # Enable 32-bit architecture first
    sudo dpkg --add-architecture i386
    sudo apt update
    
    # Install Wine staging (latest)
    smart_apt_install winehq-staging winetricks
    
    # Complete Wine dependencies (gaming distros collection)
    local wine_deps=(
        # Essential Wine libraries
        "libwine:i386" "wine32" "wine64" "wine32-development" "wine64-development"
        
        # Audio support (critical for gaming)
        "libpulse0:i386" "libasound2-plugins:i386" "libjack-jackd2-0:i386"
        "pulseaudio:i386" "libpipewire-0.3-0:i386"
        
        # Graphics and Vulkan support
        "libgl1-mesa-glx:i386" "libglu1-mesa:i386" "mesa-vulkan-drivers:i386"
        "libvulkan1:i386" "vulkan-utils" "vulkan-tools"
        "libglx-mesa0:i386" "libegl-mesa0:i386"
        
        # DirectX and gaming libs
        "libd3dadapter9-mesa:i386" "libd3dadapter9-mesa-dev"
        
        # Font rendering (Windows compatibility)
        "libfreetype6:i386" "libfontconfig1:i386" "fonts-wine"
        
        # Network and crypto
        "libssl3:i386" "libgnutls30:i386" "libcurl4:i386"
        
        # Gaming input support
        "libxi6:i386" "libxrandr2:i386" "libxinerama1:i386"
        "libxcomposite1:i386" "libxcursor1:i386" "libxtst6:i386"
        
        # Media codecs for games
        "libgstreamer-plugins-base1.0-0:i386" "libgstreamer1.0-0:i386"
    )
    
    smart_apt_install "${wine_deps[@]}"
}

install_ultimate_proton_tools() {
    log "🚀 Installing ultimate Proton management tools..."
    
    # ProtonPlus (Advanced Proton manager)
    install_protonplus
    
    # PortProton (Russian gaming community's Wine manager)
    install_portproton
    
    # ProtonTricks (Essential for Steam games)
    install_protontricks_enhanced
    
    # ProtonUp-Qt (GUI Proton updater)
    install_protonup_qt
    
    # Bottles (Modern Wine prefix manager)
    if ! command -v bottles >/dev/null 2>&1; then
        sudo flatpak install -y flathub com.usebottles.bottles || true
    fi
    
    # Lutris (Universal game installer)
    smart_apt_install lutris
}

install_protonup_qt() {
    log "🚀 Installing ProtonUp-Qt..."
    
    # Install via Flatpak (most reliable)
    sudo flatpak install -y flathub net.davidotek.pupgui2 || true
}

install_protontricks_enhanced() {
    log "🧙 Installing enhanced ProtonTricks..."
    
    # Try package manager first
    if ! smart_apt_install python3-protontricks; then
        # Fallback to pip with enhanced installation
        if command -v pip3 >/dev/null 2>&1; then
            pip3 install --user protontricks[gui]
        fi
    fi
    
    # Install ProtonTricks dependencies
    smart_apt_install python3-venv python3-setuptools
}

install_wine_gaming_components() {
    log "🎮 Installing Wine gaming-specific components..."
    
    # Install additional Wine components for gaming
    local gaming_components=(
        "cabextract" "p7zip" "unzip" "wget" "zenity"
        "wine-binfmt" "winbind" "playonlinux" "q4wine"
    )
    
    smart_apt_install "${gaming_components[@]}"
    
    # Configure Wine for gaming
    export WINEPREFIX="$HOME/.wine-gaming"
    if [ ! -d "$WINEPREFIX" ]; then
        winecfg /v win10 2>/dev/null || true
    fi
}

install_dxvk_vkd3d_ultimate() {
    log "⚡ Installing DXVK and VKD3D (Nobara style)..."
    
    # Create DXVK directory
    local dxvk_dir="$HOME/.local/share/dxvk"
    mkdir -p "$dxvk_dir"
    
    # Download latest DXVK
    local dxvk_url="https://github.com/doitsujin/dxvk/releases/latest"
    local dxvk_download_url
    dxvk_download_url=$(curl -s "$dxvk_url" | grep -o 'https://.*dxvk.*tar.gz' | head -1)
    
    if [ -n "$dxvk_download_url" ]; then
        temp_dir=$(parallel_download "$dxvk_download_url")
        if [ -f "$temp_dir/download_0" ]; then
            tar -xzf "$temp_dir/download_0" -C "$dxvk_dir" --strip-components=1
        fi
        rm -rf "$temp_dir"
    fi
    
    # Install VKD3D (DirectX 12 to Vulkan)
    smart_apt_install libvkd3d1 libvkd3d-dev vkd3d-compiler
}

install_windows_compatibility_fixes() {
    log "🔧 Installing Windows compatibility fixes..."
    
    # Essential Windows fonts
    winetricks -q corefonts vcrun2019 d3dcompiler_47 || true
    
    # Gaming-specific redistributables
    winetricks -q vcrun2022 dotnet48 xna40 || true
    
    # DirectX redistributable
    winetricks -q d3dx9 d3dx10 d3dx11_42 d3dx11_43 || true
}

# Gaming drivers and firmware (Nobara inspired)
install_gaming_drivers_firmware() {
    log "🔧 Installing gaming-focused drivers and firmware..."
    
    # Latest Mesa drivers (Nobara approach)
    install_mesa_gaming_drivers
    
    # NVIDIA drivers with gaming optimizations
    if [ "$HAS_NVIDIA" = "yes" ]; then
        install_nvidia_gaming_drivers
    fi
    
    # AMD drivers with gaming optimizations  
    if [ "$HAS_AMD_GPU" = "yes" ]; then
        install_amd_gaming_drivers
    fi
    
    # Gaming-focused firmware
    install_gaming_firmware
    
    # Kernel modules for gaming hardware
    install_gaming_kernel_modules
}

install_mesa_gaming_drivers() {
    log "🎮 Installing latest Mesa drivers for gaming..."
    
    # Install from Kisak Mesa PPA (already added)
    local mesa_packages=(
        "mesa-vulkan-drivers" "mesa-vulkan-drivers:i386"
        "libgl1-mesa-dri" "libgl1-mesa-dri:i386"
        "mesa-va-drivers" "mesa-vdpau-drivers"
        "libglx-mesa0" "libglx-mesa0:i386"
        "libegl1-mesa" "libegl1-mesa:i386"
    )
    
    smart_apt_install "${mesa_packages[@]}"
}

install_nvidia_gaming_drivers() {
    log "🎮 Installing NVIDIA gaming drivers..."
    
    local nvidia_packages=(
        "nvidia-driver-535" "nvidia-settings" "nvidia-prime"
        "libnvidia-gl-535" "libnvidia-gl-535:i386"
        "nvidia-utils-535" "libnvenc-nvml-dev"
        "libnvidia-decode-535" "libnvidia-encode-535"
        "nvidia-container-toolkit" "nvidia-opencl-dev"
    )
    
    smart_apt_install "${nvidia_packages[@]}"
    
    # NVIDIA gaming optimizations
    sudo nvidia-settings --assign CurrentMetaMode="nvidia-auto-select +0+0 { ForceFullCompositionPipeline = Off }"
    
    # Create NVIDIA gaming profile
    tee "$HOME/.nvidia-settings-rc" >/dev/null <<EOF
# Ultimate gaming optimizations
[gpu:0]/GPUPowerMizerMode=1
[gpu:0]/GPUMemoryTransferRateOffset[4]=2000
[gpu:0]/GPUGraphicsClockOffset[4]=200
[gpu:0]/GPUFanControlState=1
EOF
}

install_amd_gaming_drivers() {
    log "🎮 Installing AMD gaming drivers..."
    
    local amd_packages=(
        "firmware-amd-graphics" "radeontop" "vulkan-tools"
        "mesa-vulkan-drivers" "mesa-vulkan-drivers:i386"
        "rocm-opencl-runtime" "rocm-dev" "rocm-utils"
    )
    
    smart_apt_install "${amd_packages[@]}"
    
    # AMD gaming optimizations
    echo 'SUBSYSTEM=="drm", KERNEL=="card*", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="high"' | \
        sudo tee /etc/udev/rules.d/30-amdgpu-gaming.rules >/dev/null
}

install_gaming_firmware() {
    log "💻 Installing gaming-focused firmware..."
    
    local firmware_packages=(
        "firmware-misc-nonfree" "firmware-linux" "firmware-linux-nonfree"
        "intel-microcode" "amd64-microcode"
        "firmware-realtek" "firmware-atheros" "firmware-iwlwifi"
    )
    
    smart_apt_install "${firmware_packages[@]}"
}

install_gaming_kernel_modules() {
    log "⚙️ Installing gaming kernel modules..."
    
    # Install DKMS for dynamic kernel module support
    smart_apt_install dkms
    
    # Gaming controller support
    smart_apt_install xpad xboxdrv joystick jstest-gtk
    
    # Enable game controller support
    sudo modprobe xpad || true
    echo 'xpad' | sudo tee -a /etc/modules >/dev/null || true
}

# Streaming and remote gaming (ChimeraOS + SteamOS inspired)
install_streaming_gaming_stack() {
    log "📺 Installing streaming and remote gaming stack..."
    
    # Game streaming platforms
    install_game_streaming_platforms
    
    # Remote play and streaming tools
    install_remote_play_tools
    
    # Capture and recording tools
    install_capture_recording_tools
    
    # Network optimization for streaming
    configure_streaming_network_optimization
}

install_game_streaming_platforms() {
    log "📺 Installing game streaming platforms..."
    
    # Steam Link
    sudo flatpak install -y flathub com.valvesoftware.SteamLink || true
    
    # Moonlight (NVIDIA GameStream client)
    sudo flatpak install -y flathub com.moonlight_stream.Moonlight || true
    
    # Parsec (universal game streaming)
    local parsec_url="https://builds.parsecgaming.com/package/parsec-linux.deb"
    temp_dir=$(parallel_download "$parsec_url")
    if [ -f "$temp_dir/download_0" ]; then
        sudo dpkg -i "$temp_dir/download_0" || true
        sudo apt-get install -f -y
    fi
    rm -rf "$temp_dir"
    
    # Sunshine (open-source GameStream server)
    if command -v snap >/dev/null 2>&1; then
        sudo snap install sunshine --beta || true
    fi
}

install_remote_play_tools() {
    log "🎮 Installing remote play tools..."
    
    # KDE Connect for mobile gaming
    smart_apt_install kdeconnect
    
    # Scrcpy for Android gaming
    smart_apt_install scrcpy
    
    # Remote desktop with gaming optimizations
    smart_apt_install x11vnc tigervnc-standalone-server
}

install_capture_recording_tools() {
    log "🎥 Installing capture and recording tools..."
    
    local recording_tools=(
        "obs-studio" "simplescreenrecorder" "vokoscreen-ng"
        "ffmpeg" "v4l-utils" "v4l2loopback-dkms"
        "audacity" "pavucontrol" "pulseeffects"
    )
    
    smart_apt_install "${recording_tools[@]}"
    
    # OBS Studio plugins for gaming
    install_obs_gaming_plugins
}

install_obs_gaming_plugins() {
    log "🎬 Installing OBS gaming plugins..."
    
    # Install via Flatpak for better plugin support
    sudo flatpak install -y flathub com.obsproject.Studio || true
    
    # Gaming-specific OBS plugins
    local obs_plugins_dir="$HOME/.var/app/com.obsproject.Studio/config/obs-studio/plugins"
    mkdir -p "$obs_plugins_dir"
}

configure_streaming_network_optimization() {
    log "🌐 Configuring network optimization for streaming..."
    
    # Gaming and streaming network optimizations
    sudo tee /etc/sysctl.d/99-gaming-streaming.conf >/dev/null <<EOF
# Gaming and streaming network optimizations
net.core.rmem_default = 262144
net.core.rmem_max = 134217728
net.core.wmem_default = 262144  
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 30000
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
EOF
}

# VR gaming support (All distros)
install_vr_gaming_stack() {
    log "🥽 Installing VR gaming stack..."
    
    # SteamVR and OpenXR support
    install_steamvr_support
    
    # OpenXR runtime and tools
    install_openxr_stack
    
    # VR-specific drivers and firmware
    install_vr_drivers
    
    # VR development tools
    install_vr_development_tools
}

install_steamvr_support() {
    log "🥽 Installing SteamVR support..."
    
    # SteamVR dependencies
    local steamvr_deps=(
        "libvulkan1" "vulkan-utils" "vulkan-tools"
        "libudev1" "libudev-dev" "libusb-1.0-0" "libusb-1.0-0-dev"
        "libhidapi-libusb0" "libhidapi-hidraw0"
    )
    
    smart_apt_install "${steamvr_deps[@]}"
    
    # Enable VR device access
    sudo usermod -a -G plugdev "$USER" || true
}

install_openxr_stack() {
    log "🥽 Installing OpenXR runtime stack..."
    
    # Monado (Open Source OpenXR runtime)
    smart_apt_install monado-service monado-cli
    
    # OpenXR development
    smart_apt_install libopenxr-dev libopenxr1
}

install_vr_drivers() {
    log "🥽 Installing VR-specific drivers..."
    
    # ALVR (Air Light VR)
    sudo flatpak install -y flathub com.valvesoftware.SteamVR.ALVR || true
    
    # VR controller and headset support
    smart_apt_install libopenvr-dev libopenvr1
}

install_vr_development_tools() {
    log "🥽 Installing VR development tools..."
    
    # Godot VR, Blender VR support already installed
    # Additional VR-specific tools
    smart_apt_install blender-addons-contrib
}

# Gaming development stack (Pop!_OS + Fedora inspired)
install_gaming_development_stack() {
    log "🛠️ Installing gaming development stack..."
    
    # Game engines and frameworks
    install_game_engines
    
    # Graphics and art tools
    install_graphics_art_tools
    
    # Audio tools for game development
    install_audio_development_tools
    
    # Version control for game development
    install_gamedev_version_control
}

install_game_engines() {
    log "🎮 Installing game engines..."
    
    local game_engines=(
        "godot3" "blender" "krita"
        "love" "libsdl2-dev" "libsfml-dev"
        "libglfw3-dev" "libglew-dev"
    )
    
    smart_apt_install "${game_engines[@]}"
    
    # Unity Hub (if available)
    sudo flatpak install -y flathub com.unity.UnityHub || true
    
    # Unreal Engine dependencies
    smart_apt_install mono-complete
}

install_graphics_art_tools() {
    log "🎨 Installing graphics and art tools..."
    
    local art_tools=(
        "gimp" "inkscape" "blender" "krita"
        "aseprite" "libresprite" "mypaint"
        "darktable" "rawtherapee"
    )
    
    smart_apt_install "${art_tools[@]}"
    
    # Install additional art software via Flatpak
    sudo flatpak install -y flathub org.kde.krita org.gimp.GIMP || true
}

install_audio_development_tools() {
    log "🎵 Installing audio development tools..."
    
    local audio_tools=(
        "audacity" "ardour" "lmms" "musescore3"
        "qjackctl" "jack-tools" "pavucontrol"
        "pulseeffects" "carla" "calf-plugins"
    )
    
    smart_apt_install "${audio_tools[@]}"
    
    # Professional audio via Flatpak
    sudo flatpak install -y flathub org.audacityteam.Audacity || true
}

install_gamedev_version_control() {
    log "📊 Installing game development version control..."
    
    # Git LFS for large game assets
    smart_apt_install git-lfs
    
    # Initialize Git LFS
    git lfs install 2>/dev/null || true
    
    # Perforce (gaming industry standard)
    # Note: Commercial software, providing setup info only
    log "📊 Consider Perforce for large game projects"
}

install_wine_proton_stack() {
    log "🍷 Installing Wine and Proton compatibility stack..."
    
    # Install Wine staging (latest)
    smart_apt_install winehq-staging winetricks
    
    # Install dependencies for 32-bit support
    sudo dpkg --add-architecture i386
    sudo apt update
    
    local wine_deps=(
        # Essential Wine dependencies
        "libwine:i386" "wine32" "wine64"
        
        # Audio support
        "libpulse0:i386" "libasound2-plugins:i386"
        
        # Graphics support  
        "libgl1-mesa-glx:i386" "libglu1-mesa:i386"
        
        # Font rendering
        "libfreetype6:i386" "libfontconfig1:i386"
        
        # Network and crypto
        "libssl3:i386" "libgnutls30:i386"
    )
    
    smart_apt_install "${wine_deps[@]}"
    
    # Install ProtonPlus (manual)
    install_protonplus
    
    # Install PortProton
    install_portproton
    
    # Install ProtonTricks
    install_protontricks
    
    # Install Bottles (if not already via apt)
    if ! command -v bottles >/dev/null 2>&1; then
        sudo flatpak install -y flathub com.usebottles.bottles || true
    fi
}

install_protonplus() {
    log "🚀 Installing ProtonPlus..."
    
    local protonplus_url="https://github.com/Vysp3r/ProtonPlus/releases/latest/download/ProtonPlus-Linux.AppImage"
    local install_dir="$HOME/.local/bin"
    
    mkdir -p "$install_dir"
    
    temp_dir=$(parallel_download "$protonplus_url")
    if [ -f "$temp_dir/download_0" ]; then
        install -m 755 "$temp_dir/download_0" "$install_dir/protonplus"
        
        # Create desktop entry
        tee "$HOME/.local/share/applications/protonplus.desktop" >/dev/null <<EOF
[Desktop Entry]
Name=ProtonPlus
Comment=Proton Version Manager
Exec=$install_dir/protonplus
Icon=application-x-ms-dos-executable
Terminal=false
Type=Application
Categories=Game;Utility;
EOF
        
        log "✅ ProtonPlus installed successfully"
    fi
    
    rm -rf "$temp_dir"
}

install_portproton() {
    log "🍷 Installing PortProton..."
    
    local portproton_dir="$HOME/.local/share/PortProton"
    
    if [ ! -d "$portproton_dir" ]; then
        mkdir -p "$(dirname "$portproton_dir")"
        git clone https://github.com/Castro-Fidel/PortProton.git "$portproton_dir" || {
            log "⚠️  Failed to clone PortProton repository"
            return 1
        }
    fi
    
    # Make executable and create launcher
    chmod +x "$portproton_dir/PortProton"
    
    # Create desktop entry
    tee "$HOME/.local/share/applications/portproton.desktop" >/dev/null <<EOF
[Desktop Entry]
Name=PortProton
Comment=Wine prefix manager for Linux
Exec=$portproton_dir/PortProton
Icon=$portproton_dir/data/img/gui/pp.png
Terminal=false
Type=Application
Categories=Game;Utility;
EOF
    
    log "✅ PortProton installed successfully"
}

install_protontricks() {
    log "🧙 Installing ProtonTricks..."
    
    # Try package manager first
    if ! smart_apt_install python3-protontricks; then
        # Fallback to pip
        if command -v pip3 >/dev/null 2>&1; then
            pip3 install --user protontricks
        fi
    fi
}

install_gaming_utilities() {
    log "🎯 Installing gaming utilities and tools..."
    
    local gaming_utils=(
        # Performance monitoring
        "mangohud" "goverlay" "gamemode"
        
        # Game launchers and managers
        "legendary" "minigalaxy"
        
        # Streaming and recording
        "obs-studio" "simplescreenrecorder"
        
        # Communication
        "discord" "teamspeak3"
        
        # System utilities
        "corectrl" "piper" "solaar"
    )
    
    smart_apt_install "${gaming_utils[@]}"
    
    # Enable gamemode
    sudo systemctl enable --now fwupd
    
    # Discord (if package failed)
    if ! command -v discord >/dev/null 2>&1; then
        sudo flatpak install -y flathub com.discordapp.Discord || true
    fi
    
    # Install gaming-focused system tools
    install_gaming_system_tools
}

install_gaming_system_tools() {
    log "🔧 Installing gaming-focused system tools..."
    
    # CPU frequency scaling
    smart_apt_install cpufrequtils
    
    # Nvidia tools (if Nvidia GPU present)
    if [ "$HAS_NVIDIA" = "yes" ]; then
        smart_apt_install nvidia-settings nvidia-prime nvtop
    fi
    
    # AMD tools (if AMD GPU present)
    if [ "$HAS_AMD_GPU" = "yes" ]; then
        smart_apt_install radeontop
    fi
    
    # Gaming-specific kernel parameters
    configure_gaming_kernel_params
}

install_emulation_suite() {
    log "🕹️ Installing complete emulation suite..."
    
    local emulation_packages=(
        # RetroArch ecosystem
        "retroarch" "libretro-beetle-pce-fast" "libretro-snes9x"
        "libretro-genesis-plus-gx" "libretro-mupen64plus-next"
        
        # Standalone emulators
        "dolphin-emu" "ppsspp" "pcsx2" "desmume"
        "stella" "zsnes" "kega-fusion"
        
        # Multi-system
        "mame" "mednafen"
    )
    
    smart_apt_install "${emulation_packages[@]}"
    
    # Flatpak emulators
    sudo flatpak install -y flathub org.DolphinEmu.dolphin-emu \
        net.rpcs3.RPCS3 org.citra_emu.citra \
        org.yuzu_emu.yuzu org.ppsspp.PPSSPP || true
}

apply_gaming_optimizations() {
    log "⚡ Applying gaming-specific optimizations..."
    
    # Gaming-focused sysctl parameters
    sudo tee /etc/sysctl.d/99-gaming-performance.conf >/dev/null <<EOF
# Gaming performance optimizations
vm.max_map_count=2147483642
fs.file-max=2097152
kernel.sched_child_runs_first=0
kernel.sched_autogroup_enabled=1
kernel.sched_cfs_bandwidth_slice_us=3000
net.core.netdev_max_backlog=16384
net.core.somaxconn=8192
net.core.rmem_default=1048576
net.core.rmem_max=16777216
net.core.wmem_default=1048576
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 1048576 2097152
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_tw_reuse=1
EOF
    
    # Audio latency optimization
    configure_audio_for_gaming
    
    # GPU-specific optimizations
    configure_gpu_for_gaming
    
    # Set CPU governor to performance for gaming
    if [ -d /sys/devices/system/cpu/cpufreq ]; then
        echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
    fi
}

configure_gaming_kernel_params() {
    log "🎮 Configuring gaming kernel parameters..."
    
    # Update GRUB for gaming optimizations
    local grub_file="/etc/default/grub"
    if [ -f "$grub_file" ]; then
        # Backup original
        sudo cp "$grub_file" "${grub_file}.backup"
        
        # Add gaming-friendly kernel parameters
        local gaming_params="mitigations=off processor.max_cstate=1 intel_idle.max_cstate=0 idle=poll"
        
        if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "$grub_file"; then
            sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $gaming_params\"/" "$grub_file"
        else
            echo "GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash $gaming_params\"" | sudo tee -a "$grub_file"
        fi
        
        # Update GRUB
        sudo update-grub
    fi
}

configure_audio_for_gaming() {
    log "🎵 Configuring audio for low-latency gaming..."
    
    # PulseAudio optimizations
    if command -v pulseaudio >/dev/null 2>&1; then
        mkdir -p "$HOME/.pulse"
        tee "$HOME/.pulse/daemon.conf" >/dev/null <<EOF
# Gaming audio optimizations
default-sample-format = float32le
default-sample-rate = 48000
alternate-sample-rate = 44100
default-sample-channels = 2
default-fragments = 2
default-fragment-size-msec = 4
resample-method = speex-float-1
enable-lfe-remixing = no
high-priority = yes
nice-level = -11
realtime-scheduling = yes
realtime-priority = 9
EOF
    fi
    
    # JACK support for pro audio
    smart_apt_install qjackctl jack-tools
}

configure_gpu_for_gaming() {
    log "🎮 Configuring GPU for optimal gaming performance..."
    
    if [ "$HAS_NVIDIA" = "yes" ]; then
        # Nvidia optimizations
        sudo nvidia-settings --assign CurrentMetaMode="nvidia-auto-select +0+0 { ForceFullCompositionPipeline = Off }"
        
        # Create Nvidia gaming profile
        tee "$HOME/.nvidia-settings-rc" >/dev/null <<EOF
# Gaming optimizations
[gpu:0]/GPUPowerMizerMode=1
[gpu:0]/GPUMemoryTransferRateOffset[3]=1000
[gpu:0]/GPUGraphicsClockOffset[3]=100
EOF
    fi
    
    if [ "$HAS_AMD_GPU" = "yes" ]; then
        # AMD optimizations
        echo 'SUBSYSTEM=="drm", KERNEL=="card0", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="high"' | \
            sudo tee /etc/udev/rules.d/30-amdgpu-gaming.rules >/dev/null
    fi
}

add_development_repositories() {
    log "💻 Adding development repositories..."
    
    # VSCode repository
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
        sudo tee /etc/apt/sources.list.d/vscode.list
    
    # Docker repository
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu jammy stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list
    
    sudo apt update
}

install_productivity_suite() {
    log "💼 Installing productivity and utility software..."
    
    local productivity_packages=(
        # Office suite
        "libreoffice" "thunderbird" "firefox"
        
        # Media and graphics
        "gimp" "inkscape" "audacity" "vlc" "kdenlive"
        
        # System utilities
        "gparted" "bleachbit" "synaptic" "timeshift"
        "baobab" "gnome-disk-utility"
        
        # Archive and file management
        "file-roller" "p7zip-full" "unrar" "mc"
        
        # Network tools
        "filezilla" "transmission" "qbittorrent"
        
        # Development IDEs
        "code" "geany" "meld"
    )
    
    smart_apt_install "${productivity_packages[@]}"
    
    # Install additional Flatpak productivity apps
    sudo flatpak install -y flathub org.libreoffice.LibreOffice \
        com.github.johnfactotum.Foliate org.gnome.gitlab.somas.Apostrophe \
        org.onlyoffice.desktopeditors || true
}

setup_complete_repositories() {
    log "📦 Setting up complete repository ecosystem..."
    
    # Enable all Ubuntu repositories
    sudo add-apt-repository -y universe
    sudo add-apt-repository -y multiverse
    sudo add-apt-repository -y restricted
    
    # Flatpak support
    smart_apt_install flatpak gnome-software-plugin-flatpak
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    
    # Snap improvements (if using snaps)
    if command -v snap >/dev/null 2>&1; then
        # Speed up snap startup
        sudo systemctl disable snapd.refresh.timer
        sudo systemctl stop snapd.refresh.timer
        echo 'refresh.timer: 02:00-05:00' | sudo tee -a /etc/systemd/system/snapd.refresh.timer.d/override.conf
    fi
    
    # Add popular third-party repositories
    add_gaming_repositories
    add_development_repositories
}

install_multimedia_codecs() {
    log "🎵 Installing complete multimedia codec support..."
    
    # Accept EULA for restricted packages
    echo 'ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true' | sudo debconf-set-selections
    
    local multimedia_packages=(
        # Audio/Video codecs
        "ubuntu-restricted-extras" "libavcodec-extra" "libdvd-pkg"
        "gstreamer1.0-plugins-bad" "gstreamer1.0-plugins-ugly"
        "gstreamer1.0-libav" "gstreamer1.0-vaapi"
        
        # Image formats
        "webp" "heif-gdk-pixbuf" "gimp-heif"
        
        # Fonts
        "fonts-crosextra-carlito" "fonts-crosextra-caladea"
        "fonts-liberation2" "fonts-noto-color-emoji"
        "fonts-firacode" "fonts-powerline"
        
        # Archive support
        "unrar" "p7zip-full" "p7zip-rar"
    )
    
    smart_apt_install "${multimedia_packages[@]}"
    
    # Configure DVD support
    sudo dpkg-reconfigure -f noninteractive libdvd-pkg
}

apply_system_tweaks() {
    log "⚡ Applying advanced system tweaks..."
    
    # Reduce systemd timeout for faster boot
    sudo mkdir -p /etc/systemd/system.conf.d
    sudo tee /etc/systemd/system.conf.d/timeout.conf >/dev/null <<EOF
[Manager]
DefaultTimeoutStartSec=10s
DefaultTimeoutStopSec=10s
EOF
    
    # Improve SSD performance and lifespan
    if [ "$HAS_SSD" = "yes" ] || [ "$HAS_NVME" = "yes" ]; then
        # Enable TRIM
        sudo systemctl enable fstrim.timer
        
        # Reduce swappiness for SSDs
        echo 'vm.swappiness=1' | sudo tee -a /etc/sysctl.d/99-swappiness.conf
    fi
    
    # Increase inotify limits for development
    sudo tee /etc/sysctl.d/99-inotify.conf >/dev/null <<EOF
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=256
EOF
    
    # Optimize TCP for better network performance
    sudo tee /etc/sysctl.d/99-tcp-optimize.conf >/dev/null <<EOF
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
EOF
    
    # Preload frequently used applications
    smart_apt_install preload
    sudo systemctl enable preload
    
    # Configure automatic updates (security only)
    sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
}

enhance_security_privacy() {
    log "🔒 Enhancing security and privacy..."
    
    # Firewall setup
    smart_apt_install ufw gufw
    sudo ufw enable
    
    # Fail2ban for SSH protection
    smart_apt_install fail2ban
    sudo systemctl enable fail2ban
    
    # AppArmor profiles
    smart_apt_install apparmor-profiles apparmor-profiles-extra
    
    # Privacy tools
    smart_apt_install bleachbit
    
    # Disable unnecessary services
    local services_to_disable=(
        "whoopsie.service"  # Error reporting
        "apport.service"    # Crash reporting
        "bluetooth.service" # If no Bluetooth hardware
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            sudo systemctl disable "$service" || true
        fi
    done
}

setup_development_environment() {
    log "💻 Setting up comprehensive development environment..."
    
    local dev_packages=(
        # Version control and collaboration
        "git" "git-lfs" "github-cli" "gitlab-cli"
        
        # Build tools and compilers
        "build-essential" "cmake" "ninja-build" "meson"
        "gcc-12" "g++-12" "clang-14" "llvm-14"
        
        # Programming languages
        "python3-dev" "python3-pip" "python3-venv"
        "nodejs" "npm" "yarn" "golang-go" "rustc" "cargo"
        
        # Development tools
        "vim" "neovim" "code" "tree" "htop" "btop"
        "curl" "wget" "jq" "ripgrep" "fd-find" "bat"
        
        # Database tools
        "postgresql-client" "mysql-client" "sqlite3"
        
        # Network tools
        "nmap" "netcat" "traceroute" "tcpdump"
        
        # System analysis
        "strace" "ltrace" "gdb" "valgrind" "perf-tools-unstable"
    )
    
    smart_apt_install "${dev_packages[@]}"
    
    # Install modern alternatives to classic tools
    install_modern_cli_tools
}

install_modern_cli_tools() {
    log "🛠️ Installing modern CLI tools..."
    
    # Install via cargo (if available)
    if command -v cargo >/dev/null 2>&1; then
        cargo install exa lsd bat fd-find ripgrep tokei git-delta
    fi
    
    # Oh My Zsh (optional, user can enable)
    if ! [ -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
    fi
}

# Enhanced AI/ML installation with hardware optimization
install_ai_stack_optimized() {
    log "🤖 Installing AI/ML stack optimized for your hardware..."
    
    # CUDA only if NVIDIA GPU present
    if [ "$HAS_NVIDIA" = "yes" ]; then
        install_cuda_stack_optimized
    else
        log "⏭️  Skipping CUDA (no NVIDIA GPU detected)"
    fi
    
    # Always install CPU-optimized ML tools
    install_cpu_optimized_ml
    
    # Docker with GPU support if available
    install_docker_optimized
}

install_cuda_stack_optimized() {
    log "🎮 Installing CUDA stack..."
    
    # Use parallel download for CUDA keyring
    temp_dir=$(parallel_download \
        "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb")
    
    if [ -f "$temp_dir/download_0" ]; then
        sudo dpkg -i "$temp_dir/download_0" || true
        sudo apt update
        smart_apt_install cuda-toolkit cuda-drivers
    fi
    
    rm -rf "$temp_dir"
    
    # Optimized CUDA environment
    sudo tee /etc/profile.d/cuda.sh >/dev/null <<EOF
if [ -d /usr/local/cuda ]; then
    export PATH=/usr/local/cuda/bin:\${PATH}
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\${LD_LIBRARY_PATH:-}
    export CUDA_CACHE_PATH=\${XDG_CACHE_HOME:-\$HOME/.cache}/cuda
    # Optimize for ${CPU_CORES} cores
    export OMP_NUM_THREADS=${CPU_CORES}
    export MKL_NUM_THREADS=${CPU_CORES}
fi
EOF
}

install_cpu_optimized_ml() {
    log "🧠 Installing CPU-optimized ML stack..."
    
    # Miniforge with CPU count optimization
    local mf_path="/opt/miniforge3"
    if [ ! -x "$mf_path/bin/mamba" ]; then
        temp_dir=$(parallel_download \
            "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh")
        
        if [ -f "$temp_dir/download_0" ]; then
            sudo bash "$temp_dir/download_0" -b -p "$mf_path"
        fi
        rm -rf "$temp_dir"
    fi
    
    # Configure conda with hardware-aware settings
    sudo "$mf_path/bin/conda" config --system --set solver libmamba
    sudo "$mf_path/bin/conda" config --system --set channel_priority strict
    
    # Create optimized AI environment
    local python_version="3.11"
    if [ "$HAS_AVX512" = "yes" ]; then
        python_version="3.12"  # Better AVX512 support
    fi
    
    local pytorch_variant="cpuonly"
    if [ "$HAS_NVIDIA" = "yes" ]; then
        pytorch_variant="pytorch-cuda=12.1 -c pytorch -c nvidia"
    fi
    
    sudo "$mf_path/bin/mamba" create -y -n ai "python=$python_version" \
        pytorch torchvision torchaudio $pytorch_variant \
        numpy scipy scikit-learn pandas matplotlib seaborn \
        jupyterlab ipywidgets tqdm -c conda-forge || true
    
    # Install optimized packages
    if [ "$HAS_AVX2" = "yes" ]; then
        sudo "$mf_path/envs/ai/bin/pip" install --no-deps \
            intel-extension-for-pytorch || true
    fi
}

install_docker_optimized() {
    log "🐳 Installing Docker with optimizations..."
    
    smart_apt_install docker.io docker-compose-plugin
    sudo usermod -aG docker "$USER" || true
    
    # Docker daemon optimization
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json >/dev/null <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "default-ulimits": {
        "nofile": {
            "name": "nofile",
            "hard": 65536,
            "soft": 65536
        }
    }
}
EOF
    
    if [ "$HAS_NVIDIA" = "yes" ]; then
        # NVIDIA container toolkit
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
            sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        
        echo "deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/\$(. /etc/os-release;echo \$ID\$VERSION_ID) /" | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        
        sudo apt update
        smart_apt_install nvidia-container-toolkit
        sudo nvidia-ctk runtime configure --runtime=docker || true
    fi
    
    sudo systemctl restart docker || true
}

# Enhanced ZFSBootMenu with fallback options
install_zbm_enhanced() {
    log "🥾 Installing ZFSBootMenu with enhancements..."
    
    if ! command -v curl >/dev/null 2>&1; then
        smart_apt_install curl
    fi
    
    local esp_mnt="/boot/efi"
    if ! mountpoint -q "$esp_mnt"; then
        log "❌ EFI System Partition not mounted at $esp_mnt"
        return 1
    fi
    
    sudo mkdir -p "$esp_mnt/EFI/ZBM"
    
    # Try multiple download sources
    local zbm_urls=(
        "https://get.zfsbootmenu.org/efi"
        "https://github.com/zbm-dev/zfsbootmenu/releases/latest/download/zfsbootmenu-efi-x86_64.EFI"
    )
    
    local temp_dir
    temp_dir=$(parallel_download "${zbm_urls[@]}")
    
    local zbm_file
    for file in "$temp_dir"/download_*; do
        if [ -s "$file" ] && file "$file" | grep -q "PE32"; then
            zbm_file="$file"
            break
        fi
    done
    
    if [ -n "$zbm_file" ]; then
        sudo install -m 0644 "$zbm_file" "$esp_mnt/EFI/ZBM/ZFSBootMenu.EFI"
        log "✅ ZFSBootMenu installed successfully"
        
        # Create UEFI boot entry with priority
        if command -v efibootmgr >/dev/null 2>&1; then
            local src_dev
            src_dev=$(findmnt -no SOURCE "$esp_mnt" 2>/dev/null || true)
            if [ -n "$src_dev" ]; then
                local disk
                disk=$(lsblk -no pkname "$src_dev" 2>/dev/null || true)
                local partnum
                partnum=$(echo "$src_dev" | sed -E 's#^/dev/[a-z]+([0-9]+)$#\1#; s#^/dev/nvme[0-9]+n[0-9]+p([0-9]+)$#\1#')
                
                if [ -n "$disk" ] && [ -n "$partnum" ]; then
                    # Remove existing ZBM entries first
                    efibootmgr | grep -i "zfsbootmenu" | cut -d'*' -f1 | sed 's/Boot//' | \
                        xargs -I {} sudo efibootmgr -b {} -B 2>/dev/null || true
                    
                    sudo efibootmgr --create --disk "/dev/$disk" --part "$partnum" \
                        --label "ZFSBootMenu" --loader '\EFI\ZBM\ZFSBootMenu.EFI' || true
                fi
            fi
        fi
    else
        log "❌ Failed to download ZFSBootMenu"
        rm -rf "$temp_dir"
        return 1
    fi
    
    rm -rf "$temp_dir"
}

# System optimization with AI insights
optimize_system_performance() {
    log "⚡ Applying AI-driven system optimizations..."
    
    # CPU governor optimization
    if [ -d /sys/devices/system/cpu/cpufreq ]; then
        echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
    fi
    
    # I/O scheduler optimization based on storage
    for disk in /sys/block/sd* /sys/block/nvme*; do
        if [ -d "$disk" ]; then
            local scheduler="mq-deadline"
            if [[ "$disk" == *nvme* ]]; then
                scheduler="none"  # NVMe works better without scheduler
            fi
            echo "$scheduler" | sudo tee "$disk/queue/scheduler" >/dev/null 2>&1 || true
        fi
    done
    
    # Network optimization
    sudo tee /etc/sysctl.d/99-network-performance.conf >/dev/null <<EOF
# Network performance optimizations
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
EOF
    
    # Memory optimization
    sudo tee /etc/sysctl.d/99-memory-performance.conf >/dev/null <<EOF
# Memory performance optimizations
vm.swappiness = 1
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
EOF
    
    sudo sysctl -p /etc/sysctl.d/99-network-performance.conf || true
    sudo sysctl -p /etc/sysctl.d/99-memory-performance.conf || true
}

# ===== MAIN INSTALLATION FLOW =====

# Detect hardware first
detect_hardware

# Update System with parallel processing
log "🔄 Updating system..."
sudo apt update && sudo apt upgrade -y

# Install core packages intelligently
core_packages=(
    "zfsutils-linux" "efibootmgr" "curl" "wget" "git"
    "software-properties-common" "apt-transport-https"
    "ca-certificates" "gnupg" "lsb-release"
)
smart_apt_install "${core_packages[@]}"

# ZFS Installation (gated)
if [ "${RUN_ZFS:-0}" = "1" ]; then
    log "💾 Setting up ZFS..."
    
    # Create ZFS pool with optimizations
    sudo zpool create -o ashift=12 -o autotrim=on \
        -O normalization=formD -O mountpoint=none \
        -O atime=off -O compression=lz4 \
        -O recordsize=128k \
        "$ZPOOL_NAME" /dev/sdX
    
    # Create datasets
    sudo zfs create -o mountpoint=/ "$ZFS_DATASET"
    sudo zfs create -o mountpoint=/boot "$ZPOOL_NAME/BOOT"
    sudo zfs mount "$ZFS_DATASET"
    
    # Apply hardware-specific optimizations
    optimize_zfs_for_hardware "$ZPOOL_NAME"
    
    # Install base system
    sudo debootstrap --arch=amd64 focal /mnt http://archive.ubuntu.com/ubuntu/
    
    # Configure boot
    install_zbm_enhanced
fi

# Install GPU packages based on detection
gpu_packages=($(get_gpu_packages))
if [ ${#gpu_packages[@]} -gt 0 ]; then
    log "🎮 Installing GPU packages..."
    smart_apt_install "${gpu_packages[@]}"
fi

# Enhanced AI/ML stack
install_ai_stack_optimized

# System optimizations
optimize_system_performance

# Enhanced ZFSBootMenu (standalone)
install_zbm_enhanced

log "✅ Installation complete! Check $LOG_FILE for details."
log "🔄 Reboot recommended to apply all optimizations."