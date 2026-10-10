from __future__ import annotations

import hashlib
import json
import os
from collections import deque
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
VISUAL_BASELINE_PATH = ROOT / "godot/config/video_visual_baseline.json"
# Blue/pink are stable identity colors. "Pale" also covers skin/highlights and
# therefore varies more naturally across poses and expressions.
PALETTE_DELTA_LIMITS = {
    "blue": 6.0,
    "pink": 6.0,
    "pale": 25.0,
}
MIN_CANVAS_MARGIN = 8
CANVAS_WIDTH = 480
CANVAS_HEIGHT = 360
TARGET_IDLE_VISIBLE_HEIGHT = 220.0
MAX_REFERENCE_HEIGHT_DELTA = 14.0
MAX_IDENTITY_CORE_DELTA = 11.0
MAX_OPAQUE_FILL_RATIO = 0.72
MIN_VIDEO_COMPRESSION_RATIO = 2.0

# Cross-action transition consistency applies only to ordinary actions that
# start/end in the standing desktop-pet pose. The sleep chain has its own
# lying/standing transition rules below and must not be forced through these
# thresholds.
TRANSITION_SPECIAL_ACTION_IDS = {
    "sleep_down", "sleep_loop", "wake_up",
    "birthday_cake", "eat_noodles", "eat_fried_chicken",
    "eat_sushi", "eat_breakfast", "eat_bullfrog", "eat_fries",
}
TRANSITION_SCALE_REVIEW_RATIO = 0.03
TRANSITION_SCALE_FAIL_RATIO = 0.04
TRANSITION_CENTER_REVIEW_PX = 4.0
TRANSITION_CENTER_FAIL_PX = 8.0
TRANSITION_BOTTOM_REVIEW_PX = 3.0
TRANSITION_BOTTOM_FAIL_PX = 6.0

PROP_HEAVY_CORE_EXEMPT_ACTION_IDS = {"read_book", "watch_kline"}
CORE_BAND_TOP_RATIO = 0.08
CORE_BAND_BOTTOM_RATIO = 0.42
CORE_WIDTH_PERCENTILE = 75.0

EXPECTED = {
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
    "game_controller": ROOT / "godot/assets_display/wuzi_chibi/video_game_controller/frames",
    "read_book": ROOT / "godot/assets_display/wuzi_chibi/video_read_book/frames",
    "watch_kline": ROOT / "godot/assets_display/wuzi_chibi/video_watch_kline/frames",
    "drink_milk_tea": ROOT / "godot/assets_display/wuzi_chibi/video_drink_milk_tea/frames",
    "work_computer": ROOT / "godot/assets_display/wuzi_chibi/video_work_computer/frames",
    "lie_phone": ROOT / "godot/assets_display/wuzi_chibi/video_lie_phone/frames",
    "walk_left": ROOT / "godot/assets_display/wuzi_chibi/video_walk_left/frames",
    "walk_right": ROOT / "godot/assets_display/wuzi_chibi/video_walk_right/frames",
    "mic_test": ROOT / "godot/assets_display/wuzi_chibi/video_mic_test/frames",
    "cat_accident": ROOT / "godot/assets_display/wuzi_chibi/video_cat_accident/frames",
    "unbox_cards": ROOT / "godot/assets_display/wuzi_chibi/video_unbox_cards/frames",
    "pc_game_rage": ROOT / "godot/assets_display/wuzi_chibi/video_pc_game_rage/frames",
    "sunglasses_proud": ROOT / "godot/assets_display/wuzi_chibi/video_sunglasses_proud/frames",
    "pc_game_focused": ROOT / "godot/assets_display/wuzi_chibi/video_pc_game_focused/frames",
    "hop_bounce": ROOT / "godot/assets_display/wuzi_chibi/video_hop_bounce/frames",
    "birthday_cake": ROOT / "godot/assets_display/wuzi_chibi/video_birthday_cake/frames",
    "eat_noodles": ROOT / "godot/assets_display/wuzi_chibi/video_eat_noodles/frames",
    "eat_fried_chicken": ROOT / "godot/assets_display/wuzi_chibi/video_eat_fried_chicken/frames",
    "eat_sushi": ROOT / "godot/assets_display/wuzi_chibi/video_eat_sushi/frames",
    "eat_breakfast": ROOT / "godot/assets_display/wuzi_chibi/video_eat_breakfast/frames",
    "eat_bullfrog": ROOT / "godot/assets_display/wuzi_chibi/video_eat_bullfrog/frames",
    "eat_fries": ROOT / "godot/assets_display/wuzi_chibi/video_eat_fries/frames",
}
RUNTIME_IDS = {
    "idle": "idle",
    "click_happy": "click_happy_video",
    "click_shy": "click_shy_video",
    "march_in_place": "march_in_place_video",
    "sleepy": "sleepy_video",
    "yawn": "yawn_video",
    "click_angry": "click_angry_video",
    "sleep_down": "sleep_down_video",
    "drag_reaction": "drag_reaction_video",
    "startle": "startle_video",
    "yawn_small": "yawn_small_video",
    "game_rage": "game_rage_video",
    "click_wave": "click_wave_video",
    "wake_up": "wake_up_video",
    "sleep_loop": "sleep_loop_video",
    "sing": "sing_video",
    "game_controller": "game_controller_video",
    "read_book": "read_book_video",
    "watch_kline": "watch_kline_video",
    "drink_milk_tea": "drink_milk_tea_video",
    "work_computer": "work_computer_video",
    "lie_phone": "lie_phone_video",
    "walk_left": "walk_left_video",
    "walk_right": "walk_right_video",
    "mic_test": "mic_test_video",
    "cat_accident": "cat_accident_video",
    "unbox_cards": "unbox_cards",
    "pc_game_rage": "pc_game_rage",
    "sunglasses_proud": "sunglasses_proud",
    "pc_game_focused": "pc_game_focused",
    "hop_bounce": "hop_bounce",
    "birthday_cake": "birthday_cake",
    "eat_noodles": "eat_noodles",
    "eat_fried_chicken": "eat_fried_chicken",
    "eat_sushi": "eat_sushi",
    "eat_breakfast": "eat_breakfast",
    "eat_bullfrog": "eat_bullfrog",
    "eat_fries": "eat_fries",
}

MANIFEST_NAMES = {
    "idle": "idle_video_manifest.json",
    "click_happy": "click_happy_video_manifest.json",
    "click_shy": "click_shy_video_manifest.json",
    "march_in_place": "march_in_place_video_manifest.json",
    "sleepy": "sleepy_video_manifest.json",
    "yawn": "yawn_video_manifest.json",
    "click_angry": "click_angry_video_manifest.json",
    "sleep_down": "sleep_down_video_manifest.json",
    "drag_reaction": "drag_reaction_video_manifest.json",
    "startle": "startle_video_manifest.json",
    "yawn_small": "yawn_small_video_manifest.json",
    "game_rage": "game_rage_video_manifest.json",
    "click_wave": "click_wave_video_manifest.json",
    "wake_up": "wake_up_video_manifest.json",
    "sleep_loop": "sleep_loop_video_manifest.json",
    "sing": "sing_video_manifest.json",
    "game_controller": "game_controller_video_manifest.json",
    "read_book": "read_book_video_manifest.json",
    "watch_kline": "watch_kline_video_manifest.json",
    "drink_milk_tea": "drink_milk_tea_video_manifest.json",
    "work_computer": "work_computer_video_manifest.json",
    "lie_phone": "lie_phone_video_manifest.json",
    "walk_left": "walk_left_video_manifest.json",
    "walk_right": "walk_right_video_manifest.json",
    "mic_test": "mic_test_video_manifest.json",
    "cat_accident": "cat_accident_video_manifest.json",
    "unbox_cards": "unbox_cards_video_manifest.json",
    "pc_game_rage": "pc_game_rage_video_manifest.json",
    "sunglasses_proud": "sunglasses_proud_video_manifest.json",
    "pc_game_focused": "pc_game_focused_video_manifest.json",
    "hop_bounce": "hop_bounce_video_manifest.json",
    "birthday_cake": "birthday_cake_video_manifest.json",
    "eat_noodles": "eat_noodles_video_manifest.json",
    "eat_fried_chicken": "eat_fried_chicken_video_manifest.json",
    "eat_sushi": "eat_sushi_video_manifest.json",
    "eat_breakfast": "eat_breakfast_video_manifest.json",
    "eat_bullfrog": "eat_bullfrog_video_manifest.json",
    "eat_fries": "eat_fries_video_manifest.json",
}

SLEEP_LOOP_COMPONENT_GRID = (240, 180)
SLEEP_LOOP_ZZZ_KEEP_X = (105, 140)
SLEEP_LOOP_ZZZ_KEEP_Y = (90, 120)
SLEEP_LOOP_PROTECT_DILATE = 17
SLEEP_LOOP_WATERMARK_X = (328, 376)
SLEEP_LOOP_WATERMARK_Y = (319, 330)
SLEEP_LOOP_WATERMARK_RGB_MIN = 105
SLEEP_LOOP_WATERMARK_CHROMA_MAX = 45
SLEEP_LOOP_WATERMARK_WARM_RGB_MIN = 150
SLEEP_LOOP_WATERMARK_WARM_CHROMA_MAX = 35


def sleep_loop_residual_outside_protection(alpha: np.ndarray) -> dict | None:
    grid_w, grid_h = SLEEP_LOOP_COMPONENT_GRID
    grid = (
        np.array(
            Image.fromarray(
                (alpha >= 72).astype(np.uint8) * 255,
                "L",
            ).resize(
                (grid_w, grid_h),
                Image.Resampling.NEAREST,
            ),
            dtype=np.uint8,
        )
        > 0
    )
    visited = np.zeros_like(grid, dtype=bool)
    components: list[list[tuple[int, int]]] = []
    for y in range(grid_h):
        for x in range(grid_w):
            if not grid[y, x] or visited[y, x]:
                continue
            queue: deque[tuple[int, int]] = deque([(y, x)])
            visited[y, x] = True
            pixels: list[tuple[int, int]] = []
            while queue:
                cy, cx = queue.popleft()
                pixels.append((cy, cx))
                for ny, nx in (
                    (cy - 1, cx),
                    (cy + 1, cx),
                    (cy, cx - 1),
                    (cy, cx + 1),
                ):
                    if (
                        0 <= ny < grid_h
                        and 0 <= nx < grid_w
                        and grid[ny, nx]
                        and not visited[ny, nx]
                    ):
                        visited[ny, nx] = True
                        queue.append((ny, nx))
            components.append(pixels)

    if not components:
        return None

    main_index = max(range(len(components)), key=lambda idx: len(components[idx]))
    protected_grid = np.zeros((grid_h, grid_w), dtype=np.uint8)
    for py, px in components[main_index]:
        protected_grid[py, px] = 255

    x1, x2 = SLEEP_LOOP_ZZZ_KEEP_X
    y1, y2 = SLEEP_LOOP_ZZZ_KEEP_Y
    protected_grid[y1:y2, x1:x2] = 255

    protected = Image.fromarray(protected_grid, "L").resize(
        (alpha.shape[1], alpha.shape[0]),
        Image.Resampling.NEAREST,
    )
    protected = protected.filter(
        ImageFilter.MaxFilter(SLEEP_LOOP_PROTECT_DILATE)
    )
    keep = np.array(protected, dtype=np.uint8) > 0
    residual = (alpha > 0) & (~keep)
    if not np.any(residual):
        return None

    ys, xs = np.where(residual)
    return {
        "pixels": int(len(xs)),
        "max_alpha": int(alpha[residual].max()),
        "bbox": [
            int(xs.min()),
            int(ys.min()),
            int(xs.max() + 1),
            int(ys.max() + 1),
        ],
    }


def semantic_palette(files: list[Path]) -> dict[str, list[float]]:
    groups: dict[str, list[np.ndarray]] = {
        "blue": [],
        "pink": [],
        "pale": [],
    }
    for path in files[:18]:
        rgba = np.array(Image.open(path).convert("RGBA"), dtype=np.uint8)
        rgb = rgba[..., :3].astype(np.float32)
        alpha = rgba[..., 3]
        pixels = rgb[alpha >= 220]
        if not len(pixels):
            continue
        pixels = pixels[np.max(pixels, axis=1) >= 45]
        blue = pixels[
            (pixels[:, 2] > pixels[:, 0] * 1.10)
            & (pixels[:, 2] > pixels[:, 1] * 1.05)
            & (pixels[:, 2] > 80)
        ]
        pink = pixels[
            (pixels[:, 0] > pixels[:, 1] * 1.18)
            & (pixels[:, 0] > pixels[:, 2] * 1.03)
            & (pixels[:, 0] > 90)
        ]
        pale = pixels[
            (pixels[:, 0] > 150)
            & (pixels[:, 1] > 120)
            & (pixels[:, 2] > 120)
        ]
        if len(blue):
            groups["blue"].append(blue)
        if len(pink):
            groups["pink"].append(pink)
        if len(pale):
            groups["pale"].append(pale)

    result: dict[str, list[float]] = {}
    for label, chunks in groups.items():
        if not chunks:
            continue
        merged = np.concatenate(chunks, axis=0)
        result[label] = [float(x) for x in np.mean(merged, axis=0)]
    return result


def largest_true_run(row: np.ndarray) -> int:
    padded = np.pad(row.astype(np.int8), (1, 1), constant_values=0)
    changes = np.diff(padded)
    starts = np.where(changes == 1)[0]
    ends = np.where(changes == -1)[0]
    if not len(starts):
        return 0
    return int(np.max(ends - starts))


def identity_core_width(alpha: np.ndarray) -> float | None:
    ys, xs = np.where(alpha >= 72)
    if not len(xs):
        return None
    x1, y1, x2, y2 = int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)
    height = max(1, y2 - y1)
    band_y1 = max(y1, round(y1 + height * CORE_BAND_TOP_RATIO))
    band_y2 = min(y2, round(y1 + height * CORE_BAND_BOTTOM_RATIO))
    if band_y2 <= band_y1:
        return None
    mask = alpha >= 72
    widths = [largest_true_run(mask[y, x1:x2]) for y in range(band_y1, band_y2)]
    widths = [width for width in widths if width > 0]
    if not widths:
        return None
    return float(np.percentile(widths, CORE_WIDTH_PERCENTILE))


def transition_frame_metrics(path: Path) -> dict | None:
    if not path.is_file():
        return None
    with Image.open(path) as image:
        alpha = np.array(image.convert("RGBA"), dtype=np.uint8)[..., 3]
    ys, xs = np.where(alpha >= 72)
    if not len(xs):
        return None
    x1, y1 = int(xs.min()), int(ys.min())
    x2, y2 = int(xs.max() + 1), int(ys.max() + 1)
    core_width = identity_core_width(alpha)
    return {
        "bbox": [x1, y1, x2, y2],
        "height_px": float(y2 - y1),
        "width_px": float(x2 - x1),
        "center_x_px": float((x1 + x2) / 2.0),
        "bottom_y_px": float(y2),
        "identity_core_width_px": core_width,
    }


failures = []
results = {}
manifests = {}

try:
    visual_baseline = json.loads(VISUAL_BASELINE_PATH.read_text(encoding="utf-8"))
except Exception as exc:
    visual_baseline = {}
    failures.append(f"visual_baseline_read={exc}")

known_pending_cleanup = visual_baseline.get("known_pending_individual_cleanup", {})
if not isinstance(known_pending_cleanup, dict):
    known_pending_cleanup = {}

for name, directory in EXPECTED.items():
    manifest_path = ROOT / "godot/config" / MANIFEST_NAMES[name]
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifests[name] = manifest
    except Exception as exc:
        failures.append(f"{name}:manifest_read={exc}")
        manifest = {}

    canvas = manifest.get("canvas", [0, 0])
    if not isinstance(canvas, list) or len(canvas) < 2:
        failures.append(f"{name}:canvas={canvas}")
        expected_width, expected_height = CANVAS_WIDTH, CANVAS_HEIGHT
    else:
        expected_width, expected_height = int(canvas[0]), int(canvas[1])
    if (expected_width, expected_height) != (CANVAS_WIDTH, CANVAS_HEIGHT):
        failures.append(f"{name}:canvas={expected_width}x{expected_height}")

    files = sorted(directory.glob("*.png"))
    if len(files) != 121:
        failures.append(f"{name}:frame_count={len(files)}")
    min_margin = 999
    edge_hits = []
    nonempty = 0
    reference_heights = []
    reference_widths = []
    reference_fill_ratios = []
    reference_core_widths = []
    for i, path in enumerate(files):
        with Image.open(path) as im:
            if im.size != (expected_width, expected_height):
                failures.append(f"{name}:{path.name}:size={im.size}")
                continue
            rgba_frame = np.array(im.convert("RGBA"), dtype=np.uint8)
            alpha = rgba_frame[..., 3]
        if name == "sleep_loop":
            residual = sleep_loop_residual_outside_protection(alpha)
            if residual is not None:
                failures.append(
                    f"sleep_loop:{path.name}:residual_outside_protection={residual}"
                )

            x1, x2 = SLEEP_LOOP_WATERMARK_X
            y1, y2 = SLEEP_LOOP_WATERMARK_Y
            region = rgba_frame[y1:y2, x1:x2]
            if region.size:
                rgb = region[..., :3].astype(np.int16)
                alpha_region = region[..., 3]
                minimum = np.min(rgb, axis=2)
                maximum = np.max(rgb, axis=2)
                r = rgb[..., 0]
                g = rgb[..., 1]
                b = rgb[..., 2]
                cool_neutral = (
                    (minimum >= SLEEP_LOOP_WATERMARK_RGB_MIN)
                    & ((maximum - minimum) <= SLEEP_LOOP_WATERMARK_CHROMA_MAX)
                    & (g >= r - 8)
                    & (b >= r - 8)
                )
                warm_neutral = (
                    (minimum >= SLEEP_LOOP_WATERMARK_WARM_RGB_MIN)
                    & (
                        (maximum - minimum)
                        <= SLEEP_LOOP_WATERMARK_WARM_CHROMA_MAX
                    )
                )
                watermark_like = (alpha_region > 0) & (
                    cool_neutral | warm_neutral
                )
                if np.any(watermark_like):
                    failures.append(
                        f"sleep_loop:{path.name}:local_watermark_residual="
                        f"{int(np.sum(watermark_like))}"
                    )
        ys, xs = np.where(alpha >= 72)
        if not len(xs):
            failures.append(f"{name}:{path.name}:empty")
            continue
        nonempty += 1
        bbox = (int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1))
        if i < 12:
            reference_heights.append(bbox[3] - bbox[1])
            reference_widths.append(bbox[2] - bbox[0])
            crop = alpha[bbox[1]:bbox[3], bbox[0]:bbox[2]]
            reference_fill_ratios.append(float(np.mean(crop >= 72)))
            core_width = identity_core_width(alpha)
            if core_width is not None:
                reference_core_widths.append(core_width)
        margin = min(
            bbox[0],
            bbox[1],
            expected_width - bbox[2],
            expected_height - bbox[3],
        )
        min_margin = min(min_margin, margin)
        if margin < MIN_CANVAS_MARGIN:
            edge_hits.append(i)
    if edge_hits:
        failures.append(f"{name}:edge_hits={edge_hits[:12]}")
    reference_height_median = float(np.median(reference_heights)) if reference_heights else None
    reference_width_median = float(np.median(reference_widths)) if reference_widths else None
    reference_fill_median = float(np.median(reference_fill_ratios)) if reference_fill_ratios else None
    reference_core_median = float(np.median(reference_core_widths)) if reference_core_widths else None
    allow_height_mismatch = bool(
        (known_pending_cleanup.get(name, {}) or {}).get(
            "allow_reference_height_mismatch",
            False,
        )
    )
    sleep_chain_action = name in {"sleep_down", "sleep_loop", "wake_up"}
    transform = manifest.get("transform", {}) if isinstance(manifest, dict) else {}
    fit = manifest.get("canvas_fit", {}) if isinstance(manifest, dict) else {}
    fit_scale = float(fit.get("scale", 1.0) or 1.0)
    target_height = float(transform.get("target_visible_height", 0.0) or 0.0) * fit_scale
    target_core_width = float(transform.get("target_identity_core_width", 0.0) or 0.0) * fit_scale
    visual_norm = manifest.get("visual_scale_normalization", {}) if isinstance(manifest, dict) else {}
    visual_mode = str(visual_norm.get("mode", ""))
    visual_multiplier = float(visual_norm.get("multiplier_median", 1.0) or 1.0)
    effective_target_height = target_height * visual_multiplier
    effective_target_core_width = target_core_width * visual_multiplier

    if name == "idle" and abs(target_height - TARGET_IDLE_VISIBLE_HEIGHT) > 1e-6:
        failures.append(f"idle:target_visible_height={target_height}")

    if reference_fill_median is not None and reference_fill_median > MAX_OPAQUE_FILL_RATIO:
        failures.append(f"{name}:opaque_fill_ratio={reference_fill_median:.3f}")
    results[name] = {
        "frames": len(files),
        "nonempty": nonempty,
        "min_margin_px": None if min_margin == 999 else min_margin,
        "reference_height_median_px": reference_height_median,
        "reference_width_median_px": reference_width_median,
        "reference_identity_core_width_median_px": reference_core_median,
        "reference_fill_ratio_median": reference_fill_median,
        "semantic_palette": semantic_palette(files),
    }

idle_reference_height = results.get("idle", {}).get("reference_height_median_px")
idle_reference_core = results.get("idle", {}).get("reference_identity_core_width_median_px")
for name, result in results.items():
    if name in {"sleep_down", "sleep_loop", "wake_up"}:
        continue
    allow_height_mismatch = bool(
        (known_pending_cleanup.get(name, {}) or {}).get(
            "allow_reference_height_mismatch",
            False,
        )
    )
    reference_height = result.get("reference_height_median_px")
    reference_core = result.get("reference_identity_core_width_median_px")
    if (
        name not in PROP_HEAVY_CORE_EXEMPT_ACTION_IDS
        and not allow_height_mismatch
        and idle_reference_height is not None
        and reference_height is not None
        and abs(float(reference_height) - float(idle_reference_height))
        > MAX_REFERENCE_HEIGHT_DELTA
    ):
        failures.append(
            f"{name}:standing_height_delta="
            f"{float(reference_height) - float(idle_reference_height):.2f}"
        )
    if (
        name not in PROP_HEAVY_CORE_EXEMPT_ACTION_IDS
        and idle_reference_core is not None
        and reference_core is not None
        and abs(float(reference_core) - float(idle_reference_core))
        > MAX_IDENTITY_CORE_DELTA
    ):
        failures.append(
            f"{name}:standing_core_delta="
            f"{float(reference_core) - float(idle_reference_core):.2f}"
        )

strict_transition_mode = os.environ.get(
    "Q_VIDEO_STRICT_TRANSITIONS",
    "",
).strip().lower() in {"1", "true", "yes", "on"}

transition_reviews: list[str] = []
transition_strict_failures: list[str] = []
transition_actions: dict[str, dict] = {}

idle_manifest = manifests.get("idle", {})
idle_transform = idle_manifest.get("transform", {}) if isinstance(idle_manifest, dict) else {}
idle_fit = idle_manifest.get("canvas_fit", {}) if isinstance(idle_manifest, dict) else {}
idle_visual_norm = (
    idle_manifest.get("visual_scale_normalization", {})
    if isinstance(idle_manifest, dict)
    else {}
)
idle_effective_height = (
    float(idle_transform.get("target_visible_height", 0.0) or 0.0)
    * float(idle_fit.get("scale", 1.0) or 1.0)
    * float(idle_visual_norm.get("multiplier_median", 1.0) or 1.0)
)
idle_endpoints = {
    frame_name: transition_frame_metrics(EXPECTED["idle"] / f"{frame_name}.png")
    for frame_name in ("000", "120")
}

for name, directory in EXPECTED.items():
    if name == "idle" or name in TRANSITION_SPECIAL_ACTION_IDS:
        continue

    manifest = manifests.get(name, {})
    transform = manifest.get("transform", {}) if isinstance(manifest, dict) else {}
    fit = manifest.get("canvas_fit", {}) if isinstance(manifest, dict) else {}
    visual_norm = (
        manifest.get("visual_scale_normalization", {})
        if isinstance(manifest, dict)
        else {}
    )
    effective_height = (
        float(transform.get("target_visible_height", 0.0) or 0.0)
        * float(fit.get("scale", 1.0) or 1.0)
        * float(visual_norm.get("multiplier_median", 1.0) or 1.0)
    )
    scale_delta_ratio = (
        (effective_height / idle_effective_height) - 1.0
        if idle_effective_height > 0.0 and effective_height > 0.0
        else None
    )

    action_reviews: list[str] = []
    action_failures: list[str] = []
    endpoint_results: dict[str, dict] = {}

    if scale_delta_ratio is not None:
        if abs(scale_delta_ratio) >= TRANSITION_SCALE_REVIEW_RATIO:
            # Manifest target height is useful context, but props/pose envelopes
            # can make it disagree with the actual standing endpoint. Keep it as
            # review-only; strict gating is based on rendered 000/120 frames.
            reason = f"manifest_scale_delta={scale_delta_ratio * 100.0:+.2f}%"
            action_reviews.append(reason)

    for frame_name in ("000", "120"):
        current = transition_frame_metrics(directory / f"{frame_name}.png")
        reference = idle_endpoints.get(frame_name)
        if current is None or reference is None:
            action_failures.append(f"{frame_name}:missing_endpoint_metrics")
            continue

        height_delta_ratio = (
            (float(current["height_px"]) / float(reference["height_px"])) - 1.0
            if float(reference["height_px"]) > 0.0
            else 0.0
        )
        center_delta = (
            float(current["center_x_px"]) - float(reference["center_x_px"])
        )
        bottom_delta = (
            float(current["bottom_y_px"]) - float(reference["bottom_y_px"])
        )
        core_delta_ratio = None
        if (
            current.get("identity_core_width_px") is not None
            and reference.get("identity_core_width_px") is not None
            and float(reference["identity_core_width_px"]) > 0.0
        ):
            core_delta_ratio = (
                float(current["identity_core_width_px"])
                / float(reference["identity_core_width_px"])
            ) - 1.0

        endpoint_results[frame_name] = {
            "height_px": current["height_px"],
            "height_delta_ratio": height_delta_ratio,
            "center_x_px": current["center_x_px"],
            "center_delta_px": center_delta,
            "bottom_y_px": current["bottom_y_px"],
            "bottom_delta_px": bottom_delta,
            "identity_core_width_px": current.get("identity_core_width_px"),
            "identity_core_delta_ratio": core_delta_ratio,
        }

        if abs(height_delta_ratio) >= TRANSITION_SCALE_REVIEW_RATIO:
            action_reviews.append(
                f"{frame_name}:height_delta={height_delta_ratio * 100.0:+.2f}%"
            )
        if abs(height_delta_ratio) > TRANSITION_SCALE_FAIL_RATIO:
            action_failures.append(
                f"{frame_name}:height_delta={height_delta_ratio * 100.0:+.2f}%"
            )

        if abs(center_delta) >= TRANSITION_CENTER_REVIEW_PX:
            action_reviews.append(
                f"{frame_name}:center_delta={center_delta:+.1f}px"
            )
        if abs(center_delta) > TRANSITION_CENTER_FAIL_PX:
            action_failures.append(
                f"{frame_name}:center_delta={center_delta:+.1f}px"
            )

        if abs(bottom_delta) >= TRANSITION_BOTTOM_REVIEW_PX:
            action_reviews.append(
                f"{frame_name}:bottom_delta={bottom_delta:+.1f}px"
            )
        if abs(bottom_delta) > TRANSITION_BOTTOM_FAIL_PX:
            action_failures.append(
                f"{frame_name}:bottom_delta={bottom_delta:+.1f}px"
            )

    transition_actions[name] = {
        "effective_target_height_px": effective_height,
        "scale_delta_ratio": scale_delta_ratio,
        "target_center_x": float(
            transform.get("target_center_x", CANVAS_WIDTH / 2.0)
        ),
        "endpoints": endpoint_results,
        "reviews": action_reviews,
        "strict_failures": action_failures,
    }

    transition_reviews.extend(
        f"{name}:{reason}" for reason in action_reviews
    )
    transition_strict_failures.extend(
        f"{name}:{reason}" for reason in action_failures
    )

transition_consistency = {
    "strict_mode": strict_transition_mode,
    "excluded_special_actions": sorted(TRANSITION_SPECIAL_ACTION_IDS),
    "thresholds": {
        "scale_review_ratio": TRANSITION_SCALE_REVIEW_RATIO,
        "scale_fail_ratio": TRANSITION_SCALE_FAIL_RATIO,
        "center_review_px": TRANSITION_CENTER_REVIEW_PX,
        "center_fail_px": TRANSITION_CENTER_FAIL_PX,
        "bottom_review_px": TRANSITION_BOTTOM_REVIEW_PX,
        "bottom_fail_px": TRANSITION_BOTTOM_FAIL_PX,
    },
    "idle_reference": {
        "effective_target_height_px": idle_effective_height,
        "endpoints": idle_endpoints,
    },
    "actions": transition_actions,
    "reviews": transition_reviews,
    "strict_failures": transition_strict_failures,
}

if strict_transition_mode:
    failures.extend(
        f"transition:{item}" for item in transition_strict_failures
    )

if int(visual_baseline.get("schema_version", 0)) < 3:
    failures.append(f"visual_baseline_schema={visual_baseline.get('schema_version')}")

baseline_fill = visual_baseline.get("min_reference_fill_ratio", {})
baseline_hashes = visual_baseline.get("rgba_sha256", {})
for name, directory in EXPECTED.items():
    current_fill = results.get(name, {}).get("reference_fill_ratio_median")
    minimum_fill = baseline_fill.get(name)
    if minimum_fill is None:
        failures.append(f"{name}:missing_min_fill_baseline")
    elif current_fill is None or float(current_fill) < float(minimum_fill):
        failures.append(
            f"{name}:reference_fill_ratio={current_fill},min={minimum_fill}"
        )

    action_hashes = baseline_hashes.get(name)
    if not isinstance(action_hashes, dict):
        failures.append(f"{name}:missing_rgba_visual_baseline")
        continue
    checked_hashes = {}
    for frame_name, expected_hash in action_hashes.items():
        frame_path = directory / f"{frame_name}.png"
        if not frame_path.is_file():
            failures.append(f"{name}:missing_visual_frame={frame_name}")
            continue
        with Image.open(frame_path) as im:
            rgba_bytes = im.convert("RGBA").tobytes()
        actual_hash = hashlib.sha256(rgba_bytes).hexdigest()
        checked_hashes[frame_name] = actual_hash
        if actual_hash != expected_hash:
            failures.append(
                f"{name}:rgba_visual_hash[{frame_name}]={actual_hash}"
            )
    results[name]["visual_baseline_hashes"] = checked_hashes

idle_palette = results.get("idle", {}).get("semantic_palette", {})
for name, result in results.items():
    if name in {"idle", "wake_up"}:
        # The replacement wake-up source colour is explicitly approved as-is.
        # Do not fail it for not matching the idle palette; its colour correction
        # MUST be disabled, which is verified via manifest below.
        continue
    palette = result.get("semantic_palette", {})
    for label in ("blue", "pink", "pale"):
        if label not in idle_palette or label not in palette:
            failures.append(f"{name}:missing_palette_group={label}")
            continue
        delta = np.abs(
            np.array(palette[label], dtype=np.float32)
            - np.array(idle_palette[label], dtype=np.float32)
        )
        if float(np.max(delta)) > PALETTE_DELTA_LIMITS[label]:
            failures.append(
                f"{name}:{label}_color_delta={delta.round(2).tolist()}"
            )

# Pose width is expected to change (arms, pillow, lying pose). Character scale is
# validated against idle's upper-body/head identity core and uniform X/Y transforms.
idle_target_core = float(
    manifests.get("idle", {}).get("transform", {}).get("target_identity_core_width", 0.0) or 0.0
)
for name, manifest_name in MANIFEST_NAMES.items():
    manifest = manifests.get(name, {})
    if not manifest:
        continue
    if int(manifest.get("schema_version", 0)) < 10:
        failures.append(f"{name}:manifest_schema={manifest.get('schema_version')}")

    visual_norm = manifest.get("visual_scale_normalization", {})
    expected_visual_mode = (
        "idle_reference"
        if name == "idle"
        else (
            "sleep_chain_fixed_source"
            if name == "wake_up"
            else (
                "sleep_chain_fixed"
                if name in {"sleep_down", "sleep_loop"}
                else "fixed_action_face_height"
            )
        )
    )
    if visual_norm.get("mode") != expected_visual_mode:
        failures.append(
            f"{name}:visual_scale_mode={visual_norm.get('mode')},expected={expected_visual_mode}"
        )
    target_face_height = float(visual_norm.get("target_face_height", 0.0) or 0.0)
    if target_face_height <= 0.0:
        failures.append(f"{name}:target_face_height={target_face_height}")
    multiplier_min = float(visual_norm.get("multiplier_min", 0.0) or 0.0)
    multiplier_max = float(visual_norm.get("multiplier_max", 0.0) or 0.0)
    if multiplier_min <= 0.0 or multiplier_max <= 0.0 or multiplier_min > multiplier_max:
        failures.append(
            f"{name}:visual_scale_range={multiplier_min},{multiplier_max}"
        )
    if expected_visual_mode == "fixed_action_face_height":
        if abs(multiplier_min - 1.0) > 1e-6 or abs(multiplier_max - 1.0) > 1e-6:
            failures.append(
                f"{name}:per_frame_scale_detected={multiplier_min},{multiplier_max}"
            )

    transform = manifest.get("transform", {})
    if name == "click_happy":
        if abs(float(transform.get("manual_scale_multiplier", 0.0)) - 0.96) > 1e-6:
            failures.append(
                f"click_happy:manual_scale_multiplier={transform.get('manual_scale_multiplier')}"
            )
    if name == "drag_reaction":
        if abs(float(transform.get("manual_scale_multiplier", 0.0)) - 1.10) > 1e-6:
            failures.append(
                f"drag_reaction:manual_scale_multiplier={transform.get('manual_scale_multiplier')}"
            )
    if name == "wake_up":
        if "scale_curve" in transform:
            failures.append("wake_up:obsolete_scale_curve_present")
        if transform.get("layout_mode") != "wake_fixed_source_scale":
            failures.append("wake_up:expected_fixed_source_scale")
        start_scale = float(transform.get("start_scale", 0.0) or 0.0)
        end_scale = float(transform.get("end_scale", 0.0) or 0.0)
        if start_scale <= 0.0 or abs(end_scale - start_scale) > 1e-6:
            failures.append("wake_up:non_fixed_source_scale")
        normal = manifest.get("color_normalization", {})
        if normal.get("reference_action") != "none_source_video_preserved":
            failures.append("wake_up:source_colours_not_preserved")
        if normal.get("correction", {}).get("enabled", True):
            failures.append("wake_up:recolouring_enabled")
        if normal.get("semantic_deltas"):
            failures.append("wake_up:semantic_recolouring_detected")
        if manifest.get("skin_tone_endpoint_correction"):
            failures.append("wake_up:skin_tone_override_present")
        if normal.get("source_palette") != normal.get("corrected_palette"):
            failures.append("wake_up:source_palette_modified")
    key_config = manifest.get("key", {})
    green_key_action = name in {
        "yawn", "sleep_down", "startle", "game_rage", "sleep_loop", "wake_up",
        "drink_milk_tea", "read_book", "lie_phone", "walk_left", "walk_right",
        "mic_test", "cat_accident", "pc_game_rage", "pc_game_focused", "hop_bounce",
        "birthday_cake", "eat_noodles", "eat_fried_chicken", "eat_sushi",
        "eat_breakfast", "eat_bullfrog", "eat_fries",
    }
    expected_key_method = (
        "idle_protected_adaptive_green_chroma"
        if green_key_action
        else "edge_median_distance_initial"
    )
    if key_config.get("method") != expected_key_method:
        failures.append(f"{name}:key_method={key_config.get('method')}")
    if green_key_action:
        protection = key_config.get("character_protection", {})
        if protection.get("sample_source") != "processed_idle":
            failures.append(
                f"{name}:character_protection_source={protection.get('sample_source')}"
            )
        if int(protection.get("palette_bins", 0)) <= 0:
            failures.append(
                f"{name}:character_protection_palette_bins={protection.get('palette_bins')}"
            )
        profile = key_config.get("green_profile", {})
        if int(profile.get("sample_frames", 0)) <= 0:
            failures.append(f"{name}:green_profile_sample_frames={profile.get('sample_frames')}")
        palette = profile.get("background_palette_rgb", [])
        if not isinstance(palette, list) or not palette:
            failures.append(f"{name}:green_profile_palette=missing")
        soft = float(profile.get("soft_green_strength", 0.0))
        hard = float(profile.get("hard_green_strength", 0.0))
        if soft <= 0.0 or hard <= soft:
            failures.append(f"{name}:green_thresholds={soft},{hard}")
        if float(profile.get("edge_greenish_pixel_ratio", 0.0)) < 0.50:
            failures.append(
                f"{name}:green_edge_ratio={profile.get('edge_greenish_pixel_ratio')}"
            )
    transform = manifest.get("transform", {})
    scale_x = float(transform.get("scale_x", 0.0))
    scale_y = float(transform.get("scale_y", 0.0))
    if scale_x <= 0.0 or abs(scale_x - scale_y) > 1e-6:
        failures.append(f"{name}:non_uniform_scale={scale_x},{scale_y}")
    target_core = float(transform.get("target_identity_core_width", 0.0) or 0.0)
    if idle_target_core <= 0.0 or abs(target_core - idle_target_core) > 1e-6:
        failures.append(f"{name}:target_identity_core_width={target_core}")
    fit = manifest.get("canvas_fit", {})
    fit_scale = float(fit.get("scale", 0.0))
    if fit_scale <= 0.0:
        failures.append(f"{name}:missing_canvas_fit")
    elif abs(fit_scale - 1.0) > 1e-6:
        failures.append(f"{name}:canvas_auto_scaled={fit_scale}")
    hit_shape = manifest.get("hit_shape", {})
    if hit_shape.get("catalog") != "res://config/video_hit_shapes.json":
        failures.append(f"{name}:missing_hit_shape_catalog")
    if hit_shape.get("action_id") != RUNTIME_IDS[name]:
        failures.append(f"{name}:hit_shape_action={hit_shape.get('action_id')}")
    if int(hit_shape.get("frame_count", 0)) != 121:
        failures.append(f"{name}:hit_shape_frame_count={hit_shape.get('frame_count')}")

    runtime_video = manifest.get("runtime_video", {})
    video_resource = str(runtime_video.get("resource_path", ""))
    expected_resource = f"res://assets_display/wuzi_chibi/video_{name}/runtime_alpha.ogv"
    if video_resource != expected_resource:
        failures.append(f"{name}:runtime_video_resource={video_resource}")
    video_path = ROOT / "godot" / video_resource.removeprefix("res://") if video_resource else None
    if video_path is None or not video_path.is_file():
        failures.append(f"{name}:runtime_video_missing={video_resource}")
    else:
        actual_bytes = video_path.stat().st_size
        if int(runtime_video.get("bytes", 0)) != actual_bytes:
            failures.append(
                f"{name}:runtime_video_bytes={runtime_video.get('bytes')},actual={actual_bytes}"
            )
        if runtime_video.get("codec") != "theora":
            failures.append(f"{name}:runtime_video_codec={runtime_video.get('codec')}")
        if runtime_video.get("alpha_mode") != "side_by_side_rgb_alpha":
            failures.append(f"{name}:runtime_video_alpha_mode={runtime_video.get('alpha_mode')}")
        if runtime_video.get("packed_size") != [CANVAS_WIDTH * 2, CANVAS_HEIGHT]:
            failures.append(f"{name}:runtime_video_packed_size={runtime_video.get('packed_size')}")
        if runtime_video.get("display_size") != [CANVAS_WIDTH, CANVAS_HEIGHT]:
            failures.append(f"{name}:runtime_video_display_size={runtime_video.get('display_size')}")
        png_bytes = int(manifest.get("png_fallback_bytes", 0))
        if png_bytes <= 0 or png_bytes / max(1, actual_bytes) < MIN_VIDEO_COMPRESSION_RATIO:
            failures.append(f"{name}:runtime_video_compression={png_bytes}/{actual_bytes}")
        try:
            reader = imageio_ffmpeg.read_frames(str(video_path), pix_fmt="rgb24")
            metadata = next(reader)
            reader.close()
            if list(metadata.get("size", ())) != [CANVAS_WIDTH * 2, CANVAS_HEIGHT]:
                failures.append(f"{name}:decoded_video_size={metadata.get('size')}")
            decoded_frames, decoded_seconds = imageio_ffmpeg.count_frames_and_secs(str(video_path))
            if int(decoded_frames) != 121:
                failures.append(f"{name}:decoded_video_frames={decoded_frames}")
            expected_seconds = 121.0 / 12.0
            if abs(float(decoded_seconds) - expected_seconds) > 0.15:
                failures.append(f"{name}:decoded_video_duration={decoded_seconds}")
        except Exception as exc:
            failures.append(f"{name}:runtime_video_decode={exc}")

hit_catalog_path = ROOT / "godot/config/video_hit_shapes.json"
try:
    hit_catalog = json.loads(hit_catalog_path.read_text(encoding="utf-8"))
except Exception as exc:
    hit_catalog = {}
    failures.append(f"hit_shape_catalog_read={exc}")

hit_actions = hit_catalog.get("actions", {}) if isinstance(hit_catalog, dict) else {}
hit_canvas = hit_catalog.get("canvas", []) if isinstance(hit_catalog, dict) else []
if hit_canvas != [CANVAS_WIDTH, CANVAS_HEIGHT]:
    failures.append(f"hit_shape_canvas={hit_canvas}")
hit_shape_summary = {}
for name, runtime_id in RUNTIME_IDS.items():
    frames = hit_actions.get(runtime_id, [])
    if not isinstance(frames, list) or len(frames) != 121:
        failures.append(f"{runtime_id}:hit_frames={len(frames) if isinstance(frames, list) else 'invalid'}")
        continue

    point_counts = []
    invalid_frames = []
    for frame_index, polygon in enumerate(frames):
        if not isinstance(polygon, list) or len(polygon) < 6:
            invalid_frames.append(frame_index)
            continue
        point_counts.append(len(polygon))
        for point in polygon:
            if (
                not isinstance(point, list)
                or len(point) < 2
                or not (0 <= float(point[0]) < CANVAS_WIDTH)
                or not (0 <= float(point[1]) < CANVAS_HEIGHT)
            ):
                invalid_frames.append(frame_index)
                break

    if invalid_frames:
        failures.append(f"{runtime_id}:invalid_hit_frames={sorted(set(invalid_frames))[:12]}")
    hit_shape_summary[runtime_id] = {
        "frames": len(frames),
        "min_points": min(point_counts) if point_counts else 0,
        "max_points": max(point_counts) if point_counts else 0,
    }


def polygon_bbox(polygon: list) -> tuple[float, float, float, float] | None:
    if not isinstance(polygon, list) or not polygon:
        return None
    points = [point for point in polygon if isinstance(point, list) and len(point) >= 2]
    if not points:
        return None
    xs = [float(point[0]) for point in points]
    ys = [float(point[1]) for point in points]
    return (min(xs), min(ys), max(xs), max(ys))


sleep_frames = hit_actions.get("sleep_loop_video", [])
if isinstance(sleep_frames, list) and len(sleep_frames) == 121:
    sleep_boxes = [polygon_bbox(poly) for poly in sleep_frames]
    if any(box is None for box in sleep_boxes):
        failures.append("sleep_loop_video:missing_hit_bbox")
    else:
        sleep_widths = [box[2] - box[0] for box in sleep_boxes]
        sleep_heights = [box[3] - box[1] for box in sleep_boxes]
        if min(sleep_widths) < 240.0:
            failures.append(f"sleep_loop_video:hit_width_min={min(sleep_widths)}")
        if max(sleep_heights) * 1.4 >= min(sleep_widths):
            failures.append(
                f"sleep_loop_video:not_horizontal=max_h={max(sleep_heights)},min_w={min(sleep_widths)}"
            )

wake_frames = hit_actions.get("wake_up_video", [])
if isinstance(wake_frames, list) and len(wake_frames) == 121:
    wake_boxes = [polygon_bbox(poly) for poly in wake_frames]
    if any(box is None for box in wake_boxes):
        failures.append("wake_up_video:missing_hit_bbox")
    else:
        first = wake_boxes[0]
        last = wake_boxes[-1]
        first_w = first[2] - first[0]
        first_h = first[3] - first[1]
        last_w = last[2] - last[0]
        last_h = last[3] - last[1]
        if first_w < 240.0 or first_w <= first_h * 1.4:
            failures.append(f"wake_up_video:start_not_lying={first_w}x{first_h}")
        if last_h < 190.0 or last_h <= last_w * 1.1:
            failures.append(f"wake_up_video:end_not_standing={last_w}x{last_h}")

        max_width_step = 0.0
        max_height_step = 0.0
        max_center_step = 0.0
        for previous, current in zip(wake_boxes, wake_boxes[1:]):
            prev_w = previous[2] - previous[0]
            prev_h = previous[3] - previous[1]
            curr_w = current[2] - current[0]
            curr_h = current[3] - current[1]
            prev_center = ((previous[0] + previous[2]) / 2.0, (previous[1] + previous[3]) / 2.0)
            curr_center = ((current[0] + current[2]) / 2.0, (current[1] + current[3]) / 2.0)
            max_width_step = max(max_width_step, abs(curr_w - prev_w))
            max_height_step = max(max_height_step, abs(curr_h - prev_h))
            max_center_step = max(
                max_center_step,
                float(np.hypot(curr_center[0] - prev_center[0], curr_center[1] - prev_center[1])),
            )
        if max_width_step > 40.0 or max_height_step > 25.0 or max_center_step > 12.0:
            failures.append(
                "wake_up_video:hit_shape_discontinuity="
                f"width={max_width_step},height={max_height_step},center={max_center_step:.2f}"
            )

# Sleep-chain transitions must preserve the same lying character scale:
# sleep_down last frame -> sleep_loop first frame -> wake_up first frame.
sleep_down_frames = hit_actions.get("sleep_down_video", [])
sleep_loop_frames = hit_actions.get("sleep_loop_video", [])
wake_up_frames = hit_actions.get("wake_up_video", [])
if (
    isinstance(sleep_down_frames, list)
    and len(sleep_down_frames) == 121
    and isinstance(sleep_loop_frames, list)
    and len(sleep_loop_frames) == 121
    and isinstance(wake_up_frames, list)
    and len(wake_up_frames) == 121
):
    transition_boxes = [
        polygon_bbox(sleep_down_frames[-1]),
        polygon_bbox(sleep_loop_frames[0]),
        polygon_bbox(wake_up_frames[0]),
    ]
    if any(box is None for box in transition_boxes):
        failures.append("sleep_chain:missing_transition_bbox")
    else:
        transition_widths = [box[2] - box[0] for box in transition_boxes]
        if max(transition_widths) - min(transition_widths) > 3.0:
            failures.append(
                "sleep_chain:width_jump="
                + ",".join(f"{width:.1f}" for width in transition_widths)
            )
        transition_centers = [
            ((box[0] + box[2]) / 2.0, (box[1] + box[3]) / 2.0)
            for box in transition_boxes
        ]
        max_transition_center_delta = max(
            float(
                np.hypot(
                    current[0] - previous[0],
                    current[1] - previous[1],
                )
            )
            for previous, current in zip(
                transition_centers,
                transition_centers[1:],
            )
        )
        if max_transition_center_delta > 10.0:
            failures.append(
                f"sleep_chain:center_jump={max_transition_center_delta:.2f}"
            )

baseline_candidate_ids = {
    part.strip()
    for part in os.environ.get("Q_VIDEO_BASELINE_CANDIDATES", "").split(",")
    if part.strip()
}
baseline_candidates = {}
for name in sorted(baseline_candidate_ids):
    directory = EXPECTED.get(name)
    result = results.get(name, {})
    if directory is None or not result:
        continue
    hashes = {}
    for frame_name in ("000", "060", "120"):
        frame_path = directory / f"{frame_name}.png"
        if not frame_path.is_file():
            continue
        with Image.open(frame_path) as image:
            rgba_bytes = image.convert("RGBA").tobytes()
        hashes[frame_name] = hashlib.sha256(rgba_bytes).hexdigest()
    baseline_candidates[name] = {
        "current_reference_fill_ratio": result.get("reference_fill_ratio_median"),
        "rgba_sha256": hashes,
    }

if baseline_candidates:
    baseline_candidate_path = ROOT / "work/video_review/baseline_candidates.json"
    baseline_candidate_path.parent.mkdir(parents=True, exist_ok=True)
    baseline_candidate_path.write_text(
        json.dumps(baseline_candidates, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

active_videos = sorted((ROOT / "分享区/Q版/绿幕视频").glob("*.mp4"))
active_names = [p.name for p in active_videos]
expected_names = [
    "原地踏步.mp4",
    "打瞌睡.mp4",
    "点击-开心.mp4",
    "点击害羞.mp4",
    "角色自然待机动画生成.mp4",
    "打哈欠.mp4",
    "点击-傲娇生气.mp4",
    "进入睡眠.mp4",
    "鼠标拖拽.mp4",
    "被吓到.mp4",
    "打哈欠小幅度.mp4",
    "打游戏暴怒.mp4",
    "点击-打招呼.mp4",
    "睡眠惊醒.mp4",
    "睡眠循环.mp4",
    "悠闲唱歌.mp4",
    "正常打游戏.mp4",
    "坐下看书.mp4",
    "盯盘-看K线.mp4",
    "喝奶茶.mp4",
    "使用电脑工作.mp4",
    "躺下玩手机.mp4",
    "向左走.mp4",
    "向右走.mp4",
    "试麦.mp4",
    "不小心踢到猫.mp4",
    "拆卡.mp4",
    "打电脑游戏暴怒.mp4",
    "得意墨镜.mp4",
    "认真打电脑游戏.mp4",
    "原地蹦蹦跳.mp4",
    "吃生日蛋糕.mp4",
    "吃拉面.mp4",
    "吃炸鸡.mp4",
    "吃寿司.mp4",
    "吃早餐.mp4",
    "吃炒牛蛙.mp4",
    "吃薯条.mp4",
]
if active_names != sorted(expected_names):
    failures.append(f"active_video_set={active_names}")

old_dir = ROOT / "archive/cleanup_20261003/low_quality_videos"
old_names = sorted(p.name for p in old_dir.glob("*.mp4")) if old_dir.exists() else []
if len(old_names) < 2:
    failures.append("old_low_quality_videos_not_archived")

report = {
    "ok": not failures,
    "results": results,
    "active_videos": active_names,
    "archived_low_quality_videos": old_names,
    "hit_shapes": hit_shape_summary,
    "transition_consistency": transition_consistency,
    "baseline_candidates": baseline_candidates,
    "failures": failures,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
raise SystemExit(0 if not failures else 2)
