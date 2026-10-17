# 晚晚退出后，在独立进程里覆盖程序文件并重新启动。会先被复制到临时目录再运行，所以可以安全覆盖自身。
# 设置和打卡记录保存在 %LOCALAPPDATA%\WanwanShutdown，不受更新影响。
param(
    [int]$WaitPid = 0,
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Target,
    [string]$ResumeDeadline = '',
    [string]$LogFile = '',
    [switch]$NoLaunch
)
$ErrorActionPreference = 'Stop'
if (-not $LogFile) { $LogFile = Join-Path $env:LOCALAPPDATA 'WanwanShutdown\update.log' }
function Write-UpdateLog([string]$Message) { try { Add-Content -LiteralPath $LogFile -Value ((Get-Date -Format o) + ' ' + $Message) -Encoding UTF8 } catch {} }

$ok = $false
try {
    if ($WaitPid -gt 0) { try { Wait-Process -Id $WaitPid -Timeout 60 -ErrorAction Stop } catch {} }
    if (-not (Test-Path -LiteralPath (Join-Path $Source 'app/Main.ps1'))) { throw "Update source is incomplete: $Source" }
    if (-not (Test-Path -LiteralPath (Join-Path $Target 'app/Main.ps1'))) { throw "Target is not a Wanwan folder: $Target" }
    # 逐个文件覆盖（保留目标里额外的文件，例如用户自己放的快捷方式）。
    $files = Get-ChildItem -LiteralPath $Source -Recurse -File -Force
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($Source.TrimEnd('\', '/').Length).TrimStart('\', '/')
        $destination = Join-Path $Target $relative
        $folder = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Force $folder | Out-Null }
        for ($attempt = 1; $attempt -le 5; $attempt++) {
            try { Copy-Item -LiteralPath $file.FullName -Destination $destination -Force; break }
            catch { if ($attempt -eq 5) { throw }; Start-Sleep -Milliseconds 400 }
        }
    }
    $ok = $true
    Write-UpdateLog ("Update applied: {0} files from {1}" -f $files.Count, $Source)
} catch {
    Write-UpdateLog ('Update failed; previous version kept where not overwritten: ' + $_.Exception.Message)
}
if (-not $NoLaunch) {
    $arguments = @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"' + (Join-Path $Target 'app\Main.ps1') + '"'))
    if ($ResumeDeadline) { $arguments += @('-ResumeCountdownDeadline', ('"' + $ResumeDeadline + '"')) }
    Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $arguments -WorkingDirectory $Target -WindowStyle Hidden
}
if (-not $ok) { exit 1 }
