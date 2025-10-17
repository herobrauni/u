# Build Arguments for NVIDIA control
ARG NVIDIA_SUPPORT="false"
ARG BASE_IMAGE_NAME="base"
ARG IMAGE_TAG="latest"

# Determine base image and image name based on NVIDIA support
ARG BASE_IMAGE="ghcr.io/ublue-os/${BASE_IMAGE_NAME}-main"
ARG IMAGE_NAME="${BASE_IMAGE_NAME}"

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image - always start from base-main
FROM ${BASE_IMAGE}:${IMAGE_TAG}

ARG BASE_IMAGE_NAME="base"
ARG IMAGE_TAG="latest"
ARG IMAGE_NAME="${BASE_IMAGE_NAME}"
ARG NVIDIA_SUPPORT="false"

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    NVIDIA_SUPPORT="${NVIDIA_SUPPORT}" IMAGE_NAME="${IMAGE_NAME}" /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
