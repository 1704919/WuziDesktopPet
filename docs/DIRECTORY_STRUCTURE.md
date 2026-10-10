 1 | # 当前目录说明
 2 | 
 3 | ## 正式运行
 4 | 
 5 | ```text
 6 | godot/
 7 | ├─ assets_display/wuzi_chibi/
 8 | │  ├─ video_idle/              待机视频处理帧
 9 | │  ├─ video_click_happy/       点击开心处理帧
│  ├─ video_click_shy/         点击害羞处理帧
│  ├─ video_march_in_place/    原地踏步处理帧
│  └─ video_sleepy/            打瞌睡处理帧
├─ config/
│  ├─ pet_behavior.json
│  ├─ dialogue.json          阶段二本地规则和回复池
│  ├─ action_catalog.json
│  └─ *_video_manifest.json
├─ scenes/
├─ scripts/
└─ tests/

分享区/Q版/
├─ master.png                  角色身份参考
├─ 角色标准包/                 AI 视频生成时的身份与结构参考
└─ 绿幕视频/                   当前正式 MP4 与动作提示词
```

正式动画资源由 `godot/assets_display/wuzi_chibi/video_*/runtime_alpha.ogv` 优先播放，必要时回退到同目录的 `frames/` 透明 PNG 序列。两者都来自视频构建器；旧静态关键帧不参与运行。公开源码仓库默认不包含这些动画产物（见 `docs/ASSET_POLICY.md`）。

## 处理工具

- `tools/build_q_video_assets.py`：统一处理当前绿幕视频。
- `tools/verify_q_video_assets.py`：核对帧数、画布、透明边距与源视频集合。
- `tools/review_q_videos.py`：生成源视频抽帧审阅信息。

## 参考资料

`assets/references/` 保留为角色与动作参考，不参与正式运行。

## 归档

`archive/cleanup_20261003/` 保存退出正式路径的旧内容。**当前运行代码不得引用归档目录。**
