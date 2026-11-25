#!/usr/bin/env bash
set -euo pipefail

STAMP_FILE="$HOME/.config/.nuntium-desktop-v3"
if [ -f "$STAMP_FILE" ]; then
    exit 0
fi

mkdir -p "$HOME/.config"

# 1. Аватар пользователя Nuntium OS и сброс кэша старых иконок
if [ -f /usr/share/nuntium/avatar.png ]; then
    cp /usr/share/nuntium/avatar.png "$HOME/.face.icon"
    ln -sf "$HOME/.face.icon" "$HOME/.face"
fi
rm -f "$HOME/.cache/icon-cache.kcache" "$HOME/.cache/plasma_theme_"*.kcache

# 2. Темная индиго-фиолетовая схема NuntiumDark и явный акцент #7F77DD
kwriteconfig6 --file kdeglobals --group General --key accentColorFromWallpaper false
plasma-apply-colorscheme NuntiumDark || true
plasma-apply-colorscheme --accent-color "#7f77dd" || true
kwriteconfig6 --file kdeglobals --group KDE --key SingleClick false

# 3. Эффект матового стекла (Blur), превью окон по Alt+Tab и центрирование новых окон
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled true
kwriteconfig6 --file kwinrc --group Effect-blur --key BlurStrength 10
kwriteconfig6 --file kwinrc --group Effect-blur --key NoiseStrength 2
kwriteconfig6 --file kwinrc --group TabBox --key LayoutName "thumbnail_grid"
kwriteconfig6 --file kwinrc --group TabBox --key HighlightWindows true
kwriteconfig6 --file kwinrc --group Windows --key Placement "Centered"

# 4. Привычные горячие клавиши Windows
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Show Desktop" "Meta+D,Meta+D,Peek at Desktop"
kwriteconfig6 --file kglobalshortcutsrc --group ksmserver --key "Lock Session" $'Meta+L\tScreensaver,Meta+L\tScreensaver,Lock Session'
kwriteconfig6 --file kglobalshortcutsrc --group services --group org.kde.dolphin.desktop --key "_launch" "Meta+E"

# 5. Обои Nuntium OS (темно-индиговый градиент с сеткой и светящимся логотипом)
if [ -f /usr/share/wallpapers/Nuntium/contents/images/1920x1080.png ]; then
    plasma-apply-wallpaperimage /usr/share/wallpapers/Nuntium/contents/images/1920x1080.png || true
fi

# 6. Нижняя полупрозрачная панель с центрированными иконками
QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || true)
if [ -n "$QDBUS" ]; then
    for _ in $(seq 1 15); do
        if $QDBUS org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "1;" &>/dev/null; then
            break
        fi
        sleep 1
    done

    $QDBUS org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
        var existingPanels = panels();
        for (var i = 0; i < existingPanels.length; i++) {
            existingPanels[i].remove();
        }

        var panel = new Panel();
        panel.location = "bottom";
        panel.height = 52;
        panel.floating = false;

        panel.addWidget("org.kde.plasma.panelspacer");

        var kicker = panel.addWidget("org.kde.plasma.kickoff");
        kicker.currentConfigGroup = ["General"];
        kicker.writeConfig("icon", "nuntium-start");
        kicker.writeConfig("favoritesPortedToKAstats", true);

        var tasks = panel.addWidget("org.kde.plasma.icontasks");
        tasks.currentConfigGroup = ["General"];
        tasks.writeConfig("launchers", [
            "applications:org.kde.dolphin.desktop",
            "applications:org.kde.konsole.desktop",
            "applications:systemsettings.desktop",
            "applications:org.mozilla.firefox.desktop"
        ]);

        panel.addWidget("org.kde.plasma.panelspacer");

        panel.addWidget("org.kde.plasma.systemtray");

        var clock = panel.addWidget("org.kde.plasma.digitalclock");
        clock.currentConfigGroup = ["Appearance"];
        clock.writeConfig("use24hFormat", 2);
        clock.writeConfig("showDate", true);
        clock.writeConfig("dateFormat", "shortDate");

        panel.addWidget("org.kde.plasma.showdesktop");
    ' || true

    $QDBUS org.kde.KWin /KWin reconfigure || true
fi

touch "$STAMP_FILE"