#!/bin/bash

#############################################################################
# Deep Optimizer Pro - Security Hardening Module
# Version: 2.1.0
# Description: System security hardening and vulnerability mitigation
#############################################################################

# This script is intended to be sourced by deep-optimizer-pro.sh
# It expects $DRY_RUN, $PKG_INSTALL, $PKG_REMOVE, and log_message() to be available.

# Check for rootkits
check_rootkits() {
    log_message INFO "Checking for rootkits..."
    
    if [[ ${DRY_RUN:-false} == false ]]; then
        # Install rkhunter
        if ! command -v rkhunter &>/dev/null; then
            log_message INFO "Installing rkhunter..."
            sudo $PKG_INSTALL rkhunter 2>/dev/null || true
        fi
        
        if command -v rkhunter &>/dev/null; then
            sudo rkhunter --update 2>/dev/null || true
            sudo rkhunter --propupd 2>/dev/null || true
            sudo rkhunter --check --skip-keypress 2>/dev/null || true
        fi
        
        # Install chkrootkit
        if ! command -v chkrootkit &>/dev/null; then
            log_message INFO "Installing chkrootkit..."
            sudo $PKG_INSTALL chkrootkit 2>/dev/null || true
        fi
        
        if command -v chkrootkit &>/dev/null; then
            sudo chkrootkit 2>/dev/null | grep -v "not infected" || true
        fi
    else
        log_message INFO "[DRY RUN] Would install and run rkhunter and chkrootkit"
    fi
}

# Firewall configuration (detect SSH port — safe for custom VPS SSH)
setup_firewall() {
    log_message INFO "Configuring firewall..."
    
    local ssh_port
    ssh_port=$(get_ssh_port 2>/dev/null || echo 22)
    local extra_ports="${UFW_EXTRA_PORTS:-80,443}"
    
    if command -v ufw &>/dev/null; then
        log_message INFO "UFW detected. SSH port: $ssh_port"
        if [[ ${DRY_RUN:-false} == false ]]; then
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow "${ssh_port}/tcp" comment 'SSH'
            IFS=',' read -ra ports <<< "$extra_ports"
            for p in "${ports[@]}"; do
                p=$(echo "$p" | tr -d ' ')
                [[ -n "$p" ]] && ufw allow "${p}/tcp" comment "svc-$p" || true
            done
            ufw --force enable
        else
            log_message INFO "[DRY RUN] Would configure UFW (deny in, allow out, allow SSH $ssh_port + $extra_ports)"
        fi
        log_message SUCCESS "UFW firewall configured (SSH $ssh_port)"
    else
        log_message WARNING "UFW not installed — skip or: apt-get install -y ufw"
    fi
}

# SSH hardening
harden_ssh() {
    log_message INFO "Hardening SSH configuration..."
    
    if [[ -f /etc/ssh/sshd_config ]]; then
        if [[ ${DRY_RUN:-false} == false ]]; then
            sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
            # Backup already created above
            # Prefer prohibit-password (keys OK) over a hard deny that locks cloud recovery consoles
            if [[ ${SSH_DISABLE_ROOT:-false} == true ]]; then
                sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
            else
                sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
                log_message INFO "Root SSH limited to keys (set SSH_DISABLE_ROOT=true to disable root entirely)"
            fi
            if ! grep -qE '^MaxAuthTries' /etc/ssh/sshd_config; then
                echo 'MaxAuthTries 3' >> /etc/ssh/sshd_config
            else
                sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
            fi
            sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
            if ! grep -qE '^PasswordAuthentication' /etc/ssh/sshd_config; then
                echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
            fi
            # Do not force PasswordAuthentication=no — many VPSes still need it during bootstrap
            
            # Validate then restart
            if sshd -t 2>/dev/null; then
                systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
            else
                log_message ERROR "sshd_config invalid — not restarting. Restoring backup recommended."
            fi
        else
            log_message INFO "[DRY RUN] Would harden /etc/ssh/sshd_config (PermitRootLogin no, MaxAuthTries 3, X11Forwarding no)"
        fi
        log_message SUCCESS "SSH configuration hardened"
    fi
}

# System auditing setup
setup_auditing() {
    log_message INFO "Setting up system auditing..."
    
    if ! command -v auditd &>/dev/null; then
        if [[ ${DRY_RUN:-false} == false ]]; then
            sudo $PKG_INSTALL auditd audispd-plugins 2>/dev/null || true
        else
            log_message INFO "[DRY RUN] Would install auditd"
        fi
    fi
    
    if command -v auditd &>/dev/null; then
        if [[ ${DRY_RUN:-false} == false ]]; then
            sudo auditctl -w /etc/passwd -p wa -k passwd_changes 2>/dev/null || true
            sudo auditctl -w /etc/shadow -p wa -k shadow_changes 2>/dev/null || true
            sudo systemctl enable auditd 2>/dev/null
            sudo systemctl start auditd 2>/dev/null
        else
            log_message INFO "[DRY RUN] Would set audit rules for /etc/passwd and /etc/shadow"
        fi
        log_message SUCCESS "System auditing configured"
    fi
}


# VPS-safe permission hardening (does NOT walk entire filesystem)
harden_file_permissions_safe() {
    log_message INFO "Hardening sensitive file permissions (safe mode)..."
    
    if [[ ${DRY_RUN:-false} == false ]]; then
        [[ -f /etc/passwd ]] && chmod 644 /etc/passwd
        [[ -f /etc/shadow ]] && chmod 0640 /etc/shadow
        [[ -f /etc/group ]] && chmod 644 /etc/group
        [[ -f /etc/gshadow ]] && chmod 0640 /etc/gshadow
        [[ -f /etc/ssh/sshd_config ]] && chmod 600 /etc/ssh/sshd_config
        if [[ -d /root ]]; then chmod 700 /root; fi
        for dir in /home/*; do
            if [[ -d "$dir" ]]; then
                chmod 750 "$dir" 2>/dev/null || true
            fi
        done
    else
        log_message INFO "[DRY RUN] Would harden /etc/{passwd,shadow} and home dir modes"
    fi
    log_message SUCCESS "File permissions hardened (safe)"
}

# File permissions hardening
harden_file_permissions() {
    log_message INFO "Hardening file permissions..."
    
    if [[ ${DRY_RUN:-false} == false ]]; then
        # Set secure permissions on sensitive files
        # 0640 (root:shadow) is correct for shadow/gshadow, 000 will break user management.
        sudo chmod 644 /etc/passwd
        sudo chmod 0640 /etc/shadow
        sudo chmod 644 /etc/group
        sudo chmod 0640 /etc/gshadow
        
        # Secure home directories
        for dir in /home/*; do
            if [[ -d "$dir" ]]; then
                sudo chmod 750 "$dir" 2>/dev/null || true
            fi
        done
        
        # Full-filesystem world-writable scrub is expensive/risky on live VPS — opt-in
        if [[ ${HARDEN_WORLD_WRITABLE:-false} == true ]]; then
            find /usr /etc /var -xdev -type f -perm -002 -exec chmod o-w {} \; 2>/dev/null || true
            find /usr /etc /var -xdev -type d -perm -002 -exec chmod o-w {} \; 2>/dev/null || true
        else
            log_message INFO "Skipping full FS world-writable scrub (set HARDEN_WORLD_WRITABLE=true to enable)"
        fi
    else
        log_message INFO "[DRY RUN] Would set secure permissions on /etc/passwd, /etc/shadow, and home dirs"
    fi
    log_message SUCCESS "File permissions hardened"
}

# Kernel hardening
harden_kernel() {
    log_message INFO "Hardening kernel parameters (sysctl)..."
    
    local settings=(
        "net.ipv4.conf.all.accept_source_route=0"
        "net.ipv4.conf.all.accept_redirects=0"
        "net.ipv4.icmp_echo_ignore_broadcasts=1"
        "net.ipv4.tcp_syncookies=1"
        "net.ipv4.conf.all.rp_filter=1"
        "kernel.randomize_va_space=2"
        "kernel.yama.ptrace_scope=1"
        "fs.protected_hardlinks=1"
        "fs.protected_symlinks=1"
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
    log_message SUCCESS "Kernel parameters hardened"
}

# AppArmor/SELinux setup
setup_mandatory_access_control() {
    log_message INFO "Setting up Mandatory Access Control..."

    if [[ ${DRY_RUN:-false} == true ]]; then
        log_message INFO "[DRY RUN] Would check for and enable AppArmor/SELinux"
        return
    fi
    
    # AppArmor (Ubuntu/Debian)
    if command -v aa-status &>/dev/null; then
        sudo systemctl enable apparmor 2>/dev/null
        sudo systemctl start apparmor 2>/dev/null
        log_message SUCCESS "AppArmor enabled and running"
    fi
    
    # SELinux (RHEL/CentOS/Fedora)
    if command -v getenforce &>/dev/null; then
        sudo setenforce 1 2>/dev/null || true
        log_message SUCCESS "SELinux enforcing mode enabled"
    fi
}

# Fail2ban setup
setup_fail2ban() {
    log_message INFO "Setting up Fail2ban..."
    
    if ! command -v fail2ban-client &>/dev/null; then
        if [[ ${DRY_RUN:-false} == false ]]; then
            sudo $PKG_INSTALL fail2ban 2>/dev/null || true
        else
            log_message INFO "[DRY RUN] Would install fail2ban"
        fi
    fi
    
    if command -v fail2ban-client &>/dev/null; then
        if [[ ${DRY_RUN:-false} == false ]]; then
            cat << EOF | sudo tee /etc/fail2ban/jail.local >/dev/null
[DEFAULT]
bantime = 3600
maxretry = 5
[sshd]
enabled = true
EOF
            sudo systemctl enable fail2ban 2>/dev/null
            sudo systemctl restart fail2ban 2>/dev/null
        else
            log_message INFO "[DRY RUN] Would create /etc/fail2ban/jail.local and start service"
        fi
        log_message SUCCESS "Fail2ban configured"
    fi
}

# ClamAV antivirus setup
setup_antivirus() {
    log_message INFO "Setting up antivirus scanning..."
    
    if ! command -v clamscan &>/dev/null; then
        if [[ ${DRY_RUN:-false} == false ]]; then
            sudo $PKG_INSTALL clamav clamav-daemon 2>/dev/null || true
        else
            log_message INFO "[DRY RUN] Would install clamav and clamav-daemon"
        fi
    fi
    
    if command -v clamscan &>/dev/null; then
        if [[ ${DRY_RUN:-false} == false ]]; then
            sudo freshclam 2>/dev/null || true
            sudo systemctl enable clamav-daemon 2>/dev/null
            sudo systemctl start clamav-daemon 2>/dev/null
        else
            log_message INFO "[DRY RUN] Would run freshclam and start clamav-daemon"
        fi
        log_message SUCCESS "ClamAV antivirus configured"
    fi
}

# Remove unnecessary packages
remove_unnecessary_packages() {
    log_message INFO "Removing unnecessary packages..."
    
    # rsync was removed from this list as it is a standard backup tool
    local unnecessary_packages=(
        "telnet"
        "nis"
        "ntpdate"
        "talk"
    )
    
    for package in "${unnecessary_packages[@]}"; do
        if [[ ${DRY_RUN:-false} == false ]]; then
            sudo $PKG_REMOVE "$package" 2>/dev/null || true
        else
            log_message INFO "[DRY RUN] Would remove package: $package"
        fi
    done
    log_message SUCCESS "Unnecessary packages removed"
}

# Password policy configuration
setup_password_policy() {
    log_message INFO "Setting up password policy..."

    if [[ ${DRY_RUN:-false} == true ]]; then
        log_message INFO "[DRY RUN] Would install libpam-pwquality and configure password policies"
        return
    fi
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        sudo $PKG_INSTALL libpam-pwquality 2>/dev/null || true
    elif [[ "$PKG_MANAGER" == "yum" || "$PKG_MANAGER" == "dnf" ]]; then
        sudo $PKG_INSTALL pam_pwquality 2>/dev/null || true
    fi
    
    # Configure password complexity
    if [[ -f /etc/pam.d/common-password ]]; then
        sudo sed -i 's/pam_pwquality.so retry=3/pam_pwquality.so retry=3 minlen=12 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1/' /etc/pam.d/common-password 2>/dev/null || true
    fi
    
    # Set password aging
    sudo sed -i 's/PASS_MAX_DAYS\t99999/PASS_MAX_DAYS\t90/' /etc/login.defs 2>/dev/null || true
    sudo sed -i 's/PASS_MIN_DAYS\t0/PASS_MIN_DAYS\t7/' /etc/login.defs 2>/dev/null || true
    
    log_message SUCCESS "Password policy configured"
}

# Main security hardening function
run_security_module_main() {
    log_message INFO "--- Running Full Security Hardening Module ---"
    
    setup_firewall
    harden_ssh
    setup_fail2ban
    harden_kernel
    harden_file_permissions_safe
    
    if [[ ${SECURITY_FULL:-false} == true ]]; then
        check_rootkits
        setup_auditing
        harden_file_permissions
        setup_mandatory_access_control
        remove_unnecessary_packages
        setup_password_policy
    else
        log_message INFO "Skipped heavy scans/policies (set SECURITY_FULL=true for rootkit/audit/password policy)"
    fi
    
    if [[ ${ENABLE_ANTIVIRUS:-false} == true ]]; then
        setup_antivirus
    fi
    
    log_message SUCCESS "--- Security hardening complete! ---"
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
    
    run_security_module_main "$@"
fi
