#!/bin/bash
set -euo pipefail

ROCKCHIP_CONFIG_DIR="configs/rockchip"
BASE_CONFIG="$ROCKCHIP_CONFIG_DIR/01-nanopi"
CUSTOM_CONFIG="$ROCKCHIP_CONFIG_DIR/03-custom"

[ -f "$BASE_CONFIG" ] || { echo "Missing $BASE_CONFIG" >&2; exit 1; }
[ -f "$CUSTOM_CONFIG" ] || { echo "Missing $CUSTOM_CONFIG" >&2; exit 1; }

VERSION_NUMBER="$(sed -n 's/^CONFIG_VERSION_NUMBER="\([^"]*\)"/\1/p' "$CUSTOM_CONFIG" | head -n1)"
case "$VERSION_NUMBER" in
    25.12*) ;;
    *)
        echo "Unsupported FriendlyWrt version: ${VERSION_NUMBER:-unknown}" >&2
        exit 1
        ;;
esac

# Do not generate development artifacts that are not needed for firmware builds.
sed -i -e '/CONFIG_MAKE_TOOLCHAIN=y/d' "$BASE_CONFIG"
sed -i -e 's/CONFIG_IB=y/# CONFIG_IB is not set/g' "$BASE_CONFIG"
sed -i -e 's/CONFIG_SDK=y/# CONFIG_SDK is not set/g' "$BASE_CONFIG"

# FriendlyWrt explicitly selects a large user-space package set. Remove all of
# those selections and let OpenWrt restore target/device defaults through
# defconfig. FriendlyElec's kernel modules are injected later by the image
# assembly step, so they do not need to be selected here as OpenWrt packages.
# Also drop FriendlyWrt's all-language LuCI selection and package-specific
# feature tuning so base packages use upstream OpenWrt defaults.
for config in "$ROCKCHIP_CONFIG_DIR"/*; do
    [ -f "$config" ] || continue
    sed -i -E \
        -e '/^(# )?CONFIG_PACKAGE_/d' \
        -e '/^CONFIG_LUCI_LANG_/d' \
        -e '/^CONFIG_BUSYBOX_CUSTOM=/d' \
        -e '/^CONFIG_BUSYBOX_CONFIG_/d' \
        -e '/^CONFIG_(ARIA2|BIND|BTRFS_PROGS|COREMARK|GNUTLS|LIBCURL|LIBQMI|LIBSSH2|OPENSSL|TAR)_/d' \
        -e '/^CONFIG_IPTABLES_CONNLABEL=/d' \
        "$config"
done

# Restore the OpenWrt 25.12 rockchip/armv8 release user-space package set.
# Normal router packages such as dnsmasq, firewall4, nftables, odhcp6c and PPP
# come from OpenWrt target/device defaults and are intentionally not duplicated
# here. ethtool is the only extra user-space package, required by R28S tuning.
cat >> "$BASE_CONFIG" <<'EOF'

# OpenWrt 25.12 rockchip/armv8 release user-space package set.
CONFIG_PACKAGE_attendedsysupgrade-common=y
CONFIG_PACKAGE_cgi-io=y
CONFIG_PACKAGE_ethtool=y
CONFIG_PACKAGE_libiwinfo=y
CONFIG_PACKAGE_libiwinfo-data=y
CONFIG_PACKAGE_liblucihttp=y
CONFIG_PACKAGE_liblucihttp-ucode=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-app-attendedsysupgrade=y
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
CONFIG_PACKAGE_owut=y
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
EOF
