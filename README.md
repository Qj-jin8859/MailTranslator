# MailTranslator

macOS 菜单栏小工具：自动识别 Mail.app 当前选中邮件的主要语言，如果与目标语言不一致，就自动翻译并弹出译文。

## 功能

- 自动检测邮件语言，目标语言一致时跳过翻译
- 支持 Apple 翻译和 DeepSeek AI 翻译
- 自动翻译语种可独立设置，也可与目标语言同步
- 支持 DeepSeek 模型选择：`deepseek-chat` / `deepseek-reasoner`
- 解析 MIME、HTML、base64、quoted-printable 邮件正文
- 过滤引用、签名和重复空行
- 翻译缓存、开机自启、首次运行引导、诊断信息
- 翻译结果浮窗显示来源，并提供复制和重试

## 环境要求

- macOS 26+
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
