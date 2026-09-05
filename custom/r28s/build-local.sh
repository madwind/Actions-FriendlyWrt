#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$ROOT_DIR/project}"

bash "$ROOT_DIR/custom/r28s/host.sh" sync all

cd "$PROJECT_DIR"
# shellcheck disable=SC1091
source "$ROOT_DIR/custom/r28s/config.sh"
bash "$ROOT_DIR/custom/r28s/artifacts.sh" write-config

# FriendlyElec reuses an existing .config and otherwise forces CONFIG_ALL_KMODS.
# Patch that default and regenerate .config from the customized rockchip config.
bash "$ROOT_DIR/custom/r28s/apply-patches.sh" friendlywrt
rm -f "$PROJECT_DIR/friendlywrt/.config"

# Let the official FriendlyElec build script prepare feeds and .config without
# compiling the OpenWrt tree yet. This also installs its expected toolchains.
DEBUG_DOT_CONFIG=1 ./build.sh friendlywrt

cd friendlywrt
make download -j8
find dl -size -1024c -exec rm -f {} \;
cd ..

# U-Boot is short and uses the same sd-fuse workspace as the kernel, so finish
# it first. Then compile kernel and FriendlyWrt in parallel.
./build.sh uboot

bash "$ROOT_DIR/custom/r28s/apply-patches.sh" kernel
# shellcheck disable=SC1091
source "$ROOT_DIR/custom/r28s/kernel-config.sh"

BUILD_THIRD_PARTY_DRIVER=0 ./build.sh kernel &
kernel_pid=$!
trap 'kill "$kernel_pid" 2>/dev/null || true' EXIT

cd friendlywrt
if ! make -j"$(nproc)"; then
    make -j1 V=s
fi
cd ..

wait "$kernel_pid"
trap - EXIT

# Apply only the final-image cleanup patch, then let FriendlyElec assemble the
# image through its unchanged build.sh entry point.
bash "$ROOT_DIR/custom/r28s/apply-patches.sh" image
SDFUSE_NONINTERACTIVE=1 ./build.sh sd-img

echo "Image: $PROJECT_DIR/out/R28S-Zero2-NEO3Plus-Series-FriendlyWrt-25.12.img.gz"
