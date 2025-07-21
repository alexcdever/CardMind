# 多平台部署方案

## 1. Web端静态部署

```bash
# 构建生产版本
npm run build

# 输出目录: dist/
# 可直接部署到任何静态服务器
```

## 2. Electron桌面应用

### 安装依赖
```bash
pnpm add electron electron-builder --save-dev
```

### 创建electron入口文件 (electron-main.js)
```javascript
const { app, BrowserWindow } = require('electron')
const path = require('path')

function createWindow() {
  const win = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: true
    }
  })

  win.loadFile('dist/index.html')
}

app.whenReady().then(() => {
  createWindow()
})
```

### 修改package.json
```json
{
  "main": "electron-main.js",
  "scripts": {
    "electron:build": "vite build && electron-builder",
    "electron:dev": "vite build && electron ."
  },
  "build": {
    "appId": "com.example.cardmind",
    "win": {
      "target": "nsis"
    },
    "mac": {
      "target": "dmg"
    },
    "linux": {
      "target": "AppImage"
    }
  }
}
```

## 3. React Native移动端

### 初始化RN项目
```bash
pnpm dlx react-native init CardMindMobile --template react-native-template-typescript
```

### 共享代码方案
1. 创建shared/目录存放可复用组件
2. 使用平台特定文件后缀:
   - Component.android.tsx
   - Component.ios.tsx
   - Component.web.tsx

### 构建Android APK
```bash
cd CardMindMobile
pnpm react-native run-android --variant=release
```

### 生成签名APK
```bash
# 生成签名密钥
keytool -genkeypair -v -keystore my-release-key.keystore -alias my-key-alias -keyalg RSA -keysize 2048 -validity 10000

# 配置gradle变量
# 在android/gradle.properties中添加:
MYAPP_RELEASE_STORE_FILE=my-release-key.keystore
MYAPP_RELEASE_KEY_ALIAS=my-key-alias
MYAPP_RELEASE_STORE_PASSWORD=yourpassword
MYAPP_RELEASE_KEY_PASSWORD=yourpassword

# 生成发布APK
cd android && ./gradlew assembleRelease
```

### iOS发布配置
1. 在Xcode中设置Bundle Identifier
2. 配置App图标和启动图
3. 生成归档文件:
```bash
cd ios && pod install
# 在Xcode中选择Product > Archive
```

### 发布到应用商店
1. Android:
   - 注册Google Play开发者账号
   - 使用Google Play Console上传APK
   - 填写应用元数据和截图

2. iOS:
   - 注册Apple开发者账号($99/年)
   - 使用Transporter或Xcode上传IPA
   - 在App Store Connect中提交审核

## 实施步骤

1. 先完成Web端构建测试
2. 添加Electron配置并测试
3. 初始化RN项目并迁移代码
4. 测试各平台功能

## 注意事项

1. 平台差异处理
2. 原生模块兼容性
3. 性能优化
