#!/bin/bash

set -e

echo "====================================="
echo "🚀 Starting Conzex - cPanel Setup"
echo "====================================="

# 0. Disable IPv6
echo "📛 Disabling IPv6..."
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1

# Set hostname
echo "🖥️ Setting hostname to 'Prod-cPanel'..."
hostnamectl set-hostname Prod-cPanel

# 1. Basic system update
echo "🔄 Updating system..."
apt update && apt -y upgrade && apt -y install curl wget sudo lvm2 gnupg

# 2. Extend root volume to 20GB
echo "📏 Extending root volume to 20GB..."
lvextend -L20G /dev/mapper/ubuntu--vg-ubuntu--lv -y || true
resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv || true

# 3. Install CloudPanel
echo "📦 Installing CloudPanel..."
curl -sS https://installer.cloudpanel.io/ce/v2/install.sh -o install.sh
echo "a3ba69a8102345127b4ae0e28cfe89daca675cbc63cd39225133cdd2fa02ad36 install.sh" | sha256sum -c
bash install.sh

# 4. Extend disk space if /dev/sdb exists
if lsblk | grep -q 'sdb'; then
  echo "💽 Extending disk space using /dev/sdb..."
  pvcreate /dev/sdb
  vgextend ubuntu-vg /dev/sdb
  lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
  resize2fs /dev/ubuntu-vg/ubuntu-lv
fi

# 5. Clean system logs & cache
echo "🧹 Cleaning disk space..."
apt clean
rm -rf /var/log/* /var/cache/*
journalctl --vacuum-time=1d

# 6. Custom MOTD
echo "🛠️ Setting custom MOTD..."
chmod -x /etc/update-motd.d/10-cloudpanel || true
cat <<'EOF' > /etc/update-motd.d/10-help-text
#!/bin/sh
IP=$(hostname -I | awk '{print $1}')
cat <<EOM
########################################################
###               Welcome to cPanel                   ###
########################################################

* Website:         https://cpanel.conzex.com
* Documentation:   https://docs.conzex.com/cpanel
* Support:         https://conzex.com/en/contact
* Admin Panel:     https://$IP:8443
* CLI Tool:        cpanelctl

EOM
EOF
chmod +x /etc/update-motd.d/10-help-text

# 7. Replace branding assets
echo "🎨 Replacing logos and favicons..."
mkdir -p /home/clp/htdocs/app/files/public/assets/images/
curl -o /home/clp/htdocs/app/files/public/assets/images/logo.svg https://cdn.conzex.com/media/image/cz-light.svg
curl -o /home/clp/htdocs/app/files/public/assets/images/logo-dark.svg https://cdn.conzex.com/media/image/cz-dark.svg
curl -o /home/clp/htdocs/app/files/public/favicon.ico https://cdn.conzex.com/media/other/favicon.ico
curl -o /home/clp/htdocs/app/files/public/assets/images/cloudpanel-cloud.svg https://cdn.conzex.com/media/image/cz-light.svg
curl -o /home/clp/htdocs/app/files/public/assets/images/favicon.svg https://cdn.conzex.com/media/image/app-logo.svg

# 8. Ensure nginx log dir exists
echo "📁 Ensuring nginx log dir exists..."
mkdir -p /var/log/nginx
touch /var/log/nginx/error.log
chown -R www-data:www-data /var/log/nginx

# 9. Inject footer into Twig templates
echo "🦶 Adding footer links..."
find /home/clp/htdocs/app/files/templates/ -type f -name "*.twig" \
  -exec grep -Iq . {} \; -print | \
xargs -I {} sed -i '/footer-container/a \
<div class="footer-links text-center mt-3">\
  <a target="_blank" href="https://docs.conzex.com/cpanel/">Docs</a> | \
  <a target="_blank" href="https://www.conzex.com/en/contact-us/">Contact</a> | \
  © $(date +%Y) <a target="_blank" href="https://www.conzex.com/">Conzex Global Private Limited</a>\
</div>' {}

# 10. Download & overwrite layout templates
echo "📄 Replacing layout templates..."
curl -o /home/clp/htdocs/app/files/templates/Admin/layout.html.twig https://cdn.conzex.com/media/other/admin-layout.html.twig
curl -o /home/clp/htdocs/app/files/templates/Frontend/Login/layout.html.twig https://cdn.conzex.com/media/other/frontend-layout.html.twig
curl -o /home/clp/htdocs/app/files/templates/Frontend/layout.html.twig https://cdn.conzex.com/media/other/login-layout.html.twig

# 11. Final cleanup & restart services
echo "🔁 Restarting services..."
rm -rf /home/clp/htdocs/app/files/var/cache/*
rm -rf var/cache/*
systemctl restart php8.1-fpm
systemctl restart nginx

echo "✅ Setup complete! Access at: https://$(hostname -I | awk '{print $1}'):8443"
