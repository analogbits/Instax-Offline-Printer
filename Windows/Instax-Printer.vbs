' Instax Offline Printer — Silent Windows Launcher (Zero-Install)
Set objFSO = CreateObject("Scripting.FileSystemObject")
strDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
strBat = strDir & "\Instax-Printer.bat"

Set WshShell = CreateObject("WScript.Shell")
' Window style 0 = Hidden (no black CMD prompt appears)
WshShell.Run """" & strBat & """", 0, False
