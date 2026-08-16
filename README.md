# MailTranslator

macOS 菜单栏小工具：自动识别 Mail.app 当前选中邮件的主要语言，如果与目标语言不一致，就自动翻译并弹出译文。

> 🚧 当前阶段：Alpha / Proof of Concept，功能可用但仍在持续完善。

## 功能

- 自动检测邮件语言，目标语言一致时跳过翻译
- 支持 Apple 翻译和 DeepSeek AI 翻译
- 自动翻译语种可独立设置，也可与目标语言同步
- 支持 DeepSeek 模型选择：`deepseek-chat` / `deepseek-reasoner`
- 解析 MIME、HTML、base64、quoted-printable 邮件正文
- 过滤引用、签名和重复空行
- 翻译缓存、开机自启、首次运行引导、诊断信息
- 翻译结果浮窗显示来源，并提供复制和重试

## Roadmap

- `v0.1`：完成纯文本邮件自动检测与翻译
- `v0.2`：完善 MIME/HTML 正文解析、引用与签名清理
- `v0.3`：加入翻译缓存、DeepSeek AI 翻译、开机自启
- `v0.4`：完善隐私模式、诊断信息、自测
- 后续：快捷触发、回复内容智能识别、本地化

## 环境要求

- macOS 15+
- Swift 6.3+
- Xcode Command Line Tools 或完整 Xcode

## 运行

```bash
cd MailTranslator
swift run MailTranslator
```

首次使用需要允许 Mail.app 自动化权限。可选：在“系统设置 → 隐私与安全性 → 辅助功能”中授权本 App，以获得更低延迟的选中监听。

## 打包

```bash
./Scripts/build_app.sh
open dist/MailTranslator.app
```

## 自测

```bash
./Scripts/run_tests.sh
```

## 翻译引擎

未配置 API Key 时使用 Apple 翻译。配置 DeepSeek 后优先使用 DeepSeek：

```bash
defaults write local.codex.MailTranslator.settings deepSeekAPIKey -string "你的 DeepSeek API Key"
```

## Privacy

- Apple 翻译优先在本机处理，不会把邮件发送到 DeepSeek；
- 配置 DeepSeek 后，邮件正文会发送到 DeepSeek API，仅用于本次翻译；
- 可在偏好设置中开启“仅离线翻译”，彻底禁用云端翻译；
- 本地翻译缓存保存在 `~/Library/Application Support/MailTranslator/`。

## 结构

```text
Sources/MailTranslator          # 可执行入口
Sources/MailTranslatorCore      # 核心逻辑与 UI
Tests/SelfTests                 # 轻量自测
Resources                       # 图标与 Info.plist
Scripts                         # 打包、测试脚本
```

## 说明

- 邮件原文来自 Mail.app 的 `source`，特殊 MIME 结构可能回退到纯文本 `content`
- 正文清理基于启发式规则，复杂签名仍可能残留
- DeepSeek 翻译需要联网，邮件内容会发送到 DeepSeek
