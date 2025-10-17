#!/bin/bash

set -xeuo pipefail

### Cleanup and finalization

# Clean up package cache
dnf5 clean all

KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | tail -n 1)"
export DRACUT_NO_XATTR=1
dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
chmod 0600 "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"

# Clean up build artifacts that might have been created
rm -rf /var/cache/dnf/* /var/log/dnf* 2>/dev/null || true

echo "Build completed successfully!"
