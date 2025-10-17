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
systemctl enable systemd-timesyncd
systemctl enable systemd-resolved.service

dnf -y install dnf-plugins-core 'dnf5-command(config-manager)'

# tailscale
dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf config-manager setopt tailscale-stable.enabled=0
dnf -y install --enablerepo='tailscale-stable' tailscale
systemctl enable tailscaled

# tools
dnf -y install \
    NetworkManager-wifi \
    atheros-firmware \
    brcmfmac-firmware \
    iwlegacy-firmware \
    iwlwifi-dvm-firmware \
    iwlwifi-mvm-firmware \
    mt7xxx-firmware \
    nxpwireless-firmware \
    realtek-firmware \
    tiwilink-firmware \
    firewalld


dnf -y install \
    plymouth \
    plymouth-system-theme \
    fwupd \
    libcamera{,-{v4l2,gstreamer,tools}} \
    whois \
    tuned \
    tuned-ppd \
    unzip \
    steam-devices \
    fuse-devel \
    fuse \
    fuse-common \
    rclone \
    uxplay

# This package adds "[systemd] Failed Units: *" to the bashrc startup
dnf -y remove console-login-helper-messages \
    chrony

systemctl enable firewalld

sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/bootc update --quiet|' /usr/lib/systemd/system/bootc-fetch-apply-updates.service
sed -i 's|^OnUnitInactiveSec=.*|OnUnitInactiveSec=7d\nPersistent=true|' /usr/lib/systemd/system/bootc-fetch-apply-updates.timer
sed -i 's|#AutomaticUpdatePolicy.*|AutomaticUpdatePolicy=stage|' /etc/rpm-ostreed.conf
sed -i 's|#LockLayering.*|LockLayering=true|' /etc/rpm-ostreed.conf

systemctl enable bootc-fetch-apply-updates

tee /usr/lib/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram, 8192)
EOF

tee /usr/lib/systemd/system-preset/91-resolved-default.preset <<'EOF'
enable systemd-resolved.service
EOF
tee /usr/lib/tmpfiles.d/resolved-default.conf <<'EOF'
L /etc/resolv.conf - - - - ../run/systemd/resolve/stub-resolv.conf
EOF
systemctl preset systemd-resolved.service

dnf -y copr enable ublue-os/packages
dnf -y copr disable ublue-os/packages
dnf -y --enablerepo copr:copr.fedorainfracloud.org:ublue-os:packages install \
	ublue-brew \
	uupd \
	ublue-os-udev-rules
systemctl enable brew-setup.service
systemctl enable uupd.timer


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