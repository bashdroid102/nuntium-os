#!/usr/bin/env bash
set -ouex pipefail

DNF=$(command -v dnf5 || command -v dnf)

echo "=== [1/7] Установка стека безопасности, AMD Vulkan, Tor, PyQt6 и контейнеров ==="
$DNF install -y \
    bubblewrap \
    usbguard \
    usbguard-dbus \
    nftables \
    zram-generator \
    distrobox \
    podman \
    mesa-vulkan-drivers \
    vulkan-loader \
    vulkan-tools \
    librsvg2-tools \
    plymouth-theme-spinner \
    tor \
    python3-pyqt6 \
    nano \
    fastfetch

echo "=== [2/7] Установка ядра sing-box (поддержка Hysteria 2 TUN) ==="
SINGBOX_VER="1.11.4"
curl -fsSL "https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VER}/sing-box-${SINGBOX_VER}-linux-amd64.tar.gz" \
    -o /tmp/sing-box.tar.gz
tar -xzf /tmp/sing-box.tar.gz -C /tmp
install -m 755 "/tmp/sing-box-${SINGBOX_VER}-linux-amd64/sing-box" /usr/bin/sing-box
rm -rf /tmp/sing-box.tar.gz "/tmp/sing-box-${SINGBOX_VER}-linux-amd64"
/usr/bin/sing-box version

echo "=== [3/7] Удаление лишних пакетов и отключение сборщиков отчетов ==="
REMOVE_PKGS=(
    kmines
    kmahjongg
    kpat
    konqueror
    fedora-bookmarks
    fedora-chromium-config
)

for pkg in "${REMOVE_PKGS[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
        $DNF remove -y "$pkg"
    fi
done

for svc in abrtd.service abrt-oops.service abrt-xorg.service; do
    if systemctl list-unit-files "$svc" &>/dev/null; then
        systemctl mask "$svc" || true
    fi
done

echo "=== [4/7] Ребрендинг системы в Nuntium OS ==="
sed -i 's/^NAME=.*/NAME="Nuntium OS"/' /usr/lib/os-release
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Nuntium OS 1.0 (Balance)"/' /usr/lib/os-release
if grep -q '^VARIANT=' /usr/lib/os-release; then
    sed -i 's/^VARIANT=.*/VARIANT="Nuntium Desktop (Balance)"/' /usr/lib/os-release
else
    echo 'VARIANT="Nuntium Desktop (Balance)"' >> /usr/lib/os-release
fi
if grep -q '^VARIANT_ID=' /usr/lib/os-release; then
    sed -i 's/^VARIANT_ID=.*/VARIANT_ID=nuntium-balance/' /usr/lib/os-release
else
    echo 'VARIANT_ID=nuntium-balance' >> /usr/lib/os-release
fi

echo "=== [5/7] Сборка графических ассетов и настройка сетевых утилит ==="
# Очистка возможных Windows CRLF во всех конфигах и скриптах
sed -i 's/\r$//' \
    /usr/share/color-schemes/NuntiumDark.colors \
    /usr/share/color-schemes/NuntiumLight.colors \
    /usr/libexec/nuntium-apply-desktop.sh \
    /usr/libexec/nuntium-net-ctl \
    /usr/bin/nuntium-net \
    /usr/bin/nuntium-net-tray \
    /usr/bin/nuntium-tor-browser \
    /etc/NetworkManager/conf.d/10-nuntium-privacy.conf \
    /etc/systemd/resolved.conf.d/10-nuntium-dns.conf \
    /etc/polkit-1/rules.d/50-nuntium-net.rules \
    /usr/share/nuntium/vpn.toml.example

chmod +x \
    /usr/libexec/nuntium-apply-desktop.sh \
    /usr/libexec/nuntium-net-ctl \
    /usr/bin/nuntium-net \
    /usr/bin/nuntium-net-tray \
    /usr/bin/nuntium-tor-browser

# Иконка кнопки Пуск
install -d /usr/share/icons/hicolor/scalable/apps
cp /usr/share/nuntium/logo.svg /usr/share/icons/hicolor/scalable/apps/nuntium-start.svg
gtk-update-icon-cache -f /usr/share/icons/hicolor || true

# Аватар пользователя по умолчанию (256x256 PNG) для Kickoff и SDDM
rsvg-convert -w 256 -h 256 /usr/share/nuntium/logo.svg -o /usr/share/nuntium/avatar.png
install -d /etc/skel
cp /usr/share/nuntium/avatar.png /etc/skel/.face.icon
ln -sf .face.icon /etc/skel/.face

# Обои рабочего стола и SDDM (1920x1080 PNG из SVG)
install -d /usr/share/wallpapers/Nuntium/contents/images
rsvg-convert -w 1920 -h 1080 /usr/share/nuntium/wallpaper-dark.svg \
    -o /usr/share/wallpapers/Nuntium/contents/images/1920x1080.png

# Тема загрузки Plymouth
cp -a /usr/share/plymouth/themes/spinner/*.png /usr/share/plymouth/themes/nuntium/ || true
rsvg-convert -w 420 -h 320 /usr/share/nuntium/plymouth-brand.svg \
    -o /usr/share/plymouth/themes/nuntium/watermark.png
plymouth-set-default-theme nuntium

# Переводим firewalld в скрытый режим (отбрасывать все unsolicited входящие пакеты)
if [ -f /etc/firewalld/firewalld.conf ]; then
    sed -i 's/^DefaultZone=.*/DefaultZone=drop/' /etc/firewalld/firewalld.conf
fi

# Tor и Hysteria 2 не стартуют в фоне по умолчанию (включаются по запросу)
systemctl disable tor.service || true
systemctl disable nuntium-vpn.service || true

echo "=== [6/7] Включение сервисов и пересборка initramfs с темой Plymouth ==="
systemctl enable podman.socket

KVER=$(ls /usr/lib/modules | head -n 1)
DRACUT_NO_XATTR=1 dracut \
    --no-hostonly \
    --kver "$KVER" \
    --reproducible \
    --zstd \
    -v \
    --add plymouth \
    -f "/usr/lib/modules/${KVER}/initramfs.img"

echo "=== [7/7] Очистка кэшей ==="
$DNF clean all
rm -rf /tmp/* /var/tmp/* /var/cache/dnf/* /var/cache/libdnf5/*

echo "=== Сборка слоя Nuntium OS (Шаг 3 — Network Shield, Hysteria 2 & Tor) успешно завершена ==="