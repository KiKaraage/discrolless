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

# Define the directory where extensions are located
EXTENSIONS_DIR="/usr/share/gnome-shell/extensions"

# Compile schemas and locales for each extension
for extension in $LOCAL_EXTENSIONS; do
    ext_path="$EXTENSIONS_DIR/$extension"

    # Compile schemas
    schema_dir="$ext_path/schemas"
    if [ -d "$schema_dir" ]; then
        echo "Compiling schemas for $extension"
        glib-compile-schemas --strict "$schema_dir"
    fi

    # Compile locales (locale/ directory)
    locale_dir="$ext_path/locale"
    if [ -d "$locale_dir" ]; then
        echo "Compiling 'locale/' directory for $extension"
        for po_file in "$locale_dir"/*/LC_MESSAGES/*.po; do
            if [ -f "$po_file" ]; then
                msgfmt "$po_file" -o "${po_file%.po}.mo"
            fi
        done
    fi

    # Compile locales (po/ directory)
    po_dir="$ext_path/po"
    if [ -d "$po_dir" ]; then
        echo "Compiling 'po/' directory for $extension"
        for po_file in "$po_dir"/*.po; do
            if [ -f "$po_file" ]; then
                msgfmt "$po_file" -o "${po_file%.po}.mo"
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
