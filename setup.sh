#!/bin/bash

set -e

echo "====================================="
echo "🚀 Starting Conzex - cPanel Setup"
echo "====================================="

# 0. Disable IPv6
echo "📛 Disabling IPv6..."
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1

# Set hostname
echo "🖥️ Setting hostname to 'Prod-cPanel'..."
hostnamectl set-hostname Prod-cPanel

# 1. Basic system update
echo "🔄 Updating system..."
apt update && apt -y upgrade && apt -y install curl wget sudo lvm2 gnupg

# 2. Extend disk before CloudPanel installation
echo "💽 Checking for free space and extending root volume if needed..."
ROOT_LV=$(lsblk -o NAME,MOUNTPOINT | grep ' /$' | awk '{print $1}')
VG_NAME=$(vgdisplay | grep 'VG Name' | awk '{print $3}')

if [ -n "$VG_NAME" ] && [ -n "$ROOT_LV" ]; then
  FREE_PE=$(vgdisplay "$VG_NAME" | awk '/Free  PE/ {print $5}')
  if [ "$FREE_PE" -gt 0 ]; then
    echo "📏 Extending root logical volume using $FREE_PE free PEs..."
    lvextend -l +"$FREE_PE" "/dev/$VG_NAME/$ROOT_LV" -r
  else
    echo "⚠️ No free space in VG. Skipping disk extension."
  fi
else
  echo "❌ Could not determine VG or LV name. Disk extension skipped."
fi

FREE_SPACE=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$FREE_SPACE" -lt 6 ]; then
  echo "❌ Not enough free disk space on root (only ${FREE_SPACE}GB available)."
  echo "Aborting setup. You must extend the root volume manually."
  exit 1
fi

# 3. Install CloudPanel
echo "📦 Installing CloudPanel..."
curl -sS https://installer.cloudpanel.io/ce/v2/install.sh -o install.sh
echo "a3ba69a8102345127b4ae0e28cfe89daca675cbc63cd39225133cdd2fa02ad36 install.sh" | sha256sum -c
sudo bash install.sh

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
chmod -x /etc/update-motd.d/10-cloudpanel
cat <<'EOF' > /etc/update-motd.d/10-help-text
#!/bin/sh
IP=$(hostname -I | awk '{print $1}')
cat <<EOM
########################################################
###               Welcome to cPanel                   ###
########################################################

* Website:         https://cpanel.conzex.com
* Documentation:   https://docs.conzex.com/cpanel
* Support:         https://conzex.com/contact
* Admin Panel:     https://$IP:8443
* CLI Tool:        cpanelctl

EOM
EOF
chmod +x /etc/update-motd.d/10-help-text

# 7. Replace branding assets
echo "🎨 Replacing logos and favicons..."
sudo curl -o /home/clp/htdocs/app/files/public/assets/images/logo.svg https://cdn.conzex.com/media/image/cz-light.svg
sudo curl -o /home/clp/htdocs/app/files/public/assets/images/logo-dark.svg https://cdn.conzex.com/media/image/cz-dark.svg
sudo curl -o /home/clp/htdocs/app/files/public/favicon.ico https://cdn.conzex.com/media/other/favicon.ico
sudo curl -o /home/clp/htdocs/app/files/public/assets/images/cloudpanel-cloud.svg https://cdn.conzex.com/media/image/cz-light.svg
sudo curl -o /home/clp/htdocs/app/files/public/assets/images/favicon.svg https://cdn.conzex.com/media/image/app-logo.svg

# 8. Ensure nginx log dir exists
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
  <a target="_blank" href="https://www.conzex.com/contact-us/">Contact</a> | \
  <a target="_blank" href="https://conzex.com/en/privacy-policy/">Privacy Policy</a> | \
  <a target="_blank" href="https://conzex.com/en/terms-and-conditions/">Terms & Conditions</a> | \
  <a target="_blank" href="https://conzex.com/en/support-center/">Support</a> | \
  © $(date +%Y) <a target="_blank" href="https://www.conzex.com/">Conzex Global Private Limited</a>\
</div>' {}

# 10. Final cleanup & restart services
echo "🔁 Restarting services..."
rm -rf /home/clp/htdocs/app/files/var/cache/*
systemctl restart php8.1-fpm
systemctl restart nginx

echo "✅ Setup complete! Visit https://your-server-ip:8443"
