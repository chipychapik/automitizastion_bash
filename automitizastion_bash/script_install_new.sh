#!/bin/bash

# Exit immediately if any command fails
set -e

# ========== Variables ==========
WEB_USER="www-data"
DOMAIN_NAME="example.com"       # Replace with your domain
EMAIL="admin@example.com"       # Replace with your email for Let's Encrypt

# ========== Update the system ==========
echo "🔄 Updating system packages..."
apt update && apt upgrade -y

# ========== Install essential packages ==========
echo "⬇️ Installing required packages..."
apt install -y nginx php php-fpm php-mysql mysql-server unzip curl git ufw certbot python3-certbot-nginx

# ========== Configure firewall (UFW) ==========
echo "🔒 Configuring UFW firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# ========== Secure MySQL installation ==========
echo "🔐 Securing MySQL..."
mysql_secure_installation <<EOF

y
n
y
y
y
EOF

# ========== PHP configuration tweaks ==========
echo "⚙️ Tweaking PHP settings..."
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' /etc/php/*/fpm/php.ini
sed -i 's/post_max_size = .*/post_max_size = 64M/' /etc/php/*/fpm/php.ini
systemctl restart php*-fpm

# ========== Nginx configuration ==========
echo "🧰 Configuring Nginx..."
rm -f /etc/nginx/sites-enabled/default
cat <<EOF > /etc/nginx/sites-available/$DOMAIN_NAME
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;

    root /var/www/$DOMAIN_NAME;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Create document root and set permissions
mkdir -p /var/www/$DOMAIN_NAME
chown -R $WEB_USER:$WEB_USER /var/www/$DOMAIN_NAME

# Enable the site
ln -s /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/

# Test and reload Nginx
nginx -t && systemctl reload nginx

# ========== Get Let's Encrypt SSL certificate ==========
echo "🔐 Getting SSL certificate via Let's Encrypt..."
certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME --non-interactive --agree-tos -m $EMAIL

# ========== Enable auto-renewal of SSL ==========
echo "📅 Setting up automatic SSL certificate renewal..."
echo "0 3 * * * root certbot renew --quiet" > /etc/cron.d/certbot-renew

# ========== Done ==========
echo "✅ Setup complete! Web server is ready."
