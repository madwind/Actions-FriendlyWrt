#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$ROOT_DIR/project}"
PATCH_DIR="$ROOT_DIR/custom/r28s/patches"

apply_patch() {
    local repo_dir="$1"
    local patch_file="$2"

    if git -C "$repo_dir" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
        echo "Already applied: $(basename "$patch_file")"
        return
    fi

    git -C "$repo_dir" apply --check "$patch_file"
    git -C "$repo_dir" apply "$patch_file"
    echo "Applied: $(basename "$patch_file")"
}

case "${1:-}" in
    friendlywrt)
        apply_patch "$PROJECT_DIR/scripts" "$PATCH_DIR/friendlywrt-config.patch"
        ;;
    kernel)
        apply_patch "$PROJECT_DIR/scripts/sd-fuse" "$PATCH_DIR/kernel-drivers.patch"
        ;;
    all)
        apply_patch "$PROJECT_DIR/scripts" "$PATCH_DIR/friendlywrt-config.patch"
        apply_patch "$PROJECT_DIR/scripts/sd-fuse" "$PATCH_DIR/kernel-drivers.patch"
        ;;
    *)
        echo "Usage: $0 friendlywrt|kernel|all" >&2
        exit 1
        ;;
esac
