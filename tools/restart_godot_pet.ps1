param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath
)

$ErrorActionPreference = "Stop"
$GodotExe = "D:\Godot\Godot_v4.7-stable_win64.exe"
$project = [System.IO.Path]::GetFullPath($ProjectPath).TrimEnd('\')

if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot executable not found: $GodotExe"
}

function Get-BrokenFrameImports {
    param([string]$ProjectRoot)

    $assetRoot = Join-Path $ProjectRoot "assets_display\wuzi_chibi"
    if (-not (Test-Path -LiteralPath $assetRoot)) {
        throw "Desktop-pet asset root not found: $assetRoot"
    }

    $frames = @(
        Get-ChildItem -LiteralPath $assetRoot -Recurse -File -Filter "*.png" |
            Where-Object { $_.Directory.Name -eq "frames" }
    )
    if ($frames.Count -eq 0) {
        throw "No runtime PNG frames found under: $assetRoot"
    }

    $broken = New-Object System.Collections.Generic.List[string]
    foreach ($frame in $frames) {
        $sidecar = "$($frame.FullName).import"
        if (-not (Test-Path -LiteralPath $sidecar)) {
            $broken.Add($frame.FullName)
            continue
        }

        $importText = [System.IO.File]::ReadAllText($sidecar)
        $match = [regex]::Match($importText, '(?m)^path="res://([^"]+)"')
        if (-not $match.Success) {
            $broken.Add($frame.FullName)
            continue
        }

        $relativeImportedPath = $match.Groups[1].Value.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $importedPath = Join-Path $ProjectRoot $relativeImportedPath
        if (-not (Test-Path -LiteralPath $importedPath)) {
            $broken.Add($frame.FullName)
        }
    }

    return @($broken)
}

function Repair-GodotImportsIfNeeded {
    param([string]$ProjectRoot)

    $broken = @(Get-BrokenFrameImports -ProjectRoot $ProjectRoot)
    if ($broken.Count -eq 0) {
        return
    }

    Write-Host "Detected $($broken.Count) missing or broken Godot frame imports. Repairing..."
    $quotedProject = '"' + $ProjectRoot + '"'
    $importProcess = Start-Process -FilePath $GodotExe -ArgumentList @("--headless", "--editor", "--import", "--path", $quotedProject) -Wait -PassThru
    if ($importProcess.ExitCode -ne 0) {
        throw "Godot asset import failed with exit code $($importProcess.ExitCode)"
    }

    $remaining = @(Get-BrokenFrameImports -ProjectRoot $ProjectRoot)
    if ($remaining.Count -gt 0) {
        $sample = ($remaining | Select-Object -First 5) -join "; "
        throw "Godot import repair did not restore all runtime frames. Remaining: $sample"
    }

    Write-Host "Godot frame imports repaired successfully."
}

$existing = Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -and
    $_.CommandLine -like "*Godot_v4.7-stable_win64.exe*" -and
    $_.CommandLine -like "*$project*" -and
    $_.CommandLine -notlike "*--editor*"
}

foreach ($proc in $existing) {
    try {
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
    } catch {
        Write-Warning "Could not stop old pet process $($proc.ProcessId): $($_.Exception.Message)"
    }
}

Start-Sleep -Milliseconds 180
Repair-GodotImportsIfNeeded -ProjectRoot $project
$started = Start-Process -FilePath $GodotExe -ArgumentList @("--path", $project) -PassThru
@{
    pid = $started.Id
    project = $project
    executable = $GodotExe
} | ConvertTo-Json -Compress
