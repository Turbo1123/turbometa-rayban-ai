# TurboMeta Ray-Ban AI - iOS

**Version 1.4.0**

Ray-Ban Meta 智能眼镜 AI 助手 iOS 版本。

> **🎬 NEW: RTMP Live Streaming (Experimental) | RTMP 直播推流（实验性）**
>
> Push live video from Ray-Ban Meta glasses to **any RTMP-compatible platform** - YouTube Live, Twitch, Bilibili, Douyin, TikTok, Facebook Live, and more!
>
> 将 Ray-Ban Meta 眼镜的实时视频推送到**任意支持 RTMP 的直播平台** - YouTube Live、Twitch、B站、抖音、TikTok、Facebook Live 等！

## Features | 功能

### Live AI | 实时 AI 对话
- Real-time voice conversation with AI through Ray-Ban Meta glasses
- Supports Alibaba Qwen Omni and Google Gemini Live
- 通过 Ray-Ban Meta 眼镜与 AI 进行实时语音对话
- 支持阿里云通义千问 Omni 和 Google Gemini Live

### Quick Vision | 快速识图
- Take photos with glasses and get AI analysis
- Siri integration: "Hey Siri, TurboMeta Quick Vision"
- Shortcuts app support for lock screen widgets
- 用眼镜拍照并获取 AI 分析
- Siri 集成："嘿 Siri，用 TurboMeta 识图"
- 支持快捷指令 App 锁屏小组件

### Multi-Provider Support | 多提供商支持
- **Vision API**: Alibaba Dashscope / OpenRouter (GPT-5, Claude 4.5, Gemini 3, etc.)
- **Live AI**: Alibaba Qwen Omni / Google Gemini Live
- **视觉 API**: 阿里云 Dashscope / OpenRouter (GPT-5, Claude 4.5, Gemini 3 等)
- **实时 AI**: 阿里云通义千问 Omni / Google Gemini Live

### 🎬 RTMP Live Streaming (Experimental) | RTMP 直播推流（实验性）
- Stream first-person view from glasses to any RTMP server
- Compatible with all major platforms: YouTube, Twitch, Bilibili, Douyin, TikTok, Facebook Live, etc.
- H.264 hardware encoding for smooth streaming
- Adjustable bitrate (1-4 Mbps)
- Real-time preview on phone
- 将眼镜的第一人称视角推流到任意 RTMP 服务器
- 兼容所有主流直播平台：YouTube、Twitch、B站、抖音、TikTok、Facebook Live 等
- H.264 硬件编码，流畅推流
- 可调节码率（1-4 Mbps）
- 手机实时预览

---

## ⚠️ Important Notes | 重要说明

### Google Gemini Live | Google Gemini Live

⚠️ **Not Fully Tested | 未完全测试**

- Google Gemini Live has not been fully tested due to limited access
- If you encounter issues, please provide feedback
- Google Gemini Live 由于条件限制未能完全测试
- 如遇问题，请反馈

### RTMP Streaming | RTMP 推流

⚠️ **Experimental Feature | 实验性功能**

- RTMP streaming is currently experimental
- Some platforms may require additional configuration
- Recommend using 2 Mbps bitrate for stable streaming
- RTMP 推流目前为实验性功能
- 部分平台可能需要额外配置
- 建议使用 2 Mbps 码率以获得稳定推流

---

## Release Notes | 更新日志

### v1.4.0 (2024-12-31)

#### New Features | 新功能

- **🎬 RTMP Live Streaming (Experimental) | RTMP 直播推流（实验性）**
  - Stream first-person view from Ray-Ban Meta glasses to any RTMP server
  - Works with all major live streaming platforms worldwide
  - H.264 hardware encoding with adjustable bitrate
  - Real-time preview on phone while streaming
  - Platform presets for YouTube, Twitch, Bilibili, Douyin, TikTok, Facebook Live
  - 将 Ray-Ban Meta 眼镜的第一人称视角推流到任意 RTMP 服务器
  - 兼容全球所有主流直播平台
  - H.264 硬件编码，支持码率调节
  - 推流时手机可实时预览
  - 预设支持 YouTube、Twitch、B站、抖音、TikTok、Facebook Live

#### Supported Platforms | 支持的平台

- YouTube Live
- Twitch
- Bilibili (B站)
- Douyin (抖音)
- TikTok
- Facebook Live
- Any RTMP-compatible server (MediaMTX, nginx-rtmp, etc.)
- 任意支持 RTMP 的服务器（MediaMTX、nginx-rtmp 等）

---

### v1.4.0 (2024-12-31) - Previous Release

#### New Features | 新功能

- **Vision Model Selection | 视觉模型选择**
  - Choose from multiple vision models
  - Alibaba: Qwen VL Flash/Plus/Max, Qwen 2.5 VL 72B
  - OpenRouter: Access 500+ AI models including GPT-5, Claude 4.5, Gemini 3
  - Filter by vision-capable models

- **App Language | 应用语言**
  - Switch app interface language (System/Chinese/English)
  - Auto-syncs output language when switching

- **Siri Integration | Siri 集成**
  - Trigger Quick Vision with "Hey Siri, TurboMeta Quick Vision"
  - Add to Shortcuts app for lock screen widget

---

## Setup | 配置

### API Keys | API 密钥

1. **Alibaba Dashscope** (for Vision & Live AI)
   - Get API Key: https://help.aliyun.com/zh/model-studio/get-api-key

2. **OpenRouter** (for Vision with various models)
   - Get API Key: https://openrouter.ai/keys

3. **Google AI Studio** (for Gemini Live)
   - Get API Key: https://aistudio.google.com/apikey

---

## Requirements | 要求

- iOS 15.0 or higher
- Ray-Ban Meta glasses paired via Meta View app
- iOS 15.0 或更高版本
- 通过 Meta View 应用配对的 Ray-Ban Meta 眼镜

---

## Build | 构建

\`\`\`bash
# Open Xcode project
open CameraAccess.xcodeproj

# Build and run on device
# Select your device and press Cmd+R
\`\`\`

---

## Feedback | 反馈

If you encounter any issues, especially with:
- Google Gemini Live (not fully tested)
- RTMP streaming
- Language switching

Please report issues or provide feedback.

---

## License

MIT License
