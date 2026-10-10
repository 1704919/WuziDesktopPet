   1 | from __future__ import annotations
   2 | 
   3 | import hashlib
   4 | import json
   5 | import os
   6 | from collections import deque
   7 | from pathlib import Path
   8 | 
   9 | import imageio_ffmpeg
  10 | import numpy as np
  11 | from PIL import Image, ImageFilter
  12 | 
  13 | ROOT = Path(__file__).resolve().parents[1]
  14 | VISUAL_BASELINE_PATH = ROOT / "godot/config/video_visual_baseline.json"
  15 | # Blue/pink are stable identity colors. "Pale" also covers skin/highlights and
  16 | # therefore varies more naturally across poses and expressions.
  17 | PALETTE_DELTA_LIMITS = {
  18 |     "blue": 6.0,
  19 |     "pink": 6.0,
  20 |     "pale": 25.0,
  21 | }
  22 | MIN_CANVAS_MARGIN = 8
  23 | CANVAS_WIDTH = 480
  24 | CANVAS_HEIGHT = 360
  25 | TARGET_IDLE_VISIBLE_HEIGHT = 220.0
  26 | MAX_REFERENCE_HEIGHT_DELTA = 14.0
  27 | MAX_IDENTITY_CORE_DELTA = 11.0
  28 | MAX_OPAQUE_FILL_RATIO = 0.72
  29 | MIN_VIDEO_COMPRESSION_RATIO = 2.0
  30 | 
  31 | # Cross-action transition consistency applies only to ordinary actions that
  32 | # start/end in the standing desktop-pet pose. The sleep chain has its own
  33 | # lying/standing transition rules below and must not be forced through these
  34 | # thresholds.
  35 | TRANSITION_SPECIAL_ACTION_IDS = {
  36 |     "sleep_down", "sleep_loop", "wake_up",
  37 |     "birthday_cake", "eat_noodles", "eat_fried_chicken",
  38 |     "eat_sushi", "eat_breakfast", "eat_bullfrog", "eat_fries",
  39 | }
  40 | TRANSITION_SCALE_REVIEW_RATIO = 0.03
  41 | TRANSITION_SCALE_FAIL_RATIO = 0.04
  42 | TRANSITION_CENTER_REVIEW_PX = 4.0
  43 | TRANSITION_CENTER_FAIL_PX = 8.0
  44 | TRANSITION_BOTTOM_REVIEW_PX = 3.0
  45 | TRANSITION_BOTTOM_FAIL_PX = 6.0
  46 | 
  47 | PROP_HEAVY_CORE_EXEMPT_ACTION_IDS = {"read_book", "watch_kline"}
  48 | CORE_BAND_TOP_RATIO = 0.08
  49 | CORE_BAND_BOTTOM_RATIO = 0.42
  50 | CORE_WIDTH_PERCENTILE = 75.0
  51 | 
  52 | EXPECTED = {
  53 |     "idle": ROOT / "godot/assets_display/wuzi_chibi/video_idle/frames",
  54 |     "click_happy": ROOT / "godot/assets_display/wuzi_chibi/video_click_happy/frames",
  55 |     "click_shy": ROOT / "godot/assets_display/wuzi_chibi/video_click_shy/frames",
  56 |     "march_in_place": ROOT / "godot/assets_display/wuzi_chibi/video_march_in_place/frames",
  57 |     "sleepy": ROOT / "godot/assets_display/wuzi_chibi/video_sleepy/frames",
  58 |     "yawn": ROOT / "godot/assets_display/wuzi_chibi/video_yawn/frames",
  59 |     "click_angry": ROOT / "godot/assets_display/wuzi_chibi/video_click_angry/frames",
  60 |     "sleep_down": ROOT / "godot/assets_display/wuzi_chibi/video_sleep_down/frames",
  61 |     "drag_reaction": ROOT / "godot/assets_display/wuzi_chibi/video_drag_reaction/frames",
  62 |     "startle": ROOT / "godot/assets_display/wuzi_chibi/video_startle/frames",
  63 |     "yawn_small": ROOT / "godot/assets_display/wuzi_chibi/video_yawn_small/frames",
  64 |     "game_rage": ROOT / "godot/assets_display/wuzi_chibi/video_game_rage/frames",
  65 |     "click_wave": ROOT / "godot/assets_display/wuzi_chibi/video_click_wave/frames",
  66 |     "wake_up": ROOT / "godot/assets_display/wuzi_chibi/video_wake_up/frames",
  67 |     "sleep_loop": ROOT / "godot/assets_display/wuzi_chibi/video_sleep_loop/frames",
  68 |     "sing": ROOT / "godot/assets_display/wuzi_chibi/video_sing/frames",
  69 |     "game_controller": ROOT / "godot/assets_display/wuzi_chibi/video_game_controller/frames",
  70 |     "read_book": ROOT / "godot/assets_display/wuzi_chibi/video_read_book/frames",
  71 |     "watch_kline": ROOT / "godot/assets_display/wuzi_chibi/video_watch_kline/frames",
  72 |     "drink_milk_tea": ROOT / "godot/assets_display/wuzi_chibi/video_drink_milk_tea/frames",
  73 |     "work_computer": ROOT / "godot/assets_display/wuzi_chibi/video_work_computer/frames",
  74 |     "lie_phone": ROOT / "godot/assets_display/wuzi_chibi/video_lie_phone/frames",
  75 |     "walk_left": ROOT / "godot/assets_display/wuzi_chibi/video_walk_left/frames",
  76 |     "walk_right": ROOT / "godot/assets_display/wuzi_chibi/video_walk_right/frames",
  77 |     "mic_test": ROOT / "godot/assets_display/wuzi_chibi/video_mic_test/frames",
  78 |     "cat_accident": ROOT / "godot/assets_display/wuzi_chibi/video_cat_accident/frames",
  79 |     "unbox_cards": ROOT / "godot/assets_display/wuzi_chibi/video_unbox_cards/frames",
  80 |     "pc_game_rage": ROOT / "godot/assets_display/wuzi_chibi/video_pc_game_rage/frames",
  81 |     "sunglasses_proud": ROOT / "godot/assets_display/wuzi_chibi/video_sunglasses_proud/frames",
  82 |     "pc_game_focused": ROOT / "godot/assets_display/wuzi_chibi/video_pc_game_focused/frames",
  83 |     "hop_bounce": ROOT / "godot/assets_display/wuzi_chibi/video_hop_bounce/frames",
  84 |     "birthday_cake": ROOT / "godot/assets_display/wuzi_chibi/video_birthday_cake/frames",
  85 |     "eat_noodles": ROOT / "godot/assets_display/wuzi_chibi/video_eat_noodles/frames",
  86 |     "eat_fried_chicken": ROOT / "godot/assets_display/wuzi_chibi/video_eat_fried_chicken/frames",
  87 |     "eat_sushi": ROOT / "godot/assets_display/wuzi_chibi/video_eat_sushi/frames",
  88 |     "eat_breakfast": ROOT / "godot/assets_display/wuzi_chibi/video_eat_breakfast/frames",
  89 |     "eat_bullfrog": ROOT / "godot/assets_display/wuzi_chibi/video_eat_bullfrog/frames",
  90 |     "eat_fries": ROOT / "godot/assets_display/wuzi_chibi/video_eat_fries/frames",
  91 | }
  92 | RUNTIME_IDS = {
  93 |     "idle": "idle",
  94 |     "click_happy": "click_happy_video",
  95 |     "click_shy": "click_shy_video",
  96 |     "march_in_place": "march_in_place_video",
  97 |     "sleepy": "sleepy_video",
  98 |     "yawn": "yawn_video",
  99 |     "click_angry": "click_angry_video",
 100 |     "sleep_down": "sleep_down_video",
 101 |     "drag_reaction": "drag_reaction_video",
 102 |     "startle": "startle_video",
 103 |     "yawn_small": "yawn_small_video",
 104 |     "game_rage": "game_rage_video",
 105 |     "click_wave": "click_wave_video",
 106 |     "wake_up": "wake_up_video",
 107 |     "sleep_loop": "sleep_loop_video",
 108 |     "sing": "sing_video",
 109 |     "game_controller": "game_controller_video",
 110 |     "read_book": "read_book_video",
 111 |     "watch_kline": "watch_kline_video",
 112 |     "drink_milk_tea": "drink_milk_tea_video",
 113 |     "work_computer": "work_computer_video",
 114 |     "lie_phone": "lie_phone_video",
 115 |     "walk_left": "walk_left_video",
 116 |     "walk_right": "walk_right_video",
 117 |     "mic_test": "mic_test_video",
 118 |     "cat_accident": "cat_accident_video",
 119 |     "unbox_cards": "unbox_cards",
 120 |     "pc_game_rage": "pc_game_rage",
 121 |     "sunglasses_proud": "sunglasses_proud",
 122 |     "pc_game_focused": "pc_game_focused",
 123 |     "hop_bounce": "hop_bounce",
 124 |     "birthday_cake": "birthday_cake",
 125 |     "eat_noodles": "eat_noodles",
 126 |     "eat_fried_chicken": "eat_fried_chicken",
 127 |     "eat_sushi": "eat_sushi",
 128 |     "eat_breakfast": "eat_breakfast",
 129 |     "eat_bullfrog": "eat_bullfrog",
 130 |     "eat_fries": "eat_fries",
 131 | }
 132 | 
 133 | MANIFEST_NAMES = {
 134 |     "idle": "idle_video_manifest.json",
 135 |     "click_happy": "click_happy_video_manifest.json",
 136 |     "click_shy": "click_shy_video_manifest.json",
 137 |     "march_in_place": "march_in_place_video_manifest.json",
 138 |     "sleepy": "sleepy_video_manifest.json",
 139 |     "yawn": "yawn_video_manifest.json",
 140 |     "click_angry": "click_angry_video_manifest.json",
 141 |     "sleep_down": "sleep_down_video_manifest.json",
 142 |     "drag_reaction": "drag_reaction_video_manifest.json",
 143 |     "startle": "startle_video_manifest.json",
 144 |     "yawn_small": "yawn_small_video_manifest.json",
 145 |     "game_rage": "game_rage_video_manifest.json",
 146 |     "click_wave": "click_wave_video_manifest.json",
 147 |     "wake_up": "wake_up_video_manifest.json",
 148 |     "sleep_loop": "sleep_loop_video_manifest.json",
 149 |     "sing": "sing_video_manifest.json",
 150 |     "game_controller": "game_controller_video_manifest.json",
 151 |     "read_book": "read_book_video_manifest.json",
 152 |     "watch_kline": "watch_kline_video_manifest.json",
 153 |     "drink_milk_tea": "drink_milk_tea_video_manifest.json",
 154 |     "work_computer": "work_computer_video_manifest.json",
 155 |     "lie_phone": "lie_phone_video_manifest.json",
 156 |     "walk_left": "walk_left_video_manifest.json",
 157 |     "walk_right": "walk_right_video_manifest.json",
 158 |     "mic_test": "mic_test_video_manifest.json",
 159 |     "cat_accident": "cat_accident_video_manifest.json",
 160 |     "unbox_cards": "unbox_cards_video_manifest.json",
 161 |     "pc_game_rage": "pc_game_rage_video_manifest.json",
 162 |     "sunglasses_proud": "sunglasses_proud_video_manifest.json",
 163 |     "pc_game_focused": "pc_game_focused_video_manifest.json",
 164 |     "hop_bounce": "hop_bounce_video_manifest.json",
 165 |     "birthday_cake": "birthday_cake_video_manifest.json",
 166 |     "eat_noodles": "eat_noodles_video_manifest.json",
 167 |     "eat_fried_chicken": "eat_fried_chicken_video_manifest.json",
 168 |     "eat_sushi": "eat_sushi_video_manifest.json",
 169 |     "eat_breakfast": "eat_breakfast_video_manifest.json",
 170 |     "eat_bullfrog": "eat_bullfrog_video_manifest.json",
 171 |     "eat_fries": "eat_fries_video_manifest.json",
 172 | }
 173 | 
 174 | SLEEP_LOOP_COMPONENT_GRID = (240, 180)
 175 | SLEEP_LOOP_ZZZ_KEEP_X = (105, 140)
 176 | SLEEP_LOOP_ZZZ_KEEP_Y = (90, 120)
 177 | SLEEP_LOOP_PROTECT_DILATE = 17
 178 | SLEEP_LOOP_WATERMARK_X = (328, 376)
 179 | SLEEP_LOOP_WATERMARK_Y = (319, 330)
 180 | SLEEP_LOOP_WATERMARK_RGB_MIN = 105
 181 | SLEEP_LOOP_WATERMARK_CHROMA_MAX = 45
 182 | SLEEP_LOOP_WATERMARK_WARM_RGB_MIN = 150
 183 | SLEEP_LOOP_WATERMARK_WARM_CHROMA_MAX = 35
 184 | 
 185 | 
 186 | def sleep_loop_residual_outside_protection(alpha: np.ndarray) -> dict | None:
 187 |     grid_w, grid_h = SLEEP_LOOP_COMPONENT_GRID
 188 |     grid = (
 189 |         np.array(
 190 |             Image.fromarray(
 191 |                 (alpha >= 72).astype(np.uint8) * 255,
 192 |                 "L",
 193 |             ).resize(
 194 |                 (grid_w, grid_h),
 195 |                 Image.Resampling.NEAREST,
 196 |             ),
 197 |             dtype=np.uint8,
 198 |         )
 199 |         > 0
 200 |     )
 201 |     visited = np.zeros_like(grid, dtype=bool)
 202 |     components: list[list[tuple[int, int]]] = []
 203 |     for y in range(grid_h):
 204 |         for x in range(grid_w):
 205 |             if not grid[y, x] or visited[y, x]:
 206 |                 continue
 207 |             queue: deque[tuple[int, int]] = deque([(y, x)])
 208 |             visited[y, x] = True
 209 |             pixels: list[tuple[int, int]] = []
 210 |             while queue:
 211 |                 cy, cx = queue.popleft()
 212 |                 pixels.append((cy, cx))
 213 |                 for ny, nx in (
 214 |                     (cy - 1, cx),
 215 |                     (cy + 1, cx),
 216 |                     (cy, cx - 1),
 217 |                     (cy, cx + 1),
 218 |                 ):
 219 |                     if (
 220 |                         0 <= ny < grid_h
 221 |                         and 0 <= nx < grid_w
 222 |                         and grid[ny, nx]
 223 |                         and not visited[ny, nx]
 224 |                     ):
 225 |                         visited[ny, nx] = True
 226 |                         queue.append((ny, nx))
 227 |             components.append(pixels)
 228 | 
 229 |     if not components:
 230 |         return None
 231 | 
 232 |     main_index = max(range(len(components)), key=lambda idx: len(components[idx]))
 233 |     protected_grid = np.zeros((grid_h, grid_w), dtype=np.uint8)
 234 |     for py, px in components[main_index]:
 235 |         protected_grid[py, px] = 255
 236 | 
 237 |     x1, x2 = SLEEP_LOOP_ZZZ_KEEP_X
 238 |     y1, y2 = SLEEP_LOOP_ZZZ_KEEP_Y
 239 |     protected_grid[y1:y2, x1:x2] = 255
 240 | 
 241 |     protected = Image.fromarray(protected_grid, "L").resize(
 242 |         (alpha.shape[1], alpha.shape[0]),
 243 |         Image.Resampling.NEAREST,
 244 |     )
 245 |     protected = protected.filter(
 246 |         ImageFilter.MaxFilter(SLEEP_LOOP_PROTECT_DILATE)
 247 |     )
 248 |     keep = np.array(protected, dtype=np.uint8) > 0
 249 |     residual = (alpha > 0) & (~keep)
 250 |     if not np.any(residual):
 251 |         return None
 252 | 
 253 |     ys, xs = np.where(residual)
 254 |     return {
 255 |         "pixels": int(len(xs)),
 256 |         "max_alpha": int(alpha[residual].max()),
 257 |         "bbox": [
 258 |             int(xs.min()),
 259 |             int(ys.min()),
 260 |             int(xs.max() + 1),
 261 |             int(ys.max() + 1),
 262 |         ],
 263 |     }
 264 | 
 265 | 
 266 | def semantic_palette(files: list[Path]) -> dict[str, list[float]]:
 267 |     groups: dict[str, list[np.ndarray]] = {
 268 |         "blue": [],
 269 |         "pink": [],
 270 |         "pale": [],
 271 |     }
 272 |     for path in files[:18]:
 273 |         rgba = np.array(Image.open(path).convert("RGBA"), dtype=np.uint8)
 274 |         rgb = rgba[..., :3].astype(np.float32)
 275 |         alpha = rgba[..., 3]
 276 |         pixels = rgb[alpha >= 220]
 277 |         if not len(pixels):
 278 |             continue
 279 |         pixels = pixels[np.max(pixels, axis=1) >= 45]
 280 |         blue = pixels[
 281 |             (pixels[:, 2] > pixels[:, 0] * 1.10)
 282 |             & (pixels[:, 2] > pixels[:, 1] * 1.05)
 283 |             & (pixels[:, 2] > 80)
 284 |         ]
 285 |         pink = pixels[
 286 |             (pixels[:, 0] > pixels[:, 1] * 1.18)
 287 |             & (pixels[:, 0] > pixels[:, 2] * 1.03)
 288 |             & (pixels[:, 0] > 90)
 289 |         ]
 290 |         pale = pixels[
 291 |             (pixels[:, 0] > 150)
 292 |             & (pixels[:, 1] > 120)
 293 |             & (pixels[:, 2] > 120)
 294 |         ]
 295 |         if len(blue):
 296 |             groups["blue"].append(blue)
 297 |         if len(pink):
 298 |             groups["pink"].append(pink)
 299 |         if len(pale):
 300 |             groups["pale"].append(pale)
 301 | 
 302 |     result: dict[str, list[float]] = {}
 303 |     for label, chunks in groups.items():
 304 |         if not chunks:
 305 |             continue
 306 |         merged = np.concatenate(chunks, axis=0)
 307 |         result[label] = [float(x) for x in np.mean(merged, axis=0)]
 308 |     return result
 309 | 
 310 | 
 311 | def largest_true_run(row: np.ndarray) -> int:
 312 |     padded = np.pad(row.astype(np.int8), (1, 1), constant_values=0)
 313 |     changes = np.diff(padded)
 314 |     starts = np.where(changes == 1)[0]
 315 |     ends = np.where(changes == -1)[0]
 316 |     if not len(starts):
 317 |         return 0
 318 |     return int(np.max(ends - starts))
 319 | 
 320 | 
 321 | def identity_core_width(alpha: np.ndarray) -> float | None:
 322 |     ys, xs = np.where(alpha >= 72)
 323 |     if not len(xs):
 324 |         return None
 325 |     x1, y1, x2, y2 = int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)
 326 |     height = max(1, y2 - y1)
 327 |     band_y1 = max(y1, round(y1 + height * CORE_BAND_TOP_RATIO))
 328 |     band_y2 = min(y2, round(y1 + height * CORE_BAND_BOTTOM_RATIO))
 329 |     if band_y2 <= band_y1:
 330 |         return None
 331 |     mask = alpha >= 72
 332 |     widths = [largest_true_run(mask[y, x1:x2]) for y in range(band_y1, band_y2)]
 333 |     widths = [width for width in widths if width > 0]
 334 |     if not widths:
 335 |         return None
 336 |     return float(np.percentile(widths, CORE_WIDTH_PERCENTILE))
 337 | 
 338 | 
 339 | def transition_frame_metrics(path: Path) -> dict | None:
 340 |     if not path.is_file():
 341 |         return None
 342 |     with Image.open(path) as image:
 343 |         alpha = np.array(image.convert("RGBA"), dtype=np.uint8)[..., 3]
 344 |     ys, xs = np.where(alpha >= 72)
 345 |     if not len(xs):
 346 |         return None
 347 |     x1, y1 = int(xs.min()), int(ys.min())
 348 |     x2, y2 = int(xs.max() + 1), int(ys.max() + 1)
 349 |     core_width = identity_core_width(alpha)
 350 |     return {
 351 |         "bbox": [x1, y1, x2, y2],
 352 |         "height_px": float(y2 - y1),
 353 |         "width_px": float(x2 - x1),
 354 |         "center_x_px": float((x1 + x2) / 2.0),
 355 |         "bottom_y_px": float(y2),
 356 |         "identity_core_width_px": core_width,
 357 |     }
 358 | 
 359 | 
 360 | failures = []
 361 | results = {}
 362 | manifests = {}
 363 | 
 364 | try:
 365 |     visual_baseline = json.loads(VISUAL_BASELINE_PATH.read_text(encoding="utf-8"))
 366 | except Exception as exc:
 367 |     visual_baseline = {}
 368 |     failures.append(f"visual_baseline_read={exc}")
 369 | 
 370 | known_pending_cleanup = visual_baseline.get("known_pending_individual_cleanup", {})
 371 | if not isinstance(known_pending_cleanup, dict):
 372 |     known_pending_cleanup = {}
 373 | 
 374 | for name, directory in EXPECTED.items():
 375 |     manifest_path = ROOT / "godot/config" / MANIFEST_NAMES[name]
 376 |     try:
 377 |         manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
 378 |         manifests[name] = manifest
 379 |     except Exception as exc:
 380 |         failures.append(f"{name}:manifest_read={exc}")
 381 |         manifest = {}
 382 | 
 383 |     canvas = manifest.get("canvas", [0, 0])
 384 |     if not isinstance(canvas, list) or len(canvas) < 2:
 385 |         failures.append(f"{name}:canvas={canvas}")
 386 |         expected_width, expected_height = CANVAS_WIDTH, CANVAS_HEIGHT
 387 |     else:
 388 |         expected_width, expected_height = int(canvas[0]), int(canvas[1])
 389 |     if (expected_width, expected_height) != (CANVAS_WIDTH, CANVAS_HEIGHT):
 390 |         failures.append(f"{name}:canvas={expected_width}x{expected_height}")
 391 | 
 392 |     files = sorted(directory.glob("*.png"))
 393 |     if len(files) != 121:
 394 |         failures.append(f"{name}:frame_count={len(files)}")
 395 |     min_margin = 999
 396 |     edge_hits = []
 397 |     nonempty = 0
 398 |     reference_heights = []
 399 |     reference_widths = []
 400 |     reference_fill_ratios = []
 401 |     reference_core_widths = []
 402 |     for i, path in enumerate(files):
 403 |         with Image.open(path) as im:
 404 |             if im.size != (expected_width, expected_height):
 405 |                 failures.append(f"{name}:{path.name}:size={im.size}")
 406 |                 continue
 407 |             rgba_frame = np.array(im.convert("RGBA"), dtype=np.uint8)
 408 |             alpha = rgba_frame[..., 3]
 409 |         if name == "sleep_loop":
 410 |             residual = sleep_loop_residual_outside_protection(alpha)
 411 |             if residual is not None:
 412 |                 failures.append(
 413 |                     f"sleep_loop:{path.name}:residual_outside_protection={residual}"
 414 |                 )
 415 | 
 416 |             x1, x2 = SLEEP_LOOP_WATERMARK_X
 417 |             y1, y2 = SLEEP_LOOP_WATERMARK_Y
 418 |             region = rgba_frame[y1:y2, x1:x2]
 419 |             if region.size:
 420 |                 rgb = region[..., :3].astype(np.int16)
 421 |                 alpha_region = region[..., 3]
 422 |                 minimum = np.min(rgb, axis=2)
 423 |                 maximum = np.max(rgb, axis=2)
 424 |                 r = rgb[..., 0]
 425 |                 g = rgb[..., 1]
 426 |                 b = rgb[..., 2]
 427 |                 cool_neutral = (
 428 |                     (minimum >= SLEEP_LOOP_WATERMARK_RGB_MIN)
 429 |                     & ((maximum - minimum) <= SLEEP_LOOP_WATERMARK_CHROMA_MAX)
 430 |                     & (g >= r - 8)
 431 |                     & (b >= r - 8)
 432 |                 )
 433 |                 warm_neutral = (
 434 |                     (minimum >= SLEEP_LOOP_WATERMARK_WARM_RGB_MIN)
 435 |                     & (
 436 |                         (maximum - minimum)
 437 |                         <= SLEEP_LOOP_WATERMARK_WARM_CHROMA_MAX
 438 |                     )
 439 |                 )
 440 |                 watermark_like = (alpha_region > 0) & (
 441 |                     cool_neutral | warm_neutral
 442 |                 )
 443 |                 if np.any(watermark_like):
 444 |                     failures.append(
 445 |                         f"sleep_loop:{path.name}:local_watermark_residual="
 446 |                         f"{int(np.sum(watermark_like))}"
 447 |                     )
 448 |         ys, xs = np.where(alpha >= 72)
 449 |         if not len(xs):
 450 |             failures.append(f"{name}:{path.name}:empty")
 451 |             continue
 452 |         nonempty += 1
 453 |         bbox = (int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1))
 454 |         if i < 12:
 455 |             reference_heights.append(bbox[3] - bbox[1])
 456 |             reference_widths.append(bbox[2] - bbox[0])
 457 |             crop = alpha[bbox[1]:bbox[3], bbox[0]:bbox[2]]
 458 |             reference_fill_ratios.append(float(np.mean(crop >= 72)))
 459 |             core_width = identity_core_width(alpha)
 460 |             if core_width is not None:
 461 |                 reference_core_widths.append(core_width)
 462 |         margin = min(
 463 |             bbox[0],
 464 |             bbox[1],
 465 |             expected_width - bbox[2],
 466 |             expected_height - bbox[3],
 467 |         )
 468 |         min_margin = min(min_margin, margin)
 469 |         if margin < MIN_CANVAS_MARGIN:
 470 |             edge_hits.append(i)
 471 |     if edge_hits:
 472 |         failures.append(f"{name}:edge_hits={edge_hits[:12]}")
 473 |     reference_height_median = float(np.median(reference_heights)) if reference_heights else None
 474 |     reference_width_median = float(np.median(reference_widths)) if reference_widths else None
 475 |     reference_fill_median = float(np.median(reference_fill_ratios)) if reference_fill_ratios else None
 476 |     reference_core_median = float(np.median(reference_core_widths)) if reference_core_widths else None
 477 |     allow_height_mismatch = bool(
 478 |         (known_pending_cleanup.get(name, {}) or {}).get(
 479 |             "allow_reference_height_mismatch",
 480 |             False,
 481 |         )
 482 |     )
 483 |     sleep_chain_action = name in {"sleep_down", "sleep_loop", "wake_up"}
 484 |     transform = manifest.get("transform", {}) if isinstance(manifest, dict) else {}
 485 |     fit = manifest.get("canvas_fit", {}) if isinstance(manifest, dict) else {}
 486 |     fit_scale = float(fit.get("scale", 1.0) or 1.0)
 487 |     target_height = float(transform.get("target_visible_height", 0.0) or 0.0) * fit_scale
 488 |     target_core_width = float(transform.get("target_identity_core_width", 0.0) or 0.0) * fit_scale
 489 |     visual_norm = manifest.get("visual_scale_normalization", {}) if isinstance(manifest, dict) else {}
 490 |     visual_mode = str(visual_norm.get("mode", ""))
 491 |     visual_multiplier = float(visual_norm.get("multiplier_median", 1.0) or 1.0)
 492 |     effective_target_height = target_height * visual_multiplier
 493 |     effective_target_core_width = target_core_width * visual_multiplier
 494 | 
 495 |     if name == "idle" and abs(target_height - TARGET_IDLE_VISIBLE_HEIGHT) > 1e-6:
 496 |         failures.append(f"idle:target_visible_height={target_height}")
 497 | 
 498 |     if reference_fill_median is not None and reference_fill_median > MAX_OPAQUE_FILL_RATIO:
 499 |         failures.append(f"{name}:opaque_fill_ratio={reference_fill_median:.3f}")
 500 |     results[name] = {
 501 |         "frames": len(files),
 502 |         "nonempty": nonempty,
 503 |         "min_margin_px": None if min_margin == 999 else min_margin,
 504 |         "reference_height_median_px": reference_height_median,
 505 |         "reference_width_median_px": reference_width_median,
 506 |         "reference_identity_core_width_median_px": reference_core_median,
 507 |         "reference_fill_ratio_median": reference_fill_median,
 508 |         "semantic_palette": semantic_palette(files),
 509 |     }
 510 | 
 511 | idle_reference_height = results.get("idle", {}).get("reference_height_median_px")
 512 | idle_reference_core = results.get("idle", {}).get("reference_identity_core_width_median_px")
 513 | for name, result in results.items():
 514 |     if name in {"sleep_down", "sleep_loop", "wake_up"}:
 515 |         continue
 516 |     allow_height_mismatch = bool(
 517 |         (known_pending_cleanup.get(name, {}) or {}).get(
 518 |             "allow_reference_height_mismatch",
 519 |             False,
 520 |         )
 521 |     )
 522 |     reference_height = result.get("reference_height_median_px")
 523 |     reference_core = result.get("reference_identity_core_width_median_px")
 524 |     if (
 525 |         name not in PROP_HEAVY_CORE_EXEMPT_ACTION_IDS
 526 |         and not allow_height_mismatch
 527 |         and idle_reference_height is not None
 528 |         and reference_height is not None
 529 |         and abs(float(reference_height) - float(idle_reference_height))
 530 |         > MAX_REFERENCE_HEIGHT_DELTA
 531 |     ):
 532 |         failures.append(
 533 |             f"{name}:standing_height_delta="
 534 |             f"{float(reference_height) - float(idle_reference_height):.2f}"
 535 |         )
 536 |     if (
 537 |         name not in PROP_HEAVY_CORE_EXEMPT_ACTION_IDS
 538 |         and idle_reference_core is not None
 539 |         and reference_core is not None
 540 |         and abs(float(reference_core) - float(idle_reference_core))
 541 |         > MAX_IDENTITY_CORE_DELTA
 542 |     ):
 543 |         failures.append(
 544 |             f"{name}:standing_core_delta="
 545 |             f"{float(reference_core) - float(idle_reference_core):.2f}"
 546 |         )
 547 | 
 548 | strict_transition_mode = os.environ.get(
 549 |     "Q_VIDEO_STRICT_TRANSITIONS",
 550 |     "",
 551 | ).strip().lower() in {"1", "true", "yes", "on"}
 552 | 
 553 | transition_reviews: list[str] = []
 554 | transition_strict_failures: list[str] = []
 555 | transition_actions: dict[str, dict] = {}
 556 | 
 557 | idle_manifest = manifests.get("idle", {})
 558 | idle_transform = idle_manifest.get("transform", {}) if isinstance(idle_manifest, dict) else {}
 559 | idle_fit = idle_manifest.get("canvas_fit", {}) if isinstance(idle_manifest, dict) else {}
 560 | idle_visual_norm = (
 561 |     idle_manifest.get("visual_scale_normalization", {})
 562 |     if isinstance(idle_manifest, dict)
 563 |     else {}
 564 | )
 565 | idle_effective_height = (
 566 |     float(idle_transform.get("target_visible_height", 0.0) or 0.0)
 567 |     * float(idle_fit.get("scale", 1.0) or 1.0)
 568 |     * float(idle_visual_norm.get("multiplier_median", 1.0) or 1.0)
 569 | )
 570 | idle_endpoints = {
 571 |     frame_name: transition_frame_metrics(EXPECTED["idle"] / f"{frame_name}.png")
 572 |     for frame_name in ("000", "120")
 573 | }
 574 | 
 575 | for name, directory in EXPECTED.items():
 576 |     if name == "idle" or name in TRANSITION_SPECIAL_ACTION_IDS:
 577 |         continue
 578 | 
 579 |     manifest = manifests.get(name, {})
 580 |     transform = manifest.get("transform", {}) if isinstance(manifest, dict) else {}
 581 |     fit = manifest.get("canvas_fit", {}) if isinstance(manifest, dict) else {}
 582 |     visual_norm = (
 583 |         manifest.get("visual_scale_normalization", {})
 584 |         if isinstance(manifest, dict)
 585 |         else {}
 586 |     )
 587 |     effective_height = (
 588 |         float(transform.get("target_visible_height", 0.0) or 0.0)
 589 |         * float(fit.get("scale", 1.0) or 1.0)
 590 |         * float(visual_norm.get("multiplier_median", 1.0) or 1.0)
 591 |     )
 592 |     scale_delta_ratio = (
 593 |         (effective_height / idle_effective_height) - 1.0
 594 |         if idle_effective_height > 0.0 and effective_height > 0.0
 595 |         else None
 596 |     )
 597 | 
 598 |     action_reviews: list[str] = []
 599 |     action_failures: list[str] = []
 600 |     endpoint_results: dict[str, dict] = {}
 601 | 
 602 |     if scale_delta_ratio is not None:
 603 |         if abs(scale_delta_ratio) >= TRANSITION_SCALE_REVIEW_RATIO:
 604 |             # Manifest target height is useful context, but props/pose envelopes
 605 |             # can make it disagree with the actual standing endpoint. Keep it as
 606 |             # review-only; strict gating is based on rendered 000/120 frames.
 607 |             reason = f"manifest_scale_delta={scale_delta_ratio * 100.0:+.2f}%"
 608 |             action_reviews.append(reason)
 609 | 
 610 |     for frame_name in ("000", "120"):
 611 |         current = transition_frame_metrics(directory / f"{frame_name}.png")
 612 |         reference = idle_endpoints.get(frame_name)
 613 |         if current is None or reference is None:
 614 |             action_failures.append(f"{frame_name}:missing_endpoint_metrics")
 615 |             continue
 616 | 
 617 |         height_delta_ratio = (
 618 |             (float(current["height_px"]) / float(reference["height_px"])) - 1.0
 619 |             if float(reference["height_px"]) > 0.0
 620 |             else 0.0
 621 |         )
 622 |         center_delta = (
 623 |             float(current["center_x_px"]) - float(reference["center_x_px"])
 624 |         )
 625 |         bottom_delta = (
 626 |             float(current["bottom_y_px"]) - float(reference["bottom_y_px"])
 627 |         )
 628 |         core_delta_ratio = None
 629 |         if (
 630 |             current.get("identity_core_width_px") is not None
 631 |             and reference.get("identity_core_width_px") is not None
 632 |             and float(reference["identity_core_width_px"]) > 0.0
 633 |         ):
 634 |             core_delta_ratio = (
 635 |                 float(current["identity_core_width_px"])
 636 |                 / float(reference["identity_core_width_px"])
 637 |             ) - 1.0
 638 | 
 639 |         endpoint_results[frame_name] = {
 640 |             "height_px": current["height_px"],
 641 |             "height_delta_ratio": height_delta_ratio,
 642 |             "center_x_px": current["center_x_px"],
 643 |             "center_delta_px": center_delta,
 644 |             "bottom_y_px": current["bottom_y_px"],
 645 |             "bottom_delta_px": bottom_delta,
 646 |             "identity_core_width_px": current.get("identity_core_width_px"),
 647 |             "identity_core_delta_ratio": core_delta_ratio,
 648 |         }
 649 | 
 650 |         if abs(height_delta_ratio) >= TRANSITION_SCALE_REVIEW_RATIO:
 651 |             action_reviews.append(
 652 |                 f"{frame_name}:height_delta={height_delta_ratio * 100.0:+.2f}%"
 653 |             )
 654 |         if abs(height_delta_ratio) > TRANSITION_SCALE_FAIL_RATIO:
 655 |             action_failures.append(
 656 |                 f"{frame_name}:height_delta={height_delta_ratio * 100.0:+.2f}%"
 657 |             )
 658 | 
 659 |         if abs(center_delta) >= TRANSITION_CENTER_REVIEW_PX:
 660 |             action_reviews.append(
 661 |                 f"{frame_name}:center_delta={center_delta:+.1f}px"
 662 |             )
 663 |         if abs(center_delta) > TRANSITION_CENTER_FAIL_PX:
 664 |             action_failures.append(
 665 |                 f"{frame_name}:center_delta={center_delta:+.1f}px"
 666 |             )
 667 | 
 668 |         if abs(bottom_delta) >= TRANSITION_BOTTOM_REVIEW_PX:
 669 |             action_reviews.append(
 670 |                 f"{frame_name}:bottom_delta={bottom_delta:+.1f}px"
 671 |             )
 672 |         if abs(bottom_delta) > TRANSITION_BOTTOM_FAIL_PX:
 673 |             action_failures.append(
 674 |                 f"{frame_name}:bottom_delta={bottom_delta:+.1f}px"
 675 |             )
 676 | 
 677 |     transition_actions[name] = {
 678 |         "effective_target_height_px": effective_height,
 679 |         "scale_delta_ratio": scale_delta_ratio,
 680 |         "target_center_x": float(
 681 |             transform.get("target_center_x", CANVAS_WIDTH / 2.0)
 682 |         ),
 683 |         "endpoints": endpoint_results,
 684 |         "reviews": action_reviews,
 685 |         "strict_failures": action_failures,
 686 |     }
 687 | 
 688 |     transition_reviews.extend(
 689 |         f"{name}:{reason}" for reason in action_reviews
 690 |     )
 691 |     transition_strict_failures.extend(
 692 |         f"{name}:{reason}" for reason in action_failures
 693 |     )
 694 | 
 695 | transition_consistency = {
 696 |     "strict_mode": strict_transition_mode,
 697 |     "excluded_special_actions": sorted(TRANSITION_SPECIAL_ACTION_IDS),
 698 |     "thresholds": {
 699 |         "scale_review_ratio": TRANSITION_SCALE_REVIEW_RATIO,
 700 |         "scale_fail_ratio": TRANSITION_SCALE_FAIL_RATIO,
 701 |         "center_review_px": TRANSITION_CENTER_REVIEW_PX,
 702 |         "center_fail_px": TRANSITION_CENTER_FAIL_PX,
 703 |         "bottom_review_px": TRANSITION_BOTTOM_REVIEW_PX,
 704 |         "bottom_fail_px": TRANSITION_BOTTOM_FAIL_PX,
 705 |     },
 706 |     "idle_reference": {
 707 |         "effective_target_height_px": idle_effective_height,
 708 |         "endpoints": idle_endpoints,
 709 |     },
 710 |     "actions": transition_actions,
 711 |     "reviews": transition_reviews,
 712 |     "strict_failures": transition_strict_failures,
 713 | }
 714 | 
 715 | if strict_transition_mode:
 716 |     failures.extend(
 717 |         f"transition:{item}" for item in transition_strict_failures
 718 |     )
 719 | 
 720 | if int(visual_baseline.get("schema_version", 0)) < 3:
 721 |     failures.append(f"visual_baseline_schema={visual_baseline.get('schema_version')}")
 722 | 
 723 | baseline_fill = visual_baseline.get("min_reference_fill_ratio", {})
 724 | baseline_hashes = visual_baseline.get("rgba_sha256", {})
 725 | for name, directory in EXPECTED.items():
 726 |     current_fill = results.get(name, {}).get("reference_fill_ratio_median")
 727 |     minimum_fill = baseline_fill.get(name)
 728 |     if minimum_fill is None:
 729 |         failures.append(f"{name}:missing_min_fill_baseline")
 730 |     elif current_fill is None or float(current_fill) < float(minimum_fill):
 731 |         failures.append(
 732 |             f"{name}:reference_fill_ratio={current_fill},min={minimum_fill}"
 733 |         )
 734 | 
 735 |     action_hashes = baseline_hashes.get(name)
 736 |     if not isinstance(action_hashes, dict):
 737 |         failures.append(f"{name}:missing_rgba_visual_baseline")
 738 |         continue
 739 |     checked_hashes = {}
 740 |     for frame_name, expected_hash in action_hashes.items():
 741 |         frame_path = directory / f"{frame_name}.png"
 742 |         if not frame_path.is_file():
 743 |             failures.append(f"{name}:missing_visual_frame={frame_name}")
 744 |             continue
 745 |         with Image.open(frame_path) as im:
 746 |             rgba_bytes = im.convert("RGBA").tobytes()
 747 |         actual_hash = hashlib.sha256(rgba_bytes).hexdigest()
 748 |         checked_hashes[frame_name] = actual_hash
 749 |         if actual_hash != expected_hash:
 750 |             failures.append(
 751 |                 f"{name}:rgba_visual_hash[{frame_name}]={actual_hash}"
 752 |             )
 753 |     results[name]["visual_baseline_hashes"] = checked_hashes
 754 | 
 755 | idle_palette = results.get("idle", {}).get("semantic_palette", {})
 756 | for name, result in results.items():
 757 |     if name in {"idle", "wake_up"}:
 758 |         # The replacement wake-up source colour is explicitly approved as-is.
 759 |         # Do not fail it for not matching the idle palette; its colour correction
 760 |         # MUST be disabled, which is verified via manifest below.
 761 |         continue
 762 |     palette = result.get("semantic_palette", {})
 763 |     for label in ("blue", "pink", "pale"):
 764 |         if label not in idle_palette or label not in palette:
 765 |             failures.append(f"{name}:missing_palette_group={label}")
 766 |             continue
 767 |         delta = np.abs(
 768 |             np.array(palette[label], dtype=np.float32)
 769 |             - np.array(idle_palette[label], dtype=np.float32)
 770 |         )
 771 |         if float(np.max(delta)) > PALETTE_DELTA_LIMITS[label]:
 772 |             failures.append(
 773 |                 f"{name}:{label}_color_delta={delta.round(2).tolist()}"
 774 |             )
 775 | 
 776 | # Pose width is expected to change (arms, pillow, lying pose). Character scale is
 777 | # validated against idle's upper-body/head identity core and uniform X/Y transforms.
 778 | idle_target_core = float(
 779 |     manifests.get("idle", {}).get("transform", {}).get("target_identity_core_width", 0.0) or 0.0
 780 | )
 781 | for name, manifest_name in MANIFEST_NAMES.items():
 782 |     manifest = manifests.get(name, {})
 783 |     if not manifest:
 784 |         continue
 785 |     if int(manifest.get("schema_version", 0)) < 10:
 786 |         failures.append(f"{name}:manifest_schema={manifest.get('schema_version')}")
 787 | 
 788 |     visual_norm = manifest.get("visual_scale_normalization", {})
 789 |     expected_visual_mode = (
 790 |         "idle_reference"
 791 |         if name == "idle"
 792 |         else (
 793 |             "sleep_chain_fixed_source"
 794 |             if name == "wake_up"
 795 |             else (
 796 |                 "sleep_chain_fixed"
 797 |                 if name in {"sleep_down", "sleep_loop"}
 798 |                 else "fixed_action_face_height"
 799 |             )
 800 |         )
 801 |     )
 802 |     if visual_norm.get("mode") != expected_visual_mode:
 803 |         failures.append(
 804 |             f"{name}:visual_scale_mode={visual_norm.get('mode')},expected={expected_visual_mode}"
 805 |         )
 806 |     target_face_height = float(visual_norm.get("target_face_height", 0.0) or 0.0)
 807 |     if target_face_height <= 0.0:
 808 |         failures.append(f"{name}:target_face_height={target_face_height}")
 809 |     multiplier_min = float(visual_norm.get("multiplier_min", 0.0) or 0.0)
 810 |     multiplier_max = float(visual_norm.get("multiplier_max", 0.0) or 0.0)
 811 |     if multiplier_min <= 0.0 or multiplier_max <= 0.0 or multiplier_min > multiplier_max:
 812 |         failures.append(
 813 |             f"{name}:visual_scale_range={multiplier_min},{multiplier_max}"
 814 |         )
 815 |     if expected_visual_mode == "fixed_action_face_height":
 816 |         if abs(multiplier_min - 1.0) > 1e-6 or abs(multiplier_max - 1.0) > 1e-6:
 817 |             failures.append(
 818 |                 f"{name}:per_frame_scale_detected={multiplier_min},{multiplier_max}"
 819 |             )
 820 | 
 821 |     transform = manifest.get("transform", {})
 822 |     if name == "click_happy":
 823 |         if abs(float(transform.get("manual_scale_multiplier", 0.0)) - 0.96) > 1e-6:
 824 |             failures.append(
 825 |                 f"click_happy:manual_scale_multiplier={transform.get('manual_scale_multiplier')}"
 826 |             )
 827 |     if name == "drag_reaction":
 828 |         if abs(float(transform.get("manual_scale_multiplier", 0.0)) - 1.10) > 1e-6:
 829 |             failures.append(
 830 |                 f"drag_reaction:manual_scale_multiplier={transform.get('manual_scale_multiplier')}"
 831 |             )
 832 |     if name == "wake_up":
 833 |         if "scale_curve" in transform:
 834 |             failures.append("wake_up:obsolete_scale_curve_present")
 835 |         if transform.get("layout_mode") != "wake_fixed_source_scale":
 836 |             failures.append("wake_up:expected_fixed_source_scale")
 837 |         start_scale = float(transform.get("start_scale", 0.0) or 0.0)
 838 |         end_scale = float(transform.get("end_scale", 0.0) or 0.0)
 839 |         if start_scale <= 0.0 or abs(end_scale - start_scale) > 1e-6:
 840 |             failures.append("wake_up:non_fixed_source_scale")
 841 |         normal = manifest.get("color_normalization", {})
 842 |         if normal.get("reference_action") != "none_source_video_preserved":
 843 |             failures.append("wake_up:source_colours_not_preserved")
 844 |         if normal.get("correction", {}).get("enabled", True):
 845 |             failures.append("wake_up:recolouring_enabled")
 846 |         if normal.get("semantic_deltas"):
 847 |             failures.append("wake_up:semantic_recolouring_detected")
 848 |         if manifest.get("skin_tone_endpoint_correction"):
 849 |             failures.append("wake_up:skin_tone_override_present")
 850 |         if normal.get("source_palette") != normal.get("corrected_palette"):
 851 |             failures.append("wake_up:source_palette_modified")
 852 |     key_config = manifest.get("key", {})
 853 |     green_key_action = name in {
 854 |         "yawn", "sleep_down", "startle", "game_rage", "sleep_loop", "wake_up",
 855 |         "drink_milk_tea", "read_book", "lie_phone", "walk_left", "walk_right",
 856 |         "mic_test", "cat_accident", "pc_game_rage", "pc_game_focused", "hop_bounce",
 857 |         "birthday_cake", "eat_noodles", "eat_fried_chicken", "eat_sushi",
 858 |         "eat_breakfast", "eat_bullfrog", "eat_fries",
 859 |     }
 860 |     expected_key_method = (
 861 |         "idle_protected_adaptive_green_chroma"
 862 |         if green_key_action
 863 |         else "edge_median_distance_initial"
 864 |     )
 865 |     if key_config.get("method") != expected_key_method:
 866 |         failures.append(f"{name}:key_method={key_config.get('method')}")
 867 |     if green_key_action:
 868 |         protection = key_config.get("character_protection", {})
 869 |         if protection.get("sample_source") != "processed_idle":
 870 |             failures.append(
 871 |                 f"{name}:character_protection_source={protection.get('sample_source')}"
 872 |             )
 873 |         if int(protection.get("palette_bins", 0)) <= 0:
 874 |             failures.append(
 875 |                 f"{name}:character_protection_palette_bins={protection.get('palette_bins')}"
 876 |             )
 877 |         profile = key_config.get("green_profile", {})
 878 |         if int(profile.get("sample_frames", 0)) <= 0:
 879 |             failures.append(f"{name}:green_profile_sample_frames={profile.get('sample_frames')}")
 880 |         palette = profile.get("background_palette_rgb", [])
 881 |         if not isinstance(palette, list) or not palette:
 882 |             failures.append(f"{name}:green_profile_palette=missing")
 883 |         soft = float(profile.get("soft_green_strength", 0.0))
 884 |         hard = float(profile.get("hard_green_strength", 0.0))
 885 |         if soft <= 0.0 or hard <= soft:
 886 |             failures.append(f"{name}:green_thresholds={soft},{hard}")
 887 |         if float(profile.get("edge_greenish_pixel_ratio", 0.0)) < 0.50:
 888 |             failures.append(
 889 |                 f"{name}:green_edge_ratio={profile.get('edge_greenish_pixel_ratio')}"
 890 |             )
 891 |     transform = manifest.get("transform", {})
 892 |     scale_x = float(transform.get("scale_x", 0.0))
 893 |     scale_y = float(transform.get("scale_y", 0.0))
 894 |     if scale_x <= 0.0 or abs(scale_x - scale_y) > 1e-6:
 895 |         failures.append(f"{name}:non_uniform_scale={scale_x},{scale_y}")
 896 |     target_core = float(transform.get("target_identity_core_width", 0.0) or 0.0)
 897 |     if idle_target_core <= 0.0 or abs(target_core - idle_target_core) > 1e-6:
 898 |         failures.append(f"{name}:target_identity_core_width={target_core}")
 899 |     fit = manifest.get("canvas_fit", {})
 900 |     fit_scale = float(fit.get("scale", 0.0))
 901 |     if fit_scale <= 0.0:
 902 |         failures.append(f"{name}:missing_canvas_fit")
 903 |     elif abs(fit_scale - 1.0) > 1e-6:
 904 |         failures.append(f"{name}:canvas_auto_scaled={fit_scale}")
 905 |     hit_shape = manifest.get("hit_shape", {})
 906 |     if hit_shape.get("catalog") != "res://config/video_hit_shapes.json":
 907 |         failures.append(f"{name}:missing_hit_shape_catalog")
 908 |     if hit_shape.get("action_id") != RUNTIME_IDS[name]:
 909 |         failures.append(f"{name}:hit_shape_action={hit_shape.get('action_id')}")
 910 |     if int(hit_shape.get("frame_count", 0)) != 121:
 911 |         failures.append(f"{name}:hit_shape_frame_count={hit_shape.get('frame_count')}")
 912 | 
 913 |     runtime_video = manifest.get("runtime_video", {})
 914 |     video_resource = str(runtime_video.get("resource_path", ""))
 915 |     expected_resource = f"res://assets_display/wuzi_chibi/video_{name}/runtime_alpha.ogv"
 916 |     if video_resource != expected_resource:
 917 |         failures.append(f"{name}:runtime_video_resource={video_resource}")
 918 |     video_path = ROOT / "godot" / video_resource.removeprefix("res://") if video_resource else None
 919 |     if video_path is None or not video_path.is_file():
 920 |         failures.append(f"{name}:runtime_video_missing={video_resource}")
 921 |     else:
 922 |         actual_bytes = video_path.stat().st_size
 923 |         if int(runtime_video.get("bytes", 0)) != actual_bytes:
 924 |             failures.append(
 925 |                 f"{name}:runtime_video_bytes={runtime_video.get('bytes')},actual={actual_bytes}"
 926 |             )
 927 |         if runtime_video.get("codec") != "theora":
 928 |             failures.append(f"{name}:runtime_video_codec={runtime_video.get('codec')}")
 929 |         if runtime_video.get("alpha_mode") != "side_by_side_rgb_alpha":
 930 |             failures.append(f"{name}:runtime_video_alpha_mode={runtime_video.get('alpha_mode')}")
 931 |         if runtime_video.get("packed_size") != [CANVAS_WIDTH * 2, CANVAS_HEIGHT]:
 932 |             failures.append(f"{name}:runtime_video_packed_size={runtime_video.get('packed_size')}")
 933 |         if runtime_video.get("display_size") != [CANVAS_WIDTH, CANVAS_HEIGHT]:
 934 |             failures.append(f"{name}:runtime_video_display_size={runtime_video.get('display_size')}")
 935 |         png_bytes = int(manifest.get("png_fallback_bytes", 0))
 936 |         if png_bytes <= 0 or png_bytes / max(1, actual_bytes) < MIN_VIDEO_COMPRESSION_RATIO:
 937 |             failures.append(f"{name}:runtime_video_compression={png_bytes}/{actual_bytes}")
 938 |         try:
 939 |             reader = imageio_ffmpeg.read_frames(str(video_path), pix_fmt="rgb24")
 940 |             metadata = next(reader)
 941 |             reader.close()
 942 |             if list(metadata.get("size", ())) != [CANVAS_WIDTH * 2, CANVAS_HEIGHT]:
 943 |                 failures.append(f"{name}:decoded_video_size={metadata.get('size')}")
 944 |             decoded_frames, decoded_seconds = imageio_ffmpeg.count_frames_and_secs(str(video_path))
 945 |             if int(decoded_frames) != 121:
 946 |                 failures.append(f"{name}:decoded_video_frames={decoded_frames}")
 947 |             expected_seconds = 121.0 / 12.0
 948 |             if abs(float(decoded_seconds) - expected_seconds) > 0.15:
 949 |                 failures.append(f"{name}:decoded_video_duration={decoded_seconds}")
 950 |         except Exception as exc:
 951 |             failures.append(f"{name}:runtime_video_decode={exc}")
 952 | 
 953 | hit_catalog_path = ROOT / "godot/config/video_hit_shapes.json"
 954 | try:
 955 |     hit_catalog = json.loads(hit_catalog_path.read_text(encoding="utf-8"))
 956 | except Exception as exc:
 957 |     hit_catalog = {}
 958 |     failures.append(f"hit_shape_catalog_read={exc}")
 959 | 
 960 | hit_actions = hit_catalog.get("actions", {}) if isinstance(hit_catalog, dict) else {}
 961 | hit_canvas = hit_catalog.get("canvas", []) if isinstance(hit_catalog, dict) else []
 962 | if hit_canvas != [CANVAS_WIDTH, CANVAS_HEIGHT]:
 963 |     failures.append(f"hit_shape_canvas={hit_canvas}")
 964 | hit_shape_summary = {}
 965 | for name, runtime_id in RUNTIME_IDS.items():
 966 |     frames = hit_actions.get(runtime_id, [])
 967 |     if not isinstance(frames, list) or len(frames) != 121:
 968 |         failures.append(f"{runtime_id}:hit_frames={len(frames) if isinstance(frames, list) else 'invalid'}")
 969 |         continue
 970 | 
 971 |     point_counts = []
 972 |     invalid_frames = []
 973 |     for frame_index, polygon in enumerate(frames):
 974 |         if not isinstance(polygon, list) or len(polygon) < 6:
 975 |             invalid_frames.append(frame_index)
 976 |             continue
 977 |         point_counts.append(len(polygon))
 978 |         for point in polygon:
 979 |             if (
 980 |                 not isinstance(point, list)
 981 |                 or len(point) < 2
 982 |                 or not (0 <= float(point[0]) < CANVAS_WIDTH)
 983 |                 or not (0 <= float(point[1]) < CANVAS_HEIGHT)
 984 |             ):
 985 |                 invalid_frames.append(frame_index)
 986 |                 break
 987 | 
 988 |     if invalid_frames:
 989 |         failures.append(f"{runtime_id}:invalid_hit_frames={sorted(set(invalid_frames))[:12]}")
 990 |     hit_shape_summary[runtime_id] = {
 991 |         "frames": len(frames),
 992 |         "min_points": min(point_counts) if point_counts else 0,
 993 |         "max_points": max(point_counts) if point_counts else 0,
 994 |     }
 995 | 
 996 | 
 997 | def polygon_bbox(polygon: list) -> tuple[float, float, float, float] | None:
 998 |     if not isinstance(polygon, list) or not polygon:
 999 |         return None
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
