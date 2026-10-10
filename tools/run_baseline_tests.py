  1 | """Run the existing Godot checks in a copied project with isolated user data.
  2 | 
  3 | Uses only Python's standard library. The live project and its user settings are
  4 | hashed before/after. Test workspaces are retained for diagnosis; their paths are
  5 | recorded in report.json. No desktop-pet process is restarted or terminated.
  6 | """
  7 | from __future__ import annotations
  8 | 
  9 | import argparse
 10 | from datetime import datetime, timedelta, timezone
 11 | import hashlib
 12 | import json
 13 | import os
 14 | from pathlib import Path
 15 | import re
 16 | import shutil
 17 | import subprocess
 18 | import tempfile
 19 | import time
 20 | import uuid
 21 | 
 22 | 
 23 | ROOT = Path(__file__).resolve().parents[1]
 24 | OFFLINE_TESTS = {
 25 |     "stage5_file_executor_smoke": "STAGE5_FILE_EXECUTOR_SMOKE_OK",
 26 |     "stage5_file_planner_smoke": "STAGE5_FILE_PLANNER_SMOKE_OK",
 27 |     "stage4_mood_action_smoke": "STAGE4_MOOD_ACTION_SMOKE_OK",
 28 |     "dynamic_hit_shape_smoke": "DYNAMIC_HIT_SHAPE_SMOKE_OK",
 29 |     "drag_throw_motion_smoke": "DRAG_THROW_MOTION_SMOKE_OK",
 30 |     "movement_catalog_loader_smoke": "MOVEMENT_CATALOG_LOADER_SMOKE_OK",
 31 |     "roaming_controller_smoke": "ROAMING_CONTROLLER_SMOKE_OK",
 32 |     "roaming_integration_smoke": "ROAMING_INTEGRATION_SMOKE_OK",
 33 |     "inactivity_sleep_smoke": "INACTIVITY_SLEEP_SMOKE_OK",
 34 |     "idle_action_weight_smoke": "IDLE_ACTION_WEIGHT_SMOKE_OK",
 35 |     "autonomous_behavior_smoke": "AUTONOMOUS_BEHAVIOR_SMOKE_OK",
 36 |     "easter_egg_smoke": "EASTER_EGG_SMOKE_OK",
 37 |     "dialogue_smoke": "DIALOGUE_SMOKE_OK",
 38 |     "dialogue_ui_smoke": "DIALOGUE_UI_SMOKE_OK",
 39 |     "pet_feedback_smoke": "PET_FEEDBACK_SMOKE_OK",
 40 |     "feature_smoke": "FEATURE_SMOKE_OK",
 41 |     "green_screen_runtime_smoke": "GREENSCREEN_RUNTIME_SMOKE_OK",
 42 |     "video_runtime_smoke": "VIDEO_RUNTIME_SMOKE_OK",
 43 |     "manual_action_smoke": "MANUAL_ACTION_VIDEO_ONLY_OK",
 44 |     "click_happy_clip_smoke": "CLICK_HAPPY_CLIP_OK",
 45 |     "bubble_layout_smoke": "BUBBLE_LAYOUT_SMOKE_OK",
 46 |     "bubble_passthrough_smoke": "PASSTHROUGH_BUBBLE_SMOKE_OK",
 47 |     "ui_smoke": "UI_BUBBLE_SMOKE_OK",
 48 |     "weather_reminder_smoke": "WEATHER_REMINDER_SMOKE_OK",
 49 |     "render_ui_previews": "UI_PREVIEW_SMOKE_OK",
 50 |     "render_bubble_previews": "BUBBLE_PREVIEW_OK",
 51 | }
 52 | NETWORK_TESTS = {
 53 |     "weather_smoke": "WEATHER_SMOKE_OK",
 54 |     "weather_cn_smoke": "WEATHER_CN_SMOKE_OK",
 55 | }
 56 | 
 57 | 
 58 | def digest(path: Path) -> str | None:
 59 |     return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
 60 | 
 61 | 
 62 | def inventory(directory: Path) -> dict[str, str | None]:
 63 |     return {
 64 |         p.relative_to(directory).as_posix(): digest(p)
 65 |         for p in sorted(directory.rglob("*"))
 66 |         if p.is_file()
 67 |         and not any(part in {".godot", "test_output", "__pycache__"}
 68 |                     for part in p.relative_to(directory).parts)
 69 |     }
 70 | 
 71 | 
 72 | def main() -> int:
 73 |     parser = argparse.ArgumentParser(description=__doc__)
 74 |     parser.add_argument("--godot", type=Path,
 75 |                         default=Path(r"D:\Godot\Godot_v4.7-stable_win64.exe"))
 76 |     parser.add_argument("--network", action="store_true",
 77 |                         help="Also run the two live Open-Meteo integration checks")
 78 |     parser.add_argument("--only", nargs="+", choices=list(OFFLINE_TESTS),
 79 |                         help="Run selected offline tests in the same isolated workspace")
 80 |     args = parser.parse_args()
 81 |     if not args.godot.is_file():
 82 |         parser.error("Godot executable not found; specify --godot")
 83 |     source = ROOT / "godot"
 84 |     if (source / "override.cfg").exists():
 85 |         parser.error("Existing override.cfg needs review before isolation overrides can be applied")
 86 | 
 87 |     stamp = datetime.now(timezone(timedelta(hours=8))).strftime("%Y%m%d_%H%M%S")
 88 |     run_id = f"{stamp}_{uuid.uuid4().hex[:8]}"
 89 |     output = ROOT / "docs" / "baselines" / run_id
 90 |     output.mkdir(parents=True, exist_ok=False)
 91 |     work = Path(tempfile.mkdtemp(prefix="wuzi_baseline_"))
 92 |     project = work / "godot"
 93 |     userdata = Path(os.environ["APPDATA"]) / "WuziPetBaseline" / run_id
 94 |     production_settings = (Path(os.environ["APPDATA"]) / "Godot" / "app_userdata"
 95 |                            / "舞梓桌宠" / "wuzi_pet_settings.json")
 96 |     before = inventory(source)
 97 |     settings_before = digest(production_settings)
 98 |     report = {
 99 |         "run_id": run_id, "mode": "headless", "godot": str(args.godot.resolve()),
        "runner_sha256": digest(Path(__file__)),
        "source": str(source), "workspace": str(work), "user_data_dir": str(userdata),
        "production_settings_path": str(production_settings),
        "source_before": before, "settings_before_sha256": settings_before,
        "network_requested": args.network, "checks": [],
        "limitations": [
            "Headless preview scripts do not produce rendered screenshots.",
            "Real Windows dragging, throwing, focus and mouse passthrough require desktop validation.",
            "Test durations are not measurements of desktop runtime memory or frame performance.",
        ],
    }
    environment = os.environ.copy()
    environment["WUZI_BASELINE_USER_DIR"] = str(userdata)

    def run(name: str, arguments: list[str], marker: str | None = None,
            timeout: int = 45) -> bool:
        command = [str(args.godot), "--headless", "--path", str(project),
                   "--log-file", str(output / f"{name}.engine.log"), *arguments]
        started = time.monotonic()
        try:
            result = subprocess.run(
                command, cwd=project, env=environment, capture_output=True,
                encoding="utf-8", errors="replace", timeout=timeout,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            log = result.stdout + result.stderr
            code = result.returncode
        except subprocess.TimeoutExpired as error:
            raw = (error.stdout or b"") + (error.stderr or b"")
            log = raw.decode("utf-8", errors="replace") + "\nRUNNER_TIMEOUT\n"
            code = -1
        (output / f"{name}.log").write_text(log, encoding="utf-8")
        passed = (code == 0 and (marker is None or marker in log)
                  and not re.search(r"ERROR:|Parse Error:", log))
        report["checks"].append({
            "name": name, "passed": passed, "exit_code": code,
            "elapsed_seconds": round(time.monotonic() - started, 3),
            "expected_marker": marker, "log": f"{name}.log",
            "diagnostics": [line for line in log.splitlines()
                            if "WARNING:" in line or "ERROR:" in line],
        })
        print(f"{'PASS' if passed else 'FAIL'} {name} ({code})", flush=True)
        return passed

    try:
        shutil.copytree(source, project,
                        ignore=shutil.ignore_patterns(".godot", "test_output", "__pycache__"))
        (project / "override.cfg").write_text(
            '[application]\nconfig/use_custom_user_dir=true\n'
            f'config/custom_user_dir_name="WuziPetBaseline/{run_id}"\n', encoding="utf-8")
        (project / "baseline_isolation_probe.gd").write_text(
            'extends SceneTree\n'
            'func _init() -> void:\n'
            '\tvar actual := OS.get_user_data_dir().replace("\\\\", "/").to_lower()\n'
            '\tvar expected := OS.get_environment("WUZI_BASELINE_USER_DIR").replace("\\\\", "/").to_lower()\n'
            '\tif actual != expected:\n'
            '\t\tpush_error("ISOLATION_FAILED: " + actual + " expected " + expected)\n'
            '\t\tquit(2)\n'
            '\t\treturn\n'
            '\tprint("ISOLATION_OK: " + actual)\n'
            '\tquit(0)\n', encoding="utf-8")
        if not run("isolation", ["--script", "res://baseline_isolation_probe.gd"], "ISOLATION_OK"):
            raise RuntimeError("User data isolation failed; no feature tests were started")
        if not run("import", ["--editor", "--import"], timeout=180):
            raise RuntimeError("Isolated project import failed")
        run("startup", ["--max-fps", "60", "--quit-after", "120"])
        for name, marker in OFFLINE_TESTS.items():
            if args.only and name not in args.only:
                continue
            run(name, ["--script", f"res://tests/{name}.gd"], marker)
        for phase in (() if args.only else ("write", "read")):
            run(f"nickname_restart_{phase}",
                ["--script", "res://tests/nickname_restart_smoke.gd", "--", phase],
                "NICKNAME_RESTART_OK")
        if args.network:
            for name, marker in NETWORK_TESTS.items():
                run(name, ["--script", f"res://tests/{name}.gd"], marker)
    except Exception as error:
        report["runner_error"] = str(error)
        print(f"RUNNER_ERROR: {error}", flush=True)
    finally:
        after = inventory(source)
        report["source_unchanged"] = before == after
        report["changed_source_paths"] = sorted(
            p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
        report["settings_after_sha256"] = digest(production_settings)
        report["production_settings_unchanged"] = settings_before == report["settings_after_sha256"]
        report["ok"] = (bool(report["checks"]) and not report.get("runner_error")
                        and all(c["passed"] for c in report["checks"])
                        and report["source_unchanged"] and report["production_settings_unchanged"])
        (output / "report.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"REPORT: {output / 'report.json'}", flush=True)
        print(f"SOURCE_UNCHANGED: {report['source_unchanged']}", flush=True)
        print(f"SETTINGS_UNCHANGED: {report['production_settings_unchanged']}", flush=True)
    return 0 if report["ok"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
