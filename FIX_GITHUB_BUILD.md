# Android 构建维护说明

当前构建配置与排障入口已合并到 [README](README.md) 和 [GitHub Actions 构建指南](GITHUB_BUILD_GUIDE.md)。

项目使用 Flutter 的声明式 Gradle 插件，不再使用已移除的 `apply from: flutter.gradle`。Java、Flutter、AGP、Gradle 和 Kotlin 的版本在仓库中固定。Flutter 构建工具会补齐忽略的 Gradle wrapper 脚本和 JAR。

依赖锁定文件 `pubspec.lock` 应与代码一起提交。修改依赖后应重新执行分析、时区回归测试及 APK 构建。