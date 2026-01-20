# Flutter Windows 安装与环境配置指南

本指南将帮助您在 Windows 系统上从零开始搭建 Flutter 开发环境，以便运行“打卡记”应用。

## 第一步：下载 Flutter SDK

1.  访问 Flutter 官网下载页：[https://docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows)
2.  点击下载蓝色的 **Stable Channel** 按钮（例如 `flutter_windows_3.x.x-stable.zip`）。
3.  **解压文件**：
    *   将压缩包解压到一个路径简单且**不包含中文或空格**的文件夹中。
    *   推荐位置：`C:\src\flutter`

## 第二步：配置环境变量 (Path)

为了在任何终端都能使用 `flutter` 命令，需要将其添加到系统环境变量中。

1.  在 Windows 搜索栏输入“**编辑系统环境变量**”并打开。
2.  点击右下角的“**环境变量**”按钮。
3.  在“**用户变量**”一栏中，找到名为 `Path` 的变量，选中并点击“**编辑**”。
4.  点击“**新建**”，输入您刚才解压的 flutter `bin` 目录的完整路径。
    *   例如：`C:\src\flutter\bin`
5.  连续点击“确定”保存所有设置。

**验证**：打开一个新的 PowerShell 或 CMD 窗口，输入 `flutter --version`。如果显示版本号，说明配置成功。

## 第三步：安装 Android Studio (用于安卓开发工具链)

虽然我们使用 VS Code 写代码，但编译安卓应用需要 Android Studio 提供的 SDK 和工具链。

1.  下载并安装 **Android Studio**：[https://developer.android.com/studio](https://developer.android.com/studio)
2.  启动 Android Studio，按照向导进行“**Standard**” (标准) 安装。这将自动下载最新的 Android SDK。
3.  **关键步骤：安装命令行工具**
    *   打开 Android Studio。
    *   点击 **More Actions** > **SDK Manager**。
    *   切换到 **SDK Tools** 选项卡。
    *   勾选 **Android SDK Command-line Tools (latest)**。
    *   点击 **Apply** 进行下载安装。

## 第四步：同意 Android 协议

打开 PowerShell 或 CMD，运行以下命令并一路输入 `y` 同意所有协议：

```bash
flutter doctor --android-licenses
```

## 第五步：配置 VS Code

1.  打开 VS Code。
2.  点击左侧扩展图标 (Extensions)。
3.  搜索并安装 **Flutter** 插件 (Dart 插件会自动安装)。

## 第六步：最终检查

在终端运行以下命令检查环境状态：

```bash
flutter doctor
```

如果所有项目前面都是绿色的勾（Visual Studio for Windows 可以忽略，那是用于开发 Windows 桌面应用的），则环境搭建完成！

---

## 如何运行本项目

1.  在 VS Code 中打开 `punch_card_record` 文件夹。
2.  打开终端 (Terminal > New Terminal)。
3.  下载项目依赖：
    ```bash
    flutter pub get
    ```
4.  连接您的安卓手机（需开启 USB 调试）或启动 Android 模拟器。
5.  运行应用：
    ```bash
    flutter run