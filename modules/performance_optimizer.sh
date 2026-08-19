#!/bin/bash

#############################################################################
# Deep Optimizer Pro - Performance Optimization Module
# Version: 2.1.0
# Description: System performance tuning and optimization
#############################################################################

# This script is intended to be sourced by deep-optimizer-pro.sh
# It expects $DRY_RUN, $PKG_INSTALL and log_message() to be available.

# CPU governor optimization
optimize_cpu_governor() {
    log_message INFO "Optimizing CPU governor..."
    
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        local target_governor="ondemand"
        # Check for laptop
        if [[ -f /sys/class/power_supply/BAT0/status ]]; then
            target_governor="ondemand"
        else
            target_governor="performance"
        fi

        log_message INFO "Setting CPU governor to: $target_governor"
        if [[ ${DRY_RUN:-false} == false ]]; then
            echo "$target_governor" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
        else
            log_message INFO "[DRY RUN] Would set CPU governor to $target_governor"
        fi
    fi
}

# I/O scheduler optimization
optimize_io_scheduler() {
    log_message INFO "Optimizing I/O scheduler..."
    
    for disk in /sys/block/sd*/queue/scheduler; do
        if [[ -f "$disk" ]]; then
            local device=$(echo "$disk" | cut -d'/' -f4)
            local rotational=$(cat "/sys/block/$device/queue/rotational")
            local target_scheduler="cfq"
            
            if [[ "$rotational" == "0" ]]; then
                target_scheduler="deadline" # Better for SSDs
            fi
            
            log_message INFO "$device: Setting I/O scheduler to $target_scheduler"
            if [[ ${DRY_RUN:-false} == false ]]; then
                echo "$target_scheduler" | sudo tee "$disk" >/dev/null
            else
                log_message INFO "[DRY RUN] Would set $device I/O scheduler to $target_scheduler"
            fi
        fi
    done
}

# Kernel parameter optimization
optimize_kernel_parameters() {
    log_message INFO "Optimizing kernel parameters (sysctl)..."
    
    local settings=(
        "net.core.rmem_max=134217728"
        "net.core.wmem_max=134217728"
        "net.ipv4.tcp_rmem=4096 87380 134217728"
        "net.ipv4.tcp_wmem=4096 65536 134217728"
        "net.ipv4.tcp_congestion_control=bbr"
        "net.core.default_qdisc=fq"
        "vm.vfs_cache_pressure=50"
        "vm.swappiness=10"
        "vm.overcommit_memory=1"
    )
    
    for setting in "${settings[@]}"; do
        local k="${setting%%=*}"
        local v="${setting#*=}"
        if command -v apply_sysctl_persistent &>/dev/null; then
            apply_sysctl_persistent "$k" "$v"
        elif [[ ${DRY_RUN:-false} == false ]]; then
            sysctl -w "$setting" 2>/dev/null || true
        else
            log_message INFO "[DRY RUN] Would set kernel parameter: $setting"
        fi
    done
    log_message SUCCESS "Kernel parameters optimized"
}

# Disable unnecessary services
optimize_services() {
    log_message INFO "Optimizing system services..."
    
    # Services that can be safely disabled on most *servers*
    # cups.service was removed as it's needed for printing
    local unnecessary_services=(
        "bluetooth.service"
        "avahi-daemon.service"
        "ModemManager.service"
        "pppd-dns.service"
    )
    
    if [[ ${IS_VPS:-false} != true ]] && [[ ${FORCE_DISABLE_DESKTOP_SVCS:-false} != true ]]; then
        log_message INFO "Skipping desktop-service disable (enable with VPS profile)"
        log_message SUCCESS "Services optimized"
        return
    fi
    for service in "${unnecessary_services[@]}"; do
        if systemctl list-unit-files "$service" &>/dev/null; then
            log_message INFO "Disabling $service..."
            if [[ ${DRY_RUN:-false} == false ]]; then
                systemctl stop "$service" 2>/dev/null || true
                systemctl disable "$service" 2>/dev/null || true
            else
                log_message INFO "[DRY RUN] Would stop and disable $service"
            fi
        fi
    done
    log_message SUCCESS "Services optimized"
}

# Optimize ZRAM compression
optimize_zram() {
    log_message INFO "Optimizing ZRAM compression..."
    
    if command -v zramctl &>/dev/null; then
        if [[ ${DRY_RUN:-false} == false ]]; then
            if [[ ! -b /dev/zram0 ]]; then
                sudo modprobe zram 2>/dev/null || true
            fi
            
            if [[ -b /dev/zram0 ]]; then
                sudo swapoff /dev/zram0 2>/dev/null || true
                sudo zramctl -r /dev/zram0 2>/dev/null || true
                
                local ram_size=$(free -b | awk '/^Mem:/{print $2}')
                local zram_size=$((ram_size / 4))
                
                sudo zramctl -f -s "$zram_size" -a lz4
                sudo mkswap /dev/zram0
                sudo swapon -p 100 /dev/zram0
                log_message SUCCESS "ZRAM configured"
            fi
        else
            log_message INFO "[DRY RUN] Would configure ZRAM device"
        fi
    fi
}

# Preload optimization
setup_preload() {
    log_message INFO "Setting up preload daemon..."
    if ! command -v preload &>/dev/null; then
        log_message INFO "Installing preload..."
        if [[ ${DRY_RUN:-false} == false ]]; then
             sudo $PKG_INSTALL preload 2>/dev/null || true
        else
            log_message INFO "[DRY RUN] Would install 'preload' package"
        fi
    fi
    
    if command -v preload &>/dev/null; then
        if [[ ${DRY_RUN:-false} == false ]]; then
            sudo systemctl enable preload 2>/dev/null
            sudo systemctl start preload 2>/dev/null
            log_message SUCCESS "Preload daemon configured"
        else
            log_message INFO "[DRY RUN] Would enable and start preload service"
        fi
    fi
}

# IRQ balancing
optimize_irq_balance() {
    log_message INFO "Optimizing IRQ balance..."
    
    if ! command -v irqbalance &>/dev/null; then
        if [[ ${DRY_RUN:-false} == false ]]; then
            sudo $PKG_INSTALL irqbalance 2>/dev/null || true
        else
            log_message INFO "[DRY RUN] Would install 'irqbalance' package"
        fi
    fi
    
    if command -v irqbalance &>/dev/null; then
        if [[ ${DRY_RUN:-false} == false ]]; then
            sudo systemctl enable irqbalance 2>/dev/null
            sudo systemctl start irqbalance 2>/dev/null
            log_message SUCCESS "IRQ balance optimized"
        else
            log_message INFO "[DRY RUN] Would enable and start irqbalance service"
        fi
    fi
}

# Process priority optimization
optimize_process_priorities() {
    log_message INFO "Optimizing process priorities..."
    
    # Decrease priority for resource-intensive background processes
    if [[ ${DRY_RUN:-false} == false ]]; then
        sudo renice 10 -p $(pgrep updatedb) 2>/dev/null || true
        sudo renice 10 -p $(pgrep tracker) 2>/dev/null || true
    else
        log_message INFO "[DRY RUN] Would lower priority of updatedb and tracker"
    fi
    log_message SUCCESS "Process priorities optimized"
}

# GPU optimization (if applicable)
optimize_gpu() {
    log_message INFO "Checking for GPU optimization..."
    
    # NVIDIA optimization
    if command -v nvidia-smi &>/dev/null; then
        log_message INFO "NVIDIA GPU detected, optimizing..."
        if [[ ${DRY_RUN:-false} == false ]]; then
            sudo nvidia-smi -pm 1 2>/dev/null || true
            sudo nvidia-smi -pl 200 2>/dev/null || true
            log_message SUCCESS "NVIDIA GPU optimized"
        else
            log_message INFO "[DRY RUN] Would set NVIDIA persistence mode and power limit"
        fi
    fi
    
    # AMD GPU optimization
    if [[ -d /sys/class/drm/card0/device ]]; then
        if grep -q "AMD" /sys/class/drm/card0/device/vendor 2>/dev/null; then
            log_message INFO "AMD GPU detected, optimizing..."
            if [[ ${DRY_RUN:-false} == false ]]; then
                echo "high" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level >/dev/null 2>&1
                log_message SUCCESS "AMD GPU optimized"
            else
                log_message INFO "[DRY RUN] Would set AMD GPU to high performance"
            fi
        fi
    fi
}

# Transparent Huge Pages optimization
optimize_thp() {
    log_message INFO "Optimizing Transparent Huge Pages..."
    
    if [[ ${DRY_RUN:-false} == false ]]; then
        echo "madvise" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null 2>&1
        echo "madvise" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag >/dev/null 2>&1
    else
        log_message INFO "[DRY RUN] Would set THP to 'madvise'"
    fi
    log_message SUCCESS "THP optimized"
}

# --- Module Functions from deep-optimizer-pro.sh ---
# (These were originally in the main script, but belong to performance)

optimize_memory() {
    log_message INFO "Optimizing system memory (clearing caches)..."
    
    if [[ ${DRY_RUN:-false} == false ]]; then
        sync
        echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
    else
        log_message INFO "[DRY RUN] Would drop memory caches"
    fi
    log_message SUCCESS "Memory optimized"
}

optimize_systemd() {
    if command -v systemctl &>/dev/null; then
        log_message INFO "Optimizing systemd services..."
        if [[ ${DRY_RUN:-false} == false ]]; then
            systemctl reset-failed 2>/dev/null || true
            sudo journalctl --vacuum-size=100M 2>/dev/null || true
        else
            log_message INFO "[DRY RUN] Would reset failed services and vacuum journal"
        fi
        log_message SUCCESS "Systemd services optimized"
    fi
}

optimize_network() {
    log_message INFO "Optimizing network settings (flushing caches)..."
    
    if [[ ${DRY_RUN:-false} == false ]]; then
        if command -v systemd-resolve &>/dev/null; then
            sudo systemd-resolve --flush-caches 2>/dev/null || true
        fi
        sudo ip -s -s neigh flush all 2>/dev/null || true
    else
        log_message INFO "[DRY RUN] Would flush DNS and ARP caches"
    fi
    log_message SUCCESS "Network settings optimized"
}
# --- End of moved functions ---


# Main performance optimization function
run_performance_module_main() {
    log_message INFO "--- Running Full Performance Optimization Module ---"
    
    optimize_cpu_governor
    optimize_io_scheduler
    optimize_kernel_parameters
    optimize_services
    optimize_zram
    setup_preload
    optimize_irq_balance
    optimize_process_priorities
    optimize_gpu
    optimize_thp
    optimize_memory
    optimize_systemd
    optimize_network
    
    log_message SUCCESS "--- Performance optimization complete! ---"
}

# Guard to allow standalone execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    DRY_RUN=${DRY_RUN:-false}
    LOG_DIR="/tmp"
    log_message() { echo "$*"; }
    
    if ! command -v init_common &>/dev/null; then
        source "$(dirname "$0")/../lib/common.sh" 2>/dev/null || true
        init_common
    fi
    
    run_performance_module_main "$@"
fi
