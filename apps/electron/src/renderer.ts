// Electron渲染进程入口
// 这里可以初始化渲染进程的代码
console.log('Electron渲染进程已启动')

// 示例：使用electronAPI
if (window.electronAPI) {
  // 获取应用版本
  window.electronAPI.getAppVersion().then(version => {
    console.log('应用版本:', version)
  })
  
  // 监听窗口事件
  window.electronAPI.onWindowEvent((event) => {
    console.log('窗口事件:', event)
  })
}