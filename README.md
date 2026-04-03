# HarmonyClaw - OpenClaw for HarmonyOS

<div align="center">

**鸿蒙原生终端模拟器 + AI Agent 平台**

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-4.0+-blue.svg)](https://www.harmonyos.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

## 功能特性

- 🖥️ **原生终端模拟器** - 基于 WebView 的高性能终端渲染
- 📦 **多会话管理** - 支持多个终端会话同时运行
- 🔧 **Bootstrap 环境** - 一键安装 Termux 开发环境
- 🤖 **AI Agent 集成** - 支持 OpenClaw AI 平台
- 📱 **虚拟按键** - 完整的终端功能键支持
- 🌐 **WebView 集成** - 设置界面与终端无缝切换
- 🔐 **安全命令执行** - 白名单验证 + 速率限制

## 系统要求

- HarmonyOS 4.0 或更高版本
- API Version 10+
- 至少 500MB 可用存储空间

## 项目结构

```
harmony-claw/
├── entry/                    # 主入口模块
│   └── src/main/
│       ├── ets/              # ArkTS 源码
│       │   ├── pages/        # 页面
│       │   ├── components/   # 组件
│       │   ├── models/       # 数据模型
│       │   ├── utils/        # 工具类
│       │   └── services/     # 后台服务
│       ├── resources/        # 资源文件
│       └── cpp/              # 原生代码
├── terminal/                 # 终端模拟器模块
│   └── src/main/
│       ├── ets/              # 终端核心
│       └── cpp/              # PTY 管理
├── bootstrap/                # 引导安装模块
│   └── src/main/ets/
└── docs/                     # 文档
```

## 快速开始

### 开发环境

1. 安装 [DevEco Studio 4.0+](https://developer.harmonyos.com/cn/develop/deveco-studio)
2. 克隆项目
3. 打开项目并同步依赖
4. 连接设备或启动模拟器
5. 点击运行

### 安装

```bash
# 使用 hdc 安装
hdc install entry-default-signed.hap
```

## 核心模块

### Entry 模块
- 主页面和导航
- WebView 设置界面
- 终端视图容器
- 会话标签管理
- 虚拟按键栏

### Terminal 模块
- 终端模拟器核心
- ANSI 转义序列解析
- PTY 进程管理
- 会话生命周期

### Bootstrap 模块
- 环境检测
- 资源下载
- 解压安装
- 路径配置

## 技术栈

- **ArkTS** - HarmonyOS 原生开发语言
- **ArkUI** - 声明式 UI 框架
- **WebView** - 终端渲染引擎
- **NAPI** - 原生模块接口
- **C++** - PTY 和进程管理

## 参考项目

- [HiSH](https://github.com/tudaojia/HiSH) - HarmonyOS Shell 模拟器
- [android-openclaw](https://github.com/tudaojia/android-openclaw) - Android 版本参考

## License

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！
