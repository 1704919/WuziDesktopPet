from __future__ import annotations

import json
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
QROOT = ROOT / "分享区" / "Q版"
OUT = ROOT / "work" / "video_review"
OUT.mkdir(parents=True, exist_ok=True)

videos = []
for path in sorted(QROOT.rglob("*.mp4")):
    # Only review the current Q-version production area, not archived material.
    rel = path.relative_to(ROOT).as_posix()
    reader = imageio_ffmpeg.read_frames(str(path), pix_fmt="rgb24")
    meta = next(reader)
    w, h = meta.get("size", (0, 0))
    fps = float(meta.get("fps", 0.0) or 0.0)
    frames = list(reader)
    duration = len(frames) / fps if fps else float(meta.get("duration", 0.0) or 0.0)

    picks = [0.02, 0.25, 0.50, 0.75, 0.97]
    thumbs = []
    samples = []
    for ratio in picks:
        if not frames or not w or not h:
            continue
        idx = max(0, min(len(frames) - 1, round((len(frames) - 1) * ratio)))
        arr = np.frombuffer(frames[idx], dtype=np.uint8).reshape((h, w, 3)).copy()
        edge = np.concatenate([
            arr[:, :max(4, w//60)].reshape(-1, 3),
            arr[:, -max(4, w//60):].reshape(-1, 3),
            arr[:max(4, h//60), :].reshape(-1, 3),
        ], axis=0)
        bg = np.median(edge, axis=0)
        dist = np.linalg.norm(arr.astype(np.float32) - bg.astype(np.float32), axis=2)
        mask = dist > 35.0
        ys, xs = np.where(mask)
        bbox = None
        if len(xs):
            bbox = [int(xs.min()), int(ys.min()), int(xs.max()+1), int(ys.max()+1)]
        samples.append({"ratio": ratio, "frame": idx, "bg_rgb": [int(x) for x in bg], "bbox": bbox})

        im = Image.fromarray(arr, "RGB")
        target_h = 300
        target_w = max(1, round(w * target_h / h))
        im = im.resize((target_w, target_h), Image.Resampling.LANCZOS)
        thumbs.append((ratio, idx, im))

    if thumbs:
        tile_w = max(im.width for _,_,im in thumbs)
        sheet = Image.new("RGB", (tile_w * len(thumbs), 340), "white")
        draw = ImageDraw.Draw(sheet)
        for i, (ratio, idx, im) in enumerate(thumbs):
            x = i * tile_w + (tile_w - im.width)//2
            sheet.paste(im, (x, 0))
            draw.text((i * tile_w + 6, 306), f"{ratio:.0%}  f{idx}", fill="black")
        safe = path.stem.replace(" ", "_").replace("-", "_")
        if path.parent.name == "绿幕视频":
            safe = "old_" + safe
        else:
            safe = "new_" + safe
        sheet_path = OUT / f"{safe}_contact.jpg"
        sheet.save(sheet_path, "JPEG", quality=86, optimize=True)
        sheet_rel = sheet_path.relative_to(ROOT).as_posix()
    else:
        sheet_rel = None

    videos.append({
        "path": rel,
        "bytes": path.stat().st_size,
        "width": w,
        "height": h,
        "fps": fps,
        "frame_count": len(frames),
        "duration_sec": duration,
        "samples": samples,
        "contact_sheet": sheet_rel,
    })

report = {"videos": videos}
(OUT / "video_review.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
