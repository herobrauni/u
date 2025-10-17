# Build Arguments for NVIDIA control
ARG NVIDIA_SUPPORT="false"
ARG BASE_IMAGE_NAME="base"
ARG IMAGE_TAG="43"

# Determine base image and image name based on NVIDIA support
ARG BASE_IMAGE="ghcr.io/ublue-os/${BASE_IMAGE_NAME}-main"
ARG IMAGE_NAME="${BASE_IMAGE_NAME}"

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files

# Base Image - always start from base-main
FROM ${BASE_IMAGE}:${IMAGE_TAG}

ARG BASE_IMAGE_NAME="base"
ARG IMAGE_TAG="latest"
ARG IMAGE_NAME="${BASE_IMAGE_NAME}"
ARG NVIDIA_SUPPORT="false"

### MODIFICATIONS - Modular build approach like zirconium

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    NVIDIA_SUPPORT="${NVIDIA_SUPPORT}" IMAGE_NAME="${IMAGE_NAME}" /ctx/build_files/00-base.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/01-niri.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/99-cleanup.sh

### LINTING
## Verify final image and contents are correct.
RUN rm -rf /var/* && bootc container lint