  1 | param(
  2 |     [Parameter(Mandatory = $true)]
  3 |     [string]$ProjectPath
  4 | )
  5 | 
  6 | $ErrorActionPreference = "Stop"
  7 | $GodotExe = "D:\Godot\Godot_v4.7-stable_win64.exe"
  8 | $project = [System.IO.Path]::GetFullPath($ProjectPath).TrimEnd('\')
  9 | 
 10 | if (-not (Test-Path -LiteralPath $GodotExe)) {
 11 |     throw "Godot executable not found: $GodotExe"
 12 | }
 13 | 
 14 | function Get-BrokenFrameImports {
 15 |     param([string]$ProjectRoot)
 16 | 
 17 |     $assetRoot = Join-Path $ProjectRoot "assets_display\wuzi_chibi"
 18 |     if (-not (Test-Path -LiteralPath $assetRoot)) {
 19 |         throw "Desktop-pet asset root not found: $assetRoot"
 20 |     }
 21 | 
 22 |     $frames = @(
 23 |         Get-ChildItem -LiteralPath $assetRoot -Recurse -File -Filter "*.png" |
 24 |             Where-Object { $_.Directory.Name -eq "frames" }
 25 |     )
 26 |     if ($frames.Count -eq 0) {
 27 |         throw "No runtime PNG frames found under: $assetRoot"
 28 |     }
 29 | 
 30 |     $broken = New-Object System.Collections.Generic.List[string]
 31 |     foreach ($frame in $frames) {
 32 |         $sidecar = "$($frame.FullName).import"
 33 |         if (-not (Test-Path -LiteralPath $sidecar)) {
 34 |             $broken.Add($frame.FullName)
 35 |             continue
 36 |         }
 37 | 
 38 |         $importText = [System.IO.File]::ReadAllText($sidecar)
 39 |         $match = [regex]::Match($importText, '(?m)^path="res://([^"]+)"')
 40 |         if (-not $match.Success) {
 41 |             $broken.Add($frame.FullName)
 42 |             continue
 43 |         }
 44 | 
 45 |         $relativeImportedPath = $match.Groups[1].Value.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
 46 |         $importedPath = Join-Path $ProjectRoot $relativeImportedPath
 47 |         if (-not (Test-Path -LiteralPath $importedPath)) {
 48 |             $broken.Add($frame.FullName)
 49 |         }
 50 |     }
 51 | 
 52 |     return @($broken)
 53 | }
 54 | 
 55 | function Repair-GodotImportsIfNeeded {
 56 |     param([string]$ProjectRoot)
 57 | 
 58 |     $broken = @(Get-BrokenFrameImports -ProjectRoot $ProjectRoot)
 59 |     if ($broken.Count -eq 0) {
 60 |         return
 61 |     }
 62 | 
 63 |     Write-Host "Detected $($broken.Count) missing or broken Godot frame imports. Repairing..."
 64 |     $quotedProject = '"' + $ProjectRoot + '"'
 65 |     $importProcess = Start-Process -FilePath $GodotExe -ArgumentList @("--headless", "--editor", "--import", "--path", $quotedProject) -Wait -PassThru
 66 |     if ($importProcess.ExitCode -ne 0) {
 67 |         throw "Godot asset import failed with exit code $($importProcess.ExitCode)"
 68 |     }
 69 | 
 70 |     $remaining = @(Get-BrokenFrameImports -ProjectRoot $ProjectRoot)
 71 |     if ($remaining.Count -gt 0) {
 72 |         $sample = ($remaining | Select-Object -First 5) -join "; "
 73 |         throw "Godot import repair did not restore all runtime frames. Remaining: $sample"
 74 |     }
 75 | 
 76 |     Write-Host "Godot frame imports repaired successfully."
 77 | }
 78 | 
 79 | $existing = Get-CimInstance Win32_Process | Where-Object {
 80 |     $_.CommandLine -and
 81 |     $_.CommandLine -like "*Godot_v4.7-stable_win64.exe*" -and
 82 |     $_.CommandLine -like "*$project*" -and
 83 |     $_.CommandLine -notlike "*--editor*"
 84 | }
 85 | 
 86 | foreach ($proc in $existing) {
 87 |     try {
 88 |         Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
 89 |     } catch {
 90 |         Write-Warning "Could not stop old pet process $($proc.ProcessId): $($_.Exception.Message)"
 91 |     }
 92 | }
 93 | 
 94 | Start-Sleep -Milliseconds 180
 95 | Repair-GodotImportsIfNeeded -ProjectRoot $project
 96 | $started = Start-Process -FilePath $GodotExe -ArgumentList @("--path", $project) -PassThru
 97 | @{
 98 |     pid = $started.Id
 99 |     project = $project
    executable = $GodotExe
} | ConvertTo-Json -Compress
