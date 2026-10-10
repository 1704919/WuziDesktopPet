 1 | # 舞梓桌宠项目说明
 2 | 
 3 | 正式运行项目位于 godot/，采用 Godot 4.7，使用绿幕素材生成的透明 OGV 作为优先运行时动画，保留 PNG 回退。
 4 | 
 5 | 首先阅读根目录 `阶段五5B实现与后续AI交接.md`，再按需查看 `阶段四完成与后续AI交接.md` 的稳定约束与阶段五需求。阶段一至四及 5A/5B 已完成，验收状态以最新交接与实际代码为准；以后以用户最新指令为准。新版 wake_up 已接入并由用户确认使用原视频肤色、固定倍率，无需重新加回旧缩放曲线；其余未就绪动画不阻塞首次发布准备。当前处于阶段六和源码开源准备阶段。
 6 | 
 7 | ## GodotPrompter
 8 | 
 9 | 实现 Godot 系统前，阅读匹配的 GodotPrompter 技能。技能可通过当前环境的技能目录访问，不要求额外安装插件。

本项目后续常用技能：dialogue-system、gdscript-patterns、godot-ui、save-load、state-machine、input-handling、animation-system、multithreading、godot-testing、godot-code-review。

阶段五当前实施方案见 `docs/godot-prompter/plans/2026-10-06-stage5b-safe-execution.md`；2026-10-04 的原分阶段计划仅作历史参考。

保留现有 SceneTree smoke 测试结构，不因使用测试技能而安装 GUT 或 gdUnit4。优先运行 `tools/run_baseline_tests.py`，避免测试写入日常 user:// 设置。聊天只产生文本，不能调用真实文件执行；数字彩蛋已在阶段三完成，完整情绪与动作联动已在阶段四完成。
