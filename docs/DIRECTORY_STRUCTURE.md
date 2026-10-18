# 当前目录说明

## 正式运行

```text
godot/
├─ assets_display/wuzi_chibi/  （本地开发目录，公开仓库不包含）
│  └─ video_*/                 动作 OGV 视频及开发用 PNG 帧
├─ config/
│  ├─ pet_behavior.json
│  ├─ dialogue.json          阶段二本地规则和回复池
│  ├─ action_catalog.json
│  └─ *_video_manifest.json
├─ scenes/
├─ scripts/
└─ tests/

分享区/Q版/                       （本地开发目录，公开仓库不包含）
├─ master.png                  角色身份参考
├─ 角色标准包/                 AI 视频生成时的身份与结构参考
└─ 绿幕视频/                   当前正式 MP4 与动作提示词
```

Windows v0.1.1-rc3 轻量运行包包含 **38 组透明 OGV 动画**（`runtime_alpha.ogv`）和静态首帧，使用 OGV 播放，不包含原始 MP4 或完整 PNG 帧序列。公开源码仓库不包含动画二进制资源。

## 处理工具

- `tools/build_q_video_assets.py`：统一处理当前绿幕视频。
- `tools/verify_q_video_assets.py`：核对帧数、画布、透明边距与源视频集合。
- `tools/review_q_videos.py`：生成源视频抽帧审阅信息。

## 参考资料

`assets/references/` 属于本地开发环境，未包含在公开仓库中；用于角色与动作参考，不参与正式运行。

## 归档

`archive/cleanup_20261003/` 属于本地开发环境，未包含在公开仓库中；用于旧内容归档，正式运行不使用。
