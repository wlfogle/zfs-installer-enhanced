#!/bin/bash
set -euo pipefail

# 🚀 AI Powerhouse Gaming Post-Installation Script
# For existing ZFS systems - adds all gaming, AI/ML, and self-hosting features

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/post-install-ai-powerhouse-$(date +%Y%m%d-%H%M%S).log"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Enhanced logging
log() {
    local category="${1:-INFO}"
    local message="${2:-$1}"
    local timestamp=$(date '+%H:%M:%S')
    
    case $category in
        "ERROR") echo -e "[${RED}$timestamp ERROR${NC}] $message" | tee -a "$LOG_FILE" ;;
        "SUCCESS") echo -e "[${GREEN}$timestamp SUCCESS${NC}] $message" | tee -a "$LOG_FILE" ;;
        "WARNING") echo -e "[${YELLOW}$timestamp WARNING${NC}] $message" | tee -a "$LOG_FILE" ;;
        "AI") echo -e "[${PURPLE}$timestamp AI/ML${NC}] $message" | tee -a "$LOG_FILE" ;;
        "GAMING") echo -e "[${BLUE}$timestamp GAMING${NC}] $message" | tee -a "$LOG_FILE" ;;
        "MEDIA") echo -e "[${CYAN}$timestamp MEDIA${NC}] $message" | tee -a "$LOG_FILE" ;;
        *) echo -e "[${CYAN}$timestamp${NC}] $message" | tee -a "$LOG_FILE" ;;
    esac
}

# Progress display
show_phase() {
    local phase="$1"
    local title="$2"
    local description="$3"
    
    echo -e "\n${BOLD}${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${PURPLE}║${NC} ${BOLD}${YELLOW}Phase $phase${NC} ${BOLD}${PURPLE}║${NC} ${BOLD}${GREEN}$title${NC}"
    echo -e "${BOLD}${PURPLE}║${NC} ${CYAN}$description${NC}"
    echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
}

# Hardware detection
detect_system_hardware() {
    log "🔍 Detecting system hardware and capabilities..."
    
    # CPU detection
    CPU_CORES=$(nproc)
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    TOTAL_RAM_GB=$(($(awk '/MemTotal:/ {print $2}' /proc/meminfo) / 1024 / 1024))
    
    # Advanced CPU features
    HAS_AVX2=$(grep -q avx2 /proc/cpuinfo && echo "yes" || echo "no")
    HAS_AVX512=$(grep -q avx512 /proc/cpuinfo && echo "yes" || echo "no")
    HAS_VIRTUALIZATION=$(egrep -c '(vmx|svm)' /proc/cpuinfo > 0 && echo "yes" || echo "no")
    
    # GPU detection
    HAS_NVIDIA=$(lspci | grep -i nvidia >/dev/null && echo "yes" || echo "no")
    HAS_AMD_GPU=$(lspci | grep -i "amd.*radeon\|amd.*graphics" >/dev/null && echo "yes" || echo "no")
    HAS_INTEL_GPU=$(lspci | grep -i "intel.*graphics\|intel.*display" >/dev/null && echo "yes" || echo "no")
    
    # Storage detection
    HAS_NVME=$(lsblk -d -o NAME,ROTA | grep -q "nvme.*0" && echo "yes" || echo "no")
    HAS_ZFS=$(command -v zfs >/dev/null && echo "yes" || echo "no")
    
    # Export variables
    export CPU_CORES CPU_MODEL TOTAL_RAM_GB HAS_AVX2 HAS_AVX512 HAS_VIRTUALIZATION
    export HAS_NVIDIA HAS_AMD_GPU HAS_INTEL_GPU HAS_NVME HAS_ZFS
    
    log "📊 System detected:"
    log "  CPU: $CPU_MODEL ($CPU_CORES cores)"
    log "  Features: AVX2:$HAS_AVX2 AVX512:$HAS_AVX512 VT:$HAS_VIRTUALIZATION"
    log "  GPU: NVIDIA:$HAS_NVIDIA AMD:$HAS_AMD_GPU Intel:$HAS_INTEL_GPU"
    log "  Storage: NVMe:$HAS_NVME ZFS:$HAS_ZFS"
    log "  RAM: ${TOTAL_RAM_GB}GB"
}

# Smart package installer
smart_apt_install() {
    local packages=("$@")
    local failed_packages=()
    
    # Update if needed
    if [ ! -f /var/lib/apt/periodic/update-success-stamp ] || \
       [ "$(find /var/lib/apt/periodic/update-success-stamp -mmin +60 2>/dev/null)" ]; then
        sudo apt update
    fi
    
    # Try batch install first
    if ! sudo apt install -y "${packages[@]}" 2>/dev/null; then
        # Install individually if batch fails
        for package in "${packages[@]}"; do
            if ! sudo apt install -y "$package" 2>/dev/null; then
                failed_packages+=("$package")
            fi
        done
    fi
    
    if [ ${#failed_packages[@]} -gt 0 ]; then
        log "WARNING" "Failed to install: ${failed_packages[*]}"
    fi
}

# Phase 1: Foundation and repositories
setup_foundation_repositories() {
    show_phase "1" "Foundation Setup" "Repositories, base packages, container runtime"
    
    log "🏗️ Setting up foundation repositories and packages..."
    
    # Enable all Ubuntu repositories
    sudo add-apt-repository -y universe multiverse restricted
    
    # Gaming repositories
    sudo add-apt-repository -y ppa:lutris-team/lutris
    sudo add-apt-repository -y ppa:tkashkin/gamehub
    sudo add-apt-repository -y ppa:libretro/stable
    sudo add-apt-repository -y ppa:kisak/kisak-mesa
    sudo add-apt-repository -y ppa:flexiondotorg/mangohud
    sudo add-apt-repository -y ppa:obsproject/obs-studio
    sudo add-apt-repository -y ppa:pipewire-debian/pipewire-upstream
    
    # Wine repository
    sudo mkdir -p /etc/apt/keyrings
    wget -O /tmp/winehq.key https://dl.winehq.org/wine-builds/winehq.key
    sudo cp /tmp/winehq.key /etc/apt/keyrings/winehq-archive.key
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/winehq-archive.key] https://dl.winehq.org/wine-builds/ubuntu/ jammy main" | \
        sudo tee /etc/apt/sources.list.d/winehq.list
    
    # Docker repository
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list
    
    # VSCode repository
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
        sudo tee /etc/apt/sources.list.d/vscode.list
    
    sudo apt update
    
    # Install Docker
    smart_apt_install docker.io docker-compose-plugin
    sudo usermod -aG docker "$USER"
    
    # Docker optimization for AI/Gaming
    sudo tee /etc/docker/daemon.json >/dev/null <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "5"
    },
    "storage-driver": "overlay2",
    "default-ulimits": {
        "nofile": {
            "name": "nofile",
            "hard": 1048576,
            "soft": 1048576
        }
    },
    "default-shm-size": "2gb"
}
EOF
    
    # Install Flatpak
    smart_apt_install flatpak gnome-software-plugin-flatpak
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    
    log "SUCCESS" "Foundation setup completed"
}

# Phase 2: Ultimate Gaming Stack
install_ultimate_gaming_stack() {
    show_phase "2" "Ultimate Gaming Stack" "Steam, Wine, Emulation, VR, Performance tools"
    
    log "GAMING" "Installing ultimate gaming ecosystem..."
    
    # Enable 32-bit architecture for gaming
    sudo dpkg --add-architecture i386
    sudo apt update
    
    # Core gaming platforms
    local gaming_packages=(
        # Steam ecosystem
        "steam-installer" "steam-devices" "gamemode"
        
        # Wine and compatibility
        "winehq-staging" "winetricks" "playonlinux" "q4wine"
        
        # Game launchers
        "lutris" "gamehub" "heroic" "bottles"
        
        # Performance and monitoring
        "mangohud" "goverlay" "obs-studio"
        
        # Native Linux games
        "0ad" "supertuxkart" "minetest" "wesnoth" "xonotic"
        
        # Emulation
        "retroarch" "dolphin-emu" "ppsspp" "pcsx2"
        
        # Game development
        "godot3" "blender" "krita"
        
        # Audio and video
        "pipewire" "wireplumber" "pavucontrol" "qjackctl"
        
        # Controllers and input
        "jstest-gtk" "antimicrox"
    )
    
    smart_apt_install "${gaming_packages[@]}"
    
    # Wine dependencies for gaming
    local wine_deps=(
        "libwine:i386" "wine32" "wine64"
        "libgl1-mesa-glx:i386" "libvulkan1:i386"
        "libpulse0:i386" "libasound2-plugins:i386"
        "libfreetype6:i386" "libfontconfig1:i386"
        "mesa-vulkan-drivers:i386"
    )
    
    smart_apt_install "${wine_deps[@]}"
    
    # Install Steam manually if package failed
    if ! command -v steam >/dev/null 2>&1; then
        wget https://steamcdn-a.akamaihd.net/client/installer/steam.deb
        sudo dpkg -i steam.deb || sudo apt-get install -f -y
        rm -f steam.deb
    fi
    
    # Flatpak gaming applications
    local flatpak_games=(
        "com.valvesoftware.Steam"
        "net.lutris.Lutris"
        "com.heroicgameslauncher.hgl"
        "com.usebottles.bottles"
        "org.prismlauncher.PrismLauncher"
        "com.moonlight_stream.Moonlight"
        "org.DolphinEmu.dolphin-emu"
        "net.rpcs3.RPCS3"
        "org.ppsspp.PPSSPP"
        "com.obsproject.Studio"
    )
    
    for app in "${flatpak_games[@]}"; do
        sudo flatpak install -y flathub "$app" 2>/dev/null || log "WARNING" "Failed to install $app"
    done
    
    # Install ProtonPlus
    mkdir -p "$HOME/.local/bin"
    wget -O "$HOME/.local/bin/protonplus" https://github.com/Vysp3r/ProtonPlus/releases/latest/download/ProtonPlus-Linux.AppImage
    chmod +x "$HOME/.local/bin/protonplus"
    
    # Install PortProton
    if [ ! -d "$HOME/.local/share/PortProton" ]; then
        git clone https://github.com/Castro-Fidel/PortProton.git "$HOME/.local/share/PortProton"
        chmod +x "$HOME/.local/share/PortProton/PortProton"
    fi
    
    # Enable gamemode
    sudo systemctl enable --now gamemode
    
    log "SUCCESS" "Ultimate gaming stack installed"
}

# Phase 3: AI/ML Development Environment
setup_ai_ml_environment() {
    show_phase "3" "AI/ML Development" "CUDA, PyTorch, Ollama, Jupyter, Development tools"
    
    log "AI" "Setting up AI/ML development environment..."
    
    # Install development tools
    smart_apt_install code python3-dev python3-pip python3-venv nodejs npm git git-lfs
    
    # CUDA setup (if NVIDIA GPU present)
    if [[ "$HAS_NVIDIA" == "yes" ]]; then
        log "AI" "Installing CUDA toolkit..."
        wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
        sudo dpkg -i cuda-keyring_1.1-1_all.deb
        sudo apt update
        smart_apt_install cuda-toolkit-12-3 nvidia-container-toolkit
        
        # NVIDIA container toolkit
        sudo nvidia-ctk runtime configure --runtime=docker
        sudo systemctl restart docker
        
        rm -f cuda-keyring_1.1-1_all.deb
    fi
    
    # Install Miniforge (conda alternative with mamba)
    if [ ! -x "/opt/miniforge3/bin/mamba" ]; then
        wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
        sudo bash Miniforge3-Linux-x86_64.sh -b -p /opt/miniforge3
        rm Miniforge3-Linux-x86_64.sh
        
        # Make available to all users
        sudo chown -R root:root /opt/miniforge3
        sudo chmod -R 755 /opt/miniforge3
    fi
    
    # Create AI environment
    sudo /opt/miniforge3/bin/mamba create -y -n ai python=3.11 -c conda-forge
    
    # Install PyTorch based on hardware
    if [[ "$HAS_NVIDIA" == "yes" ]]; then
        sudo /opt/miniforge3/envs/ai/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    else
        sudo /opt/miniforge3/envs/ai/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    fi
    
    # Install AI/ML packages
    sudo /opt/miniforge3/envs/ai/bin/pip install \
        transformers accelerate diffusers \
        jupyterlab ipywidgets \
        matplotlib seaborn pandas numpy scipy scikit-learn \
        mlflow tensorboard
    
    # Install Ollama
    curl -fsSL https://ollama.ai/install.sh | sh
    
    # Create Ollama systemd service
    sudo tee /etc/systemd/system/ollama.service >/dev/null <<EOF
[Unit]
Description=Ollama Server
After=network-online.target

[Service]
Type=exec
ExecStart=/usr/local/bin/ollama serve
Environment="OLLAMA_HOST=0.0.0.0:11434"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl enable --now ollama
    
    # Pull some models based on system RAM
    if [[ $TOTAL_RAM_GB -ge 16 ]]; then
        ollama pull llama2:7b &
        ollama pull codellama:7b &
    fi
    
    # Install VS Code extensions
    code --install-extension ms-python.python
    code --install-extension ms-toolsai.jupyter
    code --install-extension github.copilot
    
    log "SUCCESS" "AI/ML development environment ready"
}

# Phase 4: Media Center and Self-Hosting
setup_media_selfhosting() {
    show_phase "4" "Media & Self-Hosting" "Jellyfin, *arr stack, Nextcloud, Monitoring"
    
    log "MEDIA" "Setting up media center and self-hosting..."
    
    # Create directories
    mkdir -p "$HOME/selfhosting"/{traefik,jellyfin,arr-stack,nextcloud,monitoring}
    mkdir -p /media/{movies,tv,downloads}
    
    # Docker networks
    docker network create proxy 2>/dev/null || true
    
    # Traefik (Reverse Proxy)
    tee "$HOME/selfhosting/traefik/docker-compose.yml" >/dev/null <<EOF
version: '3.8'
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro
    networks:
      - proxy
    labels:
      - "traefik.enable=true"

networks:
  proxy:
    external: true
EOF
    
    tee "$HOME/selfhosting/traefik/traefik.yml" >/dev/null <<EOF
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
EOF
    
    # Jellyfin (Media Server)
    tee "$HOME/selfhosting/jellyfin/docker-compose.yml" >/dev/null <<EOF
version: '3.8'
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - "8096:8096"
    volumes:
      - ./config:/config
      - ./cache:/cache
      - /media:/media:ro
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.jellyfin.rule=Host(\`jellyfin.local\`)"
EOF
    
    # *arr stack (Media automation)
    tee "$HOME/selfhosting/arr-stack/docker-compose.yml" >/dev/null <<EOF
version: '3.8'
services:
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
    volumes:
      - ./sonarr:/config
      - /media:/media
    ports:
      - "8989:8989"
    restart: unless-stopped
    networks:
      - proxy

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
    volumes:
      - ./radarr:/config
      - /media:/media
    ports:
      - "7878:7878"
    restart: unless-stopped
    networks:
      - proxy

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=1000
      - PGID=1000
    volumes:
      - ./prowlarr:/config
    ports:
      - "9696:9696"
    restart: unless-stopped
    networks:
      - proxy

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - PUID=1000
      - PGID=1000
      - WEBUI_PORT=8081
    volumes:
      - ./qbittorrent:/config
      - /media/downloads:/downloads
    ports:
      - "8081:8081"
      - "6881:6881"
    restart: unless-stopped
    networks:
      - proxy

networks:
  proxy:
    external: true
EOF
    
    # Monitoring stack
    tee "$HOME/selfhosting/monitoring/docker-compose.yml" >/dev/null <<EOF
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    restart: unless-stopped
    networks:
      - proxy

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    volumes:
      - ./grafana-data:/var/lib/grafana
    restart: unless-stopped
    networks:
      - proxy

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    restart: unless-stopped
    networks:
      - proxy

networks:
  proxy:
    external: true
EOF
    
    # Prometheus config
    tee "$HOME/selfhosting/monitoring/prometheus.yml" >/dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
  - job_name: 'ollama'
    static_configs:
      - targets: ['host.docker.internal:11434']
EOF
    
    # Start services
    cd "$HOME/selfhosting/traefik" && docker compose up -d
    cd "$HOME/selfhosting/jellyfin" && docker compose up -d
    cd "$HOME/selfhosting/arr-stack" && docker compose up -d
    cd "$HOME/selfhosting/monitoring" && docker compose up -d
    
    log "SUCCESS" "Media and self-hosting services started"
}

# Phase 5: System Optimizations
apply_system_optimizations() {
    show_phase "5" "System Optimizations" "Gaming, AI/ML, and performance tuning"
    
    log "⚡ Applying comprehensive system optimizations..."
    
    # Gaming and AI optimized sysctl
    sudo tee /etc/sysctl.d/99-ai-gaming-performance.conf >/dev/null <<EOF
# AI Powerhouse Gaming optimizations
vm.max_map_count=2147483642
vm.swappiness=1
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10

# Network optimizations
net.core.rmem_default=262144
net.core.rmem_max=134217728
net.core.wmem_default=262144
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
net.core.netdev_max_backlog=30000
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3

# File system optimizations
fs.file-max=2097152
fs.inotify.max_user_watches=1048576
fs.inotify.max_user_instances=256

# Gaming optimizations
kernel.sched_child_runs_first=0
kernel.sched_autogroup_enabled=1
EOF
    
    sudo sysctl -p /etc/sysctl.d/99-ai-gaming-performance.conf
    
    # Audio optimization
    mkdir -p "$HOME/.config/pulse"
    tee "$HOME/.config/pulse/daemon.conf" >/dev/null <<EOF
# Gaming audio optimizations
default-sample-format = float32le
default-sample-rate = 48000
default-sample-channels = 2
default-fragments = 2
default-fragment-size-msec = 4
high-priority = yes
nice-level = -11
realtime-scheduling = yes
realtime-priority = 9
EOF
    
    # GPU optimizations
    if [[ "$HAS_NVIDIA" == "yes" ]]; then
        # NVIDIA gaming optimizations
        tee "$HOME/.nvidia-settings-rc" >/dev/null <<EOF
[gpu:0]/GPUPowerMizerMode=1
[gpu:0]/GPUMemoryTransferRateOffset[4]=1000
[gpu:0]/GPUGraphicsClockOffset[4]=100
EOF
    fi
    
    # Install multimedia codecs
    echo 'ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true' | sudo debconf-set-selections
    smart_apt_install ubuntu-restricted-extras libavcodec-extra libdvd-pkg
    
    # Enable TRIM for SSDs
    if [[ "$HAS_NVME" == "yes" ]]; then
        sudo systemctl enable fstrim.timer
    fi
    
    log "SUCCESS" "System optimizations applied"
}

# Phase 6: Security and Privacy
setup_security_privacy() {
    show_phase "6" "Security & Privacy" "Firewall, fail2ban, privacy tools"
    
    log "🛡️ Setting up security and privacy..."
    
    # Firewall
    smart_apt_install ufw
    sudo ufw --force enable
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow common gaming and media ports
    sudo ufw allow 22    # SSH
    sudo ufw allow 80    # HTTP
    sudo ufw allow 443   # HTTPS
    sudo ufw allow 8080  # Traefik
    sudo ufw allow 8096  # Jellyfin
    sudo ufw allow 27015 # Steam
    
    # Install security tools
    smart_apt_install fail2ban bleachbit
    sudo systemctl enable --now fail2ban
    
    # Privacy optimizations
    sudo systemctl disable whoopsie.service || true
    sudo systemctl disable apport.service || true
    
    log "SUCCESS" "Security and privacy configured"
}

# Phase 7: Final setup and management scripts
create_management_tools() {
    show_phase "7" "Management Tools" "Scripts, automation, monitoring"
    
    log "🛠️ Creating management tools..."
    
    # Main management script
    tee "$HOME/ai-powerhouse-manager.sh" >/dev/null <<'EOF'
#!/bin/bash
# AI Powerhouse Gaming Manager

case $1 in
    "start")
        echo "🚀 Starting AI Powerhouse services..."
        sudo systemctl start ollama docker
        cd ~/selfhosting/traefik && docker compose up -d
        cd ~/selfhosting/jellyfin && docker compose up -d
        cd ~/selfhosting/arr-stack && docker compose up -d
        cd ~/selfhosting/monitoring && docker compose up -d
        echo "✅ Services started"
        ;;
    "stop")
        echo "🛑 Stopping services..."
        cd ~/selfhosting/monitoring && docker compose down
        cd ~/selfhosting/arr-stack && docker compose down
        cd ~/selfhosting/jellyfin && docker compose down
        cd ~/selfhosting/traefik && docker compose down
        echo "✅ Services stopped"
        ;;
    "status")
        echo "📊 Service Status:"
        echo "Ollama: $(systemctl is-active ollama)"
        echo "Docker: $(systemctl is-active docker)"
        echo "Containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}"
        ;;
    "update")
        echo "🔄 Updating system..."
        sudo apt update && sudo apt upgrade -y
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}" | head -10
        ;;
    *)
        echo "Usage: $0 {start|stop|status|update}"
        echo ""
        echo "🎮 Gaming URLs:"
        echo "  Steam: Launch from applications"
        echo "  MangoHUD: Use 'mangohud %command%' in Steam launch options"
        echo ""
        echo "🤖 AI/ML Services:"
        echo "  Ollama: http://localhost:11434"
        echo "  Jupyter: /opt/miniforge3/envs/ai/bin/jupyter lab"
        echo ""
        echo "📺 Media Services:"
        echo "  Traefik: http://localhost:8080"
        echo "  Jellyfin: http://localhost:8096"
        echo "  Sonarr: http://localhost:8989"
        echo "  Radarr: http://localhost:7878"
        echo "  Prowlarr: http://localhost:9696"
        echo "  qBittorrent: http://localhost:8081"
        echo "  Grafana: http://localhost:3000"
        echo "  Prometheus: http://localhost:9090"
        ;;
esac
EOF
    
    chmod +x "$HOME/ai-powerhouse-manager.sh"
    
    # Create desktop shortcut
    mkdir -p "$HOME/Desktop"
    tee "$HOME/Desktop/AI-Powerhouse-Manager.desktop" >/dev/null <<EOF
[Desktop Entry]
Version=1.0
Name=AI Powerhouse Manager
Comment=Manage AI Powerhouse Gaming services
Exec=gnome-terminal -- $HOME/ai-powerhouse-manager.sh status
Icon=computer
Terminal=false
Type=Application
Categories=System;
EOF
    
    chmod +x "$HOME/Desktop/AI-Powerhouse-Manager.desktop"
    
    # ZFS snapshot automation (if ZFS available)
    if [[ "$HAS_ZFS" == "yes" ]]; then
        sudo tee /usr/local/bin/zfs-gaming-snapshot >/dev/null <<'EOF'
#!/bin/bash
# Gaming-focused ZFS snapshots
zfs snapshot rpool/ROOT/$(hostname)@gaming-$(date +%Y%m%d-%H%M%S)
# Keep last 5 gaming snapshots
zfs list -H -t snapshot | grep "rpool/ROOT/$(hostname)@gaming-" | sort | head -n -5 | awk '{print $1}' | xargs -r -n1 zfs destroy
EOF
        
        sudo chmod +x /usr/local/bin/zfs-gaming-snapshot
        
        # Add to crontab for weekly snapshots
        (crontab -l 2>/dev/null; echo "0 2 * * 0 /usr/local/bin/zfs-gaming-snapshot") | crontab -
    fi
    
    log "SUCCESS" "Management tools created"
}

# Installation summary
show_installation_summary() {
    echo -e "\n${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║${NC}           ${BOLD}${YELLOW}🚀 AI POWERHOUSE GAMING POST-INSTALL COMPLETE${NC}           ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}📊 Installation Summary:${NC}"
    echo -e "  • System: $CPU_MODEL ($CPU_CORES cores, ${TOTAL_RAM_GB}GB RAM)"
    echo -e "  • GPU: NVIDIA:$HAS_NVIDIA AMD:$HAS_AMD_GPU Intel:$HAS_INTEL_GPU"
    echo -e "  • Storage: NVMe:$HAS_NVME ZFS:$HAS_ZFS"
    echo -e "  • Log: ${GREEN}$LOG_FILE${NC}"
    
    echo -e "\n${BLUE}🎮 Gaming Platforms:${NC}"
    echo -e "  • Steam with optimizations"
    echo -e "  • Epic Games (Heroic Launcher)"
    echo -e "  • GOG Games (via Lutris/Heroic)"
    echo -e "  • Windows Games (Wine/Proton)"
    echo -e "  • Emulation (RetroArch, Dolphin, etc.)"
    echo -e "  • MangoHUD for performance monitoring"
    
    echo -e "\n${PURPLE}🤖 AI/ML Development:${NC}"
    echo -e "  • Ollama API: ${GREEN}http://localhost:11434${NC}"
    echo -e "  • Jupyter: ${GREEN}/opt/miniforge3/envs/ai/bin/jupyter lab${NC}"
    echo -e "  • CUDA support: $([[ $HAS_NVIDIA == yes ]] && echo "✅ Available" || echo "❌ No NVIDIA GPU")"
    
    echo -e "\n${CYAN}📺 Media & Self-Hosting:${NC}"
    echo -e "  • Traefik Dashboard: ${GREEN}http://localhost:8080${NC}"
    echo -e "  • Jellyfin: ${GREEN}http://localhost:8096${NC}"
    echo -e "  • Sonarr: ${GREEN}http://localhost:8989${NC}"
    echo -e "  • Radarr: ${GREEN}http://localhost:7878${NC}"
    echo -e "  • Prowlarr: ${GREEN}http://localhost:9696${NC}"
    echo -e "  • qBittorrent: ${GREEN}http://localhost:8081${NC}"
    echo -e "  • Grafana: ${GREEN}http://localhost:3000${NC}"
    
    echo -e "\n${YELLOW}🛠️ Management:${NC}"
    echo -e "  • Manager script: ${GREEN}./ai-powerhouse-manager.sh${NC}"
    echo -e "  • Desktop shortcut: AI Powerhouse Manager"
    echo -e "  • ZFS snapshots: $([[ $HAS_ZFS == yes ]] && echo "✅ Weekly automated" || echo "❌ No ZFS")"
    
    echo -e "\n${GREEN}🎯 Quick Start:${NC}"
    echo -e "  1. ${BOLD}Reboot${NC} to apply all optimizations"
    echo -e "  2. Run ${GREEN}./ai-powerhouse-manager.sh status${NC}"
    echo -e "  3. Launch Steam and set launch options with MangoHUD"
    echo -e "  4. Access Jellyfin to set up your media library"
    echo -e "  5. Configure Ollama with: ${GREEN}ollama pull llama2${NC}"
    
    echo -e "\n${BOLD}${GREEN}🎮🤖 Your AI Powerhouse Gaming system is ready!${NC}\n"
}

# Main execution
main() {
    echo -e "${BOLD}${CYAN}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║               🚀 AI POWERHOUSE GAMING POST-INSTALLATION 🎮                   ║
    ║                                                                              ║
    ║          Adding Gaming + AI/ML + Self-Hosting to your ZFS system            ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
    
    # Check if running on existing system
    if [[ $EUID -eq 0 ]]; then
        log "ERROR" "Don't run as root. Use your regular user account."
        exit 1
    fi
    
    # Detect system and hardware
    detect_system_hardware
    
    # Create directories
    mkdir -p "$HOME/selfhosting" "$HOME/.local/bin"
    
    # Execute installation phases
    setup_foundation_repositories
    install_ultimate_gaming_stack
    setup_ai_ml_environment
    setup_media_selfhosting
    apply_system_optimizations
    setup_security_privacy
    create_management_tools
    
    # Show summary
    show_installation_summary
    
    log "SUCCESS" "AI Powerhouse Gaming post-installation completed!"
    echo -e "\n${YELLOW}⚠️  Reboot recommended to apply all optimizations${NC}\n"
}

# Run main installation
main "$@"