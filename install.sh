#!/bin/bash

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonksiyonlar
print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Root kontrolü
if [ "$EUID" -eq 0 ]; then 
   print_error "Bu scripti root olarak çalıştırma! (sudo kullanmadan çalıştır)"
   exit 1
fi

# Docker kontrol
if ! command -v docker &> /dev/null; then
    print_error "Docker bulunamadı. Lütfen Docker'ı kur: https://docs.docker.com/engine/install/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose bulunamadı."
    exit 1
fi

print_success "Docker kurulu"

# Giriş değerleri
print_header "YAPIYLANDIRMA BİLGİLERİ"

echo ""
print_info "ruTorrent Web Arayüzü için Kullanıcı Bilgileri"
read -p "Kullanıcı Adı (örn: admin): " RUTORRENT_USER
while [ -z "$RUTORRENT_USER" ]; do
    print_error "Kullanıcı adı boş olamaz!"
    read -p "Kullanıcı Adı: " RUTORRENT_USER
done

read -sp "Şifre (ekranda görünmeyecek): " RUTORRENT_PASS
echo ""
while [ -z "$RUTORRENT_PASS" ]; do
    print_error "Şifre boş olamaz!"
    read -sp "Şifre: " RUTORRENT_PASS
    echo ""
done

read -sp "Şifre (tekrar - doğrulama): " RUTORRENT_PASS_CONFIRM
echo ""
while [ "$RUTORRENT_PASS" != "$RUTORRENT_PASS_CONFIRM" ]; do
    print_error "Şifreler eşleşmiyor!"
    read -sp "Şifre: " RUTORRENT_PASS
    echo ""
    read -sp "Şifre (tekrar): " RUTORRENT_PASS_CONFIRM
    echo ""
done

print_success "ruTorrent kullanıcı bilgileri kaydedildi"

echo ""
print_info "VPS Genel IP Adresi (Tracker'lara bildirilecek)"
print_warning "Boş bırakırsan otomatik tespit edilecek"
read -p "Genel IP Adresi (Enter'a basabilirsin): " WAN_IP
if [ -n "$WAN_IP" ]; then
    print_success "IP adresi: $WAN_IP"
else
    print_info "IP otomatik tespit edilecek"
fi

echo ""
print_info "Saat Dilimi (varsayılan: Europe/Istanbul)"
read -p "Saat Dilimi (Enter için varsayılan): " TIMEZONE
TIMEZONE=${TIMEZONE:-Europe/Istanbul}
print_success "Saat dilimi: $TIMEZONE"

# Klasörler
print_header "KLASÖRLER OLUŞTURULUYOR"

mkdir -p data downloads passwd
sudo chown -R 1000:1000 data downloads passwd
sudo chmod -R 755 data downloads passwd

print_success "Klasörler oluşturuldu"

# .env dosyası
print_header ".ENV DOSYASI OLUŞTURULUYOR"

cat > .env << EOF
RUTORRENT_USER=$RUTORRENT_USER
RUTORRENT_PASS=$RUTORRENT_PASS
WAN_IP=$WAN_IP
TIMEZONE=$TIMEZONE
CREATED_AT=$(date)
EOF

chmod 600 .env
print_success ".env dosyası oluşturuldu"

# htpasswd dosyaları
print_header "KULLANICI DOSYALARI OLUŞTURULUYOR"

print_info "ruTorrent Web Arayüzü için..."
sudo docker run --rm httpd:2.4-alpine htpasswd -Bbn "$RUTORRENT_USER" "$RUTORRENT_PASS" | sudo tee passwd/rutorrent.htpasswd > /dev/null
print_success "rutorrent.htpasswd oluşturuldu"

print_info "XMLRPC API için..."
sudo docker run --rm httpd:2.4-alpine htpasswd -Bbn "$RUTORRENT_USER" "$RUTORRENT_PASS" | sudo tee passwd/rpc.htpasswd > /dev/null
print_success "rpc.htpasswd oluşturuldu"

print_info "WebDAV Dosya Erişimi için..."
sudo docker run --rm httpd:2.4-alpine htpasswd -Bbn "$RUTORRENT_USER" "$RUTORRENT_PASS" | sudo tee passwd/webdav.htpasswd > /dev/null
print_success "webdav.htpasswd oluşturuldu"

sudo chown 1000:1000 passwd/*.htpasswd
sudo chmod 600 passwd/*.htpasswd

print_success "Tüm kullanıcı dosyaları oluşturuldu"

# Docker servisleri başlat
print_header "DOCKER SERVİSLERİ BAŞLATILIYOR"

print_info "İlk çalıştırma (imaj indirilebilir, biraz zaman alabilir)..."
sudo docker compose up -d

sleep 10

if sudo docker compose ps | grep -q "rtorrent-rutorrent"; then
    print_success "Container başarıyla başlatıldı"
else
    print_error "Container başlatılamadı!"
    exit 1
fi

# Portlar kontrol
print_header "KURULUM DOĞRULANIYYOR"

if sudo ss -tulpn 2>/dev/null | grep -q ":8080"; then
    print_success "Port 8080 (ruTorrent) aktif"
fi

# Özet
print_header "✓ KURULUM TAMAMLANDI"

echo ""
echo -e "${GREEN}🎉 rtorrent-rutorrent başarıyla kuruldu!${NC}"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}ERIŞIM BİLGİLERİ${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

if [ -n "$WAN_IP" ]; then
    echo -e "🌐 Web Arayüzü: ${GREEN}http://$WAN_IP:8080${NC}"
else
    DETECTED_IP=$(hostname -I | awk '{print $1}')
    echo -e "🌐 Web Arayüzü: ${GREEN}http://$DETECTED_IP:8080${NC}"
fi

echo -e "👤 Kullanıcı Adı: ${GREEN}$RUTORRENT_USER${NC}"
echo -e "🔐 Şifre: ${GREEN}(girdiğin şifre)${NC}"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}YARALI KOMUTLAR${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Logları izle:${NC}"
echo -e "  ${GREEN}sudo docker compose logs -f${NC}"
echo ""
echo -e "${YELLOW}Servisleri durdur:${NC}"
echo -e "  ${GREEN}sudo docker compose stop${NC}"
echo ""
echo -e "${YELLOW}Servisleri başlat:${NC}"
echo -e "  ${GREEN}sudo docker compose start${NC}"
