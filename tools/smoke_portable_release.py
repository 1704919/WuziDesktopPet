"""Smoke-test a Windows portable release in an isolated fresh directory."""
from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STAGED = ROOT / "dist" / "WuziDesktopPet-v0.1.0-win64"
PRODUCTION_SETTINGS = (
    Path(os.environ["APPDATA"]) / "Godot" / "app_userdata"
    / "舞梓桌宠" / "wuzi_pet_settings.json"
)


def sha(path: Path) -> str | None:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def main() -> int:
    production_before = sha(PRODUCTION_SETTINGS)
    log_dir = ROOT / "work"
    log_dir.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="wuzi_portable_release_") as tmp:
        destination = Path(tmp)
        release_zip = ROOT / "dist" / "WuziDesktopPet-v0.1.0-win64.zip"
        if not release_zip.is_file():
            raise RuntimeError("Portable ZIP must exist before the smoke test")
        with zipfile.ZipFile(release_zip, "r") as bundle:
            bundle.extractall(destination)
        folder = destination / "WuziDesktopPet-v0.1.0-win64"
        for needed in [
            folder / "舞梓桌宠.exe", folder / "舞梓桌宠.pck",
            folder / "native" / "wuzi_file_bridge.exe",
        ]:
            if not needed.is_file():
                raise RuntimeError("Unpacked release is incomplete: " + str(needed))
        user_name = "WuziPetReleaseSmoke_20261010"
        (folder / "override.cfg").write_text(
            "[application]\nconfig/use_custom_user_dir=true\n"
            f'config/custom_user_dir_name="{user_name}"\n',
            encoding="utf-8"
        )
        print("ISOLATED_PORTABLE_START", str(folder), flush=True)
        failed = False
        # Exported release binaries do not reliably support the editor's
        # --script test harness. Verify their actual launch modes instead.
        cases = [
            ("headless", ["--headless", "--quit-after", "90"]),
            ("gui", ["--quit-after", "180"]),
        ]
        for name, arguments in cases:
            log = log_dir / ("portable_release_" + name + ".log")
            command = [
                str(folder / "舞梓桌宠.exe"),
                "--log-file", str(log), *arguments,
            ]
            result = subprocess.run(
                command, cwd=folder, capture_output=True, text=True,
                encoding="utf-8", errors="replace", timeout=95,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            engine_log = log.read_text(encoding="utf-8", errors="replace") if log.is_file() else ""
            combined = (result.stdout or "") + (result.stderr or "") + "\n" + engine_log
            failures = [
                word for word in [
                    "ERROR:", "Parse Error:", "Failed to load master texture",
                    "Unable to open pet_behavior.json",
                    "Missing clip frame:", "Failed to load idle-video frame:"
                ] if word in combined
            ]
            passed = result.returncode == 0 and not failures
            print("RELEASE_CASE", name, "PASS" if passed else "FAIL",
                  "EXIT", result.returncode, "CRITICAL_ERRORS", failures, flush=True)
            if not passed:
                print("FAILED_CASE_LOG_TAIL", combined[-1700:], flush=True)
                failed = True
    production_after = sha(PRODUCTION_SETTINGS)
    unchanged = production_before == production_after
    print("PRODUCTION_SETTINGS_UNCHANGED", unchanged, flush=True)
    if failed or not unchanged:
        return 2
    print("PORTABLE_RELEASE_STARTUP_OK", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
