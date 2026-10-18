$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\app\Schedule.ps1"
. "$PSScriptRoot\..\app\History.ps1"
function Assert-History([bool]$Pass,[string]$Message){if(-not $Pass){throw $Message}}
# 23:30 睡、收尾 10 分钟、守护 6 小时：每晚截止 23:40，守护到次日 05:30。
$cfg=@{Bedtime='23:30';Grace=10;SleepHours=6;Enabled=$true}
$n=@{}

# 1. 电脑 22:50 就关了，第二天 08:00 开机 -> early
$changed=Resolve-NightHistory $n ([datetime]'2026-10-12 22:50') ([datetime]'2026-10-13 08:00') $cfg
Assert-History ($n['2026-10-12'] -eq 'early' -and $changed.Count -eq 1) 'Computer off before the deadline must count as early'

# 2. 晚晚一直运行到 01:00 都没关机 -> late
$n=@{}
Resolve-NightHistory $n ([datetime]'2026-10-13 01:00') ([datetime]'2026-10-13 08:00') $cfg|Out-Null
Assert-History ($n['2026-10-12'] -eq 'late') 'Running past the deadline without a power request must count as late'

# 3. 运行中逐秒推进：守护区间结束那一刻补记
$n=@{}
Resolve-NightHistory $n ([datetime]'2026-10-13 05:29:59') ([datetime]'2026-10-13 05:30:00') $cfg|Out-Null
Assert-History ($n['2026-10-12'] -eq 'late') 'Window end must be resolved while running'
Resolve-NightHistory $n ([datetime]'2026-10-13 05:30:00') ([datetime]'2026-10-13 05:30:01') $cfg|Out-Null
Assert-History ($n.Count -eq 1) 'A night must be resolved only once'

# 4. 已有结果不被补记覆盖；只升级不降级
$n=@{'2026-10-12'='slept'}
Resolve-NightHistory $n ([datetime]'2026-10-13 02:00') ([datetime]'2026-10-13 08:00') $cfg|Out-Null
Assert-History ($n['2026-10-12'] -eq 'slept') 'Recorded result must not be overwritten'
Assert-History (Set-NightResult $n '2026-10-12' 'caught') 'caught must upgrade slept'
Assert-History (-not (Set-NightResult $n '2026-10-12' 'slept')) 'slept must not downgrade caught'
Assert-History ($n['2026-10-12'] -eq 'caught') 'caught must stick'

# 5. 几天没开电脑：中间每一晚都算 early
$n=@{}
Resolve-NightHistory $n ([datetime]'2026-10-10 21:00') ([datetime]'2026-10-13 09:00') $cfg|Out-Null
Assert-History (($n.Keys|Sort-Object) -join ',' -eq '2026-10-10,2026-10-11,2026-10-12') 'Nights while the computer stayed off must be early'

# 6. 首次运行（没有 LastSeen）或守护未开启时不补记
$n=@{}
Resolve-NightHistory $n ([datetime]::MinValue) ([datetime]'2026-10-13 09:00') $cfg|Out-Null
$cfg.Enabled=$false;Resolve-NightHistory $n ([datetime]'2026-10-12 21:00') ([datetime]'2026-10-13 09:00') $cfg|Out-Null;$cfg.Enabled=$true
Assert-History ($n.Count -eq 0) 'No inference on first run or with the guard disabled'

# 7. 连续天数：cancelled 不打断，late/空白打断；守护区间未结束的今晚不算
$n=@{'2026-10-12'='slept';'2026-10-11'='cancelled';'2026-10-10'='early';'2026-10-09'='slept';'2026-10-08'='late';'2026-10-07'='slept'}
Assert-History ((Get-SleepStreak $n ([datetime]'2026-10-13 09:00') $cfg) -eq 3) 'Streak must skip cancelled and stop at late'
Assert-History ((Get-SleepStreak $n ([datetime]'2026-10-13 03:00') $cfg) -eq 2) 'A night still inside its window must not count yet'
Assert-History ((Get-SleepStreak @{} ([datetime]'2026-10-13 09:00') $cfg) -eq 0) 'Empty history means no streak'
$marks=Get-RecentNightMarks $n ([datetime]'2026-10-13 09:00') $cfg
Assert-History ($marks -eq '○ ● ○ ● ● ◐ ●') "Recent marks wrong: $marks"

# 8. 周末作息下，周五晚的 01:00 落在周六
$cfg.WeekendBedtime='01:00';$n=@{}
Resolve-NightHistory $n ([datetime]'2026-10-17 00:50') ([datetime]'2026-10-17 10:00') $cfg|Out-Null
Assert-History ($n['2026-10-16'] -eq 'early') 'Friday night (Saturday 01:00 bedtime) must resolve as early at 00:50'
# 周六晚（周日 01:00）和周日晚（周日 23:30）各有自己的记录
$n=@{};Resolve-NightHistory $n ([datetime]'2026-10-17 20:00') ([datetime]'2026-10-19 08:00') $cfg|Out-Null
Assert-History ($n['2026-10-17'] -eq 'early' -and $n['2026-10-18'] -eq 'early' -and $n.Count -eq 2) 'Saturday and Sunday nights must be recorded separately'
Write-Output '17 bedtime history tests passed (early/late inference, upgrades, gaps, streaks, weekend nights)'
