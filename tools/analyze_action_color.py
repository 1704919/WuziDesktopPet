from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SETS = {
    "idle": ROOT / "godot/assets_display/wuzi_chibi/video_idle/frames",
    "click_happy": ROOT / "godot/assets_display/wuzi_chibi/video_click_happy/frames",
    "click_shy": ROOT / "godot/assets_display/wuzi_chibi/video_click_shy/frames",
    "march_in_place": ROOT / "godot/assets_display/wuzi_chibi/video_march_in_place/frames",
    "sleepy": ROOT / "godot/assets_display/wuzi_chibi/video_sleepy/frames",
}

def stats_for_pixels(px: np.ndarray) -> dict | None:
    if len(px) < 50:
        return None
    q = np.quantile(px, [0.2, 0.5, 0.8], axis=0)
    mean = px.mean(axis=0)
    std = px.std(axis=0)
    lum = 0.2126 * px[:,0] + 0.7152 * px[:,1] + 0.0722 * px[:,2]
    return {
        "count": int(len(px)),
        "mean_rgb": [round(float(x),2) for x in mean],
        "std_rgb": [round(float(x),2) for x in std],
        "q20_rgb": [round(float(x),2) for x in q[0]],
        "median_rgb": [round(float(x),2) for x in q[1]],
        "q80_rgb": [round(float(x),2) for x in q[2]],
        "mean_luma": round(float(lum.mean()),2),
        "median_luma": round(float(np.median(lum)),2),
    }

report = {}
for name, folder in SETS.items():
    samples = []
    for i, path in enumerate(sorted(folder.glob("*.png"))[:18]):
        rgba = np.array(Image.open(path).convert("RGBA"), dtype=np.uint8)
        rgb = rgba[...,:3].astype(np.float32)
        a = rgba[...,3]
        mask = a >= 220
        if not mask.any():
            continue
        px = rgb[mask]
        # Ignore near-black outlines for colour grading stats.
        useful = px[np.max(px, axis=1) >= 45]
        blue = useful[(useful[:,2] > useful[:,0] * 1.10) & (useful[:,2] > useful[:,1] * 1.05) & (useful[:,2] > 80)]
        pink = useful[(useful[:,0] > useful[:,1] * 1.18) & (useful[:,0] > useful[:,2] * 1.03) & (useful[:,0] > 90)]
        pale = useful[(useful[:,0] > 150) & (useful[:,1] > 120) & (useful[:,2] > 120)]
        samples.append((useful, blue, pink, pale))
    merged = {}
    for idx, label in enumerate(["all", "blue", "pink", "pale"]):
        groups = [s[idx] for s in samples if len(s[idx])]
        merged[label] = stats_for_pixels(np.concatenate(groups, axis=0)) if groups else None
    report[name] = merged

print(json.dumps(report, ensure_ascii=False, indent=2))
