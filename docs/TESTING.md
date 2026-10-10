  1 | # 隔离运行基线测试
  2 | 
  3 | 测试脚本会写入 user:// 设置、图片和输出，因此不要把日常运行项目直接作为 smoke 测试工作目录。
  4 | 
  5 | ## 运行入口
  6 | 
  7 | 从项目根目录使用 Python 3.10 或更高版本执行：
  8 | 
  9 | ```powershell
 10 | py -3 tools/run_baseline_tests.py
 11 | ```
 12 | 
 13 | 当前默认运行 21 个离线脚本、昵称独立进程写入/重读两项，以及隔离验证、项目导入和主场景启动，共 26 项。阶段五包含规划器和执行器专项，代码瘦身阶段新增拖拽/抛掷纯运动计算与 movement catalog loader smoke。添加两项真实天气联网检查后共 28 项：
 14 | 
 15 | ```powershell
 16 | py -3 tools/run_baseline_tests.py --network
 17 | ```
 18 | 
 19 | 默认 Godot 路径为 `D:\Godot\Godot_v4.7-stable_win64.exe`，可覆盖：
 20 | 
 21 | ```powershell
 22 | py -3 tools/run_baseline_tests.py --godot 'D:\Godot\Godot_v4.7-stable_win64.exe' --network
 23 | ```
 24 | 
 25 | 本次验收实际使用工作区自带的 Python：
 26 | 
 27 | `%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`
 28 | 
 29 | 运行器只依赖标准库，无需安装测试框架。它不会调用正式重启脚本。
 30 | 
 31 | ## 输出和隔离边界
 32 | 
 33 | - 原 Godot 项目复制到系统临时目录 `wuzi_baseline_*`，排除 .godot 和 test_output。
 34 | - 副本设置独立的 `WuziPetBaseline/<运行编号>` 用户目录，并由 Godot 探针检查实际 user:// 路径。探针失败就停止后续功能测试。
 35 | - 源项目已有 override.cfg 时会拒绝运行，要求先审阅并合并隔离覆盖配置。
 36 | - 每次结果保存在 `docs/baselines/<运行编号>/`，包括 stdout/stderr 日志、Godot 日志和 report.json。
 37 | - report.json 记录执行入口哈希、结果、耗时、警告、正式文件和日常设置的前后校验。
 38 | - 工作副本和独立用户目录保留供诊断；具体位置以 report.json 为准。清理时仅清理该次运行的两个确切目录，不清理整个临时目录或整个 AppData。
 39 | - 任何失败或正式文件/设置变化，运行器以非零状态退出。成功标记、退出码和错误日志共同决定检查结果。
 40 | 
 41 | ## 素材检查
 42 | 
 43 | 修改或新增正式动作素材后，先运行日常素材校验：
 44 | 
 45 | ```powershell
 46 | py -3 tools/verify_q_video_assets.py
 47 | ```
 48 | 
 49 | 素材校验器需要 NumPy 和 Pillow；本次工作区自带 Python 已具备这两个库。该检查只读素材，不启动桌宠。
 50 | 
 51 | 当前校验器核对正式源视频清单，并覆盖全部正式动作处理序列。普通动作新增了跨动作首尾衔接一致性审计：以 idle 为基准，同时记录 manifest 的有效目标高度，以及 000 / 120 首尾帧的实际透明包围盒高度、水平中心、底边位置和 identity core。偏差达到 3% 或位置阈值时进入 `transition_consistency.reviews`，方便人工复核。
 52 | 
 53 | 需要强制卡住普通动作首尾跳变时运行：
 54 | 
 55 | ```powershell
 56 | $env:Q_VIDEO_STRICT_TRANSITIONS = "1"
 57 | py -3 tools/verify_q_video_assets.py
 58 | Remove-Item Env:Q_VIDEO_STRICT_TRANSITIONS
 59 | ```
 60 | 
 61 | 严格模式下，普通动作首尾帧尺度超过约 ±4%、水平中心偏差超过 8 px、底边偏差超过 6 px 时以非零状态退出。manifest 理论目标高度只保留为 review 参考，不再单独作为硬失败条件，避免被道具和姿势包围盒误导。2026-10-06 已完成现有普通动作的尺寸统一校准，当前严格模式通过；暂不并入默认 26 项回归，新增或重建动画后应单独运行严格模式作为素材验收门禁。
 62 | 
 63 | `进入睡眠 / 睡眠循环 / 睡眠惊醒`（`sleep_down / sleep_loop / wake_up`）明确排除在普通动作首尾规则之外。它们继续使用睡眠链专用检查：横躺 hit shape、`sleep_down` 尾帧 → `sleep_loop` 首帧 → `wake_up` 首帧的宽度/中心连续性，以及惊醒过程的动态 scale curve 与 hit-shape 连续性。后续需要单独讨论和验收，不能为了通过普通动作标准强行拉成 idle 尺寸。
 64 | 
 65 | ### 实际接入动画的首尾帧专项检测（2026-10-09）
 66 | 
 67 | 使用 `py -3 tools/audit_action_endpoints.py`。这是一份独立的**只读检测**，不重建视频、不校正位置和尺度，也不改动已批准的 PNG / OGV / visual baseline。
 68 | 
 69 | - **唯一待机标准**来自 `godot/config/pet_behavior.json` 的 `idle_video.frames_dir` 及 `start_frame / end_frame`，当前指向实际接入的 `video_idle/frames/000.png` 和 `120.png`；不使用原始视频、母版、备份或理论高度替代。
 70 | - 遍历该配置 `clips` 中全部动作。普通动作比较「待机尾帧 → 动作首帧」「动作尾帧 → 待机首帧」，并检查动作自身首尾的一致性。进食坐姿单列规则，不将比待机矮的姿态直接认定为人物比例错误。
 71 | - 人物测量采用透明轮廓及上部主体轮廓宽度**近似指标**。不对道具做复杂识别；道具、姿势、衣袖可能干扰指标，因此疑似问题标记为人工复核，不直接自动修复。
 72 | - 睡眠专查五个边界：待机尾→入睡首，入睡尾→睡眠循环首，睡眠循环尾→首，睡眠循环尾→惊醒首，惊醒尾→待机首。使用站姿与躺姿两套阈值；**不检查惊醒中途缩放**。
 73 | - 报告输出 `work/video_review/endpoint_audit/report.json`，并生成 `ordinary_endpoints.jpg` 与 `sleep_endpoints.jpg` 对照图。对照图始终保留相同画布比例，不逐张裁剪/缩放人物。
 74 | - 普通运行退出码为 0 仅表示检测完成；需看 `pass / review / anomaly` 分类。可使用 `--strict` 在存在 `anomaly` 时返回非零状态，`review` 仍需人工判断。
 75 | 
 76 | 由于运行时可能使用同批素材编码的有损 OGV，PNG 检测反映实际接入的源帧几何位置，不保证 OGV 每个像素与 PNG 完全一致。
 77 | 
 78 | ### 首尾尺寸修复、中断恢复与复验（2026-10-09）
 79 | 
 80 | - 仅重建 `eat_breakfast`、`eat_bullfrog`、`eat_fried_chicken`、`unbox_cards`、`sleep_loop`、`wake_up` 六个动作；其余动作和现役 `idle` 基准不变。三段构建任务在网络中断后自行完成，`work/video_review/endpoint_audit/repair_progress.json` 显示全部返回码 0，检查确认后**没有重复重建**。
 81 | - 三个吃饭动作采用各自固定倍率，与现役 idle 的 PNG 起止帧对齐；拆卡整体平移。睡眠循环整体下移 3 px 对齐入睡尾帧，新版惊醒对躺姿起点和站姿终点做小幅平滑校准；保留惊醒已有的原始补偿曲线，不重新设计镜头缩放。
 82 | - 修复前七个动作（包括未修改的 `sleep_down`）的素材和相关配置备份保存在 `backups/endpoint_alignment_pre_20261009/`。仅更新六个重建动作各三张抽样帧的 18 个批准视觉哈希；其他动作的基准哈希保持不变。
 83 | - `py -3 tools/audit_action_endpoints.py --strict`：34/34 个普通动作通过，无 review 或 anomaly；睡眠链 3 处通过，另 2 处仅需人工复核：入睡首帧相较待机高度 -4.5%，惊醒首帧相较睡眠循环尾帧高度 -5.51%。它们可能来自不同姿态，不据此继续强制拉伸。
 84 | - `Q_VIDEO_STRICT_TRANSITIONS=1` 下素材完整校验：`failures=[]`，原有站立动作严格失败项为空；旧 manifest 理论值保留的三条 review 不是首尾帧失败。
 85 | - 隔离 Godot 回归（`manual_action_smoke`、`video_runtime_smoke`、`inactivity_sleep_smoke`）以及导入、启动均 PASS；`SOURCE_UNCHANGED: True`，`SETTINGS_UNCHANGED: True`。报告：`docs/baselines/20261009_200144_14044819/report.json`。实际桌面观感仍需人工确认。
 86 | 
 87 | ### 历史记录：新版惊醒肤色专项修复（2026-10-09，后续已撤销）
 88 | 
 89 | - **原因**：先前整体 RGB 及「浅色（pale）」调色把脸部肤色与白袖、浅色服装混合分析。新版 wake_up 面部肤色在站姿末帧明显比现役 idle 偏暗，原有粉色补偿并未专门校正皮肤。
 90 | - **仅修 wake_up**：`tools/wake_skin_tone.py` 为可见暖肤色像素提供柔和颜色权重；`tools/build_q_video_assets.py` 在正常颜色校正后，针对 wake_up 逐帧调用，起点对齐实际 `sleep_loop/120`，终点对齐实际 `idle/000`。没有修改全局调色、其他动作、alpha、动作尺寸或原来的惊醒补偿曲线。
 91 | - **修复前备份**：`backups/wake_up_skin_pre_20261009/` 保留原 wake_up 的 121 张 PNG、OGV、manifest 及相关基准配置。
 92 | - **面部区域 RGB 抽样（有姿态和肤色掩膜限制，代表性样本而非整个角色的平均值）**：躺姿端 `sleep_loop/120=(232.8,192.5,188.9)`，`wake_up/000=(232.5,192.2,188.6)`；站姿端 `idle/000=(239.9,210.8,196.3)`，`wake_up/120=(238.3,209.4,195.1)`。
 93 | - **改动安全性**：全部 121 帧的 RGBA alpha 与修复前逐帧完全一致；未触及识别出的蓝色头发像素；只更新 `wake_up` 的 `000/060/120` 三帧批准视觉 SHA-256。前后图片见 已清理的历史临时视觉预览（不作为当前版本肤色基准），检测见 `validate_repair.py`。
 94 | - **同步小修**：天气 UI 文案改为「启动后检查天气，之后每 10 小时检查一次」以匹配 `feature_config.json`；`action_catalog.json` 删除旧 `eat_fries` `ready=false` 重复定义；`dialogue.json` 修复两句过时的文件处理引导文案。
 95 | - **后续状态**：随机 idle 仍关闭且动作池为空。抽签算法已改为统一使用调整后权重，专项测试通过；动作间隔、权重策略和对话新场景仍待用户讨论后确定。
 96 | - **人工验收限制**：本次颜色可量化校准和静态前后对照不等同于用户实际桌面观看 OGV 全程色调的验收。
 97 | - **回归恢复记录**：首次完整回归的 `ui_smoke` 暴露旧测试仍预期「吃饭分类只有 1 项」，而当前已接入 8 项、每页 6 项；这是过期测试断言，不是天气 UI 错误。已增强测试为首页 6 项、次页 2 项及分页导航和动作内容检查，隔离专项 PASS（`docs/baselines/20261009_211318_20090c9d/report.json`）。
 98 | - **最终完整离线回归**：`docs/baselines/20261009_211539_594b1151/report.json`，28/28 PASS，`SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`。严格素材校验和 runtime OGV 解码 PASS，34/34 普通动作端点 PASS；睡眠链仅有此前已有的 2 项姿态轮廓人工复核提示。
 99 | - **JSON 配置卫生**：扫描正式 `godot/config/` 的 45 份 JSON，已无重复键。

### 用户确认后的纠偏：原视频颜色与固定缩放（2026-10-09）

- **用户决定优先于先前技术建议**：新版睡眠惊醒源视频本身没有镜头变焦问题；旧版逆向 sleep_down 缩放曲线及另行叠加的末段 5.5% 放大不再适用。针对 wake_up 已删除曲线生成与使用，生产 manifest 不再有 `scale_curve`，全程用 `start_scale=end_scale` 的固定比例，仍保留绿幕去背景、统一 480×360 画布和动态 hit shape。不要为了追求零误差再擅自增加逐帧缩放。
- **原视频颜色**：wake_up 不再参与与 idle 的 RGB affine、pink/pale 语义调色或先前人为肤色补偿。仅保留抠像必要的 RGB 去绿边和采样缩放、OGV 有损编码，不承诺与 MP4 每像素完全相同。`color_normalization.reference_action=none_source_video_preserved`，`correction.enabled=false`，`semantic_deltas={}`，并用素材验证器约束这些字段。已删除不再使用的 `tools/wake_skin_tone.py`。
- **既有图像差异如实记录**：新动画端点与睡眠循环/待机轮廓有少量尺寸与位置差异，属于人工验收项；不再通过未经确认的放大曲线强行让数字归零。原先“肤色匹配到 idle 的 RGB 数值”不再作为目标。
- **修复前备份**：`backups/wake_up_raw_color_fixed_scale_pre_20261009/` 保留了本轮重建前全部 121 帧、OGV 和有关配置。原素材视频仍在 `分享区/Q版/绿幕视频/睡眠惊醒.mp4`。
- **随机日常动作抽签**：`godot/scripts/pet_idle_action_picker.gd` 改为基于实际调整后权重分桶，若存在其他有效候选则避免立即重复；只有一个有效候选时允许重复；零或负权重不参与抽签。主控制器先应用长时间无互动加权再调用选择器；新增 `godot/tests/idle_action_weight_smoke.gd` 并加入隔离回归。随机日常动作配置仍为 `enabled=false`、空动作池，权重设计及对话库扩充等待讨论。
- **保护原则**：只重建 wake_up，不改其它视频颜色，不改变日常随机动作开关与现有睡眠状态机；生成的 PNG/OGV/manifest/hit shapes 与视觉基准在校验后共同收口。
- **最终验证**：严格素材总检（`Q_VIDEO_STRICT_TRANSITIONS=1`）`failures=[]`，runtime OGV 解码通过，34/34 普通动作首尾检查通过。睡眠链入睡首帧、惊醒首尾仍是轻微轮廓人工复核项，不因此加回缩放曲线。新增权重专项单测 PASS，完整 Godot 隔离回归 **29/29 PASS**，`SOURCE_UNCHANGED=True`，`SETTINGS_UNCHANGED=True`；报告 `docs/baselines/20261009_215228_a39f2757/report.json`。用户仍需真实桌面检查自然观感。

### 活泼型自主动作正式启用（2026-10-09；覆盖以上“尚未启用”历史记录）

- `godot/config/pet_behavior.json` 的 `idle_actions.enabled=true`，`interval_sec=[10,20]`。使用用户亲自确定的 A～E 五个**随机类别**、26 个动作、合计有效权重 **88**；27 项原始权重中 A4「打瞌睡」不放入普通随机池，只保留独立无互动睡眠系统触发。其余动作（包括随机惊吓、踢到猫及所有八种饮食动作）不更改用户权重；不引入早晚时间条件。
- 空闲时每 10～20 秒尝试播放；计时在**上一段动作返回待机**以及用户交互后重新抽取区间，打开聊天/设置等交互窗口期间暂不递减。用户点播、对话、拖拽和睡眠流程仍由现有优先级控制，普通随机不能打断它们。漫游也属于自主行为，会与随机动作争用待机时段，因此**10～20 秒是空闲尝试间隔，不保证每隔这么久都实际播放**。
- `PetIdleActionPicker.choose` 继续按用户权重抽选、避免立刻重复相同动作；新增独立 A～E 类别限制：连续两次同类后，下一次抽签剔除该类别；若没有任何其他有效候选，跳过本轮而非违反限制。**只有被协调器接受、实际开始的动作才更新类别连续次数**。
- 某些动作使用别名（例如 `read_book` → `read_book_video`）：调度器现在通过 `ActionRegistry` 解析并核验真正的运行 clip，避免它们被 `clips.has` 误排除。
- 右键「暂停随机动作」已更名为「暂停自主行为」；保留原持久化设置键 `random_actions_paused`，暂停后普通随机动作、自动睡眠尝试、桌面自主漫游和随机主动闲聊均停止，当前漫游可立即中止，**当前睡眠链不会被强行截断**。独立的「桌面漫游」个人开关保持原状态；恢复自主行为时重新计时，不补播积压任务。
- 喝水提醒、饭点提醒、天气提醒、用户手动点播和对话不属于自主暂停范围。仅对 ReminderManager 的随机闲聊分支添加独立暂停门禁；**不关闭 ReminderManager.enabled，也不停止 WeatherManager**。目前随机闲聊配置本就为关闭状态，对话语料未修改。
- 新增隔离 `godot/tests/autonomous_behavior_smoke.gd`，涵盖完整 26 项 ID/权重/类别、动作别名解析、暂停与恢复、漫游、睡眠、喝水提醒、闲聊、用户交互保护、类别强制换类、成功播放后计时重置；`idle_action_weight_smoke.gd` 增加类别抽签边界测试。正式回归工具 `tools/run_baseline_tests.py` 已注册新测试。
- **隔离完整回归 29/29 PASS**；导入与启动也 PASS，`SOURCE_UNCHANGED=True`、`SETTINGS_UNCHANGED=True`。报告：`docs/baselines/20261009_232557_e03a3a5f/report.json`。本次不改任何现成 PNG/OGV、肤色、睡眠缩放或对话内容。真实桌面观感与随机/漫游频率竞争仍需要人工验收。

### 对话、动作联动与角色反馈收口（2026-10-10）

- 用户确认现有对话系统主体保留，不新建大型对话引擎，也不引入线上 AI。仅补齐 `eat`、`slack`、`bored` 三个话题的现役动作候选（吃饭、躺手机/看书、游戏/看书），保留夸奖、摸头、睡眠、唱歌等已存在动作联动。聊天仍不能执行文件处理操作，仍限制输入 50 字。
- `mood_query` 文案在显示时读取 `MoodManager.get_snapshot().mood`，通过 `dialogue.json.mood_state_responses` 选择五种真实状态的回复（普通/开心/害羞/生气/困倦），而不是无视当前心情随机回答。
- `dialogue.json.event_feedback` 存储用户亲自给出的原文：转换/重命名成功 3 条、失败 3 条、预览 1 条、重名 1 条、拖动开始 1 条/放下 2 条、连续第 6 次起点击 5 条。此组是**事件反馈**，不作为聊天关键词，也不触发额外文件操作。
- 文件工作台用实际规划结果判断重名（多个源产生同一路径，或目标路径已有文件）；在确认预览前显示预览/重名文案。只有真正完成且无失败、跳过、取消时说「全部处理好啦」等成功语句；出现失败或跳过使用失败文案；用户主动取消不冒充成功或失败。工作台使用自己的「舞梓：」反馈栏，桌宠气泡也会展示，不抢独立文件窗口焦点。
- 真实拖拽超过阈值才播放「要带我去哪里」，移动完成/抛掷落地才播放放下的反馈。第 6 次及后续密集点击使用用户指定台词，连续吐槽间隔至少 1.5 秒；原点击 Q 弹及情绪动作不变。单句预览反馈重复出现时保持用户提供的原文，而不会意外落入普通聊天兜底。
- 新增 `godot/tests/pet_feedback_smoke.gd` 并扩展 `dialogue_smoke.gd`；覆盖真实情绪与回答、已有聊天触发动作、全部事件文案通路、部分文件失败/跳过/取消不会报成功、重复预览原文、连续戳与 Q 弹。台词录入不修改已有睡眠、动画资源或随机动作权重。
  
### Windows v0.1.0 发行包构建及独立启动（2026-10-10）

- Godot 4.7 官方 Windows x86_64 导出模板采用 `tools/fetch_win_export_templates.py` **HTTP Range 按需获取**，无需下载完整约 1.2 GiB 的多平台模板包；安装位置位于本机 Godot 用户模板目录，不随发布 ZIP 分发。
- `godot/export_presets.cfg` 提供 Windows Desktop 导出预设，`tools/package_windows_release.py` 校验全部 **38 个动作各 121 张 PNG 回退帧及对应 OGV**，导出正式 EXE/PCK；`native/wuzi_file_bridge.exe` 作为外置组件随包分发。原始绿幕 MP4、角色母版、参考素材、开发备份及缓存均不在 Windows ZIP。
- 本地包：`dist/WuziDesktopPet-v0.1.0-win64.zip`，351.67 MiB，SHA-256：`408b8cf048c5ca249259890f8aba47e44c0759490f2a761df459e3acaef78de1`。包含运行文件、用户说明、项目 MIT、Godot 上游 MIT 和角色衍生素材声明；打包后 ZIP CRC 完整性检查通过。
- `tools/smoke_portable_release.py` **直接解压最终 ZIP 到全新临时目录**，先后启动导出的 Windows EXE 无界面模式和常规 GUI 模式；两个场景均退出码 0，未发现关键资源缺失或 GDScript 加载错误；`PRODUCTION_SETTINGS_UNCHANGED=True`。额外验证 `native/wuzi_file_bridge.exe caps` 返回 0，能读取 Windows HEIC 能力。
- 导出后的 EXE 不应继续通过开发专用的 `--script res://tests/...` 机制执行编辑器脚本测试：曾有一次因此导致超时，改用正式启动路径后两种模式均通过。完整逻辑测试仍以正式工程中的隔离 `tools/run_baseline_tests.py` 为准。
- **限制**：目前仅在本机 Windows 环境完成独立目录冷启动，不代表已在另一台干净 Windows 电脑上验收；DPI、多屏、长期资源占用、SmartScreen 未签名提示及 GitHub 实际下载体验尚未完整测试。GitHub 远程仓库/Release 尚不存在，不得写成“已公开发布”。

新增素材时必须同步更新正式清单、构建配置、动态 hit-shape 与 visual baseline。

普通动作边界当前使用 **45 ms 从 alpha 1.0 下潜到 0.55 → 原子切换 → 60 ms 回到 1.0**，不是完全消失，也不是双角色 cross-fade。`manual_action_smoke` 覆盖 PNG fallback 的进入/返回 idle 和普通动作 A→B 抢占，并断言最低 alpha 不会低于 0.45；`video_runtime_smoke` 覆盖 OGV runtime 浅层下潜/恢复并确认睡眠链排除；`click_happy_clip_smoke` 确认点击 Q 弹不参与普通过渡。

`tools/build_q_video_assets.py` 现在在重建 PNG 后自动执行一次 Godot headless import，并检查生成帧的 `.png.import`。不要移除这一步，也不要恢复“删除整个 frames 目录后只写回 PNG”的旧逻辑。正式启动器 `tools/restart_godot_pet.ps1` 另有第二层兜底：启动前检查帧 sidecar 与 `.godot/imported` 缓存，异常时自动重新导入。

## 解读结果

Headless 测试检查逻辑和布局数据，两个 preview 脚本在 headless 下不会生成可审阅画面。真实 Windows 鼠标穿透、拖拽抛掷、输入焦点、显示缩放及长期内存仍需专门验证。

本次接手前基线中的 ObjectDB 退出警告已在 `baselines/STAGE1_20261004.md` 列出。新增错误应与该基线对照，不能仅凭 exit 0 忽略日志。

## 阶段五专项

```powershell
py -3 tools/run_baseline_tests.py --only stage5_file_planner_smoke stage5_file_executor_smoke
```

此入口仍复制项目并隔离 user://，执行隔离验证、导入、启动和选中的专项；不会重启正式桌宠。执行器测试在专用样本目录验证真实文件操作，其中不可写目录用临时 ACL 设置，测试结束恢复；需要 Windows 原生组件已构建。HEIC 真编码测试按本机 WIC 能力运行，缺失能力路径另有独立覆盖。

完整 5B 记录见 [STAGE5B_20261006.md](baselines/STAGE5B_20261006.md)。

真实桌面可在报告指向的隔离副本运行 `--script res://tests/stage5_desktop_preview.gd`，该脚本仅创建专用文本/图片样本并打开工作台。它不是自动交互验收，原生选择器、焦点和不同 DPI 仍需实际检查。
