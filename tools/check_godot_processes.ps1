$ErrorActionPreference = "Stop"
$items = Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -and $_.CommandLine -like "*Godot_v4.7-stable_win64*"
} | Select-Object ProcessId, Name, CommandLine
$items | ConvertTo-Json -Depth 3
