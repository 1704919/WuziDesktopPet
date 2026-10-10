"""Install only official Godot 4.7 Windows x64 export templates via HTTP ranges.

The upstream export_templates.tpz is >1 GiB; this downloader extracts
only the Windows desktop members without fetching unrelated platform files.
It does not alter the desktop pet source or runtime assets.
"""
from __future__ import annotations

import argparse
import io
import os
import shutil
import time
import urllib.request
import zipfile
from pathlib import Path

VERSION = "4.7.stable"
URL = (
    "https://godot-releases.nbg1.your-objectstorage.com/"
    "4.7-stable/Godot_v4.7-stable_export_templates.tpz"
)
TARGETS = (
    "windows_release_x86_64.exe",
    "windows_debug_x86_64.exe",
)
BLOCK = 4 * 1024 * 1024


class HTTPRangeReader(io.RawIOBase):
    def __init__(self, url: str):
        self.url = url
        request = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(request, timeout=35) as resp:
            self.length = int(resp.headers["Content-Length"])
            if resp.status != 200:
                raise RuntimeError(f"Cannot query official archive: {resp.status}")
        self.position = 0
        self.cached_from = -1
        self.cached = b""

    def readable(self):
        return True

    def seekable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=os.SEEK_SET):
        if whence == os.SEEK_SET:
            position = offset
        elif whence == os.SEEK_CUR:
            position = self.position + offset
        elif whence == os.SEEK_END:
            position = self.length + offset
        else:
            raise ValueError(whence)
        self.position = max(0, position)
        return self.position

    def _read_range(self, start, end):
        for retry in range(4):
            try:
                req = urllib.request.Request(
                    self.url, headers={"Range": f"bytes={start}-{end - 1}"}
                )
                with urllib.request.urlopen(req, timeout=100) as resp:
                    if resp.status != 206:
                        raise RuntimeError("Server ignored HTTP Range; aborting full download")
                    part = resp.read()
                    if len(part) != end - start:
                        raise RuntimeError("Partial download truncated")
                    return part
            except (OSError, RuntimeError):
                if retry == 3:
                    raise
                time.sleep(retry + 1)
        raise AssertionError("unreachable")

    def read(self, size=-1):
        if size < 0:
            size = self.length - self.position
        size = min(size, max(0, self.length - self.position))
        if size <= 0:
            return b""
        parts = []
        remaining = size
        while remaining:
            if not (self.cached_from <= self.position < self.cached_from + len(self.cached)):
                start = (self.position // BLOCK) * BLOCK
                end = min(start + BLOCK, self.length)
                self.cached = self._read_range(start, end)
                self.cached_from = start
            offset = self.position - self.cached_from
            count = min(remaining, len(self.cached) - offset)
            parts.append(self.cached[offset:offset + count])
            self.position += count
            remaining -= count
        return b"".join(parts)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true", help="Show matching upstream filenames only.")
    args = parser.parse_args()
    cache_path = (
        Path(os.environ["APPDATA"])
        / "Godot" / "export_templates" / VERSION
    )
    archive = HTTPRangeReader(URL)
    with zipfile.ZipFile(archive) as zf:
        names = {
            Path(info.filename).name: info
            for info in zf.infolist()
            if Path(info.filename).name in TARGETS
        }
        print("UPSTREAM", URL, "SIZE_GiB", round(archive.length / 2**30, 2), flush=True)
        for filename in TARGETS:
            info = names.get(filename)
            if info is None:
                raise RuntimeError(f"Required Godot template unavailable: {filename}")
            print("TEMPLATE", info.filename, "unpacked_MiB", round(info.file_size / 2**20, 1), flush=True)
        if args.list:
            return
        cache_path.mkdir(parents=True, exist_ok=True)
        for filename in TARGETS:
            dest = cache_path / filename
            info = names[filename]
            if dest.is_file() and dest.stat().st_size == info.file_size:
                print("ALREADY_INSTALLED", dest, flush=True)
                continue
            partial = dest.with_suffix(dest.suffix + ".part")
            if partial.exists():
                partial.unlink()
            print("INSTALLING", filename, flush=True)
            with zf.open(info) as src, partial.open("wb") as dst:
                shutil.copyfileobj(src, dst, 1024 * 1024)
            if partial.stat().st_size != info.file_size:
                raise RuntimeError("Size verification failed: " + filename)
            partial.replace(dest)
            print("INSTALLED", dest, flush=True)
    print("GODOT_WINDOWS_TEMPLATES_READY", VERSION, flush=True)


if __name__ == "__main__":
    main()
