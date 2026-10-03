# BE14 信道页设计

使用 2.4 / 5 / 6 GHz 选择器展示射频。选中后显示信道、EHT 带宽、TX FAL、RX CRC、最近 24 小时链路质量和收发活动。客户端信号分布仅在驱动提供有效数据时显示，不用示意数据补齐。

厂商驱动的 `iw survey dump` 返回 `nl80211 not found`；`iwpriv stat` 提供 TX 成功/失败、RX 成功/CRC 累计计数。它们不等于空中占用率、干扰率或 TX 重试次数。原始 `network.wireless.status` 可能包含密码，必须由独立组件脱敏。

`router.status` 返回状态和历史，接口字节计数来自 sysfs。历史迁移到 `/tmp/router-status`，每分钟采样，按 5 分钟桶保存最近 24 小时；缺失、重置和采样间隔过大时保留空点。仅 Wi-Fi 页读取历史，不把缺失区间连成连续实测曲线。

本文件更新了早期方案中 `/tmp/traffic` 的旧路径。历史与 CPU/无线职责均属于 `rpcd-mod-router-status`，不属于 Traffic App。示意曲线只用于布局评审。
