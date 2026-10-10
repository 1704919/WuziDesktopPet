from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image, ImageDraw
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
VIDEO = ROOT / "分享区" / "Q版" / "绿幕视频" / "角色自然待机动画生成.mp4"
OUT = ROOT / "work" / "greenscreen_debug"
OUT.mkdir(parents=True, exist_ok=True)
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

bg_hex = "7FA568"

for similarity in (0.08, 0.12, 0.16):
    key = f"{similarity:.2f}".replace(".", "_")
    rgba_path = OUT / f"idle_key_{key}.png"
    preview_path = OUT / f"idle_key_{key}_checker.png"

    vf = (
        f"drawbox=x=550:y=910:w=170:h=50:color=0x{bg_hex}:t=fill,"
        f"colorkey=0x{bg_hex}:{similarity}:0.06,"
        "format=rgba"
    )
    subprocess.run(
        [
            FFMPEG, "-y",
            "-ss", "2.0",
            "-i", str(VIDEO),
            "-vf", vf,
            "-frames:v", "1",
            str(rgba_path),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    fg = Image.open(rgba_path).convert("RGBA")
    checker = Image.new("RGBA", fg.size, (235, 235, 235, 255))
    draw = ImageDraw.Draw(checker)
    tile = 32
    for y in range(0, fg.height, tile):
        for x in range(0, fg.width, tile):
            if ((x // tile) + (y // tile)) % 2:
                draw.rectangle(
                    [x, y, x + tile - 1, y + tile - 1],
                    fill=(205, 205, 205, 255),
                )
    checker.alpha_composite(fg)
    checker.convert("RGB").save(preview_path, "PNG")

    alpha = fg.getchannel("A")
    extrema = alpha.getextrema()
    bbox = alpha.getbbox()
    print(similarity, rgba_path.relative_to(ROOT), "alpha", extrema, "bbox", bbox)
