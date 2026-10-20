# 两种性格的台词：轮换不重复、主窗口字幕、互动小剧场只做动作，以及录音包里每一句都能原生播放（静音）。
$cfg.Voice=$false;$cfg.VoicePreset='Recorded'
$report=@()
foreach($personaId in @('girlfriend','sister')){
 $cfg.Persona=$personaId;$cfg.Address=$script:personas[$personaId].default_address;$cfg.Enabled=$true
 $cues=@($script:personaLines|Where-Object {$_.persona -eq $personaId -and $_.cue -ne 'hour'}|ForEach-Object cue|Select-Object -Unique)
 foreach($cue in $cues){
  $count=@($script:personaLines|Where-Object {$_.persona -eq $personaId -and $_.cue -eq $cue}).Count
  $seen=[Collections.Generic.HashSet[string]]::new();$last=''
  for($i=0;$i -lt 2*$count;$i++){
   $line=Get-CompanionLine $cue
   if($count -gt 1 -and $line.id -eq $last){throw "Adjacent duplicate in $personaId/$cue"};$last=$line.id;$seen.Add($line.id)|Out-Null
   if((Resolve-Speech $line).Text.Contains('{')){throw "Unformatted address in $($line.id)"}
  }
  if($seen.Count -ne $count){throw "Variation coverage failed: $personaId/$cue"}
 }
 # 不能再出现被用户删掉的说法。
 foreach($line in @($script:personaLines|Where-Object persona -eq $personaId)){if($line.text -match '我陪你|慢慢收尾|我在陪你'){throw "Retired phrase in $($line.id)"}}
 $report+="$personaId $($cues.Count) cues"
}
$cfg.Persona='girlfriend';$cfg.Address='baobao'
$ui.Preview.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
if($ui.Message.Text -ne $script:lastSpokenLine.text -or $script:lastSpokenLine.cue -ne 'preview' -or $ui.Message.Text -notlike '宝宝*'){throw 'Preview caption mismatch'}
# 互动小剧场：每个按钮做对应动作，字幕是动作名，不说整句。
$gallery=New-InteractionGallery
foreach($button in $gallery.FindName('Scenes').Children){
 $button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
 if($script:action.Item.id -ne $button.Tag -or $gallery.FindName('SceneCaption').Text -ne $script:lastSpokenLine.text -or $script:lastSpokenLine.text.Length -gt 12){throw "Gallery gesture mismatch: $($button.Tag)"}
}
$gallery.Close()
# 录音包里的每一句都能被 WPF 原生打开（静音），并且等动作播完前不会提前收起。
$script:voicePlayer.Volume=0;$cfg.Voice=$true;$opened=0
foreach($personaId in @('girlfriend','sister')|Where-Object {Test-PersonaBank $_}){
 foreach($clip in $script:personaBanks[$personaId].Values){
  $script:clipReady=$false;$audioFrame=[Windows.Threading.DispatcherFrame]::new()
  $handler=[System.EventHandler]{$script:clipReady=$true;$audioFrame.Continue=$false}
  $script:voicePlayer.Add_MediaOpened($handler)
  Say $clip.text -PreparedClips @($clip.file) -PreparedDuration $clip.duration
  $timeout=[Windows.Threading.DispatcherTimer]::new();$timeout.Interval=[timespan]::FromSeconds(3)
  $timeout.Add_Tick({$audioFrame.Continue=$false;$timeout.Stop()});$timeout.Start();[Windows.Threading.Dispatcher]::PushFrame($audioFrame);$timeout.Stop()
  $script:voicePlayer.Remove_MediaOpened($handler)
  if(-not $script:clipReady -or $script:lastVoiceAsset -ne $clip.file){throw "Native playback failed: $($clip.file)"}
  $opened++;Stop-Voice
 }
}
Stop-Voice;$cfg.Voice=$false
New-Item -ItemType Directory -Force (Join-Path $root 'output\voice-lab')|Out-Null
@{personas=$report;nativeOpens=$opened}|ConvertTo-Json|Set-Content (Join-Path $root 'output\voice-lab\persona-runtime-report.json') -Encoding UTF8
Write-Output "Dialogue tests passed: $($report -join ', '), no adjacent repeats, no retired phrases, preview caption, ten gallery gestures, $opened native clip opens; muted, no shutdown"
