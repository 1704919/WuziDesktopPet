 1 | Option Explicit
 2 | Dim shell, fso, baseDir, ps1, projectDir, cmd
 3 | 
 4 | Set shell = CreateObject("WScript.Shell")
 5 | Set fso = CreateObject("Scripting.FileSystemObject")
 6 | 
 7 | baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
 8 | ps1 = baseDir & "\tools\restart_godot_pet.ps1"
 9 | projectDir = baseDir & "\godot"
cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File " & _
      Chr(34) & ps1 & Chr(34) & " -ProjectPath " & Chr(34) & projectDir & Chr(34)

shell.Run cmd, 0, False
