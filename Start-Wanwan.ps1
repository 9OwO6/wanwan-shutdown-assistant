$ErrorActionPreference='Stop'
$entry=Join-Path $PSScriptRoot 'app\Main.ps1'
Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',('"'+$entry+'"')) -WorkingDirectory $PSScriptRoot -WindowStyle Hidden
