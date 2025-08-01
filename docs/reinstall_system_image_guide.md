# 重新安装Android系统镜像指南

根据检查结果，发现系统镜像目录结构不完整，缺少必要的系统镜像文件。需要重新安装系统镜像。

## 重新安装步骤

1. 打开Android Studio
2. 点击`Configure` -> `SDK Manager`
3. 在`SDK Platforms`标签页中，确保勾选了`Android 13 (API Level 33)`
4. 切换到`SDK Tools`标签页
5. 展开`System Image`，取消勾选`Android 13 (API Level 33)`下的`Google APIs x86_64`系统镜像
6. 点击`Apply`并确认卸载
7. 再次勾选`Android 13 (API Level 33)`下的`Google APIs x86_64`系统镜像
8. 点击`Apply`并确认重新安装

## 重新创建AVD模拟器

安装完成后，您需要重新创建AVD模拟器：

1. 在Android Studio中，点击`Configure` -> `AVD Manager`
2. 点击`Create Virtual Device`
3. 选择设备类型（如Pixel 4）
4. 选择API Level 33 (Android 13)的Google APIs系统镜像
5. 完成AVD创建向导
6. 启动新创建的AVD模拟器

如果按照以上步骤操作后仍然无法启动模拟器，请检查您的系统是否满足Android模拟器的硬件要求，特别是CPU虚拟化功能是否已启用。