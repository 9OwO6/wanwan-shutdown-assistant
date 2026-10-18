$script:voicePlayer=[Windows.Media.MediaPlayer]::new()
$script:voicePlayer.Volume=0.75
$script:lastVoiceAsset=$null
$script:voiceUntil=[datetime]::MinValue
$script:voiceLines=Get-Content (Join-Path $root 'assets\voice-lines.json') -Raw -Encoding UTF8|ConvertFrom-Json
$script:n1ManifestPath=Join-Path $root 'assets\voices\N1\manifest.json'
$script:n1Records=if(Test-Path $script:n1ManifestPath){Get-Content $script:n1ManifestPath -Raw -Encoding UTF8|ConvertFrom-Json}else{@()}
if(-not $cfg.ContainsKey('VoicePreset')){$cfg.VoicePreset='System'}
function Get-VoiceAsset {
 param([string]$Message,[string]$Preset,[string]$LineId='')
 if($Preset -eq 'N1'){
  $line=$script:dialogue.lines|Where-Object {($_.id -eq $LineId -or (-not $LineId -and $_.text -eq $Message)) -and $_.text -eq $Message}|Select-Object -First 1
  if($line){$path=Join-Path $root $line.file;if(Test-Path $path){return $path}}
  return $null
 }
 if($Preset -notin @('A','B','C','D')){return $null}
 if(-not $LineId){$line=$script:voiceLines|Where-Object {$_.text -eq $Message}|Select-Object -First 1;$LineId=$line.id}
 if(-not $LineId -or $LineId -notin @($script:voiceLines.id)){return $null}
 $file=Join-Path $root "assets\voices\$Preset\$LineId.mp3"
 if(Test-Path $file){return $file}
 return $null
}
function Test-VoicePresetReady([string]$Preset){
 if($Preset -eq 'System'){return $true}
 if($Preset -eq 'N1'){
  if($script:dialogue.lines.Count -lt 90){return $false}
  foreach($line in $script:dialogue.lines){
   if(-not (Get-VoiceAsset -Message $line.text -Preset N1 -LineId $line.id)){return $false}
   if(-not ($script:n1Records|Where-Object {$_.id -eq $line.id -and $_.text -eq $line.text})){return $false}
  }
  return $true
 }
 if($Preset -notin @('A','B','C','D')){return $false}
 foreach($line in $script:voiceLines){if(-not (Get-VoiceAsset -Message $line.text -Preset $Preset)){return $false}}
 return $true
}
function Stop-Voice {
 $script:synth.SpeakAsyncCancelAll();$script:voicePlayer.Stop();$script:voiceUntil=[datetime]::MinValue
 if($script:auditionPlayer){$script:auditionPlayer.Stop()}
}
function Say {
 param([string]$message,[string]$LineId='',[string]$ActionId='',[string]$PreparedAsset='',[double]$PreparedDuration=0)
 if($ActionId){Start-Interaction $ActionId $message -Popup:((-not $win.IsVisible -or $win.WindowState -eq [Windows.WindowState]::Minimized) -and -not $script:dialog)}else{Invoke-ReminderInteraction $message $LineId}
 Stop-Voice
 if(-not $script:cfg.Voice){return}
 $asset=if($PreparedAsset){$PreparedAsset}else{Get-VoiceAsset -Message $message -Preset $cfg.VoicePreset -LineId $LineId}
 $script:lastVoiceAsset=$asset
 if($asset){
  $script:voicePlayer.Open([uri]$asset);$script:voicePlayer.Play()
  $duration=10
  $manifestPath=Join-Path $root 'assets\voices\manifest.json'
  if($PreparedAsset -and $PreparedDuration -gt 0){$duration=$PreparedDuration}
  elseif($cfg.VoicePreset -eq 'N1'){$record=$script:n1Records|Where-Object {$_.id -eq $LineId}|Select-Object -First 1;if($record){$duration=$record.duration}}
  elseif(Test-Path $manifestPath){$record=Get-Content $manifestPath -Raw -Encoding UTF8|ConvertFrom-Json|Where-Object {($_.preset -eq $cfg.VoicePreset) -and ((Split-Path $asset -Leaf) -eq ($_.id+'.mp3'))}|Select-Object -First 1;if($record){$duration=$record.duration}}
  $script:voiceUntil=(Get-Date).AddSeconds($duration)
  if($script:popup){$script:popupUntil=$script:animationClock.ElapsedMilliseconds+[math]::Max(5500,($duration*1000)+1200)}
 }else{$script:synth.SpeakAsync($message)|Out-Null}
}
function Set-VoicePreset {
 param([string]$Preset,[switch]$NoSave)
 if(-not (Test-VoicePresetReady $Preset)){throw '所选语音包尚未完整生成'}
 $cfg.VoicePreset=$Preset
 if(-not $NoSave){Save-Config}
 $label=if($Preset -eq 'System'){'系统女声'}elseif($Preset -eq 'N1'){'N1 · 清甜温柔'}else{"AI 音色 $Preset"}
 $ui.Feedback.Text="晚晚的声音：$label"
}
$script:voicePlayer.Add_MediaEnded({$script:voiceUntil=[datetime]::MinValue})
$script:voicePlayer.Add_MediaFailed({$script:voiceUntil=[datetime]::MinValue;$ui.Feedback.Text='音频播放失败，请重新试听'})
$ui.VoiceToggle.Add_Unchecked({$cfg.Voice=$false;Stop-Voice})
$ui.VoiceToggle.Add_Checked({$cfg.Voice=$true})
$win.Add_Closed({$script:voicePlayer.Close()})
