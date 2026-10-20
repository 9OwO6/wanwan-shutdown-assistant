$ErrorActionPreference='Stop'
# 桌宠行为的纯逻辑：困意、程序分类、选动作、间隔。不需要 WPF。
. "$PSScriptRoot\..\app\BehaviorCore.ps1"
function Assert-Behavior([bool]$Pass,[string]$Message){if(-not $Pass){throw $Message}}
$rules=Get-Content "$PSScriptRoot\..\assets\activity-rules.json" -Raw -Encoding UTF8|ConvertFrom-Json
$bed=[datetime]'2026-10-12T23:30:00'

# 1. 困意随时间变化
Assert-Behavior ((Get-Sleepiness ([datetime]'2026-10-12T21:00:00') $bed) -eq 0) 'Far from bedtime: awake'
Assert-Behavior ((Get-Sleepiness ([datetime]'2026-10-12T22:45:00') $bed) -eq 1) 'Within an hour: a bit sleepy'
Assert-Behavior ((Get-Sleepiness ([datetime]'2026-10-12T23:10:00') $bed) -eq 2) 'Within half an hour: sleepy'
Assert-Behavior ((Get-Sleepiness ([datetime]'2026-10-13T00:30:00') $bed) -eq 3) 'Past bedtime: very sleepy'
Assert-Behavior ((Get-Sleepiness ([datetime]'2026-10-13T09:00:00') $bed) -eq 0) 'Next morning: awake again'

# 2. 只按进程名和是否全屏归类
Assert-Behavior ((Get-ActivityCategory 'vlc' $false $rules) -eq 'video') 'Video player'
Assert-Behavior ((Get-ActivityCategory 'Code.exe' $false $rules) -eq 'work') 'Editor counts as work (case and .exe ignored)'
Assert-Behavior ((Get-ActivityCategory 'chrome' $true $rules) -eq 'video') 'Fullscreen browser is probably a video'
Assert-Behavior ((Get-ActivityCategory 'chrome' $false $rules) -eq 'browse') 'Windowed browser is browsing'
Assert-Behavior ((Get-ActivityCategory 'SomeNewGame' $true $rules) -eq 'game') 'Unknown fullscreen program is a game'
Assert-Behavior ((Get-ActivityCategory 'SomeNewTool' $false $rules) -eq 'none') 'Unknown windowed program is nothing in particular'
Assert-Behavior ((Get-ActivityCategory 'explorer' $true $rules) -eq 'none') 'Ignored shell stays nothing even fullscreen'
Assert-Behavior ((Get-ActivityCategory '' $false $rules) -eq 'none') 'No foreground window'

# 3. 选动作
$random=[Random]::new(7)
function Count-Picks($State,[int]$N=400){$counts=@{};for($i=0;$i -lt $N;$i++){$b=Select-PetBehavior $State $random;$counts[$b]=1+[int]$counts[$b]};return $counts}
$awake=Count-Picks @{Sleepiness=0;Away=$false;Activity='none';Companion=$false;Last=''}
Assert-Behavior (-not $awake.ContainsKey('yawn') -and -not $awake.ContainsKey('watch') -and -not $awake.ContainsKey('sleep')) 'Awake and on her own: no yawning, no companion actions'
$late=Count-Picks @{Sleepiness=3;Away=$false;Activity='none';Companion=$false;Last=''}
Assert-Behavior ($late['yawn'] -gt 400*0.45) "Past bedtime she mostly yawns ($($late['yawn'])/400)"
$video=Count-Picks @{Sleepiness=0;Away=$false;Activity='video';Companion=$true;Last=''}
Assert-Behavior ($video['watch'] -gt 400*0.4) 'Companion mode: watches along'
$offVideo=Count-Picks @{Sleepiness=0;Away=$false;Activity='video';Companion=$false;Last=''}
Assert-Behavior (-not $offVideo.ContainsKey('watch')) 'Companion off: never mirrors what you do'
$game=Count-Picks @{Sleepiness=0;Away=$false;Activity='game';Companion=$true;Last=''}
Assert-Behavior ($game['play'] -gt 400*0.4) 'Companion mode: plays along'
Assert-Behavior ((Select-PetBehavior @{Sleepiness=0;Away=$true;Activity='none';Companion=$true;Last=''} $random) -eq 'sleep') 'Away: she naps'
$repeat=0;$last='';for($i=0;$i -lt 200;$i++){$b=Select-PetBehavior @{Sleepiness=1;Away=$false;Activity='none';Companion=$false;Last=$last} $random;if($b -eq $last){$repeat++};$last=$b}
Assert-Behavior ($repeat -eq 0) 'Never the same action twice in a row'

# 4. 间隔：平时 2–4 分钟，越困越频繁
$delays=@(for($i=0;$i -lt 100;$i++){Get-NextBehaviorDelay 0 $random});Assert-Behavior (($delays|Measure-Object -Minimum).Minimum -ge 120 -and ($delays|Measure-Object -Maximum).Maximum -lt 240) 'Awake delay 2-4 minutes'
$delays=@(for($i=0;$i -lt 100;$i++){Get-NextBehaviorDelay 3 $random});Assert-Behavior (($delays|Measure-Object -Maximum).Maximum -lt 120) 'Sleepy delay under 2 minutes'

# 5. 书桌素材到位前用现有动作顶替
Assert-Behavior ((Get-BehaviorAnimation 'drink' @('water','peek')) -eq 'water') 'Fallback animation'
Assert-Behavior ((Get-BehaviorAnimation 'drink' @('water','desk-drink')) -eq 'desk-drink') 'Desk animation preferred when present'
Write-Output '24 behavior tests passed (sleepiness by time, activity categories, weighted picks with companion on/off, no repeats, delays, desk fallback)'
