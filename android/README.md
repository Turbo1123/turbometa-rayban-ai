# TurboMeta Ray-Ban AI - Android

**Version 1.3.0** - Synced with iOS

Ray-Ban Meta 智能眼镜 AI 助手 Android 版本。

## Features | 功能

### Live AI | 实时 AI 对话
- Real-time voice conversation with AI through Ray-Ban Meta glasses
- Supports Alibaba Qwen Omni and Google Gemini Live
- 通过 Ray-Ban Meta 眼镜与 AI 进行实时语音对话
- 支持阿里云通义千问 Omni 和 Google Gemini Live

### Quick Vision | 快速识图
- Take photos with glasses and get AI analysis
- Wake word detection: Say "Jarvis" to trigger Quick Vision
- 用眼镜拍照并获取 AI 分析
- 唤醒词检测：说 "Jarvis" 触发快速识图

### Multi-Provider Support | 多提供商支持
- **Vision API**: Alibaba Dashscope / OpenRouter (Gemini, Claude, etc.)
- **Live AI**: Alibaba Qwen Omni / Google Gemini Live
- **视觉 API**: 阿里云 Dashscope / OpenRouter (Gemini, Claude 等)
- **实时 AI**: 阿里云通义千问 Omni / Google Gemini Live

---

## ⚠️ Important Notes | 重要说明

### Wake Word Detection (Picovoice) | 唤醒词检测

The wake word detection feature ("Jarvis") uses **Picovoice Porcupine**. To use this feature:

唤醒词检测功能（"Jarvis"）使用 **Picovoice Porcupine**。使用此功能需要：

1. **Register at Picovoice Console | 注册 Picovoice 账号**
   - Go to https://console.picovoice.ai/
   - Create a free account
   - 访问 https://console.picovoice.ai/
   - 创建免费账号

2. **Get Access Key | 获取 Access Key**
   - After registration, get your Access Key from the console
   - 注册后，从控制台获取 Access Key

3. **Configure in App | 在 App 中配置**
   - Go to Settings → Quick Vision → Picovoice Access Key
   - Enter your Access Key
   - 进入 设置 → 快速识图 → Picovoice Access Key
   - 输入你的 Access Key

4. **⚠️ Microphone Always On | 麦克风常开**
   - Wake word detection requires the microphone to be always listening
   - This runs as a foreground service with a notification
   - Battery optimization should be disabled for best performance
   - 唤醒词检测需要麦克风一直处于监听状态
   - 这会作为前台服务运行，并显示通知
   - 建议关闭电池优化以获得最佳体验

### Google Gemini Live | Google Gemini Live

⚠️ **Not Fully Tested | 未完全测试**

- Google Gemini Live has not been fully tested due to limited access
- If you encounter issues, please provide feedback
- Google Gemini Live 由于条件限制未能完全测试
- 如遇问题，请反馈

---

## Release Notes | 更新日志

### v1.3.0 (2024-12-31)

#### New Features | 新功能

- **Wake Word Detection | 唤醒词检测**
  - Say "Jarvis" to trigger Quick Vision without touching the phone
  - Powered by Picovoice Porcupine
  - 说 "Jarvis" 触发快速识图，无需触摸手机
  - 基于 Picovoice Porcupine

- **Vision Model Selection | 视觉模型选择**
  - Choose from multiple vision models
  - Alibaba: Qwen VL Flash/Plus/Max, Qwen 2.5 VL 72B
  - OpenRouter: Search and select from all available models
  - Filter by vision-capable models
  - 支持选择多种视觉模型
  - 阿里云: Qwen VL Flash/Plus/Max, Qwen 2.5 VL 72B
  - OpenRouter: 搜索并选择所有可用模型
  - 可筛选仅显示视觉模型

- **App Language | 应用语言**
  - Switch app interface language (System/Chinese/English)
  - Auto-syncs output language when switching
  - 切换应用界面语言（跟随系统/中文/英文）
  - 切换时自动同步输出语言

#### Improvements | 改进

- **Quick Vision Flow | 快速识图流程**
  - Optimized capture flow: TTS → Start stream → Capture → Stop stream → Analyze → TTS result
  - Added debounce for wake word (prevents multiple triggers)
  - 优化拍照流程：TTS → 启动流 → 拍照 → 停止流 → 分析 → TTS 结果
  - 添加唤醒词防抖（防止多次触发）

- **Bilingual Support | 双语支持**
  - Full English/Chinese translation for all UI elements
  - AI prompts follow output language setting
  - 所有界面元素支持中英文
  - AI 提示词跟随输出语言设置

- **Default Models | 默认模型**
  - Alibaba: qwen-vl-flash (fast response)
  - OpenRouter: google/gemini-2.0-flash-001
  - 阿里云: qwen-vl-flash（快速响应）
  - OpenRouter: google/gemini-2.0-flash-001

#### Bug Fixes | 修复

- Fixed language switching not taking effect
- Fixed hardcoded Chinese strings in various screens
- Fixed Live AI reconnection issues
- 修复语言切换不生效的问题
- 修复多处界面硬编码中文
- 修复 Live AI 重连问题

---

## Setup | 配置

### API Keys | API 密钥

1. **Alibaba Dashscope** (for Vision & Live AI)
   - Get API Key: https://help.aliyun.com/zh/model-studio/get-api-key

2. **OpenRouter** (for Vision with various models)
   - Get API Key: https://openrouter.ai/keys

3. **Google AI Studio** (for Gemini Live)
   - Get API Key: https://aistudio.google.com/apikey

4. **Picovoice** (for Wake Word Detection)
   - Get Access Key: https://console.picovoice.ai/

---

## Requirements | 要求

- Android 8.0 (API 26) or higher
- Ray-Ban Meta glasses paired via Meta View app
- Android 8.0 (API 26) 或更高版本
- 通过 Meta View 应用配对的 Ray-Ban Meta 眼镜

---

## Build | 构建

```bash
# Debug build
./gradlew assembleDebug

# Release build
./gradlew assembleRelease

# Install to device
./gradlew installDebug
```

---

## Feedback | 反馈

If you encounter any issues, especially with:
- Google Gemini Live (not fully tested)
- Wake word detection
- Language switching

Please report issues or provide feedback.

如遇到任何问题，特别是：
- Google Gemini Live（未完全测试）
- 唤醒词检测
- 语言切换

请反馈问题或提供建议。

---

## License

MIT License
