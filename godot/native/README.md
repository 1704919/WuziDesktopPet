 1 | # Windows 文件组件
 2 | 
 3 | `wuzi_file_bridge.exe` 是本项目 `tools/native/file_bridge.cpp` 的 x64 构建产物，源码按 MIT 提供。
 4 | 
 5 | - `move` 使用不带 `MOVEFILE_REPLACE_EXISTING` 的 Windows API，不覆盖目标。
 6 | - `copy` 使用 `CopyFileW(..., TRUE)`，不覆盖目标。
 7 | - `probe` 使用独占创建、实际写入和关闭即删除的临时文件验证目录可写。
 8 | - `caps` 分别检测系统 HEIF 解码器和编码器；实际文件不受支持时仍会返回错误。
 9 | - `decode` / `encode` 使用 Windows Imaging Component，读取 HEIC/HEIF 第一帧或输出 HEIC。
- 不随程序分发 libheif、FFmpeg、HEIF/HEVC 编解码器。PNG/JPG/WebP 使用 Godot Image。

重建：在项目根目录运行 `tools/build_file_bridge.ps1`，需要 Visual Studio C++ Build Tools 和 Windows SDK。编译时静态链接 MSVC 运行库；最终用户不需要安装编译工具。

当前仍按项目目录启动。以后导出 Godot 程序时，必须将本文件夹中的 exe 作为外置文件复制到桌宠 exe 旁的 `native/` 子目录，不能只收入 PCK。运行时缺少组件会拒绝文件执行。系统 HEIC 能力与电脑已安装的 Windows 图片组件有关，不保证所有 Windows 电脑都具有相同能力。
