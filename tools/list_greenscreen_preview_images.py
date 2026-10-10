from pathlib import Path
from PIL import Image
import json

ROOT = Path(__file__).resolve().parents[1]
MEDIA_ROOT = ROOT / "分享区" / "Q版" / "绿幕视频"
items = []

for path in MEDIA_ROOT.rglob("*"):
    if not path.is_file():
        continue
    try:
        with Image.open(path) as im:
            w, h = im.size
            if w >= 500 and h >= 300:
                items.append({
                    "path": path.relative_to(ROOT).as_posix(),
                    "width": w,
                    "height": h,
                    "bytes": path.stat().st_size,
                })
    except Exception:
        pass

items.sort(key=lambda x: x["bytes"], reverse=True)
print(json.dumps(items[:30], ensure_ascii=False, indent=2))
