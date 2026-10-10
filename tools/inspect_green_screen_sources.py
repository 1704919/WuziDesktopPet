 1 | from __future__ import annotations
 2 | 
 3 | from pathlib import Path
 4 | 
 5 | import imageio_ffmpeg
 6 | import numpy as np
 7 | from PIL import Image, ImageDraw
 8 | 
 9 | ROOT = Path(__file__).resolve().parents[1]
VIDEO_ROOT = ROOT / "分享区" / "Q版" / "绿幕视频"
NEW_VIDEO_ROOT = ROOT / "分享区" / "Q版" / "新视频"
OUT_ROOT = ROOT / "work" / "video_review" / "source"

SOURCES = {
    "idle": VIDEO_ROOT / "角色自然待机动画生成.mp4",
    "yawn": NEW_VIDEO_ROOT / "打哈欠.mp4",
    "sleep_down": NEW_VIDEO_ROOT / "进入睡眠.mp4",
    "startle": NEW_VIDEO_ROOT / "被吓到.mp4",
    "yawn_small": NEW_VIDEO_ROOT / "打哈欠小幅度.mp4",
    "game_rage": NEW_VIDEO_ROOT / "打游戏暴怒.mp4",
    "click_wave": NEW_VIDEO_ROOT / "点击-打招呼.mp4",
    "wake_up": NEW_VIDEO_ROOT / "睡眠惊醒.mp4",
    "sleep_loop": NEW_VIDEO_ROOT / "睡眠循环.mp4",
    "sing": NEW_VIDEO_ROOT / "悠闲唱歌.mp4",
}


def resolve(path: Path) -> Path:
    if path.is_file():
        return path
    fallback = VIDEO_ROOT / path.name
    if fallback.is_file():
        return fallback
    raise FileNotFoundError(path)


def read_video(path: Path):
    reader = imageio_ffmpeg.read_frames(str(path), pix_fmt="rgb24")
    meta = next(reader)
    frames = list(reader)
    return meta, frames


OUT_ROOT.mkdir(parents=True, exist_ok=True)

for action_id, raw_path in SOURCES.items():
    path = resolve(raw_path)
    meta, raw_frames = read_video(path)
    w, h = meta["size"]
    count = len(raw_frames)
    picks = [0, round((count - 1) * 0.25), round((count - 1) * 0.5), round((count - 1) * 0.75), count - 1]
    tile_w = 320
    tile_h = round(h * tile_w / w)
    sheet = Image.new("RGB", (tile_w * len(picks), tile_h + 28), (238, 238, 238))
    draw = ImageDraw.Draw(sheet)
    for i, idx in enumerate(picks):
        arr = np.frombuffer(raw_frames[idx], dtype=np.uint8).reshape((h, w, 3))
        frame = Image.fromarray(arr, "RGB").resize((tile_w, tile_h), Image.Resampling.LANCZOS)
        sheet.paste(frame, (i * tile_w, 0))
        draw.text((i * tile_w + 8, tile_h + 7), f"source frame {idx}", fill="black")
    out = OUT_ROOT / f"{action_id}_source_contact.jpg"
    sheet.save(out, "JPEG", quality=92, optimize=True)
    print(f"{action_id}: {path.relative_to(ROOT).as_posix()} -> {out.relative_to(ROOT).as_posix()}")
