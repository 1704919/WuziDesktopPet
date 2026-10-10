"""Audit the *installed* desktop-pet action endpoints against installed idle.

Only reads production config and generated RGBA PNG endpoints. It never changes
videos, gameplay config, alpha frames, scale curves, or approved visual baselines.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / "godot"
CONFIG = GODOT / "config" / "pet_behavior.json"
SLEEP_IDS = {"sleep_down", "sleep_loop", "wake_up"}
ALPHA_THRESHOLD = 72


def installed_directory(resource_path: str) -> Path:
    if not resource_path.startswith("res://"):
        raise ValueError(f"Expected Godot resource path: {resource_path}")
    directory = (GODOT / resource_path[len("res://"):]).resolve()
    if not directory.is_relative_to(GODOT.resolve()):
        raise ValueError(f"Frames directory escapes Godot project: {resource_path}")
    if not directory.is_dir():
        raise FileNotFoundError(directory)
    return directory


def endpoint(directory: Path, index: int) -> tuple[Path, dict]:
    path = directory / f"{index:03d}.png"
    with Image.open(path) as image:
        rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    mask = rgba[..., 3] >= ALPHA_THRESHOLD
    ys, xs = np.nonzero(mask)
    if not xs.size:
        raise ValueError(f"Empty visible character at {path}")
    x1, x2 = int(xs.min()), int(xs.max()) + 1
    y1, y2 = int(ys.min()), int(ys.max()) + 1

    # Upper silhouette core is an intentionally lightweight *proxy* for the
    # character's head/upper body; it is not object recognition. Props can
    # still contaminate the proxy. Such measurements are review-only.
    band_top = max(y1, round(y1 + (y2 - y1) * 0.08))
    band_bottom = min(y2, round(y1 + (y2 - y1) * 0.42))
    runs = []
    for y in range(band_top, band_bottom):
        padded = np.pad(mask[y, x1:x2].astype(np.int8), (1, 1))
        changes = np.diff(padded)
        lefts = np.flatnonzero(changes == 1)
        rights = np.flatnonzero(changes == -1)
        if lefts.size:
            runs.append(float((rights - lefts).max()))
    return path, {
        "bbox": [x1, y1, x2, y2],
        "width": float(x2 - x1),
        "height": float(y2 - y1),
        "center_x": (x1 + x2) / 2.0,
        "center_y": (y1 + y2) / 2.0,
        "bottom": float(y2),
        "upper_core_width": round(float(np.percentile(runs, 75)), 2) if runs else None,
    }


def difference(reference: dict, candidate: dict) -> dict:
    diffs = {
        "height_percent": round(100 * (candidate["height"] / reference["height"] - 1), 2),
        "width_percent": round(100 * (candidate["width"] / reference["width"] - 1), 2),
        "center_x_px": round(candidate["center_x"] - reference["center_x"], 2),
        "center_y_px": round(candidate["center_y"] - reference["center_y"], 2),
        "bottom_px": round(candidate["bottom"] - reference["bottom"], 2),
    }
    if reference["upper_core_width"] and candidate["upper_core_width"]:
        diffs["upper_core_percent"] = round(
            100 * (candidate["upper_core_width"] / reference["upper_core_width"] - 1), 2
        )
    return diffs


def grade(diffs: dict, *, mode: str) -> dict:
    # Thresholds describe visual *candidates*, not a guarantee of identical
    # anatomy. A large prop or a change of pose needs human review.
    thresholds = {
        "standing": {
            "height_percent": (3, 4),
            "center_x_px": (4, 8),
            "bottom_px": (3, 6),
            "upper_core_percent": (8, None),
        },
        "food": {
            # Eating is often seated; whole-canvas height is not body scale.
            "center_x_px": (4, 8),
            "bottom_px": (3, 6),
            "upper_core_percent": (5, None),
        },
        "self": {
            "height_percent": (3, 4),
            "center_x_px": (4, 8),
            "bottom_px": (3, 6),
            "upper_core_percent": (10, None),
        },
        "sleep_standing": {
            "height_percent": (3, 7),
            "center_x_px": (4, 10),
            "bottom_px": (3, 8),
            "upper_core_percent": (8, None),
        },
        "sleep_lying": {
            "width_percent": (2, 4),
            "height_percent": (5, 12),
            "center_x_px": (4, 10),
            "center_y_px": (4, 10),
            "bottom_px": (3, 8),
        },
    }[mode]
    reviews, anomalies = [], []
    for key, (review_threshold, anomaly_threshold) in thresholds.items():
        value = diffs.get(key)
        if value is None:
            continue
        if anomaly_threshold is not None and abs(value) > anomaly_threshold:
            anomalies.append(f"{key}={value:+g}")
        elif abs(value) >= review_threshold:
            reviews.append(f"{key}={value:+g}")
    status = "anomaly" if anomalies else "review" if reviews else "pass"
    return {"status": status, "reviews": reviews, "anomalies": anomalies}


def check(reference: dict, candidate: dict, mode: str) -> dict:
    delta = difference(reference, candidate)
    return {**grade(delta, mode=mode), "difference": delta}


def combine(checks: list[dict]) -> str:
    return ("anomaly" if any(c["status"] == "anomaly" for c in checks)
            else "review" if any(c["status"] == "review" for c in checks)
            else "pass")


def contact_sheet(rows: list[tuple[str, list[Path]]], destination: Path) -> None:
    if not rows:
        return
    # All source images remain on the *same 480x360 canvas*; this overview
    # deliberately does not crop or auto-rescale individual characters.
    tile_w, tile_h, label_h = 240, 180, 26
    sheet = Image.new("RGB", (tile_w * 4, (tile_h + label_h) * len(rows)),
                      (238, 238, 238))
    draw = ImageDraw.Draw(sheet)
    for row_index, (name, frame_paths) in enumerate(rows):
        top = row_index * (tile_h + label_h)
        draw.text((6, top + 5), name, fill=(20, 20, 20))
        for col_index, frame in enumerate(frame_paths):
            with Image.open(frame) as source:
                rgba = source.convert("RGBA")
            canvas = Image.new("RGBA", rgba.size, (238, 238, 238, 255))
            canvas.alpha_composite(rgba)
            reduced = canvas.convert("RGB").resize(
                (tile_w, tile_h), Image.Resampling.LANCZOS
            )
            sheet.paste(reduced, (col_index * tile_w, top + label_h))
            # A common center and ground guide is retained for all four views.
            x0 = col_index * tile_w
            y0 = top + label_h
            draw.line((x0 + 120, y0, x0 + 120, y0 + tile_h), fill=(205, 205, 205))
            draw.line((x0, y0 + 169, x0 + tile_w, y0 + 169), fill=(207, 207, 207))
    destination.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(destination, "JPEG", quality=89, optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=ROOT / "work" / "video_review" / "endpoint_audit",
    )
    parser.add_argument(
        "--strict", action="store_true",
        help="Return nonzero if a large endpoint anomaly is detected.",
    )
    args = parser.parse_args()

    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    idle = config["idle_video"]
    if not idle.get("enabled"):
        raise ValueError("The actually configured idle video is disabled")
    idle_dir = installed_directory(idle["frames_dir"])
    idle_start_idx = int(idle["start_frame"])
    idle_end_idx = int(idle["end_frame"])
    idle_start_path, idle_start = endpoint(idle_dir, idle_start_idx)
    idle_end_path, idle_end = endpoint(idle_dir, idle_end_idx)

    categories = {
        item["id"]: item.get("category", "")
        for item in config.get("manual_actions", [])
        if isinstance(item, dict) and "id" in item
    }
    clips = config.get("clips", {})
    action_records = {}
    sleep_metrics = {}
    overview_rows = []
    mapped_ids = set()
    for runtime_id, spec in sorted(clips.items()):
        directory = installed_directory(spec["frames_dir"])
        action_id = directory.parent.name.removeprefix("video_")
        if action_id in mapped_ids or action_id == "idle":
            raise ValueError(f"Duplicate/invalid action directory: {action_id}")
        mapped_ids.add(action_id)
        start_path, first = endpoint(directory, 0)
        last_index = int(spec["frame_count"]) - 1
        end_path, last = endpoint(directory, last_index)
        if action_id in SLEEP_IDS:
            sleep_metrics[action_id] = {
                "first": first, "last": last,
                "paths": [start_path, end_path],
                "runtime_id": runtime_id,
            }
            continue
        mode = "food" if categories.get(runtime_id) == "food" else "standing"
        entering = check(idle_end, first, mode)
        leaving = check(idle_start, last, mode)
        own_seam = check(first, last, "self")
        checks = [entering, leaving, own_seam]
        action_records[action_id] = {
            "runtime_id": runtime_id,
            "category": categories.get(runtime_id, ""),
            "rule": mode,
            "status": combine(checks),
            "frames": {"first": first, "last": last},
            "checks": {
                "idle_end_to_action_start": entering,
                "action_end_to_idle_start": leaving,
                "own_start_to_end": own_seam,
            },
        }
        overview_rows.append((action_id + " [" + action_records[action_id]["status"] + "]",
                              [idle_end_path, start_path, end_path, idle_start_path]))

    if set(sleep_metrics) != SLEEP_IDS:
        raise ValueError(f"Missing sleep clips: {SLEEP_IDS - set(sleep_metrics)}")
    down = sleep_metrics["sleep_down"]
    loop = sleep_metrics["sleep_loop"]
    wake = sleep_metrics["wake_up"]
    sleep_checks = {
        "idle_end_to_sleep_down_start": check(idle_end, down["first"], "sleep_standing"),
        "sleep_down_end_to_sleep_loop_start": check(
            down["last"], loop["first"], "sleep_lying"),
        "sleep_loop_last_to_first": check(loop["last"], loop["first"], "sleep_lying"),
        "sleep_loop_end_to_wake_up_start": check(
            loop["last"], wake["first"], "sleep_lying"),
        "wake_up_end_to_idle_start": check(idle_start, wake["last"], "sleep_standing"),
    }
    sleep_status = combine(list(sleep_checks.values()))

    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    contact_sheet(overview_rows, output_dir / "ordinary_endpoints.jpg")
    contact_sheet([
        ("idle_end -> sleep_down_start",
         [idle_end_path, down["paths"][0], down["paths"][1], loop["paths"][0]]),
        ("sleep_down_end -> sleep_loop_start",
         [down["paths"][1], loop["paths"][0], loop["paths"][1], wake["paths"][0]]),
        ("sleep_loop_end -> wake_start",
         [loop["paths"][1], wake["paths"][0], wake["paths"][1], idle_start_path]),
    ], output_dir / "sleep_endpoints.jpg")

    counts = {s: sum(r["status"] == s for r in action_records.values())
              for s in ("pass", "review", "anomaly")}
    report = {
        "schema_version": 1,
        "purpose": "Endpoint-only, read-only review of installed desktop-pet PNGs",
        "no_mid_sequence_zoom_check": True,
        "no_automatic_fixes": True,
        "idle_reference": {
            "config": CONFIG.relative_to(ROOT).as_posix(),
            "runtime_video_enabled": bool(config.get("video_runtime", {}).get("enabled")),
            "runtime_video": (idle_dir.parent / "runtime_alpha.ogv").relative_to(GODOT).as_posix(),
            "frames_dir": idle["frames_dir"],
            "start_frame": idle_start_idx,
            "end_frame": idle_end_idx,
            "first": idle_start, "last": idle_end,
            "first_sha256": hashlib.sha256(idle_start_path.read_bytes()).hexdigest(),
            "last_sha256": hashlib.sha256(idle_end_path.read_bytes()).hexdigest(),
            "loop_seam": check(idle_end, idle_start, "self"),
        },
        "scope": {
            "installed_clip_count": len(clips),
            "ordinary_clip_count": len(action_records),
            "sleep_clip_count": len(sleep_metrics),
            "ordinary_counts": counts,
            "sleep_status": sleep_status,
        },
        "limitations": [
            "Upper-silhouette width is a proxy, not semantic segmentation; props/pose can change it.",
            "Seated eating height is reported against idle, not a hard scale failure.",
            "The installed PNG endpoints are checked; runtime OGV is lossy encoded from the same processed frames.",
            "No checks of motion between endpoint frames and no video-source modification.",
            "JPEG sheets are only visual review aids; numeric checks use full-resolution PNGs.",
        ],
        "ordinary_actions": action_records,
        "sleep_checks": sleep_checks,
    }
    report_path = output_dir / "report.json"
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({
        "report": str(report_path),
        "ordinary_contact_sheet": str(output_dir / "ordinary_endpoints.jpg"),
        "sleep_contact_sheet": str(output_dir / "sleep_endpoints.jpg"),
        "scope": report["scope"],
        "idle_loop": report["idle_reference"]["loop_seam"],
        "ordinary_reviews": {
            key: {"status": value["status"],
                  "checks": {check_key: check_value
                             for check_key, check_value in value["checks"].items()
                             if check_value["status"] != "pass"}}
            for key, value in action_records.items() if value["status"] != "pass"
        },
        "sleep_checks": sleep_checks,
    }, ensure_ascii=False, indent=2))
    if args.strict and (counts["anomaly"] or sleep_status == "anomaly"):
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
