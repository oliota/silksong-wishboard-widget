Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
base = fso.GetParentFolderName(WScript.ScriptFullName)
script = base & "\widget.ps1"
shell.CurrentDirectory = base
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File """ & script & """", 0, False
