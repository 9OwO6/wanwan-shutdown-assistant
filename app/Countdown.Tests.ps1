function Assert-Countdown([bool]$Pass,[string]$Message){if(-not $Pass){throw $Message}}
function Wait-Countdown([int]$Milliseconds){$loop=[Windows.Threading.DispatcherFrame]::new();$wait=[Windows.Threading.DispatcherTimer]::new();$wait.Interval=[timespan]::FromMilliseconds($Milliseconds);$wait.Add_Tick({$loop.Continue=$false;$wait.Stop()});$wait.Start();[Windows.Threading.Dispatcher]::PushFrame($loop);$wait.Stop()}
function Capture-Countdown([string]$Name){$dialog.UpdateLayout();$bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$dialog.ActualWidth,[int]$dialog.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($dialog);$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$file=[IO.File]::Create((Join-Path $root ('output\'+$Name)));$encoder.Save($file);$file.Dispose()}
$cfg.Voice=$false;$cfg.DesktopPet=$false;$baseline=$script:surfaces.Count
Show-BedDialog $true;Wait-Countdown 100;Capture-Countdown 'countdown-expanded.png';$originalDeadline=$script:deadline
$dialog.FindName('Acknowledge').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));Wait-Countdown 100
Assert-Countdown ($script:deadline -eq $originalDeadline -and $dialog.Width -eq 190 -and $dialog.Height -eq 284) 'Acknowledge must compact without extending deadline'
Assert-Countdown ($dialog.FindName('FullReminder').Visibility -eq [Windows.Visibility]::Collapsed -and $script:miniDialogSurface.Image.Source) 'Compact view missing animated character'
Capture-Countdown 'countdown-compact.png'
$before=$dialog.FindName('MiniRemaining').Text;$timer.Start();try{Wait-Countdown 1500}finally{$timer.Stop()}
Assert-Countdown ($dialog.FindName('MiniRemaining').Text -ne $before) 'Compact countdown did not advance with real Dispatcher timer'
$dialog.FindName('MiniHide').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert-Countdown (-not $dialog.IsVisible -and $script:deadline -eq $originalDeadline) 'Hide altered deadline or destroyed countdown'
$showCountdown.PerformClick();Assert-Countdown ($dialog.IsVisible -and $script:countdownView -eq 'Compact') 'Tray did not restore hidden countdown'
$dialog.FindName('MiniExpand').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));Wait-Countdown 100
Assert-Countdown ($dialog.Width -eq 410 -and $script:deadline -eq $originalDeadline -and $dialog.FindName('CancelNight').IsVisible) 'Expand lost original controls/deadline'
$cancel=$dialog.FindName('CancelNight');$point=$cancel.TranslatePoint([Windows.Point]::new(0,0),$dialog)
Assert-Countdown ($point.Y+$cancel.ActualHeight -lt $dialog.ActualHeight) 'Third button clipped the emergency cancel control'
Set-CountdownView Hidden;$script:deadline=(Get-Date).AddSeconds(-1);Invoke-GuardTick
Assert-Countdown (-not $dialog -and $script:testShutdownRequests -eq 0) 'Hidden demo did not safely complete'
$cfg.Bedtime='02:00';$cfg.Grace=30;$cfg.Cancelled='';$cfg.Deferred='';$cfg.Enabled=$true;$script:lastPhase='';$script:lastAttempt=[datetime]::MinValue;$now=[datetime]'2026-10-13T03:37:00'
Invoke-GuardTick $now;$originalDeadline=$script:deadline
$dialog.FindName('Acknowledge').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));Set-CountdownView Hidden;Invoke-GuardTick ($now.AddSeconds(70))
Assert-Countdown (-not $dialog.IsVisible -and $script:deadline -eq $originalDeadline -and $dialog.FindName('MiniRemaining').Text -eq '00:50' -and $cfg.Cancelled -eq '' -and $cfg.Deferred -eq '') 'Hidden real countdown changed schedule or stopped updating'
Invoke-GuardTick ($now.AddMinutes(2));Assert-Countdown ($dialog.IsVisible -and $script:countdownView -eq 'Compact' -and $script:testShutdownRequests -eq 0) 'Final announcement should restore mini before requesting shutdown'
Invoke-GuardTick ($now.AddSeconds(122));Assert-Countdown ($script:testShutdownRequests -eq 1) 'Compact/hidden presentation blocked simulated scheduled shutdown'
$cfg.Enabled=$false;$dialog.Close();Assert-Countdown ($script:surfaces.Count -eq $baseline) 'Countdown character surfaces leaked after close'
@{acknowledgePreservesDeadline=$true;compactTimerAdvances=$true;hiddenTimerAdvances=$true;trayRestore=$true;expandRestoresEmergencyControls=$true;hiddenDemoNeverShutsDown=$true;finalAnnouncementRestoresMini=$true;simulatedRequests=$script:testShutdownRequests;nativeShutdownCalled=$false;surfacesCleaned=$true}|ConvertTo-Json|Set-Content (Join-Path $root 'output\countdown-view-report.json') -Encoding UTF8
Write-Output 'Countdown passed: acknowledge, animated compact timer, hide, tray restore, expand, unchanged deadlines, hidden demo, final announcement, simulated request and surface cleanup. No native shutdown.'
