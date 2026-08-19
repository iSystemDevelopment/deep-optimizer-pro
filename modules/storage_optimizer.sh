#!/bin/bash

#############################################################################
# Deep Optimizer Pro - Storage Optimization Module
# Version: 2.1.0
# Description: Advanced storage management and optimization
#############################################################################

# This script is intended to be sourced by deep-optimizer-pro.sh
# It expects $DRY_RUN and log_message() to be available.

# Storage analysis function
analyze_storage() {
    log_message INFO "Analyzing storage usage..."
    
    log_message INFO "Large files (>100MB):"
    sudo find / -type f -size +100M 2>/dev/null | head -20
    
    if command -v fdupes &>/dev/null; then
        log_message INFO "Checking for duplicate files..."
        fdupes -r "$HOME" 2>/dev/null | head -50
    fi
    
    log_message INFO "Top disk usage by directory:"
    sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head -20
}

# Clean old kernels
clean_old_kernels() {
    log_message INFO "Cleaning old kernel versions..."
    
    if [[ ${DRY_RUN:-false} == true ]]; then
        log_message INFO "[DRY RUN] Would check for and remove old kernels"
        return
    fi

    case "${PKG_MANAGER:-unknown}" in
        apt)
            local current_kernel=$(uname -r)
            dpkg -l 'linux-*' | grep ^ii | grep -v "$current_kernel" | \
            awk '{print $2}' | grep -E '(image|headers|modules)' | \
            xargs sudo apt-get -y purge 2>/dev/null || true
            ;;
        dnf|yum)
            log_message INFO "Running 'autoremove' to clean old DNF/YUM kernels..."
            sudo dnf autoremove -y 2>/dev/null || sudo yum autoremove -y 2>/dev/null || true
            ;;
        pacman)
            log_message DEBUG "Kernel cleanup skipped for Pacman"
            ;;
        *)
            log_message WARNING "Kernel cleanup not supported for this package manager."
            ;;
    esac
}

# Optimize filesystem
optimize_filesystem() {
    log_message INFO "Optimizing filesystem..."

    # Defragment ext4 filesystems
    for fs in $(mount -t ext4 | awk '{print $1}'); do
        if [[ -b "$fs" ]]; then
            if [[ ${DRY_RUN:-false} == false ]]; then
                log_message INFO "Defragmenting $fs..."
                sudo e4defrag "$fs" 2>/dev/null || true
            else
                log_message INFO "[DRY RUN] Would defragment $fs"
            fi
        fi
    done
    
    # TRIM SSD if supported
    if command -v fstrim &>/dev/null; then
        if [[ ${DRY_RUN:-false} == false ]]; then
            log_message INFO "Trimming SSDs..."
            sudo fstrim -av 2>/dev/null || true
        else
            log_message INFO "[DRY RUN] Would run fstrim -av"
        fi
    fi
}

# Clean language / toolchain package caches (pip, npm, ...)
clean_package_caches() {
    clean_dev_caches
}

clean_dev_caches() {
    log_message INFO "Cleaning development package manager caches..."
    
    if [[ ${DRY_RUN:-false} == true ]]; then
        log_message INFO "[DRY RUN] Would clean all dev package manager caches"
        return
    fi
    
    # Clean pip cache
    if command -v pip &>/dev/null; then pip cache purge 2>/dev/null || true; fi
    if command -v pip3 &>/dev/null; then pip3 cache purge 2>/dev/null || true; fi
    
    # Clean npm cache
    if command -v npm &>/dev/null; then npm cache clean --force 2>/dev/null || true; fi
    
    # Clean yarn cache
    if command -v yarn &>/dev/null; then yarn cache clean 2>/dev/null || true; fi
    
    # Clean composer cache
    if command -v composer &>/dev/null; then composer clear-cache 2>/dev/null || true; fi
    
    # Clean gem cache
    if command -v gem &>/dev/null; then gem cleanup 2>/dev/null || true; fi
    
    # Clean cargo cache
    if [[ -d "$HOME/.cargo/registry" ]]; then
        rm -rf "$HOME/.cargo/registry/cache" 2>/dev/null || true
        rm -rf "$HOME/.cargo/registry/src" 2>/dev/null || true
    fi
    
    # Clean go cache
    if command -v go &>/dev/null; then go clean -cache -modcache 2>/dev/null || true; fi
}

# Clean build artifacts
clean_build_artifacts() {
    log_message INFO "Cleaning build artifacts..."
    
    local build_dirs=(
        "node_modules" "target" "dist" "build"
        "__pycache__" ".pytest_cache" ".tox" "vendor"
    )
    
    for dir_name in "${build_dirs[@]}"; do
        if [[ ${DRY_RUN:-false} == false ]]; then
            find "$HOME" -type d -name "$dir_name" -prune -exec rm -rf {} \; 2>/dev/null || true
        else
            log_message INFO "[DRY RUN] Would find and remove dirs named $dir_name"
        fi
    done
}

# Archive old files
archive_old_files() {
    log_message INFO "Archiving old files..."
    
    local archive_dir="$HOME/Archive/$(date +%Y%m)"
    
    if [[ ${DRY_RUN:-false} == false ]]; then
        mkdir -p "$archive_dir"
        
        find "$HOME/Documents" "$HOME/Downloads" -type f -atime +180 \
            -exec mv {} "$archive_dir/" \; 2>/dev/null || true
        
        if [[ -n "$(ls -A "$archive_dir" 2>/dev/null)" ]]; then
            tar czf "$archive_dir.tar.gz" "$archive_dir" && rm -rf "$archive_dir"
            log_message SUCCESS "Old files archived to $archive_dir.tar.gz"
        else
            rmdir "$archive_dir" 2>/dev/null
        fi
    else
        log_message INFO "[DRY RUN] Would find files > 180 days old and move to $archive_dir"
    fi
}

# Clean thumbnail cache
clean_thumbnail_cache() {
    log_message INFO "Cleaning thumbnail caches..."
    if [[ ${DRY_RUN:-false} == false ]]; then
        rm -rf "$HOME/.cache/thumbnails"/* 2>/dev/null || true
        rm -rf "$HOME/.thumbnails"/* 2>/dev/null || true
    else
        log_message INFO "[DRY RUN] Would clean thumbnail caches"
    fi
}

# Database optimization
optimize_databases() {
    log_message INFO "Optimizing databases..."
    
    if [[ ${DRY_RUN:-false} == true ]]; then
        log_message INFO "[DRY RUN] Would optimize SQLite, MySQL, and PostgreSQL databases"
        return
    fi
    
    # SQLite databases
    find "$HOME" -name "*.sqlite" -o -name "*.sqlite3" -o -name "*.db" 2>/dev/null | \
    while read -r db; do
        sqlite3 "$db" "VACUUM;" 2>/dev/null || true
        sqlite3 "$db" "REINDEX;" 2>/dev/null || true
    done
    
    # MySQL/MariaDB optimization
    if command -v mysqlcheck &>/dev/null; then
        mysqlcheck --all-databases --optimize --auto-repair 2>/dev/null || true
    fi
    
    # PostgreSQL optimization
    if command -v vacuumdb &>/dev/null; then
        vacuumdb --all --analyze 2>/dev/null || true
    fi
}

# Clean Wine prefix
clean_wine() {
    if [[ -d "$HOME/.wine" ]]; then
        log_message INFO "Cleaning Wine prefix..."
        if [[ ${DRY_RUN:-false} == false ]]; then
            rm -rf "$HOME/.wine/drive_c/windows/temp"/* 2>/dev/null || true
            rm -rf "$HOME/.wine/drive_c/users/$USER/Temp"/* 2>/dev/null || true
        else
            log_message INFO "[DRY RUN] Would clean Wine temp directories"
        fi
    fi
}

# --- Module Functions from deep-optimizer-pro.sh ---
# (These were originally in the main script, but belong to storage)


# System package update (Ubuntu/Debian VPS friendly)
update_system() {
    log_message INFO "Updating system packages..."
    
    if [[ ${DRY_RUN:-false} == true ]]; then
        log_message INFO "[DRY RUN] Would run package update/upgrade via $PKG_MANAGER"
        return
    fi
    
    case "${PKG_MANAGER:-unknown}" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get upgrade -y -qq
            apt-get dist-upgrade -y -qq || true
            ;;
        dnf|yum|pacman|zypper)
            $PKG_UPDATE || true
            $PKG_UPGRADE || true
            ;;
        *)
            log_message WARNING "System update skipped (unknown package manager)"
            return
            ;;
    esac
    log_message SUCCESS "System packages updated"
}

optimize_packages() {
    log_message INFO "Starting package management optimization..."
    
    if [[ ${DRY_RUN:-false} == true ]]; then
        log_message INFO "[DRY RUN] Would optimize ${PKG_MANAGER:-unknown} packages"
        return
    fi
    
    case "${PKG_MANAGER:-unknown}" in
        apt)
            sudo apt-get update -qq
            sudo apt-get autoremove -y -qq
            sudo apt-get autoclean -y -qq
            sudo apt-get clean -qq
            if command -v deborphan &>/dev/null; then
                sudo deborphan | xargs sudo apt-get -y remove --purge 2>/dev/null || true
            fi
            ;;
        yum)
            sudo yum clean all -q
            sudo yum autoremove -y -q
            ;;
        dnf)
            sudo dnf clean all -q
            sudo dnf autoremove -y -q
            ;;
        pacman)
            sudo pacman -Sc --noconfirm
            sudo pacman -Rns $(pacman -Qtdq) --noconfirm 2>/dev/null || true
            ;;
    esac
    log_message SUCCESS "Package manager optimized"
}

clean_temp_files() {
    log_message INFO "Cleaning temporary files..."
    
    local temp_dirs=("/tmp" "/var/tmp" "$HOME/.cache" "$HOME/.local/share/Trash")
    
    for dir in "${temp_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ ${DRY_RUN:-false} == false ]]; then
                case "$dir" in
                    "/tmp"|"/var/tmp")
                        sudo find "$dir" -type f -atime +7 -delete 2>/dev/null || true
                        sudo find "$dir" -type d -empty -delete 2>/dev/null || true
                        ;;
                    *)
                        find "$dir" -type f -atime +30 -delete 2>/dev/null || true
                        find "$dir" -type d -empty -delete 2>/dev/null || true
                        ;;
                esac
            else
                 log_message INFO "[DRY RUN] Would clean $dir"
            fi
        fi
    done
    log_message SUCCESS "Cleaned temporary files"
}

clean_logs() {
    log_message INFO "Cleaning system logs..."
    if [[ ${DRY_RUN:-false} == false ]]; then
        sudo journalctl --vacuum-time=7d 2>/dev/null || true
        sudo find /var/log -type f -name "*.log" -mtime +30 -delete 2>/dev/null || true
        sudo find /var/log -type f -name "*.gz" -mtime +30 -delete 2>/dev/null || true
        sudo find /var/log -type f -name "*.log" -size +100M -exec truncate -s 0 {} \; 2>/dev/null || true
    else
        log_message INFO "[DRY RUN] Would clean journal and /var/log files"
    fi
    log_message SUCCESS "System logs cleaned"
}

clean_docker() {
    if command -v docker &>/dev/null; then
        log_message INFO "Cleaning Docker resources..."
        if [[ ${DRY_RUN:-false} == false ]]; then
            docker container prune -f 2>/dev/null || true
            docker image prune -a -f 2>/dev/null || true
            docker volume prune -f 2>/dev/null || true
            docker network prune -f 2>/dev/null || true
            if [[ ${QUICK_MODE:-false} == false ]] && [[ ${DOCKER_PRUNE_VOLUMES:-false} == true ]]; then
                docker system prune -a -f --volumes 2>/dev/null || true
            elif [[ ${QUICK_MODE:-false} == false ]]; then
                docker system prune -a -f 2>/dev/null || true
            fi
        else
            log_message INFO "[DRY RUN] Would prune Docker resources"
        fi
        log_message SUCCESS "Docker resources cleaned"
    fi
}

clean_snap() {
    if command -v snap &>/dev/null; then
        log_message INFO "Cleaning Snap packages..."
        if [[ ${DRY_RUN:-false} == false ]]; then
            LANG=C snap list --all | awk '/disabled/{print $1, $3}' |
            while read snapname revision; do
                sudo snap remove "$snapname" --revision="$revision" 2>/dev/null || true
            done
        else
            log_message INFO "[DRY RUN] Would remove disabled snap packages"
        fi
        log_message SUCCESS "Snap packages cleaned"
    fi
}

clean_flatpak() {
    if command -v flatpak &>/dev/null; then
        log_message INFO "Cleaning Flatpak applications..."
        if [[ ${DRY_RUN:-false} == false ]]; then
            flatpak uninstall --unused -y 2>/dev/null || true
        else
            log_message INFO "[DRY RUN] Would remove unused flatpak runtimes"
        fi
        log_message SUCCESS "Flatpak applications cleaned"
    fi
}

clean_browser_cache() {
    log_message INFO "Cleaning browser caches..."
    local browsers=("$HOME/.cache/mozilla/firefox" "$HOME/.cache/google-chrome" "$HOME/.cache/chromium")
    
    for browser_cache in "${browsers[@]}"; do
        if [[ -d "$browser_cache" ]]; then
            if [[ ${DRY_RUN:-false} == false ]]; then
                rm -rf "$browser_cache"/* 2>/dev/null || true
            else
                log_message INFO "[DRY RUN] Would clean $browser_cache"
            fi
        fi
    done
    log_message SUCCESS "Browser caches cleaned"
}
# --- End of moved functions ---

# Main storage optimization function
run_storage_module_main() {
    log_message INFO "--- Running Full Storage Optimization Module ---"
    
    # Run all functions in this script
    analyze_storage
    optimize_packages
    clean_old_kernels
    clean_temp_files
    clean_logs
    clean_dev_caches
    clean_docker
    clean_snap
    clean_flatpak
    clean_browser_cache
    clean_thumbnail_cache
    clean_build_artifacts
    optimize_filesystem
    optimize_databases
    clean_wine
    archive_old_files
    
    log_message SUCCESS "--- Storage optimization complete! ---"
}

# Guard to allow standalone execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Set defaults if run standalone
    DRY_RUN=${DRY_RUN:-false}
    QUICK_MODE=${QUICK_MODE:-false}
    LOG_DIR="/tmp"
    
    log_message() { echo "$*"; } # Simple logger
    
    # Load common functions if not already
    if ! command -v init_common &>/dev/null; then
        source "$(dirname "$0")/../lib/common.sh" 2>/dev/null || true
        init_common
    fi
    
    run_storage_module_main "$@"
fi
