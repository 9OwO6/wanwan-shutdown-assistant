$ErrorActionPreference='Stop'
# 两种性格的台词和称呼：用假的录音包（空文件）测试选句、称呼、整点两段和兜底，不需要 WPF。
function Assert-Persona([bool]$Pass,[string]$Message){if(-not $Pass){throw $Message}}
$repo=Split-Path $PSScriptRoot
$root=Join-Path ([IO.Path]::GetTempPath()) ('wanwan-persona-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force (Join-Path $root 'assets/voices/girlfriend') | Out-Null
Copy-Item (Join-Path $repo 'assets/persona-script.json') (Join-Path $root 'assets/persona-script.json')
$script=Get-Content (Join-Path $root 'assets/persona-script.json') -Raw -Encoding UTF8 | ConvertFrom-Json
# 只给女友做一个假录音包（每个称呼一份整句 + 不带称呼的一份）；姐姐没有录音包。
$clips=@()
foreach($line in @($script.lines | Where-Object persona -eq 'girlfriend')){
    $variants=@('')
    if($line.text.Contains('{称呼}')){$variants+=@('@baobao','@qinaide')}
    foreach($suffix in $variants){
        $name=$line.id.Split('/')[1]+$suffix
        Set-Content (Join-Path $root "assets/voices/girlfriend/$name.mp3") 'x'
        $clips+=[pscustomobject]@{key=$line.id+$suffix;file="assets/voices/girlfriend/$name.mp3";duration=1.5;text=''}
    }
}
@{persona='girlfriend';clips=$clips} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $root 'assets/voices/girlfriend/bank.json') -Encoding UTF8
# Persona.ps1 在程序里由 Main.ps1 提供这些；这里换成记录参数的替身。
$cfg=@{VoicePreset='N1';Nickname='你';Voice=$true;Enabled=$true}
$script:said=$null
function Say {param([string]$message,[string]$LineId,[string]$ActionId,[string[]]$PreparedClips=@(),[double]$PreparedDuration=0) $script:said=@{Text=$message;Clips=$PreparedClips;Duration=$PreparedDuration}}
function Start-Interaction {param([string]$Id,[string]$Caption,[switch]$Popup) $script:gesture=@{Id=$Id;Caption=$Caption}}
. (Join-Path $repo 'app/Persona.ps1')
function Clip([string]$Name){Join-Path $root "assets/voices/girlfriend/$Name.mp3"}

# 1. 旧设置迁移：N1 → 女友，默认称呼「宝宝」；V3 → 姐姐
Assert-Persona ($cfg.Persona -eq 'girlfriend' -and $cfg.Address -eq 'baobao' -and $cfg.VoicePreset -eq 'Recorded' -and $cfg.Companion -eq $false) "Migration: $($cfg.Persona)/$($cfg.Address)/$($cfg.VoicePreset)"
$cfg=@{VoicePreset='V3';Nickname='宝贝';Enabled=$true};Repair-PersonaSettings
Assert-Persona ($cfg.Persona -eq 'sister' -and $cfg.Address -eq 'none') "V3 must become the sister persona: $($cfg.Persona)/$($cfg.Address)"
$cfg=@{VoicePreset='System';Nickname='小明';Enabled=$true};Repair-PersonaSettings
Assert-Persona ($cfg.Persona -eq 'girlfriend' -and $cfg.Address -eq 'custom' -and $cfg.VoicePreset -eq 'System') 'A real custom nickname stays a custom name'
$cfg=@{Persona='sister';Address='baobao';VoicePreset='Recorded';Enabled=$true};Repair-PersonaSettings
Assert-Persona ($cfg.Address -eq 'none') 'An address the persona does not use resets to its default'

# 2. 称呼：整句录音，文字和录音一致
$cfg=@{Persona='girlfriend';Address='qinaide';VoicePreset='Recorded';Nickname='';Voice=$true;Enabled=$true}
$bed=$script:personaLines|Where-Object {$_.id -eq 'girlfriend/bed-1'}
$r=Resolve-Speech $bed
Assert-Persona ($r.Text -eq '到点啦亲爱的～该睡觉觉了，不许再拖了哦。' -and $r.Clips.Count -eq 1 -and $r.Clips[0] -eq (Clip 'bed-1@qinaide')) "Address sentence: $($r.Text)"
$cfg.Address='none';$r=Resolve-Speech $bed
Assert-Persona ($r.Text -eq '到点啦～该睡觉觉了，不许再拖了哦。' -and $r.Clips[0] -eq (Clip 'bed-1')) "No address: $($r.Text)"
$cfg.Address='custom';$cfg.Nickname='小明';$r=Resolve-Speech $bed
Assert-Persona ($r.Text -eq '到点啦小明～该睡觉觉了，不许再拖了哦。' -and $r.Clips[0] -eq (Clip 'bed-1')) 'Custom name: shown in text, recording without address'
$plain=$script:personaLines|Where-Object {$_.id -eq 'girlfriend/final-1'};$cfg.Address='baobao';$r=Resolve-Speech $plain
Assert-Persona ($r.Text -eq $plain.text -and $r.Clips[0] -eq (Clip 'final-1')) 'Lines without an address slot are unchanged'

# 3. 去掉称呼时的标点
foreach($case in @(@('{称呼}，半小时后。','半小时后。'),@('晚安{称呼}，明天见。','晚安，明天见。'),@('晚安，{称呼}。明天见。','晚安。明天见。'),@('{称呼}～听得到吗？','听得到吗？'))){
    Assert-Persona ((Format-PersonaText $case[0] '') -eq $case[1]) "Punctuation: $($case[0]) -> $(Format-PersonaText $case[0] '')"
}

# 4. 整点报时：整点句 + 提醒句两段
$cfg.Address='baobao';$clock=Get-ClockReminder ([datetime]'2026-10-12T23:00:00') early;$r=Resolve-Speech $clock
Assert-Persona ($r.Text -like '宝宝，到十一点啦。*' -and $r.Clips.Count -eq 2 -and $r.Clips[0] -eq (Clip 'hour-23@baobao')) "Clock: $($r.Text)"
Assert-Persona ([math]::Abs($r.Duration-3.3) -lt 0.001) "Clock duration includes the 300 ms pause: $($r.Duration)"
$clock=Get-ClockReminder ([datetime]'2026-10-12T00:05:00') final
$t=(Resolve-Speech $clock).Text;Assert-Persona ($t -like '宝宝，到十二点啦。最后两分钟*') "Midnight clock: $t"

# 5. 守护没开时，不说「帮你关机」
$cfg.Enabled=$false;$seen=@{};for($i=0;$i -lt 8;$i++){$seen[(Get-CompanionLine early).id]=1}
Assert-Persona ($seen.Keys.Count -eq 1 -and -not $seen.ContainsKey('girlfriend/early-2')) 'Guard off must skip the shutdown variant'
$cfg.Enabled=$true;$seen=@{};for($i=0;$i -lt 8;$i++){$seen[(Get-CompanionLine early).id]=1}
Assert-Persona ($seen.Keys.Count -eq 2) 'Guard on rotates both variants'

# 6. 起夜监督、守护和睡眠都有自己的句子
$cfg.Address='none'
Assert-Persona ((Get-WatchLine final).text -eq '好啦，别再试啦，乖乖去睡。') 'Watch final maps to watch-final'
Assert-Persona ((Get-GuardLine sleep).text -notlike '*关机*') 'Sleep line must not mention shutdown'
Say-GuardLine shutdown|Out-Null
Assert-Persona ($script:said.Text -eq '时间到～关机咯。晚安，梦里见。' -and $script:said.Clips[0] -eq (Clip 'shutdown-1') -and $script:lastGuardDuration -eq 1.5) 'Guard line plays its clip'

# 7. 小互动：不说整句，做动作；戳多了会生气
Say-Cue heart -Interaction
Assert-Persona ($script:gesture.Id -eq 'heart' -and $script:lastSpokenLine.text -like '*比心*') 'Gestures are actions, not sentences'
Say-Cue nod -Interaction
Assert-Persona ($script:lastSpokenLine.cue -eq 'ack') 'The acknowledge button maps to ack'
$cues=@();for($i=0;$i -lt 5;$i++){$cues+=(Invoke-Poke).cue}
Assert-Persona (($cues -join ',') -eq 'poke,poke,poke-more,poke-more,poke-angry') "Poke escalation: $($cues -join ',')"

# 8. 没有录音包（姐姐）或系统朗读：交给系统朗读，自定义名字也读出来
$cfg.Persona='sister';$cfg.Address='xiaobendan';$r=Resolve-Speech ($script:personaLines|Where-Object id -eq 'sister/goodnight-1')
Assert-Persona ($r.Clips.Count -eq 0 -and $r.Text -eq '晚安，小笨蛋。明天见。') "No bank: system speech ($($r.Text))"
$cfg.Persona='girlfriend';$cfg.VoicePreset='System';$cfg.Address='custom';$cfg.Nickname='小明';$r=Resolve-Speech $bed
Assert-Persona ($r.Clips.Count -eq 0 -and $r.Text.Contains('小明')) 'System voice reads the custom name'

# 9. 缺一个片段：不播半句
$cfg.VoicePreset='Recorded';$cfg.Address='baobao';Remove-Item (Clip 'hour-23@baobao');$r=Resolve-Speech (Get-ClockReminder ([datetime]'2026-10-12T23:00:00') early)
Assert-Persona ($r.Clips.Count -eq 0) 'Missing clip must fall back to speech, never half a sentence'

Remove-Item -LiteralPath $root -Recurse -Force
Write-Output '26 persona tests passed (migration, whole-sentence addresses, punctuation, two-part clock, guard-off variants, watch/guard/sleep lines, gestures and pokes, fallbacks)'
