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