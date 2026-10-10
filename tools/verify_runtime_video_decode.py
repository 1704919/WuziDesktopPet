from __future__ import annotations

import json
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "godot/assets_display/wuzi_chibi"
OUTPUT_ROOT = ROOT / "work/video_review/runtime_decode"
ACTIONS = [
    "idle",
    "click_happy",
    "click_shy",
    "march_in_place",
    "sleepy",
    "yawn",
    "click_angry",
    "sleep_down",
    "drag_reaction",
    "startle",
    "yawn_small",
    "game_rage",
    "click_wave",
    "wake_up",
    "sleep_loop",
    "sing",
]
SAMPLE_FRAMES = {0, 60, 120}
WIDTH = 480
HEIGHT = 360
ALPHA_THRESHOLD = 72


def decode_samples(path: Path) -> dict[int, np.ndarray]:
    reader = imageio_ffmpeg.read_frames(str(path), pix_fmt="rgb24")
    metadata = next(reader)
    if tuple(metadata.get("size", ())) != (WIDTH * 2, HEIGHT):
        reader.close()
        raise RuntimeError(f"Unexpected video size for {path}: {metadata.get('size')}")

    result: dict[int, np.ndarray] = {}
    frame_bytes = WIDTH * 2 * HEIGHT * 3
    for index, raw in enumerate(reader):
        if index in SAMPLE_FRAMES:
            if len(raw) != frame_bytes:
                reader.close()
                raise RuntimeError(f"Unexpected frame bytes for {path}: {len(raw)}")
            result[index] = np.frombuffer(raw, dtype=np.uint8).reshape(
                HEIGHT, WIDTH * 2, 3
            ).copy()
        if index >= max(SAMPLE_FRAMES):
            break
    reader.close()
    return result


def metrics(source: np.ndarray, packed: np.ndarray) -> dict[str, float]:
    color = packed[:, :WIDTH, :]
    alpha = packed[:, WIDTH:, 0]
    source_rgb = source[..., :3]
    source_alpha = source[..., 3]

    visible = source_alpha >= 16
    source_mask = source_alpha >= ALPHA_THRESHOLD
    decoded_mask = alpha >= ALPHA_THRESHOLD
    intersection = np.count_nonzero(source_mask & decoded_mask)
    union = np.count_nonzero(source_mask | decoded_mask)
    iou = float(intersection / union) if union else 1.0

    alpha_mae = float(
        np.mean(np.abs(alpha.astype(np.int16) - source_alpha.astype(np.int16)))
    )
    if np.any(visible):
        rgb_mae_visible = float(
            np.mean(
                np.abs(
                    color[visible].astype(np.int16)
                    - source_rgb[visible].astype(np.int16)
                )
            )
        )
    else:
        rgb_mae_visible = 0.0

    edge = (source_alpha > 0) & (source_alpha < 255)
    if np.any(edge):
        alpha_edge_mae = float(
            np.mean(
                np.abs(
                    alpha[edge].astype(np.int16)
                    - source_alpha[edge].astype(np.int16)
                )
            )
        )
    else:
        alpha_edge_mae = 0.0

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
