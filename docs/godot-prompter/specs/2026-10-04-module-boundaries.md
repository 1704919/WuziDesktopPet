 1 | # 对话情绪与文件工具模块边界
 2 | 
 3 | 日期：2026-10-04。阶段二已实现 InputGuard、DialogueManager、ResponseManager、昵称设置及卡片；阶段三已实现 EasterEggManager。情绪、统一动作调度与批量文件工具仍为后续设计。现有播放、拖拽、天气与提醒保留原实现。
 4 | 
 5 | ## 计划场景结构
 6 | 
 7 | ```text
 8 | Main (Node2D，现有)
 9 | ├─ PetVisual / Bubble / ContextBubble（现有）
├─ CommandBubble / WeatherBubble（现有）
├─ SettingsStore / ReminderManager / WeatherManager（现有）
├─ FileDropManager / ActionRegistry（现有）
├─ dialogue_manager（Main 持有的 RefCounted，阶段二已实现，非场景 Node）
├─ MoodManager（新增 Node，低频 Timer 驱动恢复）
├─ ActionCoordinator（新增 Node，统一请求入口）
├─ NicknameCard（阶段二已实现，首次打开创建并复用的 Control）
└─ BatchFileWindow（按需创建独立 Window）
   └─ VBoxContainer
      ├─ 文件列表与添加操作
      ├─ 处理方式与动态参数
      ├─ 输出位置
      ├─ 预览及冲突提示
      └─ 确认、取消与进度
```

不为每个规则建立常驻节点；输入检查、数字解析、回复选择和目标路径规划优先采用轻量 GDScript 对象。普通调用和局部信号足够，无需新增全局事件总线。

## 数据所有权与职责

| 所有者 | 唯一负责的数据或行为 | 接入现有代码的位置 |
|---|---|---|
| DialogueManager | 最多三轮话题、意图和回复选择；不执行文件操作 | main.gd::_handle_command_text |
| InputGuard | 长度、空白及输入规范化，返回有效输入或拒绝原因 | 对话与昵称输入边界 |
| EasterEggManager | 第一个有效彩蛋及 original/mapped，失败返回未匹配 | 普通意图识别前 |
| ResponseManager | 回复池、防重复及昵称模板选择 | DialogueManager 内部 |
| MoodManager | mood_score、五态、临时状态、连击时间窗 | 对话事件和有效角色点击 |
| SettingsStore | 持久化 nickname，继续持有既有设置 | 复用现有 get/set/erase |
| ActionCoordinator | 当前请求优先级及短期请求，检查可用动作 | 手动、对话、点击及随机动作的入口 |
| 现有 clip 播放器 | 纹理加载、预取、序列取消、回待机 | 保留 _start_clip_sequence / sequence_token |
| FileDropManager | 单一文件队列、分类、现有图片编码；扩展执行接口 | _on_files_dropped / convert_queued_images |
| 批量规划与检查工具 | 源路径到目标路径的只读计划与冲突信息 | UI 预览阶段，不能改文件 |
| BatchFileWindow | 本次参数、预览版本、确认和进度展示 | 拖文件与右键入口 |

暂不为了拆分而搬迁 main.gd 的所有既有功能；新增模块通过窄接口接入。动作目录继续使用 action_catalog.json，设置继续使用 wuzi_pet_settings.json，不建立第二份相同数据。

## 信号与调用约定

| 事件或调用 | 来源 → 消费者 | 内容 |
|---|---|---|
| submit_message | Main → DialogueManager | 原始短文本 |
| reply_ready | DialogueManager → Main | text、intent、topic、action_request |
| apply_event | DialogueManager/点击入口 → MoodManager | 事件类型、单调时间、分数变化 |
| mood_changed | MoodManager → 对话及动作选择 | 当前状态与分数 |
| request_action | Main → ActionCoordinator | action_id、来源、优先级 |
| play_requested | ActionCoordinator → 现有播放器 | 已通过可用性及优先级检查的动作 |
| queue_changed（现有） | FileDropManager → BatchFileWindow | 单一队列变化 |
| request_preview | BatchFileWindow → 规划工具 | 队列快照、参数、输出模式 |
| execution_requested | BatchFileWindow → 文件执行层 | 用户确认过的计划及版本 |
| progress/completed | 文件执行层 → BatchFileWindow | 逐项结果、成功/失败/取消 |

具体字段和信号名称在对应阶段实现时定稿；职责和执行边界保持不变。

## 数据流

对话：输入 → 双层输入检查 → 特殊彩蛋 → 意图及有限上下文 → 当前情绪与事件变化 → 回复池及昵称 → 气泡与动作请求。无效输入不修改上下文；模块失败使用默认回复、normal 或 idle。

点击：有效单击 → 更新连击时间窗及情绪 → 请求动作；Q 弹仍立即响应。视频冷却只控制视频，不吞掉连击计数。拖拽不计为连续骚扰点击。

文件：拖入/右键 → 唯一队列 → 参数 → 只读预览 → 冲突检查 → 用户确认 → 再次检查 → 执行 → 逐项结果。确认后参数变更使旧计划失效；后台任务不直接操作 UI 节点。

## 失败与优先级约束

- 配置需要类型与字段验证；GDScript 的运行时错误不能依靠通用 try/catch 捕获，回退必须通过显式检查和结果值实现。
- 低优先级动作不得中断高优先级动作；重复请求合并，过期请求不积压成很长的动作队列。
- 新动作需要 ready 与资源检查双重通过；当前五套视频仍按需使用。
- 文件预览和执行使用同一目标路径计划，禁止预览一套、执行时重新按另一套规则命名。
- 文件错误按单项记录，保留失败源；不以“有一个成功”清空整个分类。
- 真实桌面鼠标穿透、焦点及抛掷边界在有界面环境验收，不能仅凭 headless 测试宣布通过。

## 阶段二已定稿接口

- `InputGuard.check(raw, limit, allow_empty)` 返回 `ok/text/error`，不抛出输入异常。
- `DialogueManager.submit_message(raw, nickname, now_ms=-1)` 同步返回结果字典，不另设 reply_ready 信号；`action_request` 与 `mood_event` 均为空。此前信号表是未来设计，不代表已经接线。
- 输入检查后先由 `EasterEggManager` 扫描第一个完整有效数字片段；未命中才进入配置精确匹配 → 最新话题承接 → 有序关键词。旧精确 29 分支已移除。
- 最近三轮只保留 topic/at_ms，120 秒过期；未知话题清空，明确话题立即切换。没有持久化聊天。
- `SettingsStore.get_nickname/set_nickname` 校验并复用原 JSON；`save_settings` 返回 bool，现有忽略返回值的调用兼容。
- `NicknameCard.nickname_submitted(text)` 向 Main 提交，Main 保存成功才隐藏卡片。卡片使用既有 popup 动画，并接入 overlay/Esc/互斥显示。
- 阶段二使用 RefCounted 组合，无新增常驻 Node 管理器、Autoload 或每帧计时。

## 阶段三已定稿接口

- `EasterEggManager.match_first(raw)` 返回 `matched/original/mapped/kind/start`；解析失败返回 `matched=false`，不抛异常。
- 阿拉伯数字只接受完整连续片段 `29 × 10^n` 或 `92 × 10^n`，连续数字上限 40 位；中文数字片段上限 20 字符，支持十、百、千、万、亿、兆和“二百九”“二万九”等口语省略。
- 同一句从左到右只取第一个有效彩蛋；更长的非目标数字必须整体判定失败，不能从中截取 29/92。
- `DialogueManager.submit_message` 命中后返回 `intent=easter_egg`，并附加 `easter_egg` 元数据；`action_request` 与 `mood_event` 仍为空，阶段三不提前实现阶段四。
- 新增素材“打哈欠、点击-傲娇生气、进入睡眠、鼠标拖拽”已完成绿幕处理并登记到动作目录，但未接入阶段四运行调度。睡眠入口不能独立自动回待机，未来必须与 `sleep_loop`、`wake_up` 连续编排。
