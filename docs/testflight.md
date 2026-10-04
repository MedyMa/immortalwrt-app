# TestFlight 发布说明

手动工作流 **Publish iOS to TestFlight** 构建已签名真机 IPA 并上传 App Store Connect。普通 CI 的模拟器 App 不能用于 TestFlight。

## 前置条件

Apple Developer Program 已生效，并能创建分发证书和描述文件。在同一团队创建 App Store Connect 应用记录和明确 App ID：`com.medyma.immortalwrtApp`。导出包含私钥、受密码保护的 Apple Distribution P12，并创建匹配 App ID 和证书的 App Store 分发描述文件。

## GitHub 机密变量

在仓库或 `testflight` 环境中配置：

| 变量 | 内容 |
| --- | --- |
| `IOS_TEAM_ID` | Apple 开发者团队 ID |
| `IOS_DISTRIBUTION_P12_BASE64` | 分发证书 P12 的 Base64 |
| `IOS_DISTRIBUTION_P12_PASSWORD` | P12 导出密码 |
| `IOS_PROVISION_PROFILE_BASE64` | 分发描述文件的 Base64 |
| `ASC_KEY_ID` | App Store Connect 团队 API 密钥 ID |
| `ASC_ISSUER_ID` | API 密钥签发者 ID |
| `ASC_PRIVATE_KEY_BASE64` | API 密钥 P8 的 Base64 |

API 密钥需要足够的应用访问权限。工作流不需要 Apple ID 登录密码，不要将证书、私钥、密码或验证码提交仓库。

## 发布步骤

1. 在 `main` 手动运行工作流，输入未使用过的构建号；每次上传递增，不固定沿用工作流默认值。
2. 检查签名、真机构建和上传步骤是否成功。
3. 在 App Store Connect → TestFlight 等待处理，按要求填写出口合规信息，再分配测试组。
4. 外部测试可能需要 Apple 测试版审核；工作流不会自动邀请测试者。

上传成功仅表示 Apple 接收了构建，不表示已经可供测试。Windows 可检查配置，不能替代 macOS / Xcode 的签名上传验证。开发者资格或签名配置未完成时，继续使用常规 Android / iOS 模拟器构建。

## 签名机密范围

依赖安装、分析、测试和 Flutter/CocoaPods 构建均不注入签名或上传密钥。先生成无签名归档，再在独立步骤导入分发证书和描述文件，通过 `xcodebuild -exportArchive` 签名导出；导出阶段不再执行项目构建脚本。App Store Connect API 密钥只在上传步骤提供。

已签名 IPA 不发布为 GitHub Actions artifact，只上传 App Store Connect。无论发布成功还是失败，最后一步清理临时钥匙串、描述文件、上传密钥和 IPA。P12 密码显式掩码；GitHub 机密变量自身也有日志掩码。
