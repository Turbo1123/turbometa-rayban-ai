# 🔧 添加文件到 Xcode 项目指南

## ⚠️ 重要：必须手动添加的文件

由于 Xcode 项目文件的特殊性，你需要手动将 `APIKeyManager.swift` 文件添加到项目中。

## 📋 操作步骤

### 1. 打开项目

双击 `CameraAccess.xcodeproj` 在 Xcode 中打开项目

### 2. 添加 APIKeyManager.swift

1. **找到文件位置**
   - 在左侧项目导航器中，展开 `CameraAccess` 文件夹
   - 找到 `Utilities` 或 `Utils` 文件夹

2. **添加文件**
   - 右键点击 `Utilities` 或 `Utils` 文件夹
   - 选择 **"Add Files to \"CameraAccess\"..."**
   - 浏览并选择: `CameraAccess/Utils/APIKeyManager.swift`

3. **配置选项**（重要！）
   - ✅ **勾选** "Copy items if needed"
   - ✅ **勾选** Target "CameraAccess" (或 "TurboMeta")
   - 点击 **"Add"**

### 3. 验证文件已添加

在 Xcode 左侧导航器中，你应该能在 `Utilities` 或 `Utils` 文件夹下看到：
- ✅ `APIKeyManager.swift`
- ✅ `DesignSystem.swift`
- ✅ `TimeUtils.swift`

### 4. 编译测试

1. 按 `Cmd + B` 或点击菜单栏 **Product → Build**
2. 确保没有编译错误
3. 如果有错误，检查文件是否正确添加

## 🔍 常见问题解决

### Q: 编译时提示 "Cannot find 'APIKeyManager' in scope"

**解决方法**：
1. 在项目导航器中找到 `APIKeyManager.swift`
2. 点击该文件
3. 在右侧检查器面板，确保 **Target Membership** 中勾选了项目 target
4. Clean Build Folder (`Shift + Cmd + K`)
5. 重新编译 (`Cmd + B`)

### Q: 找不到 Utilities 文件夹

**解决方法**：
1. 在项目导航器中右键点击 `CameraAccess` 文件夹
2. 选择 **"New Group"**
3. 命名为 `Utils` 或 `Utilities`
4. 然后按照上述步骤添加文件

### Q: 文件添加后仍然报错

**解决方法**：
1. 删除 `DerivedData`：
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
2. 在 Xcode 中: **Product → Clean Build Folder** (`Shift + Cmd + K`)
3. 重启 Xcode
4. 重新编译

## ✅ 检查清单

添加文件后，请确认：

- [ ] `APIKeyManager.swift` 在项目导航器中可见
- [ ] 文件的 Target Membership 已勾选正确的 target
- [ ] 项目能成功编译（无错误）
- [ ] 运行 App 后可以在设置中看到 "API Key 管理" 选项

## 🎯 完成后的下一步

文件添加成功后：

1. **编译运行** App
2. **进入「我的」** 标签页
3. **点击「API Key 管理」**
4. **输入你的阿里云 API Key**
5. **点击「保存」**

API Key 将安全保存在 iOS Keychain 中，无需在代码中硬编码！

---

**需要帮助？** 查看 [SETUP_CN.md](SETUP_CN.md) 或主 README
