 1 | from pathlib import Path
 2 | from PIL import Image
 3 | import json
 4 | 
 5 | ROOT = Path(__file__).resolve().parents[1]
 6 | MEDIA_ROOT = ROOT / "分享区" / "Q版" / "绿幕视频"
 7 | items = []
 8 | 
 9 | for path in MEDIA_ROOT.rglob("*"):
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
