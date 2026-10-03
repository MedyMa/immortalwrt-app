# 配套固件与路由器安装说明

## 适用对象

主要对象为 BPI-R4 / MT7988 路由器及 BE14（MT7990）无线模组，配合 [MedyMa/BananaPi-BPI-R4 固件构建项目](https://github.com/MedyMa/BananaPi-BPI-R4) 使用。

该 App 读取 MT7988 上的状态接口。小米 AX9000 可作为下游设备显示，不要求给 AX9000 刷入此固件，也不通过 MiWiFi 读取 BE14。

## 固件构建路线

| 构建工作流 | 固件源码及分支 | 与手机 App 的关系 |
| --- | --- | --- |
| `MT7988-Action.yml` | `MedyMa/immortalwrt-mt798x-6.6`，`mt798x-mt799x-6.6-mtwifi` | MT7988 厂商无线驱动路线；BE14 私有统计以此类驱动的数据为依据 |
| `immortalwrt_25.12_wifi7.yml` | `amhelibrary/immortalwrt`，`openwrt-25.12-mtk-hqos` | Wi-Fi7 / mt76 路线；不能直接假设具有厂商 `iwpriv stat` 字段 |
| `immortalwrt-25.12.yml` | `immortalwrt/immortalwrt`，`openwrt-25.12` | 通过独立组件提供状态接口；射频和传感器指标依驱动支持而定 |

构建路线依据 [厂商路线工作流](https://github.com/MedyMa/BananaPi-BPI-R4/blob/main/.github/workflows/MT7988-Action.yml) 和 [Wi-Fi7 工作流](https://github.com/MedyMa/BananaPi-BPI-R4/blob/main/.github/workflows/immortalwrt_25.12_wifi7.yml)。本地构建配置已加入独立状态组件的合入与选中检查；旧版固件、下载到的具体镜像和硬件运行情况仍须通过下面的命令确认。配置选中不等于所有硬件指标已经实测。

手机 App 不依赖某个固定固件发布日期。决定功能是否可用的是软件包版本、只读 RPC、账号权限和传感器/驱动能力。

## 需要哪些软件包

| 软件包 / 服务 | 最低约束或接口 | 数据 |
| --- | --- | --- |
| `rpcd-mod-router-status` | 温度需要 0.1.2 或更新版本 | CPU 计数器、CPU/无线/硬盘温度、BE14 状态及历史 |
| `luci-app-traffic` | 推荐 1.1.7 或更新版本 | 下载/上传速率、会话总量、24 小时统计、应用/站点记录及图标 |
| `luci-app-sfp-status` | `getStatuses` | SFP 插槽、链路、协商速率、模块温度 |
| turboacc | `getMTKPPEStat` | PPE 已绑定流表和容量 |
| 固件自带 rpcd / LuCI 读取接口 | `system.info`、`luci-rpc.getDHCPLeases` | 运行时间、内存、DHCP 租约 |

状态组件与 Traffic 完全独立。安装旧版状态组件可能有 CPU 数据却没有温度字段。安装 Traffic 不能替代安装状态组件。

## 安装

从 [路由器组件构建页](https://github.com/MedyMa/luci-app/actions) 下载与固件版本、架构和包管理器匹配的软件包。组件源码与检查说明见 [rpcd-mod-router-status](https://github.com/MedyMa/luci-app/tree/main/Luci-app/rpcd-mod-router-status)。

先确认设备信息和包管理器：

```sh
ubus call system board '{}'
command -v opkg
command -v apk
```

使用 `opkg` 的固件安装 `.ipk`；使用 `apk` 的固件安装路由器 `.apk`。常见 24.10 固件使用 `opkg`，25.12 路线常见 `apk`，但定制固件以实际命令输出为准。**路由器 `.apk` 不是 Android 手机安装包。** 不要只按文件后缀或固件名称猜测兼容性。

以已下载到 `/tmp` 的状态组件为例，选择与设备一致的一条命令执行：

```sh
opkg install /tmp/rpcd-mod-router-status_实际版本_实际架构.ipk
# 或在 apk 固件上：
apk add /tmp/rpcd-mod-router-status-实际版本.apk
```

示例文件名需替换为实际下载文件名，不要强制忽略架构、依赖或签名校验。安装会注册 `router.status` 并启动采样服务，rpcd 重启后旧会话可能失效，请重新连接 App / LuCI。

专用只读账号需包含 `router-status` 读取 ACL，并按使用功能授予 Traffic、SFP、turboacc 与 DHCP 的读取权限；不需要授予写权限。

## 接口检查

```sh
ubus -v list router.status
ubus call router.status getSystemMetrics '{}'
ubus call router.status getWirelessStatus '{}'
ubus call router.status getWirelessHistory '{}'
/etc/init.d/router-status status
ubus -v list luci.traffic
ubus call luci.sfp-status getStatuses '{}'
ubus call luci.turboacc getMTKPPEStat '{}'
```

- `Not found`：对象未注册，检查包是否安装及 rpcd 注册状态。
- `Method not found`：对象存在但该方法缺失，检查组件版本与接口。
- `Access denied`：检查手机账号读取 ACL；root 在 SSH 中读取成功不证明手机账号有权限。
- 无线历史为空：首次运行至少等待两次采样；不要用示意曲线填充。
- CPU 使用率需要两次计数器采样；温度缺失可能是组件版本、采样缓存或传感器不支持。

厂商 BE14 已确认能提供 TX 成功/失败、RX 成功/CRC 与温度字段，但未取得可用的空中占用率或客户端信号分布。TX FAL 与 RX CRC 是不同的质量指标，不作为重试率或干扰率显示。

历史保存在 `/tmp/router-status`，每分钟采样，按 5 分钟桶保留最近 24 小时。路由器重启清空；普通服务重启和升级保留。缺失与计数器重置保留为空值，不编造为零。

## 家外访问

App 通过普通 HTTPS 请求访问路由器 `/ubus`，认证使用路由器账号。路由器负责配置 DDnsto 客户端令牌和隧道映射；手机端不含该令牌。

需要确认自己的域名能直接返回 ubus JSON，而不是隧道网页登录页面。安装后在手机蜂窝网络下验证登录及授权读取；局域网测试不能证明家外链路可用。
