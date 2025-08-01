# Android Studio安装与AVD模拟器创建指南

## 1. 安装Android Studio

### 1.1 下载Android Studio
1. 访问Android Studio官网：https://developer.android.com/studio
2. 点击"Download Android Studio"按钮
3. 下载适用于Windows的安装包（.exe文件）

### 1.2 安装步骤
1. 双击下载的安装包启动安装向导<mcreference link="https://cloud.tencent.cn/developer/article/2499905?frompage=seopage&policyId=20240001&traceId=01jwwmytb6a2rhq0zmxn31cqas" index="5">5</mcreference>
2. 点击"Next"继续
3. 在组件选择界面，确保勾选以下选项：
   - Android Studio (IDE)
   - Android SDK
   - Android Virtual Device (用于创建模拟器)
4. 点击"Next"继续
5. 选择安装路径（建议安装在非系统盘，如D:\Android\AndroidStudio）
6. 点击"Next"继续
7. 点击"Install"开始安装
8. 等待安装完成
9. 安装完成后，取消勾选"Start Android Studio"，点击"Finish"退出安装向导<mcreference link="https://cloud.tencent.cn/developer/article/2499905?frompage=seopage&policyId=20240001&traceId=01jwwmytb6a2rhq0zmxn31cqas" index="5">5</mcreference>

## 2. 配置Android Studio

### 2.1 首次启动配置
1. 启动Android Studio
2. 在欢迎界面选择"Configure" → "SDK Manager"
3. 在SDK Platforms选项卡中，确保安装了所需的Android版本（建议安装Android 13/API 33）
4. 在SDK Tools选项卡中，确保以下组件已安装：
   - Android SDK Build-Tools
   - Android Emulator
   - Android SDK Platform-Tools
   - Intel x86 Emulator Accelerator (HAXM installer) - 仅适用于Intel处理器

## 3. 创建AVD模拟器

### 3.1 通过AVD Manager创建
1. 在Android Studio欢迎界面，点击"Configure" → "AVD Manager"<mcreference link="https://blog.csdn.net/qq_39154376/article/details/107871804" index="1">1</mcreference>
2. 点击"Create Virtual Device"按钮<mcreference link="https://blog.csdn.net/qq_39154376/article/details/107871804" index="1">1</mcreference>
3. 选择设备类型（建议选择Pixel系列）
4. 点击"Next"
5. 选择系统镜像：
   - 选择API Level 33 (Android 13)
   - 选择ABI为x86_64
   - Target选择Google APIs或Google Play
6. 点击"Next"
7. 设置AVD名称（如CardMindAVD）
8. 根据需要调整内存和存储设置
9. 点击"Finish"完成创建<mcreference link="https://blog.csdn.net/qq_39154376/article/details/107871804" index="1">1</mcreference>

### 3.2 启动模拟器
1. 在AVD Manager中，找到刚创建的AVD
2. 点击绿色的播放按钮启动模拟器
3. 等待模拟器启动完成

## 4. 使用模拟器打包应用

模拟器启动后，可以重新运行打包命令：

```bash
pnpm android
```

这将把应用安装到已连接的模拟器上并运行。

## 5. 故障排除

### 5.1 如果遇到HAXM安装问题（Intel处理器）
1. 在SDK Tools中找到"Intel x86 Emulator Accelerator (HAXM installer)"
2. 点击"Show Package Details"
3. 选择合适的HAXM版本并安装
4. 如果安装失败，可以手动下载并安装HAXM

### 5.2 如果模拟器启动缓慢
1. 确保已启用Intel VT-x或AMD-V虚拟化技术（在BIOS中设置）
2. 分配更多内存给模拟器
3. 使用x86_64系统镜像而不是ARM镜像

## 6. 替代方案：使用物理设备

如果没有足够资源运行模拟器，可以使用USB连接的Android设备进行调试：

1. 在设备上启用开发者选项和USB调试
2. 使用USB线连接设备到电脑
3. 运行打包命令：
   ```bash
   pnpm android
   ```