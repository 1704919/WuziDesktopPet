   1 | from __future__ import annotations
   2 | 
   3 | import argparse
   4 | import json
   5 | import os
   6 | import subprocess
   7 | from collections import deque
   8 | from pathlib import Path
   9 | 
  10 | import imageio_ffmpeg
  11 | import numpy as np
  12 | from PIL import Image, ImageDraw, ImageFilter
  13 | 
  14 | ROOT = Path(__file__).resolve().parents[1]
  15 | VIDEO_ROOT = ROOT / "分享区" / "Q版" / "绿幕视频"
  16 | NEW_VIDEO_ROOT = ROOT / "分享区" / "Q版" / "新视频"
  17 | ASSET_ROOT = ROOT / "godot" / "assets_display" / "wuzi_chibi"
  18 | CONFIG_ROOT = ROOT / "godot" / "config"
  19 | REVIEW_ROOT = ROOT / "work" / "video_review" / "processed"
  20 | GODOT_PROJECT = ROOT / "godot"
  21 | DEFAULT_GODOT_EXE = Path(r"D:\Godot\Godot_v4.7-stable_win64.exe")
  22 | HIT_SHAPE_CATALOG = CONFIG_ROOT / "video_hit_shapes.json"
  23 | 
  24 | TARGET_FPS = 12.0
  25 | CANVAS_WIDTH = 480
  26 | CANVAS_HEIGHT = 360
  27 | TARGET_CENTER_X = 240.0
  28 | TARGET_BOTTOM_Y = 338.0
  29 | TARGET_VISIBLE_HEIGHT = 220.0
  30 | LEFT_CLEAN_PX = 0
  31 | RIGHT_CLEAN_PX = 0
  32 | ALPHA_START = 18.0
  33 | ALPHA_RANGE = 30.0
  34 | SLEEP_LAYOUT_ACTION_IDS = {"sleep_loop", "wake_up"}
  35 | DETACHED_ARTIFACT_CLEANUP_ACTION_IDS = {"watch_kline", "lie_phone"}
  36 | DETACHED_COMPONENT_MIN_GRID_PIXELS = 160
  37 | DETACHED_COMPONENT_NEAR_MAIN_PAD = 3
  38 | DETACHED_COMPONENT_PROTECT_DILATE = 9
  39 | SLEEP_LAYOUT_MARGIN = 8
  40 | 
  41 | # Only actions explicitly reported by the user get a special key. Everything
  42 | # else keeps the approved conservative edge-median pipeline.
  43 | GREEN_KEY_ACTION_IDS = {
  44 |     "yawn", "sleep_down", "startle", "game_rage", "sleep_loop", "wake_up",
  45 |     "drink_milk_tea", "read_book", "lie_phone", "walk_left", "walk_right",
  46 |     "mic_test", "cat_accident", "pc_game_rage", "pc_game_focused", "hop_bounce",
  47 |     "birthday_cake", "eat_noodles", "eat_fried_chicken", "eat_sushi",
  48 |     "eat_breakfast", "eat_bullfrog", "eat_fries",
  49 | }
  50 | 
  51 | # Both problematic clips use green/gray-green backgrounds. Green chroma itself
  52 | # is the primary signal; neutral character colours must never be classified as
  53 | # background merely because they are low-saturation.
  54 | GREEN_KEY_SAMPLE_FRAMES = 9
  55 | GREEN_KEY_SAMPLE_STRIDE = 3
  56 | GREEN_KEY_EDGE_RATIO = 0.08
  57 | GREEN_KEY_PALETTE_QUANT_STEP = 16
  58 | GREEN_KEY_MAX_PALETTE_COLORS = 16
  59 | GREEN_KEY_SOFT_MIN = 1.5
  60 | GREEN_KEY_SOFT_MAX = 4.0
  61 | GREEN_KEY_HARD_MIN = 7.0
  62 | GREEN_KEY_HARD_MAX = 12.0
  63 | GREEN_KEY_PALETTE_START = 7.0
  64 | GREEN_KEY_PALETTE_RANGE = 20.0
  65 | GREEN_KEY_MIN_CHANNEL = 20.0
  66 | GREEN_KEY_MASK_BLUR_RADIUS = 0.45
  67 | GREEN_KEY_PROFILES: dict[str, dict] = {}
  68 | 
  69 | # Character protection is sampled from the already-approved processed idle
  70 | # animation. This covers the whole character palette: blue/purple hair, pink
  71 | # clothing, pale skin/sleeves, dark/neutral cloth/line work and gold accents.
  72 | CHARACTER_QUANT_STEP = 16
  73 | CHARACTER_MAX_BINS = 320
  74 | CHARACTER_MIN_BIN_COUNT = 6
  75 | CHARACTER_BIN_RADIUS = 1
  76 | CHARACTER_SAMPLE_FRAMES = 13
  77 | CHARACTER_SAMPLE_STRIDE = 2
  78 | CHARACTER_ALPHA_MIN = 220
  79 | CHARACTER_GREEN_REJECT_STRENGTH = 4.0
  80 | CHARACTER_RECOVERY_FILTER = 11
  81 | CHARACTER_RECOVERY_BBOX_PAD = 48
  82 | CHARACTER_PROTECTION_LOOKUP: np.ndarray | None = None
  83 | CHARACTER_PROTECTION_META: dict = {}
  84 | 
  85 | COMPONENT_GRID_W = 160
  86 | COMPONENT_GRID_H = 90
  87 | COMPONENT_EXPAND_X = 100
  88 | COMPONENT_EXPAND_Y = 50
  89 | HIT_ALPHA_THRESHOLD = 72
  90 | HIT_PADDING_PX = 7
  91 | HIT_ROW_STEP_PX = 10
  92 | HIT_BAND_HALF_PX = 5
  93 | CORE_BAND_TOP_RATIO = 0.08
  94 | CORE_BAND_BOTTOM_RATIO = 0.42
  95 | CORE_WIDTH_PERCENTILE = 75.0
  96 | 
  97 | # Visual identity scale: derive one uniform scale per action from the stable
  98 | # opening face/skin core. Never resize the character again while that action is
  99 | # playing. Hair, sleeves and raised arms may change the natural pose envelope,
 100 | # but they must not change the character's physical scale.
 101 | FACE_REGION_HALF_WIDTH_RATIO = 0.24
 102 | FACE_REGION_BOTTOM_RATIO = 0.46
 103 | FACE_SKIN_R_MIN = 180
 104 | FACE_SKIN_G_MIN = 130
 105 | FACE_SKIN_G_MAX = 245
 106 | FACE_SKIN_B_MIN = 120
 107 | FACE_SKIN_B_MAX = 235
 108 | FACE_SKIN_R_MINUS_G_MIN = 8
 109 | FIXED_ACTION_SCALE_MIN_MULTIPLIER = 0.80
 110 | FIXED_ACTION_SCALE_MAX_MULTIPLIER = 1.25
 111 | ACTION_FIXED_SCALE_OVERRIDES = {
 112 |     "click_happy": 0.96,
 113 |     "click_shy": 1.015,
 114 |     "drag_reaction": 1.10,
 115 |     "march_in_place": 1.042,
 116 |     "sleepy": 1.055,
 117 |     "yawn": 1.047,
 118 |     "startle": 1.050,
 119 |     "game_rage": 1.057,
 120 |     "click_wave": 1.040,
 121 |     "yawn_small": 1.035,
 122 |     "game_controller": 1.050,
 123 |     "work_computer": 1.040,
 124 |     "drink_milk_tea": 1.055,
 125 |     "read_book": 0.908,
 126 |     "lie_phone": 1.05,
 127 |     "walk_left": 1.05,
 128 |     "walk_right": 1.052,
 129 |     "mic_test": 1.027,
 130 |     "cat_accident": 1.057,
 131 |     "unbox_cards": 1.045,
 132 |     "pc_game_rage": 1.071,
 133 |     "sunglasses_proud": 1.025,
 134 |     "pc_game_focused": 1.052,
 135 |     "hop_bounce": 1.04,
 136 |     # Endpoint-calibrated against the PNG frames actually installed as idle.
 137 |     # Each food clip keeps a single fixed scale for its whole duration.
 138 |     "eat_breakfast": 1.06,
 139 |     "eat_bullfrog": 1.06,
 140 |     "eat_fried_chicken": 1.075,
 141 | }
 142 | ACTION_TARGET_CENTER_X_OFFSETS = {
 143 |     "watch_kline": 8.0,
 144 |     "pc_game_focused": 22.0,
 145 |     "unbox_cards": 5.0,
 146 |     "eat_bullfrog": 2.0,
 147 | }
 148 | SLEEP_LOOP_COMPONENT_GRID = (240, 180)
 149 | SLEEP_LOOP_ZZZ_KEEP_X = (105, 140)
 150 | SLEEP_LOOP_ZZZ_KEEP_Y = (90, 120)
 151 | SLEEP_LOOP_PROTECT_DILATE = 17
 152 | SLEEP_LOOP_WATERMARK_X = (328, 376)
 153 | SLEEP_LOOP_WATERMARK_Y = (319, 330)
 154 | SLEEP_LOOP_WATERMARK_RGB_MIN = 105
 155 | SLEEP_LOOP_WATERMARK_CHROMA_MAX = 45
 156 | SLEEP_LOOP_WATERMARK_WARM_RGB_MIN = 150
 157 | SLEEP_LOOP_WATERMARK_WARM_CHROMA_MAX = 35
 158 | FACE_NORMALIZE_EXCLUDED_ACTION_IDS = {"idle", "sleep_down", "sleep_loop", "wake_up"}
 159 | 
 160 | RUNTIME_VIDEO_FILENAME = "runtime_alpha.ogv"
 161 | RUNTIME_VIDEO_QUALITY = 8
 162 | 
 163 | 
 164 | def source_video(name: str) -> Path:
 165 |     """Prefer freshly supplied source video; after intake, use the archive folder."""
 166 |     incoming = NEW_VIDEO_ROOT / name
 167 |     return incoming if incoming.is_file() else VIDEO_ROOT / name
 168 | 
 169 | 
 170 | def godot_executable() -> Path:
 171 |     configured = os.environ.get("GODOT_EXE", "").strip()
 172 |     candidates = [Path(configured)] if configured else []
 173 |     candidates.append(DEFAULT_GODOT_EXE)
 174 |     for candidate in candidates:
 175 |         if candidate.is_file():
 176 |             return candidate
 177 |     raise FileNotFoundError(
 178 |         "Godot executable not found. Set GODOT_EXE or install Godot at "
 179 |         f"{DEFAULT_GODOT_EXE}"
 180 |     )
 181 | 
 182 | 
 183 | def refresh_godot_imports() -> dict:
 184 |     """Refresh Godot import metadata/cache after generated PNGs change."""
 185 |     godot = godot_executable()
 186 |     command = [
 187 |         str(godot),
 188 |         "--headless",
 189 |         "--editor",
 190 |         "--import",
 191 |         "--path",
 192 |         str(GODOT_PROJECT),
 193 |     ]
 194 |     completed = subprocess.run(
 195 |         command,
 196 |         capture_output=True,
 197 |         text=True,
 198 |         encoding="utf-8",
 199 |         errors="replace",
 200 |         timeout=180,
 201 |         check=False,
 202 |     )
 203 |     if completed.returncode != 0:
 204 |         detail = (completed.stderr or completed.stdout or "").strip()
 205 |         raise RuntimeError(
 206 |             "Godot asset import failed after rebuilding video frames"
 207 |             + (f": {detail[-2000:]}" if detail else "")
 208 |         )
 209 | 
 210 |     missing_sidecars: list[str] = []
 211 |     for item in ACTIONS:
 212 |         for png in item["out_dir"].glob("*.png"):
 213 |             if not Path(str(png) + ".import").is_file():
 214 |                 missing_sidecars.append(png.relative_to(ROOT).as_posix())
 215 |     if missing_sidecars:
 216 |         preview = ", ".join(missing_sidecars[:8])
 217 |         raise RuntimeError(
 218 |             "Godot import completed but generated PNG import metadata is still missing: "
 219 |             + preview
 220 |         )
 221 | 
 222 |     return {
 223 |         "executable": str(godot),
 224 |         "project": str(GODOT_PROJECT),
 225 |         "returncode": completed.returncode,
 226 |         "checked_sequences": len(ACTIONS),
 227 |     }
 228 | 
 229 | 
 230 | ACTIONS = [
 231 |     {
 232 |         "id": "idle",
 233 |         "source": VIDEO_ROOT / "角色自然待机动画生成.mp4",
 234 |         "out_dir": ASSET_ROOT / "video_idle" / "frames",
 235 |         "manifest": CONFIG_ROOT / "idle_video_manifest.json",
 236 |     },
 237 |     {
 238 |         "id": "click_happy",
 239 |         "source": VIDEO_ROOT / "点击-开心.mp4",
 240 |         "out_dir": ASSET_ROOT / "video_click_happy" / "frames",
 241 |         "manifest": CONFIG_ROOT / "click_happy_video_manifest.json",
 242 |     },
 243 |     {
 244 |         "id": "click_shy",
 245 |         "source": VIDEO_ROOT / "点击害羞.mp4",
 246 |         "out_dir": ASSET_ROOT / "video_click_shy" / "frames",
 247 |         "manifest": CONFIG_ROOT / "click_shy_video_manifest.json",
 248 |     },
 249 |     {
 250 |         "id": "march_in_place",
 251 |         "source": VIDEO_ROOT / "原地踏步.mp4",
 252 |         "out_dir": ASSET_ROOT / "video_march_in_place" / "frames",
 253 |         "manifest": CONFIG_ROOT / "march_in_place_video_manifest.json",
 254 |     },
 255 |     {
 256 |         "id": "sleepy",
 257 |         "source": VIDEO_ROOT / "打瞌睡.mp4",
 258 |         "out_dir": ASSET_ROOT / "video_sleepy" / "frames",
 259 |         "manifest": CONFIG_ROOT / "sleepy_video_manifest.json",
 260 |     },
 261 |     {
 262 |         "id": "yawn",
 263 |         "source": source_video("打哈欠.mp4"),
 264 |         "out_dir": ASSET_ROOT / "video_yawn" / "frames",
 265 |         "manifest": CONFIG_ROOT / "yawn_video_manifest.json",
 266 |     },
 267 |     {
 268 |         "id": "click_angry",
 269 |         "source": source_video("点击-傲娇生气.mp4"),
 270 |         "out_dir": ASSET_ROOT / "video_click_angry" / "frames",
 271 |         "manifest": CONFIG_ROOT / "click_angry_video_manifest.json",
 272 |     },
 273 |     {
 274 |         "id": "sleep_down",
 275 |         "source": source_video("进入睡眠.mp4"),
 276 |         "out_dir": ASSET_ROOT / "video_sleep_down" / "frames",
 277 |         "manifest": CONFIG_ROOT / "sleep_down_video_manifest.json",
 278 |     },
 279 |     {
 280 |         "id": "drag_reaction",
 281 |         "source": source_video("鼠标拖拽.mp4"),
 282 |         "out_dir": ASSET_ROOT / "video_drag_reaction" / "frames",
 283 |         "manifest": CONFIG_ROOT / "drag_reaction_video_manifest.json",
 284 |     },
 285 |     {
 286 |         "id": "startle",
 287 |         "source": source_video("被吓到.mp4"),
 288 |         "out_dir": ASSET_ROOT / "video_startle" / "frames",
 289 |         "manifest": CONFIG_ROOT / "startle_video_manifest.json",
 290 |     },
 291 |     {
 292 |         "id": "yawn_small",
 293 |         "source": source_video("打哈欠小幅度.mp4"),
 294 |         "out_dir": ASSET_ROOT / "video_yawn_small" / "frames",
 295 |         "manifest": CONFIG_ROOT / "yawn_small_video_manifest.json",
 296 |     },
 297 |     {
 298 |         "id": "game_rage",
 299 |         "source": source_video("打游戏暴怒.mp4"),
 300 |         "out_dir": ASSET_ROOT / "video_game_rage" / "frames",
 301 |         "manifest": CONFIG_ROOT / "game_rage_video_manifest.json",
 302 |     },
 303 |     {
 304 |         "id": "click_wave",
 305 |         "source": source_video("点击-打招呼.mp4"),
 306 |         "out_dir": ASSET_ROOT / "video_click_wave" / "frames",
 307 |         "manifest": CONFIG_ROOT / "click_wave_video_manifest.json",
 308 |     },
 309 |     {
 310 |         "id": "wake_up",
 311 |         "source": source_video("睡眠惊醒.mp4"),
 312 |         "out_dir": ASSET_ROOT / "video_wake_up" / "frames",
 313 |         "manifest": CONFIG_ROOT / "wake_up_video_manifest.json",
 314 |     },
 315 |     {
 316 |         "id": "sleep_loop",
 317 |         "source": source_video("睡眠循环.mp4"),
 318 |         "out_dir": ASSET_ROOT / "video_sleep_loop" / "frames",
 319 |         "manifest": CONFIG_ROOT / "sleep_loop_video_manifest.json",
 320 |     },
 321 |     {
 322 |         "id": "sing",
 323 |         "source": source_video("悠闲唱歌.mp4"),
 324 |         "out_dir": ASSET_ROOT / "video_sing" / "frames",
 325 |         "manifest": CONFIG_ROOT / "sing_video_manifest.json",
 326 |     },
 327 |     {
 328 |         "id": "game_controller",
 329 |         "source": source_video("正常打游戏.mp4"),
 330 |         "out_dir": ASSET_ROOT / "video_game_controller" / "frames",
 331 |         "manifest": CONFIG_ROOT / "game_controller_video_manifest.json",
 332 |     },
 333 |     {
 334 |         "id": "read_book",
 335 |         "source": source_video("坐下看书.mp4"),
 336 |         "out_dir": ASSET_ROOT / "video_read_book" / "frames",
 337 |         "manifest": CONFIG_ROOT / "read_book_video_manifest.json",
 338 |     },
 339 |     {
 340 |         "id": "watch_kline",
 341 |         "source": source_video("盯盘-看K线.mp4"),
 342 |         "out_dir": ASSET_ROOT / "video_watch_kline" / "frames",
 343 |         "manifest": CONFIG_ROOT / "watch_kline_video_manifest.json",
 344 |     },
 345 |     {
 346 |         "id": "drink_milk_tea",
 347 |         "source": source_video("喝奶茶.mp4"),
 348 |         "out_dir": ASSET_ROOT / "video_drink_milk_tea" / "frames",
 349 |         "manifest": CONFIG_ROOT / "drink_milk_tea_video_manifest.json",
 350 |     },
 351 |     {
 352 |         "id": "work_computer",
 353 |         "source": source_video("使用电脑工作.mp4"),
 354 |         "out_dir": ASSET_ROOT / "video_work_computer" / "frames",
 355 |         "manifest": CONFIG_ROOT / "work_computer_video_manifest.json",
 356 |     },
 357 |     {
 358 |         "id": "lie_phone",
 359 |         "source": source_video("躺下玩手机.mp4"),
 360 |         "out_dir": ASSET_ROOT / "video_lie_phone" / "frames",
 361 |         "manifest": CONFIG_ROOT / "lie_phone_video_manifest.json",
 362 |     },
 363 |     {
 364 |         "id": "walk_left",
 365 |         "source": source_video("向左走.mp4"),
 366 |         "out_dir": ASSET_ROOT / "video_walk_left" / "frames",
 367 |         "manifest": CONFIG_ROOT / "walk_left_video_manifest.json",
 368 |     },
 369 |     {
 370 |         "id": "walk_right",
 371 |         "source": source_video("向右走.mp4"),
 372 |         "out_dir": ASSET_ROOT / "video_walk_right" / "frames",
 373 |         "manifest": CONFIG_ROOT / "walk_right_video_manifest.json",
 374 |     },
 375 |     {
 376 |         "id": "mic_test",
 377 |         "source": source_video("试麦.mp4"),
 378 |         "out_dir": ASSET_ROOT / "video_mic_test" / "frames",
 379 |         "manifest": CONFIG_ROOT / "mic_test_video_manifest.json",
 380 |     },
 381 |     {
 382 |         "id": "cat_accident",
 383 |         "source": source_video("不小心踢到猫.mp4"),
 384 |         "out_dir": ASSET_ROOT / "video_cat_accident" / "frames",
 385 |         "manifest": CONFIG_ROOT / "cat_accident_video_manifest.json",
 386 |     },
 387 |     {
 388 |         "id": "unbox_cards",
 389 |         "source": source_video("拆卡.mp4"),
 390 |         "out_dir": ASSET_ROOT / "video_unbox_cards" / "frames",
 391 |         "manifest": CONFIG_ROOT / "unbox_cards_video_manifest.json",
 392 |     },
 393 |     {
 394 |         "id": "pc_game_rage",
 395 |         "source": source_video("打电脑游戏暴怒.mp4"),
 396 |         "out_dir": ASSET_ROOT / "video_pc_game_rage" / "frames",
 397 |         "manifest": CONFIG_ROOT / "pc_game_rage_video_manifest.json",
 398 |     },
 399 |     {
 400 |         "id": "sunglasses_proud",
 401 |         "source": source_video("得意墨镜.mp4"),
 402 |         "out_dir": ASSET_ROOT / "video_sunglasses_proud" / "frames",
 403 |         "manifest": CONFIG_ROOT / "sunglasses_proud_video_manifest.json",
 404 |     },
 405 |     {
 406 |         "id": "pc_game_focused",
 407 |         "source": source_video("认真打电脑游戏.mp4"),
 408 |         "out_dir": ASSET_ROOT / "video_pc_game_focused" / "frames",
 409 |         "manifest": CONFIG_ROOT / "pc_game_focused_video_manifest.json",
 410 |     },
 411 |     {
 412 |         "id": "hop_bounce",
 413 |         "source": source_video("原地蹦蹦跳.mp4"),
 414 |         "out_dir": ASSET_ROOT / "video_hop_bounce" / "frames",
 415 |         "manifest": CONFIG_ROOT / "hop_bounce_video_manifest.json",
 416 |     },
 417 |     {
 418 |         "id": "birthday_cake",
 419 |         "source": source_video("吃生日蛋糕.mp4"),
 420 |         "out_dir": ASSET_ROOT / "video_birthday_cake" / "frames",
 421 |         "manifest": CONFIG_ROOT / "birthday_cake_video_manifest.json",
 422 |     },
 423 |     {
 424 |         "id": "eat_noodles",
 425 |         "source": source_video("吃拉面.mp4"),
 426 |         "out_dir": ASSET_ROOT / "video_eat_noodles" / "frames",
 427 |         "manifest": CONFIG_ROOT / "eat_noodles_video_manifest.json",
 428 |     },
 429 |     {
 430 |         "id": "eat_fried_chicken",
 431 |         "source": source_video("吃炸鸡.mp4"),
 432 |         "out_dir": ASSET_ROOT / "video_eat_fried_chicken" / "frames",
 433 |         "manifest": CONFIG_ROOT / "eat_fried_chicken_video_manifest.json",
 434 |     },
 435 |     {
 436 |         "id": "eat_sushi",
 437 |         "source": source_video("吃寿司.mp4"),
 438 |         "out_dir": ASSET_ROOT / "video_eat_sushi" / "frames",
 439 |         "manifest": CONFIG_ROOT / "eat_sushi_video_manifest.json",
 440 |     },
 441 |     {
 442 |         "id": "eat_breakfast",
 443 |         "source": source_video("吃早餐.mp4"),
 444 |         "out_dir": ASSET_ROOT / "video_eat_breakfast" / "frames",
 445 |         "manifest": CONFIG_ROOT / "eat_breakfast_video_manifest.json",
 446 |     },
 447 |     {
 448 |         "id": "eat_bullfrog",
 449 |         "source": source_video("吃炒牛蛙.mp4"),
 450 |         "out_dir": ASSET_ROOT / "video_eat_bullfrog" / "frames",
 451 |         "manifest": CONFIG_ROOT / "eat_bullfrog_video_manifest.json",
 452 |     },
 453 |     {
 454 |         "id": "eat_fries",
 455 |         "source": source_video("吃薯条.mp4"),
 456 |         "out_dir": ASSET_ROOT / "video_eat_fries" / "frames",
 457 |         "manifest": CONFIG_ROOT / "eat_fries_video_manifest.json",
 458 |     },
 459 | ]
 460 | 
 461 | RUNTIME_ACTION_IDS = {
 462 |     "idle": "idle",
 463 |     "click_happy": "click_happy_video",
 464 |     "click_shy": "click_shy_video",
 465 |     "march_in_place": "march_in_place_video",
 466 |     "sleepy": "sleepy_video",
 467 |     "yawn": "yawn_video",
 468 |     "click_angry": "click_angry_video",
 469 |     "sleep_down": "sleep_down_video",
 470 |     "drag_reaction": "drag_reaction_video",
 471 |     "startle": "startle_video",
 472 |     "yawn_small": "yawn_small_video",
 473 |     "game_rage": "game_rage_video",
 474 |     "click_wave": "click_wave_video",
 475 |     "wake_up": "wake_up_video",
 476 |     "sleep_loop": "sleep_loop_video",
 477 |     "sing": "sing_video",
 478 |     "game_controller": "game_controller_video",
 479 |     "read_book": "read_book_video",
 480 |     "watch_kline": "watch_kline_video",
 481 |     "drink_milk_tea": "drink_milk_tea_video",
 482 |     "work_computer": "work_computer_video",
 483 |     "lie_phone": "lie_phone_video",
 484 |     "walk_left": "walk_left_video",
 485 |     "walk_right": "walk_right_video",
 486 |     "mic_test": "mic_test_video",
 487 |     "cat_accident": "cat_accident_video",
 488 |     "unbox_cards": "unbox_cards",
 489 |     "pc_game_rage": "pc_game_rage",
 490 |     "sunglasses_proud": "sunglasses_proud",
 491 |     "pc_game_focused": "pc_game_focused",
 492 |     "hop_bounce": "hop_bounce",
 493 |     "birthday_cake": "birthday_cake",
 494 |     "eat_noodles": "eat_noodles",
 495 |     "eat_fried_chicken": "eat_fried_chicken",
 496 |     "eat_sushi": "eat_sushi",
 497 |     "eat_breakfast": "eat_breakfast",
 498 |     "eat_bullfrog": "eat_bullfrog",
 499 |     "eat_fries": "eat_fries",
 500 | }
 501 | 
 502 | ALL_ACTIONS = ACTIONS
 503 | IDLE_ACTION = next(item for item in ALL_ACTIONS if item["id"] == "idle")
 504 | 
 505 | 
 506 | def requested_action_ids() -> set[str]:
 507 |     parser = argparse.ArgumentParser(add_help=False)
 508 |     parser.add_argument("--actions", default="")
 509 |     args, _unknown = parser.parse_known_args()
 510 |     raw = args.actions.strip() or os.environ.get("Q_VIDEO_ACTIONS", "").strip()
 511 |     return {
 512 |         part.strip()
 513 |         for part in raw.split(",")
 514 |         if part.strip()
 515 |     }
 516 | 
 517 | 
 518 | _requested_actions = requested_action_ids()
 519 | PARTIAL_BUILD = bool(_requested_actions)
 520 | if PARTIAL_BUILD:
 521 |     known_action_ids = {item["id"] for item in ALL_ACTIONS}
 522 |     unknown_action_ids = sorted(_requested_actions - known_action_ids)
 523 |     if unknown_action_ids:
 524 |         raise ValueError(f"Unknown Q_VIDEO_ACTIONS: {unknown_action_ids}")
 525 |     # Partial builds write only explicitly requested actions. Idle remains a
 526 |     # read-only normalization / character-color reference when it is not
 527 |     # requested, so a yawn-only rebuild cannot touch other animation assets.
 528 |     ACTIONS = [
 529 |         item for item in ALL_ACTIONS
 530 |         if item["id"] in _requested_actions
 531 |     ]
 532 | 
 533 | 
 534 | def read_video(path: Path) -> tuple[dict, list[bytes]]:
 535 |     reader = imageio_ffmpeg.read_frames(str(path), pix_fmt="rgb24")
 536 |     meta = next(reader)
 537 |     return meta, list(reader)
 538 | 
 539 | 
 540 | def estimate_background(frame: np.ndarray) -> np.ndarray:
 541 |     h, w, _ = frame.shape
 542 |     strip_x = max(8, w // 80)
 543 |     strip_y = max(8, h // 80)
 544 |     edge = np.concatenate(
 545 |         [
 546 |             frame[:, :strip_x].reshape(-1, 3),
 547 |             frame[:, -strip_x:].reshape(-1, 3),
 548 |             frame[:strip_y, :].reshape(-1, 3),
 549 |             frame[-strip_y:, :].reshape(-1, 3),
 550 |         ],
 551 |         axis=0,
 552 |     )
 553 |     return np.median(edge, axis=0).astype(np.float32)
 554 | 
 555 | 
 556 | def largest_component_bbox(mask: np.ndarray) -> tuple[int, int, int, int] | None:
 557 |     h, w = mask.shape
 558 |     small = Image.fromarray((mask.astype(np.uint8) * 255), "L").resize(
 559 |         (COMPONENT_GRID_W, COMPONENT_GRID_H),
 560 |         Image.Resampling.NEAREST,
 561 |     )
 562 |     grid = np.array(small, dtype=np.uint8) > 0
 563 |     visited = np.zeros_like(grid, dtype=bool)
 564 |     best = None
 565 |     best_count = 0
 566 | 
 567 |     for y in range(COMPONENT_GRID_H):
 568 |         for x in range(COMPONENT_GRID_W):
 569 |             if not grid[y, x] or visited[y, x]:
 570 |                 continue
 571 |             stack = [(x, y)]
 572 |             visited[y, x] = True
 573 |             count = 0
 574 |             min_x = max_x = x
 575 |             min_y = max_y = y
 576 |             while stack:
 577 |                 cx, cy = stack.pop()
 578 |                 count += 1
 579 |                 min_x = min(min_x, cx)
 580 |                 max_x = max(max_x, cx)
 581 |                 min_y = min(min_y, cy)
 582 |                 max_y = max(max_y, cy)
 583 |                 for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
 584 |                     if (
 585 |                         0 <= nx < COMPONENT_GRID_W
 586 |                         and 0 <= ny < COMPONENT_GRID_H
 587 |                         and grid[ny, nx]
 588 |                         and not visited[ny, nx]
 589 |                     ):
 590 |                         visited[ny, nx] = True
 591 |                         stack.append((nx, ny))
 592 | 
 593 |             if count > best_count:
 594 |                 best_count = count
 595 |                 best = (min_x, min_y, max_x + 1, max_y + 1)
 596 | 
 597 |     if best is None:
 598 |         return None
 599 | 
 600 |     sx = w / COMPONENT_GRID_W
 601 |     sy = h / COMPONENT_GRID_H
 602 |     x1 = max(0, int(best[0] * sx) - COMPONENT_EXPAND_X)
 603 |     y1 = max(0, int(best[1] * sy) - COMPONENT_EXPAND_Y)
 604 |     x2 = min(w, int(np.ceil(best[2] * sx)) + COMPONENT_EXPAND_X)
 605 |     y2 = min(h, int(np.ceil(best[3] * sy)) + COMPONENT_EXPAND_Y)
 606 |     return (x1, y1, x2, y2)
 607 | 
 608 | 
 609 | def clean_and_key(frame: np.ndarray) -> tuple[Image.Image, tuple[int, int, int, int] | None]:
 610 |     """Initial conservative keying method.
 611 | 
 612 |     Keep the original, simple behavior: estimate one background color from the
 613 |     frame edges, key by RGB distance, then keep the main character component.
 614 |     Do not use the later multi-palette/spatial classifiers here. Per-action
 615 |     exceptions should be implemented separately when the user identifies a
 616 |     problematic source video.
 617 |     """
 618 |     bg = estimate_background(frame)
 619 |     cleaned = frame.copy()
 620 | 
 621 |     # Hard side clearing remains disabled. It was an old watermark workaround,
 622 |     # not part of the core chroma-key method, and it can crop wide/lying poses.
 623 |     if LEFT_CLEAN_PX > 0 or RIGHT_CLEAN_PX > 0:
 624 |         bg_u8 = bg.astype(np.uint8)
 625 |         left = min(LEFT_CLEAN_PX, cleaned.shape[1] // 3)
 626 |         right = min(RIGHT_CLEAN_PX, cleaned.shape[1] // 3)
 627 |         if left > 0:
 628 |             cleaned[:, :left] = bg_u8
 629 |         if right > 0:
 630 |             cleaned[:, cleaned.shape[1] - right:] = bg_u8
 631 | 
 632 |     dist = np.linalg.norm(cleaned.astype(np.float32) - bg, axis=2)
 633 |     alpha_f = np.clip((dist - ALPHA_START) / ALPHA_RANGE, 0.0, 1.0)
 634 |     alpha = np.round(alpha_f * 255.0).astype(np.uint8)
 635 | 
 636 |     strong = alpha >= 72
 637 |     component_bbox = largest_component_bbox(strong)
 638 |     if component_bbox is not None:
 639 |         x1, y1, x2, y2 = component_bbox
 640 |         keep = np.zeros_like(alpha, dtype=bool)
 641 |         keep[y1:y2, x1:x2] = True
 642 |         alpha[~keep] = 0
 643 | 
 644 |     rgba = np.dstack([cleaned, alpha])
 645 |     rr = rgba[..., 0].astype(np.int16)
 646 |     gg = rgba[..., 1].astype(np.int16)
 647 |     bb = rgba[..., 2].astype(np.int16)
 648 |     semi = (alpha > 0) & (gg > np.maximum(rr, bb) + 10)
 649 |     cap = np.maximum(rr, bb) + 10
 650 |     gg[semi] = np.minimum(gg[semi], cap[semi])
 651 |     rgba[..., 1] = np.clip(gg, 0, 255).astype(np.uint8)
 652 | 
 653 |     rgba[alpha == 0, :3] = 0
 654 | 
 655 |     strong = alpha >= 72
 656 |     ys, xs = np.where(strong)
 657 |     bbox = None
 658 |     if len(xs):
 659 |         bbox = (int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1))
 660 | 
 661 |     return Image.fromarray(rgba, "RGBA"), bbox
 662 | 
 663 | 
 664 | def green_strength(rgb: np.ndarray) -> np.ndarray:
 665 |     """Return strict green excess: green must exceed both red and blue."""
 666 |     values = rgb.astype(np.float32)
 667 |     r = values[..., 0]
 668 |     g = values[..., 1]
 669 |     b = values[..., 2]
 670 |     # Using max(R, B) is deliberate. Gold/yellow character accents can have a
 671 |     # high G-(R+B)/2 score because blue is low, but R still exceeds G. They are
 672 |     # therefore not green and must remain protected.
 673 |     return g - np.maximum(r, b)
 674 | 
 675 | 
 676 | def character_color_family(rgb: np.ndarray) -> str:
 677 |     r, g, b = [float(value) for value in rgb]
 678 |     maximum = max(r, g, b)
 679 |     minimum = min(r, g, b)
 680 |     chroma = maximum - minimum
 681 |     if b >= r + 10.0 and b >= g + 8.0:
 682 |         return "blue_purple"
 683 |     if r >= g + 12.0 and r >= b + 5.0:
 684 |         return "pink_red"
 685 |     if minimum >= 145.0 and chroma <= 95.0:
 686 |         return "pale_skin_white"
 687 |     if maximum <= 115.0:
 688 |         return "dark_linework"
 689 |     if r >= g + 8.0 and g >= b + 10.0:
 690 |         return "gold_warm"
 691 |     if chroma <= 36.0:
 692 |         return "neutral_gray"
 693 |     return "other"
 694 | 
 695 | 
 696 | def build_character_protection_lookup_from_idle() -> tuple[np.ndarray, dict]:
 697 |     """Build a detailed character-only palette from approved processed idle PNGs."""
 698 |     idle_files = sorted(IDLE_ACTION["out_dir"].glob("*.png"))
 699 |     if not idle_files:
 700 |         return np.zeros(4096, dtype=bool), {
 701 |             "sample_source": "processed_idle",
 702 |             "sample_frames": 0,
 703 |             "palette_bins": 0,
 704 |             "expanded_lookup_bins": 0,
 705 |             "family_bins": {},
 706 |         }
 707 | 
 708 |     pick_count = min(CHARACTER_SAMPLE_FRAMES, len(idle_files))
 709 |     pick_indices = np.linspace(
 710 |         0,
 711 |         len(idle_files) - 1,
 712 |         num=pick_count,
 713 |         dtype=np.int32,
 714 |     )
 715 |     counts = np.zeros(4096, dtype=np.int64)
 716 |     sampled_pixels = 0
 717 |     rejected_green_pixels = 0
 718 | 
 719 |     for idx in pick_indices.tolist():
 720 |         rgba = np.array(
 721 |             Image.open(idle_files[int(idx)]).convert("RGBA"),
 722 |             dtype=np.uint8,
 723 |         )
 724 |         rgb = rgba[::CHARACTER_SAMPLE_STRIDE, ::CHARACTER_SAMPLE_STRIDE, :3]
 725 |         alpha = rgba[::CHARACTER_SAMPLE_STRIDE, ::CHARACTER_SAMPLE_STRIDE, 3]
 726 |         visible = alpha >= CHARACTER_ALPHA_MIN
 727 |         sampled_pixels += int(visible.sum())
 728 |         if not visible.any():
 729 |             continue
 730 | 
 731 |         strength = green_strength(rgb)
 732 |         safe = visible & (strength < CHARACTER_GREEN_REJECT_STRENGTH)
 733 |         rejected_green_pixels += int((visible & ~safe).sum())
 734 |         if not safe.any():
 735 |             continue
 736 | 
 737 |         quant = (rgb[safe] // CHARACTER_QUANT_STEP).astype(np.int16)
 738 |         codes = (
 739 |             (quant[:, 0] << 8)
 740 |             | (quant[:, 1] << 4)
 741 |             | quant[:, 2]
 742 |         )
 743 |         counts += np.bincount(codes, minlength=4096)
 744 | 
 745 |     supported = np.where(counts >= CHARACTER_MIN_BIN_COUNT)[0]
 746 |     ordered = supported[np.argsort(counts[supported])[::-1]]
 747 | 
 748 |     # Preserve small but important colour families instead of allowing the
 749 |     # dominant blue hair / pink clothing pixels to crowd them out.
 750 |     family_candidates: dict[str, list[int]] = {}
 751 |     center_cache: dict[int, np.ndarray] = {}
 752 |     for code in ordered.tolist():
 753 |         qr = (int(code) >> 8) & 15
 754 |         qg = (int(code) >> 4) & 15
 755 |         qb = int(code) & 15
 756 |         center = np.array(
 757 |             [
 758 |                 qr * CHARACTER_QUANT_STEP + CHARACTER_QUANT_STEP // 2,
 759 |                 qg * CHARACTER_QUANT_STEP + CHARACTER_QUANT_STEP // 2,
 760 |                 qb * CHARACTER_QUANT_STEP + CHARACTER_QUANT_STEP // 2,
 761 |             ],
 762 |             dtype=np.float32,
 763 |         )
 764 |         center_cache[int(code)] = center
 765 |         family_candidates.setdefault(
 766 |             character_color_family(center),
 767 |             [],
 768 |         ).append(int(code))
 769 | 
 770 |     selected: list[int] = []
 771 |     selected_set: set[int] = set()
 772 |     per_family_floor = 48
 773 |     for family in (
 774 |         "blue_purple",
 775 |         "pink_red",
 776 |         "pale_skin_white",
 777 |         "dark_linework",
 778 |         "neutral_gray",
 779 |         "gold_warm",
 780 |         "other",
 781 |     ):
 782 |         for code in family_candidates.get(family, [])[:per_family_floor]:
 783 |             if code not in selected_set:
 784 |                 selected.append(code)
 785 |                 selected_set.add(code)
 786 | 
 787 |     for code in ordered.tolist():
 788 |         code = int(code)
 789 |         if code in selected_set:
 790 |             continue
 791 |         selected.append(code)
 792 |         selected_set.add(code)
 793 |         if len(selected) >= CHARACTER_MAX_BINS:
 794 |             break
 795 |     selected = selected[:CHARACTER_MAX_BINS]
 796 | 
 797 |     lookup = np.zeros(4096, dtype=bool)
 798 |     family_bins: dict[str, int] = {}
 799 |     representative: list[list[int]] = []
 800 | 
 801 |     for code in selected:
 802 |         center = center_cache[code]
 803 |         family = character_color_family(center)
 804 |         family_bins[family] = family_bins.get(family, 0) + 1
 805 |         if len(representative) < 48:
 806 |             representative.append([int(v) for v in center.tolist()])
 807 | 
 808 |         qr = (code >> 8) & 15
 809 |         qg = (code >> 4) & 15
 810 |         qb = code & 15
 811 |         for dr in range(-CHARACTER_BIN_RADIUS, CHARACTER_BIN_RADIUS + 1):
 812 |             for dg in range(-CHARACTER_BIN_RADIUS, CHARACTER_BIN_RADIUS + 1):
 813 |                 for db in range(-CHARACTER_BIN_RADIUS, CHARACTER_BIN_RADIUS + 1):
 814 |                     if dr * dr + dg * dg + db * db > CHARACTER_BIN_RADIUS ** 2:
 815 |                         continue
 816 |                     nr, ng, nb = qr + dr, qg + dg, qb + db
 817 |                     if not (0 <= nr <= 15 and 0 <= ng <= 15 and 0 <= nb <= 15):
 818 |                         continue
 819 |                     lookup[(nr << 8) | (ng << 4) | nb] = True
 820 | 
 821 |     return lookup, {
 822 |         "sample_source": "processed_idle",
 823 |         "sample_frames": int(pick_count),
 824 |         "sample_stride": CHARACTER_SAMPLE_STRIDE,
 825 |         "alpha_min": CHARACTER_ALPHA_MIN,
 826 |         "quant_step": CHARACTER_QUANT_STEP,
 827 |         "palette_bins": int(len(selected)),
 828 |         "expanded_lookup_bins": int(lookup.sum()),
 829 |         "bin_radius": CHARACTER_BIN_RADIUS,
 830 |         "minimum_bin_count": CHARACTER_MIN_BIN_COUNT,
 831 |         "sampled_opaque_pixels": sampled_pixels,
 832 |         "greenish_idle_pixels_rejected": rejected_green_pixels,
 833 |         "green_reject_strength": CHARACTER_GREEN_REJECT_STRENGTH,
 834 |         "family_bins": family_bins,
 835 |         "representative_rgb": representative,
 836 |     }
 837 | 
 838 | 
 839 | def analyze_green_key_profile(
 840 |     meta: dict,
 841 |     raw_frames: list[bytes],
 842 | ) -> dict:
 843 |     """Measure the actual green/gray-green screen colours for one source clip."""
 844 |     w, h = meta["size"]
 845 |     if not raw_frames:
 846 |         return {
 847 |             "sample_frames": 0,
 848 |             "soft_green_strength": GREEN_KEY_SOFT_MIN,
 849 |             "hard_green_strength": GREEN_KEY_HARD_MIN,
 850 |             "background_palette_rgb": [],
 851 |         }
 852 | 
 853 |     pick_count = min(GREEN_KEY_SAMPLE_FRAMES, len(raw_frames))
 854 |     picks = np.linspace(
 855 |         0,
 856 |         len(raw_frames) - 1,
 857 |         num=pick_count,
 858 |         dtype=np.int32,
 859 |     )
 860 |     sampled_chunks: list[np.ndarray] = []
 861 |     edge_chunks: list[np.ndarray] = []
 862 | 
 863 |     edge_x = max(8, int(round(w * GREEN_KEY_EDGE_RATIO)))
 864 |     edge_y = max(8, int(round(h * GREEN_KEY_EDGE_RATIO)))
 865 | 
 866 |     for idx in picks.tolist():
 867 |         frame = np.frombuffer(
 868 |             raw_frames[int(idx)],
 869 |             dtype=np.uint8,
 870 |         ).reshape((h, w, 3))
 871 |         sampled = frame[
 872 |             ::GREEN_KEY_SAMPLE_STRIDE,
 873 |             ::GREEN_KEY_SAMPLE_STRIDE,
 874 |         ].reshape(-1, 3)
 875 |         sampled_chunks.append(sampled)
 876 | 
 877 |         edge = np.concatenate(
 878 |             [
 879 |                 frame[:, :edge_x].reshape(-1, 3),
 880 |                 frame[:, -edge_x:].reshape(-1, 3),
 881 |                 frame[:edge_y, :].reshape(-1, 3),
 882 |                 frame[-edge_y:, :].reshape(-1, 3),
 883 |             ],
 884 |             axis=0,
 885 |         )
 886 |         edge_chunks.append(edge[::GREEN_KEY_SAMPLE_STRIDE])
 887 | 
 888 |     sampled_rgb = np.concatenate(sampled_chunks, axis=0)
 889 |     edge_rgb = np.concatenate(edge_chunks, axis=0)
 890 |     sampled_strength = green_strength(sampled_rgb)
 891 |     edge_strength = green_strength(edge_rgb)
 892 | 
 893 |     # The character has no intentional green. Sampling all genuinely
 894 |     # green-dominant pixels therefore captures inner gray-green patches too,
 895 |     # rather than learning only a single border colour.
 896 |     greenish = (
 897 |         (sampled_strength > 0.35)
 898 |         & (sampled_rgb[:, 1] >= GREEN_KEY_MIN_CHANNEL)
 899 |     )
 900 |     edge_greenish = (
 901 |         (edge_strength > 0.35)
 902 |         & (edge_rgb[:, 1] >= GREEN_KEY_MIN_CHANNEL)
 903 |     )
 904 | 
 905 |     positive_strength = sampled_strength[greenish]
 906 |     if len(positive_strength):
 907 |         q = np.quantile(
 908 |             positive_strength,
 909 |             [0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95],
 910 |         )
 911 |         soft = float(np.clip(q[1] * 0.55, GREEN_KEY_SOFT_MIN, GREEN_KEY_SOFT_MAX))
 912 |         hard = float(np.clip(q[3] * 0.65, GREEN_KEY_HARD_MIN, GREEN_KEY_HARD_MAX))
 913 |         hard = max(hard, soft + 2.5)
 914 |     else:
 915 |         q = np.zeros(7, dtype=np.float32)
 916 |         soft = GREEN_KEY_SOFT_MIN
 917 |         hard = GREEN_KEY_HARD_MIN
 918 | 
 919 |     palette: list[list[float]] = []
 920 |     if greenish.any():
 921 |         quant = (
 922 |             sampled_rgb[greenish] // GREEN_KEY_PALETTE_QUANT_STEP
 923 |         ).astype(np.int16)
 924 |         codes = (
 925 |             (quant[:, 0] << 8)
 926 |             | (quant[:, 1] << 4)
 927 |             | quant[:, 2]
 928 |         )
 929 |         counts = np.bincount(codes, minlength=4096)
 930 |         order = np.argsort(counts)[::-1]
 931 |         for code in order.tolist():
 932 |             if counts[code] <= 0:
 933 |                 break
 934 |             qr = (int(code) >> 8) & 15
 935 |             qg = (int(code) >> 4) & 15
 936 |             qb = int(code) & 15
 937 |             center = np.array(
 938 |                 [
 939 |                     qr * GREEN_KEY_PALETTE_QUANT_STEP + GREEN_KEY_PALETTE_QUANT_STEP / 2,
 940 |                     qg * GREEN_KEY_PALETTE_QUANT_STEP + GREEN_KEY_PALETTE_QUANT_STEP / 2,
 941 |                     qb * GREEN_KEY_PALETTE_QUANT_STEP + GREEN_KEY_PALETTE_QUANT_STEP / 2,
 942 |                 ],
 943 |                 dtype=np.float32,
 944 |             )
 945 |             if float(green_strength(center.reshape(1, 3))[0]) <= 0.0:
 946 |                 continue
 947 |             if all(
 948 |                 float(np.linalg.norm(center - np.array(existing))) >= 8.0
 949 |                 for existing in palette
 950 |             ):
 951 |                 palette.append([float(v) for v in center.tolist()])
 952 |             if len(palette) >= GREEN_KEY_MAX_PALETTE_COLORS:
 953 |                 break
 954 | 
 955 |     return {
 956 |         "sample_frames": int(pick_count),
 957 |         "sample_stride": GREEN_KEY_SAMPLE_STRIDE,
 958 |         "edge_ratio": GREEN_KEY_EDGE_RATIO,
 959 |         "sampled_pixels": int(len(sampled_rgb)),
 960 |         "greenish_pixel_ratio": float(np.mean(greenish)),
 961 |         "edge_greenish_pixel_ratio": float(np.mean(edge_greenish)),
 962 |         "green_strength_quantiles": {
 963 |             "q05": float(q[0]),
 964 |             "q10": float(q[1]),
 965 |             "q25": float(q[2]),
 966 |             "q50": float(q[3]),
 967 |             "q75": float(q[4]),
 968 |             "q90": float(q[5]),
 969 |             "q95": float(q[6]),
 970 |         },
 971 |         "soft_green_strength": soft,
 972 |         "hard_green_strength": hard,
 973 |         "palette_start_distance": GREEN_KEY_PALETTE_START,
 974 |         "palette_range": GREEN_KEY_PALETTE_RANGE,
 975 |         "background_palette_rgb": palette,
 976 |     }
 977 | 
 978 | 
 979 | def recover_character_colors(
 980 |     frame: np.ndarray,
 981 |     keyed_alpha: np.ndarray,
 982 |     profile: dict,
 983 | ) -> np.ndarray:
 984 |     """Restore known idle-character colours without resurrecting green screen."""
 985 |     lookup = CHARACTER_PROTECTION_LOOKUP
 986 |     if lookup is None or not bool(lookup.any()):
 987 |         return keyed_alpha
 988 | 
 989 |     generic_keyed, _ = clean_and_key(frame)
 990 |     generic_alpha = np.array(
 991 |         generic_keyed.getchannel("A"),
 992 |         dtype=np.uint8,
 993 |     )
 994 | 
 995 |     quant = (
 996 |         frame.astype(np.uint16) // CHARACTER_QUANT_STEP
 997 |     ).astype(np.int16)
 998 |     codes = (
 999 |         (quant[..., 0] << 8)
        | (quant[..., 1] << 4)
        | quant[..., 2]
    )
    strength = green_strength(frame)
    recovery_green_limit = min(
        CHARACTER_GREEN_REJECT_STRENGTH,
        float(profile.get("soft_green_strength", GREEN_KEY_SOFT_MIN)) + 0.75,
    )
    candidate = (
        lookup[codes]
        & (generic_alpha >= 72)
        & (strength <= recovery_green_limit)
    )

    strong = keyed_alpha >= 72
    ys, xs = np.where(strong)
    if not len(xs):
        return keyed_alpha

    x1 = max(0, int(xs.min()) - CHARACTER_RECOVERY_BBOX_PAD)
    y1 = max(0, int(ys.min()) - CHARACTER_RECOVERY_BBOX_PAD)
    x2 = min(frame.shape[1], int(xs.max()) + 1 + CHARACTER_RECOVERY_BBOX_PAD)
    y2 = min(frame.shape[0], int(ys.max()) + 1 + CHARACTER_RECOVERY_BBOX_PAD)
    region = np.zeros_like(candidate, dtype=bool)
    region[y1:y2, x1:x2] = True
    candidate &= region

    seed_small = Image.fromarray(
        (strong.astype(np.uint8) * 255),
        "L",
    ).resize(
        (COMPONENT_GRID_W, COMPONENT_GRID_H),
        Image.Resampling.NEAREST,
    )
    near_small = seed_small.filter(
        ImageFilter.MaxFilter(CHARACTER_RECOVERY_FILTER)
    )
    near = np.array(
        near_small.resize(
            (frame.shape[1], frame.shape[0]),
            Image.Resampling.NEAREST,
        ),
        dtype=np.uint8,
    ) >= 128

    recovered = keyed_alpha.copy()
    add = candidate & near
    recovered[add] = np.maximum(
        recovered[add],
        generic_alpha[add],
    )
    return recovered


def clean_and_key_green_action(
    frame: np.ndarray,
    action_id: str,
) -> tuple[Image.Image, tuple[int, int, int, int] | None]:
    """Green-only key for yawn/sleep-down with processed-idle colour protection."""
    profile = GREEN_KEY_PROFILES.get(action_id, {})
    soft = float(profile.get("soft_green_strength", GREEN_KEY_SOFT_MIN))
    hard = float(profile.get("hard_green_strength", GREEN_KEY_HARD_MIN))
    hard = max(hard, soft + 0.5)

    cleaned = frame.copy()
    rgb = cleaned.astype(np.float32)
    strength = green_strength(rgb)

    chroma_confidence = np.clip(
        (strength - soft) / (hard - soft),
        0.0,
        1.0,
    )

    palette_values = profile.get("background_palette_rgb", [])
    if palette_values:
        palette = np.array(palette_values, dtype=np.float32)
        palette_dist = np.full(strength.shape, np.inf, dtype=np.float32)
        for color in palette:
            palette_dist = np.minimum(
                palette_dist,
                np.linalg.norm(
                    rgb - color.reshape((1, 1, 3)),
                    axis=2,
                ),
            )
        palette_match = 1.0 - np.clip(
            (palette_dist - GREEN_KEY_PALETTE_START) / GREEN_KEY_PALETTE_RANGE,
            0.0,
            1.0,
        )
        weak_green_gate = np.clip(
            (strength - 0.20) / max(0.75, soft + 0.55),
            0.0,
            1.0,
        )
        background_confidence = np.maximum(
            chroma_confidence,
            palette_match * weak_green_gate,
        )
    else:
        background_confidence = chroma_confidence

    brightness_gate = np.clip(
        (rgb[..., 1] - GREEN_KEY_MIN_CHANNEL) / 22.0,
        0.0,
        1.0,
    )
    background_confidence *= brightness_gate

    if GREEN_KEY_MASK_BLUR_RADIUS > 0.0:
        confidence_image = Image.fromarray(
            np.round(background_confidence * 255.0).astype(np.uint8),
            "L",
        ).filter(ImageFilter.GaussianBlur(GREEN_KEY_MASK_BLUR_RADIUS))
        background_confidence = (
            np.array(confidence_image, dtype=np.float32) / 255.0
        )

    alpha = np.round(
        (1.0 - np.clip(background_confidence, 0.0, 1.0)) * 255.0
    ).astype(np.uint8)

    alpha = recover_character_colors(cleaned, alpha, profile)

    strong = alpha >= 72
    component_bbox = largest_component_bbox(strong)
    if component_bbox is not None:
        x1, y1, x2, y2 = component_bbox
        keep = np.zeros_like(alpha, dtype=bool)
        keep[y1:y2, x1:x2] = True
        alpha[~keep] = 0

    rgba = np.dstack([cleaned, alpha])
    rr = rgba[..., 0].astype(np.int16)
    gg = rgba[..., 1].astype(np.int16)
    bb = rgba[..., 2].astype(np.int16)
    semi = (alpha > 0) & (gg > np.maximum(rr, bb) + 6)
    cap = np.maximum(rr, bb) + 6
    gg[semi] = np.minimum(gg[semi], cap[semi])
    rgba[..., 1] = np.clip(gg, 0, 255).astype(np.uint8)
    rgba[alpha == 0, :3] = 0

    strong = alpha >= 72
    ys, xs = np.where(strong)
    bbox = None
    if len(xs):
        bbox = (
            int(xs.min()),
            int(ys.min()),
            int(xs.max() + 1),
            int(ys.max() + 1),
        )
    return Image.fromarray(rgba, "RGBA"), bbox


def clean_and_key_for_action(
    frame: np.ndarray,
    action_id: str,
) -> tuple[Image.Image, tuple[int, int, int, int] | None]:
    if action_id in GREEN_KEY_ACTION_IDS:
        return clean_and_key_green_action(frame, action_id)
    return clean_and_key(frame)


def sample_indices(frame_count: int, source_fps: float) -> list[int]:
    if frame_count <= 0:
        return []
    step = max(1, round(source_fps / TARGET_FPS)) if source_fps > 0 else 2
    indices = list(range(0, frame_count, step))
    if indices[-1] != frame_count - 1:
        indices.append(frame_count - 1)
    return indices


def derive_anchor(
    meta: dict,
    raw_frames: list[bytes],
    target_identity_core_width: float | None = None,
    action_id: str = "idle",
) -> dict:
    w, h = meta["size"]
    fps = float(meta.get("fps", 24.0) or 24.0)
    indices = sample_indices(len(raw_frames), fps)
    first_second_count = max(4, round(TARGET_FPS))
    bboxes = []
    core_widths: list[float] = []
    for idx in indices[:first_second_count]:
        frame = np.frombuffer(raw_frames[idx], dtype=np.uint8).reshape((h, w, 3)).copy()
        keyed, bbox = clean_and_key_for_action(frame, action_id)
        if bbox is not None:
            bboxes.append(bbox)
        core_width = character_core_width(keyed)
        if core_width is not None:
            core_widths.append(core_width)
    if not bboxes:
        raise RuntimeError("Unable to derive character anchor from video")

    centers = [(b[0] + b[2]) / 2.0 for b in bboxes]
    bottoms = [float(b[3]) for b in bboxes]
    heights = [float(b[3] - b[1]) for b in bboxes]
    widths = [float(b[2] - b[0]) for b in bboxes]

    center_x = float(np.median(centers))
    bottom_y = float(np.median(bottoms))
    visible_height = float(np.median(heights))
    visible_width = float(np.median(widths))
    source_identity_core_width = (
        float(np.median(core_widths))
        if core_widths
        else None
    )
    height_scale = TARGET_VISIBLE_HEIGHT / visible_height

    # Idle defines the physical character scale. Other actions match the stable
    # upper-body/head silhouette instead of their full pose envelope, so raised
    # arms, hair, props or a wider stance do not make the character shrink.
    if target_identity_core_width is None or not source_identity_core_width:
        uniform_scale = height_scale
        target_identity_core_width = (
            source_identity_core_width * uniform_scale
            if source_identity_core_width
            else visible_width * uniform_scale
        )
    else:
        uniform_scale = target_identity_core_width / source_identity_core_width

    return {
        "source_center_x": center_x,
        "source_bottom_y": bottom_y,
        "source_visible_height": visible_height,
        "source_visible_width": visible_width,
        "identity_core_width": source_identity_core_width,
        "target_identity_core_width": float(target_identity_core_width),
        "scale_x": uniform_scale,
        "scale_y": uniform_scale,
        "target_visible_width": float(visible_width * uniform_scale),
        "target_visible_height": float(visible_height * uniform_scale),
        "target_center_x": TARGET_CENTER_X,
        "target_bottom_y": TARGET_BOTTOM_Y,
    }


def _rgba_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = np.array(image.getchannel("A"), dtype=np.uint8)
    ys, xs = np.where(alpha >= HIT_ALPHA_THRESHOLD)
    if not len(xs):
        return None
    return (int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1))


def _subject_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = np.array(image.getchannel("A"), dtype=np.uint8)
    return largest_component_bbox(alpha >= HIT_ALPHA_THRESHOLD)


def _largest_true_run(row: np.ndarray) -> int:
    padded = np.pad(row.astype(np.int8), (1, 1), constant_values=0)
    changes = np.diff(padded)
    starts = np.where(changes == 1)[0]
    ends = np.where(changes == -1)[0]
    if not len(starts):
        return 0
    return int(np.max(ends - starts))


def character_core_width(image: Image.Image) -> float | None:
    """Estimate identity scale from the upper-body/head silhouette, not pose bbox."""
    bbox = _subject_bbox(image)
    if bbox is None:
        return None
    x1, y1, x2, y2 = bbox
    height = max(1, y2 - y1)
    band_y1 = max(y1, round(y1 + height * CORE_BAND_TOP_RATIO))
    band_y2 = min(y2, round(y1 + height * CORE_BAND_BOTTOM_RATIO))
    if band_y2 <= band_y1:
        return None

    alpha = np.array(image.getchannel("A"), dtype=np.uint8)
    mask = alpha >= HIT_ALPHA_THRESHOLD
    widths = [
        _largest_true_run(mask[y, x1:x2])
        for y in range(band_y1, band_y2)
    ]
    widths = [width for width in widths if width > 0]
    if not widths:
        return None
    return float(np.percentile(widths, CORE_WIDTH_PERCENTILE))


def character_face_height(image: Image.Image) -> float | None:
    """Estimate face scale from the central pale-skin region of the upper head."""
    bbox = _subject_bbox(image)
    if bbox is None:
        return None
    x1, y1, x2, y2 = bbox
    width = max(1, x2 - x1)
    height = max(1, y2 - y1)
    center_x = (x1 + x2) / 2.0
    region_x1 = max(x1, int(center_x - width * FACE_REGION_HALF_WIDTH_RATIO))
    region_x2 = min(x2, int(center_x + width * FACE_REGION_HALF_WIDTH_RATIO))
    region_y1 = y1
    region_y2 = min(y2, int(y1 + height * FACE_REGION_BOTTOM_RATIO))
    if region_x2 <= region_x1 or region_y2 <= region_y1:
        return None

    rgba = np.array(image.convert("RGBA"), dtype=np.uint8)
    rgb = rgba[..., :3].astype(np.int16)
    alpha = rgba[..., 3]
    red = rgb[..., 0]
    green = rgb[..., 1]
    blue = rgb[..., 2]
    mask = (
        (alpha > HIT_ALPHA_THRESHOLD)
        & (red > FACE_SKIN_R_MIN)
        & (green > FACE_SKIN_G_MIN)
        & (green < FACE_SKIN_G_MAX)
        & (blue > FACE_SKIN_B_MIN)
        & (blue < FACE_SKIN_B_MAX)
        & ((red - green) > FACE_SKIN_R_MINUS_G_MIN)
    )
    roi = mask[region_y1:region_y2, region_x1:region_x2]
    ys, xs = np.where(roi)
    if not len(xs):
        return None
    return float(ys.max() - ys.min() + 1)


def derive_character_face_height(
    meta: dict,
    raw_frames: list[bytes],
    action_id: str,
    *,
    from_end: bool = False,
) -> float | None:
    w, h = meta["size"]
    fps = float(meta.get("fps", 24.0) or 24.0)
    indices = sample_indices(len(raw_frames), fps)
    sample_count = min(max(4, round(TARGET_FPS)), len(indices))
    selected = indices[-sample_count:] if from_end else indices[:sample_count]
    heights: list[float] = []
    for idx in selected:
        frame = np.frombuffer(raw_frames[idx], dtype=np.uint8).reshape((h, w, 3)).copy()
        keyed, _ = clean_and_key_for_action(frame, action_id)
        face_height = character_face_height(keyed)
        if face_height is not None:
            heights.append(face_height)
    if not heights:
        return None
    return float(np.median(heights))


def derive_subject_width(
    meta: dict,
    raw_frames: list[bytes],
    action_id: str,
    *,
    from_end: bool = False,
) -> float | None:
    w, h = meta["size"]
    fps = float(meta.get("fps", 24.0) or 24.0)
    indices = sample_indices(len(raw_frames), fps)
    sample_count = min(max(4, round(TARGET_FPS)), len(indices))
    selected = indices[-sample_count:] if from_end else indices[:sample_count]
    widths: list[float] = []
    for idx in selected:
        frame = np.frombuffer(raw_frames[idx], dtype=np.uint8).reshape((h, w, 3)).copy()
        keyed, _ = clean_and_key_for_action(frame, action_id)
        bbox = _subject_bbox(keyed)
        if bbox is not None:
            widths.append(float(bbox[2] - bbox[0]))
    if not widths:
        return None
    return float(np.median(widths))


def derive_character_core_width(
    meta: dict,
    raw_frames: list[bytes],
    action_id: str,
    *,
    from_end: bool = False,
) -> float | None:
    w, h = meta["size"]
    fps = float(meta.get("fps", 24.0) or 24.0)
    indices = sample_indices(len(raw_frames), fps)
    sample_count = min(max(4, round(TARGET_FPS)), len(indices))
    selected = indices[-sample_count:] if from_end else indices[:sample_count]
    widths: list[float] = []
    for idx in selected:
        frame = np.frombuffer(raw_frames[idx], dtype=np.uint8).reshape((h, w, 3)).copy()
        keyed, _ = clean_and_key_for_action(frame, action_id)
        width = character_core_width(keyed)
        if width is not None:
            widths.append(width)
    if not widths:
        return None
    return float(np.median(widths))


def derive_sleep_layout_profile(
    meta: dict,
    raw_frames: list[bytes],
    action_id: str,
    target_identity_core_width: float,
    start_scale_override: float | None = None,
    end_scale_override: float | None = None,
) -> dict:
    """Keep sleeping poses fully visible and let wake-up finish at idle scale."""
    w, h = meta["size"]
    fps = float(meta.get("fps", 24.0) or 24.0)
    indices = sample_indices(len(raw_frames), fps)
    sample_count = min(max(4, round(TARGET_FPS)), len(indices))

    def sample_bboxes(selected: list[int]) -> list[tuple[int, int, int, int]]:
        boxes: list[tuple[int, int, int, int]] = []
        for idx in selected:
            frame = np.frombuffer(raw_frames[idx], dtype=np.uint8).reshape((h, w, 3)).copy()
            keyed, _ = clean_and_key_for_action(frame, action_id)
            bbox = _subject_bbox(keyed)
            if bbox is not None:
                boxes.append(bbox)
        return boxes

    start_boxes = sample_bboxes(indices[:sample_count])
    end_boxes = sample_bboxes(indices[-sample_count:])
    if not start_boxes:
        raise RuntimeError(f"Unable to derive sleep layout for {action_id}")

    start_width = float(np.median([b[2] - b[0] for b in start_boxes]))
    start_height = float(np.median([b[3] - b[1] for b in start_boxes]))
    start_center_x = float(np.median([(b[0] + b[2]) / 2.0 for b in start_boxes]))
    start_bottom_y = float(np.median([b[3] for b in start_boxes]))
    start_core_width = derive_character_core_width(meta, raw_frames, action_id)
    end_core_width = derive_character_core_width(
        meta,
        raw_frames,
        action_id,
        from_end=True,
    )
    start_scale = (
        float(start_scale_override)
        if start_scale_override is not None
        else (
            target_identity_core_width / start_core_width
            if start_core_width and start_core_width > 0.0
            else TARGET_VISIBLE_HEIGHT / max(1.0, start_height)
        )
    )

    if action_id == "wake_up" and end_boxes:
        end_height = float(np.median([b[3] - b[1] for b in end_boxes]))
        end_width = float(np.median([b[2] - b[0] for b in end_boxes]))
        end_scale = (
            float(end_scale_override)
            if end_scale_override is not None
            else (
                target_identity_core_width / end_core_width
                if end_core_width and end_core_width > 0.0
                else TARGET_VISIBLE_HEIGHT / max(1.0, end_height)
            )
        )
    else:
        end_height = start_height
        end_width = start_width
        end_scale = start_scale

    return {
        "source_center_x": start_center_x,
        "source_bottom_y": start_bottom_y,
        "source_visible_height": start_height,
        "source_visible_width": start_width,
        "scale_x": start_scale,
        "scale_y": start_scale,
        "target_visible_width": start_width * start_scale,
        "target_visible_height": start_height * start_scale,
        "target_center_x": TARGET_CENTER_X,
        "target_bottom_y": TARGET_BOTTOM_Y,
        "layout_mode": "sleep_loop_fixed" if action_id == "sleep_loop" else "wake_progressive",
        "start_scale": start_scale,
        "end_scale": end_scale,
        "end_source_visible_width": end_width,
        "end_source_visible_height": end_height,
        "identity_core_width": start_core_width,
        "end_identity_core_width": end_core_width,
        "target_identity_core_width": target_identity_core_width,
    }


def _sleep_layout_geometry(
    image: Image.Image,
) -> tuple[float, float, float] | None:
    """Return body anchor plus the largest safe scale for the current frame."""
    subject = _subject_bbox(image)
    full = _rgba_bbox(image)
    if subject is None or full is None:
        return None

    sx1, sy1, sx2, sy2 = subject
    fx1, fy1, fx2, fy2 = full
    center_x = (sx1 + sx2) / 2.0
    bottom_y = float(sy2)

    left = max(1.0, center_x - fx1)
    right = max(1.0, fx2 - center_x)
    top = max(1.0, bottom_y - fy1)
    below = max(0.0, fy2 - bottom_y)
    caps = [
        (TARGET_CENTER_X - SLEEP_LAYOUT_MARGIN) / left,
        (CANVAS_WIDTH - SLEEP_LAYOUT_MARGIN - TARGET_CENTER_X) / right,
        (TARGET_BOTTOM_Y - SLEEP_LAYOUT_MARGIN) / top,
    ]
    if below > 0.0:
        caps.append(
            (CANVAS_HEIGHT - SLEEP_LAYOUT_MARGIN - TARGET_BOTTOM_Y) / below
        )
    return center_x, bottom_y, max(0.01, min(caps))


def cleanup_sleep_loop_detached_artifacts(image: Image.Image) -> Image.Image:
    """Keep character/Zzz and remove even faint detached watermark residue."""
    alpha = np.array(image.getchannel("A"), dtype=np.uint8)
    grid_w, grid_h = SLEEP_LOOP_COMPONENT_GRID
    grid_mask = (
        np.array(
            Image.fromarray(
                (alpha >= HIT_ALPHA_THRESHOLD).astype(np.uint8) * 255,
                "L",
            ).resize(
                (grid_w, grid_h),
                Image.Resampling.NEAREST,
            ),
            dtype=np.uint8,
        )
        > 0
    )

    visited = np.zeros_like(grid_mask, dtype=bool)
    components: list[list[tuple[int, int]]] = []
    for y in range(grid_h):
        for x in range(grid_w):
            if not grid_mask[y, x] or visited[y, x]:
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
                        and grid_mask[ny, nx]
                        and not visited[ny, nx]
                    ):
                        visited[ny, nx] = True
                        queue.append((ny, nx))
            components.append(pixels)

    if not components:
        return image

    main_index = max(range(len(components)), key=lambda idx: len(components[idx]))
    protected_grid = np.zeros((grid_h, grid_w), dtype=np.uint8)

    for py, px in components[main_index]:
        protected_grid[py, px] = 255

    # Zzz is intentionally detached from the character. Protect both its strong
    # pixels and the whole approved region so soft anti-aliased edges survive.
    zzz_x1, zzz_x2 = SLEEP_LOOP_ZZZ_KEEP_X
    zzz_y1, zzz_y2 = SLEEP_LOOP_ZZZ_KEEP_Y
    protected_grid[zzz_y1:zzz_y2, zzz_x1:zzz_x2] = 255

    protected = Image.fromarray(protected_grid, "L").resize(
        image.size,
        Image.Resampling.NEAREST,
    )
    protected = protected.filter(
        ImageFilter.MaxFilter(SLEEP_LOOP_PROTECT_DILATE)
    )
    keep = np.array(protected, dtype=np.uint8) > 0

    rgba = np.array(image, dtype=np.uint8)
    # The old strong-component pass could miss alpha<72 watermark ghosts.
    # Clearing every pixel outside the protected silhouette removes those
    # low-alpha remnants without touching the character or Zzz.
    rgba[~keep] = 0

    # A tiny gray/gray-brown watermark remnant can sit inside the protection
    # dilation immediately below the trailing skirt. In this narrow known band,
    # remove only bright low-chroma pixels; the costume is either much darker
    # or distinctly pink/black and therefore does not match.
    x1, x2 = SLEEP_LOOP_WATERMARK_X
    y1, y2 = SLEEP_LOOP_WATERMARK_Y
    region = rgba[y1:y2, x1:x2]
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
        watermark_like = (alpha_region > 0) & (cool_neutral | warm_neutral)
        region[watermark_like] = 0
        rgba[y1:y2, x1:x2] = region

    return Image.fromarray(rgba, "RGBA")


def cleanup_detached_small_artifacts(image: Image.Image) -> Image.Image:
    """Remove tiny distant watermark fragments while preserving nearby details and props."""
    alpha = np.array(image.getchannel("A"), dtype=np.uint8)
    grid_w, grid_h = SLEEP_LOOP_COMPONENT_GRID
    grid_mask = (
        np.array(
            Image.fromarray(
                (alpha >= HIT_ALPHA_THRESHOLD).astype(np.uint8) * 255,
                "L",
            ).resize(
                (grid_w, grid_h),
                Image.Resampling.NEAREST,
            ),
            dtype=np.uint8,
        )
        > 0
    )

    visited = np.zeros_like(grid_mask, dtype=bool)
    components: list[list[tuple[int, int]]] = []
    for y in range(grid_h):
        for x in range(grid_w):
            if not grid_mask[y, x] or visited[y, x]:
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
                        and grid_mask[ny, nx]
                        and not visited[ny, nx]
                    ):
                        visited[ny, nx] = True
                        queue.append((ny, nx))
            components.append(pixels)

    if not components:
        return image

    main = max(components, key=len)
    main_xs = [px for _py, px in main]
    main_ys = [py for py, _px in main]
    main_bbox = (
        min(main_xs),
        min(main_ys),
        max(main_xs) + 1,
        max(main_ys) + 1,
    )
    expanded_main = (
        max(0, main_bbox[0] - DETACHED_COMPONENT_NEAR_MAIN_PAD),
        max(0, main_bbox[1] - DETACHED_COMPONENT_NEAR_MAIN_PAD),
        min(grid_w, main_bbox[2] + DETACHED_COMPONENT_NEAR_MAIN_PAD),
        min(grid_h, main_bbox[3] + DETACHED_COMPONENT_NEAR_MAIN_PAD),
    )

    protected_grid = np.zeros((grid_h, grid_w), dtype=np.uint8)
    for pixels in components:
        xs = [px for _py, px in pixels]
        ys = [py for py, _px in pixels]
        bbox = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
        near_main = not (
            bbox[2] < expanded_main[0]
            or bbox[0] > expanded_main[2]
            or bbox[3] < expanded_main[1]
            or bbox[1] > expanded_main[3]
        )
        if pixels is main or len(pixels) >= DETACHED_COMPONENT_MIN_GRID_PIXELS or near_main:
            for py, px in pixels:
                protected_grid[py, px] = 255

    protected = Image.fromarray(protected_grid, "L").resize(
        image.size,
        Image.Resampling.NEAREST,
    )
    protected = protected.filter(
        ImageFilter.MaxFilter(DETACHED_COMPONENT_PROTECT_DILATE)
    )
    keep = np.array(protected, dtype=np.uint8) > 0
    rgba = np.array(image, dtype=np.uint8)
    rgba[~keep] = 0
    return Image.fromarray(rgba, "RGBA")


def render_sleep_layout_canvas(
    image: Image.Image,
    profile: dict,
    action_id: str,
    frame_index: int,
    frame_count: int,
    *,
    endpoint_scale: float = 1.0,
    endpoint_shift_x: float = 0.0,
    endpoint_shift_y: float = 0.0,
) -> Image.Image:
    geometry = _sleep_layout_geometry(image)
    if geometry is None:
        return Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (0, 0, 0, 0))

    center_x, bottom_y, scale_cap = geometry

    start_scale = float(profile.get("start_scale", profile["scale_x"]))

    # New wake-up video has no source camera zoom. Apply exactly one
    # uniform physical scale for its full duration; natural pose changes
    # come from the source frames, not generated per-frame zoom corrections.
    if action_id == "wake_up":
        scale = max(start_scale, 0.01)
    else:
        scale = max(min(start_scale, scale_cap) * endpoint_scale, 0.01)

    rw = max(1, round(image.width * scale))
    rh = max(1, round(image.height * scale))
    resized = image.resize((rw, rh), Image.Resampling.LANCZOS)
    paste_x = round(TARGET_CENTER_X + endpoint_shift_x - center_x * scale)
    paste_y = round(TARGET_BOTTOM_Y + endpoint_shift_y - bottom_y * scale)
    canvas = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (paste_x, paste_y))
    return canvas


def render_canvas(
    image: Image.Image,
    anchor: dict,
    scale_multiplier: float = 1.0,
) -> Image.Image:
    scale_x = float(anchor["scale_x"]) * scale_multiplier
    scale_y = float(anchor["scale_y"]) * scale_multiplier
    source_center_x = float(anchor["source_center_x"])
    source_bottom_y = float(anchor["source_bottom_y"])
    rw = max(1, round(image.width * scale_x))
    rh = max(1, round(image.height * scale_y))
    resized = image.resize((rw, rh), Image.Resampling.LANCZOS)

    target_center_x = float(anchor.get("target_center_x", TARGET_CENTER_X))
    target_bottom_y = float(anchor.get("target_bottom_y", TARGET_BOTTOM_Y))
    paste_x = round(target_center_x - source_center_x * scale_x)
    paste_y = round(target_bottom_y - source_bottom_y * scale_y)
    canvas = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (paste_x, paste_y))
    return canvas


def bbox_from_canvas(canvas: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = np.array(canvas.getchannel("A"), dtype=np.uint8)
    ys, xs = np.where(alpha >= 72)
    if not len(xs):
        return None
    return (int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1))


def sequence_union_bbox(frames: list[Image.Image]) -> tuple[int, int, int, int] | None:
    bboxes = [bbox_from_canvas(frame) for frame in frames]
    valid = [bbox for bbox in bboxes if bbox is not None]
    if not valid:
        return None
    return (
        min(b[0] for b in valid),
        min(b[1] for b in valid),
        max(b[2] for b in valid),
        max(b[3] for b in valid),
    )


def _translate_rgba(image: Image.Image, dx: int, dy: int) -> Image.Image:
    if dx == 0 and dy == 0:
        return image
    canvas = Image.new("RGBA", image.size, (0, 0, 0, 0))
    src_x1 = max(0, -dx)
    src_y1 = max(0, -dy)
    dst_x1 = max(0, dx)
    dst_y1 = max(0, dy)
    width = min(image.width - src_x1, canvas.width - dst_x1)
    height = min(image.height - src_y1, canvas.height - dst_y1)
    if width <= 0 or height <= 0:
        return canvas
    region = image.crop((src_x1, src_y1, src_x1 + width, src_y1 + height))
    canvas.alpha_composite(region, (dst_x1, dst_y1))
    return canvas


def fit_sequence_to_canvas(
    frames: list[Image.Image],
    margin: int = 8,
) -> tuple[list[Image.Image], dict]:
    """Keep the motion envelope positioned safely without resizing the character."""
    union = sequence_union_bbox(frames)
    if union is None:
        return frames, {"scale": 1.0, "shift": [0, 0], "margin": margin}

    # Character scale is authoritative. Canvas fitting may translate the whole
    # sequence, but must never shrink/enlarge it to fit the viewport.
    adjusted = frames
    fit_scale = 1.0

    x1, y1, x2, y2 = union
    dx = 0
    dy = 0
    if x1 < margin:
        dx = margin - x1
    elif x2 > CANVAS_WIDTH - margin:
        dx = CANVAS_WIDTH - margin - x2
    if y1 < margin:
        dy = margin - y1
    elif y2 > CANVAS_HEIGHT - margin:
        dy = CANVAS_HEIGHT - margin - y2

    if dx != 0 or dy != 0:
        adjusted = [_translate_rgba(frame, dx, dy) for frame in adjusted]

    return adjusted, {
        "scale": fit_scale,
        "shift": [dx, dy],
        "margin": margin,
    }


def hit_polygon_from_frame(image: Image.Image) -> list[list[int]]:
    """Build a compact Y-monotone click polygon from the frame alpha."""
    alpha = np.array(image.getchannel("A"), dtype=np.uint8)
    mask = alpha >= HIT_ALPHA_THRESHOLD
    ys, xs = np.where(mask)
    if not len(xs):
        return []

    y_min = int(ys.min())
    y_max = int(ys.max())
    sample_ys = list(range(y_min, y_max + 1, HIT_ROW_STEP_PX))
    if not sample_ys or sample_ys[-1] != y_max:
        sample_ys.append(y_max)

    rows: list[tuple[int, int, int]] = []
    for y in sample_ys:
        band_y1 = max(0, y - HIT_BAND_HALF_PX)
        band_y2 = min(CANVAS_HEIGHT, y + HIT_BAND_HALF_PX + 1)
        columns = np.where(np.any(mask[band_y1:band_y2], axis=0))[0]
        if not len(columns):
            continue
        left = max(0, int(columns.min()) - HIT_PADDING_PX)
        right = min(CANVAS_WIDTH - 1, int(columns.max()) + HIT_PADDING_PX)
        rows.append((y, left, right))

    if not rows:
        return []

    smoothed: list[tuple[int, int, int]] = []
    for index, (y, _left, _right) in enumerate(rows):
        lo = max(0, index - 1)
        hi = min(len(rows), index + 2)
        lefts = [rows[i][1] for i in range(lo, hi)]
        rights = [rows[i][2] for i in range(lo, hi)]
        smoothed.append((
            y,
            int(round(float(np.median(lefts)))),
            int(round(float(np.median(rights)))),
        ))

    top_y = max(0, y_min - HIT_PADDING_PX)
    bottom_y = min(CANVAS_HEIGHT - 1, y_max + HIT_PADDING_PX)
    first_y, first_left, first_right = smoothed[0]
    last_y, last_left, last_right = smoothed[-1]
    if first_y != top_y:
        smoothed.insert(0, (top_y, first_left, first_right))
    if last_y != bottom_y:
        smoothed.append((bottom_y, last_left, last_right))

    polygon = (
        [[left, y] for y, left, _right in smoothed]
        + [[right, y] for y, _left, right in reversed(smoothed)]
    )
    compact: list[list[int]] = []
    for point in polygon:
        if not compact or compact[-1] != point:
            compact.append(point)
    if len(compact) >= 2 and compact[0] == compact[-1]:
        compact.pop()
    return compact


def _palette_groups(frames: list[Image.Image]) -> dict[str, np.ndarray]:
    groups: dict[str, list[np.ndarray]] = {
        "all": [],
        "blue": [],
        "pink": [],
        "pale": [],
    }

    for image in frames[:18]:
        rgba = np.array(image.convert("RGBA"), dtype=np.uint8)
        rgb = rgba[..., :3].astype(np.float32)
        alpha = rgba[..., 3]
        mask = alpha >= 220
        if not mask.any():
            continue

        pixels = rgb[mask]
        useful = pixels[np.max(pixels, axis=1) >= 45]
        if not len(useful):
            continue

        groups["all"].append(useful)

        blue = useful[
            (useful[:, 2] > useful[:, 0] * 1.10)
            & (useful[:, 2] > useful[:, 1] * 1.05)
            & (useful[:, 2] > 80)
        ]
        pink = useful[
            (useful[:, 0] > useful[:, 1] * 1.18)
            & (useful[:, 0] > useful[:, 2] * 1.03)
            & (useful[:, 0] > 90)
        ]
        pale = useful[
            (useful[:, 0] > 150)
            & (useful[:, 1] > 120)
            & (useful[:, 2] > 120)
        ]

        if len(blue):
            groups["blue"].append(blue)
        if len(pink):
            groups["pink"].append(pink)
        if len(pale):
            groups["pale"].append(pale)

    merged: dict[str, np.ndarray] = {}
    for label, chunks in groups.items():
        if chunks:
            merged[label] = np.concatenate(chunks, axis=0)
    return merged


def palette_signature(frames: list[Image.Image]) -> dict[str, list[float]]:
    signature: dict[str, list[float]] = {}
    for label, pixels in _palette_groups(frames).items():
        if len(pixels) < 50:
            continue
        signature[label] = [
            float(x)
            for x in np.mean(pixels, axis=0)
        ]
    return signature


def derive_color_affine(
    reference: dict[str, list[float]],
    source: dict[str, list[float]],
) -> dict:
    labels = [
        label
        for label in ("blue", "pink", "pale", "all")
        if label in reference and label in source
    ]
    if len(labels) < 3:
        return {
            "enabled": False,
            "slope": [1.0, 1.0, 1.0],
            "offset": [0.0, 0.0, 0.0],
            "labels": labels,
        }

    source_points = np.array([source[label] for label in labels], dtype=np.float32)
    target_points = np.array([reference[label] for label in labels], dtype=np.float32)

    slopes: list[float] = []
    offsets: list[float] = []
    for channel in range(3):
        x = source_points[:, channel]
        y = target_points[:, channel]
        design = np.column_stack([x, np.ones_like(x)])
        slope, offset = np.linalg.lstsq(design, y, rcond=None)[0]

        # The generated clips only need modest grading correction. Keep the
        # transform conservative so pose/composition differences do not get
        # mistaken for lighting differences.
        slope = float(np.clip(slope, 0.88, 1.08))
        offset = float(np.clip(offset, -15.0, 15.0))
        slopes.append(slope)
        offsets.append(offset)

    return {
        "enabled": True,
        "slope": slopes,
        "offset": offsets,
        "labels": labels,
    }


def apply_color_affine(image: Image.Image, correction: dict) -> Image.Image:
    if not bool(correction.get("enabled", False)):
        return image

    rgba = np.array(image.convert("RGBA"), dtype=np.uint8)
    rgb = rgba[..., :3].astype(np.float32)
    alpha = rgba[..., 3:4]
    slope = np.array(correction["slope"], dtype=np.float32).reshape((1, 1, 3))
    offset = np.array(correction["offset"], dtype=np.float32).reshape((1, 1, 3))

    corrected = np.clip(rgb * slope + offset, 0.0, 255.0).astype(np.uint8)
    corrected[alpha[..., 0] == 0] = 0
    return Image.fromarray(np.dstack([corrected, alpha[..., 0]]), "RGBA")


def derive_semantic_deltas(
    reference: dict[str, list[float]],
    current: dict[str, list[float]],
) -> dict[str, list[float]]:
    deltas: dict[str, list[float]] = {}
    for label in ("blue", "pink", "pale"):
        if label not in reference or label not in current:
            continue
        delta = np.array(reference[label], dtype=np.float32) - np.array(
            current[label],
            dtype=np.float32,
        )
        deltas[label] = [
            float(x)
            for x in np.clip(delta, -8.0, 8.0)
        ]
    return deltas


def apply_semantic_palette_tuning(
    image: Image.Image,
    deltas: dict[str, list[float]],
) -> Image.Image:
    if not deltas:
        return image

    rgba = np.array(image.convert("RGBA"), dtype=np.uint8)
    rgb = rgba[..., :3].astype(np.float32)
    alpha = rgba[..., 3]
    r = rgb[..., 0]
    g = rgb[..., 1]
    b = rgb[..., 2]

    blue_dom = b - np.maximum(r, g)
    pink_dom = r - np.maximum(g, b)
    blue_weight = (
        np.clip((blue_dom - 4.0) / 32.0, 0.0, 1.0)
        * np.clip((b - 70.0) / 110.0, 0.0, 1.0)
    )
    pink_weight = (
        np.clip((pink_dom - 4.0) / 32.0, 0.0, 1.0)
        * np.clip((r - 80.0) / 110.0, 0.0, 1.0)
    )

    minimum = np.minimum(np.minimum(r, g), b)
    maximum = np.maximum(np.maximum(r, g), b)
    chroma = maximum - minimum
    pale_weight = (
        np.clip((minimum - 105.0) / 90.0, 0.0, 1.0)
        * np.clip((95.0 - chroma) / 55.0, 0.0, 1.0)
        * (1.0 - np.maximum(blue_weight, pink_weight))
    )

    correction = np.zeros_like(rgb, dtype=np.float32)
    for label, weight in (
        ("blue", blue_weight),
        ("pink", pink_weight),
        ("pale", pale_weight),
    ):
        if label not in deltas:
            continue
        delta = np.array(deltas[label], dtype=np.float32).reshape((1, 1, 3))
        correction += weight[..., None] * delta

    visible = (alpha > 0)[..., None]
    corrected = np.where(
        visible,
        np.clip(rgb + correction, 0.0, 255.0),
        rgb,
    ).astype(np.uint8)
    corrected[alpha == 0] = 0
    return Image.fromarray(np.dstack([corrected, alpha]), "RGBA")


def _packed_alpha_frame_bytes(image: Image.Image) -> bytes:
    rgba = np.array(image.convert("RGBA"), dtype=np.uint8)
    color = rgba[..., :3]
    alpha = rgba[..., 3:4]
    alpha_rgb = np.repeat(alpha, 3, axis=2)
    packed = np.concatenate([color, alpha_rgb], axis=1)
    return packed.tobytes()


def encode_runtime_video(frames: list[Image.Image], output_path: Path) -> dict:
    """Encode one Godot-native Theora file with RGB + alpha mask side-by-side."""
    if not frames:
        raise RuntimeError("Cannot encode empty runtime video")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = output_path.with_name(output_path.stem + ".tmp" + output_path.suffix)
    if temp_path.exists():
        temp_path.unlink()

    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    packed_width = CANVAS_WIDTH * 2
    command = [
        str(ffmpeg),
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-f",
        "rawvideo",
        "-pix_fmt",
        "rgb24",
        "-s:v",
        f"{packed_width}x{CANVAS_HEIGHT}",
        "-r",
        f"{TARGET_FPS:g}",
        "-i",
        "-",
        "-an",
        "-c:v",
        "libtheora",
        "-q:v",
        str(RUNTIME_VIDEO_QUALITY),
        "-pix_fmt",
        "yuv420p",
        str(temp_path),
    ]
    creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    process = subprocess.Popen(
        command,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        creationflags=creationflags,
    )
    try:
        assert process.stdin is not None
        for frame in frames:
            process.stdin.write(_packed_alpha_frame_bytes(frame))
        process.stdin.close()
        stdout = process.stdout.read() if process.stdout is not None else b""
        stderr = process.stderr.read() if process.stderr is not None else b""
        process.wait()
    except Exception:
        process.kill()
        process.wait()
        if temp_path.exists():
            temp_path.unlink()
        raise

    if process.returncode != 0 or not temp_path.is_file():
        detail = (stderr or stdout or b"").decode("utf-8", errors="replace").strip()
        if temp_path.exists():
            temp_path.unlink()
        raise RuntimeError(
            "Runtime Theora encode failed"
            + (f": {detail[-2000:]}" if detail else "")
        )
    temp_path.replace(output_path)
    relative_path = output_path.relative_to(GODOT_PROJECT).as_posix()
    return {
        "path": relative_path,
        "resource_path": "res://" + relative_path,
        "codec": "theora",
        "alpha_mode": "side_by_side_rgb_alpha",
        "packed_size": [packed_width, CANVAS_HEIGHT],
        "display_size": [CANVAS_WIDTH, CANVAS_HEIGHT],
        "fps": TARGET_FPS,
        "frame_count": len(frames),
        "bytes": output_path.stat().st_size,
    }


def build_contact(action_id: str, frames: list[Image.Image]) -> str | None:
    if not frames:
        return None
    REVIEW_ROOT.mkdir(parents=True, exist_ok=True)
    picks = [0, round((len(frames) - 1) * 0.25), round((len(frames) - 1) * 0.5),
             round((len(frames) - 1) * 0.75), len(frames) - 1]
    tile_width = CANVAS_WIDTH
    tile_height = CANVAS_HEIGHT
    sheet = Image.new("RGB", (tile_width * len(picks), tile_height + 28), (238, 238, 238))
    draw = ImageDraw.Draw(sheet)
    for i, idx in enumerate(picks):
        rgba = frames[idx]
        bg = Image.new("RGBA", rgba.size, (238, 238, 238, 255))
        bg.alpha_composite(rgba)
        sheet.paste(bg.convert("RGB"), (i * tile_width, 0))
        draw.text((i * tile_width + 8, tile_height + 7), f"frame {idx}", fill="black")
    out = REVIEW_ROOT / f"{action_id}_processed_contact.jpg"
    sheet.save(out, "JPEG", quality=88, optimize=True)
    return out.relative_to(ROOT).as_posix()


def key_manifest_config(action_id: str) -> dict:
    if action_id in GREEN_KEY_ACTION_IDS:
        return {
            "method": "idle_protected_adaptive_green_chroma",
            "background_rule": (
                "green-dominant source colours only; neutral/gray colours are not "
                "background by themselves; approved processed-idle colours are protected"
            ),
            "green_profile": GREEN_KEY_PROFILES.get(action_id, {}),
            "character_protection": {
                **CHARACTER_PROTECTION_META,
                "recovery_filter": CHARACTER_RECOVERY_FILTER,
                "recovery_bbox_pad": CHARACTER_RECOVERY_BBOX_PAD,
            },
        }
    return {
        "method": "edge_median_distance_initial",
        "alpha_start": ALPHA_START,
        "alpha_range": ALPHA_RANGE,
        "background_rule": "single edge-median background color; per-action exceptions are handled separately",
    }


for item in ACTIONS:
    if not item["source"].exists():
        raise FileNotFoundError(item["source"])
if not IDLE_ACTION["source"].exists():
    raise FileNotFoundError(IDLE_ACTION["source"])

# Idle is always available as a read-only reference. In a partial build that
# does not explicitly request idle, reuse its approved manifest instead of
# rewriting any idle PNG or manifest.
idle_meta, idle_raw = read_video(IDLE_ACTION["source"])
if PARTIAL_BUILD and "idle" not in _requested_actions:
    idle_manifest = json.loads(
        IDLE_ACTION["manifest"].read_text(encoding="utf-8")
    )
    idle_anchor = dict(idle_manifest["transform"])
    if (
        "target_identity_core_width" not in idle_anchor
        or abs(float(idle_anchor.get("target_visible_height", 0.0)) - TARGET_VISIBLE_HEIGHT) > 0.5
    ):
        idle_anchor = derive_anchor(idle_meta, idle_raw, action_id="idle")
    idle_palette_reference: dict[str, list[float]] | None = dict(
        idle_manifest["color_normalization"]["corrected_palette"]
    )
else:
    idle_anchor = derive_anchor(idle_meta, idle_raw, action_id="idle")
    idle_palette_reference = None

target_identity_core_width = float(idle_anchor["target_identity_core_width"])

if any(item["id"] in GREEN_KEY_ACTION_IDS for item in ACTIONS):
    (
        CHARACTER_PROTECTION_LOOKUP,
        CHARACTER_PROTECTION_META,
    ) = build_character_protection_lookup_from_idle()
else:
    CHARACTER_PROTECTION_LOOKUP = None
    CHARACTER_PROTECTION_META = {}
GREEN_KEY_PROFILES = {}

idle_face_source_height = derive_character_face_height(
    idle_meta,
    idle_raw,
    "idle",
)
target_face_height = (
    float(idle_face_source_height) * float(idle_anchor["scale_x"])
    if idle_face_source_height
    else TARGET_VISIBLE_HEIGHT * 0.44
)

# Calibrate the sleep chain as one continuous physical scale:
# sleep_down end -> sleep_loop -> wake_up start, then wake_up returns to idle.
sleep_chain_scales: dict[str, float] = {}
action_by_id = {item["id"]: item for item in ALL_ACTIONS}
for sleep_action_id in ("sleep_down", "sleep_loop", "wake_up"):
    sleep_item = action_by_id[sleep_action_id]
    sleep_meta, sleep_raw = read_video(sleep_item["source"])
    if sleep_action_id in GREEN_KEY_ACTION_IDS:
        GREEN_KEY_PROFILES[sleep_action_id] = analyze_green_key_profile(
            sleep_meta,
            sleep_raw,
        )
    if sleep_action_id == "sleep_down":
        face_height = derive_character_face_height(
            sleep_meta,
            sleep_raw,
            sleep_action_id,
        )
        if not face_height:
            raise RuntimeError("Unable to derive sleep_down face scale")
        sleep_down_scale = target_face_height / face_height
        end_width = derive_subject_width(
            sleep_meta,
            sleep_raw,
            sleep_action_id,
            from_end=True,
        )
        if not end_width:
            raise RuntimeError("Unable to derive sleep_down end width")
        sleep_chain_scales["sleep_down"] = sleep_down_scale
        sleep_chain_scales["target_lying_width"] = end_width * sleep_down_scale

target_lying_width = float(sleep_chain_scales["target_lying_width"])
for sleep_action_id in ("sleep_loop", "wake_up"):
    sleep_item = action_by_id[sleep_action_id]
    sleep_meta, sleep_raw = read_video(sleep_item["source"])
    start_width = derive_subject_width(
        sleep_meta,
        sleep_raw,
        sleep_action_id,
    )
    if not start_width:
        raise RuntimeError(f"Unable to derive {sleep_action_id} start width")
    sleep_chain_scales[f"{sleep_action_id}_start"] = target_lying_width / start_width

report = {
    "schema_version": 10,
    "partial_build": PARTIAL_BUILD,
    "requested_actions": sorted(_requested_actions),
    "target_fps": TARGET_FPS,
    "canvas": [CANVAS_WIDTH, CANVAS_HEIGHT],
    "normalization": {
        "mode": (
            "fixed_action_scale_with_source_wake"
            if "wake_up" in _requested_actions
            else "fixed_action_scale"
        ),
        "target_visible_height": TARGET_VISIBLE_HEIGHT,
        "target_identity_core_width": target_identity_core_width,
        "target_face_height": target_face_height,
        "target_center_x": TARGET_CENTER_X,
        "target_bottom_y": TARGET_BOTTOM_Y,
        "sleep_chain_scales": sleep_chain_scales,
        "idle_anchor": idle_anchor,
    },
    "actions": [],
}
if PARTIAL_BUILD and HIT_SHAPE_CATALOG.is_file():
    try:
        hit_shape_catalog = json.loads(HIT_SHAPE_CATALOG.read_text(encoding="utf-8"))
    except Exception:
        hit_shape_catalog = {}
else:
    hit_shape_catalog = {}

if not isinstance(hit_shape_catalog, dict):
    hit_shape_catalog = {}
hit_shape_catalog["schema_version"] = 1
hit_shape_catalog["canvas"] = [CANVAS_WIDTH, CANVAS_HEIGHT]
hit_shape_catalog["alpha_threshold"] = HIT_ALPHA_THRESHOLD
hit_shape_catalog["padding_px"] = HIT_PADDING_PX
hit_shape_catalog["row_step_px"] = HIT_ROW_STEP_PX
if not isinstance(hit_shape_catalog.get("actions"), dict):
    hit_shape_catalog["actions"] = {}

sleep_down_output_width: float | None = None
if (
    PARTIAL_BUILD
    and "sleep_down" not in _requested_actions
    and ({"sleep_loop", "wake_up"} & _requested_actions)
):
    sleep_down_last_frame = (
        ASSET_ROOT / "video_sleep_down" / "frames" / "120.png"
    )
    if sleep_down_last_frame.is_file():
        with Image.open(sleep_down_last_frame) as image:
            sleep_down_bbox = bbox_from_canvas(image.convert("RGBA"))
        if sleep_down_bbox is not None:
            sleep_down_output_width = float(
                sleep_down_bbox[2] - sleep_down_bbox[0]
            )
            sleep_chain_scales["target_lying_output_width"] = (
                sleep_down_output_width
            )

for item in ACTIONS:
    source = item["source"]
    meta, raw_frames = (idle_meta, idle_raw) if item["id"] == "idle" else read_video(source)
    w, h = meta["size"]
    source_fps = float(meta.get("fps", 24.0) or 24.0)
    indices = sample_indices(len(raw_frames), source_fps)
    if item["id"] in GREEN_KEY_ACTION_IDS:
        GREEN_KEY_PROFILES[item["id"]] = analyze_green_key_profile(
            meta,
            raw_frames,
        )
    # Each source can frame the same character differently. Derive the action's
    # anchor once, then lock a single physical scale for the whole action.
    if item["id"] == "idle":
        action_anchor = idle_anchor
    elif item["id"] in SLEEP_LAYOUT_ACTION_IDS:
        sleep_start_scale = float(
            sleep_chain_scales[f"{item['id']}_start"]
        )
        if sleep_down_output_width is not None:
            source_start_width = derive_subject_width(
                meta,
                raw_frames,
                item["id"],
            )
            if source_start_width and source_start_width > 0.0:
                sleep_start_scale = (
                    sleep_down_output_width / source_start_width
                )
                sleep_chain_scales[f"{item['id']}_start"] = sleep_start_scale
        action_anchor = derive_sleep_layout_profile(
            meta,
            raw_frames,
            item["id"],
            target_identity_core_width,
            start_scale_override=sleep_start_scale,
            end_scale_override=None,
        )
        if sleep_down_output_width is not None and indices:
            first_frame = np.frombuffer(
                raw_frames[indices[0]],
                dtype=np.uint8,
            ).reshape((h, w, 3)).copy()
            first_keyed, _ = clean_and_key_for_action(
                first_frame,
                item["id"],
            )
            provisional = render_sleep_layout_canvas(
                first_keyed,
                action_anchor,
                item["id"],
                0,
                len(indices),
            )
            provisional_bbox = bbox_from_canvas(provisional)
            if provisional_bbox is not None:
                provisional_width = float(
                    provisional_bbox[2] - provisional_bbox[0]
                )
                if provisional_width > 0.0:
                    correction = sleep_down_output_width / provisional_width
                    action_anchor["start_scale"] = (
                        float(action_anchor["start_scale"]) * correction
                    )
                    action_anchor["scale_x"] = float(action_anchor["start_scale"])
                    action_anchor["scale_y"] = float(action_anchor["start_scale"])
                    if item["id"] == "sleep_loop":
                        action_anchor["end_scale"] = float(
                            action_anchor["start_scale"]
                        )
                    sleep_chain_scales[
                        f"{item['id']}_first_frame_correction"
                    ] = correction
        if item["id"] == "wake_up":
            # One immutable size across the whole regenerated source clip.
            action_anchor["layout_mode"] = "wake_fixed_source_scale"
            action_anchor["end_scale"] = float(action_anchor["start_scale"])
    else:
        action_anchor = derive_anchor(
            meta,
            raw_frames,
            target_identity_core_width,
            action_id=item["id"],
        )
        if item["id"] == "sleep_down":
            fixed_scale = float(sleep_chain_scales["sleep_down"])
            action_anchor["scale_x"] = fixed_scale
            action_anchor["scale_y"] = fixed_scale
            action_anchor["target_visible_width"] = (
                float(action_anchor["source_visible_width"]) * fixed_scale
            )
            action_anchor["target_visible_height"] = (
                float(action_anchor["source_visible_height"]) * fixed_scale
            )
        elif item["id"] not in FACE_NORMALIZE_EXCLUDED_ACTION_IDS:
            source_face_height = derive_character_face_height(
                meta,
                raw_frames,
                item["id"],
            )
            if source_face_height and source_face_height > 0.0:
                base_scale = max(0.001, float(action_anchor["scale_x"]))
                desired_scale = target_face_height / source_face_height
                fixed_scale = float(
                    np.clip(
                        desired_scale,
                        base_scale * FIXED_ACTION_SCALE_MIN_MULTIPLIER,
                        base_scale * FIXED_ACTION_SCALE_MAX_MULTIPLIER,
                    )
                )
                manual_scale_multiplier = float(
                    ACTION_FIXED_SCALE_OVERRIDES.get(item["id"], 1.0)
                )
                fixed_scale *= manual_scale_multiplier
                action_anchor["manual_scale_multiplier"] = manual_scale_multiplier
                action_anchor["scale_x"] = fixed_scale
                action_anchor["scale_y"] = fixed_scale
                action_anchor["target_visible_width"] = (
                    float(action_anchor["source_visible_width"]) * fixed_scale
                )
                action_anchor["target_visible_height"] = (
                    float(action_anchor["source_visible_height"]) * fixed_scale
                )
                action_anchor["source_face_height"] = float(source_face_height)
                action_anchor["target_face_height"] = float(target_face_height)
                action_anchor["fixed_scale"] = fixed_scale

        action_anchor["target_center_x"] = float(
            action_anchor.get("target_center_x", TARGET_CENTER_X)
        ) + float(ACTION_TARGET_CENTER_X_OFFSETS.get(item["id"], 0.0))

    out_dir: Path = item["out_dir"]
    out_dir.mkdir(parents=True, exist_ok=True)
    expected_names = {f"{out_index:03d}.png" for out_index in range(len(indices))}
    # Keep the directory itself so Godot import sidecars are not destroyed.
    # Stale generated frames are removed individually.
    for old_png in out_dir.glob("*.png"):
        if old_png.name in expected_names:
            continue
        old_png.unlink()
        stale_sidecar = Path(str(old_png) + ".import")
        if stale_sidecar.exists():
            stale_sidecar.unlink()

    processed: list[Image.Image] = []
    bboxes = []
    visual_scale_multipliers: list[float] = []

    for _out_index, source_index in enumerate(indices):
        frame = np.frombuffer(raw_frames[source_index], dtype=np.uint8).reshape((h, w, 3)).copy()
        keyed, _ = clean_and_key_for_action(frame, item["id"])
        if item["id"] in SLEEP_LAYOUT_ACTION_IDS:
            # Keep the previously approved sleep-loop position. The new
            # wake-up uses its source pose/scale without artificial zoom or
            # interpolated endpoint size corrections.
            endpoint_scale = 1.0
            endpoint_shift_x = 0.0
            endpoint_shift_y = 3.0 if item["id"] == "sleep_loop" else 0.0
            canvas = render_sleep_layout_canvas(
                keyed,
                action_anchor,
                item["id"],
                _out_index,
                len(indices),
                endpoint_scale=endpoint_scale,
                endpoint_shift_x=endpoint_shift_x,
                endpoint_shift_y=endpoint_shift_y,
            )
            if item["id"] == "sleep_loop":
                canvas = cleanup_sleep_loop_detached_artifacts(canvas)
            visual_scale_multipliers.append(endpoint_scale)
        else:
            # Physical character scale is fixed for the entire action. Do not
            # resize individual frames to chase face/silhouette measurements.
            visual_scale_multipliers.append(1.0)
            canvas = render_canvas(
                keyed,
                action_anchor,
                1.0,
            )
        bbox = bbox_from_canvas(canvas)
        if bbox is not None:
            bboxes.append(bbox)
        processed.append(canvas)

    processed, canvas_fit = fit_sequence_to_canvas(processed, margin=8)
    bboxes = [
        bbox
        for bbox in (bbox_from_canvas(frame) for frame in processed)
        if bbox is not None
    ]

    if item["id"] == "sleep_down" and processed:
        sleep_end_bbox = bbox_from_canvas(processed[-1])
        if sleep_end_bbox is not None:
            sleep_down_output_width = float(
                sleep_end_bbox[2] - sleep_end_bbox[0]
            )
            sleep_chain_scales["target_lying_output_width"] = (
                sleep_down_output_width
            )

    source_palette = palette_signature(processed)
    if item["id"] == "wake_up":
        # Honor the replacement video's authored colours. RGB is only
        # resampled and green-keyed; no idle-referencing palette affine,
        # pink, pale, or skin-tone recolouring is applied.
        color_correction = {
            "enabled": False,
            "slope": [1.0, 1.0, 1.0],
            "offset": [0.0, 0.0, 0.0],
            "labels": list(source_palette),
        }
        semantic_deltas = {}
    elif item["id"] == "idle":
        idle_palette_reference = source_palette
        color_correction = {
            "enabled": False,
            "slope": [1.0, 1.0, 1.0],
            "offset": [0.0, 0.0, 0.0],
            "labels": list(source_palette.keys()),
        }
        semantic_deltas: dict[str, list[float]] = {}
    else:
        if idle_palette_reference is None:
            raise RuntimeError("Idle palette reference was not initialized")
        color_correction = derive_color_affine(
            idle_palette_reference,
            source_palette,
        )
        processed = [
            apply_color_affine(image, color_correction)
            for image in processed
        ]

        interim_palette = palette_signature(processed)
        semantic_deltas = derive_semantic_deltas(
            idle_palette_reference,
            interim_palette,
        )
        processed = [
            apply_semantic_palette_tuning(image, semantic_deltas)
            for image in processed
        ]

    if item["id"] in DETACHED_ARTIFACT_CLEANUP_ACTION_IDS:
        processed = [
            cleanup_detached_small_artifacts(image)
            for image in processed
        ]

    if item["id"] == "sleep_loop":
        # Palette correction can reintroduce a few gray-cyan edge pixels in the
        # watermark region, so enforce cleanup again on the final RGBA frames.
        processed = [
            cleanup_sleep_loop_detached_artifacts(image)
            for image in processed
        ]

    corrected_palette = palette_signature(processed)
    runtime_action_id = RUNTIME_ACTION_IDS[item["id"]]
    hit_polygons = [hit_polygon_from_frame(image) for image in processed]
    hit_shape_catalog["actions"][runtime_action_id] = hit_polygons

    runtime_video = encode_runtime_video(
        processed,
        out_dir.parent / RUNTIME_VIDEO_FILENAME,
    )

    for out_index, canvas in enumerate(processed):
        out_path = out_dir / f"{out_index:03d}.png"
        canvas.save(out_path, "PNG", optimize=True)
    png_bytes = sum(
        png.stat().st_size
        for png in out_dir.glob("*.png")
        if png.is_file()
    )

    valid = bboxes
    union = None
    min_margin = None
    if valid:
        union = [
            min(b[0] for b in valid),
            min(b[1] for b in valid),
            max(b[2] for b in valid),
            max(b[3] for b in valid),
        ]
        min_margin = min(
            union[0],
            union[1],
            CANVAS_WIDTH - union[2],
            CANVAS_HEIGHT - union[3],
        )

    manifest = {
        "schema_version": 10,
        "source": source.relative_to(ROOT).as_posix(),
        "source_size": [w, h],
        "source_fps": source_fps,
        "source_frame_count": len(raw_frames),
        "output_fps": TARGET_FPS,
        "frame_count": len(processed),
        "duration_sec": len(processed) / TARGET_FPS if TARGET_FPS else 0.0,
        "canvas": [CANVAS_WIDTH, CANVAS_HEIGHT],
        "watermark_cleanup": {
            "clear_left_margin_px": LEFT_CLEAN_PX,
            "clear_right_margin_px": RIGHT_CLEAN_PX,
            "component_filter_grid": [COMPONENT_GRID_W, COMPONENT_GRID_H],
            "reason": "no hard side crop; disconnected watermark/background is removed by component filtering",
        },
        "key": key_manifest_config(item["id"]),
        "transform": action_anchor,
        "visual_scale_normalization": {
            "mode": (
                "sleep_chain_fixed_source"
                if item["id"] == "wake_up"
                else (
                    "sleep_chain_fixed"
                    if item["id"] in {"sleep_down", "sleep_loop"}
                    else (
                        "idle_reference"
                        if item["id"] == "idle"
                        else "fixed_action_face_height"
                    )
                )
            ),
            "target_face_height": float(target_face_height),
            "multiplier_min": (
                float(min(visual_scale_multipliers))
                if visual_scale_multipliers
                else 1.0
            ),
            "multiplier_max": (
                float(max(visual_scale_multipliers))
                if visual_scale_multipliers
                else 1.0
            ),
            "multiplier_median": (
                float(np.median(visual_scale_multipliers))
                if visual_scale_multipliers
                else 1.0
            ),
            "sleep_chain_scales": (
                sleep_chain_scales
                if item["id"] in {"sleep_down", "sleep_loop", "wake_up"}
                else {}
            ),
        },
        "canvas_fit": canvas_fit,
        "endpoint_alignment": (
            {"mode": "sleep_loop_fixed_translation", "shift_px": [0, 3]}
            if item["id"] == "sleep_loop"
            else (
                {
                    "mode": "source_camera_stable",
                    "frame_scale": "fixed",
                    "additional_endpoint_zoom": False,
                    "note": "Replacement video preserved without synthetic zoom.",
                }
                if item["id"] == "wake_up"
                else {}
            )
        ),
        "color_normalization": {
            "reference_action": (
                "none_source_video_preserved"
                if item["id"] == "wake_up"
                else "idle"
            ),
            "source_palette": source_palette,
            "correction": color_correction,
            "semantic_deltas": semantic_deltas,
            "corrected_palette": corrected_palette,
        },
        "alpha_bbox_union": union,
        "min_canvas_margin_px": min_margin,
        "hit_shape": {
            "catalog": "res://config/video_hit_shapes.json",
            "action_id": runtime_action_id,
            "frame_count": len(hit_polygons),
            "alpha_threshold": HIT_ALPHA_THRESHOLD,
            "padding_px": HIT_PADDING_PX,
            "row_step_px": HIT_ROW_STEP_PX,
        },
        "runtime_video": runtime_video,
        "png_fallback_bytes": png_bytes,
        "ready_for_runtime": bool(valid) and (min_margin is None or min_margin >= 0),
    }
    item["manifest"].write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    contact = build_contact(item["id"], processed)
    report["actions"].append({
        "id": item["id"],
        "source": manifest["source"],
        "frames_dir": out_dir.relative_to(ROOT).as_posix(),
        "manifest": item["manifest"].relative_to(ROOT).as_posix(),
        "frame_count": manifest["frame_count"],
        "fps": manifest["output_fps"],
        "duration_sec": manifest["duration_sec"],
        "alpha_bbox_union": union,
        "min_canvas_margin_px": min_margin,
        "normalization": action_anchor,
        "canvas_fit": canvas_fit,
        "color_normalization": {
            "affine": color_correction,
            "semantic_deltas": semantic_deltas,
        },
        "corrected_palette": corrected_palette,
        "hit_shape_points": {
            "min": min((len(poly) for poly in hit_polygons if poly), default=0),
            "max": max((len(poly) for poly in hit_polygons if poly), default=0),
        },
        "runtime_video": runtime_video,
        "png_fallback_bytes": png_bytes,
        "compression_ratio_vs_png": (
            round(png_bytes / max(1, int(runtime_video["bytes"])), 2)
        ),
        "contact_sheet": contact,
    })

HIT_SHAPE_CATALOG.write_text(
    json.dumps(hit_shape_catalog, ensure_ascii=False, separators=(",", ":")) + "\n",
    encoding="utf-8",
)
report["hit_shape_catalog"] = HIT_SHAPE_CATALOG.relative_to(ROOT).as_posix()
report["godot_import"] = refresh_godot_imports()
review_json = REVIEW_ROOT / "build_report.json"
REVIEW_ROOT.mkdir(parents=True, exist_ok=True)
review_json.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
