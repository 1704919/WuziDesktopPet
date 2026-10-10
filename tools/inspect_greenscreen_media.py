 1 | from __future__ import annotations
 2 | 
 3 | import json
 4 | from pathlib import Path
 5 | 
 6 | ROOT = Path(__file__).resolve().parents[1]
 7 | MEDIA_ROOT = ROOT / "分享区" / "Q版" / "绿幕视频"
 8 | OUT = ROOT / "work" / "greenscreen_debug"
 9 | OUT.mkdir(parents=True, exist_ok=True)

def detect_kind(path: Path) -> str | None:
    try:
        with path.open("rb") as f:
            head = f.read(64)
    except OSError:
        return None
    if len(head) >= 12 and head[4:8] == b"ftyp":
        return "mp4"
    if head[:4] == bytes.fromhex("1A45DFA3"):
        return "webm"
    if head[:3] == b"FLV":
        return "flv"
    if head[:4] == b"RIFF" and head[8:12] == b"AVI ":
        return "avi"
    return None

candidates = []
for path in MEDIA_ROOT.rglob("*"):
    if not path.is_file():
        continue
    kind = detect_kind(path)
    if kind:
        candidates.append({
            "path": path.relative_to(ROOT).as_posix(),
            "kind": kind,
            "bytes": path.stat().st_size,
        })

result = {"candidates": candidates, "frames": [], "opencv": False}

try:
    import cv2
    result["opencv"] = True
except Exception as exc:
    result["opencv_error"] = repr(exc)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0)

if candidates:
    chosen = max(candidates, key=lambda x: x["bytes"])
    video_path = ROOT / chosen["path"]
    cap = cv2.VideoCapture(str(video_path))
    if cap.isOpened():
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = float(cap.get(cv2.CAP_PROP_FPS))
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        duration = frame_count / fps if fps > 0 else 0.0
        result["chosen"] = chosen
        result["metadata"] = {
            "frame_count": frame_count,
            "fps": fps,
            "width": width,
            "height": height,
            "duration_sec": duration,
        }

        sample_points = [
            ("start", 0.02),
            ("middle", 0.50),
            ("end", 0.96),
        ]
        for name, ratio in sample_points:
            index = max(0, min(frame_count - 1, int(frame_count * ratio)))
            cap.set(cv2.CAP_PROP_POS_FRAMES, index)
            ok, frame = cap.read()
            if not ok:
                continue
            out_path = OUT / f"idle_test_{name}.png"
            cv2.imwrite(str(out_path), frame)
            result["frames"].append({
                "name": name,
                "frame_index": index,
                "path": out_path.relative_to(ROOT).as_posix(),
            })
        cap.release()

print(json.dumps(result, ensure_ascii=False, indent=2))
