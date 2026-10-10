 1 | # 舞梓桌面宠物 / Wuzi Desktop Pet
 2 | 
 3 | 一个基于 **Godot 4.7** 的 Windows Q 版桌宠。具有透明视频动画、随机日常动作、拖拽与点击、本地对话与彩蛋、睡眠、提醒，以及文件批量重命名和图片转换。
 4 | 
 5 | > **发布状态：公开源码仓库已上线；Windows 便携包 v0.1.0 已在开发机完成构建与独立启动测试，GitHub Releases 附件仍待上传。**
 6 | > GitHub 源码仓库与运行版 ZIP 分开：源码 Git 仓库不包含动画二进制资源，完整 ZIP 的 Godot PCK 包含 38 组已处理的运行时动画（OGV 与 PNG fallback），**不包含原始绿幕 MP4 或参考图**。
 7 | 
 8 | ## 下载与使用
 9 | 
GitHub Release 附件上传后，请下载 `WuziDesktopPet-v0.1.0-win64.zip`，**完整解压后**双击 `舞梓桌宠.exe`。最终用户不需要安装 Godot、Python、FFmpeg 或其他开发工具。

请保留与 EXE 同目录的 `舞梓桌宠.pck` 和 `native/` 文件夹，否则动画或文件处理功能无法正常运行。HEIC 读写取决于 Windows 是否支持相关系统图片编解码器。

当前本地构建位置：`dist/WuziDesktopPet-v0.1.0-win64.zip`。这条路径是作者电脑上的构建成果，**不是互联网下载链接**。截至当前版本，Windows DPI 125%/150% 和多显示器尚未专门实测；运行时动态命中区域可能略大。

## 已有功能

- 透明桌宠、鼠标点击与 Q 弹、拖拽／抛掷、右键点播动作。
- 26 种按权重抽签的自主日常动作，以及独立睡眠、桌面漫游和统一自主暂停。
- 本地关键词聊天、昵称、角色彩蛋、有限上下文、真实情绪回复、动画与对话联动。
- 文件处理工作台：批量重命名、PNG/JPG/WebP 互转、可选系统 HEIC、预览/冲突保护、确认执行与失败保留；聊天不会直接处理文件。
- 喝水、吃饭及可选天气提醒。天气使用 Open-Meteo 网络请求。

## 开发者源码

源码在 `godot/` 和 `tools/`。**克隆 Git 仓库不等于下载可运行版**；出于仓库体积与素材权利划分，Git 追踪配置和代码，运行时动画二进制放在 Windows Release ZIP 内。

需要从源码重建桌宠时，须具有合法来源的动画资源，并按原项目各 `*_video_manifest.json` 和素材构建脚本重建 `godot/assets_display/`；构建不依赖或需要 Git 仓库携带原始 MP4。 Windows 文件辅助组件的 C++ 源码在 `tools/native/file_bridge.cpp`，可运行 `tools/build_file_bridge.ps1` 构建。

独立 Windows 构建要求 Godot 4.7 和配套的 Windows x86_64 导出模板：

```powershell
py -3 tools/fetch_win_export_templates.py
py -3 tools/package_windows_release.py
py -3 tools/smoke_portable_release.py
```

仅验证当前已导出 EXE/PCK 并重新生成 ZIP 时，可传入 `--reuse-export`。完整回归：

```powershell
py -3 -m pip install numpy pillow imageio-ffmpeg
py -3 tools/run_baseline_tests.py
```

开发机普通启动为 `启动桌宠.vbs`，调试启动为 `tools/诊断启动桌宠.bat`，后者和旧脚本依赖作者本机的 Godot 安装路径；正式便携包**不需要这些启动脚本**。

## 许可与角色声明

- 项目原创源代码以 [MIT License](LICENSE) 开源。
- Godot 引擎采用自身 MIT 许可证，运行 ZIP 内包含相应引擎版权与许可文本。
- **舞梓／阿梓的角色形象、衍生动画及其他视觉素材不属于项目代码 MIT 许可证。** 相关权利归各合法权利人所有。本桌宠为非官方粉丝二创，未经权利人官方背书；本仓库的版权说明不构成任何第三方授权。
- 完整 ZIP 只包含处理后的运行资源，不包含原始 MP4；这不会自动消除角色衍生创作和再分发方面的授权问题。详情请阅读 [素材说明](docs/ASSET_POLICY.md)。

## 文档

- [开发机操作说明](README_桌宠.md)
- [本机完整发布流程](docs/PUBLIC_RELEASE_PLAN.md)
- [自动测试说明](docs/TESTING.md)
- [阶段五与后续交接](阶段五5B实现与后续AI交接.md)
