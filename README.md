# TurboMeta - RayBan Meta Smart Glasses AI Assistant

<div align="center">

<img src="./rayban.png" width="120" alt="TurboMeta Logo"/>

**🌏 World's First Full-Chinese AI Multimodal RayBan Meta Assistant**

[![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://www.apple.com/ios/)
[![Android](https://img.shields.io/badge/Android-8.0%2B-green.svg)](https://www.android.com/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![Kotlin](https://img.shields.io/badge/Kotlin-1.9-purple.svg)](https://kotlinlang.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/Turbo1123/turbometa-rayban-ai)](https://github.com/Turbo1123/turbometa-rayban-ai/releases)

[English](./README.md) | [简体中文](./README_CN.md)

</div>

## 🎨 Interface Preview

<table>
  <tr>
    <td align="center"><b>首页</b><br/>Home</td>
    <td align="center"><b>对话记录</b><br/>Live AI</td>
    <td align="center"><b>拍摄页面</b><br/>Camera</td>
    <td align="center"><b>设置页面</b><br/>Settings</td>
  </tr>
  <tr>
    <td><img src="./首页.jpg" width="180"/></td>
    <td><img src="./对话记录.jpg" width="180"/></td>
    <td><img src="./拍摄页面.jpg" width="180"/></td>
    <td><img src="./设置页面.jpg" width="180"/></td>
  </tr>
</table>

## 📥 Download

> **No App Store / Google Play** - Install directly using methods below

### 📱 Android (Recommended)

| Version | Download | Size |
|---------|----------|------|
| v1.0.0 | [**TurboMeta-v1.0.0.apk**](https://github.com/Turbo1123/turbometa-rayban-ai/releases/tag/v1.0.0) | 77 MB |

**Android Installation:**
1. Download APK file
2. Enable "Install from unknown sources" in Settings
3. Open APK to install
4. Grant permissions (Bluetooth, Microphone)
5. Configure API Key in Settings

---

### 🍎 iOS

| Version | Download | Size |
|---------|----------|------|
| v1.0.0 | [****](https://github.com/Turbo1123/turbometa-rayban-ai/releases/tag/v1.0.0) | 6.0 MB |

**iOS Installation Methods:**

| Tool | Platform | Description |
|------|----------|-------------|
| [](https:///) | macOS/Windows | Free, requires Apple ID |
| [](https:///) | macOS/Windows | Free, easy to use |
| [ ()](https://www.i4.cn/) | Windows | Chinese users recommended |
| Xcode | macOS | Build from source code |

###  Installation Guide (Recommended for Windows)

**Step 1**: Open , go to "Toolbox" → "IPA Signature"

![Step 1](.//.png)

**Step 2**: Add IPA file and sign with your Apple ID

![Step 2](.//.png)

**Step 3**: After signing, go to "Apps" → "Import & Install", select the signed IPA

![Step 3](.//.png)

**Step 4**: On iPhone, go to **Settings → General → VPN & Device Management**, trust the developer certificate

**Step 5**: Open TurboMeta and configure your Alibaba Cloud API Key in Settings

## 📖 Introduction

TurboMeta is a full-featured multimodal AI assistant built exclusively for RayBan Meta smart glasses, powered by Alibaba Cloud's Qwen multimodal AI models:

- 🎯 **Live AI Conversations**: Real-time multimodal interaction through glasses camera and microphone
- 🍎 **Smart Nutrition Analysis**: Capture food photos and get detailed nutritional information and health recommendations
- 👁️ **Image Recognition**: Intelligently identify objects, scenes, and text in your field of view
- 🎥 **Live Streaming**: Stream directly to platforms like Douyin, Kuaishou, and Xiaohongshu
- 🌐 **Full Chinese Support**: Complete Chinese AI interaction experience, perfectly tailored for Chinese users

This is the world's first **fully Chinese-enabled** RayBan Meta AI assistant, bringing the convenience of smart glasses to Chinese-speaking users.

## ✨ Core Features

### 🤖 Live AI - Real-time Conversations
- **Multimodal Interaction**: Simultaneous voice and visual input support
- **Real-time Response**: Based on Qwen Omni-Realtime model with low-latency voice conversations
- **Scene Understanding**: AI can see what's in front of you and provide relevant suggestions
- **Natural Responses**: Smooth and natural Chinese conversation experience
- **One-tap Hide**: Support for hiding conversation interface to focus on visual experience

### 🍽️ LeanEat - Smart Nutrition Analysis
- **Food Recognition**: Identify food types by taking photos
- **Nutritional Content**: Detailed data on calories, protein, fat, carbohydrates, etc.
- **Health Scoring**: Health scoring system from 0-100
- **Nutrition Advice**: Personalized nutritional recommendations from AI
- **Beautiful Interface**: Carefully designed UI with clear nutritional information display

### 📸 Real-time Photography
- **Auto-start**: Automatically connects to glasses and starts preview when opened
- **Multi-function Integration**: Choose nutrition analysis or AI recognition after taking photos
- **Smooth Experience**: Real-time video stream preview

### 🎥 Live Streaming
- **Platform Support**: Compatible with mainstream live streaming platforms
- **Clean Interface**: Pure view focused on streaming content

## 🛠️ Tech Stack

### iOS
- **Platform**: iOS 17.0+
- **Language**: Swift 5.0 + SwiftUI
- **SDK**: Meta Wearables DAT SDK v0.3.0
- **Architecture**: MVVM + Combine
- **Audio**: AVAudioEngine + AVAudioPlayerNode

### Android
- **Platform**: Android 8.0+ (API 26)
- **Language**: Kotlin 1.9 + Jetpack Compose
- **SDK**: Meta Wearables DAT SDK v0.3.0
- **Architecture**: MVVM + StateFlow
- **UI**: Material 3 Design

### AI Models
- **Qwen Omni-Realtime**: Real-time multimodal conversations
- **Qwen VL-Plus**: Visual understanding and image analysis

## 📋 Requirements

### Hardware Requirements
- ✅ RayBan Meta Smart Glasses (Stories or latest model)
- ✅ iPhone (iOS 17.0+) or Android phone (8.0+)
- ✅ Stable internet connection

### Software Requirements
- ✅ Meta View App / Meta AI App (for pairing glasses)
- ✅ Alibaba Cloud account (for API access)
- ✅ Xcode 15.0+ (iOS development)
- ✅ Android Studio (Android development)

### API Requirements
You need to apply for the following Alibaba Cloud APIs:
1. **Qwen Omni-Realtime API**: For real-time conversations
2. **Qwen VL-Plus API**: For image recognition and nutrition analysis

👉 [Apply for APIs at Alibaba Cloud](https://dashscope.aliyun.com/)

## 🚀 Installation Guide

### Step 1: Enable RayBan Meta Developer Mode

⚠️ **Important**: Since this is currently in Preview phase, you must enable developer mode to use it.

1. Open **Meta View App** (or **Meta AI App**) on your iPhone
2. Go to **Settings** → **App Info** or **About**
3. Find **Version Number**
4. **Tap the version number 5 times consecutively**
5. You'll see a "DAT SDK Preview Mode enabled" message

### Step 2: Configure API Key

1. Go to [Alibaba Cloud DashScope](https://dashscope.aliyun.com/)
2. Log in and create an API Key
3. Open `VisionAPIConfig.swift` in the project
4. Replace with your API Key:

```swift
struct VisionAPIConfig {
    static let apiKey = "sk-YOUR-API-KEY-HERE"
}
```

### Step 3: Build the Project

1. Open `CameraAccess.xcodeproj` with Xcode
2. Select your development team (Team)
3. Modify Bundle Identifier (if needed)
4. Connect your iPhone
5. Click **Run** or press `Cmd + R`

### Step 4: Signing and Installation

#### Method A: Direct Installation with Xcode (Recommended)
1. Select your iPhone device in Xcode
2. Click the Run button
3. First-time run requires trusting the developer in iPhone Settings

#### Method B: Export IPA and Self-Sign
1. In Xcode, select **Product** → **Archive**
2. Export the IPA file
3. Use , , or other tools to 

```bash
# Using ios-deploy (requires installation)
brew install ios-deploy
ios-deploy --bundle YourApp.app
```

### Step 5: Pair Your Glasses

1. Open Meta View App
2. Pair your RayBan Meta glasses
3. Ensure Bluetooth is enabled
4. Return to TurboMeta App and wait for connection success

## 📱 Usage Guide

### First-time Use

1. Launch TurboMeta App
2. Ensure RayBan Meta glasses are paired and turned on
3. Wait for device connection (status shown at top)
4. Select the feature you want to use

### Live AI Real-time Conversations

1. Tap the **Live AI** card on the home screen
2. Wait for connection success (green dot in upper right)
3. Start speaking, AI will respond in real-time
4. AI can see what's in front of you
5. Tap the 👁️ button to hide conversation history

**Tips**:
- Speak clearly and maintain appropriate distance
- Ask "What do you see?" to have AI describe the scene
- AI responds in concise Chinese

### LeanEat Nutrition Analysis

1. Tap the **LeanEat** card on the home screen
2. Point at food and tap the camera button 📷
3. In photo preview, tap **Nutrition Analysis**
4. Wait for AI analysis to complete
5. View nutritional content, health score, and recommendations

**Use Cases**:
- Take photos before meals to understand nutritional content
- Track daily intake when on a fitness diet
- Learn about food nutrition

### Live Streaming

1. Tap the **Live Stream** card on the home screen
2. Wait for video stream to start
3. Create your streaming content
4. Tap stop button to end the stream

## ⚙️ Configuration Options

### API Configuration

Configure in `VisionAPIConfig.swift`:

```swift
struct VisionAPIConfig {
    // Alibaba Cloud API Key
    static let apiKey = "sk-YOUR-API-KEY-HERE"

    // API Base URL (usually doesn't need modification)
    static let baseURL = "https://dashscope.aliyuncs.com"
}
```

### System Prompts

Customize AI response style in `OmniRealtimeService.swift`:

```swift
"instructions": "You are a RayBan Meta smart glasses AI assistant. Keep answers concise and conversational..."
```

## 🔧 Troubleshooting

### Q1: Glasses won't connect?

**Solutions**:
1. Ensure glasses are successfully paired in Meta View App
2. Check if Bluetooth is enabled
3. Restart TurboMeta App
4. Restart glasses (place in charging case)
5. Ensure developer mode is enabled

### Q2: AI not responding or responding slowly?

**Solutions**:
1. Check if internet connection is stable
2. Verify API Key is correctly configured
3. Check if Alibaba Cloud API quota is sufficient
4. Review console logs for errors

### Q3: Nutrition analysis results inaccurate?

**Solutions**:
1. Ensure food photos are clear
2. Take photos in good lighting
3. Show food completely in frame
4. AI analysis is for reference only, not a substitute for professional nutritionists

### Q4: Cannot install on phone?

**Solutions**:
1. Check if iPhone is in trusted devices list
2. Verify developer certificate is valid
3. Modify Bundle Identifier to avoid conflicts
4. Free Apple Developer accounts require re-signing every 7 days

### Q5: Voice recognition inaccurate?

**Solutions**:
1. Ensure environment is relatively quiet
2. Speak clearly at moderate speed
3. Don't obstruct the microphone
4. Currently optimized for Chinese, other languages may be less accurate

## 🔒 Privacy and Security

- ✅ All audio/video data is only used for AI processing
- ✅ No storage or upload of user privacy data
- ✅ API communications use HTTPS encryption
- ✅ Images and voice are retained only during session
- ✅ Complies with Apple and Meta privacy policies

## 🗺️ Roadmap

### ✅ Completed
- [x] Live AI real-time conversations
- [x] LeanEat nutrition analysis
- [x] Image recognition
- [x] Basic live streaming functionality
- [x] Bilingual Chinese/English support
- [x] Conversation history saving
- [x] One-tap hide conversations
- [x] **Android version released** 🎉

### 🚧 In Progress
- [ ] Improve multilingual support
- [ ] Optimize UI/UX
- [ ] Performance optimization

### 📅 Planned
- [ ] Real-time translation feature
- [ ] WordLearn vocabulary learning
- [ ] Cloud conversation sync
- [ ] More live streaming platform support
- [ ] Offline mode
- [ ] Apple Watch companion app

## 🤝 Contributing

Contributions, bug reports, and feature suggestions are welcome!

1. Fork this project
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is based on modifications of original code from Meta Platforms, Inc. and follows the original project's license.

Some code copyright belongs to Meta Platforms, Inc. and its affiliates.

Please see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Meta Platforms, Inc.** - For providing DAT SDK and original sample code
- **Alibaba Cloud Qwen Team** - For powerful multimodal AI capabilities
- **RayBan** - For excellent smart glasses hardware

## 🚀 How to Open Source This Project

### 1. Create GitHub Repository

```bash
# Create a new repository on GitHub website
# Then execute in your project directory:
git init
git add .
git commit -m "Initial commit: TurboMeta - RayBan Meta AI Assistant"
git branch -M main
git remote add origin https://github.com/your-username/your-repo.git
git push -u origin main
```

### 2. Protect Sensitive Information

✅ **Security Measures Implemented**:
- API Keys are no longer hardcoded in the source code
- Uses iOS Keychain for secure storage of user API Keys
- Users configure their own API Keys in the App Settings

⚠️ **Pre-release Checklist**:
```bash
# Search for potential sensitive information
grep -r "sk-" .
grep -r "API" . | grep -i "key"
```

### 3. Add .gitignore File

Create a `.gitignore` file in project root:

```gitignore
# Xcode
build/
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
xcuserdata/
*.xccheckout
*.moved-aside
DerivedData/
*.hmap

*.xcuserstate
*.xcworkspace

# API Keys (extra protection)
**/*APIKey*.swift
**/APIKeys.swift
**/*Secret*.swift

# macOS
.DS_Store
```

### 4. Choose Open Source License

This project is based on Meta DAT SDK sample code and follows the original project's license. You can:
- Keep the same license as Meta's original project
- Choose MIT, Apache 2.0, or other permissive licenses for your code
- Acknowledge the original source code in the LICENSE file

### 5. User Configuration Instructions

⚠️ **Important Notice**: Users of this project need to:

1. **Apply for API Key**: Visit [Alibaba Cloud DashScope](https://dashscope.aliyun.com/)
2. **Configure API Key**: Enter in App Settings → API Key Management
3. **API Key Security**: Stored securely in iOS Keychain, never exposed

## 🌟 If This Project Helps You

- ⭐️ Star the project
- 🐛 Report bugs or suggest features
- 🔀 Fork and contribute code
- 📢 Share with others

## ☕ Buy Me a Coffee

如果这个项目对你有帮助，欢迎请我喝杯咖啡！

If this project helps you, consider buying me a coffee!

<div align="center">
<img src="./请我喝咖啡.png" width="200" alt="WeChat Pay"/>

**WeChat Pay / 微信支付**
</div>

---

<div align="center">

**Making Smart Glasses Speak Chinese 🇨🇳**

Made with ❤️ for RayBan Meta Users

</div>
