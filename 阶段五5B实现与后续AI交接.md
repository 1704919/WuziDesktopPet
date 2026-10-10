  1 | # 舞梓桌宠阶段五 5B 实现与后续 AI 交接
  2 | 
  3 | 更新：2026-10-08（Asia/Shanghai）；阶段五核心功能人工验收收尾。项目目录：`D:\文件\vup\阿梓宝\桌宠`。
  4 | 
  5 | > **当前统一接手入口。阶段五 5B 核心功能已通过人工验收，最新离线完整回归通过；DPI 125%/150% 与多显示器兼容性仍未实测，用户选择本轮不改变 DPI、不做多屏测试，不可将其标记为已通过。** 阶段四动画、睡眠、情绪与动态命中的稳定约束继续以《阶段四完成与后续AI交接.md》为准。
  6 | 
  7 | > **2026-10-10 发布准备进度（优先于历史状态记录）：** Godot Windows v0.1.0 本地完整便携 ZIP 已生成，包含 38 组加工后动作 OGV/PNG、原生文件桥接组件及版权声明，不包含原始 MP4；ZIP CRC 与全新隔离目录解压后无界面/GUI 启动均通过，原设置未更改。位置为 `dist/WuziDesktopPet-v0.1.0-win64.zip`（351.67 MiB）。**尚未公开上传 GitHub**，远程仓库创建/Release 资源上传及角色素材公开再分发规则仍须完成，详细见 `docs/PUBLIC_RELEASE_PLAN.md`。\n\n> **2026-10-09 状态更新（覆盖本文第 9 节早期“缺少素材”的历史列表）：** 走路/roaming、吃拉面、吃薯条、吃炸鸡与新版睡眠惊醒均已实际接入；肤色端点局部修复详见 `docs/TESTING.md`。当前动作目录还未 ready 的素材只有 `eat_burger`、`slack`、`talk`。随机日常动作默认关闭且动作池为空，权重抽样逻辑待讨论后修正；在线 GPT 对话未接入。阶段五文件处理功能已按 10 月 8 日人工验收收口，仍需阶段六 DPI/多屏/长期运行及独立发布包验收。后续状态首先以**实际代码与配置**为准，不能沿用本文件 10 月 6 日未接入的旧清单。
  8 | 
  9 | > **2026-10-09 晚间更新（此条优先于上段历史状态）：** 用户最终确认 26 个普通随机动作及 A～E 独立类别，权重总和 88，**每 10～20 秒在空闲时尝试**；独立无互动睡眠负责打瞌睡；同类最多连续两次。自主暂停已覆盖随机动作、漫游、自动睡眠和随机闲聊，**不影响喝水、饭点或天气提醒**。新随机动作综合测试与完整隔离回归 29/29 PASS，报告 `docs/baselines/20261009_232557_e03a3a5f/report.json`。功能已经启用；新增彩蛋对话仍待用户提供。以 `docs/TESTING.md` 的「活泼型自主动作正式启用」记录为准。
 10 | 
 11 | ## 1. 当前状态
 12 | 
 13 | - 5A 工作台与规划器已完成，用户已在前轮确认 UI。
 14 | - 5B 已接通真实执行。有效预览会启用“开始处理”，点击后确认当前预览才执行。2026-10-08 已完成核心文件处理人工验收，保留发布前兼容性项目。
 15 | - 支持原位置批量重命名、指定目录复制、PNG/JPG/WebP/HEIC 图片转换。
 16 | - 音频与视频只参与普通文件重命名/复制；音视频转换计划已取消。
 17 | - 未接入在线 AI；聊天不调用真实文件执行。
 18 | - 当前仍按项目目录启动，未制作正式发布安装包。
 19 | 
 20 | ## 2. 文件与职责
 21 | 
 22 | | 文件 | 职责 |
 23 | |---|---|
 24 | | `godot/scripts/file_drop_manager.gd` | 唯一待处理队列、Windows 大小写等价去重、成功项移除、恢复路径保留、Godot Image 编码 |
 25 | | `godot/scripts/file_operation_planner.gd` | 只读规划，目标与操作类型，冲突/依赖检查，源文件大小和修改时间，SHA-256 计划版本 |
 26 | | `godot/scripts/file_operation_executor.gd` | 冻结计划校验、环境复查、两阶段重命名、转换/复制、取消、逐项结果和失败恢复 |
 27 | | `godot/scripts/windows_file_bridge.gd` | 调用 Windows 小型组件、解析结构化结果与中文错误 |
 28 | | `godot/scripts/batch_file_window.gd` | 参数、预览、确认框、后台任务生命周期、状态/进度/重新预览剩余项 |
 29 | | `tools/native/file_bridge.cpp` | Windows 不覆盖文件 API、WIC HEIC 编解码与能力检测 |
 30 | | `tools/build_file_bridge.ps1` | 使用本机 MSVC/Windows SDK 重建小型原生组件 |
 31 | | `godot/native/wuzi_file_bridge.exe` | 当前 x64 原生组件，170,496 字节 |
 32 | 
 33 | 旧 `main.gd::_convert_queued_images()` 仅保留打开工作台的兼容入口。原按 `remove_classification("image")` 整类清队列的实现与旧直接转换流程已经删除。
 34 | 
 35 | ## 3. 执行语义与安全约束
 36 | 
 37 | ### 同一份计划
 38 | 
 39 | 参数或队列变化会重建只读 Plan，摘要覆盖参数、准确源/目标路径、操作类型、源文件状态和问题列表。确认时深复制冻结计划；执行器核对摘要，只复查这份计划中的路径，**不重新应用命名规则**。确认弹窗打开后改参数或队列会撤销旧确认。
 40 | 
 41 | 执行期间参数不可编辑。执行期间有新文件加入队列时，请求取消尚未开始项；新文件留到下一次预览。结果列表保留本次原路径、目标与失败原因，“重新预览剩余”才按当前队列生成下一份计划。
 42 | 
 43 | ### 文件操作
 44 | 
 45 | - 原目录 + 保持格式：原位置重命名，支持只改变大小写。
 46 | - 指定目录 + 保持格式：复制到目标，保留原文件。
 47 | - 图片转换：生成新结果并保留原图；不允许覆盖源或现有目标。
 48 | - PNG/JPG/WebP 使用 Godot Image；JPG 铺白底，质量沿用配置，默认 0.92。2026-10-08 修复 WebP→JPG 全白问题：JPG 合成前将源图统一为 RGBA8，配套增加透明及不透明 WebP 像素内容检查；用户已用原问题图片重新实测确认正常。
 49 | - HEIC/HEIF 输入解码第一帧，HEIC 输出用 Windows WIC 系统组件。读取与写入能力分别检测；组件存在但具体图片不支持时仍按真实失败返回。
 50 | - 未安装系统 HEIC 支持时仍能重命名 HEIC 文件；不假装转换成功，不引入 libheif/FFmpeg。
 51 | - 当前 UI 选择已有输出目录；目录消失或无权限时拒绝执行，不隐式建立缺失输出目录。
 52 | 
 53 | ### 不覆盖与两阶段改名
 54 | 
 55 | Windows 组件使用不带 `MOVEFILE_REPLACE_EXISTING` 的 `MoveFileExW` 和 `CopyFileW(..., TRUE)`，最后一步本身拒绝已有目标。预览与执行之间、编码期间或改名暂存之后出现同名文件，均不得覆盖。
 56 | 
 57 | 相互依赖的重命名组成一个连通组，先全部移至各自原目录中 `.wuzi-rename-<随机标识>.<扩展名>`，再提交最终名称。已开始的组完成两阶段后才响应取消，避免交换/循环停在中间。
 58 | 
 59 | 阶段一失败会尝试恢复暂存源；阶段二失败不会回滚已经成功提交的项目。恢复时仍禁止覆盖；原路径被占用时保留临时文件，结果列出**原路径、临时路径、目标路径**，队列保留实际可恢复路径。
 60 | 
 61 | 转换/复制先写入目标目录中的独占 `.wuzi-output-*` 暂存文件夹，成功后原子不覆盖提交。失败只清理本任务创建的已知临时输出，保留原文件。
 62 | 
 63 | ### 取消与线程
 64 | 
 65 | 后台使用 WorkerThreadPool。执行器只使用自己的 RefCounted 数据、文件和 CPU 图片对象，不操作窗口或队列 Node。状态通过 Mutex 保护的快照交回主线程，只有状态变化才刷新列表。
 66 | 
 67 | 取消只停止尚未开始的项目，当前文件或相互依赖的重命名组先收尾。关闭工作台请求取消并隐藏窗口；重新打开执行中的工作台显示当前进度。节点退出前等待任务收尾。成功项从唯一队列移除，失败/跳过/取消项保留。
 68 | 
 69 | ## 4. 验证证据
 70 | 
 71 | **最新验证（2026-10-08，优先于下面的 2026-10-06 历史基线）：**
 72 | 
 73 | - WebP→JPG 修复专项：`docs/baselines/20261008_221721_4c935b6c/report.json`，隔离、导入、启动、执行器和规划器检查均 PASS；新增不透明 RGB8 WebP 与透明 RGBA8 WebP 转 JPG，检查画面中心非白及透明区域白底，源 WebP 仍保留。
 74 | - 修复后完整离线回归：`docs/baselines/20261008_221920_f214c886/report.json`，运行输出全部 PASS（28 项检查），`SOURCE_UNCHANGED: True`、`SETTINGS_UNCHANGED: True`。这是测试隔离期间源文件和用户设置未被意外改变的校验，并不表示代码未发生有意修复。
 75 | - 用户随后使用先前出问题的 WebP 原图重新测试，反馈“没有问题”；正则表达式和批内重名/非法名称亦补测通过。人工验收是用户反馈，不能当成自动测试报告中的截图证据。
 76 | - 无需因文档收尾重复改动或重建文件处理程序。下次发布构建时仍应在目标 Windows 环境检验原生文件桥接组件及 HEIC 依赖。
 77 | 
 78 | 完整隔离回归（历史 2026-10-06）：`docs/baselines/20261006_143640_3ef1a68c/report.json`。
 79 | 
 80 | - **24/24 通过，`ok=true`。**
 81 | - `source_unchanged=true`、`production_settings_unchanged=true`。
 82 | - 新执行专项实际运行约 13 秒。
 83 | - 既有 `video_runtime_smoke` 退出时仍有 12 个 ObjectDB 实例泄漏警告，与接手前一致；无新增对应失败。
 84 | - 本轮未运行联网天气测试，未修改或重建动画。
 85 | 
 86 | 完整回归后，真实桌面日志暴露 `always_on_top` 与 `popup_centered()` 引入 transient 的冲突。工作台已改用普通独立窗口 `show()` / `grab_focus()` 与显式居中。修复后的真实桌面日志没有该错误：`work/stage5_desktop_preview_fixed.log`。
 87 | 
 88 | 这一最后的显示方式变更再次通过两项 5A/5B 专项，记录在 `docs/baselines/STAGE5B_GUI_FIX.json`。因此完整回归与最后一处 UI 修复的验收证据分别保留，不混写为同一次运行。
 89 | 
 90 | 已覆盖：
 91 | 
 92 | - 计划稳定、参数变更失效、冻结计划被篡改拒绝。
 93 | - 查找替换、前后缀、编号、扩展名保留、Windows 非法/保留名称与批内重名。
 94 | - 多目录、指定目录复制、源变化/消失、目标在预览后出现。
 95 | - A ↔ B 交换、三文件循环、只改大小写。
 96 | - 目标在执行期间出现；原生 move/copy 拒绝覆盖。
 97 | - 改名失败恢复、无法恢复时的临时路径和队列保留。
 98 | - 在隔离样本目录设置真实 Windows ACL，验证不可写目录拒绝并恢复 ACL。
 99 | - PNG/JPG/WebP 文件签名与重新解码，透明 PNG 转 JPG 白底。
- 本机 WIC HEIC 编码 → HEIC 文件签名 → WIC 解码回 PNG。
- 缺少 HEIC 能力的预览阻断、HEIC 普通重命名、损坏图片失败保留。
- 部分成功只移除成功项、取消未开始项、后台执行与确认版本一致。
- 旧阶段四睡眠、点击、情绪、动态命中、对话与气泡等回归。

## 5. 人工验收结果与发布前待测项目

已在真实 Windows 桌面打开隔离工作台并检查空列表、参数区、HEIC 能力说明、底部按钮和独立窗口显示。Computer Use 输入阶段遇到 `user input was detected in this window`、`unknown screenshotId` / `no screenshot targets found`，没有用这些失败尝试冒充完成交互验收。

**2026-10-08 用户亲自操作后的更新（覆盖上面 2026-10-06 旧情况）：**

- 人工验收指引 01～10、12、14～17、19～22 已反馈通过，覆盖选择器与焦点、目录、队列、命名、编号、目标保护、输出复制、图片转换、处理完整链路、处理中关闭重开、桌宠并行与睡眠拖入、最小窗口。
- 第 18 项曾发现 WebP→JPG 输出全白。随后确认不点击取消也能复现，排除“仅按取消才发生”的解释。定位为 JPG 白底混合两幅图像格式未统一；修复后通过透明和不透明 WebP 专项测试、完整回归，并获用户用原问题 WebP 的实机复验“没有问题”。因此第 18 项的**全白缺陷已关闭**；如没有单独证据证明取消过程中所有分支均得到观察，不将该缺陷关闭等同于对复杂取消时序的额外穷尽验证。
- 第 11 项正则、第 13 项批内重名/非法命名：用户补测后明确反馈“均通过测试”。
- **未实机测试：第 23 项 Windows DPI 125%/150%，第 24 项多显示器。** 两项留待发布前不同显示环境验收；没有测试的项目不标通过。
- 本阶段结论：**核心功能人工验收通过，兼容性验收待补。** 不要求因这两项未测而阻塞当前阶段日常开发收尾，也不声称达到完整发布质量。

可使用隔离项目中的 `res://tests/stage5_desktop_preview.gd`。该脚本要求 `user://` 位于 `WuziPetBaseline`，会创建两份专用样本，打开带“5B 隔离验收”标题的工作台；勿把 smoke 脚本直接运行在日常项目用户目录。

## 6. 继续开发和发布注意

- 阶段五需求依据仍在阶段四交接第 16 节；具体实施方案：`docs/godot-prompter/plans/2026-10-06-stage5b-safe-execution.md`。
- 当前状态为“5B 核心功能人工验收通过；DPI 和多屏发布前待测”。后续只在出现新缺陷、需求变更或发布准备时重新打开文件处理模块。
- 原生组件是本项目 MIT 源码的构建产物，系统编解码器不随包分发。重建和以后导出所需外置 exe 位置见 `godot/native/README.md`。
- 以后导出时应把 `native/wuzi_file_bridge.exe` 放在桌宠 exe 旁的 native 文件夹中；当前启动器仍依赖本机 Godot。未完成发布包验收。
- 源文件二次检查使用文件大小和修改时间，未对每次 UI 预览中的所有大文件计算内容哈希。
- 不包含整批撤销或断电后的自动恢复界面；操作失败会明确保留和报告恢复路径。
- 不顺手重写睡眠、动画、命中、对话，不改变 HEIC 系统组件路线。

## 7. 回退点

实现前快照：`backups/stage5b_20261006_142137_pre/`，含 `sha256.json`。

快照保存了旧脚本、场景、配置、测试、工具和交接文档。本次新增 Executor、WindowsFileBridge、native exe/源码/构建脚本、执行专项和桌面样本脚本。需要回退时先核对后续更改，按快照恢复本轮修改文件，并单独审阅这些新增文件；不要覆盖后来用户工作或删除用户样本/结果。

## 8. 当前收尾地图（2026-10-06）

当前已经不是“大量主功能尚未实现”的阶段，而是进入最终收尾。按当前正式需求估计：

- **核心软件功能约 85%～90% 完成**；
- 如果把全部计划动作素材、计划外新增动画、完整 Windows 人工验收和正式发布包都计入，整体约 **70%～80% 完成**；
- 阶段一至四的软件主线已完成；阶段五 5A/5B 的实现基本完成，主要剩真实桌面人工验收；
- 最终剩余工作主要集中在：动画素材补齐与新增动作接入、阶段六整体验收、发布打包，以及少量已知文案/工程尾项。

阶段六必须继续覆盖真实 Windows 环境下的：

- 原生文件/文件夹/输出目录选择器与取消后的焦点恢复；
- “预览 → 确认 → 执行 → 结果 → 重新预览剩余”的完整鼠标流程；
- 执行期间关闭/重开文件工作台及与桌宠点击、拖拽、睡眠、气泡并发；
- 中文输入法、真实鼠标穿透、拖拽/抛掷手感；
- 不同 DPI、多显示器、窗口位置/焦点；
- 长时间运行、启动/待机资源占用和反复开关窗口后的资源释放；
- 天气设置界面“每 30 分钟检查”与实际 `check_interval_minutes = 600`（10 小时）的文案一致性。

当前仍未完成正式独立发布包。最终发布需要 Godot Windows 导出、`native/wuzi_file_bridge.exe` 随包放置、资源打包及独立目录/干净环境启动验证。

## 9. 动画素材与后续新增动作规则

当前运行架构允许继续增加动作，但素材构建器还不是“把 MP4 放进去就自动识别”的完全数据驱动方案。

新增动作正式接入通常需要同步更新：

1. `tools/build_q_video_assets.py` 的 `ACTIONS` 与 `RUNTIME_ACTION_IDS`；
2. `godot/config/action_catalog.json` 的动作状态与 `source_action`；
3. `godot/config/pet_behavior.json` 的 clip、点播分类或触发条件；
4. 必要时补专用绿幕保护色、布局、睡眠姿态等处理规则；
5. 使用 `Q_VIDEO_ACTIONS=<id[,id...]>` 局部构建；
6. 重新运行素材校验、专项测试、完整回归和人工视觉验收。

当前已知待补/待替换素材：

- `walk_left`
- `walk_right`
- `eat_noodles`
- `eat_fries`
- `eat_fried_chicken`
- `eat_burger`
- `slack`
- `talk`
- `wake_up_video`：代码已接通，但现有视觉尺寸变化问题，仍需替换源素材。

注意：走路素材到位不等于 roaming 已完成。当前 `movement_catalog` 只具备加载基础，正式代码没有完整消费 `PetState.ROAMING` 的桌面漫游运行链。如果最终要求舞梓自动在桌面左右行走，需要另行实现并验收 roaming 状态机。

随机 idle 动作逻辑已经存在，但当前 `idle_actions.enabled=false` 且动作列表为空。等普通动作库更丰富后再统一配置权重和启用，不应为了现在凑功能提前开启空随机系统。

### 9.1 2026-10-06 新视频接入完成

本批 6 个视频已经完成正式接入：

- `正常打游戏.mp4` → `game_controller` / `game_controller_video`；
- `坐下看书.mp4` → `read_book` / `read_book_video`；
- `盯盘-看K线.mp4` → `watch_kline` / `watch_kline_video`；
- `喝奶茶.mp4` → `drink_milk_tea` / `drink_milk_tea_video`；
- `使用电脑工作.mp4` → `work_computer` / `work_computer_video`；
- `躺下玩手机.mp4` → `lie_phone` / `lie_phone_video`。

处理结果：

- 6 个源视频均为 1280×720、24 fps、241 帧、约 10.04 秒；
- 均已生成 121 帧、12 fps 的透明 PNG 回退序列、`runtime_alpha.ogv`、manifest 和动态 hit shape；
- `盯盘看 K 线` 与 `躺下玩手机` 的远离主体小型水印/背景残片已通过“保留主体和大型独立道具、只清理远距离小组件”的专项后处理清除，没有粗暴裁边；
- `坐下看书` 与 `盯盘看 K 线` 含书本/显示屏等大型前景道具，因此素材校验器只豁免其“上半身轮廓核心宽度”误判，物理缩放、画布边界、色彩、运行视频、hit shape 等其他检查仍保留；
- 6 套素材已经写入 `video_visual_baseline.json`，固定 000/060/120 三帧 RGBA 哈希并保留最低填充率检查；
- 右键点播已接入：`喝奶茶` 进入“吃饭动作”，其余 5 个进入“一般动作”；没有擅自启用随机 idle 或自动对话触发；
- 6 个源视频已经从 `分享区/Q版/新视频/` **剪切**到 `分享区/Q版/绿幕视频/`，当前 `新视频` 为空；
- 移动后已重新从正式 `绿幕视频` 路径局部构建，6 个 manifest 的 `source` 均指向正式目录；
- 最终素材校验 `py -3 tools/verify_q_video_assets.py` 已通过，`failures=[]`；
- 更新 `ui_smoke` 的动作分类/数量预期后，完整回归 `py -3 tools/run_baseline_tests.py` **26/26 通过**，并确认 `SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`。

本批同时扩展了素材校验器的 `Q_VIDEO_BASELINE_CANDIDATES` 模式：它只生成待人工批准的视觉基线候选，不会自动修改正式基线，供后续继续增加计划外动画时复用。

### 9.2 新动作首尾衔接校准（2026-10-06）

用户桌面验收发现：

- `drink_milk_tea` 人物偏小；
- `read_book` 人物偏大；
- `watch_kline` 人物本体轻微左偏；
- `lie_phone` 人物偏小；
- 问题会在“待机 ↔ 动作”切换时表现为轻微大小/位置跳变。

处理原则：只做**单动作局部校准**，不修改全局 `TARGET_VISIBLE_HEIGHT`、`TARGET_CENTER_X` 等已经稳定的标准。

实际校准：

- `drink_milk_tea`：`ACTION_FIXED_SCALE_OVERRIDES = 1.055`，目标可见高度由约 208.3 px 调整到约 **219.7 px**；
- `read_book`：`ACTION_FIXED_SCALE_OVERRIDES = 0.97`，目标可见高度由约 226.1 px 调整到约 **219.3 px**；
- `lie_phone`：`ACTION_FIXED_SCALE_OVERRIDES = 1.05`，目标可见高度由约 208.0 px 调整到约 **218.4 px**；
- `watch_kline`：大小保持不变，增加 `ACTION_TARGET_CENTER_X_OFFSETS = +8 px`。原因是右侧 K 线屏幕把整套前景几何中心向右拉，旧算法将“人物+显示屏整体”居中后导致人物本体左偏。

构建器 `render_canvas()` 已改为读取每个 action anchor 的 `target_center_x / target_bottom_y`；默认值仍是全局标准，因此没有 override 的旧动作行为不变。

校准后重新局部构建并人工检查首帧与 contact sheet；4 套动作的 000/060/120 三帧正式视觉基线已更新。最终：

- `py -3 tools/verify_q_video_assets.py`：**通过，failures=[]**；
- `py -3 tools/run_baseline_tests.py`：**26/26 通过**；
- `SOURCE_UNCHANGED=True`；
- `SETTINGS_UNCHANGED=True`。

### 9.3 跨动作首尾衔接一致性检查（2026-10-06）

为避免后续继续依赖“肉眼发现一个、再修一个”，`tools/verify_q_video_assets.py` 已加入普通动作跨动作首尾衔接一致性审计。

检查以 `idle` 为基准，并对每个普通动作同时记录：

- manifest 的有效目标可见高度；
- 000 / 120 首尾帧实际透明包围盒高度；
- 首尾帧水平中心；
- 首尾帧底边位置；
- 首尾帧 identity core 宽度（辅助诊断，不单独作为硬失败条件）。

阈值分两层：

- 尺度达到约 ±3%、水平中心偏差达到 4 px、底边偏差达到 3 px：进入 `transition_consistency.reviews`；
- 尺度超过约 ±4%、水平中心偏差超过 8 px、底边偏差超过 6 px：进入 `transition_consistency.strict_failures`；
- 设置 `Q_VIDEO_STRICT_TRANSITIONS=1` 时，严格失败项会让素材校验器以非零状态退出。

睡眠特殊链 `sleep_down / sleep_loop / wake_up` 明确排除在普通动作规则之外。它们继续使用独立的睡眠链检查，后续单独讨论，不为了通过普通站立动作标准强行拉成 idle 尺寸。

校准前的严格模式曾识别到普通动作硬失败候选 10 个：

- `march_in_place`
- `sleepy`
- `yawn`
- `drag_reaction`
- `startle`
- `game_rage`
- `click_wave`
- `game_controller`
- `read_book`
- `work_computer`

其中 `read_book` 很有代表性：manifest 理论目标高度已经接近 220 px，但实际首尾帧透明人物高度仍比 idle 高约 6%～7%，说明只看 manifest 会漏掉真实衔接问题。

校准前另外有 `click_happy / click_shy / yawn_small` 三项属于 review-only。后续校准已解决 `click_shy / yawn_small` 的实际首尾差异；`click_happy` 目前只剩 manifest 理论值提示，实际首尾严格检查通过。

当前策略：默认素材校验继续用于“素材本身是否健康”；严格模式单独用于普通动作跨动画一致性审计。新增或重建动画后必须额外运行严格模式。睡眠链仍保持独立，不纳入普通动作门禁。

### 9.4 普通动作尺寸统一完成（2026-10-06）

按严格首尾检查和人工 contact sheet 复核，对历史普通动作进行了单动作尺寸校准，未修改全局 idle 标准，也未修改 `sleep_down / sleep_loop / wake_up`。

新增/调整的局部 scale override：

- `march_in_place = 1.042`
- `sleepy = 1.055`
- `yawn = 1.047`
- `startle = 1.050`
- `game_rage = 1.057`
- `click_wave = 1.040`
- `yawn_small = 1.035`
- `game_controller = 1.050`
- `work_computer = 1.040`
- `read_book = 0.908`
- `click_shy = 1.015`

保留原有 `click_happy = 0.96` 与 `drag_reaction = 1.10`。这两项虽然 manifest 理论目标高度与 idle 有差异，但实际 000/120 首尾帧已通过严格尺度、中心和底边检查，因此不为了“让理论数字一致”继续硬改。

`read_book` 与 `watch_kline` 含大型前景道具，旧 `standing_height_delta` 会把道具/姿势包围盒误判为人物尺寸，因此与已有 identity-core 豁免保持一致，只跳过这条旧包围盒高度检查；实际首尾严格检查仍完整执行。

校准后结果：

- 普通动作 `transition_consistency.strict_failures = []`；
- 默认 `py -3 tools/verify_q_video_assets.py`：**通过，failures=[]**；
- 严格 `Q_VIDEO_STRICT_TRANSITIONS=1 py -3 tools/verify_q_video_assets.py`：**通过，failures=[]**；
- 完整 `py -3 tools/run_baseline_tests.py`：**26/26 通过**；
- `SOURCE_UNCHANGED=True`；
- `SETTINGS_UNCHANGED=True`。

严格报告仍有 3 个 review-only 理论提示：`click_happy / drag_reaction / read_book` 的 manifest 目标高度与 idle 有差异，但实际首尾帧全部通过，不属于当前尺寸故障。

### 9.5 普通动作切换淡出/淡入（2026-10-06）

为进一步降低极小尺寸/位置差异在硬切瞬间的视觉存在感，普通动作切换新增短暂的“淡出 → 原子切换 → 淡入”过渡。

实现原则：

- 使用 `PetVisual/BodyPivot.modulate.a` 统一控制 PNG Sprite 与 runtime OGV 的整体透明度；
- 第二版为减少“完全消失”造成的闪烁，改成 **45 ms** 从 alpha 1.0 下潜到 **0.55**，在浅层透明中点切换纹理/VideoStreamPlayer 与动态 hit shape，再用 **60 ms** 回到 alpha 1.0；不再让角色彻底消失；
- 不使用“两个人物同时半透明叠加”的传统 cross-fade。此前已经验证透明角色帧直接交叉混合会在头发和服装边缘产生发亮/重影；
- 普通动作 A 抢占普通动作 B 时，旧画面一直保留到淡出中点，不再先瞬间回到 idle；
- 普通动作结束回 idle 时同样在透明中点切回 idle；
- `reduce_motion=true` 时不启用该过渡。

明确排除：

- 点击 Q 弹 / click reaction：保持即时反馈，不参与普通过渡；
- 拖拽反应：保持拖动即时性；
- `sleep_down / sleep_loop / wake_up`：睡眠链继续沿用专用连续性逻辑，不套普通淡出淡入；
- 动画内部逐帧/视频播放：不做帧间淡化，只处理动作边界。

自动验证已覆盖：

- PNG fallback 的普通动作进入和返回 idle 确实经过 alpha 淡出/淡入；
- runtime OGV 普通动作能观测到 alpha 经过中点并恢复为 1；
- 普通动作 A → B 抢占时，中点前仍保持 A 的 hit/action，不闪回 idle；
- click reaction 不启用普通过渡且 alpha 保持 1；
- sleep loop 不启用普通过渡且 alpha 保持 1；
- dynamic hit shape、睡眠、Q 弹专项均通过；
- 完整 `py -3 tools/run_baseline_tests.py`：**26/26 通过**；
- `SOURCE_UNCHANGED=True`；
- `SETTINGS_UNCHANGED=True`。

这套过渡主要用于隐藏已经处于严格阈值内的细微视觉差异，不能代替尺寸校准；新增素材仍必须先通过严格首尾一致性检查。

## 10. Dead-code 第二批审计结论（只审计，尚未删除）

第一批高置信度 dead code 已于提交 `9d9c7ca refactor: remove confirmed dead code` 清理并通过 26/26 回归。

第二批当前审计结论：

- `main.gd::_convert_queued_images()`：全正式工程只有定义，没有调用；旧气泡转换流程已经退出，当前只是无调用兼容包装，**可删除**；
- `MENU_CLEAR_FILES`：右键菜单已不再创建该项，Main 处理分支不可达，**可删除旧菜单 ID、Main 常量和 match 分支**；但 `FileDropManager.clear_queue()` 与工作台“清空”按钮仍在正式使用，**不得删除底层清空能力**；
- 旧 Bubble action `convert_png / convert_jpg / convert_webp`：当前正式工程没有任何生成方，Bubble 不持久化旧按钮状态，现有分支仅是历史安全兜底，**可删除**；
- `main.gd::_on_file_queue_changed()`：Main 连接了 `queue_changed`，但函数体只有 `pass`；真正工作台已有自己的有效 `queue_changed` 处理，**可删除 Main 的空连接与空回调**；
- `FileDropManager.queue_changed` signal、`FileDropManager.clear_queue()`、`BatchFileWindow._on_queue_changed()` 和 `BatchFileWindow._clear_queue()` 均为正式功能，**不得误删**。

如执行第二批，建议仍拆成两个小提交并分别跑专项和完整回归，不与动画接入混在同一提交中。

## 11. 2026-10-07 当前改动收口

本轮停止继续扩展功能，只收口已有改动。当前实际代码已经超过本文件前部的 10 月 6 日状态，以下内容以当前代码与最新回归为准：

- 桌面漫游已经正式接通，`walk_left / walk_right` 素材、`movement_catalog.json`、`PetRoamingController` 以及对应 smoke test 均已存在，正式配置当前启用 roaming；
- 右键动作点播已经改为分类菜单，并实现分类内上翻/下翻；
- 彩蛋与对话规则继续扩展，包含生日自动触发及对应持久化状态；
- 动画播放主体已经从 `main.gd` 拆分到 `godot/scripts/pet_animation_playback.gd`，保留原有 token 取消、runtime OGV、PNG fallback、预取、动态 hit frame 与淡出/淡入语义；
- `main.gd` 当前约 2010 行；文件工作台主脚本也已拆出 UI、Theme 和 FilePicker 边界。

当前最终文件状态已重新运行完整离线回归：

- 基线：`docs/baselines/20261007_225508_44985dd2/report.json`；
- **28/28 checks PASS**；
- `SOURCE_UNCHANGED=True`；
- `SETTINGS_UNCHANGED=True`；
- 没有因为本轮测试改写正式源码或日常用户设置。

同时完成的收口验证：

- `py -3 tools/verify_q_video_assets.py`：通过，`failures=[]`；
- `Q_VIDEO_STRICT_TRANSITIONS=1 py -3 tools/verify_q_video_assets.py`：通过，`strict_failures=[]`；
- 严格模式仍保留 `click_happy / drag_reaction / read_book` 三项 review-only 理论提示，但实际首尾帧均未进入严格失败，不作为当前阻塞项；
- `py -3 tools/verify_runtime_video_decode.py`：通过；
- `py -3 -m py_compile tools/build_q_video_assets.py tools/verify_q_video_assets.py tools/verify_runtime_video_decode.py tools/run_baseline_tests.py`：通过。

因此当前改动可以视为**代码与自动验证层面的收口完成**。下一阶段不应继续夹带新功能，应转入真实 Windows 桌面整体验收、长时间运行检查，以及最终独立发布包验证。

## 12. 2026-10-08 五个新视频正式接入与网络中断恢复

本批按用户确认**全部作为新动作独立保留**，没有替换原有「打游戏暴怒」和「正常打游戏」动作，也没有重建其他旧动作：

| 正式源视频 | 新动作 ID | 右键分类 |
|---|---|---|
| `拆卡.mp4` | `unbox_cards` | 日常动作 |
| `打电脑游戏暴怒.mp4` | `pc_game_rage` | 娱乐动作 |
| `得意墨镜.mp4` | `sunglasses_proud` | 日常动作 |
| `认真打电脑游戏.mp4` | `pc_game_focused` | 娱乐动作 |
| `原地蹦蹦跳.mp4` | `hop_bounce` | 日常动作 |

- 新视频从 `分享区/Q版/新视频/` **剪切**到 `分享区/Q版/绿幕视频/`；移动前后分别计算 SHA-256，五份均相同；新视频目录检查为空。
- 构建流程：只对五个新 ID 局部执行 `py -3 tools/build_q_video_assets.py --actions unbox_cards,pc_game_rage,sunglasses_proud,pc_game_focused,hop_bounce`。正式源路径再构建完成；每套输出 121 帧、12 fps 的 480×360 透明 PNG、独立 `runtime_alpha.ogv`、manifest、动态 hit shape、审核联系图。旧视频资产未纳入本轮构建。
- 涉及 `tools/build_q_video_assets.py` 的新 ACTIONS / RUNTIME_ACTION_IDS、局部背景处理及动作独立尺寸/位置补偿；`tools/verify_q_video_assets.py` 新增五组验收目标、方法要求及正式源文件集合；`godot/config/action_catalog.json` 和 `godot/config/pet_behavior.json` 接入新 ID、右键菜单和 clip 定义；`godot/config/video_visual_baseline.json` 为五组 000/060/120 帧批准哈希和最低填充率建档；`godot/tests/ui_smoke.gd`、`godot/tests/manual_action_smoke.gd` 同步更新。
- 严格视频素材校验 `Q_VIDEO_STRICT_TRANSITIONS=1 py -3 tools/verify_q_video_assets.py` 最终 **exit 0**，`failures=[]`，`strict_failures=[]`。有历史动作的 review-only 理论提示，以及新拆卡首尾约 5～5.5 px 的中心偏差提示；均未触发严格失败。后续用户应重点人工观看实际待机与拆卡切换。
- `py -3 tools/verify_runtime_video_decode.py` **exit 0**。新增素材联系图位于 `work/video_review/processed/<id>_processed_contact.jpg`，可用于人工检查抠像与尺寸；自动化验证不能替代完整动态目测。
- 中途一次完整回归在网络中断时只生成了 `docs/baselines/20261008_232240_72020e74/` 内隔离、导入日志，不具备最终报告，**不得宣称该次通过**。
- 恢复后重新执行 `py -3 tools/run_baseline_tests.py`，**28/28 PASS**；报告 `docs/baselines/20261008_232508_0a64c9e2/report.json`，`SOURCE_UNCHANGED=True`，`SETTINGS_UNCHANGED=True`。
- 后续人工验收：分别从右键分类点播这五项，检查背景完全透明、无水印残留、角色和道具完整、待机↔动作首尾尺寸/位置、播放连贯、点击区域及菜单分页。特别留意拆卡的微小横向偏差，以及两段电脑游戏动作道具是否出现残影。**人工实机视觉验收尚未完成，不写成已通过。**
- 本次新增素材后，仍保留阶段六长时间运行、发布包、DPI / 多显示器等事项；不借新增动作任务顺带重构稳定的文件处理、睡眠或对话功能。

