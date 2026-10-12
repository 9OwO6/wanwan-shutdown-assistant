if(-not (Test-VoicePresetReady N1)){throw 'N1 bank is incomplete'}
if((Format-CompanionAddress '宝贝，宝宝，亲爱的，我的小可爱。' '宝宝$1') -ne '宝宝$1，宝宝$1，宝宝$1，宝宝$1。'){throw 'Custom address replacement must be literal and non-recursive'}
if((Format-CompanionAddress '宝宝，晚安。' '你') -ne '宝宝，晚安。'){throw 'Default system address should preserve the recorded dialogue'}
$cfg.VoicePreset='N1';$cfg.Voice=$false
$cues=@($script:dialogue.lines.cue|Select-Object -Unique)
foreach($cue in $cues){
 $seen=[Collections.Generic.HashSet[string]]::new();$last=''
 for($i=0;$i -lt 12;$i++){
  $line=Get-CompanionLine $cue
  if($line.id -eq $last){throw "Adjacent duplicate in $cue"};$last=$line.id;$seen.Add($line.id)|Out-Null
  if(-not (Get-VoiceAsset -Message $line.text -Preset N1 -LineId $line.id)){throw "Missing route $($line.id)"}
 }
 if($seen.Count -ne 4){throw "Variation coverage failed: $cue"}
}
if(Get-VoiceAsset -Message 'unrelated text' -Preset N1 -LineId preview-01){throw 'N1 must not play a mismatched transcript'}
$picker=New-VoicePicker -NoSave;$picker.Show();$picker.FindName('ChooseN1').IsChecked=$true
if(-not $picker.FindName('UseVoice').IsEnabled){throw 'N1 cannot be selected'}
$picker.FindName('UseVoice').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
if($cfg.VoicePreset -ne 'N1'){throw 'N1 picker commit failed'}
$cfg.Voice=$false
$ui.Preview.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
if($ui.Message.Text -ne $script:lastSpokenLine.text -or $script:lastSpokenLine.cue -ne 'preview'){throw 'Preview caption mismatch'}
$gallery=New-InteractionGallery
foreach($button in $gallery.FindName('Scenes').Children){
 $button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
 if($script:action.Item.id -ne $button.Tag -or $gallery.FindName('SceneCaption').Text -ne $script:lastSpokenLine.text){throw 'Gallery voice/action/caption mismatch'}
}
$gallery.Close()
# Open every file with the actual WPF media backend, at zero volume.
$script:voicePlayer.Volume=0;$cfg.Voice=$true;$opened=@()
foreach($line in $script:dialogue.lines){
 $script:clipReady=$false;$audioFrame=[Windows.Threading.DispatcherFrame]::new()
 $handler=[System.EventHandler]{$script:clipReady=$true;$audioFrame.Continue=$false}
 $script:voicePlayer.Add_MediaOpened($handler)
 Say $line.text -LineId $line.id -ActionId $line.action
 $timeout=[Windows.Threading.DispatcherTimer]::new();$timeout.Interval=[timespan]::FromSeconds(3)
 $timeout.Add_Tick({$audioFrame.Continue=$false;$timeout.Stop()});$timeout.Start();[Windows.Threading.Dispatcher]::PushFrame($audioFrame);$timeout.Stop()
 $script:voicePlayer.Remove_MediaOpened($handler)
 if(-not $script:clipReady -or $script:lastVoiceAsset -ne (Join-Path $root $line.file)){throw "Native playback failed: $($line.id)"}
 $opened+=@{id=$line.id;asset=$script:lastVoiceAsset;nativeOpened=$true};Stop-Voice
}
$heartLine=$script:dialogue.lines|Where-Object {$_.id -eq 'heart-02'}|Select-Object -First 1
Say $heartLine.text -LineId $heartLine.id -ActionId heart
$holdFrame=[Windows.Threading.DispatcherFrame]::new();$holdTimer=[Windows.Threading.DispatcherTimer]::new();$holdTimer.Interval=[timespan]::FromSeconds(4.6)
$holdTimer.Add_Tick({$holdFrame.Continue=$false;$holdTimer.Stop()});$holdTimer.Start();[Windows.Threading.Dispatcher]::PushFrame($holdFrame)
if($script:mainSurface.Key -notlike 'heart:*'){throw 'Character pose ended before the long voice line'}
Stop-Voice;$cfg.Voice=$false
$opened|ConvertTo-Json -Depth 4|Set-Content (Join-Path $root 'output\voice-lab\n1-runtime-report.json') -Encoding UTF8
Write-Output "Dialogue tests passed: $($opened.Count) native WAV opens, $($cues.Count) varied cues, no adjacent repeats, N1 picker, preview and ten gallery captions/actions; muted, no shutdown"
