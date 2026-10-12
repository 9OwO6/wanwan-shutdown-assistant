function Get-NightState {
    param([datetime]$Now, $Config)
    $today = $Now.Date.Add([timespan]::Parse($Config.Bedtime))
    $bed = $null
    foreach($candidate in @($today.AddDays(-1),$today,$today.AddDays(1))){
        if($Now -ge $candidate.AddMinutes(-30) -and $Now -lt $candidate.AddMinutes([int]$Config.Grace).AddHours(4)){$bed=$candidate;break}
    }
    if($null -eq $bed){
        $bed=if($Now -lt $today.AddMinutes(-30)){$today}else{$today.AddDays(1)}
        return @{Phase='Day';Bed=$bed;End=$bed.AddMinutes([int]$Config.Grace);Key=$bed.ToString('yyyy-MM-dd')}
    }
    $end = $bed.AddMinutes([int]$Config.Grace)
    $key = $bed.ToString('yyyy-MM-dd')
    if ($Now -ge $end.AddHours(4)) { return @{Phase='Day'; Bed=$bed.AddDays(1); End=$end.AddDays(1); Key=$bed.AddDays(1).ToString('yyyy-MM-dd')} }
    $phase = 'Quiet'
    if ($Now -ge $bed.AddMinutes(-30)) { $phase='Early' }
    if ($Now -ge $bed.AddMinutes(-10)) { $phase='Soon' }
    if ($Now -ge $bed) { $phase='Bed' }
    if ($Now -ge $end.AddMinutes(-2)) { $phase='Final' }
    if ($Now -ge $end) { $phase='Due' }
    return @{Phase=$phase; Bed=$bed; End=$end; Key=$key}
}
