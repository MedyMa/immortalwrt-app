# 手机 App v2 实施计划（历史记录）

**目标**：交付已确认的 v2 界面、可靠的只读远程状态与 Android 17 / iOS 27 SDK 构建。

**架构**：ubus 传输在 `services/router_api.dart`；应用外壳管理生命周期、凭据、刷新和快照；页面与公共组件处理展示。

**工具**：Flutter 3.47.5、Dart、`http`、`flutter_secure_storage`、Android API 37、Xcode 27 / iOS 27 SDK。

- [x] 增加会话失效、单次重登、权限、网络错误、局部失败与按页请求测试。
- [x] 实现分类错误、按页读取与快照合并。
- [x] 实现后台暂停、前台恢复与页面切换状态机及测试。
- [x] 将代码拆入 `screens/`、`widgets/`、`services/`、`models/`，保持原布局和测试。
- [x] 固定编译 SDK、输出构建工具版本并记录签名限制。
- [x] 执行格式、分析、完整测试，提交推送并核对两端产物；当时的 [CI 记录](https://github.com/MedyMa/immortalwrt-app/actions/runs/36807475862) 已成功。

不增加路由器写接口、手机后台采集、MiWiFi 或 VPN。此处构建结果为历史记录，不代表之后提交的构建结果。
