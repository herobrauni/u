#!/bin/bash

set -xeuo pipefail

### Additional packages and customizations

# Install additional useful packages including your current ones
dnf5 install -y \
    git \
    vim \
    curl \
    wget \
    htop \
    tree \
    jq \
    unzip \
    zip \
    fastfetch \
    fzf \
    bat

