"""Build and audit an isolated, OGV-first Windows portable candidate.

The v0.1.0 packaging entry point and its artifacts are deliberately untouched.
Usage: python tools/build_slim_windows_release.py audit|prepare|test|package
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import zipfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot"
WORK = ROOT / "work"
VERSION = os.environ.get("WUZI_RELEASE_VERSION", "v0.1.1-rc2")
if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+(?:-rc[0-9]+)?", VERSION):
    raise ValueError("Invalid WUZI_RELEASE_VERSION")
STAGE = WORK / ("release_slim_staging_" + VERSION)
FOLDER = f"WuziDesktopPet-{VERSION}-win64"
DIST = ROOT / "dist"
PKG = DIST / FOLDER
ZIP = DIST / f"{FOLDER}.zip"
# Set WUZI_GODOT_CONSOLE to your Godot 4.7 console executable.
# Without an override, the executable must be named 'godot' on PATH.
GODOT = Path(os.environ.get("WUZI_GODOT_CONSOLE", shutil.which("godot") or "godot"))
BRIDGE = PROJECT / "native" / "wuzi_file_bridge.exe"
BASE_ZIP = DIST / "WuziDesktopPet-v0.1.0-win64.zip"
BASE_PCK = DIST / "WuziDesktopPet-v0.1.0-win64" / "舞梓桌宠.pck"
BASE_EXE = DIST / "WuziDesktopPet-v0.1.0-win64" / "舞梓桌宠.exe"


def sha(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(4 * 1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def pck_manifest(path: Path) -> dict:
    """Read actual Godot standalone PCK directory, not export filter hints."""
    with path.open("rb") as f:
        def u32() -> int:
            return struct.unpack("<I", f.read(4))[0]

        def u64() -> int:
            return struct.unpack("<Q", f.read(8))[0]

        magic = u32()
        if magic != 0x43504447:
            raise RuntimeError(f"Unexpected PCK magic: {magic:08x}")
        fmt, major, minor, patch, flags = [u32() for _ in range(5)]
        base = u64()
        if fmt >= 3:
            # Godot 4.7 PCK v4 stores its index at the end, not after the header.
            directory_offset = u64()
            f.seek(directory_offset)
        else:
            f.read(16 * 4)
        count = u32()
        if count < 10 or count > 500000:
            raise RuntimeError(f"Unexpected PCK entry count: {count}")
        names = []
        sizes = Counter()
        counts = Counter()
        clip_videos = []
        video_md5 = {}
        needed = set()
        for _ in range(count):
            name_len = u32()
            if name_len <= 0 or name_len > 16384:
                raise RuntimeError(f"Invalid PCK name length {name_len}")
            name = f.read(name_len).rstrip(b"\0").decode("utf-8", "replace")
            offset, size = u64(), u64()
            payload_md5 = f.read(16).hex()
            _entry_flags = u32()
            names.append(name)
            low = name.lower()
            kind = ("ctex" if low.endswith(".ctex") else
                    "ogv" if low.endswith(".ogv") else
                    "tests" if "/tests/" in low or low.startswith("res://tests/") else
                    "config" if "/config/" in low else "other")
            sizes[kind] += size
            counts[kind] += 1
            if low.endswith("runtime_alpha.ogv"):
                clip_videos.append(name)
                video_md5[name] = payload_md5
            if any(term in low for term in [
                "pet_behavior.json", "movement_catalog.json",
                "video_hit_shapes.json", "feature_config.json"]):
                needed.add(name)
        return {
            "format": fmt, "godot_version": [major, minor, patch],
            "flags": flags, "file_base": base, "entry_count": count,
            "counts": dict(counts), "bytes_by_type": dict(sizes),
            "ogv_paths": sorted(clip_videos), "ogv_md5": video_md5,
            "config_paths": sorted(needed),
            "test_entries": [x for x in names if "/tests/" in x],
            "mp4_entries": [x for x in names if x.lower().endswith(".mp4")],
            "ctex_paths": [x for x in names if x.lower().endswith(".ctex")],
        }


def clips_and_dependency_contract() -> dict:
    config = json.loads((PROJECT / "config" / "pet_behavior.json").read_text(encoding="utf-8"))
    specs = {"idle": config["idle_video"], **config["clips"]}
    base = PROJECT / "assets_display" / "wuzi_chibi"
    dirs = sorted(base.glob("video_*"))
    if len(dirs) != 38 or len(specs) != 38:
        raise RuntimeError(f"Expected 38: dirs={len(dirs)}, config={len(specs)}")
    info = {}
    for clip_id, spec in specs.items():
        prefix = str(spec["frames_dir"])
        if not prefix.startswith("res://assets_display/wuzi_chibi/video_"):
            raise RuntimeError(f"Unsafe video path: {prefix}")
        frame_dir = PROJECT / prefix.removeprefix("res://")
        folder = frame_dir.parent
        pngs = list(frame_dir.glob("*.png"))
        if len(pngs) != 121 or int(spec.get("frame_count", 0)) != 121:
            raise RuntimeError(f"Full-frame source contract broken: {clip_id}")
        ogv = folder / "runtime_alpha.ogv"
        anchor = frame_dir / "000.png"
        if not ogv.is_file() or ogv.stat().st_size < 1000 or not anchor.is_file():
            raise RuntimeError(f"Missing runtime asset for {clip_id}")
        info[clip_id] = {
            "ogv": ogv.relative_to(PROJECT).as_posix(),
            "anchor": anchor.relative_to(PROJECT).as_posix(),
            "frames": len(pngs), "ogv_bytes": ogv.stat().st_size,
            "anchor_sha256": sha(anchor), "ogv_sha256": sha(ogv),
        }
    if {p.name for p in dirs} != {Path(v["ogv"]).parent.name for v in info.values()}:
        raise RuntimeError("Clip config does not match video_* directory inventory")
    if not BRIDGE.is_file() or BRIDGE.stat().st_size < 30000:
        raise RuntimeError("Required native helper missing")
    return info


def audit() -> dict:
    clips = clips_and_dependency_contract()
    if not BASE_ZIP.is_file() or not BASE_PCK.is_file() or not BASE_EXE.is_file():
        raise RuntimeError("Existing v0.1.0 baseline files are missing")
    base_pack = pck_manifest(BASE_PCK)
    with zipfile.ZipFile(BASE_ZIP) as z:
        crc_ok = z.testzip() is None
    result = {
        "baseline_version": "v0.1.0",
        "zip_bytes": BASE_ZIP.stat().st_size, "zip_sha256": sha(BASE_ZIP),
        "zip_crc_ok": crc_ok,
        "exe_bytes": BASE_EXE.stat().st_size, "exe_sha256": sha(BASE_EXE),
        "pck_bytes": BASE_PCK.stat().st_size, "pck_sha256": sha(BASE_PCK),
        "pck": {k: v for k, v in base_pack.items() if k != "ctex_paths"},
        "clip_count": len(clips), "clips": clips,
        "required_runtime": [
            "scenes/*.tscn", "scripts/*.gd", "shaders/*.gdshader",
            "config/*.json", "38 x runtime_alpha.ogv",
            "38 x video_*/frames/000.png", "native/wuzi_file_bridge.exe",
            "LICENSE and engine/asset notices", "Godot engine executable",
        ],
        "excluded_from_slim": [
            "4,560 non-anchor frame PNGs", "tests/*.gd",
            "raw MP4 and master/reference images", "test_output/ and .godot cache",
        ],
    }
    WORK.mkdir(exist_ok=True)
    (WORK / "release_slim_baseline.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("BASELINE_OK", "clip_count", len(clips), "zip_bytes", result["zip_bytes"],
          "ctex", base_pack["counts"].get("ctex"), flush=True)
    return result


def keep_only_runtime(directory: str, names: list[str]) -> list[str]:
    current = Path(directory)
    rejected = set()
    if current.name == "godot" or current == PROJECT:
        rejected.update({".godot", "test_output"})
    if current.name == "frames" and current.parent.name.startswith("video_"):
        rejected.update(n for n in names if n != "000.png")
    rejected.update(n for n in names if n.endswith((".log", ".tmp")))
    return list(rejected)


def prepare() -> None:
    if STAGE.exists():
        raise RuntimeError(f"Staging directory already exists; won't overwrite: {STAGE}")
    audit()
    print("PREPARING_STAGING", STAGE, flush=True)
    shutil.copytree(PROJECT, STAGE, ignore=keep_only_runtime)
    settings_path = STAGE / "config" / "pet_behavior.json"
    settings = json.loads(settings_path.read_text(encoding="utf-8"))
    settings["runtime_profile"] = "release_slim"
    settings["video_runtime"]["enabled"] = True
    settings_path.write_text(
        json.dumps(settings, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    if any((STAGE / "assets_display" / "wuzi_chibi").rglob("001.png")):
        raise RuntimeError("Slim stage unexpectedly includes full frame sequences")
    assert len(list((STAGE / "assets_display" / "wuzi_chibi").rglob("000.png"))) == 38
    assert len(list((STAGE / "assets_display" / "wuzi_chibi").rglob("*.ogv"))) == 38
    preset_path = STAGE / "export_presets.cfg"
    preset_text = preset_path.read_text(encoding="utf-8")
    major, minor, patch = VERSION.removeprefix("v").split("-")[0].split(".")
    dotted_version = f"{major}.{minor}.{patch}.0"
    preset_text = re.sub(r'application/file_version="[^"]*"', f'application/file_version="{dotted_version}"', preset_text)
    preset_text = re.sub(r'application/product_version="[^"]*"', f'application/product_version="{dotted_version}"', preset_text)
    preset_path.write_text(preset_text, encoding="utf-8")
    print("STAGING_OK", flush=True)


def run_godot(args: list[str], name: str, timeout: int = 360) -> str:
    command = [str(GODOT), "--headless", "--path", str(STAGE), *args]
    result = subprocess.run(
        command, cwd=STAGE, capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=timeout,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )
    log = (result.stdout or "") + (result.stderr or "")
    (WORK / f"release_slim_{name}.log").write_text(log, encoding="utf-8")
    if result.returncode != 0 or "ERROR:" in log or "Parse Error:" in log:
        raise RuntimeError(f"Godot {name} failed ({result.returncode}): {log[-2300:]}")
    return log


def test() -> None:
    if not STAGE.is_dir():
        raise RuntimeError("Run prepare first")
    # Export intentionally removes staged tests. Restore them only to the
    # isolated staging project when re-running checks after an export.
    stage_tests = STAGE / "tests"
    stage_tests.mkdir(exist_ok=True)
    for name in ("release_slim_smoke.gd", "video_runtime_completion_probe.gd"):
        shutil.copy2(PROJECT / "tests" / name, stage_tests / name)
    print("IMPORTING_SLIM_STAGE", flush=True)
    run_godot(["--editor", "--import"], "import", timeout=360)
    isolated_settings = STAGE / "override.cfg"
    if isolated_settings.exists():
        raise RuntimeError("Existing override.cfg in stage; refusing to overwrite")
    isolated_settings.write_text(
        '[application]\nconfig/use_custom_user_dir=true\n'
        'config/custom_user_dir_name="WuziPetSlimValidation20261010"\n',
        encoding="utf-8",
    )
    try:
        for name, marker in [
            ("release_slim_smoke", "RELEASE_SLIM_SMOKE_OK"),
            ("video_runtime_completion_probe", "VIDEO_RUNTIME_COMPLETION_PROBE_OK"),
        ]:
            print("TESTING", name, flush=True)
            output = run_godot(["--script", f"res://tests/{name}.gd"], name, timeout=100)
            if marker not in output:
                raise RuntimeError(f"Missing expected marker: {marker}")
            print("PASS", name, flush=True)
    finally:
        isolated_settings.unlink()
    (WORK / "release_slim_tests_passed.json").write_text(
        json.dumps({"staging": str(STAGE), "tests": [
            "release_slim_smoke", "video_runtime_completion_probe"]}, indent=2),
        encoding="utf-8",
    )


def package() -> None:
    if not (WORK / "release_slim_tests_passed.json").is_file():
        raise RuntimeError("Run and pass staged tests before package")
    if PKG.exists() or ZIP.exists():
        raise RuntimeError("Candidate already exists; refusing to overwrite")
    if not GODOT.is_file():
        raise RuntimeError(f"Godot executable unavailable: {GODOT}")
    if (STAGE / "override.cfg").exists():
        raise RuntimeError("Do not export isolated settings override")
    if (STAGE / "tests").exists():
        shutil.rmtree(STAGE / "tests")
    PKG.mkdir(parents=True)
    target_exe = PKG / "舞梓桌宠.exe"
    print("EXPORTING_CANDIDATE", flush=True)
    run_godot(["--export-release", "Windows Desktop", str(target_exe)], "export", timeout=480)
    target_pck = PKG / "舞梓桌宠.pck"
    if not target_exe.is_file() or not target_pck.is_file():
        raise RuntimeError("Export did not generate EXE and PCK")
    pck = pck_manifest(target_pck)
    all_videos = clips_and_dependency_contract()
    got_videos = {Path(p).parent.name for p in pck["ogv_paths"]}
    expected_videos = {Path(v["ogv"]).parent.name for v in all_videos.values()}
    if got_videos != expected_videos:
        raise RuntimeError(f"OGV action mismatch: {expected_videos - got_videos}")
    if (pck["counts"].get("ctex", 0) > 150 or pck["test_entries"] or
            pck["mp4_entries"]):
        raise RuntimeError("Forbidden resource present in candidate PCK")
    if not any("video_hit_shapes.json" in p for p in pck["config_paths"]):
        raise RuntimeError("Missing dynamic-hit configuration in PCK")
    if not any("pet_behavior.json" in p for p in pck["config_paths"]):
        raise RuntimeError("Missing behavior configuration in PCK")
    (PKG / "native").mkdir(exist_ok=True)
    shutil.copy2(BRIDGE, PKG / "native" / BRIDGE.name)
    shutil.copy2(ROOT / "LICENSE", PKG / "LICENSE.txt")
    shutil.copy2(ROOT / "docs" / "licenses" / "GODOT_LICENSE.txt",
                 PKG / "GODOT_LICENSE.txt")
    (PKG / "README_使用说明.txt").write_text(
        f"舞梓桌宠 Windows 64 位候选测试版 {VERSION}\n"
        "完整解压后运行 舞梓桌宠.exe，保持 native 目录与程序同级。\n"
        "全部 38 套动作正常播放时使用原始透明 OGV 视频；"
        "若视频不可用，则安全恢复静态首帧/待机，不再包含完整 PNG 逐帧后备。\n"
        "此版本仅供人工视觉验收，不代表正式公开发布。\n"
        "HEIC 图片转换取决于 Windows 系统是否安装相关解码组件。\n",
        encoding="utf-8",
    )
    (PKG / "ASSET_NOTICES.txt").write_text(
        "角色与动画均为非官方粉丝二创，独立视觉素材不适用源码 MIT 许可。\n"
        "本候选包包含已处理透明 OGV 动画与少量静态 PNG 锚点，"
        "不包含原始 MP4、角色母版和开发参考图。\n"
        "发布前须由发布者确认角色及素材使用权和二创规则。\n",
        encoding="utf-8",
    )
    manifest = {
        "version": VERSION,
        "contents": {
            p.relative_to(PKG).as_posix(): {
                "bytes": p.stat().st_size, "sha256": sha(p)}
            for p in sorted(PKG.rglob("*")) if p.is_file()
        },
    }
    (PKG / "MANIFEST_SHA256.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=5) as z:
        for file in sorted(PKG.rglob("*")):
            if file.is_file():
                z.write(file, (Path(FOLDER) / file.relative_to(PKG)).as_posix())
    with zipfile.ZipFile(ZIP) as z:
        crc = z.testzip() is None
        if not crc:
            raise RuntimeError("Candidate ZIP CRC failed")
    report = {
        "version": VERSION, "zip": str(ZIP),
        "zip_bytes": ZIP.stat().st_size, "zip_sha256": sha(ZIP), "zip_crc": crc,
        "exe_bytes": target_exe.stat().st_size, "exe_sha256": sha(target_exe),
        "pck_bytes": target_pck.stat().st_size, "pck_sha256": sha(target_pck),
        "pck": {k: v for k, v in pck.items() if k != "ctex_paths"},
        "unchanged_baseline_zip_sha256": sha(BASE_ZIP),
        "development_png_remaining": len(list(
            (PROJECT / "assets_display" / "wuzi_chibi").rglob("*.png"))),
        "candidate_not_published": True,
    }
    (WORK / "release_slim_candidate_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("CANDIDATE_OK", "ZIP_MiB", round(report["zip_bytes"] / 1048576, 2),
          "CTEX_COUNT", pck["counts"].get("ctex", 0),
          "ZIP_SHA256", report["zip_sha256"], flush=True)



def verify() -> None:
    """Verify finished artifacts and prove all OGV payloads are byte-identical."""
    previous_baseline = json.loads(
        (WORK / "release_slim_baseline.json").read_text(encoding="utf-8")
    )
    previous_candidate = json.loads(
        (WORK / "release_slim_candidate_report.json").read_text(encoding="utf-8")
    )
    baseline = audit()
    if any(baseline[k] != previous_baseline[k] for k in (
        "zip_sha256", "exe_sha256", "pck_sha256", "clip_count")):
        raise RuntimeError("Existing v0.1.0 artifact changed after baseline capture")
    if not ZIP.is_file() or not (PKG / "舞梓桌宠.pck").is_file():
        raise RuntimeError("Candidate ZIP/PCK no longer exists")
    if sha(ZIP) != previous_candidate["zip_sha256"]:
        raise RuntimeError("Candidate ZIP changed after packaging")
    candidate_pck = pck_manifest(PKG / "舞梓桌宠.pck")
    old_pck = pck_manifest(BASE_PCK)
    if old_pck["ogv_md5"] != candidate_pck["ogv_md5"]:
        raise RuntimeError("Original OGV payloads differ from candidate package")
    if candidate_pck["counts"].get("ctex") != 38:
        raise RuntimeError("Candidate must contain precisely 38 imported first frames")
    if candidate_pck["counts"].get("ogv") != 38:
        raise RuntimeError("Candidate lost OGV files")
    if candidate_pck["test_entries"] or candidate_pck["mp4_entries"]:
        raise RuntimeError("Candidate includes forbidden test/raw media resources")
    if len(list((PROJECT / "assets_display" / "wuzi_chibi").rglob("*.png"))) != 4598:
        raise RuntimeError("Development PNG source inventory changed")
    staged = json.loads(
        (STAGE / "config" / "pet_behavior.json").read_text(encoding="utf-8")
    )
    original = json.loads(
        (PROJECT / "config" / "pet_behavior.json").read_text(encoding="utf-8")
    )
    if staged.pop("runtime_profile", None) != "release_slim" or staged != original:
        raise RuntimeError("Staged behavior settings changed beyond release profile")
    with zipfile.ZipFile(ZIP) as archive:
        if archive.testzip() is not None:
            raise RuntimeError("Candidate ZIP CRC failed")
        names = archive.namelist()
        for path in ("舞梓桌宠.exe", "舞梓桌宠.pck",
                     "native/wuzi_file_bridge.exe", "ASSET_NOTICES.txt",
                     "GODOT_LICENSE.txt", "LICENSE.txt"):
            if not any(x.endswith("/" + path) for x in names):
                raise RuntimeError(f"Required release file missing: {path}")
    result = {
        "verified": True,
        "baseline_zip_sha256": baseline["zip_sha256"],
        "candidate_zip_sha256": sha(ZIP),
        "all_38_ogv_identical": True,
        "original_4598_png_kept": True,
        "runtime_config_only_profile_changed": True,
        "zip_crc": True,
        "tests_in_pck": 0,
        "raw_mp4_in_pck": 0,
        "slim_png_ctex": 38,
        "slim_ogv": 38,
        "gui_manual_approval": "PENDING_USER",
        "git_commit_or_release": "NOT_PERFORMED",
    }
    (WORK / "release_slim_integrity_verification.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("SLIM_INTEGRITY_OK", "OGV_BYTE_IDENTICAL", 38,
          "ORIGINAL_PNG_KEPT", 4598, flush=True)

if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in {"audit", "prepare", "test", "package", "verify"}:
        raise SystemExit("Usage: py tools/build_slim_windows_release.py audit|prepare|test|package|verify")
    {"audit": audit, "prepare": prepare, "test": test, "package": package,
     "verify": verify}[sys.argv[1]]()
