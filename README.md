# GenieACS Armbian Installer

Installer otomatis untuk GenieACS 1.2.13 pada Armbian v24.04 Ubuntu (Noble).

## 🚀 Fitur

- Instalasi GenieACS dan dependensinya (Node.js, MongoDB 4.4.8, libssl1.1)
- Konfigurasi logrotate
- Pembuatan file systemd
- Dukungan CLI interaktif dengan spinner dan warna
- Uninstaller bawaan untuk rollback

## 📦 Requirements

- Armbian 24.04
- Akses root / sudo

## 🛠️ Cara Install

```bash
git clone https://github.com/username/genieacs-ubuntu-installer.git
cd genieacs-armbian-installer
chmod +x install.sh uninstall.sh
sudo ./install.sh
```

Setelah selesai, buka browser ke http://<ip-server>:3000

## 🔁 Cara Uninstall

```bash
sudo ./uninstall.sh
```
