# 🚀 Conzex | cPanel Setup

Automated installer script for setting up **CloudPanel** with **Conzex Global branding**, disk space configuration, MOTD, logo, and system optimizations.

---

## 🛠 Supported OS

- Ubuntu 24.04 LTS
- Ubuntu 22.04 LTS
- Debian 12 LTS
- Debian 11 LTS

---

## 📦 What This Script Does

- ✅ Installs official **CloudPanel v2**
- ✅ Applies **Conzex branding** (logo, favicon, footer links)
- ✅ Extends disk if `/dev/sdb` is available
- ✅ Cleans logs, cache, and junk
- ✅ Adds a **custom welcome MOTD**
- ✅ Restarts key services (`nginx`, `php8.1-fpm`)
- ✅ Replaces CloudPanel logos and links
- ✅ Modifies footer with company info and support links

---

## ⚙️ How to Use

### 1️⃣ SSH Into Your Server

**Using a private key:**
```bash
ssh -i /path/to/private_key.pem root@your_server_ip
