# 起夜监督、早睡打卡和更新安装参数：隔离配置、静音、模拟关机请求。
function Assert-Watch([bool]$Pass,[string]$Message){if(-not $Pass){throw $Message}}
$cfg.Voice=$false;$cfg.DesktopPet=$false;$cfg.Enabled=$true;$cfg.Action='Shutdown';$cfg.Bedtime='02:00';$cfg.WeekendBedtime='';$cfg.Grace=30;$cfg.SleepHours=6;$cfg.WakeGrace=5
$cfg.Cancelled='';$cfg.Deferred='';$cfg.CaughtNight='';$cfg.CaughtCount=0;$script:nights=@{};$script:lastSeen=[datetime]::MinValue
$night=[datetime]'2026-10-14T03:20:00';$key=(Get-NightState $night $cfg).Key
$cfg.GuardedNight=$key;$script:lastPhase='';$script:lastAttempt=[datetime]::MinValue;$before=$script:testShutdownRequests

# 1. 关机后 03:20 又开机：进入起夜监督，给 5 分钟
Invoke-GuardTick $night
Assert-Watch ($dialog -and $script:caughtMode) 'Booting inside the sleep window after a guarded night must open the watch'
Assert-Watch ($script:deadline -eq $night.AddMinutes(5) -and $dialog.FindName('Remaining').Text -eq '05:00') 'Watch must grant exactly WakeGrace minutes'
Assert-Watch ($script:lastSpokenLine.cue -eq 'caught' -and $dialog.FindName('Headline').Text -like '*被晚晚发现*') 'Caught line and headline must be shown'
Assert-Watch ($dialog.FindName('Defer').Visibility -eq [Windows.Visibility]::Collapsed -and $dialog.FindName('CancelNight').Content -like '*急事*') 'Watch must offer only the emergency option'
Assert-Watch ($script:nights[$key] -eq 'caught' -and $cfg.CaughtCount -eq 1) 'Night must be recorded as caught'
$dialog.UpdateLayout();$bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$dialog.ActualWidth,[int]$dialog.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($dialog);$enc=[Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp));$file=[IO.File]::Create((Join-Path $root 'output\caught-watch.png'));$enc.Save($file);$file.Dispose()

# 2. 5 分钟内不请求；到点先播“别再尝试了”，再模拟关机
Invoke-GuardTick ($night.AddMinutes(4))
Assert-Watch ($script:testShutdownRequests -eq $before) 'No request inside the grace period'
Invoke-GuardTick ($night.AddMinutes(5))
Assert-Watch ($script:lastSpokenLine.cue -eq 'final' -and $script:testShutdownRequests -eq $before) 'Final watch line must precede the request'
Invoke-GuardTick ($night.AddMinutes(5).AddSeconds(2))
Assert-Watch ($script:testShutdownRequests -eq $before+1) 'Watch expiry must reach the simulated power request'
Assert-Watch ($script:nights[$key] -eq 'caught') 'A later successful request must not erase the caught record'

# 3. 第二次被发现：换一句台词
$cfg.Enabled=$false;$dialog.Close();$cfg.Enabled=$true;$script:lastAttempt=[datetime]::MinValue
Invoke-GuardTick ($night.AddMinutes(20))
Assert-Watch ($script:caughtMode -and $script:lastSpokenLine.cue -eq 'caught-again' -and $cfg.CaughtCount -eq 2) 'Second wake-up must use the caught-again line'

# 4. 守护时间（02:00 + 6 小时）一过就结束监督
Invoke-GuardTick ([datetime]'2026-10-14T08:00:00')
Assert-Watch (-not $dialog -and -not $script:caughtMode) 'Watch must end when the sleep window ends'

# 5. 没有关机记录的夜晚（比如电脑本来就开着）不算“又起来”，仍是两分钟保存窗口
$cfg.GuardedNight='';$script:lastPhase='';$script:lastAttempt=[datetime]::MinValue
Invoke-GuardTick ([datetime]'2026-10-15T03:20:00')
Assert-Watch ($dialog -and -not $script:caughtMode -and $script:deadline -eq [datetime]'2026-10-15T03:22:00') 'Unguarded overdue night keeps the two-minute save window'
$cfg.Enabled=$false;$dialog.Close();$cfg.Enabled=$true

# 6. 早上的打卡问候 + 连续天数显示
$script:allowGreetingInTests=$true;$cfg.DesktopPet=$true;$cfg.GreetedNight=''
# 02:00 的睡觉时间：2026-10-15 凌晨那一晚的记录键是 2026-10-15。
$script:nights=@{'2026-10-15'='slept';'2026-10-14'='early';'2026-10-13'='slept'};$script:lastSeen=[datetime]'2026-10-15T08:59:00'
Invoke-GuardTick ([datetime]'2026-10-15T09:00:00')
Assert-Watch ($script:lastSpokenLine.cue -eq 'streak' -and $cfg.GreetedNight -eq '2026-10-15') 'Morning greeting must report last night once'
Assert-Watch ($popup -and $popup.FindName('PopupText').Text -like '*连续早睡 3 天*') 'Greeting bubble must show the streak'
Assert-Watch ($ui.StreakText.Text -like '*已连续早睡 3 天*') 'Main window must show the streak'
$spoken=$script:lastSpokenLine;Invoke-GuardTick ([datetime]'2026-10-15T09:00:05')
Assert-Watch ([object]::ReferenceEquals($spoken,$script:lastSpokenLine)) 'Greeting must not repeat'
$popup.UpdateLayout();$bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$popup.ActualWidth,[int]$popup.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($popup);$enc=[Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp));$file=[IO.File]::Create((Join-Path $root 'output\streak-greeting.png'));$enc.Save($file);$file.Dispose()
$popup.Close();$script:allowGreetingInTests=$false;$cfg.DesktopPet=$false

# 7. 守护期间更新：安装参数带上原截止时间，晚晚重启后恢复同一个倒计时
$cfg.GuardedNight='';$script:lastPhase='';Invoke-GuardTick ([datetime]'2026-10-16T03:20:00')
Install-DownloadedUpdate 'C:\Temp\WanwanUpdate\extracted\Wanwan'
$joined=$script:testUpdateArguments -join ' '
Assert-Watch ($joined -match '-WaitPid \d+' -and $joined -match [regex]::Escape('-ResumeDeadline "'+$script:deadline.ToString('o')+'"') -and $joined -match '-Target') 'Update must wait for this process and resume the active countdown'
Assert-Watch (Test-Path (Join-Path ([IO.Path]::GetTempPath()) 'WanwanUpdate\ApplyUpdate.ps1')) 'Installer must run from a temporary copy'
$cfg.Enabled=$false;$dialog.Close()
Assert-Watch ($ui.CheckUpdate -and $ui.FooterText.Text -like ('*v'+$script:appVersion)) 'Update button and version must be visible'
Write-Output 'Watch tests passed: caught-after-shutdown with 5-minute grace, final line before simulated request, repeat line, window end, unguarded overdue unchanged, morning streak greeting once, update resumes countdown. No native power call.'
