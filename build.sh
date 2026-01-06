#!/usr/bin/bash
set -eoux pipefail


echo "::group:: Copy Custom Files"

echo "::endgroup::"


echo "::group:: System Configuration"

# Enable/disable systemd services
# Example: systemctl enable podman.socket
# Example: systemctl mask unwanted-service

echo "::endgroup::"

echo "Custom build complete!"