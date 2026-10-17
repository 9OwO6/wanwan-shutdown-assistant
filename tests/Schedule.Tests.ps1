$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\app\Schedule.ps1"
$cfg=@{Bedtime='23:30';Grace=10}
$cases=@(
 @('2026-10-10 12:00','Day','2026-10-10'),
 @('2026-10-10 22:59','Day','2026-10-10'),
 @('2026-10-10 23:00','Early','2026-10-10'),
 @('2026-10-10 23:20','Soon','2026-10-10'),
 @('2026-10-10 23:30','Bed','2026-10-10'),
 @('2026-10-10 23:38','Final','2026-10-10'),
 @('2026-10-10 23:40','Due','2026-10-10'),
 @('2026-10-11 00:10','Due','2026-10-10'),
 @('2026-10-11 04:00','Day','2026-10-11')
)
foreach($case in $cases){$s=Get-NightState ([datetime]$case[0]) $cfg;if($s.Phase -ne $case[1] -or $s.Key -ne $case[2]){throw "Failed: $($case[0]) -> $($s.Phase), $($s.Key)"}}
$cfg.Bedtime='00:15'
$s=Get-NightState ([datetime]'2026-10-10 23:50') $cfg
if($s.Phase -ne 'Early' -or $s.Key -ne '2026-10-11'){throw 'After-midnight bedtime failed'}
$s=Get-NightState ([datetime]'2026-10-11 00:25') $cfg
if($s.Phase -ne 'Due'){throw 'After-midnight deadline failed'}
# 周末作息：周五、周六晚上使用 WeekendBedtime；2026-10-16 是周五。
$cfg=@{Bedtime='23:30';WeekendBedtime='01:00';Grace=10}
$weekend=@(
 @('2026-10-15 23:30','Bed','2026-10-15'),   # 周四晚仍是工作日时间
 @('2026-10-16 23:30','Day','2026-10-17'),   # 周五 23:30 不再提醒
 @('2026-10-17 00:30','Early','2026-10-17'), # 周五晚的 01:00 落在周六凌晨
 @('2026-10-17 01:10','Due','2026-10-17'),
 @('2026-10-17 23:30','Day','2026-10-18'),   # 周六晚同样是周末时间
 @('2026-10-18 01:00','Bed','2026-10-18'),
 @('2026-10-18 23:30','Bed','2026-10-18'),   # 周日晚恢复工作日时间
 @('2026-10-18 05:00','Due','2026-10-18')    # 周六晚截止后四小时内仍是当晚
)
foreach($case in $weekend){$s=Get-NightState ([datetime]$case[0]) $cfg;if($s.Phase -ne $case[1] -or $s.Key -ne $case[2]){throw "Weekend failed: $($case[0]) -> $($s.Phase), $($s.Key)"}}
$s=Get-NightState ([datetime]'2026-10-16 12:00') $cfg
if($s.Bed -ne [datetime]'2026-10-17 01:00'){throw "Friday daytime should point at the weekend bedtime, got $($s.Bed)"}
$cfg.WeekendBedtime=''
$s=Get-NightState ([datetime]'2026-10-16 23:30') $cfg
if($s.Phase -ne 'Bed'){throw 'Empty weekend bedtime must fall back to the weekday time'}
Write-Output '21 schedule boundary tests passed (including weekend bedtimes)'
