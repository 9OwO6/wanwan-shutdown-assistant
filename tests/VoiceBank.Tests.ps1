$ErrorActionPreference='Stop'
# 称呼 + 正文的解析逻辑：用一个假的分段声音包（空文件）测试，不需要 WPF 或真实录音。
function Assert-Bank([bool]$Pass,[string]$Message){if(-not $Pass){throw $Message}}
$repo=Split-Path $PSScriptRoot
$root=Join-Path ([IO.Path]::GetTempPath()) ('wanwan-voicebank-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force (Join-Path $root 'assets/voices/V9') | Out-Null
Copy-Item (Join-Path $repo 'assets/voice-script.json') (Join-Path $root 'assets/voice-script.json')
'{"voices":[{"id":"N1","name":"清甜"},{"id":"V9","name":"测试"},{"id":"V8","name":"未安装"}]}' | Set-Content (Join-Path $root 'assets/voices.json') -Encoding UTF8
$script=Get-Content (Join-Path $root 'assets/voice-script.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$clips=@()
function Add-Clip([string]$Kind,[string]$Id,[string]$Text){
    $file="assets/voices/V9/$Kind-$Id.mp3"; Set-Content (Join-Path $root $file) 'x'
    $script:clips+=[pscustomobject]@{kind=$Kind;id=$Id;text=$Text;file=$file;duration=2.0}
}
foreach($row in $script.lines){Add-Clip line $row.id $row.body}
foreach($row in $script.clock.hours){Add-Clip hour $row.id $row.body}
foreach($row in $script.clock.tails){Add-Clip tail $row.id $row.body}
foreach($row in $script.addresses){Add-Clip address $row.id $row.text}
@{voice='V9';clips=$clips} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $root 'assets/voices/V9/bank.json') -Encoding UTF8
# VoiceBank.ps1 在程序里由 Main.ps1 提供这些变量。
$script:n1Records=@(); $cfg=@{VoicePreset='V9';Address='';Nickname='你'}
. (Join-Path $repo 'app/VoiceBank.ps1')
function Clip([string]$Kind,[string]$Id){Join-Path $root "assets/voices/V9/$Kind-$Id.mp3"}

Assert-Bank ($cfg.Address -eq 'rotate') 'Default nickname 你 must migrate to rotating addresses'
Assert-Bank ((@(Get-AvailableVoices).id -join ',') -eq 'N1,V9') 'Only installed voices are offered'
$preview=[pscustomobject]@{id='preview-01';cue='preview';action='peek';text='宝宝，已经有点晚啦。先保存一下，好不好？我陪你慢慢收尾。';file='';duration=0}
$bed=[pscustomobject]@{id='bed-01';cue='bed';action='nod';text='到约好的时间啦，宝宝。先保存文件，再关闭手上的程序，我们该休息啦。';file='';duration=0}
$plain=[pscustomobject]@{id='peek-01';cue='peek';action='peek';text='x';file='';duration=0}

# 1. 轮流叫：沿用原 N1 台词里的称呼，但称呼统一放到句首
$r=Resolve-Speech $preview
Assert-Bank ($r.Text -eq '宝宝，已经有点晚啦。先保存一下，好不好？我陪你慢慢收尾。') "Rotate text: $($r.Text)"
Assert-Bank (($r.Clips -join '|') -eq ((Clip address baobao),(Clip line preview-01) -join '|')) 'Rotate must play the address then the body'
Assert-Bank ([math]::Abs($r.Duration-4.1) -lt 0.001) "Duration must include the pause: $($r.Duration)"
$r=Resolve-Speech $bed
Assert-Bank ($r.Text -eq '宝宝，到约好的时间啦。先保存文件，再关闭手上的程序，我们该休息啦。') "Mid-sentence address moves to the front: $($r.Text)"

# 2. 指定称呼 / 不叫称呼
$cfg.Address='xiaobendan';$r=Resolve-Speech $bed
Assert-Bank ($r.Text -like '小笨蛋，到约好的时间啦*' -and $r.Clips[0] -eq (Clip address xiaobendan)) 'Chosen address must be spoken and shown'
$cfg.Address='none';$r=Resolve-Speech $bed
Assert-Bank ($r.Text -eq '到约好的时间啦。先保存文件，再关闭手上的程序，我们该休息啦。' -and $r.Clips.Count -eq 1) 'No address: body only'

# 3. 本来没有称呼的句子不会被加上称呼
$cfg.Address='baobei';$r=Resolve-Speech $plain
$body=($script.lines|Where-Object id -eq 'peek-01').body
Assert-Bank ($r.Text -eq $body -and $r.Clips.Count -eq 1) 'Lines without an address slot stay unchanged'

# 4. 自定义名字：文字里有，录音里不叫；系统朗读时读出完整文字
$cfg.Address='custom';$cfg.Nickname='小明';$r=Resolve-Speech $preview
Assert-Bank ($r.Text -like '小明，已经有点晚啦*' -and $r.Clips.Count -eq 1 -and $r.Clips[0] -eq (Clip line preview-01)) 'Custom name is text-only for recorded voices'
$r=Resolve-Speech $preview 'System'
Assert-Bank ($r.Text -like '小明，已经有点晚啦*' -and $r.Clips.Count -eq 0 -and $r.Duration -ge 3) 'System voice reads the custom name'

# 5. 整点报时：称呼 + 整点 + 提醒三段
$cfg.Address='qinaide';$clock=[pscustomobject]@{id='clock-23-early';cue='early';action='water';text='宝贝，已经晚上十一点啦。快到睡觉时间喽。';file='';duration=0}
$r=Resolve-Speech $clock
Assert-Bank ($r.Text -like '亲爱的，已经晚上十一点啦。快到睡觉时间喽。*' -and $r.Clips.Count -eq 3 -and $r.Clips[1] -eq (Clip hour hour-23) -and $r.Clips[2] -eq (Clip tail tail-early)) "Clock must be address + hour + tail: $($r.Text)"
$cfg.Address='rotate';$r=Resolve-Speech $clock
Assert-Bank ($r.Text -like '宝贝，已经晚上十一点啦*') 'Clock rotates to the original 宝贝'

# 6. 守护和起夜监督台词也在表里
$cfg.Address='baobao';$r=Resolve-Speech ([pscustomobject]@{id='guard-due';cue='due';action='nod';text='x';file='';duration=0})
Assert-Bank ($r.Text -like '宝宝，已经超过休息时间啦*' -and $r.Clips.Count -eq 2) 'Guard lines take the address'
$r=Resolve-Speech ([pscustomobject]@{id='watch-caught';cue='caught';action='peek';text='x';file='';duration=0})
Assert-Bank ($r.Text -like '诶嘿，被晚晚发现啦*' -and $r.Clips.Count -eq 1) 'Watch lines without an address stay unchanged'

# 7. 缺片段时不播放半句：交给系统朗读
Remove-Item (Join-Path $root 'assets/voices/V9/address-baobao.mp3');$r=Resolve-Speech $preview
Assert-Bank ($r.Clips.Count -eq 0 -and $r.Text -like '宝宝，*') 'Missing clip must fall back to speech, never half a sentence'

# 8. 旧设置迁移
foreach($case in @(@('宝贝','baobei'),@('亲爱的朋友','custom'),@('','rotate'))){
    $cfg=@{VoicePreset='V9';Nickname=$case[0]};Repair-AddressSetting
    Assert-Bank ($cfg.Address -eq $case[1]) "Nickname '$($case[0])' must migrate to $($case[1]), got $($cfg.Address)"
}
$cfg=@{Address='gone'};Repair-AddressSetting;Assert-Bank ($cfg.Address -eq 'rotate') 'Unknown address resets to rotate'

Remove-Item -LiteralPath $root -Recurse -Force
Write-Output '20 voice bank tests passed (address + body splicing, rotate/none/chosen/custom, clock three-part, guard/watch, missing-clip fallback, migration)'
