#!/bin/bash

# ============================================================================
# rtorrent-rutorrent Otomatik Kurulum Scripti
# ============================================================================
# Bu script Docker, Docker Compose ve tüm gereken bileşenleri otomatik kurar
# ============================================================================

set -e  # Herhangi bir hata oluşursa script'i durdur

# Renkli çıktı için değişkenler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# FONKSIYONLAR
# ============================================================================

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

# ============================================================================
# KONTROLLER
# ============================================================================

print_header "Sistem Kontrolleri Yapılıyor..."

# Root kontrolü
if [ "$EUID" -eq 0 ]; then 
   print_error "Bu scripti root olarak çalıştırma! (sudo kullanmadan çalıştır)"
   exit 1
fi

print_success "Root kontrolü tamam"

# ============================================================================
# DOCKER KURULUMU (Eğer yoksa)
# ============================================================================

if ! command -v docker &> /dev/null; then
    print_header "Docker Kurulumu Yapılıyor..."
    
    # Sistem paketlerini güncelle
    print_info "Sistem paketleri güncelleniyor..."
    sudo apt update
    sudo apt upgrade -y
    
    # Docker kurulumu için gerekli paketleri kur
    print_info "Gerekli paketler kuruluyor..."
    sudo apt install -y ca-certificates curl gnupg lsb-release
    
    # Docker'ın GPG anahtarını ekle (güvenlik için)
    print_info "Docker GPG anahtarı ekleniyor..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Docker repository'sini ekle
    print_info "Docker repository'si ekleniyor..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Paket listesini güncelle
    print_info "Paket listesi güncelleniyor..."
    sudo apt update
    
    # Docker Engine, CLI ve Compose'u kur
    print_info "Docker Engine ve Compose kuruluyor..."
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Docker servisini başlat
    print_info "Docker servisi başlatılıyor..."
    sudo systemctl start docker
    sudo systemctl enable docker
    
    print_success "Docker başarıyla kuruldu"
else
    print_success "Docker zaten kurulu"
fi

# Docker Compose kontrol
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose kurulunamadı. Lütfen manuel olarak Docker kur."
    exit 1
fi

print_success "Docker Compose kurulu"

# ============================================================================
# KULLANICI GİRİŞLERİ
# ============================================================================

print_header "Yapılandırma Bilgileri Girişi"

# ruTorrent kullanıcı adı
echo ""
print_info "ruTorrent Web Arayüzü için Kullanıcı Bilgileri"
read -p "Kullanıcı Adı (örn: admin): " RUTORRENT_USER
while [ -z "$RUTORRENT_USER" ]; do
    print_error "Kullanıcı adı boş olamaz!"
    read -p "Kullanıcı Adı: " RUTORRENT_USER
done

# ruTorrent şifre
read -sp "Şifre (ekranda görünmeyecek): " RUTORRENT_PASS
echo ""
while [ -z "$RUTORRENT_PASS" ]; do
    print_error "Şifre boş olamaz!"
    read -sp "Şifre: " RUTORRENT_PASS
    echo ""
done

# Şifre doğrulama
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

# VPS IP adresi
echo ""
print_info "VPS Genel IP Adresi (Tracker'lara bildirilecek)"
print_warning "Boş bırakırsan otomatik tespit edilecek"
read -p "Genel IP Adresi (Enter'a basabilirsin): " WAN_IP
if [ -z "$WAN_IP" ]; then
    print_info "IP otomatik tespit edilecek"
    WAN_IP=""
else
    print_success "IP adresi: $WAN_IP"
fi

# Saat dilimi
echo ""
print_info "Saat Dilimi (varsayılan: Europe/Istanbul)"
read -p "Saat Dilimi (Enter için varsayılan): " TIMEZONE
TIMEZONE=${TIMEZONE:-Europe/Istanbul}
print_success "Saat dilimi: $TIMEZONE"

# ============================================================================
# KLASÖRLERIN OLUŞTURULMASI
# ============================================================================

print_header "Klasörler Oluşturuluyor..."

# Gerekli klasörleri oluştur
mkdir -p data downloads passwd

# Klasörlere sahip ve yetkiler
sudo chown -R 1000:1000 data downloads passwd
sudo chmod -R 755 data downloads passwd

print_success "Klasörler oluşturuldu"

# ============================================================================
# DOCKER COMPOSE DOSYASININ OLUŞTURULMASI
# ============================================================================

print_header "docker-compose.yml Yapılandırılıyor..."

# Eğer template dosya varsa onu kullan, yoksa satır içinde oluştur
if [ ! -f "docker-compose.yml" ]; then
cat > docker-compose.yml << 'EOF'
services:
  rtorrent-rutorrent:
    image: crazymax/rtorrent-rutorrent:latest
    container_name: rtorrent-rutorrent
    restart: unless-stopped
    network_mode: "host"
    environment:
      - TZ=${TIMEZONE}
      - PUID=1000
      - PGID=1000
      - WAN_IP=${WAN_IP}
      - MEMORY_LIMIT=512M
      - UPLOAD_MAX_SIZE=32M
      - RUTORRENT_PORT=8080
      - RUTORRENT_AUTHBASIC_STRING=ruTorrent Erisim - Kullanici Adi ve Sifre Gerekli
      - XMLRPC_PORT=8000
      - WEBDAV_PORT=9000
      - RT_DHT_PORT=6881
      - RT_INC_PORT=50000
      - RT_LOG_LEVEL=info
      - RT_SESSION_SAVE_SECONDS=3600
    volumes:
      - ./data:/data
      - ./downloads:/downloads
      - ./passwd:/passwd
    ulimits:
      nproc: 65535
      nofile:
        soft: 32000
        hard: 40000
EOF
    print_success "docker-compose.yml oluşturuldu"
else
    print_warning "docker-compose.yml zaten var"
fi

# ============================================================================
# HTPASSWD DOSYALARININ OLUŞTURULMASI
# ============================================================================

print_header "Kullanıcı Adı/Şifre Dosyaları Oluşturuluyor..."

print_info "ruTorrent Web Arayüzü için htpasswd oluşturuluyor..."
sudo docker run --rm httpd:2.4-alpine htpasswd -Bbn "$RUTORRENT_USER" "$RUTORRENT_PASS" | sudo tee passwd/rutorrent.htpasswd > /dev/null
print_success "rutorrent.htpasswd oluşturuldu"

print_info "XMLRPC (API) için htpasswd oluşturuluyor..."
sudo docker run --rm httpd:2.4-alpine htpasswd -Bbn "$RUTORRENT_USER" "$RUTORRENT_PASS" | sudo tee passwd/rpc.htpasswd > /dev/null
print_success "rpc.htpasswd oluşturuldu"

print_info "WebDAV (Dosya Erişimi) için htpasswd oluşturuluyor..."
sudo docker run --rm httpd:2.4-alpine htpasswd -Bbn "$RUTORRENT_USER" "$RUTORRENT_PASS" | sudo tee passwd/webdav.htpasswd > /dev/null
print_success "webdav.htpasswd oluşturuldu"

# Dosya sahipliğini ayarla
sudo chown 1000:1000 passwd/*.htpasswd
sudo chmod 600 passwd/*.htpasswd

print_success "Tüm htpasswd dosyaları oluşturuldu"

# ============================================================================
# .env DOSYASININ OLUŞTURULMASI
# ============================================================================

print_header ".env Dosyası Oluşturuluyor (Yerel Kayıt)..."

cat > .env << EOF
# ============================================================================
# rtorrent-rutorrent Yapılandırması
# ============================================================================
# UYARI: Bu dosya hassas bilgiler içerir. Git'e yükleme!
# ============================================================================

# ruTorrent kullanıcı bilgileri
RUTORRENT_USER=$RUTORRENT_USER
RUTORRENT_PASS=$RUTORRENT_PASS

# VPS IP adresi
WAN_IP=$WAN_IP

# Saat dilimi
TIMEZONE=$TIMEZONE

# Oluşturulma tarihi
CREATED_AT=$(date)
EOF

chmod 600 .env

print_success ".env dosyası oluşturuldu (sadece yerel kullanım)"

# ============================================================================
# .gitignore GÜNCELLEMESI
# ============================================================================

print_header ".gitignore Kontrol Ediliyor..."

if [ ! -f ".gitignore" ]; then
cat > .gitignore << EOF
# Hassas bilgiler ve yerel dosyalar
.env
.env.local
passwd/
data/
downloads/
*.log
.DS_Store
.vscode/
.idea/
EOF
    print_success ".gitignore oluşturuldu"
else
    print_warning ".gitignore zaten var"
fi

# ============================================================================
# SERVISLERIN BAŞLATILMASI
# ============================================================================

print_header "Docker Servisleri Başlatılıyor..."

print_info "İlk çalıştırma (imaj indirilebilir, biraz zaman alabilir)..."
sudo docker compose up -d

print_info "Servisin başlaması için 10 saniye bekleniyor..."
sleep 10

# ============================================================================
# KONTROL VE DOĞRULAMA
# ============================================================================

print_header "Kurulum Doğrulanıyor..."

# Container durumu kontrol
if sudo docker compose ps | grep -q "healthy"; then
    print_success "Container sağlıklı çalışıyor"
else
    print_warning "Container sağlık kontrolü henüz başlamadı, biraz bekle"
fi

# Portlar kontrol
print_info "Portlar kontrol ediliyor..."
if sudo ss -tulpn 2>/dev/null | grep -q ":8080"; then
    print_success "Port 8080 (ruTorrent) aktif"
else
    print_error "Port 8080 bulunamadı"
fi

# ============================================================================
# ÖZET VE SONUÇ
# ============================================================================

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
    # IP'yi otomatik tespit et
    DETECTED_IP=$(hostname -I | awk '{print $1}')
    echo -e "🌐 Web Arayüzü: ${GREEN}http://$DETECTED_IP:8080${NC}"
fi

echo -e "👤 Kullanıcı Adı: ${GREEN}$RUTORRENT_USER${NC}"
echo -e "🔐 Şifre: ${GREEN}(girdiğin şifre)${NC}"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}ÖNEMLI KLASÖRLER${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "📂 İndirilen Dosyalar: ${YELLOW}./downloads/complete/${NC}"
echo -e "📂 İndiriliyor: ${YELLOW}./downloads/temp/${NC}"
echo -e "📂 Yapılandırma: ${YELLOW}./data/${NC}"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}YARALI KOMUTLAR${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Logları görüntüle:${NC}"
echo -e "  ${GREEN}sudo docker compose logs -f${NC}"
echo ""
echo -e "${YELLOW}Servisleri durdur:${NC}"
echo -e "  ${GREEN}sudo docker compose stop${NC}"
echo ""
echo -e "${YELLOW}Servisleri başlat:${NC}"
echo -e "  ${GREEN}sudo docker compose start${NC}"
echo ""
echo -e "${YELLOW}Durumu kontrol et:${NC}"
echo -e "  ${GREEN}sudo docker compose ps${NC}"

echo ""
echo -e "${GREEN}Daha fazla bilgi için README.md dosyasını oku${NC}"
echo ""
