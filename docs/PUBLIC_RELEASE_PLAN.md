 1 | # 舞梓桌宠 GitHub 公开仓库与 Windows 发行计划
 2 | 
 3 | 状态：**Windows v0.1.0 ZIP 已在本地构建、通过 CRC 与独立目录的 headless + GUI 启动检查；尚未创建/上传 GitHub 仓库或 Release。**
 4 | 
 5 | 2026-10-10 收口记录：完整隔离回归 **31/31 PASS**，`SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`，报告位于本机忽略目录 `docs/baselines/20261010_165213_ff9782ff/report.json`。入口清理后项目根目录只保留 `启动桌宠.vbs`，诊断入口移至 `tools/诊断启动桌宠.bat`。清理仅针对已确认属于 AI 诊断过程的 `work/video_review/skin_fix/`、`work/video_review/dialogue_feedback_full_regression.log`、`tools/__pycache__/`；保留资产、回退备份及历史测试报告。
 6 | 
 7 | ## 范围与选择
 8 | 
 9 | - **公开源码仓库**：以 `godot/` 中的源码/配置与导出预设、`tools/` 下的自写工具和原生桥接源码、文档及 MIT LICENSE 为主。
- **不纳入 Git 历史**：角色参考图、母版、原始绿幕视频、PNG/OGV 生产帧、原生 EXE 构建产物、机器日志、回退备份、测试输出及 `.godot/` 缓存。已处理的 PNG/OGV 则通过 Windows Release ZIP 的 **PCK 资源包**随程序分发。
- **完整用户 ZIP**：本机已生成并通过独立目录启动检查，包含所有当前已就绪动作以及原生文件组件；对外发布时需要发布者确认角色/素材二创再分发规则，并补齐 Release 网站端操作。没有原始 MP4。

## 建议仓库结构

```text
WuziDesktopPet/
├── README.md                 GitHub 首页：状态、功能、源码限制
├── README_桌宠.md            开发机详细使用说明
├── LICENSE                   项目原创代码的 MIT 许可证
├── .gitignore                排除素材、缓存、构建与本机私人状态
├── docs/
│   ├── ASSET_POLICY.md       角色/视频/图片权利边界
│   ├── PUBLIC_RELEASE_PLAN.md 本文件
│   ├── TESTING.md            隔离测试说明
│   └── ...                   需要保留的项目文档
├── godot/
│   ├── project.godot
│   ├── scenes/
│   ├── scripts/
│   ├── shaders/
│   ├── config/               不含敏感秘密的配置信息
│   ├── native/README.md
│   └── tests/
├── tools/
│   ├── native/file_bridge.cpp
│   ├── build_file_bridge.ps1
│   ├── 诊断启动桌宠.bat
│   └── ...                   自制开发／测试／素材构建工具
└── 启动桌宠.vbs              **仅开发机用**，正式包不用该启动器
```

本地保留而 Git 忽略：`分享区/`、`assets/references/`、`godot/assets_display/`、`godot/native/*.exe`、`godot/.godot/`、`work/`、`dist/`、`backups/`、`docs/baselines/`、`.ai-bridge/`。这些目录不应仅为公开开源而直接删除。

## 发布前检查

1. **Git 工作区干净**：正式提交所有已验收代码与文档，确认没有未审阅的秘密、个人数据、第三方素材和生成产物进入 Git 历史。
2. **第三方许可审核**：确认 MIT 只应用于有权授权的项目代码；核对 Godot 引擎发行时所需版权及许可文本，以及随发行包实际包含的第三方二进制。
3. **源码重建指引**：说明所需 Godot 版本、Windows C++ Build Tools/SDK、Python 依赖及合法素材来源；不要宣称未配素材的克隆仓库即开即用。
4. **人工验收**：中文输入法、焦点／点击穿透、文件处理与取消、连续点击、拖拽、睡眠、漫游、对话；对于 DPI、多屏等无条件测试项目，标记「未验证」而非伪造通过。
5. **长时间运行**：确认实际内存/CPU/GPU、睡眠和随机动作循环、天气与提醒、反复打开/关闭工作台均稳定。
6. **Windows 导出（已完成）**：`godot/export_presets.cfg` 定义 Windows Desktop x86_64；`tools/fetch_win_export_templates.py` 安装官方匹配模板；`tools/package_windows_release.py` 生成 `舞梓桌宠.exe` 与 `.pck` 并将 `native/wuzi_file_bridge.exe` 复制到相对路径 `native/`。HEIC 仍按系统实际能力探测。
7. **新目录／其他机器**：已通过将最终 ZIP 解压到全新 Windows 临时目录后的独立 headless 和 GUI 启动测试、资源与配置关键错误检查；未触碰日常设置。**其他电脑的实机兼容性仍待验证**（DPI、多屏也未测）。正常 ZIP 无本机 Godot/Python 依赖。
8. **正式打包（本地已完成）**：`dist/WuziDesktopPet-v0.1.0-win64.zip`，351.67 MiB，SHA-256 `408b8cf048c5ca249259890f8aba47e44c0759490f2a761df459e3acaef78de1`；含 MIT、Godot LICENSE、素材声明与文件清单。GitHub Release 远程上传尚未执行。
9. **GitHub 公开发布（待执行）**：用户已明确要求完整发布，但当前本地仓库没有 `origin`，所连 GitHub 插件下没有已创建的仓库，且此环境的 GitHub 工具不提供创建仓库或上传 Release 附件的动作。用户需先在 GitHub 创建空仓库并提供地址/合适发布权限，才能继续推送源码并上传 ZIP。请勿把「本地 ZIP 已构建」误写成「GitHub 已发布」。

## 当前 Windows ZIP 的实际结构

```text
WuziDesktopPet-v0.1.0-win64/
├── 舞梓桌宠.exe
├── 舞梓桌宠.pck       # 完整 38 套运行时 OGV/PNG 和脚本配置
├── native/
│   └── wuzi_file_bridge.exe
├── LICENSE.txt        # 项目原创代码授权
├── GODOT_LICENSE.txt # Godot 引擎上游 MIT 全文
├── ASSET_NOTICES.txt  # 角色衍生素材说明，不授予额外角色权利
├── README_使用说明.txt
└── MANIFEST_SHA256.json # 每个随包文件的 SHA-256
```

以上为**本机已生成的结构**，不代表包已上传 GitHub 或已获得第三方角色的公开再分发授权。用户不必下载安装 Visual Studio、Python 或 Godot 才能使用最终导出程序。

## 本次用户确定的不做项

- 不为验收调整 Windows 的 DPI／缩放设置。
- 没有双显示器环境，不强制测试多屏；公开时在已知限制中如实标为「未实测」。
- 用户一直使用中文输入法且现有输入表现正常；鼠标穿透主观使用正常，但人物命中范围略偏大，列为非阻塞可改善项。
- 文件处理在 2026-10-08 完成主要人工验收，WebP→JPG 白图问题已修复复验；不为了进入发布阶段重新开发文件处理系统。
- 当前本地规则对话和自主动作足以进入发布前收尾，不因在线 GPT、换装、汉堡等未到素材而阻塞。

## 现阶段剩余外部发布条件

1. 公开上传时请根据实际角色/视频素材来源，核对权利人的粉丝二创与再分发规则；其他 GitHub 二创项目存在，不是本项目的许可证明。
2. GitHub 新建一个空白公开仓库，提供 `owner/repository` 地址。当前连接的 GitHub 应用返回仓库列表为空，本地 `git remote -v` 也为空；本环境无法直接创建仓库或上传 Release 二进制附件。
3. 仓库创建后推送源码（不推原始 MP4、不推角色母版、不将大量 OGV/PNG 放入普通 Git 历史）。再通过 GitHub Releases 上传本机完整 ZIP 和 SHA-256。
4. 如果有条件，另找一台没有安装 Godot 的 Windows 机器下载 ZIP 做实机测试；DPI 与多屏继续标为未测，不必为此改变本人当前系统设置。
