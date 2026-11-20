#!/bin/bash
# ============================================================================
# ImmortalWrt DIY 脚本 —— 在 openwrt 源码根目录执行（云编译工作流自动调用）
# 作用：
#   1) 修改默认 LAN IP / 主机名，避免与主路由网段冲突
#   2) 检查 ZeroTier/UPnP 中文语言包是否齐全
#   3) 提示：Fullcone/硬件加速/BBR 由首次启动脚本通过 firewall4 UCI 开启
# 说明：ImmortalWrt 25.12 原生集成 fullconenat-nft，无需打第三方补丁。
# ============================================================================

echo "===== [DIY-ImmortalWrt] 开始执行 ====="

# ---------- 1. 默认 LAN IP / 主机名 ----------
if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i 's/192\.168\.1\.1/192.168.2.1/g' package/base-files/files/bin/config_generate
    sed -i 's/OpenWrt/K2P-A2/g' package/base-files/files/bin/config_generate
    echo "[DIY] 默认 IP -> 192.168.2.1，主机名 -> K2P-A2"
fi

# ---------- 2. 中文语言包检查 ----------
for pkg in luci-i18n-zerotier-zh-cn luci-i18n-upnp-zh-cn luci-i18n-base-zh-cn; do
    if ! find feeds package -maxdepth 5 -type d -name "$pkg" 2>/dev/null | grep -q .; then
        echo "[DIY][提示] 未在 feeds 中找到 $pkg，编译后若非中文请在 menuconfig 补选。"
    fi
done

# ---------- 3. Fullcone / flow offload 依赖确认 ----------
# ImmortalWrt 源已包含 fullconenat-nft 与 nft-fullcone；此处仅提示，不强制拉取。
echo "[DIY] Fullcone 使用官方 kmod-nft-fullcone，硬件加速使用 kmod-nft-offload (MT7621 PPE)"
echo "[DIY] 首次启动脚本将设置: firewall.@defaults[0].fullcone=1 / flow_offloading=1 / flow_offloading_hw=1"

echo "===== [DIY-ImmortalWrt] 执行完毕 ====="
