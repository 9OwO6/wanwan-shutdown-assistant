# 早睡打卡：每晚一个结果，纯函数，便于脱离界面测试。
# slept     到点后晚晚成功请求了关机/睡眠
# early     截止前电脑就已经关了/睡了（晚晚最后一次运行早于截止时间）
# caught    睡眠守护期间又开机/唤醒，被晚晚发现
# late      晚晚一直运行过了截止时间，却没有完成关机/睡眠
# cancelled 当晚用“紧急取消”；不计入也不打断连续天数
$script:NightResultRank=@{early=1;slept=1;late=2;caught=3;cancelled=4}

function Set-NightResult {
    # 同一晚只升级不降级：被发现起夜后，再成功关机也仍记为 caught。
    param([hashtable]$Nights, [string]$Key, [string]$Result)
    $old = $Nights[$Key]
    if (-not $old -or $script:NightResultRank[$Result] -gt $script:NightResultRank[$old]) { $Nights[$Key] = $Result; return $true }
    return $false
}

function Get-PastNights {
    # 最近 $Count 个已经结束（守护区间已过）的夜晚，新到旧。
    param([datetime]$Now, $Config, [int]$Count = 14)
    $list = @()
    foreach ($offset in 0..($Count + 2)) {
        $bed = Get-NightBedtime $Now.Date.AddDays(-$offset) $Config
        $windowEnd = Get-NightWindowEnd $bed $Config
        if ($windowEnd -le $Now) { $list += [pscustomobject]@{Key=$bed.ToString('yyyy-MM-dd'); Bed=$bed; End=$bed.AddMinutes([int]$Config.Grace); WindowEnd=$windowEnd} }
        if ($list.Count -ge $Count) { break }
    }
    return $list
}

function Resolve-NightHistory {
    # 补记“晚晚没有亲眼看到结果”的夜晚：从 LastSeen 到 Now 之间结束的每一晚。
    # LastSeen 早于截止时间 = 电脑在截止前已经关了/睡了 -> early；否则 -> late。
    param([hashtable]$Nights, [datetime]$LastSeen, [datetime]$Now, $Config)
    $changed = @()
    if ($LastSeen -eq [datetime]::MinValue -or -not $Config.Enabled) { return $changed }
    foreach ($night in Get-PastNights $Now $Config 14) {
        if ($night.WindowEnd -le $LastSeen) { break }
        if ($Nights.ContainsKey($night.Key)) { continue }
        $result = if ($LastSeen -lt $night.End) { 'early' } else { 'late' }
        $Nights[$night.Key] = $result; $changed += $night.Key
    }
    return $changed
}

function Get-SleepStreak {
    # 从最近结束的一晚往回数连续的 slept/early；cancelled 跳过，其他结果或空白中断。
    param([hashtable]$Nights, [datetime]$Now, $Config)
    $streak = 0
    foreach ($night in Get-PastNights $Now $Config 60) {
        $r = $Nights[$night.Key]
        if ($r -in @('slept', 'early')) { $streak++ }
        elseif ($r -eq 'cancelled') { continue }
        else { break }
    }
    return $streak
}

function Get-RecentNightMarks {
    # 最近 7 晚，旧到新：● 按时  ○ 熬夜/被发现/没有记录  ◐ 紧急取消
    param([hashtable]$Nights, [datetime]$Now, $Config)
    $marks = @(foreach ($night in (Get-PastNights $Now $Config 7)) {
        switch ($Nights[$night.Key]) { 'slept' {'●'} 'early' {'●'} 'cancelled' {'◐'} default {'○'} }
    })
    [array]::Reverse($marks)
    return ($marks -join ' ')
}
