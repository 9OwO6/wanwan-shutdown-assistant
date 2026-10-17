function Assert-Guard([bool]$Pass,[string]$Message){if(-not $Pass){throw $Message}}
$testNow=[datetime]'2026-10-11T03:37:00';$cfg.Bedtime='02:00';$cfg.Grace=30;$cfg.Cancelled='';$cfg.Deferred='';$cfg.VoicePreset='N1';$cfg.Voice=$false;$cfg.Enabled=$false
Invoke-GuardTick $testNow
Assert-Guard ($ui.ModeLabel.Text -eq '仅陪伴 · 不会自动关机' -and -not $dialog) 'Disabled guard displayed misleading state or opened shutdown'
$cfg.Enabled=$true;Invoke-GuardTick $testNow
Assert-Guard ($dialog -and $script:deadline -eq $testNow.AddMinutes(2)) 'Overdue startup must give exactly two minutes to save'
Assert-Guard ($dialog.FindName('Remaining').Text -eq '02:00' -and $script:lastSpokenLine.cue -eq 'due') 'Overdue dialog must show 02:00 immediately and the overdue line'
$dialog.UpdateLayout();$bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new(410,610,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($dialog);$enc=[Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp));$file=[IO.File]::Create((Join-Path $root 'output\overdue-reminder.png'));$enc.Save($file);$file.Dispose()
Invoke-GuardTick ($testNow.AddSeconds(119));Assert-Guard ($script:testShutdownRequests -eq 0) 'Shutdown requested before saving time elapsed'
Invoke-GuardTick ($testNow.AddMinutes(2));Assert-Guard ($script:testShutdownRequests -eq 0 -and $script:lastSpokenLine.cue -eq 'shutdown') 'Final announcement must precede shutdown'
Invoke-GuardTick ($testNow.AddSeconds(121));Assert-Guard ($script:testShutdownRequests -eq 0) 'Announcement display was cut short'
Invoke-GuardTick ($testNow.AddSeconds(122));Assert-Guard ($script:testShutdownRequests -eq 1) 'Deadline did not reach simulated normal shutdown'
Invoke-GuardTick ($testNow.AddSeconds(123));Assert-Guard ($script:testShutdownRequests -eq 1) 'Shutdown retry fired too early'
$cfg.Enabled=$false;$dialog.Close();$script:lastAttempt=[datetime]::MinValue;$script:lastPhase='';$cfg.Enabled=$true
Invoke-GuardTick $testNow;Invoke-GuardTick ($testNow.AddMinutes(2));$cfg.Cancelled=(Get-NightState $testNow $cfg).Key;Invoke-GuardTick ($testNow.AddMinutes(3))
Assert-Guard ($script:testShutdownRequests -eq 1 -and -not $script:shutdownAfter) 'Cancellation must prevent pending shutdown'
$cfg.Enabled=$false;$dialog.Close();$cfg.Cancelled='';$script:lastPhase=''
# Open all three new N1 files through the actual WPF media engine, at zero volume.
$script:voicePlayer.Volume=0
foreach($cue in @('due','shutdown','disabled')){
 $cfg.Voice=$true;$script:guardMediaReady=$false;$loop=[Windows.Threading.DispatcherFrame]::new()
 $handler=[System.EventHandler]{$script:guardMediaReady=$true;$loop.Continue=$false};$script:voicePlayer.Add_MediaOpened($handler)
 Say-GuardLine $cue
 $wait=[Windows.Threading.DispatcherTimer]::new();$wait.Interval=[timespan]::FromSeconds(4);$wait.Add_Tick({$loop.Continue=$false;$wait.Stop()});$wait.Start();[Windows.Threading.Dispatcher]::PushFrame($loop);$wait.Stop();$script:voicePlayer.Remove_MediaOpened($handler)
 Assert-Guard $script:guardMediaReady ('Native muted audio open failed: '+$cue);Stop-Voice
}
$cfg.Voice=$false;$cfg.Enabled=$true;$script:lastAttempt=[datetime]::MinValue
Invoke-GuardTick $testNow
$cfg.Voice=$true;Invoke-GuardTick ($testNow.AddMinutes(2));Stop-Voice
Assert-Guard (($script:shutdownAfter-$testNow.AddMinutes(2)).TotalSeconds -ge $script:lastGuardDuration) 'Voiced announcement duration not reserved'
$cfg.Enabled=$false;$dialog.Close();$script:shutdownAfter=$null;$cfg.Voice=$false
# Sleep action: no "shutdown" recording, a goodnight line before the simulated request, then a fresh two-minute window.
$cfg.Action='Sleep';$cfg.Enabled=$true;$cfg.Cancelled='';$script:lastAttempt=[datetime]::MinValue;$script:lastPhase='';$sleepBefore=$script:testShutdownRequests
Invoke-GuardTick $testNow
Assert-Guard ($dialog -and $script:lastSpokenLine.cue -eq 'final' -and $dialog.FindName('Safety').Text -like '*睡眠*' -and $ui.ModeLabel.Text -like '*睡眠*') 'Sleep mode overdue reminder must avoid the shutdown recording and say sleep'
Invoke-GuardTick ($testNow.AddMinutes(2))
Assert-Guard ($script:lastSpokenLine.cue -eq 'goodnight' -and $script:testShutdownRequests -eq $sleepBefore) 'Sleep announcement must be a goodnight line before the request'
Invoke-GuardTick ($testNow.AddSeconds(122))
Assert-Guard ($script:testShutdownRequests -eq $sleepBefore+1 -and $dialog -and $script:deadline -eq $testNow.AddSeconds(122).AddMinutes(2)) 'Simulated sleep must keep the countdown and reset a two-minute save window'
Invoke-GuardTick ($testNow.AddHours(5))
Assert-Guard (-not $dialog) 'Countdown must close once the night window has ended'
$cfg.Enabled=$false;$cfg.Action='Shutdown';if($dialog){$dialog.Close()};$script:shutdownAfter=$null
Assert-Guard ([Wanwan.Power]::TokenStructureSize -eq 16) 'Native TOKEN_PRIVILEGES layout must be 16 bytes'
$privilege=[Wanwan.Power]::TryEnableShutdownPrivilege();$powerError=[Wanwan.Power]::LastError
Assert-Guard ($privilege -and $powerError -eq 0) ('Shutdown privilege unavailable; error='+$powerError)
@{scenario='02:00 bedtime, 30 minutes grace, now 03:37';initialSeconds=120;simulatedRequests=$script:testShutdownRequests;nativeShutdownCalled=$false;nativeTokenBytes=[Wanwan.Power]::TokenStructureSize;privilegeEnabled=$privilege;privilegeError=$powerError;mutedNativeAudioClips=3;cancelPendingPassed=$true;voiceWaitPassed=$true}|ConvertTo-Json|Set-Content (Join-Path $root 'output\guard-runtime-report.json') -Encoding UTF8
Write-Output 'Guard tests passed: overdue at 03:37, sleep action (goodnight line, fresh save window, end-of-night close), save countdown, announcement before simulated request, retry, cancellation, 3 muted native audio opens, correct privilege layout and safe privilege enable. No native shutdown called.'
