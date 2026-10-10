from __future__ import annotations

import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "work" / "video_review" / "alpha_repair_preview"
ARCHIVE = ROOT / "backups" / "stage3_20261004_152500" / "baseline.zip"

TARGETS = [
    "godot/assets_display/wuzi_chibi/video_idle/frames/000.png",
    "godot/assets_display/wuzi_chibi/video_idle/frames/060.png",
    "godot/assets_display/wuzi_chibi/video_idle/frames/120.png",
]


def main() -> None:
    out_dir = OUT / "stage3_idle_reference"
    out_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(ARCHIVE, "r") as zf:
        names = set(zf.namelist())
        for target in TARGETS:
            if target not in names:
                print("missing", target)
                continue
            output = out_dir / Path(target).name
            output.write_bytes(zf.read(target))
            print("extracted", target, "->", output.relative_to(ROOT))


if __name__ == "__main__":
    main()
