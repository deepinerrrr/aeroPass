# aeroPass

基于 Flutter 的执照备考应用，支持自有题库导入、练习与模拟考试、错题与合集管理、学习统计，以及使用个人 API Key 的 AI 答疑。

## 原生 iOS 版本

`native-ios/` 包含 SwiftUI 原生实现。打开 `native-ios/aeropass.xcodeproj` 构建；该版本同样不包含题库或 API 密钥，首次使用请在 App 内导入自有 `.xlsx` 题库。具体说明见 [native-ios/README.md](native-ios/README.md)。

## 运行

1. 安装 Flutter，并运行 `flutter pub get`。
2. 使用 `flutter run` 启动应用。
3. 在应用的「题库管理」中导入自己有权使用的 `.xlsx` 题库。AI 功能需要在设置中填写自己的 Qwen 或 DeepSeek API Key。

本仓库不包含内置题库或任何可用的 API Key。首次启动时如果提示内置题库不存在，可直接进入「题库管理」导入自己的文件。`assets/questions.json` 是本地私有数据文件，不需要创建即可编译项目。

## 题库格式

仅支持 `.xlsx`。每个工作表第一行直接填写题目数据，不要添加表头。A–G 列依次为：题目、正确答案、题目编号、选项 A、选项 B、选项 C、选项 D。判断题可使用「正确」或「错误」作为答案。导入前会验证格式和重复编号。

## 隐私与部署

- 题库文件、数据库、环境变量、签名材料和本机生成文件均被 Git 忽略。
- AI API Key 由使用者在应用内配置；不要写入源码或提交到仓库。
- `server/app-update/.env.example` 仅提供占位值。部署更新服务前必须设置自己的管理令牌和域名。

## 许可

本项目源码采用 [GNU Affero General Public License v3.0](LICENSE)（AGPL-3.0-only）。第三方依赖仍遵循各自的许可证。题库内容不随本仓库发布。
