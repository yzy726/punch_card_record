# 打卡记录应用 (Punch Card Record)

一个简单的Flutter应用，用于记录每日打卡情况。

## 功能特性

- 📅 日历视图显示打卡记录
- ✅ 标记每日打卡状态
- 📊 查看月度统计
- 💾 本地数据存储
- 📱 响应式设计，支持移动设备

## 技术栈

- **Flutter** - 跨平台UI框架
- **Dart** - 编程语言
- **Provider** - 状态管理
- **Shared Preferences** - 本地存储
- **Table Calendar** - 日历组件

## 项目结构

```
lib/
├── main.dart          # 应用入口
├── models/            # 数据模型
│   ├── punch_record.dart
│   └── punch_log.dart
├── providers/         # 状态管理
│   └── punch_provider.dart
├── screens/           # 界面页面
│   ├── home_page.dart
│   └── log_page.dart
└── services/          # 服务层
    └── storage_service.dart
```

## 构建APK

### 使用GitHub Actions（推荐）

1. 将项目推送到GitHub仓库
2. GitHub Actions会自动构建APK
3. 在Actions标签页下载生成的APK

### 本地构建

```bash
# 安装依赖
flutter pub get

# 构建APK
flutter build apk --release

# 构建完成后，APK文件位于：
# build/app/outputs/flutter-apk/app-release.apk
```

## 安装与运行

1. 下载APK文件到Android设备
2. 允许安装来自未知来源的应用（设置 > 安全 > 未知来源）
3. 安装并运行应用

## 开发环境设置

请参考 [FLUTTER_INSTALLATION.md](FLUTTER_INSTALLATION.md) 设置Flutter开发环境。

## 许可证

MIT License