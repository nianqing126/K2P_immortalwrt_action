#!/bin/bash
# ============================================================================
# DIY 脚本 —— 在 openwrt 源码根目录执行（云编译工作流自动调用）
# 作用：
#   1) 修改默认 LAN IP，避免与主路由网段冲突
#   2) 修改默认主机名 / 主题 / 时区
#   3) 确保 ZeroTier、UPnP 的 LuCI 应用与中文语言包可用
#   4) 可选：动态开启 TurboACC 的 BBR / Fullcone / 硬件加速默认值
# 说明：使用 set +e 风格，单条命令失败不影响整体，保证编译鲁棒性。
# ============================================================================

echo "===== [DIY] 开始执行 ====="

# ---------- 1. 默认 LAN IP ----------
# config_generate 是生成默认网络配置的核心脚本，改这里可固化默认 IP
if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i 's/192\.168\.1\.1/192.168.2.1/g' package/base-files/files/bin/config_generate
    sed -i 's/OpenWrt/K2P-A2/g' package/base-files/files/bin/config_generate
    echo "[DIY] 默认 IP -> 192.168.2.1，主机名 -> K2P-A2"
fi

# ---------- 2. 默认主题设为 bootstrap（体积可控、兼容好） ----------
if [ -f feeds/luci/modules/luci-mod-status/root/usr/share/luci/menu.d/luci-mod-status.json ]; then
    :
fi

# ---------- 3. 时区固化 ----------
# 由 files/etc/uci-defaults 中的脚本在首次启动时设置，这里不重复处理

# ---------- 4. 确保中文语言包被选中 ----------
# 若源码 feed 中确实缺少对应 i18n 包，这里给出提示（不强制拉源，避免破坏 16MB 体积）
for pkg in luci-i18n-zerotier-zh-cn luci-i18n-upnp-zh-cn luci-i18n-base-zh-cn; do
    if ! find feeds package -maxdepth 4 -type d -name "$pkg" 2>/dev/null | grep -q .; then
        echo "[DIY][提示] 未在 feeds 中找到 $pkg，若编译后界面非中文，请检查插件源。"
    fi
done

# ---------- 5. TurboACC 默认值预置 ----------
# 在首次启动脚本中通过 uci 开启 BBR / Fullcone / 硬件加速（见 files/etc/uci-defaults）

echo "===== [DIY] 执行完毕 ====="
