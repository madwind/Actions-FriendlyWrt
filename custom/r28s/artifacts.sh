#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$ROOT_DIR/project}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$ROOT_DIR/artifact}"
DOWNLOADS_DIR="${DOWNLOADS_DIR:-$ROOT_DIR/downloads}"
VERSION="${VERSION:-25.12}"
MODEL="${MODEL:-R28S-Zero2-NEO3Plus-Series}"
DIST_DIR="friendlywrt${VERSION%%.*}"
IMG_FILE="${MODEL}-FriendlyWrt-${VERSION}.img"

write_config() {
    cat > "$PROJECT_DIR/.current_config.mk" <<EOF
. device/friendlyelec/rk3528/base.mk
TARGET_IMAGE_DIRNAME=${DIST_DIR}
TARGET_FRIENDLYWRT_CONFIG=rockchip
TARGET_SD_RAW_FILENAME=${IMG_FILE}
EOF
}

package_friendlywrt() {
    mkdir -p "$ARTIFACT_DIR"
    cd "$PROJECT_DIR"
    # shellcheck disable=SC1091
    source .current_config.mk

    tar czf "$ARTIFACT_DIR/rootfs-friendlywrt-${VERSION}.tgz" \
        "${FRIENDLYWRT_SRC}/${FRIENDLYWRT_ROOTFS}" \
        "${FRIENDLYWRT_SRC}/${FRIENDLYWRT_PACKAGE_DIR}"

    local pm_bin=""
    [ -f "${FRIENDLYWRT_SRC}/staging_dir/host/bin/apk" ] && pm_bin="${FRIENDLYWRT_SRC}/staging_dir/host/bin/apk"
    [ -f "${FRIENDLYWRT_SRC}/staging_dir/host/bin/opkg" ] && pm_bin="${FRIENDLYWRT_SRC}/staging_dir/host/bin/opkg"
    [ -n "$pm_bin" ] || { echo "Neither apk nor opkg was built" >&2; exit 1; }

    tar czf "$ARTIFACT_DIR/host-pm-${VERSION}.tgz" "$pm_bin"
}

package_uboot() {
    mkdir -p "$ARTIFACT_DIR/uboot"
    cd "$PROJECT_DIR"

    test -f u-boot/uboot.img
    local loader
    loader="$(find u-boot -maxdepth 1 -type f \( -name 'rk3528_spl_loader_*.bin' -o -name 'rk3528_loader_*.bin' \) | sort -V | tail -1)"
    [ -n "$loader" ] || { echo "R28S U-Boot loader was not generated" >&2; exit 1; }

    cp u-boot/uboot.img "$ARTIFACT_DIR/uboot/"
    cp "$loader" "$ARTIFACT_DIR/uboot/"
}

package_kernel() {
    mkdir -p "$ARTIFACT_DIR/kernel"
    cd "$PROJECT_DIR"

    test -f kernel/kernel.img
    test -f kernel/resource.img
    test -d scripts/sd-fuse/out/output_rk3528_kmodules

    cp kernel/kernel.img kernel/resource.img "$ARTIFACT_DIR/kernel/"
    cp -a scripts/sd-fuse/out/output_rk3528_kmodules "$ARTIFACT_DIR/kernel/"
}

install_products() {
    cd "$PROJECT_DIR"

    tar xzf "$DOWNLOADS_DIR/friendlywrt/rootfs-friendlywrt-${VERSION}.tgz"
    tar xzf "$DOWNLOADS_DIR/friendlywrt/host-pm-${VERSION}.tgz"

    mkdir -p u-boot kernel scripts/sd-fuse/out

    test -f "$DOWNLOADS_DIR/uboot/uboot.img"
    local loader
    loader="$(find "$DOWNLOADS_DIR/uboot" -maxdepth 1 -type f \( -name 'rk3528_spl_loader_*.bin' -o -name 'rk3528_loader_*.bin' \) | sort -V | tail -1)"
    [ -n "$loader" ] || { echo "R28S U-Boot loader is missing" >&2; exit 1; }
    cp "$DOWNLOADS_DIR/uboot/uboot.img" u-boot/
    cp "$loader" u-boot/

    test -f "$DOWNLOADS_DIR/kernel/kernel.img"
    test -f "$DOWNLOADS_DIR/kernel/resource.img"
    test -d "$DOWNLOADS_DIR/kernel/output_rk3528_kmodules"
    cp "$DOWNLOADS_DIR/kernel/kernel.img" "$DOWNLOADS_DIR/kernel/resource.img" kernel/
    rm -rf scripts/sd-fuse/out/output_rk3528_kmodules
    cp -a "$DOWNLOADS_DIR/kernel/output_rk3528_kmodules" scripts/sd-fuse/out/
}

collect_image() {
    mkdir -p "$ARTIFACT_DIR"
    cd "$PROJECT_DIR"
    test -f "out/$IMG_FILE"
    mv "out/$IMG_FILE" "$ARTIFACT_DIR/"
    gzip -f "$ARTIFACT_DIR/$IMG_FILE"
    echo "$ARTIFACT_DIR/$IMG_FILE.gz"
}

case "${1:-}" in
    write-config) write_config ;;
    package-friendlywrt) package_friendlywrt ;;
    package-uboot) package_uboot ;;
    package-kernel) package_kernel ;;
    install-products) install_products ;;
    collect-image) collect_image ;;
    *)
        echo "Usage: $0 write-config|package-friendlywrt|package-uboot|package-kernel|install-products|collect-image" >&2
        exit 1
        ;;
esac
