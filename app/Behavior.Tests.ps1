# 桌宠行为（真实 WPF）：随机小动作、越来越困、晚晚陪伴的跟做 / 趴睡 / 回来打招呼、到点时的陪伴台词。静音，不关机。
function Assert-Pet([bool]$Pass,[string]$Message){if(-not $Pass){throw $Message}}
function Wait-Behavior([int]$Milliseconds){$loop=[Windows.Threading.DispatcherFrame]::new();$wait=[Windows.Threading.DispatcherTimer]::new();$wait.Interval=[timespan]::FromMilliseconds($Milliseconds);$wait.Add_Tick({$loop.Continue=$false;$wait.Stop()});$wait.Start();[Windows.Threading.Dispatcher]::PushFrame($loop);$wait.Stop()}
$cfg.Voice=$false;$cfg.Enabled=$false;$cfg.Bedtime='23:30';$cfg.WeekendBedtime='';$cfg.DesktopPet=$true;$cfg.Companion=$false;$cfg.Persona='girlfriend';$cfg.Address='baobao'
$behaviorDirectory=Join-Path $root 'output\behavior';New-Item -ItemType Directory -Force $behaviorDirectory|Out-Null
Show-DesktopPet -Compact;Wait-Behavior 200
Assert-Pet ($script:petAvatarSurface -and $script:petAvatarSurface.Image.Source) 'Compact pet must show the animated character, not a static icon'

# 1. 自己的小动作：到时间才做，不改主窗口文字，不说话
$message=$ui.Message.Text;$script:petBehavior.NextAt=[datetime]'2026-10-12T21:00:00';$script:petBehavior.Last=''
Update-PetBehavior ([datetime]'2026-10-12T20:59:00');Assert-Pet ($script:petBehavior.Last -eq '') 'No action before the next scheduled time'
Update-PetBehavior ([datetime]'2026-10-12T21:00:00')
Assert-Pet ($script:petBehavior.Last -in @('write','drink','stretch','peek') -and $ui.Message.Text -eq $message -and -not $script:petExpanded) "Quiet idle action expected, got $($script:petBehavior.Last)"
Assert-Pet ($script:petBehavior.NextAt -ge [datetime]'2026-10-12T21:02:00') 'Next action two or more minutes later'
Wait-Behavior 400;Assert-Pet ($script:petAvatarSurface.Key -like ($script:petBehavior.LastAnimation+':*')) 'Compact pet plays the chosen animation'

# 2. 过了睡觉时间：大多在打哈欠
$yawns=0;for($i=0;$i -lt 30;$i++){$script:petBehavior.NextAt=[datetime]::MinValue;Update-PetBehavior ([datetime]'2026-10-13T00:20:00');if($script:petBehavior.Last -eq 'yawn'){$yawns++}}
Assert-Pet ($yawns -ge 10) "Past bedtime she should yawn often ($yawns/30)"

# 3. 晚晚陪伴关闭时：不看你在做什么，你离开也不会趴下
$script:activityOverride=@{Process='vlc';Fullscreen=$false};$script:idleOverride=1200
$script:petBehavior.NextAt=[datetime]::MinValue;Update-PetBehavior ([datetime]'2026-10-12T21:00:00')
Assert-Pet (-not $script:petBehavior.Away -and $script:petBehavior.Activity -eq 'none' -and $script:petBehavior.Last -ne 'watch') 'Companion off must ignore activity and idle time'

# 4. 打开晚晚陪伴：看视频一起看；离开就趴睡；回来打招呼（半小时一次）
$cfg.Companion=$true;$script:idleOverride=5;$watch=0
for($i=0;$i -lt 20;$i++){$script:petBehavior.NextAt=[datetime]::MinValue;$script:petBehavior.Last='';Update-PetBehavior ([datetime]'2026-10-12T21:00:00');if($script:petBehavior.Last -eq 'watch'){$watch++}}
Assert-Pet ($script:petBehavior.Activity -eq 'video' -and $watch -ge 8) "Companion mode should watch along ($watch/20)"
$script:idleOverride=900;Update-PetBehavior ([datetime]'2026-10-12T21:10:00')
Assert-Pet ($script:petBehavior.Away -and $script:restPose -and $script:petBehavior.Last -eq 'sleep') 'Away for 15 minutes: she naps'
Wait-Behavior 3500;Assert-Pet ($script:petAvatarSurface.Key -like ($script:restPose.Id+':2')) 'Nap pose must hold after the animation'
$pet=$script:popup;$pet.UpdateLayout();$bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$pet.ActualWidth,[int]$pet.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($pet);$enc=[Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp));$file=[IO.File]::Create((Join-Path $behaviorDirectory 'pet-napping.png'));$enc.Save($file);$file.Dispose()
$script:idleOverride=2;Update-PetBehavior ([datetime]'2026-10-12T21:30:00')
Assert-Pet (-not $script:petBehavior.Away -and -not $script:restPose -and $script:lastSpokenLine.cue -eq 'back') 'Coming back wakes her with a greeting'
if($script:popup -and $script:petExpanded){Complete-DesktopPetReminder};Wait-Behavior 100
$script:idleOverride=900;Update-PetBehavior ([datetime]'2026-10-12T21:40:00');$script:idleOverride=2;$spoken=$script:lastSpokenLine;Update-PetBehavior ([datetime]'2026-10-12T21:45:00')
Assert-Pet ([object]::ReferenceEquals($spoken,$script:lastSpokenLine)) 'Greeting at most once per half hour'

# 5. 到点时还在打游戏：说陪伴那句，而不是普通的到点提醒
$script:activityOverride=@{Process='SomeNewGame';Fullscreen=$true}
Assert-Pet ((Get-CompanionBedtimeCue) -eq 'companion-game') 'Fullscreen unknown program counts as a game at bedtime'
Say-ClockReminder -Now ([datetime]'2026-10-12T23:30:00') -Cue bed
Assert-Pet ($script:lastSpokenLine.cue -eq 'companion-game' -and $popup.FindName('PopupText').Text -eq '打完这把就睡，好不好？') "Bedtime companion line expected, got $($script:lastSpokenLine.cue)"
$cfg.Companion=$false;Say-ClockReminder -Now ([datetime]'2026-10-12T23:30:00') -Cue bed
Assert-Pet ($script:lastSpokenLine.cue -eq 'bed') 'Companion off keeps the normal bedtime line'

# 6. 提醒或倒计时进行中不插入小动作
$cfg.Companion=$true;$script:idleOverride=5;Show-BedDialog $true;$before=$script:petBehavior.Last;$script:petBehavior.NextAt=[datetime]::MinValue
Update-PetBehavior ([datetime]'2026-10-12T21:00:00');Assert-Pet ($script:petBehavior.Last -eq $before) 'No idle actions during a countdown'
$dialog.Close()
$script:activityOverride=$null;$script:idleOverride=$null;$script:restPose=$null;$cfg.Companion=$false;$cfg.DesktopPet=$false;if($popup){$popup.Close()}
Write-Output 'Behavior tests passed: animated compact pet, quiet scheduled idle actions, sleepier after bedtime, companion off ignores activity, watch-along, nap when away with held pose, one greeting per half hour, bedtime companion line, no actions during countdown. Muted, no shutdown.'
