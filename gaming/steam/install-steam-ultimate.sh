#!/bin/bash
set -euo pipefail

# Steam Ultimate Installation (ChimeraOS + SteamOS inspired)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${LOG_FILE:-/tmp/steam-install-$(date +%Y%m%d-%H%M%S).log}"

source "${SCRIPT_DIR}/../../zfsinstall-ai-enhanced.sh" 2>/dev/null || true

log() {
    echo "[$(date +'%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

main() {
    log "🚂 Installing Steam Ultimate (ChimeraOS + SteamOS style)..."
    
    # Call functions from main AI-enhanced script
    install_steam_ultimate
    configure_steam_optimizations
    
    # Additional ChimeraOS-style optimizations
    log "🎮 Applying ChimeraOS-style Steam optimizations..."
    
    # Steam Deck controller support
    sudo systemctl enable --now steam-controller
    
    # Gamescope setup (Steam Deck compositor)
    sudo apt install -y gamescope || log "Gamescope not available in repositories"
    
    log "✅ Steam Ultimate installation completed!"
}

main "$@"