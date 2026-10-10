"""Pre-publication audit of files staged for the source-only Git repository."""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BINARY_SUFFIXES = {".exe", ".mp4", ".ogv", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".zip", ".pck", ".psd", ".pfx", ".p12"}
PRIVATE_PREFIXES = ("assets/", "分享区/", "backups/", "archive/", "work/", "dist/", "godot/assets_display/", "godot/.godot/", "docs/baselines/", ".ai-bridge/")
TOKENS = (
    ("github_token", re.compile(r"gh[pousr]_[A-Za-z0-9_]{25,}")),
    ("api_key", re.compile(r"sk-[A-Za-z0-9_-]{25,}")),
    ("private_key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("local_user_profile", re.compile(r"C:[\\/]Users[\\/][^\\/\s]+", re.IGNORECASE)),
)


def main() -> int:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "-z"], cwd=ROOT,
        check=True, capture_output=True
    )
    names = [Path(x.decode("utf-8")) for x in result.stdout.split(b"\0") if x]
    findings: list[tuple[str, str]] = []
    for name in names:
        rel = name.as_posix()
        if rel.startswith(PRIVATE_PREFIXES):
            findings.append((rel, "private_or_generated_path"))
        if name.suffix.lower() in BINARY_SUFFIXES:
            findings.append((rel, "binary_asset_in_git"))
        path = ROOT / name
        if not path.is_file():
            continue
        if path.stat().st_size > 2 * 1024 * 1024:
            # This machine-generated JSON is required for the desktop pet's
            # alpha-based mouse hit shapes; it contains only frame geometry.
            if rel != "godot/config/video_hit_shapes.json":
                findings.append((rel, "large_tracked_file_needs_review"))
            continue
        data = path.read_text(encoding="utf-8", errors="replace")
        for label, pattern in TOKENS:
            if pattern.search(data):
                findings.append((rel, label))
    print("TRACKED_FILES", len(names))
    print("PUBLICATION_FINDINGS", len(findings))
    for path, label in findings:
        print("FLAG", label, path)
    return 2 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
