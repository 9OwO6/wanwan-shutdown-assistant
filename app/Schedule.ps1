function Get-NightBedtime {
    # 每晚的睡觉时刻。周五、周六晚上可以使用单独的周末时间。
    # 早于中午的时间（如 00:30）算作前一天晚上的延续：周五晚的 01:00 落在周六凌晨。
    param([datetime]$Evening, $Config)
    $text = $Config.Bedtime
    if ($Config.WeekendBedtime -and $Evening.DayOfWeek -in @([DayOfWeek]::Friday, [DayOfWeek]::Saturday)) { $text = $Config.WeekendBedtime }
    $time = [timespan]::Parse($text)
    $bed = $Evening.Date.Add($time)
    if ($time.TotalHours -lt 12) { $bed = $bed.AddDays(1) }
    return $bed
}
function Get-NightState {
    param([datetime]$Now, $Config)
    $grace = [int]$Config.Grace
    # 每晚的区间：提前 30 分钟开始提醒，截止后 4 小时结束。按时间顺序找第一个覆盖当前时刻的夜晚。
    $nights = foreach ($offset in -2..2) { Get-NightBedtime $Now.Date.AddDays($offset) $Config }
    $bed = $nights | Where-Object { $Now -ge $_.AddMinutes(-30) -and $Now -lt $_.AddMinutes($grace).AddHours(4) } | Select-Object -First 1
    if ($null -eq $bed) {
        $bed = $nights | Where-Object { $_.AddMinutes(-30) -gt $Now } | Select-Object -First 1
        return @{Phase='Day'; Bed=$bed; End=$bed.AddMinutes($grace); Key=$bed.ToString('yyyy-MM-dd')}
    }
    $end = $bed.AddMinutes($grace)
    $phase = 'Quiet'
    if ($Now -ge $bed.AddMinutes(-30)) { $phase='Early' }
    if ($Now -ge $bed.AddMinutes(-10)) { $phase='Soon' }
    if ($Now -ge $bed) { $phase='Bed' }
    if ($Now -ge $end.AddMinutes(-2)) { $phase='Final' }
    if ($Now -ge $end) { $phase='Due' }
    return @{Phase=$phase; Bed=$bed; End=$end; Key=$bed.ToString('yyyy-MM-dd')}
}
