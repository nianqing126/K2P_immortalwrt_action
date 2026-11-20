# 斐讯 K2P A2 云编译项目（16MB 原厂闪存）

开箱即用的 GitHub Actions 云编译项目，专为**斐讯 K2P A2**（MT7621 + MT7615，128MB 内存，**16MB 未改闪存**）定制。提供**三个完全独立的工作流**：

| 方案 | 工作流 | 源码 / 内核 |
| --- | --- | --- |
| LEDE | `build-lean.yml` | coolsnowwolf/lede · 较旧内核 |
| **ImmortalWrt 25.12** | `build-immortalwrt-25.12.yml` | openwrt-25.12 · **内核 6.12**（当前稳定） |
| **ImmortalWrt 24.10** | `build-immortalwrt-24.10.yml` | openwrt-24.10 · **内核 6.6** |

> 24.10 与 25.12 **分成两个独立 yml 分别产出固件**，互不干扰，无需在运行时选分支。想用新内核选 25.12，想要更成熟的 6.6 内核选 24.10。

三个方案都集成以下功能，且**管理页均为中文**：

| 功能 | LEDE 方案 | ImmortalWrt 方案（24.10 / 25.12） |
| --- | --- | --- |
| **ZeroTier** | `luci-app-zerotier` + 中文包 | `luci-app-zerotier` + 中文包 |
| **UPnP** | `luci-app-upnp` + 中文包 | `luci-app-upnp` + 中文包 |
| **硬件加速** | TurboACC `hw_flow` + Shortcut FE | `kmod-nft-offload`（MT7621 PPE 硬件流卸载） |
| **BBR** | TurboACC `bbr_cca` | `kmod-tcp-bbr` + 内核参数 |
| **Fullcone NAT** | TurboACC `fullcone_nat` | 官方 `kmod-nft-fullcone` + `fullconenat-nft` |

---

## ⚠️ 16MB 闪存的重要约束

> K2P 固件分区中 firmware 上限为 **`15744 KiB`（约 15.4MB）**，这是分区表决定的硬限制。三个方案都已核实该值。
>
> - 已针对该限制精简：不编译 initramfs、不启用大主题、不开 IPv6 全家桶。
> - 三个工作流编译后都**自动校验固件大小**，超过 15744 KiB 直接报错中止。
> - 若自行添加大型插件导致超限，请删减后重编译。
>
> **务必确认是 16MB 原厂闪存且未改分区**。若已改 32MB 或刷 Breed 改分区表，需自行调大 `IMAGE_SIZE`。

---

## 🚀 快速开始

### 第 1 步：Fork + 开启 Actions

Fork 本仓库 → 进入 **`Actions`** 标签页 → 启用工作流。

### 第 2 步：选择工作流并运行

在左侧工作流列表中选择：

| 想编译 | 选择的工作流 | 产物名前缀 |
| --- | --- | --- |
| LEDE | `编译 K2P A2 固件 - LEDE 方案` | `k2p-a2-firmware-` |
| ImmortalWrt 25.12（内核6.12） | `编译 K2P A2 固件 - ImmortalWrt 25.12 (内核6.12)` | `k2p-a2-immortalwrt-25.12-` |
| ImmortalWrt 24.10（内核6.6） | `编译 K2P A2 固件 - ImmortalWrt 24.10 (内核6.6)` | `k2p-a2-immortalwrt-24.10-` |

点击 **`Run workflow`**，可选参数：
- `debug`：失败后开远程调试（默认 `false`）；
- `release`：成功后发布 Release（默认 `false`）。

编译约 **1.5~3 小时**。完成后在本次运行页面底部 **`Artifacts`** 下载对应前缀的压缩包，解压得到：

- `*-sysupgrade.bin`（固件内升级 / Breed 刷入）
- `*-factory.bin`（原厂升级）

因三个工作流产物前缀不同（见上表），同时存在也不会混淆。

---

## 📁 项目结构（三方案完全独立）

```
k2p-a2-builder/
├── .github/workflows/
│   ├── build-lean.yml                    # LEDE 方案
│   ├── build-immortalwrt-25.12.yml       # ImmortalWrt 25.12 / 内核 6.12
│   └── build-immortalwrt-24.10.yml       # ImmortalWrt 24.10 / 内核 6.6
├── configs/
│   ├── k2p-a2-lean.config                # LEDE 配置
│   └── k2p-a2-immortalwrt.config         # ImmortalWrt 配置（两版本共用，包兼容）
├── scripts/
│   ├── diy-lean.sh                       # LEDE DIY
│   └── diy-immortalwrt.sh                # ImmortalWrt DIY（两版本共用）
├── files-lean/                           # LEDE 首次启动脚本 (firewall3/TurboACC)
│   └── etc/
│       ├── uci-defaults/99-k2p-a2-init-lede      # LEDE 首次启动脚本
│       └── sysctl.d/99-bbr-lede.conf             # LEDE BBR 内核参数
├── files-immortalwrt/                    # ImmortalWrt 首次启动脚本 (firewall4)
│   └── etc/
│       ├── uci-defaults/99-k2p-a2-init-immortalwrt  # ImmortalWrt 首次启动脚本
│       └── sysctl.d/99-bbr-immortalwrt.conf         # ImmortalWrt BBR 内核参数
├── .gitignore
└── README.md
```

> 24.10 与 25.12 的 yml 各自固定分支、独立产出；功能配置与首次启动脚本因两版本包兼容而共用（fullconenat-nft / nft-fullcone / nft-offload / tcp-bbr 在两个分支都存在）。如需针对某版本单独定制，复制一份 config 并在对应 yml 里改 `CONFIG_FILE` 即可。

---

## ⚙️ 自定义编译

改完对应方案的文件，推送到 `main` 会自动触发该方案重新编译。

**改分支**：编辑对应 yml 顶部的 `REPO_BRANCH`（25.12 固定 `openwrt-25.12`，24.10 固定 `openwrt-24.10`）。

**增删插件**：编辑 `configs/k2p-a2-lean.config` 或 `configs/k2p-a2-immortalwrt.config`，按 `CONFIG_PACKAGE_xxx=y` 格式增删。

**改默认 IP / 主机名**：编辑 `scripts/diy-*.sh` 第 1 部分，默认 LAN IP `192.168.2.1`、主机名 `K2P-A2`。

**调加速开关**：编辑对应方案的首次启动脚本（文件名已带方案名，不会混淆）。
- LEDE：`files-lean/etc/uci-defaults/99-k2p-a2-init-lede`，设置 `turboacc.config.*` 开关；
- ImmortalWrt：`files-immortalwrt/etc/uci-defaults/99-k2p-a2-init-immortalwrt`，设置 `firewall.@defaults[0]` 的 `fullcone` / `flow_offloading` / `flow_offloading_hw`。

> 各方案文件命名对照：`99-k2p-a2-init-lede` ↔ `99-k2p-a2-init-immortalwrt`、`99-bbr-lede.conf` ↔ `99-bbr-immortalwrt.conf`。

---

## 🔧 刷机说明（K2P A2）

1. **先备份**：备份原厂固件与 EEPROM（无线校准数据）。
2. **推荐 Breed**：刷入 Breed 引导后，在 Breed 中"固件更新"刷入 `sysupgrade.bin`，分区选**公版布局**。
3. 从原厂固件直接升级用 `factory.bin`。
4. 首次开机等待 **3~5 分钟** 完成初始化（自动设置中文 / BBR / Fullcone / 硬件加速）。
5. 管理页 `http://192.168.2.1`，默认无密码，登录后请立即设置密码。

> **A1 与 A2**：硬件方案接近（MT7621 + MT7615），`phicomm_k2p` 配置对两者通用；A2 的 2.4G 偶有断流属已知驱动问题，可调整信道/频宽规避。

---

## ✅ 功能验证

刷机联网后 SSH 登录验证：

```sh
# 1) BBR 是否生效（应输出 bbr）
sysctl net.ipv4.tcp_congestion_control

# 2) Fullcone / 硬件加速
#  LEDE 方案：LuCI → 网络 → TurboACC 网络加速，查看开关状态
#  ImmortalWrt 方案：
uci show firewall.@defaults[0] | grep -E 'fullcone|flow_offloading'
ls /sys/kernel/debug/ppe0/entries 2>/dev/null && echo "PPE 硬件流表可用"

# 3) ZeroTier / UPnP 运行状态
/etc/init.d/zerotier status
/etc/init.d/miniupnpd status

# 4) 中文界面：LuCI → System → Language → 简体中文
```

NAT 类型用 NatTypeTester 测试，开启 Fullcone 后应显示 **FullCone / NAT1**。

---

## ❓ 常见问题

**Q：24.10 和 25.12 选哪个？**
A：两个独立工作流分别产出。25.12 内核 6.12 更新、当前稳定；24.10 内核 6.6 更成熟、资料多。都集成相同功能。

**Q：编译失败？**
A：多为源码依赖下载失败，重新 Run workflow 即可（已带多线程失败后单线程重试）。仍失败可开 `debug=true` 用 tmate 排查。

**Q：固件超过 15744 KiB 被中止？**
A：插件太多。在对应 `configs/k2p-a2-*.config` 里关闭非必需项。

**Q：刷机后是英文界面？**
A：首次启动脚本已设中文；未生效则在 LuCI → System → Language 选简体中文，或检查 `luci-i18n-base-zh-cn` 是否编入。

---

## 🙏 致谢

- [Lean / coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) —— 成熟 K2P 固件源码
- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) —— 新内核、原生 Fullcone 支持
- [coolsnowwolf/luci](https://github.com/coolsnowwolf/luci) —— 中文 LuCI 与 TurboACC
- 斐讯 K2P 开源社区 —— 持续的驱动与工具链维护

---

**License**: MIT
