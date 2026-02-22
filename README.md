# VoiceType-Lite
[![GitHub stars](https://img.shields.io/github/stars/Winterslife/VoiceType-Lite?style=social)](https://github.com/Winterslife/VoiceType-Lite)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 13.0+](https://img.shields.io/badge/macOS-13.0%2B-brightgreen.svg)](https://www.apple.com/macos/)
[![Latest Release](https://img.shields.io/github/v/release/Winterslife/VoiceType-Lite)](https://github.com/Winterslife/VoiceType-Lite/releases)

**开源、本地、隐私优先的 macOS 语音输入工具**

**Open-source, local, privacy-first voice input for macOS**

<p align="center">
  <img src="assets/demo.gif" alt="VoiceType-Lite Demo" width="600">
  <br>
  <em>按住右 Option 键说话 → 松开 → 文字自动输入 / Hold Right Option → Speak → Release → Text appears</em>
</p>

---

## 功能特点 / Features

- **完全本地运行** — 无需联网，语音数据不离开你的电脑
- **一键语音输入** — 按住右 Option 键说话，松开即输入文字
- **自动标点** — 智能添加中文标点符号
- **菜单栏常驻** — 轻量运行，不干扰工作流
- **开源透明** — 代码可审计，MIT 协议

---

- **Fully local** — No internet needed, your voice data never leaves your machine
- **Push-to-talk** — Hold Right Option key to speak, release to insert text
- **Auto punctuation** — Intelligent Chinese punctuation via SenseVoiceSmall
- **Menu bar app** — Lightweight, stays out of your way
- **Open source** — Auditable code, MIT license

## 技术架构 / Architecture

```
┌─────────────────────────┐
│   VoiceType-Lite.app    │
│   (SwiftUI Menu Bar)    │
│                         │
│  Right Option → Record  │
│  Release → Transcribe   │
│  Result → Paste Text    │
└────────┬────────────────┘
         │ HTTP (localhost:8766)
         ▼
┌─────────────────────────┐
│   FastAPI Backend        │
│   (Python + uvicorn)     │
│                         │
│  SenseVoiceSmall (CPU)  │
│  FunASR + Torch         │
└─────────────────────────┘
```

Swift 前端通过 HTTP 与本地 Python 后端通信。后端使用阿里达摩院的 [SenseVoiceSmall](https://github.com/FunAudioLLM/SenseVoice) 模型进行语音识别，完全在 CPU 上运行。

The Swift frontend communicates with a local Python backend via HTTP. The backend uses Alibaba DAMO Academy's [SenseVoiceSmall](https://github.com/FunAudioLLM/SenseVoice) model for speech recognition, running entirely on CPU.

## 系统要求 / Requirements

- macOS 13.0+
- Python 3.10+
- [Xcode](https://developer.apple.com/xcode/) 15.0+（从源码构建 / for building from source）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）

## 安装 / Installation

### 方式一：下载 DMG / Option 1: Download DMG

前往 [Releases](../../releases) 页面下载最新的 DMG 安装包。

Go to the [Releases](../../releases) page to download the latest DMG.

### 方式二：从源码构建 / Option 2: Build from Source

```bash
# 1. 克隆仓库 / Clone the repo
git clone https://github.com/Winterslife/VoiceType-Lite.git
cd VoiceType-Lite

# 2. 安装 xcodegen / Install xcodegen
brew install xcodegen

# 3. 运行安装脚本（创建 Python 环境 + 下载模型）
#    Run setup script (creates Python venv + downloads model)
./scripts/setup.sh

# 4. 生成 Xcode 项目并构建
#    Generate Xcode project and build
cd app
xcodegen generate
open VoiceType-Lite.xcodeproj
# 在 Xcode 中按 Cmd+R 运行 / Press Cmd+R to run in Xcode

# 5. 启动后端 + 应用（开发模式）
#    Start backend + app (dev mode)
cd ..
./start.sh
```

### 构建 DMG / Build DMG

```bash
./scripts/build-dmg.sh
# 输出 / Output: build/VoiceType.dmg
```

> **注意 / Note:** 首次运行时需要下载 SenseVoiceSmall 模型（约 900MB），请确保网络畅通。
> The first run will download the SenseVoiceSmall model (~900MB). Please ensure a stable network connection.

## 使用方法 / Usage

1. 启动应用后，菜单栏会出现麦克风图标
2. 按住 **右 Option 键** 开始录音
3. 松开按键，等待转写完成
4. 文字自动输入到当前光标位置

---

1. After launching, a microphone icon appears in the menu bar
2. Hold the **Right Option key** to start recording
3. Release the key and wait for transcription
4. Text is automatically typed at the current cursor position

> 首次使用需要授予 **麦克风权限** 和 **辅助功能权限**（用于模拟键盘输入）。
>
> On first use, grant **Microphone** and **Accessibility** permissions (for simulating keyboard input).

## 项目结构 / Project Structure

```
VoiceType-Lite/
├── app/                        # macOS SwiftUI 应用
│   ├── VoiceType/              # Swift 源代码
│   │   ├── VoiceTypeApp.swift  # 应用入口 + 菜单栏 UI
│   │   ├── AppDelegate.swift   # 生命周期管理
│   │   ├── AppState.swift      # 应用状态
│   │   ├── AudioRecorder.swift # 音频录制
│   │   ├── BackendManager.swift# 后端进程管理
│   │   ├── HotkeyListener.swift# 全局快捷键监听
│   │   ├── TextInserter.swift  # 文字输入模拟
│   │   ├── TranscriptionClient.swift # API 客户端
│   │   └── SetupManager.swift  # 首次设置
│   ├── Resources/              # 应用资源（构建时自动填充）
│   └── project.yml             # XcodeGen 配置
├── backend/
│   ├── server.py               # FastAPI 语音识别服务
│   ├── requirements.txt        # Python 依赖
│   └── start.sh                # 后端启动脚本
├── scripts/
│   ├── setup.sh                # 一键安装脚本
│   ├── build-dmg.sh            # DMG 构建脚本
│   └── ExportOptions.plist     # Xcode 导出配置
├── start.sh                    # 开发模式启动（后端 + 应用）
├── LICENSE                     # MIT 协议
└── README.md
```

## 对比 / Comparison

| 特性 / Feature | VoiceType-Lite | 闪电说 | Typeless | 豆包语音 |
|---|---|---|---|---|
| 开源 / Open Source | ✅ MIT | ❌ | ❌ | ❌ |
| 完全本地 / Fully Local | ✅ | ✅ | ❌ 需联网 | ❌ 需联网 |
| 免费 / Free | ✅ | ✅ | ❌ 订阅制 | ✅ |
| 隐私可审计 / Auditable | ✅ | ❌ | ❌ | ❌ |
| 中文优化 / Chinese Optimized | ✅ | ✅ | ✅ | ✅ |
| 无需注册 / No Account | ✅ | ✅ | ❌ | ❌ |
| macOS 原生 / Native macOS | ✅ | ✅ | ✅ | ❌ 网页端 |

## 如果这个项目对你有帮助，欢迎点个 ⭐ Star 支持！
## If you find this useful, a ⭐ star would mean a lot!

## 致谢 / Acknowledgments

- [FunASR](https://github.com/modelscope/FunASR) — 阿里达摩院开源语音识别框架
- [SenseVoiceSmall](https://github.com/FunAudioLLM/SenseVoice) — 高效中文语音识别模型
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — Xcode 项目生成工具
- [uv](https://github.com/astral-sh/uv) — 极速 Python 包管理器

## 许可证 / License

[MIT](LICENSE)
