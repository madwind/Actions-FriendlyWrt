# R28S FriendlyWrt

基于 FriendlyElec `Actions-FriendlyWrt` 的 NanoPi R28S 定制构建。

本仓库不再保留上游的通用固件配置，主要目标是：**减少无用组件、缩短重复构建时间，并保留 R28S 实际需要的功能。**

## 主要改动

### 精简 FriendlyWrt

- 基于 OpenWrt / FriendlyWrt `25.12`。
- 清除 FriendlyWrt 原有的大量显式软件包选择，改回接近 OpenWrt `rockchip/armv8` release 的基础用户空间。
- 保留 LuCI、网络、无线和系统管理所需的基础组件。
- 保留 R28S 所需的 Wi-Fi 支持。
- 禁用：
  - `CONFIG_ALL_KMODS`
  - `CONFIG_ALL_NONSHARED`
  - `CONFIG_BUILDBOT`
  - SDK
  - Image Builder
  - Toolchain 产物
- 不再预装 R28S 不需要的 `kmod-usb-net-rtl8152` 和 `r8152-firmware`。
- 将 FriendlyWrt 默认 root 密码恢复为空密码，首次登录后请自行设置密码。

### 精简内核构建

R28S 内核继续使用 FriendlyElec 官方源码和构建流程，只通过最小补丁移除不需要的额外构建：

- 不编译外置 `r8125` 驱动。
- 不编译 `cryptodev-linux`。
- 不编译额外的 `rtw88/8822ce` backport。
- 构建时关闭通用第三方 USB Wi-Fi 驱动批量编译。
- 保留 FriendlyElec 原有 R28S 内核配置和板级支持。
- 额外启用：
  - `CONFIG_NET_ACT_CT=m`
  - `CONFIG_NET_ACT_CTINFO=m`

### 更干净的最终镜像

FriendlyElec 在生成镜像时会临时使用本地 APK 软件仓库。本仓库在最终打包前删除：

- 镜像内的本地 APK 软件包仓库。
- `/etc/apk/repositories.d/local.list`。

这些内容只在构建阶段使用，不再占用最终固件空间。

### 不生成升级包

Release 只发布最终可直接写盘的：

```text
R28S-Zero2-NEO3Plus-Series-FriendlyWrt-25.12.img.gz
```

不再生成或发布额外的 `images-*.tgz` 升级包。

## GitHub Actions 构建优化

构建流程拆分为多个独立任务：

- FriendlyWrt
- U-Boot
- Kernel
- Image

FriendlyWrt、U-Boot 和 Kernel 可以分别完成后，再由 Image Job 汇总产物生成最终镜像，避免所有步骤串行执行。

同时启用两类 GitHub Actions 缓存：

- `friendlywrt/dl`：缓存 OpenWrt 下载文件。
- `friendlywrt/.ccache`：缓存编译器输出。

OpenWrt 配置中同时启用 `CONFIG_CCACHE=y`，因此修改少量配置后重新构建时可以复用之前的大量编译结果。

## GitHub Actions 构建

打开：

```text
Actions -> Build FriendlyWrt -> Run workflow
```

构建完成后，最终的 `.img.gz` 会直接上传到当天创建的 GitHub Release。

## 本地构建

仓库提供本地构建脚本：

```sh
bash custom/r28s/build-local.sh
```

脚本仍然调用 FriendlyElec 官方 `build.sh`，只在必要位置应用 R28S 定制配置和补丁。

主要流程：

1. 同步 FriendlyElec 源码。
2. 应用精简后的 FriendlyWrt 配置。
3. 下载软件包源码。
4. 编译 U-Boot。
5. Kernel 与 FriendlyWrt 并行编译。
6. 使用官方 `sd-img` 流程生成最终镜像。

## R28S 性能调优

`r28s-tune` 不再直接集成进固件，改为可选安装脚本。需要时在 R28S 上执行：

```sh
wget -qO- https://raw.githubusercontent.com/madwind/Actions-FriendlyWrt/master/custom/r28s/install-tune.sh | sh
```

安装脚本会自动安装 `ethtool`（如果系统尚未安装），并创建开机及接口上线自动执行的调优脚本。

当前调优内容包括：

- 关闭 OpenWrt `packet_steering`。
- 将 IRQ 48 绑定到 CPU1。
- 设置 `eth0` / `eth1` RPS CPU mask。
- 关闭 RFS flow table。
- 为 `eth1` 启用 SG / TSO / GSO。
- 如果内核提供 `tcp_bbr`，自动加载并切换 TCP 拥塞控制为 BBR。

安装后也可以手动重新应用：

```sh
/usr/sbin/r28s-tune
```

## 目录

```text
custom/r28s/
├── config.sh                 FriendlyWrt 软件包和构建配置
├── kernel-config.sh          R28S 内核配置增量
├── host.sh                   CI / 本地构建环境与源码同步
├── artifacts.sh              多 Job 构建产物打包和组装
├── build-local.sh            本地构建入口
├── install-tune.sh           R28S 可选运行时性能调优
├── apply-patches.sh          应用最小化补丁
└── patches/
    ├── friendlywrt-config.patch
    ├── kernel-drivers.patch
    └── image-local-repo.patch
```

## 上游

本项目基于 FriendlyElec 官方项目：

- https://github.com/friendlyarm/Actions-FriendlyWrt

FriendlyElec 的原始 `build.sh`、内核和镜像构建流程仍作为主要构建基础，本仓库只维护 R28S 所需的定制差异。
