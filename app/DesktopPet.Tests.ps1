# 验证真实窗口、托盘图标、Dispatcher 提醒和原生音频；保持真实配置文件不变。
$petOutput=Join-Path $root 'output\desktop-pet';New-Item -ItemType Directory -Force $petOutput|Out-Null
function Wait-Pet([int]$Milliseconds){
 $loop=[Windows.Threading.DispatcherFrame]::new();$wait=[Windows.Threading.DispatcherTimer]::new();$wait.Interval=[timespan]::FromMilliseconds($Milliseconds)
 $wait.Add_Tick({$loop.Continue=$false;$wait.Stop()});$wait.Start();[Windows.Threading.Dispatcher]::PushFrame($loop);$wait.Stop()
}
function Capture-Pet($Window,[string]$Name){
 $Window.UpdateLayout();$bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$Window.ActualWidth,[int]$Window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($Window)
 $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$file=[IO.File]::Create((Join-Path $petOutput $Name));$encoder.Save($file);$file.Dispose()
}
function Assert-PetBounds($Window){
 $area=Get-DesktopWorkArea
 if($Window.Left -lt $area.Left-1 -or $Window.Top -lt $area.Top-1 -or $Window.Left+$Window.Width -gt $area.Right+1 -or $Window.Top+$Window.Height -gt $area.Bottom+1){throw 'Pet overlaps taskbar or leaves the work area'}
}
if(@($script:personaLines|Where-Object cue -eq 'hour').Count -ne 48){throw 'Both personas need 24 hourly lines'}
if($script:appIdentityResult -ne 0 -or -not $win.Icon -or $tray.Icon.Handle -eq [IntPtr]::Zero){throw 'Branded window and tray resources missing'}
$handle=[Windows.Interop.WindowInteropHelper]::new($win).Handle
if([Wanwan.Desktop]::SendMessage($handle,0x7f,[IntPtr]::Zero,[IntPtr]::Zero) -eq [IntPtr]::Zero){throw 'Native title-bar icon was not set'}
$negative=Get-PetPlacement ([Windows.Rect]::new(-1920,-200,1920,1040)) 390 420
if($negative.Left -ne -408 -or $negative.Top -ne 402){throw 'Negative monitor coordinates are incorrect'}
$cfg.VoicePreset='Recorded';$cfg.Persona='girlfriend';$cfg.Address='baobao';$cfg.Voice=$false;$cfg.DesktopPet=$true
$win.Activate()|Out-Null;Wait-Pet 100;$foreground=[Wanwan.Desktop]::GetForegroundWindow()
Show-DesktopPet -Compact;Wait-Pet 150
if(-not $popup.IsVisible -or $popup.ShowActivated -or $script:petExpanded -or $popup.Width -ne 142){throw 'Compact companion did not appear without activation'}
if([Wanwan.Desktop]::GetForegroundWindow() -ne $foreground){throw 'Compact companion stole keyboard focus'}
Assert-PetBounds $popup;Capture-Pet $popup 'compact.png'
$compactTouch=[Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice,0,[Windows.Input.MouseButton]::Left);$compactTouch.RoutedEvent=[Windows.UIElement]::MouseLeftButtonUpEvent
$win.Hide();$popup.FindName('CompactOpen').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));Wait-Pet 100
if(-not $win.IsVisible -or $script:petExpanded){throw 'Compact avatar touch did not restore the main window'}
$ui.PetPreview.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));Wait-Pet 100
$win.Hide();$popup.FindName('PetOpen').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));Wait-Pet 100
if(-not $win.IsVisible){throw 'Open Wanwan button did not restore the main window'}
$foreground=[Wanwan.Desktop]::GetForegroundWindow()
$ui.PetPreview.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));Wait-Pet 300
if(-not $script:petExpanded -or $popup.FindName('PetStatus').Text -notlike '提醒体验 · *' -or $popup.FindName('PopupText').Text -ne $script:lastSpokenLine.text){throw 'Pet preview text/clock state mismatch'}
if($cfg.Enabled -or $script:dialog -or $popup.FindName('PetPromise').Text -ne ('约好 '+$cfg.Bedtime+' 休息')){throw 'Preview changed guard state or started a countdown'}
if([Wanwan.Desktop]::GetForegroundWindow() -ne $foreground){throw 'Reminder stole keyboard focus'}
Assert-PetBounds $popup;Capture-Pet $popup 'reminder.png'
$touch=[Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice,0,[Windows.Input.MouseButton]::Left);$touch.RoutedEvent=[Windows.UIElement]::MouseLeftButtonDownEvent
$popup.FindName('PopupPortrait').RaiseEvent($touch)
if($script:lastSpokenLine.cue -notlike 'poke*'){throw 'Touch did not trigger the poke response'}
# Record actual advancing poses while the popup is visible.
Start-Interaction wave '你回来啦。' -Popup
$poses=[Collections.Generic.HashSet[int]]::new()
for($i=0;$i -lt 24;$i++){Wait-Pet 100;if($script:action.Item.id -eq 'wave'){$poses.Add($script:frameIndex)|Out-Null;Capture-Pet $popup ('motion-'+$script:frameIndex+'.png')}}
if($poses.Count -lt 4){throw 'Desktop pet did not advance through four real poses'}
Set-Motion $false;Start-Interaction heart '给你一颗小小的心。' -Popup;Wait-Pet 150;$held=$script:popupSurface.Key;Wait-Pet 250
if($script:popupSurface.Key -ne $held -or $script:popupSurface.Move.Y -ne 0 -or $popup.Opacity -ne 1){throw 'Reduced motion is not static'}
Set-Motion $true
$popup.FindName('PopupClose').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));Wait-Pet 60
if(-not $popup -or $script:petExpanded -or $popup.Width -ne 142){throw 'Dismiss did not return to compact companion'}
Say-ClockReminder -Now ([datetime]'2026-10-11T00:59:00') -Cue early -Demo;Wait-Pet 150
if($script:lastSpokenLine.hour -ne 0 -or $popup.FindName('PetStatus').Text -ne '提醒体验 · 00:59' -or $popup.FindName('PopupText').Text -notlike '*十二点*'){throw 'Midnight clock is inaccurate'}
$script:popupUntil=$script:animationClock.ElapsedMilliseconds-1;Wait-Pet 100
if($script:petExpanded){throw 'Finished reminder did not return to compact form'}
$ui.PetToggle.IsChecked=$true;$ui.PetToggle.IsChecked=$false
if($popup -or $cfg.DesktopPet){throw 'Disabling desktop companionship did not close the compact avatar'}
Say-ClockReminder -Now ([datetime]'2026-10-10T23:59:59') -Cue soon;Wait-Pet 150
if($script:lastSpokenLine.hour -ne 23 -or $script:lastSpokenLine.time -ne '23:59'){throw 'Hour must not round forward'}
$popup.FindName('PopupClose').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
if($popup){throw 'Transient reminder did not dismiss when residence is disabled'}
# Exercise all four real scheduler branches. Test mode additionally blocks the power API.
$scheduled=@()
foreach($scenario in @(@{phase='Early';minutes=30;cue='early'},@{phase='Soon';minutes=10;cue='soon'},@{phase='Bed';minutes=0;cue='bed'},@{phase='Final';minutes=-8;cue='final'})){
 $cfg.Bedtime=(Get-Date).AddMinutes($scenario.minutes).ToString('HH:mm');$cfg.Grace=10;$cfg.Cancelled='';$cfg.Deferred='';$script:lastPhase='';$cfg.Enabled=$true
 if((Get-NightState (Get-Date) $cfg).Phase -ne $scenario.phase){throw 'Scheduled scenario phase changed before the test'}
 $timer.Start();try{Wait-Pet 1250}finally{$timer.Stop();$cfg.Enabled=$false}
 if($script:lastSpokenLine.cue -ne $scenario.cue){throw ('Scheduled voice did not reach the correct phase: '+$scenario.phase)}
 if($scenario.phase -in @('Early','Soon')){
  if(-not $popup -or -not $script:petExpanded -or $script:dialog){throw 'Scheduled gentle reminder did not reach the pet bubble'}
  Assert-PetBounds $popup;Capture-Pet $popup ('scheduled-'+$scenario.cue+'.png')
  $popup.FindName('PopupClose').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
 }else{
  if(-not $dialog -or $dialog.ShowActivated -or $dialog.FindName('Info').Text -ne $script:lastSpokenLine.text){throw 'Scheduled bedtime reminder did not reach the pet countdown'}
  Assert-PetBounds $dialog;Capture-Pet $dialog ('scheduled-'+$scenario.cue+'.png');$dialog.Close()
 }
 $scheduled+=@{phase=$scenario.phase;cue=$script:lastSpokenLine.cue;time=$script:lastSpokenLine.time;verified=$true}
}
# Exercise a real final-phase UI without starting the shutdown timer or enabling the guard.
$cfg.Bedtime=(Get-Date).AddMinutes(-8).ToString('HH:mm');$script:dialog=$null;Show-BedDialog $false;Wait-Pet 300
if(-not $dialog -or $dialog.ShowActivated -or $script:lastSpokenLine.cue -ne 'final' -or $dialog.FindName('Info').Text -ne $script:lastSpokenLine.text){throw 'Final reminder is not a consistent non-activating pet countdown'}
Assert-PetBounds $dialog;Capture-Pet $dialog 'bedtime.png'
if($dialog.FindName('CancelNight').ActualHeight -lt 24 -or $dialog.FindName('CancelNight').TranslatePoint([Windows.Point]::new(0,0),$dialog).Y+$dialog.FindName('CancelNight').ActualHeight -gt $dialog.ActualHeight){throw 'Bedtime controls are clipped'}
$dialog.Close()
# Every prepared audio file is opened by the native WPF backend at zero volume.
$cfg.Voice=$true;$script:voicePlayer.Volume=0;$opened=@()
foreach($row in @(foreach($h in 0..23){foreach($c in 'early','soon','bed','final'){[pscustomobject]@{hour=$h;cue=$c}}})){
 $now=[datetime]'2026-10-10T00:37:00';$now=$now.AddHours([int]$row.hour);$resolved=Get-ClockReminder $now $row.cue
 if($resolved.cue -ne $row.cue -or $resolved.parts[0].hour -ne $row.hour -or $resolved.time -ne ('{0:00}:37' -f $row.hour)){throw 'Hour/phase voice route is incorrect'}
 if(-not (Test-PersonaBank)){$opened+=@{hour=$row.hour;cue=$row.cue;nativeOpened=$false};continue}
 $ready=$false;$audioLoop=[Windows.Threading.DispatcherFrame]::new();$handler=[System.EventHandler]{$script:petClipReady=$true;$audioLoop.Continue=$false};$script:petClipReady=$false
 $script:voicePlayer.Add_MediaOpened($handler)
 $spokenAt=Get-Date;Speak-Line $resolved|Out-Null;$spokenUntil=$script:voiceUntil
 $timeout=[Windows.Threading.DispatcherTimer]::new();$timeout.Interval=[timespan]::FromSeconds(3);$timeout.Add_Tick({$audioLoop.Continue=$false;$timeout.Stop()});$timeout.Start();[Windows.Threading.Dispatcher]::PushFrame($audioLoop);$timeout.Stop();$script:voicePlayer.Remove_MediaOpened($handler)
 if(-not $script:petClipReady -or $script:lastVoiceClips.Count -ne 2 -or $script:lastVoiceAsset -notlike ('*hour-{0:00}@baobao.mp3' -f $row.hour)){throw "Native hourly audio failed: $($row.hour) $($row.cue)"}
 if(($spokenUntil-$spokenAt).TotalSeconds -lt $script:lastSpokenLine.duration-0.5){throw 'Pet lifetime does not reflect actual spoken duration'}
 $opened+=@{hour=$row.hour;cue=$row.cue;nativeOpened=$true};Stop-Voice
}
$cfg.Voice=$false;$cfg.Bedtime='23:30';$cfg.DesktopPet=$false;if($popup){$popup.Close()}
$cfg.VoicePreset='System';$cfg.Address='custom';$cfg.Nickname='亲爱的朋友';Say-ClockReminder -Now ([datetime]'2026-10-10T23:37:00') -Cue early -Demo
if($popup.FindName('PopupText').Text -notlike '亲爱的朋友，*' -or $script:lastSpokenLine.text -ne $popup.FindName('PopupText').Text){throw 'System nickname did not match the visible clock caption'}
$popup.Close();$cfg.VoicePreset='Recorded';$cfg.Address='baobao';$cfg.Nickname='';$ui.TimeDisplay.Text=$cfg.Bedtime;$ui.ModeLabel.Text='守护未开启';$ui.Clock.Text=(Get-Date).ToString('HH:mm');$ui.Countdown.Text='我会提前半小时轻轻提醒你';Set-CompanionMode '陪伴';Set-Motion $false;Start-Interaction peek;Wait-Pet 150
Capture-Pet $win 'main-window.png'
if($script:surfaces.Count -ne 1){throw 'Desktop windows leaked animation surfaces'}
@{nativeOpens=$opened;titleBarIcon=$true;trayIcon=$true;appIdentity=$true;compact=$true;nonActivating=$true;rightCorner=$true;midnight=$true;fourPoses=@($poses);scheduledPhases=$scheduled;finalCountdown=$true;reducedMotion=$true;shutdownInvoked=$false;testModeBlocksPowerApi=$script:isTestMode}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $petOutput 'runtime-report.json') -Encoding UTF8
Write-Output 'Desktop pet passed: compact/expanded forms, focus preserved, taskbar-safe placement, four poses, mute, reduced motion, midnight, all four actual scheduled phases, final pet countdown and 96 hour/phase routes (native opens when the voice bank is installed); test mode blocks power API'
