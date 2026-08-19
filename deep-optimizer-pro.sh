#!/bin/bash

#############################################################################
# Deep Optimizer Pro - Advanced Linux System Optimization Tool
# Version: 2.2.0
# Author: iSystem Development
# License: MIT
# Repository: https://github.com/iSystemDevelopment/deep-optimizer-pro
#############################################################################

set -o pipefail

SCRIPT_VERSION="2.2.0"
SCRIPT_NAME="Deep Optimizer Pro"

# Resolve install directory (follow symlinks)
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
INSTALL_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

LIB_DIR="$INSTALL_DIR/lib"
MODULE_DIR="$INSTALL_DIR/modules"

# Defaults
DRY_RUN=false
VERBOSE=false
QUICK_MODE=false
QUIET=false
ASSUME_YES=false
PROFILE="auto"   # auto | vps | desktop | full

# Source common library
if [[ -f "$LIB_DIR/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "$LIB_DIR/common.sh"
else
    echo -e "\033[0;31m[ERROR]\033[0m Critical file not found: $LIB_DIR/common.sh"
    exit 1
fi

# Source modules
if [[ -d "$MODULE_DIR" ]]; then
    shopt -s nullglob
    for module in "$MODULE_DIR"/*.sh; do
        # shellcheck disable=SC1090
        source "$module"
    done
    shopt -u nullglob
else
    echo -e "\033[0;31m[ERROR]\033[0m Module directory not found: $MODULE_DIR"
    exit 1
fi

apply_profile() {
    case "$PROFILE" in
        auto)
            if [[ "${IS_VPS:-false}" == true ]] || [[ "${IS_DESKTOP:-false}" != true ]]; then
                export FORCE_VPS_PROFILE=true
                PROFILE="vps"
            else
                PROFILE="desktop"
            fi
            ;;
        vps)
            export FORCE_VPS_PROFILE=true
            ;;
        desktop|full) ;;
        *)
            log_message WARNING "Unknown profile '$PROFILE' — using auto"
            PROFILE="auto"
            apply_profile
            return
            ;;
    esac
    log_message INFO "Active profile: $PROFILE"
}

show_system_info() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}           DEEP OPTIMIZER PRO - SYSTEM INFORMATION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"

    echo -e "${BLUE}System:${NC} $(uname -s) $(uname -r)"
    echo -e "${BLUE}Distribution:${NC} $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
    echo -e "${BLUE}Hostname:${NC} $(hostname)"
    echo -e "${BLUE}Uptime:${NC} $(uptime -p 2>/dev/null || uptime)"
    echo -e "${BLUE}Memory:${NC} $(free -h | awk '/^Mem:/ {print $2 " total, " $3 " used, " $4 " free"}')"
    echo -e "${BLUE}Disk /:${NC} $(df -h / | awk 'NR==2 {print $2 " total, " $3 " used, " $4 " free (" $5 " used)"}')"
    echo -e "${BLUE}Load:${NC} $(uptime | awk -F'load average:' '{print $2}')"
    echo -e "${BLUE}CPU:${NC} $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs 2>/dev/null || echo n/a)"
    echo -e "${BLUE}Cores:${NC} $(nproc)"
    echo -e "${BLUE}SSH port:${NC} $(get_ssh_port)"
    echo -e "${BLUE}Profile hint:${NC} IS_VPS=${IS_VPS:-?} IS_DESKTOP=${IS_DESKTOP:-?} PKG=${PKG_MANAGER:-?}"
    echo ""
}

generate_report() {
    local report_file="$LOG_DIR/optimization_report_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "Deep Optimizer Pro - Optimization Report"
        echo "========================================="
        echo "Date: $(date)"
        echo "Version: $SCRIPT_VERSION"
        echo "Profile: $PROFILE"
        echo "Dry-run: $DRY_RUN"
        echo ""
        echo "System:"
        uname -a
        echo ""
        df -h
        echo ""
        free -h
        echo ""
        echo "Top memory processes:"
        ps aux --sort=-%mem | head -10
    } > "$report_file" 2>/dev/null || {
        {
            echo "Deep Optimizer Pro report $(date)"
            uname -a
            df -h
        } | tee "$report_file" >/dev/null
    }

    log_message SUCCESS "Report generated: $report_file"
}

backup_config() {
    log_message INFO "Creating configuration backup..."

    local backup_file="$BACKUP_DIR/config_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    mkdir -p "$BACKUP_DIR"

    if [[ $DRY_RUN == false ]]; then
        local paths=(/etc/fstab /etc/hosts /etc/hostname /etc/ssh/sshd_config)
        [[ -d /etc/sysctl.d ]] && paths+=(/etc/sysctl.d)
        [[ -d /etc/ufw ]] && paths+=(/etc/ufw)
        [[ -d /etc/fail2ban ]] && paths+=(/etc/fail2ban)
        [[ -d /etc/netplan ]] && paths+=(/etc/netplan)
        [[ -d /etc/network ]] && paths+=(/etc/network)
        tar czf "$backup_file" "${paths[@]}" 2>/dev/null || true
    else
        log_message INFO "[DRY RUN] Would back up system config to $backup_file"
    fi

    log_message SUCCESS "Configuration backed up to $backup_file"
}

# --- Profiles ---

run_vps_optimization() {
    echo -e "\n${CYAN}Starting VPS / Ubuntu Server Optimization...${NC}\n"
    local tasks=8 current=0

    ((current++)); show_progress $current $tasks
    backup_config

    ((current++)); show_progress $current $tasks
    update_system

    ((current++)); show_progress $current $tasks
    optimize_packages
    clean_old_kernels
    clean_temp_files
    clean_logs
    clean_docker
    clean_snap

    ((current++)); show_progress $current $tasks
    optimize_kernel_parameters
    optimize_memory
    optimize_network
    optimize_systemd

    ((current++)); show_progress $current $tasks
    # Server-oriented: skip GPU/preload/gaming services
    optimize_services

    ((current++)); show_progress $current $tasks
    harden_ssh
    setup_firewall
    setup_fail2ban

    ((current++)); show_progress $current $tasks
    harden_kernel
    harden_file_permissions_safe

    ((current++)); show_progress $current $tasks
    echo -e "\n"
    generate_report

    echo -e "\n${GREEN}VPS optimization complete.${NC}"
    echo -e "${YELLOW}Tip:${NC} Review UFW rules and SSH access before disconnecting remote sessions.\n"
}

run_full_optimization() {
    echo -e "\n${CYAN}Starting Full System Optimization...${NC}\n"
    local tasks=10 current=0

    ((current++)); show_progress $current $tasks; backup_config
    ((current++)); show_progress $current $tasks; update_system
    ((current++)); show_progress $current $tasks
    optimize_packages; clean_old_kernels; clean_docker; clean_snap; clean_flatpak
    clean_temp_files; clean_browser_cache; clean_thumbnail_cache; clean_dev_caches

    ((current++)); show_progress $current $tasks; optimize_cpu_governor
    ((current++)); show_progress $current $tasks; optimize_io_scheduler
    ((current++)); show_progress $current $tasks; optimize_kernel_parameters
    ((current++)); show_progress $current $tasks; optimize_zram; optimize_memory
    ((current++)); show_progress $current $tasks; harden_ssh; setup_firewall; setup_fail2ban
    ((current++)); show_progress $current $tasks; harden_file_permissions_safe; harden_kernel
    ((current++)); show_progress $current $tasks
    echo -e "\n"
    generate_report
    echo -e "\n${GREEN}Full system optimization complete.${NC}\n"
}

run_quick_optimization() {
    echo -e "\n${CYAN}Starting Quick Optimization...${NC}\n"
    QUICK_MODE=true
    optimize_packages
    clean_temp_files
    clean_logs
    optimize_memory
    QUICK_MODE=false
    echo -e "\n${GREEN}Quick optimization complete.${NC}\n"
}

run_update_only() {
    echo -e "\n${CYAN}System update + package cleanup...${NC}\n"
    update_system
    optimize_packages
    clean_logs
    echo -e "\n${GREEN}Update complete.${NC}\n"
}

run_harden_only() {
    echo -e "\n${CYAN}Security hardening (VPS-safe defaults)...${NC}\n"
    backup_config
    harden_ssh
    setup_firewall
    setup_fail2ban
    harden_kernel
    harden_file_permissions_safe
    echo -e "\n${GREEN}Hardening complete.${NC}\n"
}

show_menu() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}     ${WHITE}DEEP OPTIMIZER PRO${NC} — Linux / Ubuntu VPS      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                  ${YELLOW}Version $SCRIPT_VERSION${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} VPS Optimize (update + clean + harden)  ${YELLOW}← recommended for servers${NC}"
    echo -e "${GREEN}2.${NC} Quick Optimize (clean + free memory)"
    echo -e "${GREEN}3.${NC} Full Optimize (desktop/workstation style)"
    echo -e "${GREEN}4.${NC} Update packages only"
    echo -e "${GREEN}5.${NC} Harden only (SSH / UFW / Fail2ban / sysctl)"
    echo ""
    echo -e "${MAGENTA}--- Modules ---${NC}"
    echo -e "${GREEN}6.${NC} Storage module"
    echo -e "${GREEN}7.${NC} Performance module"
    echo -e "${GREEN}8.${NC} Security module (full)"
    echo ""
    echo -e "${MAGENTA}--- System ---${NC}"
    echo -e "${GREEN}9.${NC}  Show system information"
    echo -e "${GREEN}10.${NC} Backup configuration"
    echo -e "${GREEN}11.${NC} Dry-run VPS optimize (preview)"
    echo -e "${RED}0.${NC}  Exit"
    echo ""
    echo -n "Select an option: "
}

show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION — Linux / Ubuntu VPS optimizer

Usage: sudo $0 [OPTIONS]

Options:
  -h, --help            Show help
  -v, --verbose         Extra debug lines
  -q, --quiet           Less console noise
  -y, --yes             Skip confirmations (non-interactive)
  -d, --dry-run         Preview only (no changes)
  --quick               Quick clean
  --full                Full optimization
  --vps                 VPS profile (update + clean + harden)
  --update              apt/dnf upgrade + package cleanup
  --harden              SSH / firewall / fail2ban / sysctl only
  --profile <name>      auto | vps | desktop | full
  --module <name>       storage | performance | security
  --version             Show version

Examples (Ubuntu VPS):
  sudo ./deep-optimizer-pro.sh --vps
  sudo ./deep-optimizer-pro.sh --vps --dry-run
  sudo ./deep-optimizer-pro.sh --update
  sudo ./deep-optimizer-pro.sh --harden
  curl -fsSL https://raw.githubusercontent.com/iSystemDevelopment/deep-optimizer-pro/main/run.sh | sudo bash -s -- --vps

Install once:
  sudo ./install.sh
  sudo deep-optimizer --vps
EOF
}

parse_arguments() {
    local run_action=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            -v|--verbose) VERBOSE=true; export VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; export QUIET=true; shift ;;
            -y|--yes) ASSUME_YES=true; export ASSUME_YES=true; shift ;;
            -d|--dry-run)
                DRY_RUN=true; export DRY_RUN=true
                echo -e "${YELLOW}DRY RUN — no changes will be made${NC}"
                shift
                ;;
            --quick) run_action="quick"; shift ;;
            --full) run_action="full"; shift ;;
            --vps) run_action="vps"; PROFILE="vps"; shift ;;
            --update) run_action="update"; shift ;;
            --harden) run_action="harden"; shift ;;
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --module)
                case "$2" in
                    storage) run_action="mod_storage" ;;
                    performance) run_action="mod_perf" ;;
                    security) run_action="mod_sec" ;;
                    *) log_message ERROR "Unknown module: $2"; exit 1 ;;
                esac
                shift 2
                ;;
            --version)
                echo "$SCRIPT_NAME version $SCRIPT_VERSION"
                exit 0
                ;;
            *)
                log_message ERROR "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    apply_profile

    case "$run_action" in
        quick)  run_quick_optimization; exit 0 ;;
        full)   run_full_optimization; exit 0 ;;
        vps)    run_vps_optimization; exit 0 ;;
        update) run_update_only; exit 0 ;;
        harden) run_harden_only; exit 0 ;;
        mod_storage) run_storage_module_main; exit 0 ;;
        mod_perf) run_performance_module_main; exit 0 ;;
        mod_sec) run_security_module_main; exit 0 ;;
        "") ;;
    esac
}

main() {
    # Allow help/version without root
    case "${1:-}" in
        -h|--help)
            # shellcheck disable=SC1091
            [[ -f "$LIB_DIR/common.sh" ]] && source "$LIB_DIR/common.sh"
            show_help
            exit 0
            ;;
        --version)
            echo "$SCRIPT_NAME version $SCRIPT_VERSION"
            exit 0
            ;;
    esac

    init_common
    check_privileges

    if [[ $# -gt 0 ]]; then
        parse_arguments "$@"
        apply_profile
    else
        apply_profile
    fi

    while true; do
        show_menu
        read -r choice
        case $choice in
            1) run_vps_optimization; read -rp "Press Enter..." ;;
            2) run_quick_optimization; read -rp "Press Enter..." ;;
            3) run_full_optimization; read -rp "Press Enter..." ;;
            4) run_update_only; read -rp "Press Enter..." ;;
            5) run_harden_only; read -rp "Press Enter..." ;;
            6) run_storage_module_main; read -rp "Press Enter..." ;;
            7) run_performance_module_main; read -rp "Press Enter..." ;;
            8) run_security_module_main; read -rp "Press Enter..." ;;
            9) show_system_info; read -rp "Press Enter..." ;;
            10) backup_config; read -rp "Press Enter..." ;;
            11)
                DRY_RUN=true; export DRY_RUN=true
                echo -e "${YELLOW}Dry run mode${NC}"
                run_vps_optimization
                DRY_RUN=false; export DRY_RUN=false
                read -rp "Press Enter..."
                ;;
            0)
                echo -e "${GREEN}Thank you for using $SCRIPT_NAME.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

trap 'echo -e "\n${YELLOW}Interrupted${NC}"; exit 130' INT TERM
main "$@"
