Option Explicit
Dim shell, fso, baseDir, ps1, projectDir, cmd

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = baseDir & "\tools\restart_godot_pet.ps1"
projectDir = baseDir & "\godot"
cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File " & _
      Chr(34) & ps1 & Chr(34) & " -ProjectPath " & Chr(34) & projectDir & Chr(34)

shell.Run cmd, 0, False
