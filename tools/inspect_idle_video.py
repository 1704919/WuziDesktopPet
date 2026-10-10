 1 | from __future__ import annotations
 2 | 
 3 | import json
 4 | from pathlib import Path
 5 | 
 6 | from PIL import Image
 7 | import imageio_ffmpeg
 8 | 
 9 | ROOT = Path(__file__).resolve().parents[1]
VIDEO = ROOT / "分享区" / "Q版" / "绿幕视频" / "角色自然待机动画生成.mp4"
OUT = ROOT / "work" / "greenscreen_debug"
OUT.mkdir(parents=True, exist_ok=True)

reader = imageio_ffmpeg.read_frames(str(VIDEO), pix_fmt="rgb24")
meta = next(reader)
size = meta.get("size", (0, 0))
fps = float(meta.get("fps", 0.0) or 0.0)
duration = float(meta.get("duration", 0.0) or 0.0)

frames = []
for frame in reader:
    frames.append(frame)

w, h = size
result = {
    "video": VIDEO.relative_to(ROOT).as_posix(),
    "bytes": VIDEO.stat().st_size,
    "width": w,
    "height": h,
    "fps": fps,
    "duration_sec": duration,
    "frame_count": len(frames),
    "samples": [],
}

if frames and w > 0 and h > 0:
    picks = [
        ("start", 0),
        ("quarter", max(0, round((len(frames) - 1) * 0.25))),
        ("middle", max(0, round((len(frames) - 1) * 0.50))),
        ("three_quarter", max(0, round((len(frames) - 1) * 0.75))),
        ("end", len(frames) - 1),
    ]
    for name, index in picks:
        im = Image.frombytes("RGB", (w, h), frames[index])
        out_path = OUT / f"idle_video_{name}.png"
        im.save(out_path, "PNG")
        result["samples"].append({
            "name": name,
            "frame_index": index,
            "time_sec": index / fps if fps > 0 else None,
            "path": out_path.relative_to(ROOT).as_posix(),
        })

print(json.dumps(result, ensure_ascii=False, indent=2))
