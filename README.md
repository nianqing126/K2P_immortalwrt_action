# K2P ImmortalWrt 双版本云编译工程（纯主线，无 turboacc）

面向 **斐讯 K2P（A2，MT7621，mipsel_24kc，128MB 内存，16MB 闪存）** 的统一编译工程，一个工作流同时出两个版本：

| 版本 | 源码引用 | 包管理器 | 内核 | 定位 |
|---|---|---|---|---|
| **24.10** | 分支 `openwrt-24.10` | opkg | 6.6 | ✅ 主力推荐，兼容性最稳 |
| **25.12.2** | 标签 `v25.12.2` | apk | 6.12.103 | ⚠️ 尝鲜测试 |

- **纯主线包**：不注入第三方 turboacc，不打第三方内核补丁，规避 952 conntrack 补丁 `Hunk FAILED` 编译错误。
- 基础功能保留官方默认：双频 WiFi、LuCI 中文、防火墙、DHCP、PPPoE、SSH。
- 加装：**ZeroTier 组网**、**UPnP**、主线流卸载 / BBR / fullcone 内核模块。

---

## 一、功能与操作界面一览

| 功能 | 固件默认 | 操作方式 / 界面 | 说明 |
|---|---|---|---|
| 软件流卸载（flow offload） | 已开启 | **LuCI → 网络 → 防火墙** 页面勾选框（官方内置） | nftables 软件快速路径；硬件分载 MT7621 无主线驱动，保持关闭 |
| 全锥 NAT（fullcone，IPv4） | 已开启 | 主线防火墙4 UCI 开关，首启脚本预置 | LuCI 页面是否显示该勾选框取决于 luci 版本；不显示也不影响默认生效。**仅 UDP 全锥**，TCP 退化为普通 MASQUERADE |
| BBR 拥塞控制 | 已开启 | 主线无独立网页开关，sysctl 预置 | 开机即 BBR + fq 队列；改回 CUBIC 见第六节 |
| UPnP | 已装应用 | **LuCI → 服务 → UPnP** 官方页面 | fw4/nftables 配套 |
| ZeroTier | 已装应用 | **LuCI → 服务 → ZeroTier** 官方页面（中文） | 走 tun 虚拟网卡 |

### 关于“没有网页开关”的两项

- **BBR**：主线没有 LuCI 切换应用，工程用 `/etc/sysctl.d/99-bbr.conf` 预置 BBR，刷完即用，不用敲命令开启。
- **fullcone**：主线防火墙4 通过 UCI `defaults.fullcone` 控制，首启脚本写入并提交；LuCI 界面未必渲染这个勾选框，但配置已生效。

---

## 二、内置组件清单（已在官方 feed 核对存在）

| 类别 | 包 / 模块 |
|---|---|
| 组网 | `zerotier`、`luci-app-zerotier`、`luci-i18n-zerotier-zh-cn`、`kmod-tun` |
| 流卸载 | `kmod-nft-offload` |
| 拥塞控制 | `kmod-tcp-bbr` |
| 全锥 NAT | `kmod-nft-fullcone`（防火墙4 原生支持） |
| UPnP | `miniupnpd-nftables`、`luci-app-upnp`、`luci-i18n-upnp-zh-cn` |
| LuCI 基础 | `luci`、`luci-mod-admin-full`、`luci-theme-bootstrap`、`luci-i18n-base-zh-cn`、`luci-compat` |

**不带**：EasyTier、Shortcut-FE、Docker、第三方 turboacc 面板。

设备符号（两份 config 一致，已对照官方 `config.buildinfo` 核对）：

```
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_mt7621=y
CONFIG_TARGET_DEVICE_ramips_mt7621_DEVICE_phicomm_k2p=y
```

---

## 三、容量评估（16MB 闪存）

| 版本 | 官方基线镜像 | 加装增量（压缩进 rootfs） | 预估成品 |
|---|---|---|---|
| 24.10.6 | 9.63 MiB（10,093,658 字节） | ≈1.5～1.7 MiB | ≈11.2～11.6 MiB |
| 25.12.2 | 10.19 MiB（10,682,926 字节） | ≈1.5～1.8 MiB | ≈11.7～12.0 MiB |

两版均低于 15MB 编译闸门；最终以实际 `sysupgrade.bin` 体积为准。

---

## 四、目录结构

```
openwrt-k2p-clean/
├── .github/workflows/
│   └── build.yml                       # 矩阵编译：24.10 + 25.12.2
├── configs/
│   ├── immortalwrt-24.10.config        # 24.10 种子配置
│   └── immortalwrt-25.12.config        # 25.12.2 种子配置
├── files/                              # 固件 overlay（两版本共用，首启写入）
│   ├── etc/sysctl.d/99-bbr.conf       # 预置 BBR + fq
│   └── etc/uci-defaults/99-accel-defaults  # 首启写入流卸载/fullcone 防火墙配置
└── README.md
```

两份 config 包清单完全一致，只有头部注释区分版本；overlay 文件共用。

---

## 五、云端编译步骤

1. **Fork 本仓库**到自己的 GitHub 账号。
2. 仓库 **Settings → Actions → General**，允许 Actions 读写。
3. 打开 **Actions**，启用 `Build K2P ImmortalWrt Firmware (24.10 / 25.12.2)`。
4. 点 **Run workflow**，矩阵会并行跑两个任务（`fail-fast: false`，一个失败不影响另一个）。
5. 编译完成后在 Artifacts 下载：
   - `k2p-24.10` / `k2p-25.12.2`：固件（通配全部 bin，不再限定机型名）
   - `build-log-24.10` / `build-log-25.12.2`：完整编译日志（排错搜 `error:` / `failed`）
6. `*-squashfs-sysupgrade.bin` 用于 OpenWrt 下升级；首次从原厂刷入走 Breed / U-Boot 恢复界面。

工作流已做：Ubuntu apt 源换清华镜像、4G Swap 防 OOM、单线程编译（日志不乱序）、15MB 体积闸门校验。

> 注意：下载后先核对文件名带 `phicomm_k2p`；如果文件名是别的机型，说明 config 设备符号没生效，不要刷入 K2P。

---

## 六、刷机后配置

LuCI 地址 `192.168.1.1`。

### 1. ZeroTier 组网

左侧 **服务 → ZeroTier**，网页里加入网络；也可 SSH：

```sh
/etc/init.d/zerotier enable
/etc/init.d/zerotier start
zerotier-cli join <network-id>
zerotier-cli info
```

### 2. 软件流卸载

**网络 → 防火墙** 页面查看“软件流量分载”，固件已默认勾选；硬件流量分载在 MT7621 上无主线驱动，不要勾。

### 3. UPnP

左侧 **服务 → UPnP**，开启后内网设备可自动申请端口映射。

### 4. BBR / fullcone 状态

- BBR：开机即生效。查看当前算法：`sysctl net.ipv4.tcp_congestion_control`；切回 CUBIC：把 `/etc/sysctl.d/99-bbr.conf` 里 `bbr` 改成 `cubic` 后 `sysctl -p`。
- fullcone：开机即对 IPv4 生效，IPv6 关闭。默认值由首启脚本写入防火墙配置。

---

## 七、注意事项与风险

- **MT7621 没有 Filogic 那种硬件 HNAT/PPE 加速**，本工程只有软件流卸载；不要期待 MT7981 固件里的 HNAT 面板和连接计数。
- 开启软件流卸载后，**流量统计、限速、SQM QoS 可能失效**，这是流卸载方案的通病。
- **ZeroTier 走 tun 虚拟网卡，不进入流卸载通道**，与加速功能互不冲突。
- fullcone **只对 UDP 做真正全锥**；TCP 全锥场景等价于普通 MASQUERADE。
- fullcone 规则可能与 UPnP、ZeroTier 防火墙规则互相影响；开启后先验证连通性和回程路由。
- 128MB 内存只跑 ZeroTier + 加速余量充足，不要再叠加 Docker、重流量监控组件。
- 25.12.2 基线镜像比 24.10 大，余量更紧；若 25.12 编译出现主线包缺失或 kmod 报错，优先用 24.10。
- 刷机前确认能进 Breed / U-Boot 恢复界面，保留回滚路径。
