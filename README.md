# K2P TurboACC + ZeroTier 组网固件云编译工程（24.10 单版本）

面向 **斐讯 K2P（A2，MT7621，mipsel_24kc，128MB 内存，16MB 闪存）** 的 ImmortalWrt 云端编译工程，固定使用稳定分支 **`openwrt-24.10`**（opkg 包管理器，内核 6.6）。

固件**保留官方默认基础功能**（双频 WiFi、LuCI 中文、防火墙、DHCP、PPPoE、SSH），在其之上加装：**ZeroTier 组网**、**Turbo ACC 加速面板**、**UPnP**，不做无网页的过度精简版。

> 本工程只出 24.10 一个稳定版本；snapshot 主线已剔除，25.12.2 另见独立工程（见第五节版本选型）。

---

## 一、能力边界（刷机前必读）

### 1.1 截图里的 HNAT 面板，K2P 复现不了

参考截图的设备是 **KOMI A31（MT7981B，Filogic，ARM A53）**，里面的：

- 快速转发引擎下拉 **MediaTek HNAT**
- **PPE0 / PPE1 已绑定连接数**、**HNAT PPE 数量**、**HNAT 速率阈值(pps)**
- 全锥下拉 **Boardcom Fullcone**

这些来自 **MediaTek 闭源 HNAT 驱动 + mtk 原厂工具链**，只存在于 MT7981/7986 等 Filogic 平台的第三方固件里。**K2P 的 MT7621 是老款双核 MIPS 芯片，主线 ImmortalWrt / OpenWrt 没有可用的 HNAT 驱动，也没有对应的 PPE 计数界面**，这套下拉页面和硬件加速在 K2P 上无法复现。

本工程集成开源的 [chenmozhijin/turboacc](https://github.com/chenmozhijin/turboacc)（LuCI 面板名 **Turbo ACC Center**），在 MT7621 上实际提供：

| 截图里的功能 | K2P 上能否实现 | 本工程对应实现 |
|---|---|---|
| 软件流卸载（快速转发） | ✅ 可以 | `kmod-nft-offload`，面板“软件流量分载” |
| 硬件 HNAT / PPE 计数 | ❌ 无驱动，不出现 | —（面板“硬件流量分载”开关在本机勾选也不生效，默认已关闭） |
| 全锥形 NAT | ⚠️ 部分可用 | `nft-fullcone`（第三方补丁版防火墙4/nftables/libnftnl），**仅 UDP 做全锥**，TCP 退化为普通 MASQUERADE |
| BBR 拥塞控制 | ✅ 可以 | `kmod-tcp-bbr`，面板一键切换 BBR / CUBIC |
| UPnP | ✅ 可以 | `miniupnpd-nftables` + LuCI 页面 |

### 1.2 “K2P 支持硬件加速”到底指什么

MT7621 芯片内部确实带转发引擎，但驱动分两套，差距很大：

- **原厂 SDK 固件（Padavan、老联发科闭源固件）**：闭源驱动可把 IPv4 NAT 交给芯片 PPE 引擎，WAN-LAN 转发几乎不占 CPU，这是“K2P 硬件加速很强”说法的来源。
- **OpenWrt / ImmortalWrt 主线开源驱动**：联发科没有把完整 PPE/HNAT 驱动开源给主线，主线只实现 **nftables 软件流卸载**（内核快速路径，省掉用户态转发开销），**没有硬件 IPv6 NAT、无线侧卸载和硬件层全锥**。
- **Shortcut-FE（SFE）** 是纯软件快速路径，不是硬件加速；本工程按作者建议不带 SFE。

### 1.3 全锥 NAT：现在 K2P 新固件基本都这样

目前主流 K2P 新固件（fw4 / nftables，22.03 之后）用的是同一个开源 nft-fullcone 内核模块。源码里写死了协议判断：非 UDP 流量按普通 MASQUERADE 处理——**只有 UDP 走真全锥，TCP 退化为对称 NAT**。各家 fork 都改不出硬件级全锥。

- P2P 打洞（游戏联机、语音、视频、下载器）主要走 **UDP**，UDP 全锥即可解决 NAT1/NAT2 识别。
- TCP 场景（网页、普通下载）本就依赖 conntrack 回程，全锥对它意义不大；测 NAT 类型看 UDP 结果即可。
- 老 fw3/iptables 时代的 `xt_FULLCONENAT` 只支持老内核，新 fw4 固件用不了。

---

## 二、内置组件清单

| 类别 | 包 / 模块 | 说明 |
|---|---|---|
| 组网 | `zerotier`、`luci-app-zerotier`、中文包、`kmod-tun` | ZeroTier 虚拟组网，走 tun 网卡 |
| 加速面板 | `luci-app-turboacc`、`luci-compat` | 第三方 Turbo ACC 网页面板 |
| 流卸载 | `kmod-nft-offload` | nftables 软件流卸载快速路径 |
| 拥塞控制 | `kmod-tcp-bbr` | BBR 模块，面板切换 |
| 全锥 NAT | `nft-fullcone`（第三方源码包） | 随 turboacc 注入，替换为打补丁的 firewall4 / libnftnl / nftables |
| UPnP | `miniupnpd-nftables`、`luci-app-upnp`、中文包 | fw4/nftables 配套 |
| 基础系统 | LuCI 中文、双频 WiFi、netifd、firewall4、dnsmasq、ppp/pppoe、dropbear | 沿用 ImmortalWrt 默认，不裁剪 |

**不带**：EasyTier（容量不足，见第三节）、Shortcut-FE（作者自述未充分测试）、Docker 等重组件。

---

## 三、容量评估（16MB 闪存，实测数据）

### 官方同机型镜像基线（完整基础功能 + LuCI + 双频 WiFi）

| 版本 | 镜像大小 | 其中内核 | 其中 rootfs(squashfs) |
|---|---|---|---|
| 24.10.6 | 9.63 MiB（10,093,658 字节） | 3.26 MiB | 6.37 MiB |

### 加装增量

| 项 | 增量 | 说明 |
|---|---|---|
| ZeroTier 本体 | 已安装 1.02 MB / ipk 491 KB | 依赖（kmod-tun、libstdcpp6、ip 等）由 defconfig 自动补齐 |
| TurboACC 面板 + nft-fullcone | 面板 Lua 页面约几十 KB，fullcone 模块约 30KB | firewall4/nftables/libnftnl 为**替换**现有版本，不净增体积 |
| UPnP | miniupnpd 220KB + LuCI 页 30KB | 多数依赖基础系统已带 |
| 估算增量（压缩进 rootfs） | ≈1.5～1.7 MiB | 编译后以实际 `sysupgrade.bin` 体积为准 |
| 预估成品镜像 | ≈11.2～11.6 MiB | 低于 15MB 闸门，16MB 闪存可装下 |

### 为什么不含 EasyTier

EasyTier v2.6.4 mipsel 静态二进制实测：`easytier-core` 原始 6.69 MB，gzip 压缩后 **6.38 MB**（Rust 静态 ELF 几乎压不动），另有 `easytier-cli` 2.69 MB。加进带 LuCI 的基础固件会把镜像顶到约 16.0 MiB、超 15MB 闸门；只有砍掉 LuCI 退回纯命令行才勉强放下，属于过度精简。因此**只出 ZeroTier 版本，不做 EasyTier 版本**。

---

## 四、TurboACC 注入方式与兼容性

第三方 turboacc 不是官方 feed 包，CI 在克隆源码后执行官方脚本 `add_turboacc.sh --no-sfe` 完成注入：

1. 拷贝 `luci-app-turboacc` 面板与 `nft-fullcone` 源码到 `package/turboacc/`；
2. 打入 **952** 内核补丁（conntrack 多注册事件支持，fullcone 依赖）；
3. 用归档的打补丁版本**替换** `firewall4`、`libnftnl`、`nftables`；
4. 不编译 Shortcut-FE（`--no-sfe`）。

### 版本匹配情况（已逐一核对源码版本，24.10 内核 6.6）

| 组件 | 主线版本 | turboacc 归档匹配 |
|---|---|---|
| firewall4 | `18fc0ead…` | ✅ 有对应版本 |
| nftables | 1.1.1 | ✅ 有 |
| libnftnl | 1.2.8 | ✅ 有 |
| 952 内核补丁 | `hack-6.6` | ✅ 含 |

24.10 三个被替换组件版本都能对上归档，是这套第三方组合最稳的状态。

---

## 五、版本选型对比

| 版本 | 包管理器 | 内核 | TurboACC 面板 | fullcone / 流卸载 | 结论 |
|---|---|---|---|---|---|
| **24.10（本工程）** | opkg | 6.6 | ✅ 第三方面板 | 第三方补丁版 nft-fullcone + 软件流卸载 | ✅ **主力推荐**，版本匹配、最稳 |
| 25.12.2（独立工程） | apk | 6.12.103 | ❌ 无第三方面板 | 主线自带 kmod-nft-fullcone / nft-offload | ⚠️ 仅尝鲜，见 `openwrt-k2p-25.12` 工程 |
| snapshot（master） | apk/opkg 不定 | 每日滚动 | ❌ 归档版本回退、补丁易冲突 | 主线包 | ❌ 已剔除，不适合长期使用 |

> 25.12.2 主线已自带 fullcone / offload 内核模块，但 turboacc 无官方 25.12 适配，注入会与主线同名模块重复定义、并替换防火墙核心组件，风险高；因此 25.12 工程只选主线包、不带面板。

---

## 六、目录结构

```
openwrt-k2p-zt/
├── .github/workflows/
│   └── build.yml                  # GitHub Actions：24.10 单版本编译
├── configs/
│   └── immortalwrt-24.10.config   # 24.10 种子配置
├── files/                         # 固件 overlay（首启写入）
│   ├── etc/config/turboacc        # K2P 安全默认值（硬件分载/sfe/fullcone/BBR 关）
│   └── etc/uci-defaults/99-turboacc-enable  # 首启启用 turboacc init 脚本
└── README.md
```

种子配置只指定：目标机型、LuCI 基础包、ZeroTier、TurboACC 面板及选项、流卸载/BBR 模块、UPnP；其余基础组件全部沿用 ImmortalWrt 默认选择，不主动关闭。

---

## 七、云端编译步骤

1. **Fork 本仓库**到自己的 GitHub 账号。
2. 仓库 **Settings → Actions → General**，允许 Actions 读写。
3. 打开 **Actions**，启用 `Build K2P TurboACC ZeroTier Firmware (24.10)`。
4. 点 **Run workflow**（`release_tag` 留空则产物只存 Artifacts，保留 30 天）。
5. 编译完成后在 Artifacts 下载 `k2p-turboacc-24.10`。
6. `*-squashfs-sysupgrade.bin` 用于 OpenWrt 下升级；首次从原厂刷入走 Breed / U-Boot 恢复界面。

工作流已把 Ubuntu apt 源替换为清华镜像，规避 `azure.archive.ubuntu.com` 连接超时；内置 15MB 镜像上限校验，超过即判失败，避免刷砖。

---

## 八、刷机后配置

LuCI 地址 `192.168.1.1`。

### 1. ZeroTier 组网

左侧 **服务 → ZeroTier**（已带中文），网页里加入网络；也可 SSH：

```sh
/etc/init.d/zerotier enable
/etc/init.d/zerotier start
zerotier-cli join <network-id>
zerotier-cli info
```

### 2. Turbo ACC 加速面板

左侧 **网络 → Turbo ACC Center**。固件默认值（见 `files/etc/config/turboacc`）：

- 软件流量分载：**开**（MT7621 可用的快速路径）
- 硬件流量分载：**关**（本机无硬件 NAT 驱动，勿勾）
- 全锥形 NAT：**关**（需要时手动开；仅 UDP 全锥）
- BBR：**关**（沿用 CUBIC；需要时勾上保存并应用）

改完点 **保存并应用**，init 脚本会把选项写进防火墙配置并重启防火墙。

### 3. UPnP

左侧 **服务 → UPnP**，开启后内网设备可自动申请端口映射。

---

## 九、注意事项与风险

- **开启软件流卸载 / 全锥后，流量统计、限速、SQM QoS 可能失效**，这是流卸载/硬件 NAT 类方案的通病。
- **ZeroTier 走 tun 虚拟网卡，不进入流卸载/HNAT 通道**，与加速功能互不冲突。
- nft-fullcone **只对 UDP 做真正全锥**；TCP 全锥场景下等价于普通 MASQUERADE。
- fullcone 规则可能与 UPnP、ZeroTier 防火墙规则互相影响；开启后先验证连通性和回程路由。
- 24.10 包管理器为 opkg，固件内已自带，不影响使用。
- 128MB 内存只跑 ZeroTier + 加速余量充足，不要再叠加 Docker、流量监控等重组件。
- 刷机前确认能进 Breed / U-Boot 恢复界面，保留回滚路径。
