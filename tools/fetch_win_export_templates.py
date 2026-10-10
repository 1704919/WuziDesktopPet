  1 | """Install only official Godot 4.7 Windows x64 export templates via HTTP ranges.
  2 | 
  3 | The upstream export_templates.tpz is >1 GiB; this downloader extracts
  4 | only the Windows desktop members without fetching unrelated platform files.
  5 | It does not alter the desktop pet source or runtime assets.
  6 | """
  7 | from __future__ import annotations
  8 | 
  9 | import argparse
 10 | import io
 11 | import os
 12 | import shutil
 13 | import time
 14 | import urllib.request
 15 | import zipfile
 16 | from pathlib import Path
 17 | 
 18 | VERSION = "4.7.stable"
 19 | URL = (
 20 |     "https://godot-releases.nbg1.your-objectstorage.com/"
 21 |     "4.7-stable/Godot_v4.7-stable_export_templates.tpz"
 22 | )
 23 | TARGETS = (
 24 |     "windows_release_x86_64.exe",
 25 |     "windows_debug_x86_64.exe",
 26 | )
 27 | BLOCK = 4 * 1024 * 1024
 28 | 
 29 | 
 30 | class HTTPRangeReader(io.RawIOBase):
 31 |     def __init__(self, url: str):
 32 |         self.url = url
 33 |         request = urllib.request.Request(url, method="HEAD")
 34 |         with urllib.request.urlopen(request, timeout=35) as resp:
 35 |             self.length = int(resp.headers["Content-Length"])
 36 |             if resp.status != 200:
 37 |                 raise RuntimeError(f"Cannot query official archive: {resp.status}")
 38 |         self.position = 0
 39 |         self.cached_from = -1
 40 |         self.cached = b""
 41 | 
 42 |     def readable(self):
 43 |         return True
 44 | 
 45 |     def seekable(self):
 46 |         return True
 47 | 
 48 |     def tell(self):
 49 |         return self.position
 50 | 
 51 |     def seek(self, offset, whence=os.SEEK_SET):
 52 |         if whence == os.SEEK_SET:
 53 |             position = offset
 54 |         elif whence == os.SEEK_CUR:
 55 |             position = self.position + offset
 56 |         elif whence == os.SEEK_END:
 57 |             position = self.length + offset
 58 |         else:
 59 |             raise ValueError(whence)
 60 |         self.position = max(0, position)
 61 |         return self.position
 62 | 
 63 |     def _read_range(self, start, end):
 64 |         for retry in range(4):
 65 |             try:
 66 |                 req = urllib.request.Request(
 67 |                     self.url, headers={"Range": f"bytes={start}-{end - 1}"}
 68 |                 )
 69 |                 with urllib.request.urlopen(req, timeout=100) as resp:
 70 |                     if resp.status != 206:
 71 |                         raise RuntimeError("Server ignored HTTP Range; aborting full download")
 72 |                     part = resp.read()
 73 |                     if len(part) != end - start:
 74 |                         raise RuntimeError("Partial download truncated")
 75 |                     return part
 76 |             except (OSError, RuntimeError):
 77 |                 if retry == 3:
 78 |                     raise
 79 |                 time.sleep(retry + 1)
 80 |         raise AssertionError("unreachable")
 81 | 
 82 |     def read(self, size=-1):
 83 |         if size < 0:
 84 |             size = self.length - self.position
 85 |         size = min(size, max(0, self.length - self.position))
 86 |         if size <= 0:
 87 |             return b""
 88 |         parts = []
 89 |         remaining = size
 90 |         while remaining:
 91 |             if not (self.cached_from <= self.position < self.cached_from + len(self.cached)):
 92 |                 start = (self.position // BLOCK) * BLOCK
 93 |                 end = min(start + BLOCK, self.length)
 94 |                 self.cached = self._read_range(start, end)
 95 |                 self.cached_from = start
 96 |             offset = self.position - self.cached_from
 97 |             count = min(remaining, len(self.cached) - offset)
 98 |             parts.append(self.cached[offset:offset + count])
 99 |             self.position += count
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
