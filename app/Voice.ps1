$script:voicePlayer=[Windows.Media.MediaPlayer]::new()
$script:voicePlayer.Volume=0.75
$script:lastVoiceAsset=$null
$script:voiceUntil=[datetime]::MinValue
# 声音：性格录音包（见 Persona.ps1）或 Windows 系统朗读。找不到录音时由系统朗读兜底。
function Stop-Voice {
 $script:synth.SpeakAsyncCancelAll();$script:voicePlayer.Stop();$script:voiceUntil=[datetime]::MinValue
 $script:voiceQueue.Clear();$script:voiceGapTimer.Stop()
}
function Say {
 param([string]$message,[string]$LineId='',[string]$ActionId='',[string]$PreparedAsset='',[double]$PreparedDuration=0,[string[]]$PreparedClips=@())
 if($ActionId){Start-Interaction $ActionId $message -Popup:((-not $win.IsVisible -or $win.WindowState -eq [Windows.WindowState]::Minimized) -and -not $script:dialog)}else{Invoke-ReminderInteraction $message $LineId}
 Stop-Voice
 if(-not $script:cfg.Voice){return}
 # 一句话可以由多个片段组成（称呼 + 正文，或称呼 + 整点 + 提醒），依次播放，中间停顿一小会儿。
 # 注意：if 语句会把单元素数组展开成字符串，所以外面再包一层 @()。
 $clips=@(if($PreparedClips.Count){$PreparedClips}elseif($PreparedAsset){$PreparedAsset})
 $script:lastVoiceClips=$clips;$script:lastVoiceAsset=if($clips.Count){$clips[0]}else{$null};$script:lastVoiceMessage=$message
 if($clips.Count){
  for($i=1;$i -lt $clips.Count;$i++){$script:voiceQueue.Enqueue($clips[$i])}
  $script:voicePlayer.Open([uri]$clips[0]);$script:voicePlayer.Play()
  $duration=10
  if($PreparedDuration -gt 0){$duration=$PreparedDuration}
  $script:voiceUntil=(Get-Date).AddSeconds($duration)
  if($script:popup){$script:popupUntil=$script:animationClock.ElapsedMilliseconds+[math]::Max(5500,($duration*1000)+1200)}
 }else{$script:synth.SpeakAsync($message)|Out-Null}
}
$script:voiceQueue=[Collections.Generic.Queue[string]]::new()
$script:voiceGapTimer=[Windows.Threading.DispatcherTimer]::new();$script:voiceGapTimer.Interval=[timespan]::FromMilliseconds(100)
$script:voiceGapTimer.Add_Tick({$script:voiceGapTimer.Stop();if($script:voiceQueue.Count){$script:voicePlayer.Open([uri]$script:voiceQueue.Dequeue());$script:voicePlayer.Play()}})
$script:voicePlayer.Add_MediaEnded({if($script:voiceQueue.Count){$script:voiceGapTimer.Start()}else{$script:voiceUntil=[datetime]::MinValue}})
$script:voicePlayer.Add_MediaFailed({$script:voiceQueue.Clear();$script:voiceUntil=[datetime]::MinValue;$ui.Feedback.Text='音频播放失败，已改用系统声音';if($cfg.Voice -and $script:lastVoiceMessage){$script:synth.SpeakAsync($script:lastVoiceMessage)|Out-Null}})
$ui.VoiceToggle.Add_Unchecked({$cfg.Voice=$false;Stop-Voice})
$ui.VoiceToggle.Add_Checked({$cfg.Voice=$true})
$win.Add_Closed({$script:voicePlayer.Close()})
