# Here is a universal developer's Master Hanbook by Dr-Diodac.  
---
## Usable functions, commands, and configuration snippets living there. 
## Its life and growing up!
## Happy codding :)
---

## 1\. Git & SSH

### SSH Key & Git Signing Setup

A "pro" setup involves using SSH keys for both server access and for *signing your Git commits*, which verifies you as the author.

1.  **Generate a new, high-security Ed25519 SSH key**:
    ```bash
    # -t ed25519 (type) -C "email" (comment) -f (filename)
    ssh-keygen -t ed25519 -C "your.email@example.com" -f ~/.ssh/id_dev_key
    ```
2.  **Add the key to your SSH agent** (so you don't type a password):
    ```bash
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_dev_key
    ```
3.  **Configure Git to use your SSH key for signing commits**:
    ```bash
    # Show Git your public key
    git config --global user.signingkey ~/.ssh/id_dev_key.pub
    # Tell Git to use the SSH format
    git config --global gpg.format ssh
    # Tell Git to sign all commits by default
    git config --global commit.gpgsign true
    ```
4.  **Test your connection to GitHub**:
    ```bash
    ssh -T git@github.com
    ```
5.  **Fix key permissions** (a common source of "permission denied" errors):
    ```bash
    chmod 600 ~/.ssh/id_dev_key
    chmod 644 ~/.ssh/id_dev_key.pub
    ```

### Git Workflow Commands

  * **Create a signed commit with a multi-line message**:
    ```bash
    git commit -S -m "Line 1: Summary of change
    > 
    > Line 2: More detailed description of the fix
    > Line 3: Another detail"
    ```
  * **Handle a "rejected push"** (when the server has changes you don't):
    ```bash
    # Pulls remote changes and "re-plays" your local commits on top
    git pull --rebase origin main
    git push origin main
    ```
  * **Get a compact, graphical log of all branches**:
    ```bash
    git log --oneline --graph --all
    ```

-----

## 2\. Server Administration & Monitoring

### System Monitoring One-Liners

  * **Check system load, memory, and disk usage**:
    ```bash
    uptime     # Check load average
    free -h    # Check RAM
    df -h      # Check disk space
    ```
  * **Find the top 10 processes by CPU or Memory**:
    ```bash
    # Top 10 by CPU
    ps aux --sort=-%cpu | head -10

    # Top 10 by Memory
    ps aux --sort=-%mem | head -10
    ```
  * **Check network connections and listening ports**:
    ```bash
    sudo ss -tulpn  # Modern, fast
    sudo netstat -tulpn # Older, but common
    ```
  * **Find which process is using a specific port** (e.g., port 443):
    ```bash
    sudo lsof -i:443
    ```
  * **Check disk I/O in real-time**:
    ```bash
    sudo iotop
    ```

### Log Monitoring

  * **View systemd journal for a specific service** (and follow):
    ```bash
    sudo journalctl -u nginx -f
    sudo journalctl -u php8.4-fpm -f
    ```
  * **View auth logs** (for SSH attempts, sudo use):
    ```bash
    sudo tail -f /var/log/auth.log
    ```
  * **Find top 20 IPs in an Nginx log** (great for finding bots):
    ```bash
    sudo awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20
    ```

### Service Management (systemd)

  * **Check status of multiple services**:
    ```bash
    sudo systemctl status nginx php8.4-fpm mysql redis-server
    ```
  * **Reload a service gracefully** (no downtime, for config changes):
    ```bash
    sudo systemctl reload nginx
    sudo systemctl reload php8.4-fpm
    ```

-----

## 3\. Web Stack (LEMP) & Caching

### Nginx (Web Server)

  * **The *most important* Nginx command**: Test config before reloading:
    ```bash
    sudo nginx -t
    ```
  * **Performance Config** (`/etc/nginx/nginx.conf`):
    ```nginx
    worker_processes auto;
    worker_rlimit_nofile 65535;

    events {
        worker_connections 4096;
        use epoll;
        multi_accept on;
    }
    ```
  * **Gzip Config** (`nginx.conf` in `http` block):
    ```nginx
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json text/xml application/javascript;
    ```
  * **Security Headers** (in `server` block):
    ```nginx
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    ```
  * **Block WordPress XML-RPC Attacks** (in `server` block):
    ```nginx
    location /xmlrpc.php {
        deny all;
        access_log off;
        log_not_found off;
    }
    ```
  * **SSL/TLS Hardening** (in `server` block):
    ```nginx
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers off;
    ssl_stapling on;
    ssl_stapling_verify on;
    ```

### PHP & Composer

  * **Production Composer Install** (smaller, faster):
    ```bash
    # --no-dev: skips development packages
    # --optimize-autoloader: creates a faster classmap
    composer install --no-dev --optimize-autoloader
    ```
  * **Production `php.ini` Settings** (for performance & security):
    ```ini
    memory_limit = 512M
    upload_max_filesize = 100M
    post_max_size = 100M
    max_execution_time = 300

    ; --- Security (Production) ---
    display_errors = Off
    log_errors = On
    error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
    error_log = /var/log/php8.4-fpm.log

    ; --- OPcache (MUST-HAVE for performance) ---
    opcache.enable = 1
    opcache.memory_consumption = 256
    opcache.max_accelerated_files = 10000
    opcache.revalidate_freq = 60
    opcache.fast_shutdown = 1
    ```
  * **Production `php-fpm.conf`** (for stability):
    ```ini
    pm = dynamic
    pm.max_children = 50
    pm.start_servers = 10
    pm.min_spare_servers = 5
    pm.max_spare_servers = 20
    pm.max_requests = 500  ; Restart workers after 500 requests to prevent leaks
    request_terminate_timeout = 300
    ```

### MySQL (Database)

  * **First command on a new server**:
    ```bash
    sudo mysql_secure_installation
    ```
  * **Secure Config** (`mysqld.cnf`): **Bind to localhost** to prevent all remote access:
    ```ini
    bind-address = 127.0.0.1
    ```
  * **Create a new DB and User** (with limited privileges):
    ```sql
    CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'STRONG_PASSWORD';
    CREATE DATABASE my_app_db;
    GRANT SELECT, INSERT, UPDATE, DELETE ON my_app_db.* TO 'app_user'@'localhost';
    FLUSH PRIVILEGES;
    ```
  * **Check a user's permissions**:
    ```sql
    SHOW GRANTS FOR 'app_user'@'localhost';
    ```
  * **Backup (Dump) a database** with a timestamp:
    ```bash
    mysqldump -u root -p database_name > ~/backups/database_name_$(date +%Y%m%d).sql
    ```
  * **Restore a database from a backup**:
    ```bash
    mysql -u root -p database_name < backup.sql
    ```
  * **Check for slow queries** (if enabled in config):
    ```bash
    sudo tail -f /var/log/mysql/mysql-slow.log
    ```

### Redis (Cache)

  * **Flush the *entire* cache** (the "turn it off and on again" fix):
    ```bash
    redis-cli FLUSHALL
    ```
  * **Monitor all commands** in real-time (to see what's being cached):
    ```bash
    redis-cli MONITOR
    ```
  * **Secure Config** (`redis.conf`): Bind to localhost:
    ```ini
    bind 127.0.0.1
    protected-mode yes
    ```
  * **Memory Limit Config** (to prevent crashing the server):
    ```ini
    maxmemory 256mb
    maxmemory-policy allkeys-lru # Evict Least Recently Used keys
    ```

-----

## 4\. WordPress Management

### The "Golden" File Permissions Snippet

This is the most common fix for WordPress issues. Run this from the *parent* of your web root.

```bash
# 1. Set correct ownership
sudo chown -R www-data:www-data /var/www/example.com

# 2. Set all directories to 755
sudo find /var/www/example.com -type d -exec chmod 755 {} \;

# 3. Set all files to 644
sudo find /var/www/example.com -type f -exec chmod 644 {} \;

# 4. Secure the most sensitive file
sudo chmod 640 /var/www/example.com/wp-config.php
```

### WP-CLI (Command Line)

*Always run as the `www-data` user to prevent permission errors.*

  * **Update everything** (core, plugins, themes):
    ```bash
    cd /var/www/example.com
    sudo -u www-data wp core update
    sudo -u www-data wp plugin update --all
    sudo -u www-data wp theme update --all
    ```
  * **Deactivate/Reactivate a plugin** (for troubleshooting):
    ```bash
    sudo -u www-data wp plugin deactivate my-plugin-slug
    sudo -u www-data wp plugin activate my-plugin-slug
    ```
  * **Run a database search/replace** (for migrating domains):
    ```bash
    sudo -u www-data wp search-replace 'http://old-url.com' 'https://new-url.com' --all-tables
    ```
  * **Delete all post revisions** (to clean the DB):
    ```bash
    sudo -u www-data wp post delete $(wp post list --post_type='revision' --format=ids) --force
    ```

### Hardening `wp-config.php`

Snippets to add to your `wp-config.php` for security.

  * **Enable Debug Logging** (for troubleshooting, NOT production):
    ```php
    define('WP_DEBUG', true);
    define('WP_DEBUG_LOG', true);
    define('WP_DEBUG_DISPLAY', false);
    @ini_set('display_errors', 0);
    ```
  * **Harden Production** (disable file editors):
    ```php
    define('DISALLOW_FILE_EDIT', true);
    define('DISALLOW_FILE_MODS', true);
    define('FORCE_SSL_ADMIN', true);
    ```

-----

## 5\. Security & SSL

### Certbot (Let's Encrypt)

  * **Check all certificate expiration dates**:
    ```bash
    sudo certbot certificates
    ```
  * **Test your renewal process** (without making changes):
    ```bash
    sudo certbot renew --dry-run
    ```
  * **Force a renewal** (if a test fails or SSL is broken):
    ```bash
    sudo certbot renew --force-renewal
    ```
  * **Check SSL cert details from the command line**:
    ```bash
    openssl s_client -servername example.com -connect example.com:443 2>/dev/null | openssl x509 -noout -dates
    ```

### UFW (Firewall)

  * **Reset to a secure default**:
    ```bash
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    ```
  * **Allow standard ports + SSH from a specific IP** (very secure):
    ```bash
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow from YOUR_IP_ADDRESS to any port 22
    sudo ufw enable
    ```

-----

## 6\. Automation (Ansible & Bash)

### Ansible Ad-Hoc Commands

  * **Check connectivity to all hosts** in your inventory:
    ```bash
    ansible all -m ping
    ```
  * **Run a command as root** on all hosts:
    ```bash
    ansible all -m shell -a "uptime" --become
    ```
  * **Update all packages** on all hosts:
    ```bash
    ansible all -m apt -a "update_cache=yes upgrade=dist" --become
    ```

### Backup Script (`backup.sh`)

A simple, universal script for backing up a website.

```bash
#!/bin/bash
DATE=$(date +%Y%m%d)
BACKUP_DIR=~/backups
DEST_FILE=~/backups/site_backup_$DATE.tar.gz
WWW_DIR=/var/www/example.com
DB_NAME=wordpress_db
DB_USER=root
DB_PASS=YOUR_PASSWORD

# Create a temp directory
mkdir -p $BACKUP_DIR/$DATE

# 1. Dump database
mysqldump -u $DB_USER -p$DB_PASS $DB_NAME > $BACKUP_DIR/$DATE/$DB_NAME.sql

# 2. Archive web files
tar -czf $BACKUP_DIR/$DATE/www.tar.gz $WWW_DIR

# 3. Archive configs
tar -czf $BACKUP_DIR/$DATE/configs.tar.gz /etc/nginx/sites-available /etc/letsencrypt

# 4. Compress all backups into one
tar -czf $DEST_FILE -C $BACKUP_DIR $DATE

# 5. Clean up temp
rm -rf $BACKUP_DIR/$DATE

# 6. Delete backups older than 30 days
find ~/backups -type f -mtime +30 -delete

echo "Backup complete: $DEST_FILE"
```

### Monitoring Script (`monitor.sh`)

A simple script to check services and restart them if they're down.

```bash
#!/bin/bash
LOG_FILE="/var/log/monitor.log"
echo "=== Monitoring Report $(date) ===" >> $LOG_FILE

# 1. Check Services
for service in nginx php8.4-fpm mysql; do
  if ! systemctl is-active --quiet $service; then
    echo "$service: FAILED. Attempting restart." >> $LOG_FILE
    sudo systemctl restart $service
  else
    echo "$service: OK" >> $LOG_FILE
  fi
done

# 2. Check Website HTTP Status
for site in https://example.com https://api.example.com; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" $site)
  if [ $STATUS -ne 200 ]; then
    echo "$site: WARNING (HTTP $STATUS)" >> $LOG_FILE
  else
    echo "$site: OK (HTTP $STATUS)" >> $LOG_FILE
  fi
done
```

-----

## 7\. API Testing & Troubleshooting

### `curl` (API Testing)

  * **Test a JSON POST request**:
    ```bash
    curl -X POST https://api.example.com/endpoint \
         -H "Content-Type: application/json" \
         -d '{"key": "value"}'
    ```
  * **Test an API and decode the Base64 response** (a powerful pipeline):
    ```bash
    # Assumes 'jq' is installed (sudo apt install jq)
    # 1. POST to the API
    # 2. Pipe to jq to extract the "pdf" field
    # 3. Decode the Base64 string
    # 4. Save to a file
    curl -X POST -H "Content-Type: application/json" \
         -d '{"content":"<h1>Test</h1>"}' \
         https://api.example.com/tcpdf/api.php \
    | jq -r .pdf | base64 -d > test.pdf
    ```
  * **Test for CORS errors** (simulates a browser preflight):
    ```bash
    curl -I -X OPTIONS https://api.example.com/endpoint \
         -H "Origin: https://my-frontend.com" \
         -H "Access-Control-Request-Method: POST"
    ```

### JavaScript Base64 Download

This is the "secret trick" for handling a Base64 file sent from an API to the browser.

```javascript
// data.pdf = "JVBERi0xLjcK..." (your Base64 string)
// data.filename = "invoice.pdf"

// 1. Decode the Base64 string
const byteChars = atob(data.pdf);
const byteNumbers = new Array(byteChars.length);
for (let i = 0; i < byteChars.length; i++) {
  byteNumbers[i] = byteChars.charCodeAt(i);
}
const byteArray = new Uint8Array(byteNumbers);

// 2. Create a Blob (a file in memory)
const blob = new Blob([byteArray], {type: 'application/pdf'});

// 3. Create a hidden link and "click" it to download
const url = URL.createObjectURL(blob);
const a = document.createElement('a');
a.style.display = 'none';
a.href = url;
a.download = data.filename;
document.body.appendChild(a);
a.click();
window.URL.revokeObjectURL(url);
a.remove();
```

### Troubleshooting Playbooks

  * **"502 Bad Gateway"**:

    1.  `sudo systemctl status php8.4-fpm` (Is it running?).
    2.  `sudo tail -f /var/log/php8.4-fpm.log` (Any PHP errors?).
    3.  `sudo tail -f /var/log/nginx/error.log` (Any Nginx errors?).
    4.  **Fix:** `sudo systemctl restart php8.4-fpm`.

  * **"Error Establishing Database Connection"**:

    1.  `sudo systemctl status mysql` (Is it running?).
    2.  **Fix:** `sudo systemctl restart mysql`.
    3.  If still broken, check credentials: `sudo nano /var/www/example.com/wp-config.php`.
    4.  Test credentials manually: `mysql -u 'user' -p'pass' db_name`.
    5.  Check permissions: `sudo mysql -u root -p -e "SHOW GRANTS FOR 'user'@'localhost';"`.

  * **"SSL Certificate Expired"**:

    1.  `sudo certbot certificates` (Check expiration).
    2.  `sudo certbot renew --dry-run` (Test renewal).
    3.  **Fix:** `sudo certbot renew --force-renewal`.
    4.  Reload Nginx: `sudo systemctl reload nginx`.

  * **"Git Push Permission Denied"**:

    1.  `ssh -T git@github.com` (Test auth).
    2.  `eval "$(ssh-agent -s)"` (Start agent).
    3.  `ssh-add ~/.ssh/id_dev_key` (Add your key).
    4.  If it *still* fails, check permissions: `chmod 600 ~/.ssh/id_dev_key`.
  ----
