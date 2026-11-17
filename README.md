<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Zorme 浏览器图标"/>
</p>

<h1 align="center">Zorme 浏览器 · OpenHarmony 版</h1>

<p align="center">
  基于 OpenHarmony ArkWeb 构建的轻量浏览器<br/>
  <b>轻量、干净、不打扰</b>
</p>

<p align="center">
  <a href="https://github.com/lmxdg/ZormeBrowser-OpenHarmony/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/lmxdg/ZormeBrowser-OpenHarmony?label=%E6%9C%80%E6%96%B0%E7%89%88&color=black"/></a>
  <img alt="Platform" src="https://img.shields.io/badge/%E5%B9%B3%E5%8F%B0-OpenHarmony%207.0-black"/>
  <img alt="API" src="https://img.shields.io/badge/API-26%20%2F%20min%2012-black"/>
  <img alt="Size" src="https://img.shields.io/badge/HAP-%E7%BA%A6500KB-black"/>
  <img alt="License" src="https://img.shields.io/badge/%E8%AE%B8%E5%8F%AF%E8%AF%81-MIT-black"/>
</p>

---

## 简介

这是 [ZormeBrowser](https://github.com/lmxdg/ZormeBrowser)（Android 版）的 **OpenHarmony 原生重写版**。

界面语言、交互逻辑、配色与功能布局与原版保持一致，但代码全部用 **ArkTS / ArkUI** 重写，内核由 Android System WebView 换成 **ArkWeb**，不依赖任何 Android 兼容层。

- 目标平台：**OpenHarmony 7.0 Release（API 26）**
- 最低兼容：API 12（OpenHarmony 5.0）
- 包名：`com.zorme.browser`
- 设备类型：default / tablet / 2in1

## 下载

前往 [Releases](https://github.com/lmxdg/ZormeBrowser-OpenHarmony/releases) 下载 `ZormeBrowser-1.1.0.hap`，通过 hdc 安装：

```bash
hdc install ZormeBrowser-1.1.0.hap
```

也可以在应用内检查更新：**菜单 → 设置 → 关于 → 检查更新**，会读取 GitHub Releases 最新版本号并与本地版本比较，支持切换下载加速站（直连 / ghfast.top / ghproxy.net）。

## 功能特性

**浏览核心**
- 基于 ArkWeb 的多标签浏览，标签卡片管理（新建 / 关闭 / 切换 / 无痕）
- Via 风格底部栏：返回 / 前进 / 地址胶囊 / 标签数徽标 / 菜单，单手可达
- 智能地址栏：自动区分网址与搜索词，实时给出历史与书签建议
- 起始页：Zorme 徽标、搜索框、AI 助手入口、8 个常用网站、书签 / 历史 / 下载快捷入口
- 网页加载进度、错误页、下拉回弹、标签会话恢复（下次启动还原标签）
- 长按地址栏：复制链接 / 用其他浏览器打开 / 保存离线网页

**效率工具**
- **AI 助手**：OpenAI 兼容 Chat Completions 协议，流式输出、随时停止、长按复制、一键清空
  - 内置预设：智谱、DeepSeek、阿里云百炼、基元律动、字节跳动（火山方舟）、自定义
  - API 地址 / Key / 模型均可在设置中修改，Key 仅保存在本机
- **网站证书**：查看当前站点 TLS 证书的颁发者、有效期、签名算法、SHA-256 指纹、SAN、证书链长度；HTTP 站点给出明文传输风险提示
- **网页源码**：读取当前页面完整 HTML，可滚动查看与一键复制
- **网络日志**：记录页面加载的资源请求（方法 / URL / 主文档或子资源 / 是否被广告拦截），仅存内存，退出即清空
- **页内查找**：关键字高亮、上一处 / 下一处、匹配计数
- **阅读模式**：注入脚本抽取正文，去除干扰元素
- **网页翻译**：接入必应翻译（Bing Translator），把整页正文按段落译成中文（可选 12 种目标语言）
  - 按块级容器合并文本节点再翻译，`<p>Visit <a>the site</a> now.</p>` 不会被拆成语序错乱的碎片
  - 自动跳过代码块、输入框、`translate=no` 元素与纯中文段落
  - 逐批翻译并显示进度，可随时停止；一键「原文」还原；切回标签仍保留翻译条
  - 无需 API Key：复用必应翻译网页的公开接口，token 本地缓存并自动刷新

**隐私与外观**
- 广告与追踪域名拦截（内置规则表 `rawfile/ad_hosts.txt`，设置中可开关）
- 夜间模式（跟随系统 / 常亮 / 关闭）、无图模式、桌面版 UA
- UA 模式：默认 / 桌面 Chrome / iPhone / iPad / 自定义字符串，所有标签即时生效
- 无痕标签：不写历史、不落 Cookie
- 记录历史开关、清除缓存 / Cookie / 历史 / 全部数据
- 搜索引擎可切换：百度、必应、Google、搜狗、360、神马、DuckDuckGo
- 自定义主页、网页字体缩放（80%–150%）

**内置弹窗体系**
- 确认 / 输入 / 单选 / 操作列表 / 浮层提示，以及网页的 `alert` / `confirm` / `prompt`，全部为应用内自绘卡片（底部升起 + 遮罩动画），不调用系统弹窗
- 长文本（用户协议、更新日志）自动进入可滚动区域

## 运行环境

| 项目 | 要求 |
|:--|:--|
| 系统 | OpenHarmony 7.0 Release（API 26）及以上 |
| 最低系统 | OpenHarmony 5.0（API 12） |
| 编译 SDK | `26.0.0.38-Release`（Public SDK） |
| 开发工具 | DevEco Studio（支持 API 26 的版本）或命令行 hvigor |
| 权限 | `ohos.permission.INTERNET`、`ohos.permission.GET_NETWORK_INFO` |

> 应用为纯 ArkTS 实现，`deviceTypes` 为 `default / tablet / 2in1`，手机、平板与 PC 形态均可运行。

## 构建

### DevEco Studio

1. 用 DevEco Studio 打开工程根目录
2. 在 `File → Project Structure → Signing Configs` 中勾选自动签名（或配置自己的证书）
3. 选择 `entry` 模块，`Build → Build Hap(s)/APP(s) → Build Hap(s)`

### 命令行

```bash
# 依赖：Node.js 18+、JDK 17+、OpenHarmony SDK（API 26）
export OHOS_SDK=$HOME/ohsdk/sdk          # SDK 根目录，内部需有 26.0.0/ 组件目录
export PATH=$PATH:$OHOS_SDK/26.0.0/toolchains

# 安装构建依赖（首次）
ohpm install

# 构建 + 签名，产物输出到 dist/
./build.sh
```

`build.sh` 内部做三件事：

1. `hvigor assembleHap --mode module -p buildMode=release`
2. 用 SDK 自带 `hap-sign-tool.jar` 对 `signature/profile.json` 签出 `signature/profile.p7b`
3. 对未签名 HAP 签出 `dist/ZormeBrowser-1.0.0.hap`，并执行 `verify-app` 校验

仓库内 `signature/` 只保存描述文件模板（不含私钥），签名密钥直接使用 OpenHarmony SDK 公共测试证书（`toolchains/lib/OpenHarmony.p12`，口令 `123456`），**仅供开发调试与自用侧载**；上架应用市场请替换为自己的证书与 Profile。

## 项目结构

```
ZormeBrowser-OpenHarmony/
├── AppScope/                      # 应用级配置（bundleName、版本、图标）
├── entry/src/main/
│   ├── ets/
│   │   ├── entryability/EntryAbility.ets
│   │   ├── pages/Index.ets        # 主界面：标签、地址栏、菜单、弹窗、下载
│   │   ├── components/
│   │   │   ├── TabWeb.ets         # 单标签 Web 组件与回调
│   │   │   ├── HomeView.ets       # 起始页
│   │   │   ├── MenuSheet.ets      # 功能菜单面板
│   │   │   ├── AddressOverlay.ets # 地址栏浮层与建议
│   │   │   ├── TabsOverlay.ets    # 标签管理
│   │   │   ├── SettingsView.ets   # 设置页
│   │   │   ├── AiChatView.ets     # AI 助手对话页
│   │   │   ├── ListView.ets       # 书签 / 历史 / 下载
│   │   │   ├── SourceView.ets     # 网页源码
│   │   │   ├── NetLogView.ets     # 网络日志
│   │   │   ├── ZIcon.ets          # SVG 单色图标
│   │   │   └── ZSwitch.ets        # 自绘开关
│   │   ├── model/                 # Prefs / Store / AdBlocker / AiClient / SslInfo / BingTranslate ...
│   │   └── common/                # 主题色板与工具函数
│   └── resources/rawfile/         # 图标 SVG、广告域名表、翻译注入脚本
├── signature/                     # 签名描述文件模板
├── build.sh                       # 构建 + 签名脚本
└── docs/icon.png
```

## 与原 Android 版的差异

| 能力 | Android 版 | OpenHarmony 版 |
|:--|:--|:--|
| 内核 | Android System WebView | ArkWeb |
| 语言 | Java | ArkTS / ArkUI |
| 标签预览截图 | 支持 | 不支持（ArkWeb 未开放跨进程截图接口） |
| 下载管理 | DownloadManager | ArkWeb `WebDownloadDelegate` + 应用沙箱目录 |
| 安装包 | APK ~2.6MB | HAP ~500KB |

## 隐私

- 无云服务、无账号体系，不收集任何个人信息
- 书签 / 历史 / 下载记录 / 设置全部保存在应用沙箱（`preferences`），卸载即清除
- AI 请求只发送到你自行配置的服务商地址，Key 仅存本机
- 不内置任何统计、追踪或广告 SDK

## License

[MIT](LICENSE)
