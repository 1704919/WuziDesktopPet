"""Prepare two isolated visual QA copies on D:, without touching either ZIP."""
from __future__ import annotations

import shutil
import struct
import zipfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "work" / "release_slim_visual_review"
DIST = ROOT / "dist"
VERSIONS = ["v0.1.0", "v0.1.1-rc2"]


def extract_safe(src: Path, dst: Path) -> Path:
    folder_name = src.stem
    with zipfile.ZipFile(src) as z:
        if z.testzip() is not None:
            raise RuntimeError(f"Broken ZIP: {src}")
        for member in z.namelist():
            p = Path(member)
            if p.is_absolute() or ".." in p.parts or not member.startswith(folder_name + "/"):
                raise RuntimeError(f"Unexpected ZIP entry: {member}")
        z.extractall(dst)
    result = dst / folder_name
    if not (result / "舞梓桌宠.exe").is_file():
        raise RuntimeError(f"EXE missing: {result}")
    return result


def png_chunk(name: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + name + data + struct.pack(
        ">I", zlib.crc32(name + data) & 0xFFFFFFFF)


def make_sample(path: Path) -> None:
    # A tiny valid opaque RGB test image; not a project character asset.
    width, height = 16, 16
    scan = b"".join(
        b"\x00" + b"".join(
            bytes((x * 12, y * 12, (x + y) * 6))
            for x in range(width))
        for y in range(height)
    )
    data = (b"\x89PNG\r\n\x1a\n" +
            png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height,
                                          8, 2, 0, 0, 0)) +
            png_chunk(b"IDAT", zlib.compress(scan)) +
            png_chunk(b"IEND", b""))
    path.write_bytes(data)


def main() -> None:
    if OUT.exists():
        raise RuntimeError("Review directory already exists; refusing to overwrite it")
    required = [DIST / f"WuziDesktopPet-{v}-win64.zip" for v in VERSIONS]
    if not all(p.is_file() for p in required):
        raise RuntimeError("v0.1.0 and candidate ZIP must both be present")
    free = shutil.disk_usage(ROOT).free
    if free < 800 * 1024 * 1024:
        raise RuntimeError("Need at least 800 MiB free on project drive for QA copies")
    OUT.mkdir(parents=True)
    paths = []
    for version, source in zip(VERSIONS, required):
        package = extract_safe(source, OUT / version)
        # This is added only to the disposable unpacked QA copy.
        isolated_name = ("WuziPetManualBaseline_20261010"
                         if version == "v0.1.0" else "WuziPetManualSlimRC1_20261010")
        (package / "override.cfg").write_text(
            '[application]\nconfig/use_custom_user_dir=true\n' +
            f'config/custom_user_dir_name="{isolated_name}"\n',
            encoding="utf-8")
        paths.append((version, package))
    samples = OUT / "测试文件"
    samples.mkdir()
    make_sample(samples / "测试图片_1.png")
    make_sample(samples / "测试图片_2.png")
    guide = [
        "# Windows 轻量候选版人工视觉验收（待用户确认）",
        "",
        "以下两套是独立解压副本；旧 v0.1.0 ZIP、现有用户设置和原素材不变。",
        "请一次只运行一套，退出桌宠后再打开另一套，避免两个置顶窗口重叠。",
        "",
        "## 启动位置",
        "",
    ]
    for version, package in paths:
        guide.append(f"- {version}：{package / '舞梓桌宠.exe'}")
    guide += [
        "",
        "## 要求逐项人工勾选",
        "",
        "- [ ] 正常启动，角色不变黑、不消失，待机循环没有断层。",
        "- [ ] 比较皮肤颜色、眼睛、头发、服装与透明抠像边缘，无变化。",
        "- [ ] 比较点击开心、害羞、惊吓及连续 Q 弹，无新闪烁、动作大小变化。",
        "- [ ] 从右键动作分类中点播全部动作，逐个对照旧版（37 个非待机动作）。",
        "- [ ] 尤其查看 sleep_down → sleep_loop → wake_up → idle，确认惊醒没有缩放，人物肤色正常。",
        "- [ ] 检查普通动作进出场淡入淡出与回待机时有无闪白、闪黑、残影。",
        "- [ ] 检查拖拽、抛掷、动态命中区域、漫游行走方向与动作同步。",
        "- [ ] 检查右键菜单、聊天输入中文、昵称、气泡、天气和提醒。",
        "- [ ] 用“测试文件”里的图片在文件处理窗口试验重命名和转换，核对输出目录。",
        "- [ ] 检查随机动作和自动睡眠机制（需要较长时间观察）。",
        "- [ ] 关闭后重新启动，核对候选版昵称、偏好仍可保存。",
        "",
        "如果任意项目失败，请不要发布。报告版本、动作名和具体画面现象。",
        "本文件中的勾选只有使用者亲自确认后才视为通过。",
    ]
    (OUT / "人工视觉验收清单.md").write_text(
        "\n".join(guide) + "\n", encoding="utf-8")
    print("VISUAL_REVIEW_PREPARED", OUT, flush=True)
    for version, package in paths:
        print("REVIEW_EXE", version, package / "舞梓桌宠.exe", flush=True)
    print("MANUAL_APPROVAL_PENDING", flush=True)


if __name__ == "__main__":
    main()
