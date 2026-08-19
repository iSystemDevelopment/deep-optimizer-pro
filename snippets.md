TODO: Build organised snippets source.

## Git & Local Development
### SSH Key Generation & Setup

**1. Generate a new SSH key** (e.g., Ed25519):

```bash
ssh-keygen -t ed25519 -C "your.email@example.com" -f ~/.ssh/id_github_key
```

**2. Add the key to the SSH agent**:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_github_key
```

**3. Display the public key** to add to GitHub or servers:

```bash
cat ~/.ssh/id_github_key.pub
```

**4. Test the GitHub connection**:

```bash
ssh -T git@github.com
```

### Git Configuration

**1. Set global user details**:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

**2. Configure Git for commit signing with your SSH key**:

```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_github_key.pub
git config --global commit.gpgsign true
```

### Common Git Workflow

**1. Clone a repository**:

```bash
git clone git@github.com:your-username/your-repo.git
```

**2. Commit changes (using the signed commit -S flag)**:

```bash
git add .
git commit -S -m "Your commit message"
```

**3. Push changes to the remote repository**:

```bash
git push origin main
```

**4. Pull changes from the remote repository**:

```bash
git pull origin main
```

**5. Handle a rejected push (remote has changes you don't)**:

```bash
git pull --rebase origin main
```

**6. View commit history** (compact):

```bash
git log --oneline --graph --all
```

-----

## SSH & Server Access

**1. Connect to a server**:

```bash
ssh dev_user@SERVER_IP_1
```

**2. Connect with a specific identity key**:

```bash
ssh -i ~/.ssh/id_github_key dev_user@SERVER_IP_1
```

**3. Fix SSH key permissions** (a common issue):

```bash
chmod 600 ~/.ssh/id_github_key
chmod 644 ~/.ssh/id_github_key.pub
```

-----

## System Administration & Monitoring

### Resource Monitoring

**1. Check system load and uptime**:

```bash
uptime
w
```

**2. Check memory usage**:

```bash
free -h
```

**3. Check disk usage**:

```bash
df -h
```

**4. Check directory size** (summarize):

```bash
du -sh /var/www/*
```

**5. View top processes** (CPU/Memory):

```bash
top
htop
ps aux --sort=-%cpu | head -10
ps aux --sort=-%mem | head -10
```

**6. Monitor disk I/O**:

```bash
sudo iotop
```

### Network Monitoring

**1. View all listening ports** (TCP/UDP):

```bash
sudo netstat -tulpn
sudo ss -tulpn
```

**2. Check which process is using a port**:

```bash
sudo lsof -i:443
```

**3. Monitor network traffic** in real-time:

```bash
sudo iftop
sudo nethogs
```

### Log Monitoring

**1. View system logs** (general):

```bash
sudo tail -f /var/log/syslog
```

**2. View authentication logs** (SSH, sudo):

```bash
sudo tail -f /var/log/auth.log
```

**3. View systemd journal** (and follow):

```bash
sudo journalctl -xe
sudo journalctl -u SERVICE_NAME -f
```

-----

## Service Management (systemd)

**1. Check service status**:

```bash
sudo systemctl status nginx
sudo systemctl status php8.4-fpm
sudo systemctl status mysql
```

**2. Restart a service**:

```bash
sudo systemctl restart nginx
```

**3. Reload a service** (graceful, no downtime):

```bash
sudo systemctl reload nginx
sudo systemctl reload php8.4-fpm
```

**4. Enable a service** (start on boot):

```bash
sudo systemctl enable nginx
```

-----

## Automation (Ansible)

### Ad-Hoc Commands

**1. Test connection to all servers**:

```bash
ansible all -m ping
```

**2. Run a command on all servers**:

```bash
ansible all -m shell -a "uptime"
```

**3. Run a command as root** (`--become`):

```bash
ansible all -m shell -a "systemctl status nginx" --become
```

**4. Run on a specific host or group**:

```bash
ansible web-servers -m shell -a "df -h"
```

**5. Update all packages on all servers**:

```bash
ansible all -m apt -a "update_cache=yes upgrade=dist" --become
```

### Playbooks

**1. Run a playbook**:

```bash
ansible-playbook deploy-wordpress.yml
```

**2. Run a playbook on a specific server**:

```bash
ansible-playbook deploy-wordpress.yml --limit SERVER_NAME
```

**3. Run a "dry run"** (check mode):

```bash
ansible-playbook deploy-wordpress.yml --check
```

### Sample Playbook Snippet

A simple "pull and deploy" playbook:

```yaml
- name: Deploy Complete Stack
  hosts: all
  become: yes
  tasks:
    - name: Pull latest code from repo
      git:
        repo: 'https://github.com/your-username/your-repo.git'
        dest: /root/your-repo
        version: main

    - name: Deploy WordPress plugin
      copy:
        src: /root/your-repo/wordpress-plugins/my-plugin/
        dest: /var/www/example.com/wp-content/plugins/my-plugin/
        owner: www-data
        group: www-data
        mode: '0755'

    - name: Reload PHP-FPM
      systemd:
        name: php8.4-fpm
        state: reloaded

    - name: Reload Nginx
      systemd:
        name: nginx
        state: reloaded
```

-----

## Web Server (Nginx)

### Management Commands

**1. Test configuration syntax**:

```bash
sudo nginx -t
```

**2. Test and show all loaded configs**:

```bash
sudo nginx -T
```

**3. Reload config** (no downtime):

```bash
sudo systemctl reload nginx
```

**4. Monitor error logs**:

```bash
sudo tail -f /var/log/nginx/error.log
```

**5. Monitor access logs**:

```bash
sudo tail -f /var/log/nginx/access.log
```

### Configuration Snippets

**1. Gzip Compression**:

```nginx
# In http { ... } block
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_types text/plain text/css text/xml text/javascript
    application/json application/javascript application/xml+rss
    image/svg+xml;
```

**2. Security Headers**:

```nginx
# In server { ... } block
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

**3. HSTS Header** (force HTTPS):

```nginx
# In server { ... } block for HTTPS
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

**4. Strong SSL/TLS Ciphers**:

```nginx
# In server { ... } block for HTTPS
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers off;
ssl_stapling on;
ssl_stapling_verify on;
```

**5. Block WordPress XML-RPC** (common attack vector):

```nginx
# In server { ... } block
location /xmlrpc.php {
    deny all;
    access_log off;
    log_not_found off;
}
```

**6. Rate Limiting**:

```nginx
# In http { ... } block
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login_limit:10m rate=1r/s;

# In server { ... } block, inside location /api
location /api {
    limit_req zone=api_limit burst=20;
    ...
}
location /wp-login.php {
    limit_req zone=login_limit burst=5;
    ...
}
```

**7. CORS Headers** (for APIs):

```nginx
# In location { ... } block for your API
add_header 'Access-Control-Allow-Origin' 'https://your-frontend.com' always;
add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
add_header 'Access-Control-Allow-Headers' 'Content-Type' always;
```

-----

## PHP & Application

### Management Commands

**1. Update Composer dependencies**:

```bash
composer update
```

**2. Install Composer dependencies** (for production):

```bash
composer install --no-dev --optimize-autoloader
```

**3. Run a local PHP server** (for testing):

```bash
php -S localhost:8000
```

**4. Check PHP file syntax**:

```bash
php -l /path/to/your/file.php
```

### Configuration Snippets

**1. `php.ini` (Production Settings)**:

```ini
; Performance
memory_limit = 512M
max_execution_time = 300
upload_max_filesize = 100M
post_max_size = 100M

; Error Handling (Production)
display_errors = Off
display_startup_errors = Off
log_errors = On
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
error_log = /var/log/php8.4-fpm.log

; OPcache (Essential for performance)
opcache.enable = 1
opcache.memory_consumption = 256
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 60
opcache.fast_shutdown = 1
```

**2. `php-fpm.conf` (Process Manager)**:

```ini
[www]
listen = /run/php/php8.4-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

; Process Manager
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 20
pm.max_requests = 500
pm.process_idle_timeout = 10s
request_terminate_timeout = 300
```

-----

## Database (MySQL)

### Management Commands

**1. Secure a new installation**:

```bash
sudo mysql_secure_installation
```

**2. Connect to the MySQL shell**:

```bash
sudo mysql -u root -p
```

**3. Create a new database and user**:

```sql
CREATE USER 'wp_user'@'localhost' IDENTIFIED BY 'strong_password';
CREATE DATABASE wordpress_db;
GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wp_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

**4. Backup a database**:

```bash
mysqldump -u root -p database_name > backup.sql
```

**5. Restore a database**:

```bash
mysql -u root -p database_name < backup.sql
```

**6. Monitor slow queries**:

```bash
sudo tail -f /var/log/mysql/mysql-slow.log
```

**7. Show active processes**:

```bash
sudo mysqladmin processlist
```

*Or inside MySQL:* `SHOW PROCESSLIST;`

### Configuration Snippet (`mysqld.cnf`)

Key performance and logging settings:

```ini
[mysqld]
# Performance
max_connections = 200
max_allowed_packet = 64M
thread_cache_size = 128
sort_buffer_size = 4M

# InnoDB (Primary engine)
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
innodb_file_per_table = 1
innodb_flush_method = O_DIRECT

# Logging
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 2
log_error = /var/log/mysql/error.log
```

-----

## Caching (Redis)

### Management Commands

**1. Connect to the Redis CLI**:

```bash
redis-cli
```

**2. Test the connection**:

```redis
PING
```

**3. Delete ALL keys** (flush the cache):

```redis
FLUSHALL
```

**4. Monitor commands in real-time**:

```redis
MONITOR
```

**5. Check memory usage**:

```redis
INFO memory
```

### Configuration Snippet (`redis.conf`)

Key settings for security and memory:

```ini
# Network (Lock to localhost)
bind 127.0.0.1
protected-mode yes
port 6379

# Memory Management
maxmemory 256mb
maxmemory-policy allkeys-lru

# Persistence (Snapshot)
save 900 1
save 300 10
save 60 10000
dir /var/lib/redis
```

-----

## WordPress (WP-CLI)

*Note: Always run as the web user (`www-data`).*

**1. Update core, plugins, and themes**:

```bash
cd /var/www/example.com
sudo -u www-data wp core update
sudo -u www-data wp plugin update --all
sudo -u www-data wp theme update --all
```

**2. Manage plugins** (list, activate, deactivate):

```bash
sudo -u www-data wp plugin list
sudo -u www-data wp plugin activate my-plugin
sudo -u www-data wp plugin deactivate my-plugin
```

**3. Flush the cache**:

```bash
sudo -u www-data wp cache flush
```

**4. Search and replace** (for domain migrations):

```bash
sudo -u www-data wp search-replace 'http://old.com' 'https://new.com' --all-tables
```

**5. Enable WordPress debug mode** (in `wp-config.php`):

```php
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true); // Errors go to wp-content/debug.log
define('WP_DEBUG_DISPLAY', false); // Don't show errors on the page
```

**6. Harden `wp-config.php`**:

```php
define('DISALLOW_FILE_EDIT', true); // Disable theme/plugin editor
define('DISALLOW_FILE_MODS', true); // Disable installing/updating
define('FORCE_SSL_ADMIN', true); // Force SSL for login
```

-----

## Security (Firewall & SSL)

### UFW (Firewall)

**1. Check status**:

```bash
sudo ufw status verbose
```

**2. Set default rules**:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

**3. Allow common ports**:

```bash
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
```

**4. Allow SSH from a specific IP** (more secure):

```bash
sudo ufw delete allow 22/tcp
sudo ufw allow from YOUR_IP_ADDRESS to any port 22
```

**5. Enable the firewall**:

```bash
sudo ufw enable
```

### Certbot (Let's Encrypt SSL)

**1. Check all current certificates**:

```bash
sudo certbot certificates
```

**2. Run a "dry run"** (test renewal):

```bash
sudo certbot renew --dry-run
```

**3. Manually renew certificates**:

```bash
sudo certbot renew
```

**4. Force renewal** (if something is broken):

```bash
sudo certbot renew --force-renewal
```

**5. Get a new certificate** (using Nginx plugin):

```bash
sudo certbot --nginx -d example.com -d www.example.com
```

-----

## Networking & API Testing

### DNS & Header Checks

**1. Check DNS resolution** (using Cloudflare/Google DNS):

```bash
dig @1.1.1.1 example.com
dig @8.8.8.8 example.com
```

**2. Check server headers** (for status code, cache, etc.):

```bash
curl -I https://example.com
```

**3. Check SSL certificate expiration date**:

```bash
openssl s_client -servername example.com -connect example.com:443 2>/dev/null | openssl x509 -noout -dates
```

### API (curl) & JavaScript

**1. Test a POST request** (JSON):

```bash
curl -X POST https://api.example.com/endpoint \
     -H "Content-Type: application/json" \
     -d '{"key": "value", "user_id": 123}'
```

**2. Test with verbose output** (to see headers):

```bash
curl -v https://api.example.com
```

**3. Test response time**:

```bash
curl -w "\nTime: %{time_total}s\n" https://api.example.com
```

**4. Test CORS headers** (preflight):

```bash
curl -I -X OPTIONS https://api.example.com/endpoint \
     -H "Origin: https://frontend.com" \
     -H "Access-Control-Request-Method: POST"
```

**5. Purge Cloudflare cache** (via API):

```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/purge_cache" \
     -H "Authorization: Bearer YOUR_API_TOKEN" \
     -H "Content-Type: application/json" \
     --data '{"purge_everything":true}'
```

**6. JavaScript `fetch` snippet** (for downloading a Base64 PDF):

```javascript
fetch('https://api.example.com/tcpdf/api.php', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({
    title: 'My Document',
    content: '<h1>Hello World</h1>'
  })
})
.then(r => r.json())
.then(data => {
  // Decode Base64
  const byteChars = atob(data.pdf);
  const byteNumbers = new Array(byteChars.length);
  for (let i = 0; i < byteChars.length; i++) {
    byteNumbers[i] = byteChars.charCodeAt(i);
  }
  const byteArray = new Uint8Array(byteNumbers);
  
  // Create Blob and download link
  const blob = new Blob([byteArray], {type: 'application/pdf'});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = data.filename;
  a.click();
});
```

-----

## Backup & Disaster Recovery

### Backup Script Snippet

A simple script to back up a site and database:

```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=~/backups/$DATE
mkdir -p $BACKUP_DIR

# Database backup
mysqldump -u root -p$DB_PASSWORD wordpress_db > $BACKUP_DIR/wordpress_db.sql

# WordPress files backup
tar -czf $BACKUP_DIR/wp-content.tar.gz /var/www/example.com/wp-content/

# Nginx configs backup
tar -czf $BACKUP_DIR/nginx.tar.gz /etc/nginx/sites-available/

# SSL certificates backup
tar -czf $BACKUP_DIR/ssl.tar.gz /etc/letsencrypt/

# Compress all
tar -czf ~/backups/backup_$DATE.tar.gz $BACKUP_DIR
rm -rf $BACKUP_DIR

# Remove old backups (keep 30 days)
find ~/backups -type f -mtime +30 -delete
echo "Backup completed: backup_$DATE.tar.gz"
```

### Restore Procedures

**1. Restore a database**:

```bash
gunzip < backup.sql.gz | mysql -u root -p database_name
```

**2. Restore WordPress files**:

```bash
# Move old one
sudo mv /var/www/example.com /var/www/example.com.old
# Extract backup
sudo tar -xzf wp-content-backup.tar.gz -C /var/www/
# Fix permissions
sudo chown -R www-data:www-data /var/www/example.com
```

### Full Server Migration

A high-level checklist for moving a server:

1.  **On New Server:** Install Nginx, PHP, MySQL, Certbot. Configure firewall.
2.  **On Old Server:** Dump all databases and `tar` all web files (`/var/www/`, `/etc/nginx/`, etc.).
3.  **Transfer:** Use `scp` to move the backups to the new server.
4.  **On New Server:** Restore the databases (`mysql < all_databases.sql`) and extract files (`tar -xzf ... -C /`).
5.  **Fix Permissions:** `chown -R www-data:www-data /var/www/`.
6.  **Test:** Check `sudo nginx -t` and restart services.
7.  **DNS:** Update A records in Cloudflare to the new server's IP.
8.  **SSL:** Run `sudo certbot --nginx` to issue new certificates for the domains.

### Cron Job Snippets

View and edit cron jobs:

```bash
# For your user
crontab -l
crontab -e

# For the root user
sudo crontab -l
sudo crontab -e
```

**Example cron jobs**:

```cron
# Run a backup script every day at 2 AM
0 2 * * * /root/scripts/backup.sh

# Run monitoring every 5 minutes
*/5 * * * * /root/scripts/monitor.sh

# Update apt cache daily at 6 AM
0 6 * * * apt-get update -qq

# Update WordPress core weekly (Sunday at 4 AM)
0 4 * * 0 cd /var/www/example.com && sudo -u www-data wp core update
```
