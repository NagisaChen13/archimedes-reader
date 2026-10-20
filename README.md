# Archimedes Reader (阿基米德阅读器)

新一代跨平台电子书阅读器：
* **视觉主干**：以轻小说文库（Wenku8_Flutter）的「档案工坊与奶白液态玻璃」为主，配备自研 GLSL 着色器、工程十字规线与机打档案印章。
* **阅读核心**：以静读天下（Moon+ Reader Pro）的「工业级自定义」为主体，搭载 9 宫格屏幕触控映射、3D 拟真翻页、仿生聚焦阅读（Bionic Reading）、6 款阅读标尺、正则字符清洗与微型状态栏。
* **特色增强**：融入轻小说文库的「分卷自动合并母本」与「全卷插画一览提取器」；融入 Reeden 的「6 款物理真实纸张翻页声效」、「OpenAI 协议长篇角色关系拓扑图谱」与「多角色广播剧式听书」。
* **全景统计**：融合足迹日历热力图、年度趋势图、连续阅读目标，以及业内首创的「外挂实体书计时器」。

---

## 目录结构

```
archimedes_reader/
├── .github/workflows/
│   └── build_apps.yml         # GitHub Actions 云端全自动打包流水线 (Android + iOS)
├── android/                   # 完整的 Android 原生脚手架与权限清单配置
├── ios/                       # 完整的 iOS 原生 Xcode / CocoaPods 脚手架
├── shaders/                   # GLSL 奶白流体玻璃连续高斯模糊着色器
├── assets/
│   ├── audio/                 # 6 种物理真实纸张翻折声效 (book, magazine, natural...)
│   └── fonts/                 # 思源宋体 (Source Han Serif CN) 出版级字体
└── lib/
    ├── main.dart              # 应用入口与 3D 轮播书架 / 列表书架双模
    ├── theme/                 # 档案工坊设计规范系统与 Design Tokens
    ├── ui/widgets/            # 十字规线、机打印章、玻璃悬浮 Dock、微型状态栏
    ├── models/                # 书籍实体、分卷结构、阅读会话、知识图谱节点
    ├── reader/                # 阅读器核心视图、声学引擎、仿生阅读、标尺、9宫格手势
    ├── stats/                 # 全景量化数据中心、日历足迹热力图、外挂实体书计时器
    ├── ai/                    # OpenAI 兼容上下文助读引擎、交互式角色拓扑网络图
    └── services/              # 本地持久化与多角色 TTS 语音引擎
```

---

## 云端全自动打包指南 (双平台方案 A)

本项目已配置开箱即用的 GitHub Actions CI/CD 工作流，**您无需在本地电脑配置复杂的 Flutter、Android SDK 或 Mac Xcode 环境**：

1. **创建 GitHub 仓库**：在 GitHub 上新建一个空仓库（公开或私有均可）。
2. **推送代码**：将 `archimedes_reader` 目录内的代码推送到您的 GitHub 仓库的 `main` 分支：
   ```bash
   cd c:\工作\Antigravity\REA\阅读器app\archimedes_reader
   git init
   git add .
   git commit -m "feat: initial commit for Archimedes Reader"
   git remote add origin https://github.com/您的用户名/您的仓库名.git
   git push -u origin main
   ```
3. **云端自动编译**：
   * 触发推送后，打开 GitHub 仓库页面的 **Actions** 标签栏。
   * 云端 Linux 服务器将自动编译生成 **Android Release APK**（包括通用完整包与分架构优化包）。
   * 云端 macOS 虚拟机将自动编译并打包出 **iOS 软件安装包 (`Archimedes-iOS-unsigned.ipa`)**。
4. **下载安装包**：
   * 编译完成后（约 5~8 分钟），直接在对应工作流详情页底部的 **Artifacts** 区域一键下载 `.apk` 与 `.ipa` 产物！
