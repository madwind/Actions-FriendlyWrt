#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$ROOT_DIR/project}"
VERSION="${VERSION:-25.12}"

setup_host() {
    local tmp
    tmp="$(mktemp -d)"

    if [ "${CI:-}" = "true" ]; then
        sudo rm -rf /etc/apt/sources.list.d
    fi

    wget -q https://raw.githubusercontent.com/friendlyarm/build-env-on-ubuntu-bionic/master/install.sh -O "$tmp/install.sh"
    sed -i \
        -e 's/^apt-get -y install openjdk-8-jdk/# apt-get -y install openjdk-8-jdk/g' \
        -e 's/^\[ -d fa-toolchain \]/# [ -d fa-toolchain ]/g' \
        -e 's/^(cat fa-toolchain/# (cat fa-toolchain/g' \
        -e 's/^(tar xf fa-toolchain/# (tar xf fa-toolchain/g' \
        "$tmp/install.sh"
    sudo -E DEBIAN_FRONTEND=noninteractive bash "$tmp/install.sh"

    if [ "${CI:-}" = "true" ]; then
        git config --global user.name 'GitHub Actions'
        git config --global user.email 'noreply@github.com'
        git config --global color.ui false
    fi

    curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "$tmp/repo"
    chmod 0755 "$tmp/repo"
    sudo install -m 0755 "$tmp/repo" /usr/local/bin/repo

    if [ "${CI:-}" = "true" ]; then
        sudo swapoff -a || true
        sudo rm -rf /usr/share/dotnet /usr/local/lib/android/sdk /usr/local/share/boost /opt/ghc 2>/dev/null || true
    fi

    rm -rf "$tmp"
    echo "cores: $(nproc)"
}

check_git_identity() {
    if ! git config --global user.name >/dev/null || ! git config --global user.email >/dev/null; then
        cat >&2 <<'EOF'
Git identity is required by repo. Configure it once, for example:
  git config --global user.name "madwind"
  git config --global user.email "you@example.com"
EOF
        exit 1
    fi
}

sync_source() {
    local target="${1:-all}"
    local projects=()

    check_git_identity
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"

    if [ -d .repo ]; then
        repo forall -c 'git reset --hard HEAD' >/dev/null
    fi

    repo init --depth=1 \
        -u https://github.com/friendlyarm/friendlywrt_manifests \
        -b "master-v${VERSION}" \
        -m rk3528.xml \
        --no-clone-bundle

    case "$target" in
        friendlywrt)
            projects=(friendlywrt configs device/common device/friendlyelec scripts scripts/sd-fuse toolchain)
            ;;
        uboot)
            projects=(u-boot rkbin configs device/common device/friendlyelec scripts scripts/sd-fuse toolchain)
            ;;
        kernel)
            projects=(kernel configs device/common device/friendlyelec scripts scripts/sd-fuse toolchain)
            ;;
        image)
            projects=(configs device/common device/friendlyelec scripts scripts/sd-fuse toolchain)
            ;;
        all)
            projects=(friendlywrt kernel u-boot rkbin configs device/common device/friendlyelec scripts scripts/sd-fuse toolchain)
            ;;
        *)
            echo "Unknown sync target: $target" >&2
            exit 1
            ;;
    esac

    repo sync -c -j"$(nproc)" "${projects[@]}" --no-clone-bundle
}

case "${1:-}" in
    setup) setup_host ;;
    sync) shift; sync_source "${1:-all}" ;;
    *)
        echo "Usage: $0 setup | sync [friendlywrt|uboot|kernel|image|all]" >&2
        exit 1
        ;;
esac
