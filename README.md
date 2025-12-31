# TurboMeta - RayBan Meta 智能眼镜 AI 助手

<div align="center">

<img src="./rayban.png" width="120" alt="TurboMeta Logo"/>

**🌏 全球首个支持全中文AI的全模态 RayBan Meta 助手**

[![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://www.apple.com/ios/)
[![Android](https://img.shields.io/badge/Android-8.0%2B-green.svg)](https://www.android.com/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![Kotlin](https://img.shields.io/badge/Kotlin-1.9-purple.svg)](https://kotlinlang.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/Turbo1123/turbometa-rayban-ai)](https://github.com/Turbo1123/turbometa-rayban-ai/releases)
[![请我喝咖啡](https://img.shields.io/badge/请我喝咖啡-☕-yellow?style=flat-square)](#-请我喝杯咖啡)

**🇺🇸 [English Version / README in English](./README_EN.md)** | 简体中文

</div>

---

> 🌍 **For English speakers**: Please check [**README_EN.md**](./README_EN.md) for the English version of this documentation.

---

## 🎉 重磅更新 v1.3.0

<div align="center">

### 🌍 iOS & Android 双平台同步 + 中英文双语 + 多平台 AI

**Quick Vision 快速识图 | Live AI 实时对话 | OpenRouter & Gemini 支持**

✅ **iOS v1.3.0** | ✅ **Android v1.3.0** - 功能完全同步

</div>

### 🆕 核心功能

- 👁️ **Quick Vision 快速识图**：Siri 语音唤醒，无需解锁手机即可识别眼前物体
- 🤖 **Live AI 实时对话**：通过眼镜摄像头和麦克风进行多模态实时 AI 对话
- 🍽️ **LeanEat 营养分析**：拍照即可获得食物营养成分和健康评分

### 🌐 多语言 & 多平台

- 🌐 **中英文双语界面**：App 界面完整支持中文和英文切换
- 🔌 **OpenRouter 支持**：接入 500+ AI 模型，包括 GPT-4、Claude、Gemini 等
- 🎙️ **Google Gemini Live**：Live AI 支持 Google Gemini 实时语音对话（需海外网络）
- 🌏 **阿里云多区域**：支持北京（中国大陆）和新加坡（国际）两个服务区域
- 🔑 **独立 API Key 管理**：不同服务商和区域的 API Key 独立管理

---

## 📱 Quick Vision 快速识图

<div align="center">

### 🚀 支持后台唤醒 + Siri 语音触发！

**无需解锁手机，一句话即可让 AI 识别眼前的一切**

</div>

由于 Meta DAT SDK 的限制，App 无法在后台直接访问眼镜摄像头。我们创新性地结合了 **Siri 快捷指令 + App Intent + 阿里云 TTS** 实现了这一功能：

- 📱 **Siri 语音唤醒**：对着 iPhone 说"嘿 Siri，TurboMeta 快速识图"
- ⌚ **操作按钮触发**（iPhone 15 Pro+）：一键触发快速识图
- 🔊 **语音播报结果**：使用阿里云 qwen3-tts-flash 高品质语音播报
- 🎯 **全自动流程**：启动流 → 拍照 → 停止流 → AI 识别 → TTS 播报

👉 [查看详细使用教程](#quick-vision-tutorial)

---

## 🎨 界面预览

<table>
  <tr>
    <td align="center"><b>首页</b></td>
    <td align="center"><b>对话记录</b></td>
    <td align="center"><b>拍摄页面</b></td>
    <td align="center"><b>设置页面</b></td>
  </tr>
  <tr>
    <td><img src="./screenshots/首页.jpg" width="180"/></td>
    <td><img src="./screenshots/对话记录.jpg" width="180"/></td>
    <td><img src="./screenshots/camera.jpg" width="180"/></td>
    <td><img src="./screenshots/设置页面.jpg" width="180"/></td>
  </tr>
</table>

## 🎬 视频演示

<a href="https://www.bilibili.com/video/BV1aTqSBHEqN" target="_blank">
  <img src="https://img.shields.io/badge/Bilibili-演示视频-00A1D6?style=for-the-badge&logo=bilibili" alt="视频演示"/>
</a>

👉 <a href="https://www.bilibili.com/video/BV1aTqSBHEqN" target="_blank">在 Bilibili 观看</a>

> 💡 如果这个项目对你有帮助，欢迎[请我喝杯咖啡](#-请我喝杯咖啡) ☕

## 📥 下载安装

> **无需上架应用商店** - 直接下载安装

### ⚠️ 重要：请先开启开发者模式！

使用 TurboMeta 前，**必须**在 Meta AI App 中开启开发者模式：

1. **将 RayBan Meta 眼镜固件更新到 20 版本以上**（DAT SDK 需要）
2. **将 Meta AI App 更新到最新版本**
3. 打开手机上的 **Meta AI App**
4. 进入 **设置** → **应用信息**
5. 找到 **版本号**
6. **快速连续点击版本号 5 次**
7. 会出现"开发者模式已开启"的提示

> 不开启开发者模式，跳转 Meta AI App 时会提示异常！

---

### 📱 Android

**v1.3.0** - 已与 iOS 版本同步

👉 [**前往下载页面**](https://github.com/Turbo1123/turbometa-rayban-ai/releases)

**Android 安装步骤：**
1. 下载 APK 文件
2. 在设置中开启"允许安装未知来源应用"
3. 打开 APK 进行安装
4. 授予权限（蓝牙、麦克风）
5. 在设置中配置 API Key 👉 [查看配置教程](#api-key-config)

---

### 🍎 iOS（推荐）

> ✅ **最新版本**：iOS 版本已更新至 v1.3.0，支持中英文、OpenRouter、Gemini 等新功能

👉 [**前往下载页面**](https://github.com/Turbo1123/turbometa-rayban-ai/releases)

### 安装工具推荐

| 工具 | 平台 | 说明 |
|------|------|------|
| [爱思助手](https://www.i4.cn/) | Windows | 国内用户首选，简单易用 |
| [AltStore](https://altstore.io/) | macOS/Windows | 免费，需要 Apple ID |
| [Sideloadly](https://sideloadly.io/) | macOS/Windows | 免费，操作简单 |
| Xcode | macOS | 从源码编译安装 |

### 爱思助手安装教程（推荐）

**第一步**：打开爱思助手，选择「工具箱」→「IPA 签名」

![第一步](./i4png/第一步打开爱思选择工具ipa签名.png)

**第二步**：添加 IPA 文件，使用 Apple ID 进行签名

![第二步](./i4png/第二步用appleid进行签名.png)

**第三步**：签名完成后，回到「应用游戏」→「导入安装」，选择签名后的 IPA 安装

![第三步](./i4png/第三步.png)

**第四步**：在 iPhone 上打开 **设置 → 通用 → VPN与设备管理**，信任开发者证书

**第五步**：打开 TurboMeta，在设置中配置你的阿里云 API Key 👉 [查看配置教程](#api-key-config)

---

### 🔋 Ray-Ban Meta 电池升级 & 维修服务 <sup>`📢 广告`</sup>

> 🇨🇳 **中国用户专属福利**

很多国内朋友通过海淘购买了 Ray-Ban Meta 智能眼镜，但遇到了一些烦恼：

- 😤 **一代电池续航太短** - 用不了多久就没电，体验大打折扣
- 😰 **国内没有官方售后** - 坏了不知道找谁修，只能吃灰
- 💸 **寄回美国维修成本高** - 运费贵、周期长、还不一定能修好

**现在有解决方案了！** 一位专业维修 Ray-Ban Meta 的师傅可以帮你：

✅ **Gen1 → Gen2 电池升级** - 续航时间翻倍，告别电量焦虑
✅ **专业维修服务** - 解决各种硬件问题，让你的眼镜重获新生
✅ **国内售后保障** - 再也不用担心坏了没人修

#### 📊 续航对比：为什么要升级？

| | Gen1 原装电池 | Gen2 升级电池 |
|--|--------------|--------------|
| **眼镜单次续航** | ~4 小时 | **~8 小时** ⚡ |

> 💡 简单说：**一代换二代电池 = 续航直接翻倍**，同样的眼镜，两倍的体验！

<table>
  <tr>
    <td><img src="./ad/电池更换计划.jpg" width="220"/></td>
    <td><img src="./ad/更换后的图片.jpg" width="220"/></td>
  </tr>
</table>

| 服务项目 | 价格 |
|---------|------|
| 电池升级原价 | ~~¥299~~ |
| **Turbo 推荐价** | **¥249**（省 ¥50）|

📱 **联系方式**：添加微信 `lifesux`，备注「**Turbo推荐**」即可享受优惠价

---

## 📖 简介

TurboMeta 是专为 RayBan Meta 智能眼镜打造的全模态AI助手，集成了阿里云通义千问多模态大模型，实现了：

- 🎯 **实时AI对话**：通过眼镜摄像头和麦克风进行多模态实时交互
- 🍎 **智能营养分析**：拍摄食物即可获得详细的营养成分和健康建议
- 👁️ **图像识别**：智能识别眼前的物体、场景和文字
- 🎥 **直播推流**：支持抖音、快手、小红书等平台的直播功能
- 🌐 **完整中文支持**：全中文AI交互体验，完美适配中文用户

这是全球第一个实现**完全中文化**的 RayBan Meta AI 助手，让中文用户也能享受到智能眼镜带来的便利。

## ✨ 核心功能

### 👁️ Quick Vision - 快速识图 <sup>`NEW`</sup>
- **Siri 唤醒**：无需解锁手机，语音触发识别
- **快捷指令集成**：支持 iOS 快捷指令自动化
- **操作按钮支持**：iPhone 15 Pro 系列一键触发
- **高品质 TTS**：阿里云 qwen3-tts-flash 语音播报
- **智能识别**：基于 qwen3-vl-plus 多模态视觉理解

### 🤖 Live AI - 实时对话
- **多模态交互**：同时支持语音和视觉输入
- **实时响应**：基于通义千问 Omni-Realtime 模型，低延迟语音对话
- **场景理解**：AI 能看到你眼前的画面并提供相关建议
- **口语化回复**：自然流畅的中文对话体验
- **一键隐藏**：支持隐藏对话界面，专注于视觉体验

### 🍽️ LeanEat - 智能营养分析
- **食物识别**：拍照即可识别食物种类
- **营养成分**：详细的热量、蛋白质、脂肪、碳水化合物等数据
- **健康评分**：0-100分的健康评分系统
- **营养建议**：AI提供的个性化营养建议
- **美观界面**：精心设计的UI，清晰展示营养信息

### 📸 实时拍照
- **自动启动**：打开界面自动连接眼镜并开始预览
- **多功能集成**：拍照后可选择营养分析或AI识别
- **流畅体验**：实时视频流预览

### 🎥 直播功能
- **平台支持**：适配主流直播平台
- **简洁界面**：专注于直播内容的纯净视图

## 🛠️ 技术栈

### iOS
- **平台**：iOS 17.0+
- **语言**：Swift 5.0 + SwiftUI
- **SDK**：Meta Wearables DAT SDK v0.3.0
- **架构**：MVVM + Combine
- **音频**：AVAudioEngine + AVAudioPlayerNode

### Android
- **平台**：Android 8.0+ (API 26)
- **语言**：Kotlin 1.9 + Jetpack Compose
- **SDK**：Meta Wearables DAT SDK v0.3.0
- **架构**：MVVM + StateFlow
- **UI**：Material 3 Design

### AI 模型
- **通义千问 Omni-Realtime**：实时多模态对话
- **通义千问 VL-Plus**：视觉理解和图像分析
- **通义千问 TTS-Flash**：高品质中文语音合成

## 📋 前置要求

### 硬件要求
- ✅ RayBan Meta 智能眼镜（Stories 或最新款）
- ✅ iPhone（iOS 17.0 或更高版本）
- ✅ 稳定的网络连接

### 软件要求
- ✅ Xcode 15.0 或更高版本
- ✅ Meta View App（用于配对眼镜）
- ✅ 阿里云账号（申请 API）

### API 要求
需要申请以下阿里云 API：
1. **通义千问 Omni-Realtime API**：用于实时对话
2. **通义千问 VL-Plus API**：用于图像识别和营养分析

👉 [前往阿里云百炼申请 API](https://www.aliyun.com/product/bailian) | [百炼控制台](https://bailian.console.aliyun.com/)

## 🚀 安装指南

### 步骤 1：开启 RayBan Meta 开发者模式

⚠️ **重要**：由于当前处于 Preview 阶段，必须开启开发者模式才能使用。

1. 在 iPhone 上打开 **Meta View App**（或 **Meta AI App**）
2. 进入 **设置** → **应用信息** 或 **关于**
3. 找到 **版本号**
4. **连续点击版本号 5 次**
5. 会出现"开发者模式已开启"的提示

### 步骤 2：配置 API Key

详细配置教程请参考 👉 [API Key 配置说明](#api-key-config)

简要步骤：
1. 前往 [阿里云百炼](https://www.aliyun.com/product/bailian) 注册账号
2. 登录 [百炼控制台](https://bailian.console.aliyun.com/) → API-KEY 管理 → 创建 API Key
3. 在 App「设置」→「API Key 管理」中输入你的 API Key

### 步骤 3：编译项目

1. 用 Xcode 打开 `CameraAccess.xcodeproj`
2. 选择你的开发团队（Team）
3. 修改 Bundle Identifier（如果需要）
4. 连接你的 iPhone
5. 点击 **Run** 或按 `Cmd + R`

### 步骤 4：签名和安装

#### 方法 A：使用 Xcode 直接安装（推荐）
1. 在 Xcode 中选择你的 iPhone 设备
2. 点击 Run 按钮
3. 首次运行需要在 iPhone 设置中信任开发者

#### 方法 B：导出 IPA 并自签名
1. 在 Xcode 中选择 **Product** → **Archive**
2. 导出 IPA 文件
3. 使用 AltStore、Sideloadly 或其他工具进行签名安装

```bash
# 使用 ios-deploy (需要安装)
brew install ios-deploy
ios-deploy --bundle YourApp.app
```

### 步骤 5：配对眼镜

1. 打开 Meta View App
2. 配对你的 RayBan Meta 眼镜
3. 确保蓝牙已开启
4. 返回 TurboMeta App，等待连接成功

## 📱 使用指南

### 首次使用

1. 启动 TurboMeta App
2. 确保 RayBan Meta 眼镜已配对并开启
3. 等待设备连接（顶部会显示连接状态）
4. 选择你想使用的功能

### Live AI 实时对话

1. 点击首页的 **Live AI** 卡片
2. 等待连接成功（右上角显示绿点）
3. 开始说话，AI 会实时回复
4. AI 可以看到你眼前的画面
5. 点击 👁️ 按钮可以隐藏对话记录

**使用技巧**：
- 说话清晰，保持适当距离
- 可以问"你看到了什么？"让 AI 描述画面
- AI 会用简练的中文回答

### LeanEat 营养分析

1. 点击首页的 **LeanEat** 卡片
2. 对准食物，点击拍照按钮 📷
3. 在照片预览中点击 **营养分析**
4. 等待 AI 分析完成
5. 查看营养成分、健康评分和建议

**使用场景**：
- 餐前拍照，了解营养成分
- 健身减脂时记录每日摄入
- 学习食物的营养知识

### 直播功能

1. 点击首页的 **直播** 卡片
2. 等待视频流启动
3. 进行直播内容创作
4. 点击停止按钮结束直播

---

<a id="quick-vision-tutorial"></a>

## 👁️ Quick Vision 快速识图使用教程

Quick Vision 让你可以通过 Siri 或快捷指令，在不解锁手机的情况下快速识别眼前的物体。

### 📋 前置准备

1. ✅ 确保已安装 TurboMeta App 并配置好 API Key
2. ✅ 确保 RayBan Meta 眼镜已配对并开启
3. ✅ 首次使用需要打开一次 TurboMeta App 完成初始化

### 🔧 设置快捷指令

#### 方式一：Siri 语音触发

1. 打开 iPhone 的 **快捷指令** App
2. 点击右上角 **+** 创建新快捷指令
3. 点击 **添加操作**
4. 搜索 **TurboMeta** 或 **Turbo Meta**
5. 选择 **快速识图** 操作
6. 点击顶部的快捷指令名称，重命名为你喜欢的名字（如"识图"、"看看这是什么"）
7. 点击 **完成** 保存

**使用方法**：
- 说 "嘿 Siri，识图"（或你设置的快捷指令名称）
- AI 会自动拍照、识别、并语音播报结果

<details>
<summary>📸 点击查看设置截图</summary>

1. 在快捷指令 App 中搜索 TurboMeta
2. 添加"快速识图"操作
3. 重命名快捷指令

</details>

#### 方式二：iPhone 15 Pro 操作按钮

如果你使用 iPhone 15 Pro / 15 Pro Max / 16 系列，可以将快速识图绑定到操作按钮：

1. 打开 **设置** → **操作按钮**（或 **按钮** → **操作按钮**）
2. 选择 **快捷指令**
3. 选择你创建的 TurboMeta 快速识图快捷指令
4. 完成设置

**使用方法**：
- 长按操作按钮即可触发快速识图
- 无需解锁手机，戴着眼镜即可使用

#### 方式三：锁屏小组件

1. 长按锁屏界面进入编辑模式
2. 点击 **自定义**
3. 在锁屏小组件区域添加 **快捷指令**
4. 选择 TurboMeta 快速识图快捷指令
5. 点击完成

**使用方法**：
- 在锁屏界面直接点击小组件即可触发

### 🎯 Quick Vision 工作流程

```
Siri/快捷指令触发
      ↓
  启动视频流
      ↓
  自动拍摄照片
      ↓
  停止视频流
      ↓
  AI 图像识别 (qwen3-vl-plus)
      ↓
  TTS 语音播报 (qwen3-tts-flash)
```

### 💡 使用技巧

- **确保眼镜已开启**：触发前确保眼镜没有在充电盒中
- **保持稳定**：拍照时尽量保持头部稳定
- **光线充足**：在光线良好的环境下识别效果更好
- **等待播报**：识别需要几秒钟，请耐心等待语音播报

### ⚠️ 常见问题

**Q: 为什么提示"眼镜未连接"？**
- 确保眼镜已开启且与 Meta View App 配对
- 确保开发者模式已开启
- 尝试重新打开 TurboMeta App

**Q: 为什么没有声音？**
- 检查手机是否静音
- 检查蓝牙音频输出设置
- TTS 使用的是阿里云服务，需要网络连接

**Q: 快捷指令中找不到 TurboMeta？**
- 首次安装后需要打开一次 TurboMeta App
- 尝试重启手机

---

## ⚙️ 配置选项

### API 配置

在 `VisionAPIConfig.swift` 中配置：

```swift
struct VisionAPIConfig {
    // 阿里云 API Key
    static let apiKey = "sk-YOUR-API-KEY-HERE"

    // API 基础 URL（通常不需要修改）
    static let baseURL = "https://dashscope.aliyuncs.com"
}
```

### 系统提示词

可以在 `OmniRealtimeService.swift` 中自定义 AI 的回复风格：

```swift
"instructions": "你是RayBan Meta智能眼镜AI助手。回答要简练、口语化..."
```

## 🔧 常见问题

### Q1: 眼镜连接不上怎么办？

**解决方案**：
1. 确保眼镜已在 Meta View App 中配对成功
2. 检查蓝牙是否开启
3. 重启 TurboMeta App
4. 重启眼镜（放入眼镜盒充电仓）
5. 确保已开启开发者模式

### Q2: AI 没有回复或回复很慢？

**解决方案**：
1. 检查网络连接是否稳定
2. 确认 API Key 是否正确配置
3. 查看阿里云 API 额度是否充足
4. 检查控制台日志排查错误

### Q3: 营养分析结果不准确？

**解决方案**：
1. 确保食物拍摄清晰
2. 尽量在良好光线下拍摄
3. 食物尽量完整展示在画面中
4. AI 分析仅供参考，不能替代专业营养师

### Q4: 无法安装到手机？

**解决方案**：
1. 检查 iPhone 是否在信任的设备列表中
2. 确认开发者证书是否有效
3. 修改 Bundle Identifier 避免冲突
4. 使用免费的 Apple Developer 账号每 7 天需重新签名

### Q5: 语音识别不准确？

**解决方案**：
1. 确保环境相对安静
2. 说话清晰，语速适中
3. 麦克风不要被遮挡
4. 当前主要优化了中文，其他语言可能不太准确

## 🔒 隐私和安全

- ✅ 所有音视频数据仅用于 AI 处理
- ✅ 不会存储或上传用户隐私数据
- ✅ API 通信使用 HTTPS 加密
- ✅ 图片和语音仅在会话期间保留
- ✅ 遵循苹果和 Meta 的隐私政策

## 🗺️ 开发路线图

### ✅ 已完成
- [x] Live AI 实时对话
- [x] LeanEat 营养分析
- [x] 图像识别
- [x] 基础直播功能
- [x] 中英文双语支持
- [x] 对话记录保存
- [x] 一键隐藏对话
- [x] **Android 版本发布** 🎉
- [x] **Quick Vision 快速识图** 🆕
  - [x] Siri 快捷指令集成
  - [x] App Intent 支持
  - [x] 阿里云 TTS 语音播报
  - [x] iPhone 操作按钮支持

### 🚧 进行中
- [ ] 完善多语言支持
- [ ] 优化 UI/UX
- [ ] 性能优化

### 📅 计划中
- [ ] 实时翻译功能
- [ ] WordLearn 单词学习
- [ ] 云端同步对话记录
- [ ] 更多直播平台支持
- [ ] 离线模式
- [ ] Apple Watch 配套应用
- [ ] Android Quick Vision 支持

## 🤝 贡献

欢迎贡献代码、报告 Bug 或提出新功能建议！

1. Fork 本项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目基于 Meta Platforms, Inc. 的原始代码修改而来，遵循原项目的许可证。

部分代码版权归 Meta Platforms, Inc. 及其关联公司所有。

请参阅 [LICENSE](LICENSE) 文件了解详细信息。

## 🙏 致谢

- **Meta Platforms, Inc.** - 提供 DAT SDK 和原始示例代码
- **阿里云通义千问团队** - 提供强大的多模态 AI 能力
- **RayBan** - 出色的智能眼镜硬件

## 🚀 如何开源此项目

### 1. 创建 GitHub 仓库

```bash
# 在 GitHub 网站上创建新仓库
# 然后在项目目录执行：
git init
git add .
git commit -m "Initial commit: TurboMeta - RayBan Meta AI Assistant"
git branch -M main
git remote add origin https://github.com/你的用户名/仓库名.git
git push -u origin main
```

### 2. 保护敏感信息

✅ **已完成的安全措施**：
- API Key 不再硬编码在代码中
- 使用 iOS Keychain 安全存储用户的 API Key
- 用户需在 App 内「设置」中自行配置

⚠️ **发布前检查**：
```bash
# 搜索可能残留的敏感信息
grep -r "sk-" .
grep -r "API" . | grep -i "key"
```

### 3. 添加 .gitignore 文件

在项目根目录创建 `.gitignore` 文件：

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
*.ipa
*.xcuserstate
*.xcworkspace

# API Keys (额外保护)
**/*APIKey*.swift
**/APIKeys.swift
**/*Secret*.swift

# macOS
.DS_Store
```

### 4. 选择开源协议

本项目基于 Meta DAT SDK 示例代码，遵循原项目许可证。你可以：
- 保持与 Meta 相同的许可证
- 为你的代码部分选择 MIT、Apache 2.0 等许可证
- 在 LICENSE 文件中注明原始代码来源

<a id="api-key-config"></a>
### 5. 用户配置说明

⚠️ **重要提示**：使用本项目的用户需要配置阿里云 API Key：

#### 第一步：注册阿里云账号
前往 [阿里云百炼](https://www.aliyun.com/product/bailian) 注册账号

#### 第二步：获取 API Key
1. 登录 [百炼控制台](https://bailian.console.aliyun.com/)
2. 在左侧菜单找到「**API-KEY 管理**」
3. 点击「**创建 API Key**」生成密钥
4. 复制生成的 API Key

#### 第三步：在 App 中配置
1. 打开 TurboMeta App
2. 进入「**设置**」→「**API Key 管理**」
3. 粘贴你的 API Key 并保存

> 🔒 **安全说明**：API Key 在 iOS 上存储于 Keychain，在 Android 上使用 EncryptedSharedPreferences 加密存储，不会泄露

## 🌟 如果这个项目对你有帮助

- ⭐️ 给项目点个 Star
- 🐛 报告 Bug 或提出建议
- 🔀 Fork 并贡献代码
- 📢 分享给更多人

## ☕ 请我喝杯咖啡

如果这个项目对你有帮助，欢迎请我喝杯咖啡！

<div align="center">
<img src="./screenshots/请我喝咖啡.png" width="200" alt="微信支付"/>

**微信支付**
</div>

---

<div align="center">

**让智能眼镜说中文 🇨🇳**

Made with ❤️ for RayBan Meta Users

</div>
