# 舞梓桌宠 · Wuzi Desktop Pet

基于 **Godot 4.7** 开发的 Windows 桌面宠物。舞梓会随机活动、和你互动，也能帮助处理图片和批量重命名文件。

**[下载 Windows 64 位完整版 v0.1.0](https://github.com/1704919/WuziDesktopPet/releases/download/v0.1.0/WuziDesktopPet-v0.1.0-win64.zip)** · [查看版本说明](https://github.com/1704919/WuziDesktopPet/releases/tag/v0.1.0)

## 如何使用

1. 下载上面的 `WuziDesktopPet-v0.1.0-win64.zip`（约 352 MiB）。
2. 将 ZIP **完整解压**到任意文件夹，不要直接在压缩包里启动。
3. 双击 `舞梓桌宠.exe`。

请保留 `舞梓桌宠.pck` 和 `native/` 目录，它们分别提供动画及文件处理所需资源。遇到 Windows 未知发布者提示时，请确认下载来源和文件校验值。

## 功能介绍

- **桌面陪伴**：透明动画、点击 Q 弹、拖动／抛掷、右键动作点播、桌面漫游。
- **自主行为**：26 种加权随机日常动作，独立打瞌睡与睡眠系统；可以暂停自主行为。
- **本地对话**：离线关键词聊天、昵称、彩蛋、情绪回答和动作联动；不需要配置云端 AI API。
- **文件处理**：批量重命名，PNG／JPG／WebP 格式转换、预览及重名冲突保护；HEIC 能力依赖 Windows 系统图片组件。
- **生活提醒**：喝水、吃饭及可选天气提醒；天气查询使用 Open-Meteo 网络服务。

完整版包含 **38 组已处理的运行时动画**。

## 源码与构建

本仓库主要提供 `godot/` 下的 GDScript、场景与配置，以及 `tools/` 中的构建和测试工具。

**注意：本项目大量使用AI开发。**

**注意：Git 仓库本身不包含角色动画二进制资源。** 单纯克隆本仓库，不能直接得到与完整版 ZIP 相同的角色画面；普通用户请从 [Releases](https://github.com/1704919/WuziDesktopPet/releases) 下载 Windows 便携版。开发者需要合法取得相应素材，并自行生成 `godot/assets_display/` 的运行时资源。

Windows 原生文件处理组件的源码位于 `tools/native/file_bridge.cpp`。

## 已知限制

目前主要在 Windows 11 上验证。125%／150% 显示缩放、多显示器尚未专项测试；个别姿态的鼠标命中范围可能偏大。HEIC 编解码能力取决于用户的 Windows 环境。

## 许可与版权

- 本项目原创源代码采用 [MIT License](LICENSE)。
- **舞梓／阿梓的角色形象、相关设计及衍生动画不属于源码 MIT 授权范围**；相关权利归各自合法权利人所有。
- 这是非官方粉丝二创作品，不代表角色权利人或任何官方组织。
- Godot 引擎及其他实际分发组件依各自许可证使用。

**v0.1.0 Windows ZIP SHA-256：**

```text
2e3ace7f418d0d25f6be56f3be82d7ae32e52fdaf2876b7db91d04333443fe80
```

可以在 PowerShell 中运行 `Get-FileHash .\WuziDesktopPet-v0.1.0-win64.zip -Algorithm SHA256` 核对下载文件。
