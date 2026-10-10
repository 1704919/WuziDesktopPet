  1 | # 阶段三完成与后续 AI 交接
  2 | 
  3 | > 当前状态已推进到阶段四完成。后续接手请优先阅读 [阶段四完成与后续 AI 交接](阶段四完成与后续AI交接.md)。本文保留阶段三结束时的历史状态。
  4 | 
  5 | 更新时间：2026-10-04（Asia/Shanghai）。
  6 | 
  7 | ## 1. 接手结论
  8 | 
  9 | 阶段一、二、三已经完成。下一阶段是**阶段四：情绪与动作联动**。
 10 | 
 11 | 当前正式运行层仍是 Godot 4.7，入口和既有桌宠交互没有改成其他运行方案。角色动画继续使用绿幕视频处理后的透明 PNG 序列。
 12 | 
 13 | 接手时优先阅读：
 14 | 
 15 | 1. 本文件。
 16 | 2. `docs/godot-prompter/plans/2026-10-04-interaction-and-file-tools.md`。
 17 | 3. `docs/godot-prompter/specs/2026-10-04-module-boundaries.md`。
 18 | 4. 阶段三验收：`docs/baselines/STAGE3_20261004.md`。
 19 | 5. 如需追溯阶段二，再阅读 `阶段二完成与后续AI交接.md`。
 20 | 
 21 | 不要从旧 Python 运行层或静态关键帧路线继续开发。那些内容只作历史归档。
 22 | 
 23 | ---
 24 | 
 25 | ## 2. 阶段三实际完成内容
 26 | 
 27 | ### 2.1 独立数字彩蛋模块
 28 | 
 29 | 新增：
 30 | 
 31 | - `godot/scripts/easter_egg_manager.gd`
 32 | - `godot/tests/easter_egg_smoke.gd`
 33 | 
 34 | 接入：
 35 | 
 36 | - `godot/scripts/dialogue_manager.gd`
 37 | - `godot/scripts/main.gd`
 38 | - `tools/run_baseline_tests.py`
 39 | 
 40 | 旧的精确字符串 `29` 特判已经移除，`feature_config.json` 里的旧 `commands` 配置也已经删除，避免形成两套入口。
 41 | 
 42 | 当前调用顺序是：
 43 | 
 44 | `InputGuard → EasterEggManager → 普通对话规则/话题上下文 → 回复池`
 45 | 
 46 | 彩蛋命中后返回：
 47 | 
 48 | - `intent = "easter_egg"`
 49 | - `text = "{original}？我还以为{mapped}呢"`
 50 | - `easter_egg.original`
 51 | - `easter_egg.mapped`
 52 | - `easter_egg.kind`
 53 | - `easter_egg.start`
 54 | 
 55 | 命中彩蛋时会清空旧话题上下文，避免下一句错误承接之前的话题。
 56 | 
 57 | **阶段四字段仍保持惰性**：
 58 | 
 59 | - `action_request = ""`
 60 | - `mood_event = ""`
 61 | 
 62 | 阶段三没有偷偷提前实现情绪或动作调度。
 63 | 
 64 | ### 2.2 彩蛋规则
 65 | 
 66 | 阿拉伯数字按字符串处理，不转固定宽度整数：
 67 | 
 68 | - `29 ↔ 92`
 69 | - `290 ↔ 920`
 70 | - `2900 ↔ 9200`
 71 | - 继续按尾零扩展。
 72 | 
 73 | 要求：
 74 | 
 75 | - 必须是完整连续数字片段。
 76 | - `129`、`292`、`029` 不应从中截取有效彩蛋。
 77 | - 连续阿拉伯数字最多 40 位。
 78 | - 同一句从左到右只处理第一个有效彩蛋。
 79 | 
 80 | 中文支持：
 81 | 
 82 | - 十、百、千、万、亿、兆。
 83 | - 标准表达和需求中明确的口语省略。
 84 | 
 85 | 已测试：
 86 | 
 87 | - `二十九 ↔ 九十二`
 88 | - `二百九 ↔ 九百二`
 89 | - `二千九 ↔ 九千二`
 90 | - `二万九 ↔ 九万二`
 91 | - `二十九万 ↔ 九十二万`
 92 | - `二百九十 ↔ 九百二十`
 93 | 
 94 | 中文数字片段最多 20 字符。解析失败必须回到普通对话，不能抛异常，也不能误截取。
 95 | 
 96 | ---
 97 | 
 98 | ## 3. 本轮新视频素材
 99 | 
用户提供的四个新视频原本位于：

`分享区/Q版/新视频/`

现已全部处理完成并**移动**到：

`分享区/Q版/绿幕视频/`

当前 `新视频/` 目录为空。

新素材：

| 视频 | 处理 ID | Manifest | 运行帧目录 |
|---|---|---|---|
| `打哈欠.mp4` | `yawn` | `godot/config/yawn_video_manifest.json` | `godot/assets_display/wuzi_chibi/video_yawn/frames` |
| `点击-傲娇生气.mp4` | `click_angry` | `godot/config/click_angry_video_manifest.json` | `godot/assets_display/wuzi_chibi/video_click_angry/frames` |
| `进入睡眠.mp4` | `sleep_down` | `godot/config/sleep_down_video_manifest.json` | `godot/assets_display/wuzi_chibi/video_sleep_down/frames` |
| `鼠标拖拽.mp4` | `drag_reaction` | `godot/config/drag_reaction_video_manifest.json` | `godot/assets_display/wuzi_chibi/video_drag_reaction/frames` |

四套新素材均为：

- 121 帧。
- 12 fps。
- 360 × 360 透明 PNG。
- 约 10.08 秒运行时长。
- 经过绿幕抠像、边缘水印清理、动作自身参考姿态归一、脚底/中心定位和颜色统一。

`tools/build_q_video_assets.py` 已扩展为同时识别“新视频”临时入口和“绿幕视频”正式归档位置，因此未来新素材仍可先放到“新视频”再处理。2026-10-04 启动故障修复后，构建器不再删除整个 `frames` 目录，而是只清理多余的旧 PNG，保留现有 `.png.import`；所有视频帧重建完成后还会自动调用 Godot 的 headless import，强制刷新 `.import` 与 `.godot/imported` 缓存。素材构建只有在 Godot 导入成功后才算完成。

`tools/verify_q_video_assets.py` 当前正式清单为 9 个源视频、9 套序列。最终校验 `ok=true`。

> 注意：色彩分组是按像素阈值重新分类的，边界像素会造成少量均值漂移，因此当前统一色差校验上限为 6 RGB 级。打哈欠素材的浅色分组最接近该阈值，但仍通过。不要再次叠加残差调色；测试中验证过，重复语义分组校正会因为像素重新分类而反向过校正。

---

## 4. 动作目录状态

`godot/config/action_catalog.json` 已更新。

新增或更新为已处理素材：

- `yawn` → `yawn_video`
- `yawn_video`
- `click_angry_video`
- `drag_reaction_video`
- `sleep_down` → `sleep_down_video`
- `sleep_down_video`

这些条目表示**素材本身已经可用**。

但是阶段四尚未实施，因此：

- 没有把它们接入自动情绪调度。
- 没有改变现有点击连击规则。
- 没有把傲娇生气接到第 6 次点击。
- 没有把鼠标拖拽视频接到拖拽状态机。
- 没有把打哈欠接到 sleepy/random 行为。
- 没有扩充当前右键“点播动作”的列表。
- `pet_behavior.json` 仍保持阶段二的运行触发集合，避免在阶段三提前增加常驻加载和阶段四行为。

阶段四接手时再决定这些素材的触发、优先级、冷却和懒加载策略。

---

## 5. 睡眠动画：最高优先级交接说明

这一点不要按普通单段动作处理。

用户明确要求：

- “进入睡眠动画”
- “睡眠循环动画”
- “睡眠惊醒动画”

三者在程序中是连续关系。

正确状态链应为：

`normal/idle → sleep_down → sleep_loop → wake_up → idle`

其中：

### 已完成

`sleep_down`

对应源视频：

`分享区/Q版/绿幕视频/进入睡眠.mp4`

已生成运行帧和 manifest，`action_catalog.json` 中可用。

### 尚未完成

`sleep_loop`

- 用户尚未制作/提供源视频。
- 当前必须保持 `ready=false`、`status=waiting_video`。
- 不得创建假素材，不得拿普通待机或打瞌睡冒充正式睡眠循环。

`wake_up`

- 对应用户所说“睡眠惊醒动画/醒来动画”。
- 用户尚未制作/提供源视频。
- 当前必须保持 `ready=false`、`status=waiting_video`。

### 阶段四接入时必须遵守

现有播放器的一般 one-shot 动作通常结束后回 idle，这对睡眠入口是错误的。

`sleep_down` 播完以后：

**不能回 idle。**

必须：

1. `sleep_down` 播放一次。
2. 保持最后睡姿并无缝进入 `sleep_loop`。
3. `sleep_loop` 持续循环。
4. 收到唤醒/惊醒事件后，在同一睡姿基础上切换到 `wake_up`。
5. `wake_up` 完成后才回 `idle`。

未来实现 ActionCoordinator 时，睡眠链要作为**连续状态链**特殊处理，不能简单调用默认 `return_to_idle_after=true` 的通用单动作路径。

在 `sleep_loop` 与 `wake_up` 两个正式素材到齐之前，**不要启用完整自动睡眠流程**。否则用户会看到进入睡眠后突然跳回待机，或者无法正确醒来。

收到后两段视频时，还要检查：

- `sleep_down` 最后一帧与 `sleep_loop` 第一帧姿态是否连续。
- `sleep_loop` 首尾是否适合循环。
- `sleep_loop` 当前睡姿与 `wake_up` 第一帧是否连续。
- 三段角色尺寸、中心、颜色与透明边缘是否一致。
- 惊醒结束后回 idle 是否自然。

---

## 6. 阶段四建议接入边界

下一阶段按原计划实现，不要一次跳到阶段五。

阶段四核心仍是：

- `MoodManager`：normal / happy / shy / angry / sleepy。
- 点击计数和视频冷却分离。
- 1～2 次普通、3～5 次害羞、6 次及以上生气。
- `ActionCoordinator`：统一动作请求、优先级、重复请求、过期、缺失素材回退。
- 保留现有 Q 弹、拖拽、抛掷手感。
- 低优先级动作不能中断高优先级动作。
- 继续使用现有 clip 播放器和懒加载思路。

本轮新素材可在阶段四作为：

- `click_angry_video`：高点击连击生气。
- `drag_reaction_video`：拖拽期间或拖拽起始反馈。
- `yawn_video`：sleepy/空闲低优先级动作。
- `sleep_down_video`：完整睡眠链入口；后两段缺失前不启用自动链。

不要把“素材 ready”和“功能已接线”混为一谈。

---

## 7. 测试状态

最终完整隔离回归：

`20261004_154828_a268adc3`

结果：

- isolation：PASS
- import：PASS
- startup：PASS
- easter_egg_smoke：PASS
- dialogue_smoke：PASS
- dialogue_ui_smoke：PASS
- feature_smoke：PASS
- green_screen_runtime_smoke：PASS
- manual_action_smoke：PASS
- click_happy_clip_smoke：PASS
- bubble_layout_smoke：PASS
- bubble_passthrough_smoke：PASS
- ui_smoke：PASS
- weather_reminder_smoke：PASS
- render_ui_previews：PASS
- render_bubble_previews：PASS
- nickname_restart_write：PASS
- nickname_restart_read：PASS

总计：**18/18 通过**。

测试运行器同时确认：

- `SOURCE_UNCHANGED: True`
- `SETTINGS_UNCHANGED: True`

报告：

`docs/baselines/20261004_154828_a268adc3/report.json`

素材校验：

`tools/verify_q_video_assets.py`

结果：

- `ok=true`
- 正式源视频 9 个。
- 9 套运行序列无失败项。

本轮没有重新执行真实联网天气测试。也没有用 headless 结果冒充真实 Windows 桌面鼠标穿透、IME、焦点、拖拽手感或长期内存验收。

### 7.1 2026-10-04 启动故障事件与修复

阶段三完成后出现过一次“桌宠双击后没有界面、像完全无法启动”的故障。实际情况是 Godot 进程成功启动后立即退出。

**根因：** `tools/build_q_video_assets.py` 原先会对每套动画执行 `shutil.rmtree(out_dir)`，也就是把整个 `frames` 目录删掉后重建。这样虽然重新生成了 `000.png`～`120.png`，但 Godot 放在同目录的 `*.png.import` 也被一起删除。正式启动器只执行普通 `--path` 启动，不会像隔离测试那样先执行 `--editor --import`，因此 `ResourceLoader` 看得到 PNG 文件，却没有可用的 Godot 导入记录和导入缓存。日志最终表现为 `No loader found for resource`、`Failed to load idle-video frame`、`Failed to load master texture`，随后 `main.gd` 按设计退出。

这也解释了为什么当时隔离回归 18/18 通过、正式项目却打不开：`tools/run_baseline_tests.py` 会在临时副本中先运行 `--editor --import`，临时副本自动补齐了导入文件，而正式项目没有经过这一步。

**本次修复分两层：**

1. 素材构建根治：`tools/build_q_video_assets.py` 不再删除整个 `frames` 目录；现有对应 `.png.import` 会保留，多余旧帧才会按文件单独删除。全部 PNG、manifest 与预览生成完成后，构建器自动执行 Godot `--headless --editor --import`，并检查九套序列都重新具有 `.png.import`。如果 Godot 不存在、导入失败或仍缺 sidecar，构建器直接报错，不再把“PNG 已生成”误判为“运行素材已完成”。可通过环境变量 `GODOT_EXE` 覆盖默认 Godot 路径。
2. 启动器兜底：`tools/restart_godot_pet.ps1` 在正式启动前扫描 `assets_display/wuzi_chibi/**/frames/*.png`。它不仅检查旁边的 `.png.import` 是否存在，还读取其中的 `res://.godot/imported/...ctex` 路径并确认实际缓存存在。发现缺失或损坏时，先自动执行一次 headless import；导入后再次检查，确认全部恢复才继续启动。健康状态下不会重复导入，直接启动桌宠。

**现场恢复与验证结果：**

- 第一次使用修复后的启动器时，自动检测到 **1089 个**运行帧缺失或损坏 Godot 导入状态，并成功自动修复，然后正常启动桌宠。
- 随后完整重新执行 `tools/build_q_video_assets.py`，九套视频全部重新构建成功；构建报告中的 `godot_import.returncode=0`、`checked_sequences=9`。
- `tools/verify_q_video_assets.py` 再次通过：`ok=true`，九套序列均 121/121 非空帧，无失败项。
- 再次运行正式启动器时没有触发修复流程，说明健康状态检查可以直接放行；Godot 正式进程保持运行。
- 正式 `user://` 最新 `godot.log` 仅记录 Godot 4.7 与 RTX 4060/OpenGL 初始化，没有 `ERROR:`、`Failed to load` 或资源加载失败。
- 修复后完整隔离回归编号：`20261004_162717_1698fa0b`，**18/18 PASS**，并继续满足 `SOURCE_UNCHANGED: True`、`SETTINGS_UNCHANGED: True`。

**以后必须遵守：** 任何脚本只要修改 Godot 运行时 PNG，任务结束前都必须保证正式项目完成资源导入；不能只看 PNG 是否存在，也不能只依赖隔离测试副本的 import 结果。若未来调整素材构建器或启动器，必须保留这两层保护。

---

## 8. 阶段三回退点

修改前已经建立完整快照：

`backups/stage3_20261004_152500/`

包含：

- `baseline.zip`
- `manifest.json`
- `README.md`

快照信息：

- 文件数：1495。
- ZIP SHA-256：`ae776995a21aa227133c9bdd311e3cb648a3aac222268457f3df880b97c3fe08`。

该快照创建在：

- 阶段三代码修改之前。
- 四个新视频从“新视频”移动到“绿幕视频”之前。

因此如果阶段四开发出现严重问题，可恢复到阶段三开工前状态。恢复时按备份 README 选择性恢复，不要盲目覆盖整个项目。

---

## 9. 关键修改文件

阶段三核心代码：

- `godot/scripts/easter_egg_manager.gd`
- `godot/scripts/dialogue_manager.gd`
- `godot/scripts/main.gd`
- `godot/tests/easter_egg_smoke.gd`
- `godot/tests/dialogue_smoke.gd`

配置：

- `godot/config/feature_config.json`
- `godot/config/action_catalog.json`
- 四个新视频 manifest。

素材工具：

- `tools/build_q_video_assets.py`
- `tools/verify_q_video_assets.py`
- `tools/run_baseline_tests.py`

文档：

- `docs/baselines/STAGE3_20261004.md`
- `docs/TESTING.md`
- `docs/godot-prompter/plans/2026-10-04-interaction-and-file-tools.md`
- `docs/godot-prompter/specs/2026-10-04-module-boundaries.md`
- `分享区/Q版/绿幕视频/README.md`
- `README_桌宠.md`
- `CLAUDE.md`
- `.ai-bridge/current-plan.md`
- `.ai-bridge/agent-status.md`
- `.ai-bridge/decisions.md`
- `.ai-bridge/open-questions.md`

---

## 10. 接手时不要误判的事项

1. **阶段三已经完成，不要重新做 29 精确特判。** 现在是完整双向解析器。
2. **四个新视频已经处理，但阶段四动作调度还没做。**
3. **“进入睡眠”不等于完整睡眠。** 睡眠循环和睡眠惊醒仍缺素材。
4. **睡眠入口不能自动回 idle。**
5. **不要把 waiting_video 改成 ready 以绕过缺素材。**
6. **聊天仍不能直接调用文件处理。**
7. **阶段五批量文件处理还没有开始。**
8. **测试必须继续走隔离运行器，避免污染日常 `user://`。**
9. **项目仍未初始化 Git。**
10. **以后新增视频要同步更新构建器、正式视频清单、动作目录和素材校验器；重建运行 PNG 后必须保留/刷新 Godot import 状态，不能再次整目录删除 `frames` 后直接结束。**

阶段四开始前，如用户又补充了“睡眠循环”或“睡眠惊醒”视频，先走现有绿幕处理和素材校验，再进行睡眠状态链接线。
