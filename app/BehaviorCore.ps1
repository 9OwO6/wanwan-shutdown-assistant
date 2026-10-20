# 桌宠行为的纯逻辑：困意、你在做什么、下一个小动作。不依赖 WPF 或 Windows API，可以单独测试。

function Get-Sleepiness([datetime]$Now,[datetime]$Bed){
 # 0 = 精神；1 = 睡前一小时内；2 = 睡前半小时内；3 = 已经过了睡觉时间。离睡觉还很远（或白天）都算 0。
 $minutes=($Bed-$Now).TotalMinutes
 if($minutes -le 0 -and $minutes -gt -360){return 3}
 if($minutes -gt 0 -and $minutes -le 30){return 2}
 if($minutes -gt 30 -and $minutes -le 60){return 1}
 return 0
}

function Get-ActivityCategory([string]$ProcessName,[bool]$Fullscreen,$Rules){
 # 只看前台程序属于哪一类（不看窗口标题和内容）：video / game / work / browse / none。
 $name=([string]$ProcessName).ToLowerInvariant() -replace '\.exe$',''
 if(-not $name){return 'none'}
 if($name -in @($Rules.video)){return 'video'}
 if($name -in @($Rules.game)){return 'game'}
 if($name -in @($Rules.work)){return 'work'}
 if($name -in @($Rules.browser)){if($Fullscreen){return 'video'};return 'browse'}
 if($name -in @($Rules.ignore)){return 'none'}
 # 不认识的程序全屏运行，多半是游戏。
 if($Fullscreen){return 'game'}
 return 'none'
}

function Select-PetBehavior($State,[Random]$Random){
 # $State：@{Sleepiness;Away;Activity;Companion;Last}。返回行为 id。
 if($State.Companion -and $State.Away){return 'sleep'}
 $weights=[ordered]@{write=3;drink=2;stretch=2;peek=1;yawn=0}
 $weights.yawn=[int]$State.Sleepiness*2
 if($State.Sleepiness -ge 3){$weights.write=1;$weights.stretch=1;$weights.yawn=6}
 if($State.Companion){
  switch($State.Activity){
   'video'{$weights['watch']=8}
   'game'{$weights['play']=8}
   'work'{$weights.write+=6}
   'browse'{$weights.peek+=2}
  }
 }
 # 不连续做同一个动作（除非只剩它）。
 $choices=@($weights.Keys|Where-Object {$weights[$_] -gt 0 -and $_ -ne $State.Last})
 if(-not $choices.Count){$choices=@($weights.Keys|Where-Object {$weights[$_] -gt 0})}
 $total=0;foreach($c in $choices){$total+=$weights[$c]}
 $pick=$Random.Next(0,$total);$sum=0
 foreach($c in $choices){$sum+=$weights[$c];if($pick -lt $sum){return $c}}
 return $choices[-1]
}

function Get-NextBehaviorDelay([int]$Sleepiness,[Random]$Random){
 # 平时 2–4 分钟做一个小动作；越困越频繁（打哈欠），最快 1–2 分钟。
 $range=switch($Sleepiness){3{@(60,120)}2{@(80,160)}1{@(100,200)}default{@(120,240)}}
 return $Random.Next($range[0],$range[1])
}

# 行为 → 现有动作帧（书桌素材到位前的替代）。有书桌素材时用 desk-<行为>。
$script:BehaviorFallback=@{write='nod';drink='water';stretch='stretch';peek='peek';yawn='yawn';sleep='goodnight';watch='peek';play='cheer'}
function Get-BehaviorAnimation([string]$Behavior,$Available){
 if($Available -contains ('desk-'+$Behavior)){return 'desk-'+$Behavior}
 if($script:BehaviorFallback.ContainsKey($Behavior)){return $script:BehaviorFallback[$Behavior]}
 return 'peek'
}
