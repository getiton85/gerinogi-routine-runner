Set shell = CreateObject("Shell.Application")
base = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File """ & base & "\local_state_routine_runner.ps1"""
shell.ShellExecute "powershell.exe", args, base, "runas", 2