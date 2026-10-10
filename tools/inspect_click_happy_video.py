 1 | from __future__ import annotations
 2 | import json
 3 | from pathlib import Path
 4 | 
 5 | from PIL import Image
 6 | import imageio_ffmpeg
 7 | 
 8 | ROOT = Path(__file__).resolve().parents[1]
 9 | VIDEO = ROOT / "分享区" / "Q版" / "绿幕视频" / "点击-开心.mp4"
OUT = ROOT / "work" / "greenscreen_debug"
OUT.mkdir(parents=True, exist_ok=True)

reader = imageio_ffmpeg.read_frames(str(VIDEO), pix_fmt="rgb24")
meta = next(reader)
w, h = meta.get("size", (0, 0))
fps = float(meta.get("fps", 0.0) or 0.0)
duration = float(meta.get("duration", 0.0) or 0.0)

frames = list(reader)
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
        ("start", 0.02),
        ("quarter", 0.25),
        ("middle", 0.50),
        ("three_quarter", 0.75),
        ("end", 0.97),
    ]
    for name, ratio in picks:
        index = max(0, min(len(frames) - 1, round((len(frames) - 1) * ratio)))
        im = Image.frombytes("RGB", (w, h), frames[index])
        out = OUT / f"click_happy_{name}.png"
        im.save(out, "PNG")
        result["samples"].append({
            "name": name,
            "frame_index": index,
            "time_sec": index / fps if fps else None,
            "path": out.relative_to(ROOT).as_posix(),
        })

print(json.dumps(result, ensure_ascii=False, indent=2))
