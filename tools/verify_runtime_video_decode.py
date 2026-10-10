  1 | from __future__ import annotations
  2 | 
  3 | import json
  4 | from pathlib import Path
  5 | 
  6 | import imageio_ffmpeg
  7 | import numpy as np
  8 | from PIL import Image
  9 | 
 10 | ROOT = Path(__file__).resolve().parents[1]
 11 | ASSET_ROOT = ROOT / "godot/assets_display/wuzi_chibi"
 12 | OUTPUT_ROOT = ROOT / "work/video_review/runtime_decode"
 13 | ACTIONS = [
 14 |     "idle",
 15 |     "click_happy",
 16 |     "click_shy",
 17 |     "march_in_place",
 18 |     "sleepy",
 19 |     "yawn",
 20 |     "click_angry",
 21 |     "sleep_down",
 22 |     "drag_reaction",
 23 |     "startle",
 24 |     "yawn_small",
 25 |     "game_rage",
 26 |     "click_wave",
 27 |     "wake_up",
 28 |     "sleep_loop",
 29 |     "sing",
 30 | ]
 31 | SAMPLE_FRAMES = {0, 60, 120}
 32 | WIDTH = 480
 33 | HEIGHT = 360
 34 | ALPHA_THRESHOLD = 72
 35 | 
 36 | 
 37 | def decode_samples(path: Path) -> dict[int, np.ndarray]:
 38 |     reader = imageio_ffmpeg.read_frames(str(path), pix_fmt="rgb24")
 39 |     metadata = next(reader)
 40 |     if tuple(metadata.get("size", ())) != (WIDTH * 2, HEIGHT):
 41 |         reader.close()
 42 |         raise RuntimeError(f"Unexpected video size for {path}: {metadata.get('size')}")
 43 | 
 44 |     result: dict[int, np.ndarray] = {}
 45 |     frame_bytes = WIDTH * 2 * HEIGHT * 3
 46 |     for index, raw in enumerate(reader):
 47 |         if index in SAMPLE_FRAMES:
 48 |             if len(raw) != frame_bytes:
 49 |                 reader.close()
 50 |                 raise RuntimeError(f"Unexpected frame bytes for {path}: {len(raw)}")
 51 |             result[index] = np.frombuffer(raw, dtype=np.uint8).reshape(
 52 |                 HEIGHT, WIDTH * 2, 3
 53 |             ).copy()
 54 |         if index >= max(SAMPLE_FRAMES):
 55 |             break
 56 |     reader.close()
 57 |     return result
 58 | 
 59 | 
 60 | def metrics(source: np.ndarray, packed: np.ndarray) -> dict[str, float]:
 61 |     color = packed[:, :WIDTH, :]
 62 |     alpha = packed[:, WIDTH:, 0]
 63 |     source_rgb = source[..., :3]
 64 |     source_alpha = source[..., 3]
 65 | 
 66 |     visible = source_alpha >= 16
 67 |     source_mask = source_alpha >= ALPHA_THRESHOLD
 68 |     decoded_mask = alpha >= ALPHA_THRESHOLD
 69 |     intersection = np.count_nonzero(source_mask & decoded_mask)
 70 |     union = np.count_nonzero(source_mask | decoded_mask)
 71 |     iou = float(intersection / union) if union else 1.0
 72 | 
 73 |     alpha_mae = float(
 74 |         np.mean(np.abs(alpha.astype(np.int16) - source_alpha.astype(np.int16)))
 75 |     )
 76 |     if np.any(visible):
 77 |         rgb_mae_visible = float(
 78 |             np.mean(
 79 |                 np.abs(
 80 |                     color[visible].astype(np.int16)
 81 |                     - source_rgb[visible].astype(np.int16)
 82 |                 )
 83 |             )
 84 |         )
 85 |     else:
 86 |         rgb_mae_visible = 0.0
 87 | 
 88 |     edge = (source_alpha > 0) & (source_alpha < 255)
 89 |     if np.any(edge):
 90 |         alpha_edge_mae = float(
 91 |             np.mean(
 92 |                 np.abs(
 93 |                     alpha[edge].astype(np.int16)
 94 |                     - source_alpha[edge].astype(np.int16)
 95 |                 )
 96 |             )
 97 |         )
 98 |     else:
 99 |         alpha_edge_mae = 0.0

    return {
        "alpha_mae": round(alpha_mae, 4),
        "alpha_edge_mae": round(alpha_edge_mae, 4),
        "rgb_mae_visible": round(rgb_mae_visible, 4),
        "alpha_iou_72": round(iou, 6),
    }


def main() -> int:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    report: dict[str, object] = {"actions": {}, "samples_per_action": 3}
    all_rows: list[dict[str, object]] = []

    for action in ACTIONS:
        directory = ASSET_ROOT / f"video_{action}"
        video = directory / "runtime_alpha.ogv"
        samples = decode_samples(video)
        action_rows: list[dict[str, object]] = []

        for index in sorted(SAMPLE_FRAMES):
            source_path = directory / "frames" / f"{index:03d}.png"
            source = np.array(Image.open(source_path).convert("RGBA"), dtype=np.uint8)
            packed = samples[index]
            color = packed[:, :WIDTH, :]
            alpha = packed[:, WIDTH:, 0]
            reconstructed = np.dstack([color, alpha]).astype(np.uint8)

            row: dict[str, object] = {
                "frame": index,
                **metrics(source, packed),
            }
            action_rows.append(row)
            all_rows.append({"action": action, **row})

            if action in {"idle", "click_happy", "yawn", "sleep_loop", "wake_up"}:
                Image.fromarray(reconstructed, "RGBA").save(
                    OUTPUT_ROOT / f"{action}_{index:03d}.png"
                )

        report["actions"][action] = action_rows

    report["worst"] = {
        "alpha_mae": max(all_rows, key=lambda row: float(row["alpha_mae"])),
        "alpha_edge_mae": max(
            all_rows, key=lambda row: float(row["alpha_edge_mae"])
        ),
        "rgb_mae_visible": max(
            all_rows, key=lambda row: float(row["rgb_mae_visible"])
        ),
        "alpha_iou_72": min(
            all_rows, key=lambda row: float(row["alpha_iou_72"])
        ),
    }
    report_path = OUTPUT_ROOT / "decode_report.json"
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report["worst"], ensure_ascii=False))
    print(f"REPORT: {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
