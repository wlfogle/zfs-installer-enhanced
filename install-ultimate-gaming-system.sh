#!/bin/bash
set -euo pipefail

# Ultimate Gaming ZFS Setup - Main Installation Script
# Combines the best features from all major gaming distributions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/ultimate-gaming-install-$(date +%Y%m%d-%H%M%S).log"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    local message="$*"
    local timestamp=$(date '+%H:%M:%S')
    echo -e "[${CYAN}$timestamp${NC}] $message" | tee -a "$LOG_FILE"
}

# Progress display
show_phase() {
    local phase="$1"
    local description="$2"
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC} ${YELLOW}Phase $phase${NC} - ${GREEN}$description${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
}

# Error handling
error_exit() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    echo "Check log file: $LOG_FILE"
    exit 1
}

# Success message
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Warning message
warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if running as root for certain operations
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should not be run as root. Use sudo when needed."
    fi
    
    if ! sudo -n true 2>/dev/null; then
        log "This script requires sudo privileges. Please enter your password:"
        sudo -v || error_exit "Sudo access required"
    fi
}

# System requirements check
check_system_requirements() {
    log "🔍 Checking system requirements..."
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu" /etc/os-release; then
        error_exit "This script is designed for Ubuntu systems"
    fi
    
    # Check available space
    local available_space
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 52428800 ]]; then  # 50GB in KB
        warning "Less than 50GB available space. Gaming installation requires substantial disk space."
    fi
    
    # Check RAM
    local ram_gb
    ram_gb=$(awk '/MemTotal:/ {print int($2/1024/1024)}' /proc/meminfo)
    if [[ $ram_gb -lt 16 ]]; then
        warning "Less than 16GB RAM detected. Gaming performance may be limited."
    fi
    
    success "System requirements check completed"
}

# Hardware detection
detect_hardware() {
    log "🔍 Detecting hardware configuration..."
    
    # CPU detection
    CPU_CORES=$(nproc)
    HAS_AVX2=$(grep -q avx2 /proc/cpuinfo && echo "yes" || echo "no")
    HAS_AVX512=$(grep -q avx512 /proc/cpuinfo && echo "yes" || echo "no")
    
    # GPU detection
    HAS_NVIDIA=$(lspci | grep -i nvidia >/dev/null && echo "yes" || echo "no")
    HAS_INTEL_GPU=$(lspci | grep -i "intel.*graphics\|intel.*display" >/dev/null && echo "yes" || echo "no")
    HAS_AMD_GPU=$(lspci | grep -i "amd.*radeon\|amd.*graphics" >/dev/null && echo "yes" || echo "no")
    
    # Storage detection
    HAS_NVME=$(lsblk -d -o NAME,ROTA | grep -q "nvme.*0" && echo "yes" || echo "no")
    HAS_SSD=$(lsblk -d -o NAME,ROTA | grep -q "sd.*0" && echo "yes" || echo "no")
    
    # Memory
    TOTAL_RAM_GB=$(($(awk '/MemTotal:/ {print $2}' /proc/meminfo) / 1024 / 1024))
    
    log "Hardware detected:"
    log "  CPU: ${CPU_CORES} cores, AVX2: ${HAS_AVX2}, AVX512: ${HAS_AVX512}"
    log "  GPU: NVIDIA: ${HAS_NVIDIA}, Intel: ${HAS_INTEL_GPU}, AMD: ${HAS_AMD_GPU}"
    log "  RAM: ${TOTAL_RAM_GB}GB, NVMe: ${HAS_NVME}, SSD: ${HAS_SSD}"
    
    # Export for other scripts
    export CPU_CORES HAS_AVX2 HAS_AVX512 HAS_NVIDIA HAS_INTEL_GPU HAS_AMD_GPU HAS_NVME HAS_SSD TOTAL_RAM_GB
}

# Installation options
show_installation_options() {
    echo -e "\n${CYAN}🎮 Ultimate Gaming ZFS Setup${NC}"
    echo -e "Choose your installation type:\n"
    
    echo -e "${GREEN}1)${NC} Complete Installation (Recommended)"
    echo -e "   - ZFS root filesystem"
    echo -e "   - Complete gaming ecosystem"
    echo -e "   - AI/ML development stack"
    echo -e "   - All optimizations"
    echo
    
    echo -e "${GREEN}2)${NC} Gaming Only (Existing System)"
    echo -e "   - Gaming platforms and tools"
    echo -e "   - Performance optimizations"
    echo -e "   - Driver installation"
    echo
    
    echo -e "${GREEN}3)${NC} Custom Installation"
    echo -e "   - Choose specific components"
    echo -e "   - Modular installation"
    echo
    
    echo -e "${GREEN}4)${NC} Development Focus"
    echo -e "   - Gaming development tools"
    echo -e "   - AI/ML stack"
    echo -e "   - Performance optimization"
    echo
    
    read -p "Select option (1-4): " INSTALL_OPTION
    
    case $INSTALL_OPTION in
        1) INSTALL_TYPE="complete" ;;
        2) INSTALL_TYPE="gaming-only" ;;
        3) INSTALL_TYPE="custom" ;;
        4) INSTALL_TYPE="development" ;;
        *) error_exit "Invalid option selected" ;;
    esac
    
    export INSTALL_TYPE
}

# Custom installation menu
custom_installation_menu() {
    echo -e "\n${CYAN}Custom Installation - Select Components:${NC}\n"
    
    local components=(
        "ZFS Root Filesystem:zfs"
        "Steam Gaming Stack:steam"
        "Wine/Proton Windows Gaming:wine"
        "Emulation Suite:emulation"
        "VR Gaming:vr"
        "Game Streaming:streaming"
        "NVIDIA Drivers:nvidia"
        "AMD Drivers:amd"
        "Intel Drivers:intel"
        "Audio Optimization:audio"
        "Network Optimization:network"
        "Security Hardening:security"
        "AI/ML Development:aiml"
        "System Monitoring:monitoring"
    )
    
    declare -A selected_components
    
    for i in "${!components[@]}"; do
        IFS=':' read -r desc key <<< "${components[$i]}"
        read -p "$((i+1)). Install $desc? (y/N): " choice
        case $choice in
            [Yy]*) selected_components["$key"]=1 ;;
            *) selected_components["$key"]=0 ;;
        esac
    done
    
    # Export selections
    for key in "${!selected_components[@]}"; do
        export "INSTALL_${key^^}"="${selected_components[$key]}"
    done
}

# Phase 1: ZFS Installation
install_zfs_foundation() {
    show_phase "1" "ZFS Foundation Setup"
    
    if [[ "${RUN_ZFS:-1}" == "1" ]]; then
        log "🗄️ Installing ZFS root filesystem..."
        
        if [[ -f "$SCRIPT_DIR/zfs-install-complete.sh" ]]; then
            sudo bash "$SCRIPT_DIR/zfs-install-complete.sh" || error_exit "ZFS installation failed"
            success "ZFS root filesystem installed"
        else
            error_exit "ZFS installation script not found"
        fi
    else
        log "⏭️ Skipping ZFS installation (RUN_ZFS=0)"
    fi
}

# Phase 2: Gaming Ecosystem
install_gaming_ecosystem() {
    show_phase "2" "Gaming Ecosystem Installation"
    
    log "🎮 Installing ultimate gaming stack..."
    
    # Steam installation
    if [[ "${INSTALL_TYPE}" == "complete" ]] || [[ "${INSTALL_TYPE}" == "gaming-only" ]] || [[ "${INSTALL_STEAM:-1}" == "1" ]]; then
        bash "$SCRIPT_DIR/gaming/steam/install-steam-ultimate.sh" || warning "Steam installation had issues"
    fi
    
    # Wine/Proton stack
    if [[ "${INSTALL_TYPE}" == "complete" ]] || [[ "${INSTALL_TYPE}" == "gaming-only" ]] || [[ "${INSTALL_WINE:-1}" == "1" ]]; then
        bash "$SCRIPT_DIR/gaming/wine-proton/install-wine-stack.sh" || warning "Wine/Proton installation had issues"
    fi
    
    # Emulation suite
    if [[ "${INSTALL_TYPE}" == "complete" ]] || [[ "${INSTALL_TYPE}" == "gaming-only" ]] || [[ "${INSTALL_EMULATION:-1}" == "1" ]]; then
        bash "$SCRIPT_DIR/gaming/emulation/install-emulation-suite.sh" || warning "Emulation installation had issues"
    fi
    
    # VR gaming
    if [[ "${INSTALL_TYPE}" == "complete" ]] || [[ "${INSTALL_VR:-0}" == "1" ]]; then
        bash "$SCRIPT_DIR/gaming/vr/install-vr-stack.sh" || warning "VR installation had issues"
    fi
    
    success "Gaming ecosystem installation completed"
}

# Phase 3: Drivers Installation
install_gaming_drivers() {
    show_phase "3" "Gaming Drivers Installation"
    
    log "🔧 Installing gaming-optimized drivers..."
    
    # NVIDIA drivers
    if [[ "$HAS_NVIDIA" == "yes" ]] && ([[ "${INSTALL_TYPE}" == "complete" ]] || [[ "${INSTALL_NVIDIA:-1}" == "1" ]]); then
        bash "$SCRIPT_DIR/drivers/nvidia/install-nvidia-gaming.sh" || warning "NVIDIA driver installation had issues"
    fi
    
    # AMD drivers
    if [[ "$HAS_AMD_GPU" == "yes" ]] && ([[ "${INSTALL_TYPE}" == "complete" ]] || [[ "${INSTALL_AMD:-1}" == "1" ]]); then
        bash "$SCRIPT_DIR/drivers/amd/install-amd-gaming.sh" || warning "AMD driver installation had issues"
    fi
    
    # Intel drivers
    if [[ "$HAS_INTEL_GPU" == "yes" ]] && ([[ "${INSTALL_TYPE}" == "complete" ]] || [[ "${INSTALL_INTEL:-1}" == "1" ]]); then
        bash "$SCRIPT_DIR/drivers/intel/install-intel-gaming.sh" || warning "Intel driver installation had issues"
    fi
    
    success "Gaming drivers installation completed"
}

# Phase 4: AI/ML Development Stack
install_ai_ml_stack() {
    show_phase "4" "AI/ML Development Stack"
    
    if [[ "${INSTALL_TYPE}" == "complete" ]] || [[ "${INSTALL_TYPE}" == "development" ]] || [[ "${INSTALL_AIML:-0}" == "1" ]]; then
        log "🤖 Installing AI/ML development stack..."
        
        # CUDA toolkit (if NVIDIA GPU present)
        if [[ "$HAS_NVIDIA" == "yes" ]]; then
            bash "$SCRIPT_DIR/ai-ml/cuda/install-cuda-stack.sh" || warning "CUDA installation had issues"
        fi
        
        # PyTorch and ML tools
        bash "$SCRIPT_DIR/ai-ml/pytorch/install-pytorch-stack.sh" || warning "PyTorch installation had issues"
        
        # Development environment
        bash "$SCRIPT_DIR/ai-ml/development/install-development-stack.sh" || warning "Development stack installation had issues"
        
        success "AI/ML development stack installed"
    else
        log "⏭️ Skipping AI/ML stack installation"
    fi
}

# Phase 5: System Optimizations
apply_system_optimizations() {
    show_phase "5" "System Optimizations"
    
    log "⚡ Applying gaming optimizations..."
    
    # Kernel optimizations
    bash "$SCRIPT_DIR/optimization/kernel/apply-gaming-kernel-params.sh" || warning "Kernel optimization had issues"
    
    # Audio optimization
    if [[ "${INSTALL_AUDIO:-1}" == "1" ]]; then
        bash "$SCRIPT_DIR/optimization/audio/optimize-gaming-audio.sh" || warning "Audio optimization had issues"
    fi
    
    # Network optimization
    if [[ "${INSTALL_NETWORK:-1}" == "1" ]]; then
        bash "$SCRIPT_DIR/optimization/network/optimize-gaming-network.sh" || warning "Network optimization had issues"
    fi
    
    # Storage optimization
    bash "$SCRIPT_DIR/optimization/storage/optimize-gaming-storage.sh" || warning "Storage optimization had issues"
    
    success "System optimizations applied"
}

# Phase 6: Security Hardening
apply_security_hardening() {
    show_phase "6" "Security Hardening"
    
    if [[ "${INSTALL_TYPE}" == "complete" ]] || [[ "${INSTALL_SECURITY:-1}" == "1" ]]; then
        log "🛡️ Applying security hardening..."
        
        # Firewall configuration
        bash "$SCRIPT_DIR/security/firewall/setup-gaming-firewall.sh" || warning "Firewall setup had issues"
        
        # Privacy tools
        bash "$SCRIPT_DIR/security/privacy/install-privacy-tools.sh" || warning "Privacy tools installation had issues"
        
        # System hardening
        bash "$SCRIPT_DIR/security/hardening/apply-system-hardening.sh" || warning "System hardening had issues"
        
        success "Security hardening applied"
    else
        log "⏭️ Skipping security hardening"
    fi
}

# Phase 7: Automation Setup
setup_automation() {
    show_phase "7" "Automation & Monitoring Setup"
    
    if [[ "${INSTALL_TYPE}" == "complete" ]] || [[ "${INSTALL_MONITORING:-1}" == "1" ]]; then
        log "🤖 Setting up automation and monitoring..."
        
        # Backup automation
        bash "$SCRIPT_DIR/automation/backup/setup-gaming-backups.sh" || warning "Backup setup had issues"
        
        # System monitoring
        bash "$SCRIPT_DIR/automation/monitoring/setup-system-monitoring.sh" || warning "Monitoring setup had issues"
        
        # Update automation
        bash "$SCRIPT_DIR/automation/updates/setup-gaming-updates.sh" || warning "Update automation setup had issues"
        
        success "Automation and monitoring setup completed"
    else
        log "⏭️ Skipping automation setup"
    fi
}

# Final system configuration
final_system_configuration() {
    log "🔧 Applying final system configuration..."
    
    # Update desktop database
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    
    # Update font cache
    fc-cache -f || true
    
    # Update shared library cache
    sudo ldconfig || true
    
    # Refresh package database
    sudo apt update || true
    
    success "Final system configuration completed"
}

# Installation summary
show_installation_summary() {
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                    ${YELLOW}🎮 ULTIMATE GAMING SETUP COMPLETE${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}📊 Installation Summary:${NC}"
    echo -e "  • Installation Type: ${GREEN}$INSTALL_TYPE${NC}"
    echo -e "  • Hardware: ${CPU_CORES} cores, ${TOTAL_RAM_GB}GB RAM"
    echo -e "  • GPU Support: NVIDIA: $HAS_NVIDIA, AMD: $HAS_AMD_GPU, Intel: $HAS_INTEL_GPU"
    echo -e "  • Storage: NVMe: $HAS_NVME, SSD: $HAS_SSD"
    echo -e "  • Log File: ${GREEN}$LOG_FILE${NC}"
    
    echo -e "\n${CYAN}🎮 Available Gaming Platforms:${NC}"
    echo -e "  • Steam with optimizations"
    echo -e "  • Epic Games (via Heroic)"
    echo -e "  • GOG Games"
    echo -e "  • Windows games (Wine/Proton)"
    echo -e "  • Emulated games (RetroArch, Dolphin, etc.)"
    if [[ "${INSTALL_VR:-0}" == "1" ]]; then
        echo -e "  • VR Gaming (SteamVR, OpenXR)"
    fi
    
    echo -e "\n${CYAN}⚡ Performance Features:${NC}"
    echo -e "  • Gaming kernel parameters"
    echo -e "  • Low-latency audio"
    echo -e "  • Network optimization"
    echo -e "  • GPU performance tuning"
    
    echo -e "\n${YELLOW}🔄 Next Steps:${NC}"
    echo -e "  1. Reboot your system to apply all optimizations"
    echo -e "  2. Launch Steam and sign in to your account"
    echo -e "  3. Configure MangoHUD for performance monitoring"
    echo -e "  4. Check out the documentation in ${GREEN}$SCRIPT_DIR/docs/${NC}"
    
    echo -e "\n${GREEN}🎮 Happy Gaming! 🚀${NC}\n"
}

# Main installation function
main() {
    echo -e "${CYAN}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                      🎮 ULTIMATE GAMING ZFS SETUP 🚀                        ║
    ║                                                                              ║
    ║              Combining the best from all gaming distributions:              ║
    ║          Garuda • ChimeraOS • Nobara • Pop!_OS • SteamOS • Batocera         ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
    
    # Preparation
    check_sudo
    check_system_requirements
    detect_hardware
    
    # Installation type selection
    if [[ "${INSTALL_TYPE:-}" == "" ]]; then
        show_installation_options
        
        if [[ "$INSTALL_TYPE" == "custom" ]]; then
            custom_installation_menu
        fi
    fi
    
    log "Starting $INSTALL_TYPE installation..."
    
    # Installation phases
    install_zfs_foundation
    install_gaming_ecosystem
    install_gaming_drivers
    install_ai_ml_stack
    apply_system_optimizations
    apply_security_hardening
    setup_automation
    final_system_configuration
    
    # Complete
    show_installation_summary
    
    log "Installation completed successfully!"
}

# Handle script arguments
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
            echo "Ultimate Gaming ZFS Setup"
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --type=TYPE      Installation type (complete|gaming-only|custom|development)"
            echo "  --no-zfs         Skip ZFS installation"
            echo "  --help, -h       Show this help"
            exit 0
            ;;
        *)
            error_exit "Unknown option: $1"
            ;;
    esac
done

# Run main installation
main "$@"