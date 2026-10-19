$script:voicePlayer=[Windows.Media.MediaPlayer]::new()
$script:voicePlayer.Volume=0.75
$script:lastVoiceAsset=$null
$script:voiceUntil=[datetime]::MinValue
$script:n1ManifestPath=Join-Path $root 'assets\voices\N1\manifest.json'
$script:n1Records=if(Test-Path $script:n1ManifestPath){@((Get-Content $script:n1ManifestPath -Raw -Encoding UTF8|ConvertFrom-Json)|ForEach-Object {$_})}else{@()}
# 只有两种声音：晚晚的录音（N1）和 Windows 系统朗读。N1 找不到对应录音时返回 $null，由系统朗读兜底。
function Repair-VoicePreset {if($cfg.VoicePreset -notin @('N1','System')){$cfg.VoicePreset='N1'}}
Repair-VoicePreset
function Get-VoiceAsset {
 param([string]$Message,[string]$Preset,[string]$LineId='')
 if($Preset -ne 'N1'){return $null}
 $line=$script:dialogue.lines|Where-Object {($_.id -eq $LineId -or (-not $LineId -and $_.text -eq $Message)) -and $_.text -eq $Message}|Select-Object -First 1
 if($line){$path=Join-Path $root $line.file;if(Test-Path $path){return $path}}
 return $null
}
function Test-VoicePresetReady([string]$Preset){
 if($Preset -eq 'System'){return $true}
 if($Preset -ne 'N1'){return $false}
 if($script:dialogue.lines.Count -lt 90){return $false}
 foreach($line in $script:dialogue.lines){
  if(-not (Get-VoiceAsset -Message $line.text -Preset N1 -LineId $line.id)){return $false}
  if(-not ($script:n1Records|Where-Object {$_.id -eq $line.id -and $_.text -eq $line.text})){return $false}
 }
 return $true
}
function Stop-Voice {
 $script:synth.SpeakAsyncCancelAll();$script:voicePlayer.Stop();$script:voiceUntil=[datetime]::MinValue
}
function Say {
 param([string]$message,[string]$LineId='',[string]$ActionId='',[string]$PreparedAsset='',[double]$PreparedDuration=0)
 if($ActionId){Start-Interaction $ActionId $message -Popup:((-not $win.IsVisible -or $win.WindowState -eq [Windows.WindowState]::Minimized) -and -not $script:dialog)}else{Invoke-ReminderInteraction $message $LineId}
 Stop-Voice
 if(-not $script:cfg.Voice){return}
 $asset=if($PreparedAsset){$PreparedAsset}else{Get-VoiceAsset -Message $message -Preset $cfg.VoicePreset -LineId $LineId}
 $script:lastVoiceAsset=$asset;$script:lastVoiceMessage=$message
 if($asset){
  $script:voicePlayer.Open([uri]$asset);$script:voicePlayer.Play()
  $duration=10
  if($PreparedAsset -and $PreparedDuration -gt 0){$duration=$PreparedDuration}
  else{$record=$script:n1Records|Where-Object {$_.id -eq $LineId}|Select-Object -First 1;if($record){$duration=$record.duration}}
  $script:voiceUntil=(Get-Date).AddSeconds($duration)
  if($script:popup){$script:popupUntil=$script:animationClock.ElapsedMilliseconds+[math]::Max(5500,($duration*1000)+1200)}
 }else{$script:synth.SpeakAsync($message)|Out-Null}
}
$script:voicePlayer.Add_MediaEnded({$script:voiceUntil=[datetime]::MinValue})
$script:voicePlayer.Add_MediaFailed({$script:voiceUntil=[datetime]::MinValue;$ui.Feedback.Text='音频播放失败，已改用系统声音';if($cfg.Voice -and $script:lastVoiceMessage){$script:synth.SpeakAsync($script:lastVoiceMessage)|Out-Null}})
$ui.VoiceToggle.Add_Unchecked({$cfg.Voice=$false;Stop-Voice})
$ui.VoiceToggle.Add_Checked({$cfg.Voice=$true})
$win.Add_Closed({$script:voicePlayer.Close()})
