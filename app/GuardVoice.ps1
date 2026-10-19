$script:guardLines=(Get-Content (Join-Path $root 'assets\guard-lines.json') -Raw -Encoding UTF8|ConvertFrom-Json).lines
$script:guardRecords=Get-Content (Join-Path $root 'assets\voices\N1-guard\manifest.json') -Raw -Encoding UTF8|ConvertFrom-Json
function Get-GuardLine([string]$Cue){
 $line=$script:guardLines|Where-Object cue -eq $Cue|Select-Object -First 1
 $record=$script:guardRecords|Where-Object {$_.id -eq $line.id -and $_.text -eq $line.text}|Select-Object -First 1
 if(-not $record -or -not (Test-Path (Join-Path $root $line.file))){throw '守护提醒录音与台词不一致'}
 return [pscustomobject]@{id=$line.id;cue=$Cue;action=$line.action;text=$line.text;file=$line.file;duration=$record.duration}
}
function Say-GuardLine([string]$Cue){
 $spoken=Speak-Line (Get-GuardLine $Cue);$script:lastGuardDuration=$spoken.duration
}
