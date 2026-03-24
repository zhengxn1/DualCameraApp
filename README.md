# DualCameraApp — 苹果手机前后置摄像头同时拍摄

## 功能介绍

- **前后置同时预览**：屏幕分为上下两栏，实时显示后置和前置摄像头画面
- **同时拍摄**：点击一次快门按钮，前后置摄像头同时拍照
- **自动保存**：两张照片均自动保存到系统相册
- **深色 UI**：适合拍摄场景的深色界面

## 设备要求

| 条件 | 要求 |
|------|------|
| iPhone 型号 | iPhone XS / XR 及更新机型（A12 芯片+） |
| iOS 版本 | iOS 13.0 或更高 |
| 核心 API | `AVCaptureMultiCamSession` |

> 在不支持的设备上运行会弹出提示，模拟器无法测试摄像头功能。

## 项目结构

```
DualCameraApp/
├── DualCameraApp.xcodeproj/       ← Xcode 项目文件
└── DualCameraApp/
    ├── AppDelegate.swift           ← App 入口
    ├── SceneDelegate.swift         ← 设置根视图控制器
    ├── ViewController.swift        ← 主界面（上下分屏预览 + 拍摄按钮）
    ├── DualCameraManager.swift     ← 双摄核心逻辑（AVCaptureMultiCamSession）
    ├── Info.plist                  ← 权限声明（摄像头、相册）
    ├── LaunchScreen.storyboard     ← 启动页
    └── Assets.xcassets/            ← 图标资源
```

## 如何构建运行

1. 将整个 `DualCameraApp` 文件夹拷贝到 **Mac**
2. 用 **Xcode 15+** 打开 `DualCameraApp.xcodeproj`
3. 在 `Signing & Capabilities` 中选择你的 Apple 开发者账号
4. 将 iPhone（XS/XR 及以上）连接到 Mac
5. 选择真机目标，点击 **Run (▶)**

## 核心代码说明

### DualCameraManager.swift

```swift
// 关键：使用 AVCaptureMultiCamSession 而非普通 AVCaptureSession
let session = AVCaptureMultiCamSession()

// 前后摄像头各自独立添加，不共用连接
session.addInputWithNoConnections(backInput)
session.addInputWithNoConnections(frontInput)

// 通过 Port 建立独立连接
let backConn = AVCaptureConnection(inputPorts: [backPort], output: backOutput)
session.addConnection(backConn)

// 预览层也通过 Port 独立关联
let previewConn = AVCaptureConnection(inputPort: backPort, videoPreviewLayer: backPreview)
session.addConnection(previewConn)
```

### 同时触发拍摄

```swift
func capturePhotos() {
    backPhotoOutput?.capturePhoto(with: settings, delegate: self)
    frontPhotoOutput?.capturePhoto(with: frontSettings, delegate: self)
    // 两个 output 的回调都完成后触发 onPhotoCaptured
}
```

## 权限说明（Info.plist 已配置）

- `NSCameraUsageDescription` — 摄像头权限
- `NSPhotoLibraryAddUsageDescription` — 相册写入权限
