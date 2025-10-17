#!/bin/bash

set -xeuo pipefail

# Get build arguments from environment
NVIDIA_SUPPORT="${NVIDIA_SUPPORT:-false}"
IMAGE_NAME="${IMAGE_NAME:-base}"

# If NVIDIA support is enabled, add nvidia to image name
if [ "${NVIDIA_SUPPORT}" = "true" ]; then
    IMAGE_NAME="${IMAGE_NAME}-nvidia"
fi

### Basic packages and system setup

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
dnf5 install -y tmux

# System services and basic utilities
systemctl enable podman.socket

# NVIDIA support - install if enabled
if [ "${NVIDIA_SUPPORT}" = "true" ]; then
    echo "Installing NVIDIA support..."

    # Get current kernel version
    KERNEL="$(rpm -q --queryformat='%{evr}.%{arch}' kernel-core)"
    FEDORA_VERSION="$(rpm -E %fedora)"

    # Fetch NVIDIA akmods
    if skopeo copy --retry-times 3 docker://ghcr.io/ublue-os/akmods-nvidia:main-"${FEDORA_VERSION}"-"${KERNEL}" dir:/tmp/akmods-rpms; then
        NVIDIA_TARGZ=$(jq -r '.layers[].digest' </tmp/akmods-rpms/manifest.json | cut -d : -f 2)
        tar -xvzf /tmp/akmods-rpms/"$NVIDIA_TARGZ" -C /tmp/
        mv /tmp/rpms/* /tmp/akmods-rpms/

        # Install NVIDIA drivers and tools
        curl --retry 3 -Lo /tmp/nvidia-install.sh https://raw.githubusercontent.com/ublue-os/main/main/build_files/nvidia-install.sh
        chmod +x /tmp/nvidia-install.sh
        IMAGE_NAME="${IMAGE_NAME}" /tmp/nvidia-install.sh

        # Cleanup nouveau drivers and setup NVIDIA
        rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json
        ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so

        # Add kernel args for NVIDIA
        tee /usr/lib/bootc/kargs.d/00-nvidia.toml <<EOF
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1", "initcall_blacklist=simpledrm_platform_driver_init"]
EOF

        echo "NVIDIA support installed successfully"
    else
        echo "Failed to fetch NVIDIA akmods for kernel ${KERNEL}"
        exit 1
    fi
fi