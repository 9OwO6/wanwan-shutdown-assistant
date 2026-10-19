# 声音包与称呼：从 v0.4.0 起，每种声音把「称呼」和「正文」分开录制，播放时先称呼、停顿、再正文。
# 这样换称呼不用重录整套台词；自定义名字只出现在气泡文字里（系统朗读时也会读出来）。
# N1 仍保留旧的整句录音（称呼已经录在句子里），所以 N1 只会按原录音轮流称呼。
$script:voiceScriptPath=Join-Path $root 'assets\voice-script.json'
$script:voiceScript=if(Test-Path $script:voiceScriptPath){Get-Content $script:voiceScriptPath -Raw -Encoding UTF8|ConvertFrom-Json}else{$null}
$script:scriptLines=@{};$script:scriptHours=@{};$script:scriptTails=@{};$script:addressById=@{}
if($script:voiceScript){
 foreach($row in @($script:voiceScript.lines)){$script:scriptLines[$row.id]=$row}
 foreach($row in @($script:voiceScript.clock.hours)){$script:scriptHours[[int]$row.hour]=$row}
 foreach($row in @($script:voiceScript.clock.tails)){$script:scriptTails[$row.cue]=$row}
 foreach($row in @($script:voiceScript.addresses)){$script:addressById[$row.id]=$row}
}
$script:voicePauseSeconds=if($script:voiceScript){[double]$script:voiceScript.pause_ms/1000}else{0.1}

# 可选的声音：N1（旧整句包）和所有带 bank.json 的分段声音包。
$script:voiceCatalogPath=Join-Path $root 'assets\voices.json'
$script:voiceCatalog=if(Test-Path $script:voiceCatalogPath){@((Get-Content $script:voiceCatalogPath -Raw -Encoding UTF8|ConvertFrom-Json).voices|ForEach-Object {$_})}else{@()}
$script:voiceBanks=@{}
foreach($voiceInfo in $script:voiceCatalog){
 $bankPath=Join-Path $root ("assets\voices\{0}\bank.json" -f $voiceInfo.id)
 if(-not (Test-Path $bankPath)){continue}
 $clips=@{}
 foreach($clip in @((Get-Content $bankPath -Raw -Encoding UTF8|ConvertFrom-Json).clips|ForEach-Object {$_})){
  $clips[$clip.kind+':'+$clip.id]=[pscustomobject]@{file=(Join-Path $root $clip.file);duration=[double]$clip.duration;text=$clip.text}
 }
 $script:voiceBanks[$voiceInfo.id]=$clips
}
function Get-AvailableVoices {
 # 返回设置里可选的录音声音（不含系统朗读），按 voices.json 的顺序。
 return @($script:voiceCatalog|Where-Object {$_.id -eq 'N1' -or $script:voiceBanks.ContainsKey($_.id)})
}
function Test-SplitVoice([string]$Voice){return $script:voiceBanks.ContainsKey($Voice)}

# ---------- 称呼设置 ----------
# Address：rotate（轮流叫，按原 N1 台词）、none（不叫称呼）、addresses[].id，或 custom（用 Nickname 里的文字）。
function Repair-AddressSetting {
 if(-not $cfg.ContainsKey('Address') -or -not $cfg.Address){
  # 旧版本只有「称呼」输入框：默认「你」= 轮流叫；填过预设称呼就选它，否则当作自定义名字。
  $nick=[string]$cfg.Nickname
  $match=@($script:addressById.Values|Where-Object {$_.label -eq $nick})|Select-Object -First 1
  $cfg.Address=if(-not $nick -or $nick -eq '你'){'rotate'}elseif($match){$match.id}else{'custom'}
 }
 if($cfg.Address -notin @('rotate','none','custom') -and -not $script:addressById.ContainsKey([string]$cfg.Address)){$cfg.Address='rotate'}
}
function Get-AddressChoice([string]$N1Address){
 # 返回 @{Id=录音里用的称呼 id 或 $null; Label=文字里显示的称呼或 ''}
 switch($cfg.Address){
  'rotate'{if($N1Address -and $script:addressById.ContainsKey($N1Address)){return @{Id=$N1Address;Label=$script:addressById[$N1Address].label}};return @{Id=$null;Label=''}}
  'none'{return @{Id=$null;Label=''}}
  'custom'{$name=([string]$cfg.Nickname).Trim();if(-not $name -or $name -eq '你'){return @{Id=$null;Label=''}};return @{Id=$null;Label=$name}}
  default{$row=$script:addressById[[string]$cfg.Address];return @{Id=$row.id;Label=$row.label}}
 }
}

# ---------- 把一句台词解析成文字 + 要播放的片段 ----------
function Resolve-Speech($Line,[string]$Voice=$cfg.VoicePreset){
 # $Line 是旧目录里的台词对象（id/cue/action/text/file/duration）。返回 @{Text;Clips;Duration}。
 $parts=@();$addressed=$false;$n1Address=$null
 if($Line.id -match '^clock-(\d{2})-(\w+)$' -and $script:scriptHours.ContainsKey([int]$Matches[1]) -and $script:scriptTails.ContainsKey($Matches[2])){
  $addressed=$true;$n1Address=$script:voiceScript.clock.address
  $parts=@(@{kind='hour';id=$script:scriptHours[[int]$Matches[1]].id;body=$script:scriptHours[[int]$Matches[1]].body},@{kind='tail';id=$script:scriptTails[$Matches[2]].id;body=$script:scriptTails[$Matches[2]].body})
 }elseif($Line.id -and $script:scriptLines.ContainsKey($Line.id)){
  $row=$script:scriptLines[$Line.id];$addressed=[bool]$row.addressed;$n1Address=$row.n1_address
  $parts=@(@{kind='line';id=$row.id;body=$row.body})
 }
 $legacyFile=if($Line.file){if([IO.Path]::IsPathRooted($Line.file)){$Line.file}else{Join-Path $root $Line.file}}else{''}
 $legacyDuration=if($Line.duration){[double]$Line.duration}else{$record=$script:n1Records|Where-Object {$_.id -eq $Line.id}|Select-Object -First 1;if($record){[double]$record.duration}else{0}}
 # 不在台词表里的句子（例如测试用文字）：原样朗读。
 if(-not $parts.Count){
  $clips=if($Voice -eq 'N1' -and $legacyFile -and (Test-Path $legacyFile)){@($legacyFile)}else{@()}
  return @{Text=$Line.text;Clips=$clips;Duration=$legacyDuration}
 }
 $address=if($addressed){Get-AddressChoice $n1Address}else{@{Id=$null;Label=''}}
 $body=($parts|ForEach-Object {$_.body}) -join ''
 $text=if($address.Label){$address.Label+'，'+$body}else{$body}
 if(Test-SplitVoice $Voice){
  $bank=$script:voiceBanks[$Voice];$clips=@();$duration=0
  $keys=@();if($address.Id){$keys+='address:'+$address.Id};foreach($part in $parts){$keys+=($part.kind+':'+$part.id)}
  foreach($key in $keys){
   $clip=$bank[$key]
   if(-not $clip -or -not (Test-Path $clip.file)){return @{Text=$text;Clips=@();Duration=0}}
   $clips+=$clip.file;$duration+=$clip.duration
  }
  $duration+=$script:voicePauseSeconds*[math]::Max(0,$clips.Count-1)
  return @{Text=$text;Clips=$clips;Duration=$duration}
 }
 if($Voice -eq 'N1' -and $legacyFile -and (Test-Path $legacyFile)){
  # N1 的整句录音自带原来的称呼，文字也保持原样，保证字幕和声音一致。
  return @{Text=$Line.text;Clips=@($legacyFile);Duration=$legacyDuration}
 }
 # 系统朗读：读出完整文字（包括自定义名字）。
 return @{Text=$text;Clips=@();Duration=[math]::Max(3,$text.Length*0.24)}
}
function Speak-Line($Line){
 # 统一入口：按当前声音和称呼解析后播放，返回实际显示/朗读的台词对象。
 $speech=Resolve-Speech $Line
 $spoken=[pscustomobject]@{id=$Line.id;cue=$Line.cue;action=$Line.action;text=$speech.Text;file=$(if($speech.Clips.Count){$speech.Clips[0]}else{''});duration=$(if($speech.Duration){$speech.Duration}else{[double]$Line.duration})}
 foreach($extra in @('time','hour')){if($Line.PSObject.Properties[$extra]){$spoken|Add-Member -NotePropertyName $extra -NotePropertyValue $Line.$extra}}
 $script:lastSpokenLine=$spoken
 Say $speech.Text -LineId $Line.id -ActionId $Line.action -PreparedClips $speech.Clips -PreparedDuration $spoken.duration
 return $spoken
}
Repair-AddressSetting
