# Capture real WPF surfaces using an isolated, muted portfolio scenario.
$showcaseDirectory=Join-Path $root 'docs\screenshots';$frameDirectory=Join-Path $root 'output\showcase-frames'
New-Item -ItemType Directory -Force $showcaseDirectory,$frameDirectory|Out-Null
function Wait-Showcase([int]$Milliseconds){$loop=[Windows.Threading.DispatcherFrame]::new();$wait=[Windows.Threading.DispatcherTimer]::new();$wait.Interval=[timespan]::FromMilliseconds($Milliseconds);$wait.Add_Tick({$loop.Continue=$false;$wait.Stop()});$wait.Start();[Windows.Threading.Dispatcher]::PushFrame($loop);$wait.Stop()}
function Capture-Showcase($Window,[string]$Path){
 $Window.UpdateLayout();$bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$Window.ActualWidth,[int]$Window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($Window)
 $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create($Path);$encoder.Save($stream);$stream.Dispose()
}
$ui.StartupToggle.IsChecked=$false;$script:voicePlayer.Volume=0;$script:synth.Volume=0;$cfg.Voice=$true;$ui.VoiceToggle.IsChecked=$true;$cfg.Enabled=$false;$cfg.DesktopPet=$true;$ui.PetToggle.IsChecked=$true
Invoke-GuardTick ([datetime]'2026-10-12T23:00:00')
# 展示用的早睡打卡样例：最近 5 晚按时，之前有一晚熬夜。
$script:nights=@{};$index=0;foreach($pastNight in (Get-PastNights (Get-Date) $cfg 7)){$script:nights[$pastNight.Key]=@('slept','slept','early','slept','slept','late','early')[$index];$index++};Update-StreakDisplay
Start-Interaction peek;Wait-Showcase 300
Capture-Showcase $win (Join-Path $showcaseDirectory 'main-window.png')
Show-DesktopPet -Compact;Wait-Showcase 150;Capture-Showcase $popup (Join-Path $showcaseDirectory 'desktop-pet.png')
Say-ClockReminder -Now ([datetime]'2026-10-12T23:00:00') -Cue early -Demo;Wait-Showcase 300
Capture-Showcase $popup (Join-Path $showcaseDirectory 'reminder-bubble.png')
Start-Interaction wave '宝贝，晚晚在这里呀。' -Popup
$capturedPoses=[Collections.Generic.HashSet[int]]::new()
for($index=0;$index -lt 32;$index++){Wait-Showcase 100;$capturedPoses.Add($script:frameIndex)|Out-Null;Capture-Showcase $popup (Join-Path $frameDirectory ('frame-{0:00}.png' -f $index))}
if($capturedPoses.Count -lt 4){throw 'Showcase animation did not advance through four poses'}
$popup.Close();Show-BedDialog $true;Wait-Showcase 300
Capture-Showcase $dialog (Join-Path $showcaseDirectory 'bedtime-countdown.png');$dialog.Close()
$gallery=New-InteractionGallery;$gallery.Show();Wait-Showcase 200
Capture-Showcase $gallery (Join-Path $showcaseDirectory 'interaction-gallery.png');$gallery.Close()
$picker=New-VoicePicker -NoSave;$picker.Show();Wait-Showcase 200
Capture-Showcase $picker (Join-Path $showcaseDirectory 'voice-picker.png');$picker.Close()
$cfg.DesktopPet=$false;if($popup){$popup.Close()}
Write-Output 'Six real WPF showcase surfaces and 32 animation frames captured; synthetic settings, muted voice, no native shutdown.'
