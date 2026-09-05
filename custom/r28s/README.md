# R28S custom helpers

This directory contains all repository-specific R28S customizations.

- `config.sh`: R28S/OpenWrt user-space configuration applied before the FriendlyWrt build.
- `kernel-config.sh`: the small R28S-specific kernel config delta.
- `host.sh`: host environment and manifest sync helpers for CI and local WSL builds.
- `artifacts.sh`: transfers build products between parallel CI jobs without changing FriendlyElec build scripts.
- `apply-patches.sh`: checks and applies the minimal patches under `patches/` to the checked-out FriendlyElec worktree.
- `patches/kernel-drivers.patch`: skips R28S-unneeded r8125, cryptodev-linux and rtw88 builds; generic USB Wi-Fi modules are disabled with `BUILD_THIRD_PARTY_DRIVER=0`.
- `build-local.sh`: local WSL build helper; it uses the official `build.sh` entry points and only overlaps kernel and FriendlyWrt compilation.
- `install-tune.sh`: optional runtime tuning installer for an already running R28S system.

FriendlyElec's embedded local APK repository is intentionally kept in the final image so packages built for the exact firmware and kernel ABI, especially optional `kmod-*` packages, remain installable after flashing.

FriendlyElec's checked-out `build.sh`, `scripts/sd-fuse/build-kernel.sh`, and other upstream build scripts are not maintained as forked copies here. The minimal R28S deltas are kept as explicit patches so an upstream conflict fails at `git apply --check` instead of being silently rewritten.
