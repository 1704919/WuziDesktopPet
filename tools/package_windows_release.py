"""Build and verify the portable Wuzi desktop pet Windows ZIP.

Exported package contains cooked PNG/OGV and Godot data. Never includes
green-screen MP4s, original references, source videos or development caches.
Requires matching Godot 4.7 Windows x64 templates installed separately.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot"
VERSION = "v0.1.0"
FOLDER = f"WuziDesktopPet-{VERSION}-win64"
DIST = ROOT / "dist"
PACKAGE_DIR = DIST / FOLDER
EXE = PACKAGE_DIR / "舞梓桌宠.exe"
PCK = PACKAGE_DIR / "舞梓桌宠.pck"
ZIP_PATH = DIST / f"{FOLDER}.zip"
GODOT = Path("D:/Godot/Godot_v4.7-stable_win64_console.exe")
BRIDGE = PROJECT / "native" / "wuzi_file_bridge.exe"


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def require_runtime_assets() -> None:
    settings = json.loads((PROJECT / "config" / "pet_behavior.json").read_text(encoding="utf-8"))
    base = PROJECT / "assets_display" / "wuzi_chibi"
    dirs = sorted(base.glob("video_*"))
    if len(dirs) != 38:
        raise RuntimeError(f"Expected 38 processed video directories, found {len(dirs)}")
    for directory in dirs:
        video = directory / "runtime_alpha.ogv"
        pngs = list((directory / "frames").glob("*.png"))
        if not video.is_file() or video.stat().st_size < 1000 or len(pngs) != 121:
            raise RuntimeError(f"Missing video/PNG fallback frames: {directory}")
    for spec in [settings.get("idle_video", {})] + list(settings.get("clips", {}).values()):
        frames_path = str(spec.get("frames_dir", ""))
        if not frames_path.startswith("res://assets_display/wuzi_chibi/"):
            raise RuntimeError("Configured runtime path is unexpected: " + frames_path)
        local_dir = PROJECT / frames_path.removeprefix("res://")
        if not (local_dir / "000.png").is_file():
            raise RuntimeError("Missing configured first frame: " + frames_path)
    if not BRIDGE.is_file() or BRIDGE.stat().st_size < 30000:
        raise RuntimeError("Compiled Windows file bridge is missing")
    print("ASSET_PREFLIGHT_OK: 38 OGV clips, 38 x 121 PNG fallback frames, native bridge", flush=True)


def export_game() -> None:
    if not GODOT.is_file():
        raise RuntimeError(f"Godot Windows editor missing: {GODOT}")
    PACKAGE_DIR.mkdir(parents=True, exist_ok=True)
    command = [
        str(GODOT), "--headless", "--path", str(PROJECT),
        "--export-release", "Windows Desktop", str(EXE)
    ]
    print("EXPORTING_WINDOWS_DESKTOP", flush=True)
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=480)
    log_dir = ROOT / "work"
    log_dir.mkdir(exist_ok=True)
    (log_dir / "windows_release_export.log").write_text(
        result.stdout + result.stderr, encoding="utf-8"
    )
    if result.returncode != 0:
        raise RuntimeError(f"Godot export failed (exit {result.returncode}); see work/windows_release_export.log")
    print("EXPORT_OK", flush=True)


def make_notices() -> None:
    shutil.copy2(BRIDGE, PACKAGE_DIR / "native" / BRIDGE.name)
    shutil.copy2(ROOT / "LICENSE", PACKAGE_DIR / "LICENSE.txt")
    shutil.copy2(ROOT / "docs" / "licenses" / "GODOT_LICENSE.txt", PACKAGE_DIR / "GODOT_LICENSE.txt")
    (PACKAGE_DIR / "README_使用说明.txt").write_text(
        """舞梓桌宠 Windows 64 位便携版

运行方法：
  1. 将 ZIP 完整解压到一个普通文件夹，不要直接在压缩包内启动。
  2. 双击“舞梓桌宠.exe”，即可启动；不需要安装 Godot、Python 或 FFmpeg。
  3. 右键桌宠可聊天、点播动作、设置提醒、打开文件处理工具。
  4. PNG/JPG/WebP 图片转换和文件批量改名需要旁边 native/ 目录里的文件组件。
     不要单独移动桌宠 exe；整个文件夹必须保留。
  5. HEIC 支持取决于 Windows 系统是否已安装 HEIF/HEVC 等图片组件。
  6. Windows 可能提示“未知发布者”：当前免费版未购买代码签名证书，
     请确认来自可信发布渠道并核对官方提供的 SHA-256。

限制：未实测多显示器、125%/150% DPI 环境；其他 Windows 机器仍需进一步验收。
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
