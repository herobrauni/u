#!/bin/bash

set -xeuo pipefail

dnf -y copr enable yalter/niri-git
dnf -y copr disable yalter/niri-git
echo "priority=1" | sudo tee -a /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:yalter:niri-git.repo
dnf -y --enablerepo copr:copr.fedorainfracloud.org:yalter:niri-git install niri

# dnf -y copr enable errornointernet/quickshell
# dnf -y copr disable errornointernet/quickshell
# dnf -y --enablerepo copr:copr.fedorainfracloud.org:errornointernet:quickshell install quickshell

# dnf -y copr enable scottames/ghostty
# dnf -y copr disable scottames/ghostty
# dnf -y --enablerepo copr:copr.fedorainfracloud.org:scottames:ghostty install ghostty

dnf -y install \
    brightnessctl \
    chezmoi \
    ddcutil \
    fastfetch \
    flatpak \
    fpaste \
    fzf \
    git-core \
    gnome-keyring \
    greetd \
    greetd-selinux \
    just \
    nautilus \
    orca \
    pipewire \
    tuigreet \
    udiskie \
    wireplumber \
    wl-clipboard \
    wlsunset \
    xdg-desktop-portal-gnome \
    xdg-user-dirs \
    xwayland-satellite

dnf -y copr enable avengemedia/danklinux
dnf -y copr disable avengemedia/danklinux
dnf -y --enablerepo copr:copr.fedorainfracloud.org:avengemedia:danklinux install dgop  material-symbols-fonts cliphist  quickshell-git matugen ghostty

dnf -y copr enable avengemedia/dms-git
dnf -y copr disable avengemedia/dms-git
dnf -y --enablerepo copr:copr.fedorainfracloud.org:avengemedia:dms-git install dms


sed -i '/gnome_keyring.so/ s/-auth/auth/ ; /gnome_keyring.so/ s/-session/session/' /etc/pam.d/greetd
cat /etc/pam.d/greetd

dnf install -y --setopt=install_weak_deps=False \
    kf6-kirigami \
    polkit-kde

sed -i "s/After=.*/After=graphical-session.target/" /usr/lib/systemd/user/plasma-polkit-agent.service

systemctl enable greetd
systemctl enable firewalld

# Sacrificed to the :steamhappy: emoji old god
dnf install -y \
    default-fonts-core-emoji \
    google-noto-fonts-all \
    google-noto-color-emoji-fonts \
    google-noto-emoji-fonts \
    glibc-all-langpacks

cp -avf "/ctx/system_files"/. /
