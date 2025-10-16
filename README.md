# rtorrent-rutorrent_mkpCapt
Docker tabanlı rTorrent + ruTorrent kurulumu - Türkçe rehber

# rtorrent-rutorrent - Docker Kurulum Sistemi

Docker tabanlı **rTorrent** ve **ruTorrent** kurulumu. Türkçe rehberli, otomatik install scripti ile tek komutla kuruluyor.

## ⚡ Hızlı Kurulum
```bash
git clone https://github.com/mkptheCapt/rtorrent-rutorrent_mkpCapt.git
cd rtorrent-rutorrent_mkpCapt
bash install.sh
```

## 📋 Kurulum Sırasında Sorulacaklar

1. **ruTorrent Web Arayüzü Kullanıcı Adı** (örn: admin)
2. **ruTorrent Şifre** (güvenli bir şifre gir)
3. **VPS Genel IP Adresi** (boş bırakabilirsin - otomatik tespit)
4. **Saat Dilimi** (varsayılan: Europe/Istanbul)

## ✨ Özellikler

- ✅ **Otomatik Kurulum** - `install.sh` ile her şey otomatik
- ✅ **Web Arayüzü** - ruTorrent modern web interface
- ✅ **Şifre Koruması** - Kullanıcı adı/şifre ile güvenli erişim
- ✅ **WebDAV Desteği** - Tamamlanan dosyalara network üzerinden erişim
- ✅ **XMLRPC API** - Harici uygulamalardan kontrol
- ✅ **Türkçe Rehber** - Türkçe açıklamalarla tüm dosyalar
- ✅ **Docker Container** - Kolay yönetim ve yükseltme

## 📂 Erişim Adresleri (Kurulum Sonrası)
```
🌐 ruTorrent Web:    http://VPS_IP:8080
🌐 WebDAV:           http://VPS_IP:9000
🌐 XMLRPC (API):     http://VPS_IP:8000
```

Kullanıcı Adı ve Şifre: Kurulum sırasında girdiğin bilgiler

## 📁 Önemli Klasörler
```
rtorrent-rutorrent_mkpCapt/
├── data/               # rTorrent yapılandırması ve loglar
├── downloads/
│   ├── temp/          # İndiriliyor (tamamlanmamış)
│   └── complete/      # Tamamlanan dosyalar
└── passwd/            # Kullanıcı şifreleri (GİT'E YÜKLEME!)
```

## 🔧 Temel Komutlar
```bash
# Logları izle (canlı)
sudo docker compose logs -f

# Container durumunu kontrol et
sudo docker compose ps

# Servisleri durdur
sudo docker compose stop

# Servisleri başlat
sudo docker compose start

# Servisleri yeniden başlat
sudo docker compose restart
```

## 🔒 Güvenlik Notları

⚠️ **ÖNEMLİ:**
- `.env` dosyası hassas bilgiler içerir - **GİT'E YÜKLEME!**
- `passwd/` klasörü kullanıcı şifreleri içerir - **GİT'E YÜKLEME!**
- `.gitignore` bu dosyaları otomatik olarak hariç tutar

## 🔄 Hassas Bilgileri Değiştirme

Şifre değiştirmek için:
```bash
cd rtorrent-rutorrent_mkpCapt
sudo docker run --rm httpd:2.4-alpine htpasswd -Bbn YENİ_KULLANICI YENİ_ŞİFRE | sudo tee passwd/rutorrent.htpasswd
sudo docker compose restart
```

## 📊 Sistem Gereksinimleri

- Ubuntu 20.04+ veya Debian 11+
- Docker 20.10+
- Docker Compose 2.0+
- Minimum 1GB RAM (4GB+ önerilir)
- Internet bağlantısı

## 📚 İlgili Bağlantılar

- [rTorrent GitHub](https://github.com/rakshasa/rtorrent)
- [ruTorrent GitHub](https://github.com/Novik/ruTorrent)
- [crazy-max Docker Imajı](https://github.com/crazy-max/docker-rtorrent-rutorrent)

## 📝 Lisans

MIT License

## 🤝 Katkıda Bulun

Hataları bildir, fikirler öner: GitHub Issues'de yazabilirsin.

---

**Hazırladı:** mkptheCapt  
**Son Güncelleme:** 2025-10-16
