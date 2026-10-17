$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\app\UpdateCore.ps1"
function Assert-Update([bool]$Pass,[string]$Message){if(-not $Pass){throw $Message}}

Assert-Update (Test-NewerRelease '0.3.0' 'v0.4.0') 'v0.4.0 must be newer than 0.3.0'
Assert-Update (Test-NewerRelease '0.3.0' 'v0.3.1') 'patch release must be newer'
Assert-Update (Test-NewerRelease '0.3.9' 'v0.10.0') 'versions must compare numerically, not as text'
Assert-Update (-not (Test-NewerRelease '0.3.0' 'v0.3.0')) 'same version is not an update'
Assert-Update (-not (Test-NewerRelease '0.4.0' 'v0.3.5')) 'older release is not an update'
Assert-Update (-not (Test-NewerRelease '0.3.0' 'nightly')) 'unparseable tag must be ignored'

$good=[pscustomobject]@{name='Wanwan-v0.4.0-windows.zip';browser_download_url='https://github.com/9OwO6/wanwan-shutdown-assistant/releases/download/v0.4.0/Wanwan-v0.4.0-windows.zip';digest='sha256:abc'}
$foreign=[pscustomobject]@{name='Wanwan-v0.4.0-windows.zip';browser_download_url='https://example.com/Wanwan-v0.4.0-windows.zip'}
$source=[pscustomobject]@{name='Source code.zip';browser_download_url='https://github.com/9OwO6/wanwan-shutdown-assistant/archive/v0.4.0.zip'}
Assert-Update ((Select-UpdateAsset ([pscustomobject]@{assets=@($source,$good)})).name -eq $good.name) 'portable ZIP must be selected'
Assert-Update ($null -eq (Select-UpdateAsset ([pscustomobject]@{assets=@($foreign,$source)}))) 'assets from other hosts must be rejected'
Assert-Update ($null -eq (Select-UpdateAsset ([pscustomobject]@{assets=@()}))) 'release without assets has no update'

$summary=Get-UpdateSummary ([pscustomobject]@{body="## 晚晚 v0.4.0`r`n`r`n- **新功能**：起夜监督`r`n- 早睡打卡"})
Assert-Update ($summary -eq "晚晚 v0.4.0`n- 新功能：起夜监督`n- 早睡打卡") "Release notes summary wrong: $summary"

# 安装脚本：覆盖已有文件、新增文件、保留额外文件、源不完整时拒绝。
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('wanwan-update-test-'+[guid]::NewGuid().ToString('N'))
$src=Join-Path $tmp 'new';$dst=Join-Path $tmp '晚晚 目标'
foreach($d in @("$src/app","$src/assets/voices/N1-watch","$dst/app")){New-Item -ItemType Directory -Force $d|Out-Null}
Set-Content "$src/app/Main.ps1" 'new main';Set-Content "$src/assets/voices/N1-watch/a.mp3" 'clip';Set-Content "$src/VERSION" '0.4.0'
Set-Content "$dst/app/Main.ps1" 'old main';Set-Content "$dst/user-note.txt" 'keep me'
$log=Join-Path $tmp 'update.log'
& "$PSScriptRoot\..\app\ApplyUpdate.ps1" -Source $src -Target $dst -LogFile $log -NoLaunch
Assert-Update ((Get-Content "$dst/app/Main.ps1") -eq 'new main') 'existing file must be overwritten'
Assert-Update ((Get-Content "$dst/assets/voices/N1-watch/a.mp3") -eq 'clip' -and (Get-Content "$dst/VERSION") -eq '0.4.0') 'new files and folders must be created'
Assert-Update ((Get-Content "$dst/user-note.txt") -eq 'keep me') 'extra files must be kept'
Assert-Update ((Get-Content $log -Raw) -match 'Update applied: 3 files') 'success must be logged'
Remove-Item "$src/app/Main.ps1"
$failed=$false;try{& "$PSScriptRoot\..\app\ApplyUpdate.ps1" -Source $src -Target $dst -LogFile $log -NoLaunch}catch{$failed=$true}
Assert-Update ((Get-Content "$dst/app/Main.ps1") -eq 'new main' -and (Get-Content $log -Raw) -match 'Update failed') 'incomplete source must not be applied'
Remove-Item -LiteralPath $tmp -Recurse -Force
Write-Output '16 update tests passed (version order, asset origin, notes, file replacement, incomplete package rejected)'
# 上面故意让安装脚本失败过一次（exit 1）；测试本身全部通过时以 0 退出。
exit 0
