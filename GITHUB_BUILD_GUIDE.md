# GitHub Actions 构建 APK

电脑无需安装 Flutter 或 Android SDK。

1. 打开 [Build Android APK](https://github.com/yzy726/punch_card_record/actions/workflows/build_apk.yml)。
2. 主分支推送会自动构建，也可点击 **Run workflow** 手动构建。
3. 等待运行变绿，打开底部 **Artifacts → punch-card-record-apk**，下载并解压。
4. 安装 `punch-card-record-1.1.0.apk`；`SHA256SUMS.txt` 可校验文件完整性。

`validation-*` 包含锁定依赖、测试覆盖率和 `home.png`、`backup.png`、`logs.png` 界面预览。

构建会先运行静态分析和测试，失败时不会生成误导性的成功安装包。主分支构建要求配置固定签名 Secrets，详见 [README](README.md)。