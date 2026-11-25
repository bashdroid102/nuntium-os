# Базовый атомарный образ с KDE Plasma 6 (Wayland), драйверами AMD/Vulkan и поддержкой bootc
FROM ghcr.io/ublue-os/kinoite-main:latest

LABEL org.opencontainers.image.title="Nuntium OS"
LABEL org.opencontainers.image.description="Secure atomic operating system with Windows-like ergonomics and integrated VPN"
LABEL org.opencontainers.image.vendor="Nuntium Project"

# Копируем статические системные файлы (sysctl, метаданные Nuntium OS)
COPY system_files/ /

# Копируем и запускаем скрипт сборки (с защитой от Windows CRLF)
COPY build_scripts/build.sh /tmp/build.sh
RUN sed -i 's/\r$//' /tmp/build.sh && \
    chmod +x /tmp/build.sh && \
    /tmp/build.sh && \
    rm -f /tmp/build.sh