#!/usr/bin/bash
set -eoux pipefail


echo "::group:: Copy Custom Files"

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
# Example: systemctl enable podman.socket
# Example: systemctl mask unwanted-service

echo "::endgroup::"

# GNOME Extensions Setup

echo "::group:: GNOME Extensions Setup"

# Compile schemas for all extensions
for schema_dir in /usr/share/gnome-shell/extensions/*/schemas; do
    if [ -d "${schema_dir}" ]; then
        glib-compile-schemas --strict "${schema_dir}"
    fi
done

# Compile locales for extensions that need it
# Handle locale/ directory structure (Vitals, Clipboard Indicator)
for locale_dir in /usr/share/gnome-shell/extensions/*/locale; do
    if [ -d "${locale_dir}" ]; then
        for po_file in "${locale_dir}"/*/LC_MESSAGES/*.po; do
            if [ -f "${po_file}" ]; then
                msgfmt "${po_file}" -o "${po_file%.po}.mo"
            fi
        done
    fi
done

# Handle po/ directory structure (Bluetooth Battery Meter)
for po_dir in /usr/share/gnome-shell/extensions/*/po; do
    if [ -d "${po_dir}" ]; then
        for po_file in "${po_dir}"/*.po; do
            if [ -f "${po_file}" ]; then
                msgfmt "${po_file}" -o "${po_file%.po}.mo"
            fi
        done
    fi
done

# Install Vitals helper binaries
if [ -d /usr/share/gnome-shell/extensions/Vitals@CoreCoding.com/helpers ]; then
    install -Dpm0755 -t /usr/bin /usr/share/gnome-shell/extensions/Vitals@CoreCoding.com/helpers/*
fi

echo "::endgroup::"

echo "Custom build complete!"
