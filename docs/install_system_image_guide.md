# Android系统镜像安装指南

由于命令行安装系统镜像遇到问题，建议通过Android Studio的图形界面来安装。

## 安装步骤

1. 打开Android Studio
2. 点击`Configure` -> `SDK Manager`
3. 在`SDK Platforms`标签页中，勾选`Android 13 (API Level 33)`
4. 切换到`SDK Tools`标签页
5. 展开`Android Emulator`并确保已安装
6. 展开`System Image`，选择`Android 13 (API Level 33)`下的`Google APIs x86_64`系统镜像
7. 点击`Apply`并确认安装

安装完成后，您就可以继续创建AVD模拟器了。