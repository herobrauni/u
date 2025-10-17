#!/bin/bash

set -ouex pipefail

# Get build arguments
NVIDIA_SUPPORT="${NVIDIA_SUPPORT:-false}"
IMAGE_NAME="${IMAGE_NAME:-base}"

# If NVIDIA support is enabled, add nvidia to image name
if [ "${NVIDIA_SUPPORT}" = "true" ]; then
    IMAGE_NAME="${IMAGE_NAME}-nvidia"
fi

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux

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

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
