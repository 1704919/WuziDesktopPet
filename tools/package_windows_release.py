  1 | """Build and verify the portable Wuzi desktop pet Windows ZIP.
  2 | 
  3 | Exported package contains cooked PNG/OGV and Godot data. Never includes
  4 | green-screen MP4s, original references, source videos or development caches.
  5 | Requires matching Godot 4.7 Windows x64 templates installed separately.
  6 | """
  7 | from __future__ import annotations
  8 | 
  9 | import argparse
 10 | import hashlib
 11 | import json
 12 | import shutil
 13 | import subprocess
 14 | import sys
 15 | import zipfile
 16 | from pathlib import Path
 17 | 
 18 | ROOT = Path(__file__).resolve().parents[1]
 19 | PROJECT = ROOT / "godot"
 20 | VERSION = "v0.1.0"
 21 | FOLDER = f"WuziDesktopPet-{VERSION}-win64"
 22 | DIST = ROOT / "dist"
 23 | PACKAGE_DIR = DIST / FOLDER
 24 | EXE = PACKAGE_DIR / "舞梓桌宠.exe"
 25 | PCK = PACKAGE_DIR / "舞梓桌宠.pck"
 26 | ZIP_PATH = DIST / f"{FOLDER}.zip"
 27 | GODOT = Path("D:/Godot/Godot_v4.7-stable_win64_console.exe")
 28 | BRIDGE = PROJECT / "native" / "wuzi_file_bridge.exe"
 29 | 
 30 | 
 31 | def digest(path: Path) -> str:
 32 |     hasher = hashlib.sha256()
 33 |     with path.open("rb") as stream:
 34 |         for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
 35 |             hasher.update(chunk)
 36 |     return hasher.hexdigest()
 37 | 
 38 | 
 39 | def require_runtime_assets() -> None:
 40 |     settings = json.loads((PROJECT / "config" / "pet_behavior.json").read_text(encoding="utf-8"))
 41 |     base = PROJECT / "assets_display" / "wuzi_chibi"
 42 |     dirs = sorted(base.glob("video_*"))
 43 |     if len(dirs) != 38:
 44 |         raise RuntimeError(f"Expected 38 processed video directories, found {len(dirs)}")
 45 |     for directory in dirs:
 46 |         video = directory / "runtime_alpha.ogv"
 47 |         pngs = list((directory / "frames").glob("*.png"))
 48 |         if not video.is_file() or video.stat().st_size < 1000 or len(pngs) != 121:
 49 |             raise RuntimeError(f"Missing video/PNG fallback frames: {directory}")
 50 |     for spec in [settings.get("idle_video", {})] + list(settings.get("clips", {}).values()):
 51 |         frames_path = str(spec.get("frames_dir", ""))
 52 |         if not frames_path.startswith("res://assets_display/wuzi_chibi/"):
 53 |             raise RuntimeError("Configured runtime path is unexpected: " + frames_path)
 54 |         local_dir = PROJECT / frames_path.removeprefix("res://")
 55 |         if not (local_dir / "000.png").is_file():
 56 |             raise RuntimeError("Missing configured first frame: " + frames_path)
 57 |     if not BRIDGE.is_file() or BRIDGE.stat().st_size < 30000:
 58 |         raise RuntimeError("Compiled Windows file bridge is missing")
 59 |     print("ASSET_PREFLIGHT_OK: 38 OGV clips, 38 x 121 PNG fallback frames, native bridge", flush=True)
 60 | 
 61 | 
 62 | def export_game() -> None:
 63 |     if not GODOT.is_file():
 64 |         raise RuntimeError(f"Godot Windows editor missing: {GODOT}")
 65 |     PACKAGE_DIR.mkdir(parents=True, exist_ok=True)
 66 |     command = [
 67 |         str(GODOT), "--headless", "--path", str(PROJECT),
 68 |         "--export-release", "Windows Desktop", str(EXE)
 69 |     ]
 70 |     print("EXPORTING_WINDOWS_DESKTOP", flush=True)
 71 |     result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=480)
 72 |     log_dir = ROOT / "work"
 73 |     log_dir.mkdir(exist_ok=True)
 74 |     (log_dir / "windows_release_export.log").write_text(
 75 |         result.stdout + result.stderr, encoding="utf-8"
 76 |     )
 77 |     if result.returncode != 0:
 78 |         raise RuntimeError(f"Godot export failed (exit {result.returncode}); see work/windows_release_export.log")
 79 |     print("EXPORT_OK", flush=True)
 80 | 
 81 | 
 82 | def make_notices() -> None:
 83 |     shutil.copy2(BRIDGE, PACKAGE_DIR / "native" / BRIDGE.name)
 84 |     shutil.copy2(ROOT / "LICENSE", PACKAGE_DIR / "LICENSE.txt")
 85 |     shutil.copy2(ROOT / "docs" / "licenses" / "GODOT_LICENSE.txt", PACKAGE_DIR / "GODOT_LICENSE.txt")
 86 |     (PACKAGE_DIR / "README_使用说明.txt").write_text(
 87 |         """舞梓桌宠 Windows 64 位便携版
 88 | 
 89 | 运行方法：
 90 |   1. 将 ZIP 完整解压到一个普通文件夹，不要直接在压缩包内启动。
 91 |   2. 双击“舞梓桌宠.exe”，即可启动；不需要安装 Godot、Python 或 FFmpeg。
 92 |   3. 右键桌宠可聊天、点播动作、设置提醒、打开文件处理工具。
 93 |   4. PNG/JPG/WebP 图片转换和文件批量改名需要旁边 native/ 目录里的文件组件。
 94 |      不要单独移动桌宠 exe；整个文件夹必须保留。
 95 |   5. HEIC 支持取决于 Windows 系统是否已安装 HEIF/HEVC 等图片组件。
 96 |   6. Windows 可能提示“未知发布者”：当前免费版未购买代码签名证书，
 97 |      请确认来自可信发布渠道并核对官方提供的 SHA-256。
 98 | 
 99 | 限制：未实测多显示器、125%/150% DPI 环境；其他 Windows 机器仍需进一步验收。
本项目是非官方粉丝二创，不代表相关角色的权利人。

代码许可见 LICENSE.txt。Godot 引擎许可见 GODOT_LICENSE.txt。
角色与动画为独立的视觉资源，不属于项目代码的 MIT 许可。
""", encoding="utf-8")
    (PACKAGE_DIR / "ASSET_NOTICES.txt").write_text(
        """角色与动画素材说明 / Character & Animation Notice

本发行包仅包含运行桌宠所需的已处理透明视频 (OGV) 与 PNG
回退帧以及程序文件，不包含用于生成动作的原始 MP4、参考图或
角色母版。

舞梓／阿梓相关角色、造型及可能包含的其他第三方创意元素的权利
属于各自合法权利人。本程序是非官方粉丝二创，与角色权利人无
官方关联。本包中的角色形象和视频动画不适用项目源代码的 MIT
许可；本通知不构成任何第三方角色使用或再分发授权。

公开下载包前，请由发布者确认实际素材使用权及相关二创规则。
项目不应以本通知替代权利人授权。
""", encoding="utf-8")


def make_zip() -> None:
    for necessary in [EXE, PCK, PACKAGE_DIR / "native" / BRIDGE.name,
                      PACKAGE_DIR / "LICENSE.txt", PACKAGE_DIR / "GODOT_LICENSE.txt",
                      PACKAGE_DIR / "ASSET_NOTICES.txt", PACKAGE_DIR / "README_使用说明.txt"]:
        if not necessary.is_file():
            raise RuntimeError("Missing packaged file: " + str(necessary))
    checksums = {
        file.relative_to(PACKAGE_DIR).as_posix(): {
            "bytes": file.stat().st_size,
            "sha256": digest(file)
        }
        for file in sorted(PACKAGE_DIR.rglob("*")) if file.is_file()
        and file.name != "MANIFEST_SHA256.json"
    }
    (PACKAGE_DIR / "MANIFEST_SHA256.json").write_text(
        json.dumps({"version": VERSION, "contents": checksums},
                   ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("CREATING_ZIP", flush=True)
    with zipfile.ZipFile(ZIP_PATH, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=5, allowZip64=True) as out:
        for file in sorted(PACKAGE_DIR.rglob("*")):
            if file.is_file():
                out.write(file, (Path(FOLDER) / file.relative_to(PACKAGE_DIR)).as_posix())
    with zipfile.ZipFile(ZIP_PATH, "r") as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError("ZIP CRC check failed: " + bad)
        names = archive.namelist()
        if any(name.lower().endswith((".mp4", ".mov", ".mkv", ".psd")) for name in names):
            raise RuntimeError("Found raw or unrelated source assets in ZIP")
        if len(names) != len(checksums) + 1:
            raise RuntimeError("Unexpected ZIP manifest / file count mismatch")
    report = {
        "version": VERSION,
        "zip": str(ZIP_PATH),
        "zip_bytes": ZIP_PATH.stat().st_size,
        "sha256": digest(ZIP_PATH),
        "files": list(checksums.keys()),
        "asset_clip_count": 38,
        "raw_source_videos_in_zip": 0,
        "zip_crc_ok": True
    }
    (DIST / "release_manifest.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("WINDOWS_PORTABLE_PACKAGE_OK", "MB", round(report["zip_bytes"] / 1048576, 2),
          "SHA256", report["sha256"], flush=True)
    print("PACKAGE_PATH", ZIP_PATH, flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reuse-export", action="store_true", help="Skip Godot export if EXE/PCK already built.")
    args = parser.parse_args()
    require_runtime_assets()
    if not args.reuse_export:
        export_game()
    if not EXE.is_file() or not PCK.is_file():
        raise RuntimeError("Godot EXE or PCK missing")
    (PACKAGE_DIR / "native").mkdir(parents=True, exist_ok=True)
    make_notices()
    make_zip()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("RELEASE_PACKAGE_FAILED:", str(error), file=sys.stderr)
        raise
