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
Write-Output '11 schedule boundary tests passed'
