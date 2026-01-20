# 如何使用 GitHub 免费云端打包 APK (无需本地安装环境)

这是最简单的打包方法。您不需要在电脑上安装任何复杂的软件，只需要有一个 GitHub 账号。

## 第一步：准备代码

您现在的 `punch_card_record` 文件夹中已经包含了所有必要的代码和自动化配置（我刚刚添加了 `.github/workflows/build_apk.yml` 文件）。

## 第二步：上传到 GitHub

1.  登录 [GitHub](https://github.com/)。
2.  点击右上角的 **+** 号，选择 **New repository** (新建仓库)。
3.  输入仓库名称（例如 `punch-card-app`），选择 **Public** (公开) 或 **Private** (私有) 均可。
4.  点击 **Create repository**。
5.  在页面中找到 "uploading an existing file" (上传现有文件) 的链接，或者使用 GitHub Desktop 工具将 `punch_card_record` 文件夹中的**所有文件**上传到这个新仓库中。
    *   **注意**：确保 `.github` 文件夹及其内部的 `workflows/build_apk.yml` 文件也被成功上传。

## 第三步：等待自动打包

1.  上传完成后，点击仓库顶部的 **Actions** 标签页。
2.  您会看到一个名为 "Build Android APK" 的任务正在运行（黄色旋转图标）。
3.  等待约 3-5 分钟，直到图标变成绿色的对勾 ✅。

## 第四步：下载 APK

1.  点击那个绿色的任务记录（通常显示为 "Initial commit" 或您提交时的备注）。
2.  在任务详情页面的底部，找到 **Artifacts** 区域。
3.  点击 **punch-card-record-apk**。
4.  GitHub 会下载一个 `.zip` 压缩包。
5.  解压该压缩包，里面就是您的安卓安装包 `app-release.apk`！

---

**常见问题：**
*   **安装失败？** 由于是未签名的测试包，安装时手机可能会提示“未知来源”或“风险应用”，请选择“继续安装”或“信任此应用”即可。