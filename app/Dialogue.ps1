$script:dialogue=Get-Content (Join-Path $root 'assets\companion-lines.json') -Raw -Encoding UTF8|ConvertFrom-Json
$script:dialogueBags=@{};$script:lastDialogue=@{};$script:lastSpokenLine=$null
function Get-CompanionLine([string]$Cue){
 $options=@($script:dialogue.lines|Where-Object {$_.cue -eq $Cue})
 if(-not $options.Count){throw "Unknown dialogue cue: $Cue"}
 if(-not $script:dialogueBags.ContainsKey($Cue) -or $script:dialogueBags[$Cue].Count -eq 0){
  $bag=[Collections.Generic.List[object]]::new()
  foreach($item in @($options|Sort-Object {Get-Random})){$bag.Add($item)}
  if($bag.Count -gt 1 -and $bag[0].id -eq $script:lastDialogue[$Cue]){$swap=$bag[0];$bag[0]=$bag[1];$bag[1]=$swap}
  $script:dialogueBags[$Cue]=$bag
 }
 $line=$script:dialogueBags[$Cue][0];$script:dialogueBags[$Cue].RemoveAt(0);$script:lastDialogue[$Cue]=$line.id
 return $line
}
function Format-CompanionAddress([string]$Text,[string]$Nickname){
 if(-not $Nickname -or $Nickname -eq '你'){return $Text}
 $names=if($script:dialogue.addresses){@($script:dialogue.addresses)}else{@('宝贝')}
 $pattern=(@($names|Sort-Object {$_.Length} -Descending|ForEach-Object {[regex]::Escape($_)})) -join '|'
 # 一次替换避免自定义称呼中的昵称被再次替换，也保留字面量美元符号。
 return [regex]::Replace($Text,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($match) $Nickname})
}
function Say-Cue {
 param([string]$Cue,[switch]$Interaction,[switch]$Demo)
 if($Demo -and $Cue -eq 'dialog'){$Cue='demo'}
 $line=Get-CompanionLine $Cue
 # 旧音色包保留它们实际录制的台词；互动新台词没有旧录音时由系统朗读。
 if($cfg.VoicePreset -in @('A','B','C','D') -and -not $Interaction){
  $legacyCue=if($Cue -eq 'night'){'goodnight'}else{$Cue}
  $legacy=$script:voiceLines|Where-Object {$_.id -eq $legacyCue}|Select-Object -First 1
  if($legacy){$line=[pscustomobject]@{id=$legacy.id;cue=$Cue;action=$line.action;text=$legacy.text}}
 }
 $script:lastSpokenLine=$line
 if($cfg.VoicePreset -eq 'System' -and $cfg.Nickname -and $cfg.Nickname -ne '你'){
  $line=[pscustomobject]@{id='';cue=$line.cue;action=$line.action;text=(Format-CompanionAddress $line.text $cfg.Nickname)}
  $script:lastSpokenLine=$line
 }
 Say $line.text -LineId $line.id -ActionId $line.action
 if($script:dialog -and $Cue -in @('dialog','demo','final','bye')){$script:dialog.FindName('Info').Text=$line.text}
}
