#!/usr/bin/env bash
set -ouex pipefail

DNF=$(command -v dnf5 || command -v dnf)

echo "=== [1/5] Установка базового стека безопасности, AMD Vulkan и контейнеров ==="
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
    fastfetch

echo "=== [2/5] Удаление лишних пакетов и отключение фоновых сборщиков отчетов ==="
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

# Отключаем автоматическую отправку отчетов о сбоях (если присутствует в образе)
for svc in abrtd.service abrt-oops.service abrt-xorg.service; do
    if systemctl list-unit-files "$svc" &>/dev/null; then
        systemctl mask "$svc" || true
    fi
done

echo "=== [3/5] Ребрендинг системы в Nuntium OS ==="
# Оставляем ID=fedora для совместимости с bootc-image-builder и репозиториями.
# В интерфейсе, загрузчике и fastfetch система будет отображаться как Nuntium OS.
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

echo "=== [4/5] Включение базовых системных сервисов ==="
systemctl enable podman.socket
# usbguard и жесткий nftables Kill-Switch будут активированы после генерации правил на Шагах 3 и 5

echo "=== [5/5] Очистка кэшей для минимального размера образа ==="
$DNF clean all
rm -rf /tmp/* /var/tmp/* /var/cache/dnf/* /var/cache/libdnf5/*

echo "=== Сборка базового слоя Nuntium OS успешно завершена ==="