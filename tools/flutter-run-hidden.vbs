' SGP-Agent: Android 빌드/실행 시 cmd 창 숨김
Set shell = CreateObject("WScript.Shell")
projectRoot = CreateObject("Scripting.FileSystemObject").GetParentFolderName(
  CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName))
cmd = "cmd /c cd /d """ & projectRoot & """ && tools\flutter-direct.cmd run -d R3CW203HFGK"
shell.Run cmd, 0, False
