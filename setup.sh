#!/bin/bash
set -e

# Track progress
function step() {
  echo -e "\033[1;32m=> $1\033[0m"
  sleep 0.5
}

step "Step 1: Creating Physical Volume"
pvcreate /dev/sdb

step "Step 2: Extending Volume Group"
vgextend ubuntu-vg /dev/sdb

step "Step 3: Extending Logical Volume"
lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv

step "Step 4: Resizing Filesystem"
resize2fs /dev/ubuntu-vg/ubuntu-lv

step "Disk successfully extended"
df -hT

step "Cleaning disk"
apt clean
rm -rf /var/log/*
rm -rf /var/cache/*
journalctl --vacuum-time=1d

step "Disabling original MOTD and adding custom welcome message"
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
* Admin Panel:     https://\$IP:8443
* CLI Tool:        cpanelctl

EOM
EOF

chmod +x /etc/update-motd.d/10-help-text

step "Replacing branding assets"
sudo curl -o /home/clp/htdocs/app/files/public/assets/images/logo.svg https://cdn.conzex.com/media/image/cz-light.svg
sudo curl -o /home/clp/htdocs/app/files/public/assets/images/logo-dark.svg https://cdn.conzex.com/media/image/cz-dark.svg
sudo curl -o /home/clp/htdocs/app/files/public/favicon.ico https://cdn.conzex.com/media/other/favicon.ico
sudo curl -o /home/clp/htdocs/app/files/public/assets/images/cloudpanel-cloud.svg https://cdn.conzex.com/media/image/cz-light.svg
sudo curl -o /home/clp/htdocs/app/files/public/assets/images/favicon.svg https://cdn.conzex.com/media/image/app-logo.svg

step "Fixing nginx log permissions"
sudo mkdir -p /var/log/nginx
sudo touch /var/log/nginx/error.log
sudo chown -R www-data:www-data /var/log/nginx

step "Clearing cache"
rm -rf var/cache/*

step "Restarting services"
sudo systemctl restart php8.1-fpm
sudo systemctl restart nginx
sudo systemctl status nginx.service
sudo journalctl -xeu nginx.service

step "Injecting footer globally"
sudo find /home/clp/htdocs/app/files/templates/ -type f -name "*.twig" \
  -exec grep -Iq . {} \; -print | \
  xargs -I {} sudo sed -i '/footer-container/a \
<div class="footer-links text-center mt-3">\
  <a target="_blank" href="https://docs.conzex.com/cpanel/">Docs</a> | \
  <a target="_blank" href="https://www.conzex.com/contact-us/">Contact</a> | \
  <a target="_blank" href="https://conzex.com/en/privacy-policy/">Privacy Policy</a> | \
  <a target="_blank" href="https://conzex.com/en/terms-and-conditions/">Terms & Conditions</a> | \
  <a target="_blank" href="https://conzex.com/en/support-center/">Support</a> | \
  © {{ "now"|date("Y") }} <a target="_blank" href="https://www.conzex.com/">Conzex Global Private Limited</a>\
</div>' {}

step "All steps completed successfully."
