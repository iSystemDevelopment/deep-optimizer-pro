#!/bin/bash

#############################################################################
# Deep Optimizer Pro - Installation Script
# Version: 2.2.0
# Description: Install to /opt and expose `deep-optimizer` on PATH
#############################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/opt/deep-optimizer-pro"
BIN_PATH="/usr/local/bin/deep-optimizer"
CONFIG_DIR="/etc/deep-optimizer-pro"
LOG_DIR="/var/log/deep-optimizer-pro"
BACKUP_DIR="/var/backups/deep-optimizer-pro"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════╗"
    echo "║     Deep Optimizer Pro - Installation Script      ║"
    echo "║                  Version 2.2.0                    ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_requirements() {
    echo -e "${YELLOW}Checking system requirements...${NC}"
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Run as root: sudo ./install.sh${NC}"
        exit 1
    fi
    if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
        echo -e "${RED}Bash 4.0+ required${NC}"
        exit 1
    fi
    for cmd in grep sed awk find tar; do
        command -v "$cmd" &>/dev/null || { echo -e "${RED}Missing: $cmd${NC}"; exit 1; }
    done
    echo -e "${GREEN}OK — requirements met${NC}"
}

create_directories() {
    mkdir -p "$INSTALL_DIR/modules" "$INSTALL_DIR/lib" "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR"
}

copy_files() {
    echo -e "${YELLOW}Copying files...${NC}"
    # Strip CRLF if present (Windows clones)
    find "$SCRIPT_DIR" -name '*.sh' -exec sed -i 's/\r$//' {} + 2>/dev/null || true

    cp "$SCRIPT_DIR/deep-optimizer-pro.sh" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/run.sh" "$INSTALL_DIR/" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/deep-optimizer-pro.sh"
    [[ -f "$INSTALL_DIR/run.sh" ]] && chmod +x "$INSTALL_DIR/run.sh"

    if [[ -d "$SCRIPT_DIR/modules" ]]; then
        cp -r "$SCRIPT_DIR"/modules/* "$INSTALL_DIR/modules/"
        chmod +x "$INSTALL_DIR"/modules/*.sh
    fi
    if [[ -d "$SCRIPT_DIR/lib" ]]; then
        cp -r "$SCRIPT_DIR"/lib/* "$INSTALL_DIR/lib/"
        chmod +x "$INSTALL_DIR"/lib/*.sh 2>/dev/null || true
    fi
    for f in README.md QUICK_START.md LICENSE SECURITY.md; do
        [[ -f "$SCRIPT_DIR/$f" ]] && cp "$SCRIPT_DIR/$f" "$INSTALL_DIR/"
    done
    echo -e "${GREEN}OK — files copied${NC}"
}

create_config() {
    cat > "$CONFIG_DIR/config.conf" << 'EOF'
# Deep Optimizer Pro Configuration
LOG_LEVEL="INFO"
LOG_DIR="/var/log/deep-optimizer-pro"
BACKUP_DIR="/var/backups/deep-optimizer-pro"

# VPS defaults (override with env or profile flags)
# FORCE_VPS_PROFILE=true
# SSH_DISABLE_ROOT=false
# UFW_EXTRA_PORTS=80,443
# ENABLE_ANTIVIRUS=false
# SECURITY_FULL=false
# DOCKER_PRUNE_VOLUMES=false
EOF
    chmod 644 "$CONFIG_DIR/config.conf"
}

create_symlink() {
    ln -sf "$INSTALL_DIR/deep-optimizer-pro.sh" "$BIN_PATH"
    chmod +x "$BIN_PATH"
}

setup_systemd() {
    cat > /etc/systemd/system/deep-optimizer.service << EOF
[Unit]
Description=Deep Optimizer Pro quick maintenance
After=network-online.target

[Service]
Type=oneshot
ExecStart=$BIN_PATH --quick --yes --quiet
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/deep-optimizer.timer << EOF
[Unit]
Description=Deep Optimizer Pro weekly maintenance

[Timer]
OnCalendar=Sun *-*-* 03:30:00
Persistent=true
RandomizedDelaySec=30m

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    echo -e "${YELLOW}Optional weekly timer:${NC}"
    echo "  sudo systemctl enable --now deep-optimizer.timer"
}

install_dependencies() {
    echo -e "${YELLOW}Installing core dependencies (best effort)...${NC}"
    # Keep lean for VPS — skip preload (desktop-oriented)
    local apt_pkgs="ufw fail2ban curl ca-certificates"
    if command -v apt-get &>/dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        # shellcheck disable=SC2086
        apt-get install -y -qq $apt_pkgs 2>/dev/null || true
    elif command -v dnf &>/dev/null; then
        dnf install -y ufw fail2ban curl ca-certificates 2>/dev/null || true
    fi
    echo -e "${GREEN}OK — core deps attempted${NC}"
}

setup_completion() {
    mkdir -p /etc/bash_completion.d
    cat > /etc/bash_completion.d/deep-optimizer << 'EOF'
_deep_optimizer() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="--help --version --full --quick --vps --update --harden --dry-run --verbose --quiet --yes --module --profile"
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
    case "${prev}" in
        --module) COMPREPLY=( $(compgen -W "storage performance security" -- ${cur}) ) ;;
        --profile) COMPREPLY=( $(compgen -W "auto vps desktop full" -- ${cur}) ) ;;
    esac
}
complete -F _deep_optimizer deep-optimizer
EOF
}

uninstall() {
    echo -e "${RED}Uninstalling Deep Optimizer Pro...${NC}"
    read -r -p "Are you sure? (y/N): " reply
    [[ "$reply" =~ ^[Yy]$ ]] || exit 0
    systemctl disable --now deep-optimizer.timer 2>/dev/null || true
    rm -rf "$INSTALL_DIR" "$BIN_PATH"
    rm -f /etc/systemd/system/deep-optimizer.service /etc/systemd/system/deep-optimizer.timer
    rm -f /etc/bash_completion.d/deep-optimizer
    read -r -p "Remove config/logs/backups? (y/N): " reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        rm -rf "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR"
    fi
    systemctl daemon-reload
    echo -e "${GREEN}Uninstalled${NC}"
}

verify_installation() {
    [[ -f "$INSTALL_DIR/deep-optimizer-pro.sh" ]] || return 1
    [[ -L "$BIN_PATH" || -f "$BIN_PATH" ]] || return 1
    bash -n "$INSTALL_DIR/deep-optimizer-pro.sh"
    echo -e "${GREEN}OK — installation verified${NC}"
}

main() {
    case "${1:-}" in
        --uninstall) uninstall; exit 0 ;;
        --help)
            echo "Usage: sudo $0 [--uninstall]"
            exit 0
            ;;
    esac

    show_banner
    check_requirements
    create_directories
    copy_files
    create_config
    create_symlink
    setup_systemd
    install_dependencies
    setup_completion
    verify_installation

    echo
    echo -e "${GREEN}Installed.${NC} Try:"
    echo -e "  ${CYAN}sudo deep-optimizer --vps --dry-run${NC}"
    echo -e "  ${CYAN}sudo deep-optimizer --vps${NC}"
    echo -e "  ${CYAN}sudo deep-optimizer${NC}   # interactive menu"
    echo
}

main "$@"
