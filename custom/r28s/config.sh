#!/bin/bash
set -euo pipefail

ROCKCHIP_CONFIG_DIR="configs/rockchip"
BASE_CONFIG="$ROCKCHIP_CONFIG_DIR/01-nanopi"
CUSTOM_CONFIG="$ROCKCHIP_CONFIG_DIR/03-custom"
SHADOW_FILE="friendlywrt/package/base-files/files/etc/shadow"

[ -f "$BASE_CONFIG" ] || { echo "Missing $BASE_CONFIG" >&2; exit 1; }
[ -f "$CUSTOM_CONFIG" ] || { echo "Missing $CUSTOM_CONFIG" >&2; exit 1; }
[ -f "$SHADOW_FILE" ] || { echo "Missing $SHADOW_FILE" >&2; exit 1; }

VERSION_NUMBER="$(sed -n 's/^CONFIG_VERSION_NUMBER="\([^"]*\)"/\1/p' "$CUSTOM_CONFIG" | head -n1)"
case "$VERSION_NUMBER" in
    25.12*) ;;
    *)
        echo "Unsupported FriendlyWrt version: ${VERSION_NUMBER:-unknown}" >&2
        exit 1
        ;;
esac

# Match OpenWrt's default empty root password instead of FriendlyWrt's preset.
sed -i 's#^root:[^:]*:#root::#' "$SHADOW_FILE"

# Do not generate development artifacts that are not needed for firmware builds.
sed -i -e '/CONFIG_MAKE_TOOLCHAIN=y/d' "$BASE_CONFIG"
sed -i -e 's/CONFIG_IB=y/# CONFIG_IB is not set/g' "$BASE_CONFIG"
sed -i -e 's/CONFIG_SDK=y/# CONFIG_SDK is not set/g' "$BASE_CONFIG"

# Remove FriendlyWrt's explicit package selections and broad buildbot defaults,
# then restore the OpenWrt 25.12 rockchip/armv8 release user-space set plus the
# R28S Wi-Fi requirements.
for config in "$ROCKCHIP_CONFIG_DIR"/*; do
    [ -f "$config" ] || continue
    sed -i -E \
        -e '/^(# )?CONFIG_PACKAGE_/d' \
        -e '/^(# )?CONFIG_(ALL_KMODS|ALL_NONSHARED|BUILDBOT)(=| is not set)/d' \
        -e '/^(# )?CONFIG_CCACHE(=| is not set)/d' \
        -e '/^CONFIG_CCACHE_DIR=/d' \
        -e '/^CONFIG_LUCI_LANG_/d' \
        -e '/^CONFIG_BUSYBOX_CUSTOM=/d' \
        -e '/^CONFIG_BUSYBOX_CONFIG_/d' \
        -e '/^CONFIG_(ARIA2|BIND|BTRFS_PROGS|COREMARK|GNUTLS|LIBCURL|LIBQMI|LIBSSH2|OPENSSL|TAR)_/d' \
        -e '/^CONFIG_IPTABLES_CONNLABEL=/d' \
        "$config"
done

cat >> "$BASE_CONFIG" <<'EOF'

# Build only packages needed by the selected firmware instead of all target
# kernel modules and target-specific packages.
# CONFIG_ALL_KMODS is not set
# CONFIG_ALL_NONSHARED is not set
# CONFIG_BUILDBOT is not set

# Reuse compiler outputs between incremental local and CI builds.
CONFIG_CCACHE=y

# The R28S board uses RTL8111H and RTL8211F Ethernet, not an RTL8152 USB NIC.
# CONFIG_PACKAGE_kmod-usb-net-rtl8152 is not set
# CONFIG_PACKAGE_r8152-firmware is not set

# OpenWrt 25.12 rockchip/armv8 release user-space package set.
CONFIG_PACKAGE_cgi-io=y
CONFIG_DRIVER_11AC_SUPPORT=y
CONFIG_DRIVER_11AX_SUPPORT=y
CONFIG_PACKAGE_iw=y
CONFIG_PACKAGE_libiwinfo=y
CONFIG_PACKAGE_libiwinfo-data=y
CONFIG_PACKAGE_liblucihttp=y
CONFIG_PACKAGE_liblucihttp-ucode=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-app-firewall=y
CONFIG_PACKAGE_luci-app-package-manager=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-lib-uqr=y
CONFIG_PACKAGE_luci-light=y
CONFIG_PACKAGE_luci-mod-admin-full=y
CONFIG_PACKAGE_luci-mod-network=y
CONFIG_PACKAGE_luci-mod-status=y
CONFIG_PACKAGE_luci-mod-system=y
CONFIG_PACKAGE_luci-proto-ipv6=y
CONFIG_PACKAGE_luci-proto-ppp=y
CONFIG_PACKAGE_luci-ssl=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_px5g-mbedtls=y
CONFIG_PACKAGE_rpcd=y
CONFIG_PACKAGE_rpcd-mod-file=y
CONFIG_PACKAGE_rpcd-mod-iwinfo=y
CONFIG_PACKAGE_rpcd-mod-luci=y
CONFIG_PACKAGE_rpcd-mod-rpcsys=y
CONFIG_PACKAGE_rpcd-mod-rrdns=y
CONFIG_PACKAGE_rpcd-mod-ucode=y
CONFIG_PACKAGE_ucode-mod-html=y
CONFIG_PACKAGE_ucode-mod-log=y
CONFIG_PACKAGE_ucode-mod-math=y
CONFIG_PACKAGE_ucode-mod-uclient=y
CONFIG_PACKAGE_uhttpd=y
CONFIG_PACKAGE_uhttpd-mod-ubus=y
CONFIG_PACKAGE_wifi-scripts=y
CONFIG_PACKAGE_wireless-regdb=y
CONFIG_PACKAGE_wpad-basic-mbedtls=y
CONFIG_WIFI_SCRIPTS_UCODE=y
EOF
