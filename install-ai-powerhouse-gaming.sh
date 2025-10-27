#!/bin/bash
set -euo pipefail

# 🚀 AI Powerhouse Gaming Setup - Ultimate Development & Gaming Environment
# Combines: Gaming Distros + AI/ML Development + Self-Hosting + Media Stack + Virtualization

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/ai-powerhouse-gaming-$(date +%Y%m%d-%H%M%S).log"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Enhanced logging with categories
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

# Enhanced progress display with ASCII art
show_phase() {
    local phase="$1"
    local title="$2"
    local description="$3"
    
    echo -e "\n${BOLD}${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${PURPLE}║${NC} ${BOLD}${YELLOW}Phase $phase${NC} ${BOLD}${PURPLE}║${NC} ${BOLD}${GREEN}$title${NC}"
    echo -e "${BOLD}${PURPLE}║${NC} ${CYAN}$description${NC}"
    echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
}

# System capabilities assessment
assess_system_capabilities() {
    log "🔍 Assessing system capabilities for AI Powerhouse Gaming..."
    
    # Hardware detection (enhanced)
    CPU_CORES=$(nproc)
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    TOTAL_RAM_GB=$(($(awk '/MemTotal:/ {print $2}' /proc/meminfo) / 1024 / 1024))
    
    # Advanced CPU features
    HAS_AVX2=$(grep -q avx2 /proc/cpuinfo && echo "yes" || echo "no")
    HAS_AVX512=$(grep -q avx512 /proc/cpuinfo && echo "yes" || echo "no")
    HAS_VIRTUALIZATION=$(egrep -c '(vmx|svm)' /proc/cpuinfo > 0 && echo "yes" || echo "no")
    
    # GPU capabilities
    HAS_NVIDIA=$(lspci | grep -i nvidia >/dev/null && echo "yes" || echo "no")
    HAS_AMD_GPU=$(lspci | grep -i "amd.*radeon\|amd.*graphics" >/dev/null && echo "yes" || echo "no")
    HAS_INTEL_GPU=$(lspci | grep -i "intel.*graphics\|intel.*display" >/dev/null && echo "yes" || echo "no")
    
    # Storage capabilities
    HAS_NVME=$(lsblk -d -o NAME,ROTA | grep -q "nvme.*0" && echo "yes" || echo "no")
    TOTAL_STORAGE_GB=$(df / | awk 'NR==2 {print int($2/1024/1024)}')
    
    # Network capabilities
    NETWORK_SPEED=$(ethtool $(ip route | grep default | awk '{print $5}' | head -1) 2>/dev/null | grep "Speed:" | awk '{print $2}' || echo "Unknown")
    
    # Container runtime detection
    HAS_DOCKER=$(command -v docker >/dev/null && echo "yes" || echo "no")
    HAS_PODMAN=$(command -v podman >/dev/null && echo "yes" || echo "no")
    
    log "📊 System Assessment Complete:"
    log "  CPU: $CPU_MODEL ($CPU_CORES cores)"
    log "  RAM: ${TOTAL_RAM_GB}GB | Storage: ${TOTAL_STORAGE_GB}GB"
    log "  Features: AVX2:$HAS_AVX2 AVX512:$HAS_AVX512 VT:$HAS_VIRTUALIZATION"
    log "  GPU: NVIDIA:$HAS_NVIDIA AMD:$HAS_AMD_GPU Intel:$HAS_INTEL_GPU"
    log "  Storage: NVMe:$HAS_NVME | Network: $NETWORK_SPEED"
    
    # Export for other phases
    export CPU_CORES CPU_MODEL TOTAL_RAM_GB HAS_AVX2 HAS_AVX512 HAS_VIRTUALIZATION
    export HAS_NVIDIA HAS_AMD_GPU HAS_INTEL_GPU HAS_NVME TOTAL_STORAGE_GB
    export HAS_DOCKER HAS_PODMAN NETWORK_SPEED
    
    # Capability recommendations
    recommend_installation_profile
}

# AI-powered installation profile recommendation
recommend_installation_profile() {
    log "🤖 Analyzing optimal installation profile..."
    
    # Score different capabilities
    local gaming_score=0
    local ai_score=0
    local media_score=0
    local selfhost_score=0
    
    # Gaming capability scoring
    [[ $HAS_NVIDIA == "yes" ]] && ((gaming_score+=30))
    [[ $HAS_AMD_GPU == "yes" ]] && ((gaming_score+=25))
    [[ $TOTAL_RAM_GB -ge 16 ]] && ((gaming_score+=20))
    [[ $HAS_NVME == "yes" ]] && ((gaming_score+=15))
    [[ $CPU_CORES -ge 8 ]] && ((gaming_score+=10))
    
    # AI/ML capability scoring
    [[ $HAS_NVIDIA == "yes" ]] && ((ai_score+=40))
    [[ $HAS_AVX2 == "yes" ]] && ((ai_score+=20))
    [[ $HAS_AVX512 == "yes" ]] && ((ai_score+=30))
    [[ $TOTAL_RAM_GB -ge 32 ]] && ((ai_score+=10))
    
    # Media/Self-hosting scoring
    [[ $TOTAL_STORAGE_GB -ge 500 ]] && ((media_score+=20)) && ((selfhost_score+=20))
    [[ $CPU_CORES -ge 8 ]] && ((media_score+=15)) && ((selfhost_score+=15))
    [[ $HAS_VIRTUALIZATION == "yes" ]] && ((selfhost_score+=30))
    [[ $TOTAL_RAM_GB -ge 32 ]] && ((selfhost_score+=25))
    
    log "📈 Capability Scores:"
    log "  Gaming: $gaming_score/100"
    log "  AI/ML: $ai_score/100" 
    log "  Media: $media_score/100"
    log "  Self-hosting: $selfhost_score/100"
    
    # Determine recommended profile
    local max_score=$gaming_score
    local recommended_profile="gaming-focused"
    
    [[ $ai_score -gt $max_score ]] && max_score=$ai_score && recommended_profile="ai-development"
    [[ $((media_score + selfhost_score)) -gt $max_score ]] && recommended_profile="media-powerhouse"
    [[ $((gaming_score + ai_score)) -gt 120 ]] && recommended_profile="ultimate-powerhouse"
    
    log "🎯 Recommended Profile: $recommended_profile"
    export RECOMMENDED_PROFILE="$recommended_profile"
}

# Enhanced installation options with AI recommendations
show_enhanced_installation_options() {
    echo -e "\n${BOLD}${CYAN}🚀 AI Powerhouse Gaming Setup${NC}"
    echo -e "${BOLD}Recommended Profile: ${GREEN}$RECOMMENDED_PROFILE${NC}\n"
    
    echo -e "${GREEN}1)${NC} ${BOLD}Ultimate Powerhouse${NC} (Recommended for high-end systems)"
    echo -e "   ✅ Complete gaming ecosystem (all distros' best)"
    echo -e "   ✅ Full AI/ML development stack (CUDA, PyTorch, Ollama)"
    echo -e "   ✅ Complete media center (Jellyfin, *arr stack)"
    echo -e "   ✅ Self-hosting platform (Traefik, Portainer, monitoring)"
    echo -e "   ✅ Virtualization (KVM/QEMU, Docker orchestration)"
    echo -e "   ✅ ZFS root with snapshots and encryption"
    echo
    
    echo -e "${GREEN}2)${NC} ${BOLD}Gaming + AI Development${NC}"
    echo -e "   ✅ Ultimate gaming setup (Steam, Wine, Emulation, VR)"
    echo -e "   ✅ AI/ML development environment"
    echo -e "   ✅ Development tools and containers"
    echo -e "   ✅ Performance optimizations"
    echo
    
    echo -e "${GREEN}3)${NC} ${BOLD}Media & Self-Hosting Powerhouse${NC}"
    echo -e "   ✅ Complete media center with automation"
    echo -e "   ✅ Self-hosting services (Nextcloud, Bitwarden, etc.)"
    echo -e "   ✅ Monitoring and automation"
    echo -e "   ✅ Backup and disaster recovery"
    echo
    
    echo -e "${GREEN}4)${NC} ${BOLD}Gaming Focus${NC} (For gaming-first setups)"
    echo -e "   ✅ All gaming platforms and emulation"
    echo -e "   ✅ Streaming and content creation"
    echo -e "   ✅ Performance optimization"
    echo -e "   ✅ Hardware-specific tuning"
    echo
    
    echo -e "${GREEN}5)${NC} ${BOLD}Custom Modular Installation${NC}"
    echo -e "   ✅ Choose specific components"
    echo -e "   ✅ Fine-grained control"
    echo
    
    read -p "Select installation type (1-5): " INSTALL_OPTION
    
    case $INSTALL_OPTION in
        1) INSTALL_TYPE="ultimate-powerhouse" ;;
        2) INSTALL_TYPE="gaming-ai-dev" ;;
        3) INSTALL_TYPE="media-selfhost" ;;
        4) INSTALL_TYPE="gaming-focus" ;;
        5) INSTALL_TYPE="custom-modular" ;;
        *) log "ERROR" "Invalid option selected" && exit 1 ;;
    esac
    
    export INSTALL_TYPE
    log "Selected installation type: $INSTALL_TYPE"
}

# Phase 1: Foundation Setup (Enhanced ZFS + Container Runtime)
setup_foundation() {
    show_phase "1" "Foundation Setup" "ZFS filesystem + Container runtime + Base optimizations"
    
    log "🏗️ Setting up system foundation..."
    
    # ZFS installation (if requested)
    if [[ "${RUN_ZFS:-1}" == "1" ]]; then
        log "💾 Installing ZFS root filesystem..."
        if [[ -f "$SCRIPT_DIR/zfs-install-complete.sh" ]]; then
            sudo bash "$SCRIPT_DIR/zfs-install-complete.sh"
            log "SUCCESS" "ZFS root filesystem installed"
        fi
    fi
    
    # Enhanced container runtime setup
    setup_container_runtime
    
    # System optimization baseline
    apply_baseline_optimizations
}

# Enhanced container runtime with multiple options
setup_container_runtime() {
    log "🐳 Setting up enhanced container runtime..."
    
    # Docker with optimizations
    if [[ "$HAS_DOCKER" != "yes" ]]; then
        # Add Docker repository
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
        
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Add user to docker group
        sudo usermod -aG docker "$USER"
    fi
    
    # Docker optimizations for AI/Gaming workloads
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
        },
        "memlock": {
            "name": "memlock",
            "hard": -1,
            "soft": -1
        }
    },
    "default-shm-size": "2gb"
}
EOF
    
    # NVIDIA container toolkit (if NVIDIA GPU present)
    if [[ "$HAS_NVIDIA" == "yes" ]]; then
        log "🎮 Installing NVIDIA container toolkit..."
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/$(. /etc/os-release;echo $ID$VERSION_ID) /" | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        
        sudo apt update && sudo apt install -y nvidia-container-toolkit
        sudo nvidia-ctk runtime configure --runtime=docker
    fi
    
    sudo systemctl restart docker
    log "SUCCESS" "Container runtime setup completed"
}

# Phase 2: Gaming Ecosystem (Ultimate from all distros)
setup_ultimate_gaming() {
    show_phase "2" "Ultimate Gaming Ecosystem" "Best features from Garuda, ChimeraOS, Nobara, Pop!_OS, SteamOS, Batocera"
    
    if [[ "$INSTALL_TYPE" =~ (ultimate-powerhouse|gaming-ai-dev|gaming-focus) ]]; then
        log "GAMING" "Installing ultimate gaming ecosystem..."
        
        # Source and execute the enhanced gaming installation
        source "$SCRIPT_DIR/zfsinstall-ai-enhanced.sh"
        install_complete_gaming_stack
        
        log "SUCCESS" "Ultimate gaming ecosystem installed"
    fi
}

# Phase 3: AI/ML Development Powerhouse
setup_ai_ml_powerhouse() {
    show_phase "3" "AI/ML Development Powerhouse" "CUDA, PyTorch, Ollama, Jupyter, Model management"
    
    if [[ "$INSTALL_TYPE" =~ (ultimate-powerhouse|gaming-ai-dev) ]]; then
        log "AI" "Setting up AI/ML development environment..."
        
        # Advanced AI/ML stack
        setup_cuda_environment
        setup_pytorch_environment
        setup_ollama_integration
        setup_jupyter_lab
        setup_ai_development_tools
        
        log "SUCCESS" "AI/ML development powerhouse ready"
    fi
}

# Enhanced CUDA environment setup
setup_cuda_environment() {
    if [[ "$HAS_NVIDIA" == "yes" ]]; then
        log "AI" "Setting up CUDA environment..."
        
        # CUDA repository and installation
        wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
        sudo dpkg -i cuda-keyring_1.1-1_all.deb
        sudo apt update
        sudo apt install -y cuda-toolkit-12-3 cuda-drivers
        
        # Environment configuration
        sudo tee /etc/profile.d/cuda.sh >/dev/null <<EOF
if [ -d /usr/local/cuda ]; then
    export PATH=/usr/local/cuda/bin:\${PATH}
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\${LD_LIBRARY_PATH:-}
    export CUDA_HOME=/usr/local/cuda
    export CUDA_ROOT=/usr/local/cuda
fi
EOF
        
        rm -f cuda-keyring_1.1-1_all.deb
    fi
}

# PyTorch with hardware optimization
setup_pytorch_environment() {
    log "AI" "Setting up PyTorch environment..."
    
    # Miniforge for conda
    if [ ! -x "/opt/miniforge3/bin/mamba" ]; then
        wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
        sudo bash Miniforge3-Linux-x86_64.sh -b -p /opt/miniforge3
        rm Miniforge3-Linux-x86_64.sh
    fi
    
    # Create AI environment
    sudo /opt/miniforge3/bin/mamba create -y -n ai python=3.11 -c conda-forge
    
    # Install PyTorch (GPU or CPU based on hardware)
    if [[ "$HAS_NVIDIA" == "yes" ]]; then
        sudo /opt/miniforge3/envs/ai/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    else
        sudo /opt/miniforge3/envs/ai/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    fi
    
    # Additional AI/ML packages
    sudo /opt/miniforge3/envs/ai/bin/pip install transformers accelerate diffusers jupyterlab ipywidgets matplotlib seaborn pandas numpy scipy scikit-learn
}

# Ollama integration with model management
setup_ollama_integration() {
    log "AI" "Setting up Ollama with model management..."
    
    # Install Ollama
    curl -fsSL https://ollama.ai/install.sh | sh
    
    # Create Ollama service for multi-user access
    sudo tee /etc/systemd/system/ollama-server.service >/dev/null <<EOF
[Unit]
Description=Ollama Server
After=network-online.target

[Service]
Type=exec
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="OLLAMA_HOST=0.0.0.0:11434"

[Install]
WantedBy=multi-user.target
EOF

    # Create ollama user
    sudo useradd -r -s /bin/false -d /usr/share/ollama ollama || true
    
    sudo systemctl enable --now ollama-server
    
    # Pull popular models (based on system RAM)
    if [[ $TOTAL_RAM_GB -ge 16 ]]; then
        ollama pull llama2:7b
        ollama pull codellama:7b
    fi
    
    if [[ $TOTAL_RAM_GB -ge 32 ]]; then
        ollama pull llama2:13b
        ollama pull codellama:13b
    fi
}

# JupyterLab with extensions
setup_jupyter_lab() {
    log "AI" "Setting up JupyterLab with extensions..."
    
    # Install JupyterLab extensions
    sudo /opt/miniforge3/envs/ai/bin/pip install jupyterlab-git jupyterlab-lsp jupyter-ai
    
    # Generate JupyterLab config
    sudo /opt/miniforge3/envs/ai/bin/jupyter lab --generate-config
    
    # Create systemd service for JupyterLab
    sudo tee /etc/systemd/system/jupyterlab.service >/dev/null <<EOF
[Unit]
Description=JupyterLab Server
After=network-online.target

[Service]
Type=simple
User=$USER
ExecStart=/opt/miniforge3/envs/ai/bin/jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root
WorkingDirectory=/home/$USER
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl enable jupyterlab
}

# AI development tools
setup_ai_development_tools() {
    log "AI" "Installing AI development tools..."
    
    # VSCode with AI extensions
    if ! command -v code >/dev/null; then
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
        sudo apt update && sudo apt install -y code
    fi
    
    # Install AI-focused VS Code extensions
    code --install-extension ms-python.python
    code --install-extension ms-toolsai.jupyter
    code --install-extension github.copilot
    code --install-extension continue.continue
    
    # Development containers
    setup_ai_development_containers
}

# AI development containers
setup_ai_development_containers() {
    log "AI" "Setting up AI development containers..."
    
    # Create docker-compose for AI development
    mkdir -p "$HOME/ai-development"
    
    tee "$HOME/ai-development/docker-compose.yml" >/dev/null <<EOF
version: '3.8'

services:
  jupyter:
    image: jupyter/tensorflow-notebook:latest
    ports:
      - "8889:8888"
    volumes:
      - ./notebooks:/home/jovyan/work
    environment:
      - JUPYTER_ENABLE_LAB=yes
    restart: unless-stopped
    
  tensorboard:
    image: tensorflow/tensorflow:latest
    command: tensorboard --logdir=/logs --host=0.0.0.0
    ports:
      - "6006:6006"
    volumes:
      - ./logs:/logs
    restart: unless-stopped
    
  mlflow:
    image: python:3.11-slim
    command: bash -c "pip install mlflow && mlflow server --host 0.0.0.0 --port 5000"
    ports:
      - "5000:5000"
    volumes:
      - ./mlflow:/mlflow
    restart: unless-stopped
EOF

    # GPU support if available
    if [[ "$HAS_NVIDIA" == "yes" ]]; then
        echo "    runtime: nvidia" >> "$HOME/ai-development/docker-compose.yml"
        echo "    environment:" >> "$HOME/ai-development/docker-compose.yml"
        echo "      - NVIDIA_VISIBLE_DEVICES=all" >> "$HOME/ai-development/docker-compose.yml"
    fi
    
    cd "$HOME/ai-development" && docker compose up -d
}

# Phase 4: Media Center & Self-Hosting Stack
setup_media_selfhosting() {
    show_phase "4" "Media Center & Self-Hosting" "Jellyfin, *arr stack, Nextcloud, Monitoring, Traefik"
    
    if [[ "$INSTALL_TYPE" =~ (ultimate-powerhouse|media-selfhost) ]]; then
        log "MEDIA" "Setting up media center and self-hosting stack..."
        
        setup_traefik_reverse_proxy
        setup_jellyfin_media_center
        setup_arr_stack
        setup_nextcloud
        setup_monitoring_stack
        setup_backup_system
        
        log "SUCCESS" "Media center and self-hosting stack ready"
    fi
}

# Traefik reverse proxy with SSL
setup_traefik_reverse_proxy() {
    log "Setting up Traefik reverse proxy..."
    
    mkdir -p "$HOME/selfhosting/traefik"
    
    # Traefik configuration
    tee "$HOME/selfhosting/traefik/traefik.yml" >/dev/null <<EOF
global:
  checkNewVersion: false
  sendAnonymousUsage: false

api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com
      storage: /acme.json
      httpChallenge:
        entryPoint: web

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
  file:
    filename: /dynamic.yml
    watch: true
EOF

    # Traefik docker-compose
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
      - ./acme.json:/acme.json
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(\`traefik.local\`)"

networks:
  proxy:
    external: true
EOF

    # Create proxy network
    docker network create proxy 2>/dev/null || true
    
    cd "$HOME/selfhosting/traefik" && docker compose up -d
}

# Jellyfin media center
setup_jellyfin_media_center() {
    log "MEDIA" "Setting up Jellyfin media center..."
    
    mkdir -p "$HOME/selfhosting/jellyfin"
    
    tee "$HOME/selfhosting/jellyfin/docker-compose.yml" >/dev/null <<EOF
version: '3.8'

services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    volumes:
      - ./config:/config
      - ./cache:/cache
      - /media:/media:ro
    ports:
      - "8096:8096"
    environment:
      - JELLYFIN_PublishedServerUrl=http://localhost:8096
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.jellyfin.rule=Host(\`jellyfin.local\`)"
      - "traefik.http.services.jellyfin.loadbalancer.server.port=8096"
EOF

    # GPU acceleration for transcoding
    if [[ "$HAS_NVIDIA" == "yes" ]]; then
        echo "    runtime: nvidia" >> "$HOME/selfhosting/jellyfin/docker-compose.yml"
        echo "    environment:" >> "$HOME/selfhosting/jellyfin/docker-compose.yml"
        echo "      - NVIDIA_VISIBLE_DEVICES=all" >> "$HOME/selfhosting/jellyfin/docker-compose.yml"
    fi
    
    cd "$HOME/selfhosting/jellyfin" && docker compose up -d
}

# Complete *arr stack (Sonarr, Radarr, Prowlarr, qBittorrent)
setup_arr_stack() {
    log "MEDIA" "Setting up *arr media automation stack..."
    
    mkdir -p "$HOME/selfhosting/arr-stack"
    
    tee "$HOME/selfhosting/arr-stack/docker-compose.yml" >/dev/null <<EOF
version: '3.8'

services:
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./prowlarr:/config
    ports:
      - "9696:9696"
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prowlarr.rule=Host(\`prowlarr.local\`)"

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./sonarr:/config
      - /media/tv:/tv
      - /media/downloads:/downloads
    ports:
      - "8989:8989"
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.sonarr.rule=Host(\`sonarr.local\`)"

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./radarr:/config
      - /media/movies:/movies
      - /media/downloads:/downloads
    ports:
      - "7878:7878"
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.radarr.rule=Host(\`radarr.local\`)"

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - WEBUI_PORT=8080
    volumes:
      - ./qbittorrent:/config
      - /media/downloads:/downloads
    ports:
      - "8080:8080"
      - "6881:6881"
      - "6881:6881/udp"
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.qbittorrent.rule=Host(\`qbittorrent.local\`)"
      - "traefik.http.services.qbittorrent.loadbalancer.server.port=8080"
EOF
    
    cd "$HOME/selfhosting/arr-stack" && docker compose up -d
}

# Nextcloud with office suite
setup_nextcloud() {
    log "Setting up Nextcloud with OnlyOffice..."
    
    mkdir -p "$HOME/selfhosting/nextcloud"
    
    tee "$HOME/selfhosting/nextcloud/docker-compose.yml" >/dev/null <<EOF
version: '3.8'

services:
  nextcloud-db:
    image: postgres:15
    container_name: nextcloud-db
    environment:
      POSTGRES_DB: nextcloud
      POSTGRES_USER: nextcloud
      POSTGRES_PASSWORD: secure_password_here
    volumes:
      - ./db:/var/lib/postgresql/data
    restart: unless-stopped
    networks:
      - proxy

  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    depends_on:
      - nextcloud-db
    environment:
      POSTGRES_HOST: nextcloud-db
      POSTGRES_DB: nextcloud
      POSTGRES_USER: nextcloud
      POSTGRES_PASSWORD: secure_password_here
      NEXTCLOUD_ADMIN_USER: admin
      NEXTCLOUD_ADMIN_PASSWORD: admin_password_here
    volumes:
      - ./data:/var/www/html
      - ./apps:/var/www/html/custom_apps
    ports:
      - "8081:80"
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=Host(\`nextcloud.local\`)"
      - "traefik.http.services.nextcloud.loadbalancer.server.port=80"

  onlyoffice:
    image: onlyoffice/documentserver:latest
    container_name: onlyoffice
    ports:
      - "8082:80"
    volumes:
      - ./onlyoffice:/var/www/onlyoffice/Data
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.onlyoffice.rule=Host(\`onlyoffice.local\`)"
EOF
    
    cd "$HOME/selfhosting/nextcloud" && docker compose up -d
}

# Monitoring stack (Prometheus, Grafana, Node Exporter)
setup_monitoring_stack() {
    log "Setting up monitoring stack..."
    
    mkdir -p "$HOME/selfhosting/monitoring"
    
    # Prometheus configuration
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
  
  - job_name: 'docker'
    static_configs:
      - targets: ['docker-exporter:9323']
  
  - job_name: 'ollama'
    static_configs:
      - targets: ['host.docker.internal:11434']
EOF

    # Monitoring docker-compose
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
      - ./prometheus-data:/prometheus
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(\`prometheus.local\`)"

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
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(\`grafana.local\`)"

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped
    networks:
      - proxy
EOF
    
    cd "$HOME/selfhosting/monitoring" && docker compose up -d
}

# Enhanced backup system
setup_backup_system() {
    log "Setting up automated backup system..."
    
    # ZFS snapshots (if ZFS is available)
    if command -v zfs >/dev/null; then
        # Automated ZFS snapshots
        sudo tee /usr/local/bin/zfs-auto-snapshot >/dev/null <<EOF
#!/bin/bash
# Automated ZFS snapshots
zfs snapshot rpool/ROOT/ubuntu@\$(date +%Y%m%d-%H%M%S)
# Keep only last 10 snapshots
zfs list -H -t snapshot | grep "rpool/ROOT/ubuntu@" | sort | head -n -10 | awk '{print \$1}' | xargs -r -n1 zfs destroy
EOF
        
        sudo chmod +x /usr/local/bin/zfs-auto-snapshot
        
        # Cron job for regular snapshots
        (crontab -l 2>/dev/null; echo "0 */6 * * * /usr/local/bin/zfs-auto-snapshot") | crontab -
    fi
    
    # Docker volume backup
    tee "$HOME/selfhosting/backup-docker-volumes.sh" >/dev/null <<EOF
#!/bin/bash
# Backup all Docker volumes
BACKUP_DIR="/backup/docker-volumes/\$(date +%Y%m%d)"
mkdir -p "\$BACKUP_DIR"

for volume in \$(docker volume ls -q); do
    echo "Backing up volume: \$volume"
    docker run --rm -v "\$volume":/source -v "\$BACKUP_DIR":/backup alpine tar czf /backup/"\$volume".tar.gz -C /source .
done
EOF
    
    chmod +x "$HOME/selfhosting/backup-docker-volumes.sh"
    
    # Weekly backup cron
    (crontab -l 2>/dev/null; echo "0 2 * * 0 $HOME/selfhosting/backup-docker-volumes.sh") | crontab -
}

# Phase 5: Virtualization & Development Environment
setup_virtualization_development() {
    show_phase "5" "Virtualization & Development" "KVM/QEMU, Development containers, Remote development"
    
    if [[ "$INSTALL_TYPE" =~ (ultimate-powerhouse|gaming-ai-dev) ]] && [[ "$HAS_VIRTUALIZATION" == "yes" ]]; then
        log "Setting up virtualization and development environment..."
        
        setup_kvm_qemu
        setup_development_containers
        setup_remote_development
        
        log "SUCCESS" "Virtualization and development environment ready"
    fi
}

# KVM/QEMU setup with GPU passthrough support
setup_kvm_qemu() {
    log "Setting up KVM/QEMU virtualization..."
    
    # Install virtualization packages
    sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
    
    # Add user to libvirt group
    sudo usermod -aG libvirt "$USER"
    
    # Enable and start libvirt
    sudo systemctl enable --now libvirtd
    
    # GPU passthrough preparation (if multiple GPUs)
    if [[ "$HAS_NVIDIA" == "yes" ]] && lspci | grep -c -i nvidia | grep -q -E "[2-9]|[1-9][0-9]+"; then
        setup_gpu_passthrough
    fi
}

# GPU passthrough setup (advanced)
setup_gpu_passthrough() {
    log "Setting up GPU passthrough support..."
    
    # Enable IOMMU
    if grep -q "intel" /proc/cpuinfo; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on /' /etc/default/grub
    elif grep -q "AMD" /proc/cpuinfo; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="amd_iommu=on /' /etc/default/grub
    fi
    
    sudo update-grub
}

# Development containers for various stacks
setup_development_containers() {
    log "Setting up development containers..."
    
    mkdir -p "$HOME/development"
    
    # Multi-language development environment
    tee "$HOME/development/docker-compose.yml" >/dev/null <<EOF
version: '3.8'

services:
  # Rust development
  rust-dev:
    image: rust:latest
    container_name: rust-dev
    volumes:
      - ./rust-projects:/workspace
      - cargo-cache:/usr/local/cargo
    working_dir: /workspace
    tty: true
    stdin_open: true
    
  # Node.js development
  node-dev:
    image: node:18-alpine
    container_name: node-dev
    volumes:
      - ./node-projects:/workspace
      - node-modules:/workspace/node_modules
    working_dir: /workspace
    ports:
      - "3001:3000"
    tty: true
    stdin_open: true
    
  # Python development
  python-dev:
    image: python:3.11
    container_name: python-dev
    volumes:
      - ./python-projects:/workspace
    working_dir: /workspace
    tty: true
    stdin_open: true
    
  # Database development
  postgres-dev:
    image: postgres:15
    container_name: postgres-dev
    environment:
      POSTGRES_DB: development
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: devpass
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  cargo-cache:
  node-modules:
  postgres-data:
EOF
}

# Remote development setup
setup_remote_development() {
    log "Setting up remote development environment..."
    
    # Code Server (web-based VS Code)
    docker run -d \
        --name code-server \
        --restart unless-stopped \
        -p 8443:8443 \
        -v "$HOME/development:/home/coder/workspace" \
        -e PASSWORD=development123 \
        codercom/code-server:latest
    
    # SSH hardening for remote development
    sudo tee -a /etc/ssh/sshd_config >/dev/null <<EOF

# Enhanced security for remote development
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
    
    sudo systemctl restart sshd
}

# Phase 6: Final Optimizations & Integration
final_optimizations_integration() {
    show_phase "6" "Final Optimizations" "System tuning, Service integration, Performance monitoring"
    
    log "⚡ Applying final optimizations and integrations..."
    
    # System-wide optimizations
    apply_ultimate_system_optimizations
    
    # Service integration and health checks
    setup_service_health_monitoring
    
    # Performance monitoring dashboard
    setup_performance_dashboard
    
    # Create management scripts
    create_management_scripts
    
    log "SUCCESS" "Final optimizations and integrations complete"
}

# Ultimate system optimizations
apply_ultimate_system_optimizations() {
    log "Applying ultimate system optimizations..."
    
    # Gaming + AI/ML optimized sysctl
    sudo tee /etc/sysctl.d/99-ultimate-performance.conf >/dev/null <<EOF
# Ultimate gaming and AI/ML optimizations
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

# Kernel optimizations
kernel.sched_child_runs_first=0
kernel.sched_autogroup_enabled=1
kernel.sched_cfs_bandwidth_slice_us=3000
EOF
    
    sudo sysctl -p /etc/sysctl.d/99-ultimate-performance.conf
}

# Service health monitoring
setup_service_health_monitoring() {
    log "Setting up service health monitoring..."
    
    # Health check script
    tee "$HOME/selfhosting/health-check.sh" >/dev/null <<EOF
#!/bin/bash
# Service health monitoring

SERVICES=(
    "docker:docker ps"
    "ollama:curl -s http://localhost:11434/api/version"
    "jellyfin:curl -s http://localhost:8096/health"
    "traefik:curl -s http://localhost:8080/ping"
)

LOG_FILE="/var/log/service-health.log"

for service_check in "\${SERVICES[@]}"; do
    IFS=':' read -r service_name check_command <<< "\$service_check"
    
    if eval "\$check_command" >/dev/null 2>&1; then
        echo "\$(date): \$service_name - OK" >> "\$LOG_FILE"
    else
        echo "\$(date): \$service_name - FAILED" >> "\$LOG_FILE"
        # Could add notification logic here
    fi
done
EOF
    
    chmod +x "$HOME/selfhosting/health-check.sh"
    
    # Cron job for health checks
    (crontab -l 2>/dev/null; echo "*/5 * * * * $HOME/selfhosting/health-check.sh") | crontab -
}

# Performance dashboard setup
setup_performance_dashboard() {
    log "Setting up performance monitoring dashboard..."
    
    # Custom Grafana dashboard for gaming + AI workloads
    tee "$HOME/selfhosting/monitoring/gaming-ai-dashboard.json" >/dev/null <<'EOF'
{
  "dashboard": {
    "title": "AI Powerhouse Gaming Dashboard",
    "panels": [
      {
        "title": "GPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "nvidia_ml_py_gpu_utilization_percent",
            "legendFormat": "GPU {{gpu}}"
          }
        ]
      },
      {
        "title": "AI Model Performance",
        "type": "graph", 
        "targets": [
          {
            "expr": "ollama_request_duration_seconds",
            "legendFormat": "Ollama Response Time"
          }
        ]
      },
      {
        "title": "Gaming Performance",
        "type": "graph",
        "targets": [
          {
            "expr": "node_cpu_seconds_total",
            "legendFormat": "CPU Usage"
          }
        ]
      }
    ]
  }
}
EOF
}

# Management scripts
create_management_scripts() {
    log "Creating management scripts..."
    
    # Main management script
    tee "$HOME/manage-ai-powerhouse.sh" >/dev/null <<EOF
#!/bin/bash
# AI Powerhouse Gaming Management Script

case \$1 in
    "start-all")
        echo "🚀 Starting all services..."
        systemctl --user start ollama-server jupyterlab
        cd ~/selfhosting/traefik && docker compose up -d
        cd ~/selfhosting/jellyfin && docker compose up -d
        cd ~/selfhosting/arr-stack && docker compose up -d
        cd ~/selfhosting/nextcloud && docker compose up -d
        cd ~/selfhosting/monitoring && docker compose up -d
        echo "✅ All services started"
        ;;
    "stop-all")
        echo "🛑 Stopping all services..."
        cd ~/selfhosting/monitoring && docker compose down
        cd ~/selfhosting/nextcloud && docker compose down
        cd ~/selfhosting/arr-stack && docker compose down
        cd ~/selfhosting/jellyfin && docker compose down
        cd ~/selfhosting/traefik && docker compose down
        systemctl --user stop jupyterlab ollama-server
        echo "✅ All services stopped"
        ;;
    "status")
        echo "📊 Service Status:"
        echo "Docker: \$(systemctl is-active docker)"
        echo "Ollama: \$(systemctl is-active ollama-server)"
        echo "JupyterLab: \$(systemctl --user is-active jupyterlab)"
        echo "Container Status:"
        docker ps --format "table {{.Names}}\\t{{.Status}}"
        ;;
    "backup")
        echo "💾 Starting backup..."
        ~/selfhosting/backup-docker-volumes.sh
        echo "✅ Backup completed"
        ;;
    *)
        echo "Usage: \$0 {start-all|stop-all|status|backup}"
        ;;
esac
EOF
    
    chmod +x "$HOME/manage-ai-powerhouse.sh"
    
    # Desktop shortcut
    tee "$HOME/Desktop/AI-Powerhouse-Manager.desktop" >/dev/null <<EOF
[Desktop Entry]
Version=1.0
Name=AI Powerhouse Manager
Comment=Manage AI Powerhouse Gaming services
Exec=gnome-terminal -- $HOME/manage-ai-powerhouse.sh status
Icon=computer
Terminal=false
Type=Application
Categories=System;
EOF
    
    chmod +x "$HOME/Desktop/AI-Powerhouse-Manager.desktop"
}

# Installation summary with service URLs
show_final_summary() {
    echo -e "\n${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║${NC}                ${BOLD}${YELLOW}🚀 AI POWERHOUSE GAMING SETUP COMPLETE${NC}                 ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}📊 Installation Summary:${NC}"
    echo -e "  • Type: ${GREEN}$INSTALL_TYPE${NC}"
    echo -e "  • Hardware: ${CPU_CORES} cores, ${TOTAL_RAM_GB}GB RAM"
    echo -e "  • GPUs: NVIDIA:$HAS_NVIDIA AMD:$HAS_AMD_GPU Intel:$HAS_INTEL_GPU"
    echo -e "  • Storage: ${TOTAL_STORAGE_GB}GB, NVMe:$HAS_NVME"
    
    if [[ "$INSTALL_TYPE" =~ (ultimate-powerhouse|gaming-ai-dev|gaming-focus) ]]; then
        echo -e "\n${BLUE}🎮 Gaming Platforms Available:${NC}"
        echo -e "  • Steam with optimizations"
        echo -e "  • Epic Games (Heroic Launcher)"
        echo -e "  • GOG Games"
        echo -e "  • Windows Games (Wine/Proton)"
        echo -e "  • Complete emulation suite"
        echo -e "  • VR Gaming support"
    fi
    
    if [[ "$INSTALL_TYPE" =~ (ultimate-powerhouse|gaming-ai-dev) ]]; then
        echo -e "\n${PURPLE}🤖 AI/ML Development:${NC}"
        echo -e "  • JupyterLab: http://localhost:8888"
        echo -e "  • Ollama API: http://localhost:11434"
        echo -e "  • MLflow: http://localhost:5000"
        echo -e "  • TensorBoard: http://localhost:6006"
    fi
    
    if [[ "$INSTALL_TYPE" =~ (ultimate-powerhouse|media-selfhost) ]]; then
        echo -e "\n${CYAN}📺 Media & Self-Hosting:${NC}"
        echo -e "  • Traefik Dashboard: http://localhost:8080"
        echo -e "  • Jellyfin: http://localhost:8096"
        echo -e "  • Sonarr: http://localhost:8989"
        echo -e "  • Radarr: http://localhost:7878"
        echo -e "  • Prowlarr: http://localhost:9696"
        echo -e "  • qBittorrent: http://localhost:8080"
        echo -e "  • Nextcloud: http://localhost:8081"
        echo -e "  • Grafana: http://localhost:3000"
        echo -e "  • Prometheus: http://localhost:9090"
    fi
    
    echo -e "\n${YELLOW}🛠️ Management:${NC}"
    echo -e "  • Manager: ${GREEN}./manage-ai-powerhouse.sh${NC}"
    echo -e "  • Health checks: Every 5 minutes"
    echo -e "  • Backups: Weekly automated"
    echo -e "  • Log file: ${GREEN}$LOG_FILE${NC}"
    
    echo -e "\n${GREEN}🎯 Next Steps:${NC}"
    echo -e "  1. ${BOLD}Reboot your system${NC} to apply all optimizations"
    echo -e "  2. Run ${GREEN}./manage-ai-powerhouse.sh status${NC} to check services"
    echo -e "  3. Access JupyterLab for AI development"
    echo -e "  4. Configure your media library in Jellyfin"
    echo -e "  5. Set up your gaming library in Steam"
    
    echo -e "\n${BOLD}${GREEN}🚀 Your AI Powerhouse Gaming system is ready! 🎮🤖${NC}\n"
}

# Main execution function
main() {
    echo -e "${BOLD}${CYAN}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                    🚀 AI POWERHOUSE GAMING SETUP 🎮                          ║
    ║                                                                              ║
    ║     Ultimate Gaming + AI/ML Development + Self-Hosting + Media Stack         ║
    ║                                                                              ║
    ║    Features from: Garuda • ChimeraOS • Nobara • Pop!_OS • SteamOS • More    ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
    
    # System assessment and recommendations
    assess_system_capabilities
    
    # Installation type selection (if not provided)
    if [[ "${INSTALL_TYPE:-}" == "" ]]; then
        show_enhanced_installation_options
    fi
    
    log "🚀 Starting AI Powerhouse Gaming installation: $INSTALL_TYPE"
    
    # Create directory structure
    mkdir -p "$HOME/selfhosting" "$HOME/ai-development" "$HOME/development"
    
    # Execute installation phases
    setup_foundation
    setup_ultimate_gaming
    setup_ai_ml_powerhouse
    setup_media_selfhosting
    setup_virtualization_development
    final_optimizations_integration
    
    # Final summary
    show_final_summary
    
    log "SUCCESS" "AI Powerhouse Gaming installation completed successfully!"
}

# Argument handling
while [[ $# -gt 0 ]]; do
    case $1 in
        --type=*)
            INSTALL_TYPE="${1#*=}"
            shift
            ;;
        --no-zfs)
            export RUN_ZFS=0
            shift
            ;;
        --help|-h)
            echo "AI Powerhouse Gaming Setup"
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --type=TYPE      Installation type (ultimate-powerhouse|gaming-ai-dev|media-selfhost|gaming-focus)"
            echo "  --no-zfs         Skip ZFS installation"
            echo "  --help, -h       Show this help"
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Execute main installation
main "$@"