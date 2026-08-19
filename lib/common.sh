#!/bin/bash

#############################################################################
# Deep Optimizer Pro - Common Library Functions
# Version: 2.2.0
# Description: Shared functions and utilities
#############################################################################

# Color definitions
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m'

# Global variables
export SCRIPT_VERSION="${SCRIPT_VERSION:-2.2.0}"
export SCRIPT_NAME="${SCRIPT_NAME:-Deep Optimizer Pro}"
export LOG_DIR="${LOG_DIR:-/var/log/deep-optimizer-pro}"
export BACKUP_DIR="${BACKUP_DIR:-/var/backups/deep-optimizer-pro}"
export CONFIG_FILE="${CONFIG_FILE:-/etc/deep-optimizer-pro/config.conf}"

# Logging levels
export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_WARNING=2
export LOG_LEVEL_ERROR=3
export CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# Initialize logging
init_logging() {
    [[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR" 2>/dev/null || sudo mkdir -p "$LOG_DIR"
    local log_file="$LOG_DIR/optimization.log"
    touch "$log_file" 2>/dev/null || sudo touch "$log_file"
}

# Enhanced logging function
log_message() {
    local level=$1
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$LOG_DIR/optimization.log"

    local level_num
    case $level in
        DEBUG)   level_num=$LOG_LEVEL_DEBUG ;;
        INFO)    level_num=$LOG_LEVEL_INFO ;;
        WARNING) level_num=$LOG_LEVEL_WARNING ;;
        ERROR)   level_num=$LOG_LEVEL_ERROR ;;
        SUCCESS) level_num=$LOG_LEVEL_INFO ;;
        *)       level_num=$LOG_LEVEL_INFO ;;
    esac

    if [[ $level_num -ge $CURRENT_LOG_LEVEL ]]; then
        if [[ -w "$log_file" ]] 2>/dev/null; then
            echo "[$timestamp] [$level] $message" >> "$log_file"
        else
            echo "[$timestamp] [$level] $message" | sudo tee -a "$log_file" >/dev/null 2>&1 || true
        fi

        # Quiet mode: only warnings/errors/success summary
        if [[ ${QUIET:-false} == true ]] && [[ "$level" == "INFO" || "$level" == "DEBUG" ]]; then
            return 0
        fi

        case $level in
            ERROR)   echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
            WARNING) echo -e "${YELLOW}[WARN]${NC}  $message" ;;
            SUCCESS) echo -e "${GREEN}[OK]${NC}    $message" ;;
            INFO)    echo -e "${CYAN}[INFO]${NC}  $message" ;;
            DEBUG)   [[ ${VERBOSE:-false} == true ]] && echo -e "${BLUE}[DEBUG]${NC} $message" ;;
            *)       echo "$message" ;;
        esac
    fi
}

# Check if running with required privileges
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_message ERROR "This script requires root privileges. Please run with sudo."
        exit 1
    fi
    log_message DEBUG "Root privileges confirmed."
}

# Get distribution information
get_distro_info() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        export DISTRO_NAME="$NAME"
        export DISTRO_VERSION="$VERSION_ID"
        export DISTRO_ID="$ID"
        export DISTRO_ID_LIKE="${ID_LIKE:-$ID}"
    else
        export DISTRO_NAME="Unknown"
        export DISTRO_VERSION="Unknown"
        export DISTRO_ID="unknown"
        export DISTRO_ID_LIKE="unknown"
    fi

    log_message DEBUG "Detected: $DISTRO_NAME $DISTRO_VERSION ($DISTRO_ID)"
}

# Detect VPS / cloud / headless servers
detect_environment() {
    export IS_VPS=false
    export IS_CONTAINER=false
    export IS_DESKTOP=false

    if [[ -f /.dockerenv ]] || grep -qaE 'docker|lxc|kubepods' /proc/1/cgroup 2>/dev/null; then
        export IS_CONTAINER=true
    fi

    # Cloud / VPS heuristics
    if [[ -d /sys/class/dmi/id ]]; then
        local product
        product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
        local vendor
        vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
        if echo "$product $vendor" | grep -qiE 'DigitalOcean|Linode|Vultr|Hetzner|OVH|Amazon|Google|Microsoft|QEMU|KVM|VMware|Xen|OpenStack|Cloud'; then
            export IS_VPS=true
        fi
    fi

    # Headless / no graphical target often = server
    if systemctl is-active --quiet graphical.target 2>/dev/null; then
        export IS_DESKTOP=true
    elif [[ -z "${DISPLAY:-}" ]] && [[ ! -d /run/user/1000 ]]; then
        # Prefer VPS profile on typical Ubuntu server installs
        if [[ "$DISTRO_ID" =~ ^(ubuntu|debian)$ ]]; then
            export IS_VPS=true
        fi
    fi

    # Explicit override
    if [[ "${FORCE_VPS_PROFILE:-false}" == true ]]; then
        export IS_VPS=true
    fi

    log_message DEBUG "Environment: IS_VPS=$IS_VPS IS_DESKTOP=$IS_DESKTOP IS_CONTAINER=$IS_CONTAINER"
}

# Detect listening SSH port from sshd_config (default 22)
get_ssh_port() {
    local port=22
    if [[ -f /etc/ssh/sshd_config ]]; then
        local configured
        configured=$(grep -E '^[Pp]ort[[:space:]]+' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | tail -1)
        if [[ "$configured" =~ ^[0-9]+$ ]]; then
            port=$configured
        fi
    fi
    echo "$port"
}

# Package manager detection
detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        export PKG_MANAGER="apt"
        export PKG_INSTALL="apt-get install -y"
        export PKG_REMOVE="apt-get remove -y"
        export PKG_UPDATE="apt-get update"
        export PKG_UPGRADE="apt-get upgrade -y"
        export PKG_CLEAN="apt-get autoremove -y && apt-get autoclean -y"
    elif command -v dnf &>/dev/null; then
        export PKG_MANAGER="dnf"
        export PKG_INSTALL="dnf install -y"
        export PKG_REMOVE="dnf remove -y"
        export PKG_UPDATE="dnf check-update || true"
        export PKG_UPGRADE="dnf upgrade -y"
        export PKG_CLEAN="dnf autoremove -y && dnf clean all"
    elif command -v yum &>/dev/null; then
        export PKG_MANAGER="yum"
        export PKG_INSTALL="yum install -y"
        export PKG_REMOVE="yum remove -y"
        export PKG_UPDATE="yum check-update || true"
        export PKG_UPGRADE="yum update -y"
        export PKG_CLEAN="yum autoremove -y && yum clean all"
    elif command -v pacman &>/dev/null; then
        export PKG_MANAGER="pacman"
        export PKG_INSTALL="pacman -S --noconfirm"
        export PKG_REMOVE="pacman -R --noconfirm"
        export PKG_UPDATE="pacman -Sy"
        export PKG_UPGRADE="pacman -Syu --noconfirm"
        export PKG_CLEAN="pacman -Sc --noconfirm"
    elif command -v zypper &>/dev/null; then
        export PKG_MANAGER="zypper"
        export PKG_INSTALL="zypper install -y"
        export PKG_REMOVE="zypper remove -y"
        export PKG_UPDATE="zypper refresh"
        export PKG_UPGRADE="zypper update -y"
        export PKG_CLEAN="zypper clean -a"
    else
        export PKG_MANAGER="unknown"
        export PKG_INSTALL="true"
        export PKG_REMOVE="true"
        export PKG_UPDATE="true"
        export PKG_UPGRADE="true"
        export PKG_CLEAN="true"
        log_message WARNING "Package manager not detected. Package-related functions will be skipped."
    fi

    log_message DEBUG "Package manager: $PKG_MANAGER"
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    [[ $total -lt 1 ]] && total=1
    local percentage=$((current * 100 / total))
    local filled=$((percentage * width / 100))

    printf "\rProgress: ["
    printf "%${filled}s" | tr ' ' '#'
    printf "%$((width - filled))s" | tr ' ' '-'
    printf "] %3d%%" "$percentage"
}

# Confirm action (for dangerous operations)
confirm_action() {
    local message=${1:-"Are you sure?"}

    if [[ ${ASSUME_YES:-false} == true ]]; then
        return 0
    fi

    log_message WARNING "$message"
    echo -e "${RED}This may be destructive. Type ${YELLOW}YES${NC}${RED} to proceed:${NC}"
    read -r user_input

    if [[ "$user_input" != "YES" ]]; then
        log_message INFO "Action cancelled by user."
        return 1
    fi
    return 0
}

# Persist a sysctl key (live + /etc/sysctl.d)
apply_sysctl_persistent() {
    local key="$1"
    local value="$2"
    local file="${3:-/etc/sysctl.d/99-deep-optimizer.conf}"

    if [[ ${DRY_RUN:-false} == true ]]; then
        log_message INFO "[DRY RUN] Would set $key=$value (persistent in $file)"
        return 0
    fi

    sysctl -w "$key=$value" >/dev/null 2>&1 || true
    mkdir -p "$(dirname "$file")"
    touch "$file"
    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null; then
        sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key}=${value}|" "$file"
    else
        echo "${key}=${value}" >> "$file"
    fi
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
        log_message DEBUG "Configuration loaded from: $CONFIG_FILE"

        case ${LOG_LEVEL:-"INFO"} in
            DEBUG)   export CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
            INFO)    export CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
            WARNING) export CURRENT_LOG_LEVEL=$LOG_LEVEL_WARNING ;;
            ERROR)   export CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
            *)       export CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
        esac
    else
        log_message DEBUG "Configuration file not found, using defaults: $CONFIG_FILE"
    fi
}

# Initialize
init_common() {
    load_config
    init_logging
    get_distro_info
    detect_package_manager
    detect_environment

    mkdir -p "$BACKUP_DIR" 2>/dev/null || sudo mkdir -p "$BACKUP_DIR"
}

# Export all functions
export -f log_message
export -f check_privileges
export -f get_distro_info
export -f detect_environment
export -f get_ssh_port
export -f detect_package_manager
export -f show_progress
export -f load_config
export -f init_logging
export -f init_common
export -f confirm_action
export -f apply_sysctl_persistent
