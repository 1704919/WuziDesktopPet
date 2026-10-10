  1 | # 舞梓桌宠代码瘦身实施规划
  2 | 
  3 | 日期：2026-10-06  
  4 | 状态：准备执行  
  5 | 目标文件：`godot/scripts/batch_file_window.gd`、`godot/scripts/main.gd`
  6 | 
  7 | 关联文档：
  8 | 
  9 | - `docs/PROJECT_HEALTH_CHECK_20261006.md`
 10 | - `阶段五5B实现与后续AI交接.md`
 11 | - `docs/TESTING.md`
 12 | 
 13 | ## 1. 目标
 14 | 
 15 | 在**不改变现有行为**的前提下，逐步降低两个大型脚本的职责密度和后续修改成本。
 16 | 
 17 | 本轮不是功能开发，也不是重写。
 18 | 
 19 | 成功标准不是“代码更漂亮”，而是：
 20 | 
 21 | 1. 原有功能表现不变；
 22 | 2. 原有配置含义不变；
 23 | 3. 原有信号和调用时序不变；
 24 | 4. 原有测试继续通过；
 25 | 5. 每次拆分都能通过 Git 单独回退；
 26 | 6. 大文件逐步变成“协调器”，具体职责转移到边界清楚的小模块。
 27 | 
 28 | ## 2. 不可违反的总原则
 29 | 
 30 | ### 2.1 只搬家，不改行为
 31 | 
 32 | 拆分时禁止顺手做以下事情：
 33 | 
 34 | - 修复旧 Bug；
 35 | - 改 UI 文案、颜色、尺寸或布局；
 36 | - 改函数语义；
 37 | - 改参数默认值；
 38 | - 改配置结构；
 39 | - 改 signal 时序；
 40 | - 优化算法；
 41 | - 改动作效果；
 42 | - 改睡眠概率；
 43 | - 改文件处理规则；
 44 | - 改 Planner / Executor / native bridge 的安全语义；
 45 | - 进行与当前拆分无关的重命名或格式化。
 46 | 
 47 | 如果发现旧问题，只记录，不夹带修复。
 48 | 
 49 | ### 2.2 一次只拆一个职责块
 50 | 
 51 | 每一步固定流程：
 52 | 
 53 | ```text
 54 | 选择一个低耦合职责块
 55 | ↓
 56 | 确认依赖和测试覆盖
 57 | ↓
 58 | 只移动代码
 59 | ↓
 60 | 运行专项测试
 61 | ↓
 62 | 运行完整离线回归
 63 | ↓
 64 | 全部通过
 65 | ↓
 66 | 检查 Git diff
 67 | ↓
 68 | 单独提交
 69 | ↓
 70 | 再进入下一块
 71 | ```
 72 | 
 73 | 测试失败时立即停止，不继续下一块。
 74 | 
 75 | ### 2.3 先 Git，再改正式源码
 76 | 
 77 | 在首次修改 `main.gd` 或 `batch_file_window.gd` 前：
 78 | 
 79 | 1. 创建合适的 `.gitignore`；
 80 | 2. 初始化 Git；
 81 | 3. 验证当前基线；
 82 | 4. 提交当前稳定状态；
 83 | 5. 后续每拆完一块并通过测试，单独提交一次。
 84 | 
 85 | ## 3. Git 范围
 86 | 
 87 | Git 本轮主要保护：
 88 | 
 89 | - `godot/scripts/`
 90 | - `godot/scenes/`
 91 | - `godot/config/`
 92 | - `godot/shaders/`
 93 | - `godot/tests/`
 94 | - `godot/project.godot`
 95 | - `tools/` 中的源码和脚本
 96 | - 根目录启动脚本
 97 | - 关键 README / 交接 / 规划 / 测试文档
 98 | 
 99 | 默认不跟踪：

- `godot/.godot/`
- `godot/test_output/`
- `work/`
- `backups/`
- `docs/baselines/`
- Python `__pycache__/`
- 临时日志、缓存、构建产物
- `.ai-bridge/` 的运行时协调文件
- 可由素材流水线重新生成的大批运行帧 `godot/assets_display/`

说明：大型素材和历史备份继续保留在磁盘；本轮 Git 的首要用途是**安全回退代码瘦身**，不是马上制作可独立克隆发布的完整发行仓库。

## 4. 拆分顺序

### 阶段 A：batch_file_window.gd

先处理该文件，因为危险的业务规则已经位于：

- `file_operation_planner.gd`
- `file_operation_executor.gd`
- `windows_file_bridge.gd`

本轮明确不修改以上三者行为。

#### A1. Theme / Style 辅助代码

优先级：最高  
风险：低

候选内容：

- `_panel_style()`
- `_workbench_theme()`
- `_tooltip_panel_style()`
- `_button_style()`
- `_input_style()`
- `_list_panel_style()`
- `_list_focus_style()`
- `_list_selected_style()`
- `_help_button_style()`

目标：

- 搬到独立 UI theme/helper 脚本；
- 原颜色、尺寸、圆角、边框、返回类型全部保持；
- `batch_file_window.gd` 只调用新 helper。

禁止：

- 顺手统一颜色；
- 改主题数值；
- 改视觉风格。

#### A2. UI 构建辅助

风险：低至中

候选：

- section title；
- line field；
- spin field；
- help button；
- 纯控件创建逻辑。

目标：缩短 `_build_ui()`，但保持 Node 层级和 signal 连接行为不变。

#### A3. 文件 / 文件夹选择辅助

风险：中

候选：

- FileDialog 创建；
- 添加文件；
- 添加文件夹；
- 输出目录选择；
- 文件夹遍历。

注意：

- 不改 queue 语义；
- 不改扩展名判断；
- 不改 Planner 参数。

#### A4. 暂停点

完成 A1–A3 后重新评估，不强制继续拆。

如果文件已经明显降到可维护范围，可以先停止，避免为了行数继续制造碎片化模块。

## 5. main.gd 拆分顺序

Main 耦合更深，因此排在 BatchFileWindow 之后。

### M1. 窗口位置 / 窗口布局

风险：低至中

候选：

- `_configure_window()`
- `_position_is_visible()`
- `_persist_window_position()`

重点保护：

- 多显示器可见性判断；
- 历史位置迁移；
- settings_store 写入时序；
- borderless / transparent / always-on-top 设置。

### M2. 右键动作菜单

风险：中

候选：

- 菜单构建；
- category map；
- manual action map；
- 菜单 id 路由。

重点保护：

- 菜单项顺序；
- ID；
- action priority；
- sleep / overlay 状态下行为。

### M3. 拖拽 + 抛掷

风险：中

重点保护：

- drag threshold；
- 窗口位置；
- throw velocity；
- 状态切换；
- Q 弹与拖拽之间的优先级；
- 鼠标穿透。

### M4. 睡眠状态控制

风险：中高

重点保护：

- 20 分钟无互动规则；
- 休息检查区间；
- 睡眠概率；
- sleep loop 次数；
- dream talk；
- 哪些交互惊醒 / 不惊醒；
- wake priority。

### M5. 动画 / clip runtime

风险：高，最后处理

原因：

- 与 active clip、hit shape、mouse passthrough、state、action coordinator、sleep、点击反馈高度交织；
- 是最容易产生“代码看起来只是搬家，但时序发生变化”的区域。

因此只有前面拆分流程已经被证明稳定后才处理。

## 6. 每块拆分的验收门槛

### 6.1 静态检查

确认：

- 没有夹带无关修改；
- 新模块职责单一；
- Main / BatchFileWindow 仍是协调器；
- 没有复制出两份状态源；
- 没有新增循环依赖；
- 没有把安全业务逻辑搬进 UI。

### 6.2 专项测试

按拆分内容选择现有 smoke test。

BatchFileWindow 相关至少关注：

- `stage5_file_planner_smoke`
- `stage5_file_executor_smoke`
- `stage5_desktop_preview`（适用时）
- UI smoke（适用时）

Main 相关按职责选择：

- manual action
- click happy
- dynamic hit shape
- inactivity sleep
- stage4 mood action
- video runtime
- dialogue / bubble
- feature smoke

### 6.3 完整离线回归

每个正式拆分提交前运行：

```powershell
py -3 tools/run_baseline_tests.py
```

必须保持完整回归通过。

### 6.4 Git 检查

每个提交前检查：

- 只包含当前职责块；
- 无测试产生物被误纳入；
- 无大型缓存或备份被纳入；
- 无无关格式化；
- 无行为修改。

## 7. 提交策略

建议提交粒度：

```text
chore: establish refactor baseline
refactor: extract batch workbench theme helpers
refactor: extract batch workbench ui helpers
refactor: extract batch workbench file selection helpers
refactor: extract pet window layout controller
refactor: extract pet context action menu
...
```

每个 `refactor:` 提交必须对应：

- 一个职责块；
- 一次完整通过的测试结果；
- 一个明确可回退点。

## 8. 明确不在本轮顺手处理的事项

以下问题存在，但与当前瘦身分开：

- `tools/build_q_video_assets.py` 过大；
- Python 依赖清单；
- Godot 路径硬编码；
- baseline 日志保留策略；
- `popup_card_window.gd` 是否遗留；
- roaming 的 `movement_catalog.json`；
- 新格式支持；
- 新动作、新 UI、新功能。

它们只能在后续独立任务中处理。

## 9. 何时停止瘦身

不追求把每个脚本都拆成很小。

出现以下情况即可停止：

- 每个剩余大函数仍然职责清楚；
- 新增常规功能不再需要频繁修改多个无关区块；
- 状态所有权清楚；
- 拆分继续进行的收益低于新增模块带来的跳转成本；
- 测试和交接已经能清楚说明边界。

## 10. 当前执行状态

当前执行进度：

- 健康检查已完成；
- Git 已初始化，稳定基线提交：`ae9de24 chore: establish refactor baseline`；
- Git 基线建立前重新运行完整离线回归：24/24 通过；
- A1 Theme / Style 辅助代码已完成：
  - 新增 `godot/scripts/batch_workbench_theme.gd`；
  - `batch_file_window.gd` 只改为委托调用，样式数值保持不变；
  - `batch_file_window.gd` 从约 1004 行降至约 823 行；
  - 专项检查 `ui_smoke`、`render_ui_previews`、`stage5_file_planner_smoke`、`stage5_file_executor_smoke` 通过；
  - 完整离线回归 24/24 通过；
  - `SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`；
- 桌面人工验收仍有未完成项目；
- A2 UI 构建辅助已完成：
  - 新增 `godot/scripts/batch_workbench_ui.gd`；
  - `section title / line field / spin field / help button` 的原创建逻辑原样搬入 helper；
  - 原 Node 创建参数、添加顺序和帮助按钮样式调用保持不变；
  - 专项检查 `ui_smoke`、`render_ui_previews`、`stage5_file_planner_smoke`、`stage5_file_executor_smoke` 通过；
  - 完整离线回归 24/24 通过；
  - `SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`；
- A3 文件 / 文件夹选择辅助已完成：
  - 新增 `godot/scripts/batch_workbench_file_picker.gd`；
  - FileDialog 的模式、文件系统访问、native dialog 和 signal 连接参数原样搬入 helper；
  - 目录递归的符号链接跳过、`.wuzi-` 临时项跳过、递归条件原样搬入 helper；
  - queue enqueue/remove、文件分类、Planner / Executor 仍保留原所有权，没有复制业务规则；
  - 专项检查 `ui_smoke`、`render_ui_previews`、`stage5_file_planner_smoke`、`stage5_file_executor_smoke` 通过；
  - 完整离线回归 24/24 通过；
  - `SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`；
  - Windows 原生选择器的完整人工验收仍属于原有待验收项，本次自动测试不替代人工验收；
- A4 暂停点重新评估已完成：
  - `batch_file_window.gd` 已从约 1004 行降至 **704 行**，约减少 30%；
  - 当前剩余最大函数仍是约 268 行的 `_build_ui()`，但内容主要是一次性的声明式控件组装；
  - 继续把 `_build_ui()` 强行拆到更多外部模块，需要传递大量控件引用和 callback，容易用“文件更短”换来“跨文件跳转和接线更复杂”；
  - Planner / Executor / native bridge 的安全边界保持原样；
  - **结论：推荐在此暂停 BatchFileWindow 瘦身。** 后续若文件工作台 UI 进入大改，再围绕具体改动继续拆分；
- BatchFileWindow 阶段 A 完成；
- M1 窗口位置 / 窗口布局已完成：
  - 新增 `godot/scripts/pet_window_layout.gd`；
  - `WINDOW_LAYOUT_VERSION`、`LEGACY_PET_X`、窗口 flag / size / initial position / 历史位置迁移 / 多屏可见性判断原样搬入；
  - `main.gd` 的 `_persist_window_position()` 保留为薄包装，避免修改拖拽、重置等多个原调用点；
  - 专项检查 `ui_smoke`、`bubble_passthrough_smoke`、`dynamic_hit_shape_smoke`、`manual_action_smoke` 通过；
  - 完整离线回归 24/24 通过；
  - `SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`；
  - 多显示器位置恢复仍属于原桌面人工验收范围；
- M2 右键动作菜单已完成：
  - 新增 `godot/scripts/pet_context_menu.gd`；
  - 菜单 ID、固定锚点、根菜单内容、设置菜单、动作分类、动作列表和分类过滤原样搬入；
  - Main 保留 `_open_control_menu()`、`_open_settings_menu()`、`_open_action_picker()`、`_open_action_category()` 薄包装，保持现有 deferred call 和测试入口；
  - Main 仍负责天气、提醒、文件工作台、重置位置、退出、睡眠判断和真正动作播放等业务行为；
  - 原菜单常量在 Main 中改为引用 `PetContextMenu` 的别名，保证外部测试访问方式不变且数值只有一个来源；
  - 专项检查 `ui_smoke`、`manual_action_smoke`、`feature_smoke`、`inactivity_sleep_smoke` 通过；
  - 完整离线回归 24/24 通过；
  - `SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`；
- M2 已提交：`3950116 refactor: extract pet context menu`；
- M3 拖拽 + 抛掷采用**缩小范围方案**并已完成：
  - 新增 `godot/scripts/pet_drag_throw_motion.gd`；
  - 只迁出无副作用的拖拽弹簧、抛掷初速度、重力、碰撞、反弹和停止条件计算；
  - `_begin_drag()` / `_end_drag()`、睡眠打断、动作协调、点击反应、PetState 切换、窗口位置写入仍由 Main 持有；
  - 保留“reduce_motion / throw disabled 时不重写旧 throw_velocity”的原有细节；
  - 新增 `godot/tests/drag_throw_motion_smoke.gd`，覆盖拖拽弹簧、抛掷阈值、reduce_motion、自由落体、侧边反弹、底部停止和禁用分支；
  - smoke 已纳入 `tools/run_baseline_tests.py`，默认离线回归由 24 项增至 **25 项**，`docs/TESTING.md` 已同步；
  - M3 专项检查通过；
  - 完整离线回归 **25/25** 通过；
  - `SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`；
  - 真实 Windows 鼠标拖拽 / 抛掷手感仍属于桌面人工验收，不由 headless smoke 替代；
- M3 已提交：`fbb95ec refactor: extract drag throw motion`；
- M4 睡眠状态控制边界评估已完成，**本轮暂缓拆分**：
  - 现有 `inactivity_sleep_smoke` 已覆盖 20 分钟长时间无互动、sleep 概率分支、冻结 inactivity、waiting_loop 梦话/提醒/右键不唤醒、文件拖入唤醒、5 次 sleep loop 自动 wake；
  - 但睡眠阶段转换仍直接依赖 ActionCoordinator、动画完成回调、最终帧保留、wake 动画可用性和 inactivity 冻结/解冻；
  - 如果强行迁出，新的睡眠模块必须反向依赖 Main 或大量 callback，主要收益只是减少几十行，维护成本反而上升；
  - **结论：暂缓。** 只有未来睡眠系统需要新增复杂规则时，再围绕具体改动重新设计边界；
- M5 动画 / clip runtime **本轮不进入**：
  - 该区域仍是 Main 中最高时序风险区，与 active clip、hit shape、mouse passthrough、sleep、点击反馈和 ActionCoordinator 高度交织；
  - 当前动画链稳定且已有完整回归，继续只为“缩短 Main”而拆分不划算；
  - **结论：不在本轮继续。**
- 第一轮代码瘦身正式收口：
  - `batch_file_window.gd`：约 1004 行 → **704 行**；
  - `main.gd`：约 2288 行 → **2087 行**；
  - Main 仍然较大，但窗口布局、右键菜单和拖拽/抛掷纯运动计算已经形成独立边界；
  - 安全文件处理 Planner / Executor / native bridge 未改；
  - 睡眠和动画 runtime 保持原稳定结构，避免为了行数制造跨模块时序风险；
  - 后续 AI 应优先按“修改到哪个职责，就围绕该职责小步抽取”的方式继续，而不是启动独立的大重构。

## 10.1 第二轮小瘦身（2026-10-06 续）

目标：继续降低 `main.gd` 的职责密度，但只处理**低风险、无状态或配置加载类职责**。

执行顺序：

1. **S1 天气文案格式化**
   - 抽出 `_build_weather_reply()`；
   - Main 只负责接收 weather manager 事件、保存设置和显示气泡；
   - 不修改任何天气文案、阈值、格式和睡眠梦话逻辑。

2. **S2 Clip 配置 / 素材加载**
   - 只抽出 clip catalog 构建、帧路径校验、start texture / runtime stream 加载；
   - 不碰 `_start_clip_sequence()`、`_run_runtime_video_sequence()`、`_run_direct_clip_sequence()`；
   - 不碰 sequence token、sleep chain、ActionCoordinator、hit shape。

3. **S3 movement catalog 加载**
   - 抽出 movement catalog JSON 读取和 frame path 构建；
   - roaming 行为和状态机继续留在 Main。

4. **S4 再次暂停评估**
   - 不以行数为硬指标；
   - 睡眠、动画播放、鼠标穿透默认继续不拆；
   - 如果继续拆需要大量 callback、Node 引用或状态同步，则停止。

每块仍遵循：**只搬家 → 专项测试 → 完整回归 → Git 单独提交 → 再进入下一块**。

当前进度：

- **S1 天气文案格式化已完成**
  - 新增 `godot/scripts/weather_reply_formatter.gd`；
  - Main 保留 `_build_weather_reply(summary)` 薄包装，现有调用与测试入口不变；
  - 原文案、阈值、分支顺序和格式原样搬入；
  - 专项 `ui_smoke / weather_reminder_smoke / inactivity_sleep_smoke` 通过；
  - 完整离线回归 **25/25** 通过；
  - `SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`；
  - S1 提交：`334a410 refactor: extract weather reply formatter`；
- **S2 Clip 配置 / 素材加载已完成**
  - 新增 `godot/scripts/pet_clip_catalog_loader.gd`；
  - Main 继续持有并清空原 `clips` 字典，继续决定 `video_runtime_enabled`；
  - helper 只负责原有 clip 配置筛选、帧路径生成/校验、timing 默认值、start texture 和 runtime stream 加载，并填回同一个字典；
  - 动画播放、sequence token、sleep chain、ActionCoordinator、hit shape 均未修改；
  - 专项 `green_screen_runtime_smoke / video_runtime_smoke / manual_action_smoke / click_happy_clip_smoke / inactivity_sleep_smoke / dynamic_hit_shape_smoke` 通过；
  - 完整离线回归 **25/25** 通过；
  - `SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`；
  - S2 提交：`35e9c61 refactor: extract clip catalog loader`；
- **S3 movement catalog 加载已完成**
  - 新增 `godot/scripts/pet_movement_catalog_loader.gd`；
  - Main 保留 `movement_catalog` 状态，只把 JSON 读取和 frame path 构建委托给 loader；
  - roaming 行为、PetState 和动作流程未修改；
  - 新增 `godot/tests/movement_catalog_loader_smoke.gd`，覆盖禁用分支、隔离 JSON 读取、帧路径生成和缺失 clip；
  - 默认离线回归由 25 项增至 **26 项**，`docs/TESTING.md` 已同步；
  - 专项 `movement_catalog_loader_smoke / feature_smoke / manual_action_smoke` 通过；
  - 完整离线回归 **26/26** 通过；
  - `SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`；
  - S3 提交：`6fc8dd8 refactor: extract movement catalog loader`；
- **S4 暂停点重新评估已完成**
  - `main.gd` 当时为 **1927 行**，从第一轮收口时的 2087 行再减少 160 行；
  - 相比最初约 2288 行，Main 当时累计减少约 361 行；
  - `batch_file_window.gd` 维持 704 行，不继续为了行数拆 UI；
  - 剩余大块主要是 idle video、mouse passthrough、clip playback runtime、sleep chain，它们都直接持有或协调多个运行时状态；
  - `_reset_window_position()` 规模很小，单独迁出收益不足；
  - **结论：推荐在此收口第二轮瘦身。** 后续只有在实际修改某个高耦合职责时，再围绕那个职责做针对性抽取，不再开展独立“大瘦身”。

## 10.2 Dead-code 审计第一批（2026-10-06）

第一批仅清理高置信度、当前正式工程无引用的遗留代码：

- 删除孤立脚本 `godot/scripts/popup_card_window.gd` 及其 `.uid`；
- 删除 `main.gd::_popup_position_near_pet()`；
- 删除 `main.gd::_movement_clip_frame_paths()`；
- 未触碰 `_convert_queued_images()`、`MENU_CLEAR_FILES`、旧 `convert_png/jpg/webp` 兼容分支和空 `_on_file_queue_changed()`，这些留待第二批单独审计；
- 清理后 `main.gd` 为 **1901 行**；
- 专项 `movement_catalog_loader_smoke / ui_smoke / bubble_layout_smoke / dialogue_ui_smoke` 通过；
- 完整离线回归 **26/26** 通过；
- `SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`。

---

## 11. 给后续 AI 的强制提示

如果你接手本项目：

**不要因为看到“大文件”就直接重写。**

先阅读：

1. 本规划；
2. `docs/PROJECT_HEALTH_CHECK_20261006.md`；
3. `阶段五5B实现与后续AI交接.md`；
4. `docs/TESTING.md`。

然后查看 Git 最近提交，确认当前拆到了哪一块。

如果上一块测试未通过，优先恢复或修正上一块，**不要继续下一块**。

本轮的核心不是“写出更聪明的代码”，而是：

> 在行为完全不变的前提下，让未来修改更便宜、更安全。
