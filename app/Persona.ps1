# 晚晚的两种性格（女友 / 姐姐）：台词、称呼和录音。台词来自 assets/persona-script.json（用户定稿的第二版）。
# 带 {称呼} 的句子按每个称呼各录了一遍整句，另录一遍不带称呼的；自定义名字只出现在文字里。
# 整点报时 = 整点句 + 对应提醒句，中间停顿 clock_pause_ms；其余句子都是整句播放，不拼接。
$script:personaScript=Get-Content (Join-Path $root 'assets\persona-script.json') -Raw -Encoding UTF8|ConvertFrom-Json
$script:personas=@{};foreach($p in @($script:personaScript.personas)){$script:personas[$p.id]=$p}
$script:personaLines=@($script:personaScript.lines|ForEach-Object {$_})
$script:addressMark='{称呼}'
$script:dialogueBags=@{};$script:lastDialogue=@{};$script:lastSpokenLine=$null

# ---------- 设置：性格、称呼、声音 ----------
function Repair-PersonaSettings {
 # 旧版本只有 VoicePreset（N1 / V3 / System）和称呼输入框：V3 = 姐姐，其余录音声音 = 女友。
 if(-not $cfg.ContainsKey('Persona') -or -not $script:personas.ContainsKey([string]$cfg.Persona)){$cfg.Persona=if($cfg.VoicePreset -eq 'V3'){'sister'}else{'girlfriend'}}
 if($cfg.VoicePreset -ne 'System'){$cfg.VoicePreset='Recorded'}
 $persona=$script:personas[$cfg.Persona]
 $valid=@($persona.addresses.id)+@('none','custom')
 if(-not $cfg.ContainsKey('Address') -or [string]$cfg.Address -notin $valid){
  $nick=([string]$cfg.Nickname).Trim()
  $match=@($persona.addresses|Where-Object label -eq $nick)|Select-Object -First 1
  $cfg.Address=if($match){$match.id}elseif($nick -and $nick -ne '你' -and $nick -notin @('宝宝','宝贝','亲爱的','我的小可爱','小笨蛋')){'custom'}else{$persona.default_address}
 }
 if(-not $cfg.ContainsKey('Companion')){$cfg.Companion=$false}
}
function Get-Persona {return $script:personas[[string]$cfg.Persona]}
function Get-AddressChoice {
 # 返回 @{Id=录音里用的称呼（没有就是 $null）; Label=文字里显示的称呼（没有就是空）}
 $persona=Get-Persona
 if($cfg.Address -eq 'custom'){$name=([string]$cfg.Nickname).Trim();return @{Id=$null;Label=$(if($name -and $name -ne '你'){$name}else{''})}}
 $row=@($persona.addresses|Where-Object id -eq $cfg.Address)|Select-Object -First 1
 if($row){return @{Id=$row.id;Label=$row.label}}
 return @{Id=$null;Label=''}
}
function Format-PersonaText([string]$Text,[string]$Label){
 if(-not $Text.Contains($script:addressMark)){return $Text}
 if($Label){return $Text.Replace($script:addressMark,$Label)}
 # 去掉称呼时，句首的「称呼，」连同标点一起去掉；句中「，称呼。」变成「。」；其余只去掉称呼本身。
 $out=[regex]::Replace($Text,'^'+[regex]::Escape($script:addressMark)+'[，～]','')
 $out=$out.Replace('，'+$script:addressMark+'。','。').Replace($script:addressMark,'')
 return $out
}

# ---------- 录音包 ----------
$script:personaBanks=@{}
foreach($p in $script:personas.Values){
 $bankPath=Join-Path $root ("assets\voices\{0}\bank.json" -f $p.id)
 if(-not (Test-Path $bankPath)){continue}
 $clips=@{}
 foreach($clip in @((Get-Content $bankPath -Raw -Encoding UTF8|ConvertFrom-Json).clips|ForEach-Object {$_})){
  $clips[$clip.key]=[pscustomobject]@{file=(Join-Path $root $clip.file);duration=[double]$clip.duration;text=$clip.text}
 }
 $script:personaBanks[$p.id]=$clips
}
function Test-PersonaBank([string]$Persona=$cfg.Persona){return $script:personaBanks.ContainsKey($Persona)}

# ---------- 选台词 ----------
$script:cueAliases=@{nod='ack';night='goodnight';bye='goodnight';final='final';'watch-final'='watch-final'}
function Get-CompanionLine([string]$Cue){
 # 同一场景的几种说法轮流用，一轮内不重复。
 $options=@($script:personaLines|Where-Object {$_.persona -eq $cfg.Persona -and $_.cue -eq $Cue})
 # 守护没开时，不说「帮你关机」的那种说法。
 if(-not $cfg.Enabled -and $options.Count -gt 1){$safe=@($options|Where-Object {-not $_.text.Contains('关机')});if($safe.Count){$options=$safe}}
 if(-not $options.Count){throw "Unknown dialogue cue: $Cue"}
 $bagKey=$cfg.Persona+'/'+$Cue+'/'+$options.Count
 if(-not $script:dialogueBags.ContainsKey($bagKey) -or $script:dialogueBags[$bagKey].Count -eq 0){
  $bag=[Collections.Generic.List[object]]::new()
  foreach($item in @($options|Sort-Object {Get-Random})){$bag.Add($item)}
  if($bag.Count -gt 1 -and $bag[0].id -eq $script:lastDialogue[$bagKey]){$swap=$bag[0];$bag[0]=$bag[1];$bag[1]=$swap}
  $script:dialogueBags[$bagKey]=$bag
 }
 $line=$script:dialogueBags[$bagKey][0];$script:dialogueBags[$bagKey].RemoveAt(0);$script:lastDialogue[$bagKey]=$line.id
 return $line
}
function Test-PersonaCue([string]$Cue){return [bool](@($script:personaLines|Where-Object {$_.persona -eq $cfg.Persona -and $_.cue -eq $Cue}).Count)}

# ---------- 解析成文字 + 录音片段 ----------
function Resolve-Speech($Line,[string]$Mode=$cfg.VoicePreset){
 # $Line：一句台词，或带 parts（整点句 + 提醒句）的组合。返回 @{Text;Clips;Duration}。
 $parts=if($Line.PSObject.Properties['parts'] -and $Line.parts){@($Line.parts)}else{@($Line)}
 $address=Get-AddressChoice
 $text=($parts|ForEach-Object {Format-PersonaText $_.text $address.Label}) -join ''
 if($Mode -ne 'System' -and (Test-PersonaBank)){
  $bank=$script:personaBanks[$cfg.Persona];$clips=@();$duration=0
  foreach($part in $parts){
   $key=$part.id+$(if($part.text.Contains($script:addressMark) -and $address.Id){'@'+$address.Id}else{''})
   $clip=$bank[$key]
   # 缺任何一段都不播半句，整句交给系统朗读。
   if(-not $clip -or -not (Test-Path $clip.file)){$clips=@();$duration=0;break}
   $clips+=$clip.file;$duration+=$clip.duration
  }
  if($clips.Count){return @{Text=$text;Clips=$clips;Duration=$duration+($script:personaScript.clock_pause_ms/1000)*($clips.Count-1)}}
 }
 return @{Text=$text;Clips=@();Duration=[math]::Max(2,$text.Length*0.24)}
}
function Speak-Line($Line){
 $speech=Resolve-Speech $Line
 $spoken=[pscustomobject]@{id=$Line.id;cue=$Line.cue;action=$Line.action;text=$speech.Text;file=$(if($speech.Clips.Count){$speech.Clips[0]}else{''});duration=$speech.Duration}
 foreach($extra in @('time','hour')){if($Line.PSObject.Properties[$extra]){$spoken|Add-Member -NotePropertyName $extra -NotePropertyValue $Line.$extra}}
 $script:lastSpokenLine=$spoken
 Say $speech.Text -LineId $Line.id -ActionId $Line.action -PreparedClips $speech.Clips -PreparedDuration $speech.Duration
 return $spoken
}

# ---------- 各场景的入口 ----------
function Say-Cue {
 param([string]$Cue,[switch]$Interaction,[switch]$Demo)
 if($Demo -and $Cue -eq 'dialog'){$Cue='demo'}
 if($script:cueAliases.ContainsKey($Cue)){$Cue=$script:cueAliases[$Cue]}
 # 小互动（拍拍、比心、挥手……）不再说整句：做动作，必要时配一个短音。
 if(-not (Test-PersonaCue $Cue)){Invoke-Gesture $Cue;return}
 $line=Speak-Line (Get-CompanionLine $Cue)
 if($script:dialog -and $Cue -in @('dialog','demo','final','goodnight')){$script:dialog.FindName('Info').Text=$line.text}
}
$script:gestureNames=@{peek='探头';pat='拍一拍';water='喝口水';stretch='伸懒腰';nod='点点头';heart='比心';cheer='加油';wave='挥挥手';yawn='打哈欠';goodnight='晚安'}
function Invoke-Gesture([string]$Id){
 $symbol=switch($Id){'water'{'☕'}'yawn'{'💤'}'wave'{'👋'}'heart'{'♡'}'cheer'{'✦'}'goodnight'{'☾'}default{'·'}}
 $caption=$symbol+'  '+$(if($script:gestureNames.ContainsKey($Id)){$script:gestureNames[$Id]}else{$Id})
 $sound=if($Id -eq 'yawn'){'yawn-sound'}else{''}
 if($sound -and (Test-PersonaCue $sound)){$line=Get-CompanionLine $sound;$speech=Resolve-Speech $line
  $script:lastSpokenLine=[pscustomobject]@{id=$line.id;cue=$sound;action=$Id;text=$caption;file=$(if($speech.Clips.Count){$speech.Clips[0]}else{''});duration=$speech.Duration}
  Start-Interaction $Id $caption -Popup:((-not $win.IsVisible -or $win.WindowState -eq [Windows.WindowState]::Minimized) -and -not $script:dialog)
  if($cfg.Voice -and $speech.Clips.Count){Stop-Voice;$script:lastVoiceClips=$speech.Clips;$script:lastVoiceAsset=$speech.Clips[0];$script:voicePlayer.Open([uri]$speech.Clips[0]);$script:voicePlayer.Play();$script:voiceUntil=(Get-Date).AddSeconds($speech.Duration)}
  return}
 $script:lastSpokenLine=[pscustomobject]@{id='';cue=$Id;action=$Id;text=$caption;file='';duration=0}
 Start-Interaction $Id $caption -Popup:((-not $win.IsVisible -or $win.WindowState -eq [Windows.WindowState]::Minimized) -and -not $script:dialog)
}
# 戳晚晚：连续戳会越来越不耐烦（嗯？→ 诶——干嘛呀～ → 哼！）。
$script:pokeTimes=[Collections.Generic.List[datetime]]::new()
function Invoke-Poke {
 $now=Get-Date;$script:pokeTimes.Add($now)
 while($script:pokeTimes.Count -and ($now-$script:pokeTimes[0]).TotalSeconds -gt 10){$script:pokeTimes.RemoveAt(0)}
 $cue=if($script:pokeTimes.Count -ge 5){'poke-angry'}elseif($script:pokeTimes.Count -ge 3){'poke-more'}else{'poke'}
 $line=Speak-Line (Get-CompanionLine $cue)
 return $line
}
function Get-GuardLine([string]$Cue){
 $line=Get-CompanionLine $Cue
 return [pscustomobject]@{id=$line.id;persona=$line.persona;cue=$Cue;action=$line.action;text=$line.text}
}
function Say-GuardLine([string]$Cue){$spoken=Speak-Line (Get-GuardLine $Cue);$script:lastGuardDuration=$spoken.duration;return $spoken}
function Get-WatchLine([string]$Cue){
 $mapped=if($Cue -eq 'final'){'watch-final'}else{$Cue}
 $line=Get-CompanionLine $mapped
 return [pscustomobject]@{id=$line.id;persona=$line.persona;cue=$Cue;action=$line.action;text=$line.text}
}
function Say-WatchLine([string]$Cue){$spoken=Speak-Line (Get-WatchLine $Cue);$script:lastGuardDuration=$spoken.duration;return $spoken}
function Get-ClockReminder([datetime]$Now,[string]$Cue){
 # 整点报时：「宝宝，到十一点啦。」+ 这个阶段的提醒句。超时（due）只说守护句。
 if($Cue -eq 'due'){$line=Get-GuardLine due;return [pscustomobject]@{id=$line.id;cue=$Cue;action=$line.action;text=$line.text;time=$Now.ToString('HH:mm');hour=$Now.Hour}}
 if($Cue -notin @('early','soon','bed','final')){throw 'Unknown clock reminder phase'}
 $hourLine=$script:personaLines|Where-Object {$_.persona -eq $cfg.Persona -and $_.cue -eq 'hour' -and [int]$_.hour -eq $Now.Hour}|Select-Object -First 1
 $cueLine=Get-CompanionLine $Cue
 return [pscustomobject]@{id=$cueLine.id;cue=$Cue;action=$cueLine.action;text=$hourLine.text+$cueLine.text;parts=@($hourLine,$cueLine);time=$Now.ToString('HH:mm');hour=$Now.Hour}
}
Repair-PersonaSettings
