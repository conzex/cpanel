# 🚀 Conzex CloudPanel Setup (One-Line Install)

This guide helps you install CloudPanel **with full Conzex branding**, footer customization, logo replacement, disk extension, and cleanup in **one step**.

---

## 🖥️ Supported OS

- Ubuntu 24.04 LTS
- Ubuntu 22.04 LTS
- Debian 12 LTS
- Debian 11 LTS

---

## ⚙️ Quick Install & Customize (Run All Below)

> 📋 Copy & paste this whole block into your terminal (as root):

```bash
apt update && apt -y upgrade && apt -y install curl wget sudo lvm2 gnupg && \
curl -sS https://installer.cloudpanel.io/ce/v2/install.sh -o install.sh && \
echo "a3ba69a8102345127b4ae0e28cfe89daca675cbc63cd39225133cdd2fa02ad36 install.sh" | sha256sum -c && \
sudo bash install.sh && \

# === Conzex Custom Setup ===
# 1. Extend Disk Automatically (Optional: assumes /dev/sdb exists)
if lsblk | grep -q 'sdb'; then
  pvcreate /dev/sdb && \
  vgextend ubuntu-vg /dev/sdb && \
  lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv && \
  resize2fs /dev/ubuntu-vg/ubuntu-lv
fi && \

# 2. Clean Disk
apt clean && \
rm -rf /var/log/* /var/cache/* && \
journalctl --vacuum-time=1d && \

# 3. MOTD Branding
chmod -x /etc/update-motd.d/10-cloudpanel && \
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
chmod +x /etc/update-motd.d/10-help-text && \

# 4. Replace Logos & Icons
sudo curl -o /home/clp/htdocs/app/files/public/assets/images/logo.svg https://cdn.conzex.com/media/image/cz-light.svg && \
sudo curl -o /home/clp/htdocs/app/files/public/assets/images/logo-dark.svg https://cdn.conzex.com/media/image/cz-dark.svg && \
sudo curl -o /home/clp/htdocs/app/files/public/favicon.ico https://cdn.conzex.com/media/other/favicon.ico && \
sudo curl -o /home/clp/htdocs/app/files/public/assets/images/cloudpanel-cloud.svg https://cdn.conzex.com/media/image/cz-light.svg && \
sudo curl -o /home/clp/htdocs/app/files/public/assets/images/favicon.svg https://cdn.conzex.com/media/image/app-logo.svg && \

# 5. Set Log Permissions
mkdir -p /var/log/nginx && touch /var/log/nginx/error.log && \
chown -R www-data:www-data /var/log/nginx && \

# 6. Inject Footer Links into All Twig Templates
sudo find /home/clp/htdocs/app/files/templates/ -type f -name "*.twig" \
  -exec grep -Iq . {} \; -print | \
xargs -I {} sudo sed -i '/footer-container/a \
<div class="footer-links text-center mt-3">\
  <a target="_blank" href="https://docs.conzex.com/cpanel/">Docs</a> | \
  <a target="_blank" href="https://www.conzex.com/contact-us/">Contact</a> | \
  <a target="_blank" href="https://conzex.com/en/privacy-policy/">Privacy Policy</a> | \
  <a target="_blank" href="https://conzex.com/en/terms-and-conditions/">Terms & Conditions</a> | \
  <a target="_blank" href="https://conzex.com/en/support-center/">Support</a> | \
  © $(date +%Y) <a target="_blank" href="https://www.conzex.com/">Conzex Global Private Limited</a>\
</div>' {} && \

# 7. Restart Services
rm -rf /home/clp/htdocs/app/files/var/cache/* && \
sudo systemctl restart php8.1-fpm && \
sudo systemctl restart nginx && \

echo "✅ Conzex CloudPanel Setup Completed!"
