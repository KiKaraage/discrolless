#!/usr/bin/bash
set -eoux pipefail

# Enable/disable systemd services
# Example: systemctl enable podman.socket
# Example: systemctl mask unwanted-service

echo "::group:: GNOME Extensions Setup"

# Compile schemas for all extensions
for schema_dir in /usr/share/gnome-shell/extensions/*/schemas; do
    if [ -d "${schema_dir}" ]; then
        glib-compile-schemas --strict "${schema_dir}"
    fi
done

# Compile locales for extensions that need it
# Bluetooth Battery Meter (po/)
if [ -d /usr/share/gnome-shell/extensions/Bluetooth-Battery-Meter@maniacx.github.com/po ]; then
    for po_file in /usr/share/gnome-shell/extensions/Bluetooth-Battery-Meter@maniacx.github.com/po/*.po; do
        if [ -f "${po_file}" ]; then
            msgfmt "${po_file}" -o "${po_file%.po}.mo"
        fi
    done
fi

# Vitals (locale/)
if [ -d /usr/share/gnome-shell/extensions/Vitals@CoreCoding.com/locale ]; then
    for po_file in /usr/share/gnome-shell/extensions/Vitals@CoreCoding.com/locale/*/LC_MESSAGES/*.po; do
        if [ -f "${po_file}" ]; then
            msgfmt "${po_file}" -o "${po_file%.po}.mo"
        fi
    done
fi

# Clipboard Indicator (locale/)
if [ -d /usr/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com/locale ]; then
    for po_file in /usr/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com/locale/*/LC_MESSAGES/*.po; do
        if [ -f "${po_file}" ]; then
            msgfmt "${po_file}" -o "${po_file%.po}.mo"
        fi
    done
fi

# Install Vitals helper binaries
if [ -d /usr/share/gnome-shell/extensions/Vitals@CoreCoding.com/helpers ]; then
    install -Dpm0755 -t /usr/bin /usr/share/gnome-shell/extensions/Vitals@CoreCoding.com/helpers/*
fi

echo "::endgroup::"

echo "Custom build complete!"
