 1 | $ErrorActionPreference = 'Stop'
 2 | $taskRoot = Split-Path $PSScriptRoot -Parent
 3 | $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
 4 | $vsRoot = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
 5 | if (-not $vsRoot) { throw '需要 Visual Studio C++ Build Tools 和 Windows SDK。' }
 6 | $buildDir = Join-Path $taskRoot 'work/file_bridge_build'
 7 | $outDir = Join-Path $taskRoot 'godot/native'
 8 | New-Item -ItemType Directory -Force -Path $buildDir, $outDir | Out-Null
 9 | $source = Join-Path $PSScriptRoot 'native/file_bridge.cpp'
$output = Join-Path $outDir 'wuzi_file_bridge.exe'
$vcvars = Join-Path $vsRoot 'VC/Auxiliary/Build/vcvars64.bat'
Push-Location $buildDir
try {
    # No shell-expanded input paths come from users or file workbench parameters.
    @"
@echo off
call "$vcvars" >nul
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /EHsc /O2 /MT /DUNICODE /D_UNICODE ../../tools/native/file_bridge.cpp /Fe:../../godot/native/wuzi_file_bridge.exe /link ole32.lib oleaut32.lib windowscodecs.lib shlwapi.lib
"@ | Set-Content -LiteralPath 'build.cmd' -Encoding ascii
    & $env:ComSpec /d /c build.cmd
    if ($LASTEXITCODE -ne 0) { throw "C++ build failed: $LASTEXITCODE" }
} finally { Pop-Location }
Get-FileHash -LiteralPath $output -Algorithm SHA256
