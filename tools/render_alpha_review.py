from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "work" / "video_review" / "alpha_review"
OUT.mkdir(parents=True, exist_ok=True)

ACTIONS = {
    "idle": ROOT / "godot/assets_display/wuzi_chibi/video_idle/frames",
    "click_happy": ROOT / "godot/assets_display/wuzi_chibi/video_click_happy/frames",
    "click_shy": ROOT / "godot/assets_display/wuzi_chibi/video_click_shy/frames",
    "march_in_place": ROOT / "godot/assets_display/wuzi_chibi/video_march_in_place/frames",
    "sleepy": ROOT / "godot/assets_display/wuzi_chibi/video_sleepy/frames",
    "yawn": ROOT / "godot/assets_display/wuzi_chibi/video_yawn/frames",
    "click_angry": ROOT / "godot/assets_display/wuzi_chibi/video_click_angry/frames",
    "sleep_down": ROOT / "godot/assets_display/wuzi_chibi/video_sleep_down/frames",
    "drag_reaction": ROOT / "godot/assets_display/wuzi_chibi/video_drag_reaction/frames",
    "startle": ROOT / "godot/assets_display/wuzi_chibi/video_startle/frames",
    "yawn_small": ROOT / "godot/assets_display/wuzi_chibi/video_yawn_small/frames",
    "game_rage": ROOT / "godot/assets_display/wuzi_chibi/video_game_rage/frames",
    "click_wave": ROOT / "godot/assets_display/wuzi_chibi/video_click_wave/frames",
    "wake_up": ROOT / "godot/assets_display/wuzi_chibi/video_wake_up/frames",
    "sleep_loop": ROOT / "godot/assets_display/wuzi_chibi/video_sleep_loop/frames",
    "sing": ROOT / "godot/assets_display/wuzi_chibi/video_sing/frames",
}
PICKS = [0, 30, 60, 90, 120]


def checker(size: tuple[int, int], cell: int = 18) -> Image.Image:
    w, h = size
    arr = np.zeros((h, w, 3), dtype=np.uint8)
    a = np.array([255, 40, 180], dtype=np.uint8)
    b = np.array([30, 220, 255], dtype=np.uint8)
    yy, xx = np.indices((h, w))
    mask = ((xx // cell) + (yy // cell)) % 2 == 0
    arr[mask] = a
    arr[~mask] = b
    return Image.fromarray(arr, "RGB").convert("RGBA")


for action, directory in ACTIONS.items():
    tile_w = 360
    tile_h = 360
    label_h = 26
    sheet = Image.new("RGB", (tile_w * len(PICKS), (tile_h + label_h) * 2), "white")
    draw = ImageDraw.Draw(sheet)
    for col, idx in enumerate(PICKS):
        path = directory / f"{idx:03d}.png"
        rgba = Image.open(path).convert("RGBA")
        bg = checker(rgba.size)
        bg.alpha_composite(rgba)
        y0 = 0
        sheet.paste(bg.convert("RGB"), (col * tile_w, y0))
        draw.text((col * tile_w + 8, tile_h + 6), f"frame {idx} checker", fill="black")

        alpha = rgba.getchannel("A")
        alpha_rgb = Image.merge("RGB", (alpha, alpha, alpha))
        y1 = tile_h + label_h
        sheet.paste(alpha_rgb, (col * tile_w, y1))
        draw.text((col * tile_w + 8, y1 + tile_h + 6), f"frame {idx} alpha", fill="black")

    out = OUT / f"{action}_checker_alpha.jpg"
    sheet.save(out, "JPEG", quality=92, optimize=True)
    print(out.relative_to(ROOT).as_posix())
