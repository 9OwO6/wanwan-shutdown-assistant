# 起夜监督、早睡打卡和检查更新的界面逻辑。纯计算在 Schedule.ps1 / History.ps1 / UpdateCore.ps1。
. "$PSScriptRoot\History.ps1"
. "$PSScriptRoot\UpdateCore.ps1"

# 起夜监督和早上问候的台词见 Persona.ps1（Get-WatchLine / Say-WatchLine）。

# ---------- 早睡打卡记录 ----------
$script:historyFile=Join-Path $data 'history.json'
$script:nights=@{};$script:lastSeen=[datetime]::MinValue;$script:lastSeenSaved=[datetime]::MinValue
if(Test-Path $script:historyFile){
 try{
  $saved=Get-Content $script:historyFile -Raw -Encoding UTF8|ConvertFrom-Json
  foreach($p in $saved.nights.PSObject.Properties){$script:nights[$p.Name]=[string]$p.Value}
  if($saved.lastSeen){$script:lastSeen=[datetime]::Parse($saved.lastSeen,[cultureinfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind)}
 }catch{Write-Event ('History unreadable: '+$_.Exception.Message)}
}
function Save-History {
 # 只保留最近 120 晚。
 $keep=[ordered]@{};foreach($k in @($script:nights.Keys|Sort-Object -Descending|Select-Object -First 120)){$keep[$k]=$script:nights[$k]}
 [pscustomobject]@{lastSeen=$script:lastSeen.ToString('o');nights=$keep}|ConvertTo-Json -Depth 4|Set-Content $script:historyFile -Encoding UTF8
 $script:lastSeenSaved=$script:lastSeen
}
function Set-TonightResult([string]$Key,[string]$Result){
 if(Set-NightResult $script:nights $Key $Result){Save-History;Write-Event ("Night $Key recorded as $Result");Update-StreakDisplay}
}
function Update-StreakDisplay([datetime]$Now=(Get-Date)){
 $streak=Get-SleepStreak $script:nights $Now $cfg
 $marks=Get-RecentNightMarks $script:nights $Now $cfg
 $ui.StreakText.Text=if(-not $cfg.Enabled -and -not $script:nights.Count){'开启守护后，晚晚帮你记录早睡'}elseif($streak -gt 0){"☆ 已连续早睡 $streak 天   $marks"}else{"☆ 早睡打卡   $marks"}
 $ui.StreakText.ToolTip='最近 7 晚（旧→新）：● 按时睡觉  ○ 熬夜或半夜又起来  ◐ 紧急取消（不打断连续天数）'
 $script:currentStreak=$streak
}
function Invoke-HistoryTick([datetime]$Now,[string]$Phase='Day'){
 # 用上一次“看到电脑开着”的时间判断刚结束的夜晚：之前就关机/睡眠 = 早睡，一直开着 = 熬夜。
 $changed=Resolve-NightHistory $script:nights $script:lastSeen $Now $cfg
 $script:lastSeen=$Now
 if($changed.Count){Save-History;Write-Event ('Nights resolved: '+($changed -join ','));Update-StreakDisplay $Now}
 elseif(($Now-$script:lastSeenSaved).TotalSeconds -ge 60 -or $Now -lt $script:lastSeenSaved){Save-History}
 # 早上第一次见面：报告昨晚的结果（每晚只报一次，下午之后不再补报）。
 if(-not $cfg.Enabled -or $Phase -notin @('Day','Quiet') -or ($script:isTestMode -and -not $script:allowGreetingInTests)){return}
 $last=@(Get-PastNights $Now $cfg 1)|Select-Object -First 1
 if(-not $last -or $cfg.GreetedNight -eq $last.Key){return}
 $result=$script:nights[$last.Key]
 if(-not $result){return}
 $cfg.GreetedNight=$last.Key;Save-Config;Update-StreakDisplay $Now
 if($result -eq 'cancelled' -or $Now.Hour -ge 15 -or $Now -gt $last.WindowEnd.AddHours(10)){return}
 Show-MorningGreeting $result $Now
}
function Show-MorningGreeting([string]$Result,[datetime]$Now=(Get-Date)){
 $good=$Result -in @('slept','early')
 $line=Say-WatchLine $(if($good){'streak'}else{'reset'})
 $streak=Get-SleepStreak $script:nights $Now $cfg
 $caption=if($good){$line.text+"`n已经连续早睡 $streak 天啦 ☆"}else{$line.text}
 if(-not $script:dialog){Show-DesktopPet $caption '晚晚 · 早睡打卡';Extend-DesktopPetLifetime}
 Write-Event ('Morning greeting: '+$Result+'; streak='+$streak)
}

# ---------- 起夜监督 ----------
function Enter-CaughtMode([datetime]$Now,[switch]$Quiet){
 # 守护区间内又开机/唤醒：给 WakeGrace 分钟处理急事，然后再次关机或睡眠。
 $state=Get-NightState $Now $cfg
 $minutes=[math]::Max(1,[int]$cfg.WakeGrace)
 $script:deadline=$Now.AddMinutes($minutes);$script:shutdownAfter=$null;$script:caughtMode=$true;$script:lastAttempt=[datetime]::MinValue
 $count=if($cfg.CaughtNight -eq $state.Key){[int]$cfg.CaughtCount+1}else{1}
 $cfg.CaughtNight=$state.Key;$cfg.CaughtCount=$count;Save-Config
 Set-TonightResult $state.Key 'caught'
 $d=$script:dialog
 $d.FindName('Headline').Text='嘘，现在是睡觉时间～'
 $d.FindName('ReminderTime').Text='起夜监督 · '+$Now.ToString('HH:mm')
 $d.FindName('Safety').Text="真的有急事就点下面的「今晚真的有急事」：今晚不再监督，明天照常。否则 $minutes 分钟后晚晚会再帮你"+(Get-GuardActionName)+'。'
 $d.FindName('Acknowledge').Content='好嘛，我这就去睡 ♡'
 $d.FindName('Defer').Visibility=[Windows.Visibility]::Collapsed
 $d.FindName('CancelNight').Content='今晚真的有急事，取消监督…'
 $d.FindName('MiniStatus').Text='被发现啦，快去睡觉 ♡'
 if(-not $d.IsVisible){Set-CountdownView Expanded}
 Update-CountdownText $Now|Out-Null
 if(-not $Quiet){$line=Say-WatchLine $(if($count -gt 1){'caught-again'}else{'caught'});$d.FindName('Info').Text=$line.text}
 Write-Event ("Caught awake during the sleep window (#$count); grace=$minutes min")
}

# ---------- 检查更新 ----------
$script:appVersion=if(Test-Path (Join-Path $root 'VERSION')){(Get-Content (Join-Path $root 'VERSION') -Raw).Trim()}else{'0.0.0'}
$script:updateJob=$null;$script:updateRelease=$null;$script:updateManual=$false;$script:updateStage='idle'
$script:updateTimer=New-Object Windows.Threading.DispatcherTimer;$script:updateTimer.Interval=[timespan]::FromMilliseconds(400)
function Start-UpdateCheck([switch]$Manual){
 if($script:updateStage -in @('checking','downloading')){if($Manual){$ui.Feedback.Text='正在处理更新，请稍等…'};return}
 $script:updateManual=[bool]$Manual;$script:updateStage='checking'
 if($Manual){$ui.Feedback.Text='正在检查新版本…'}
 $script:updateJob=Start-BackgroundWork $script:UpdateCheckWork @($script:UpdateApi);$script:updateTimer.Start()
 $cfg.LastUpdateCheck=(Get-Date).ToString('o');Save-Config
}
function Request-UpdateInstall {
 $release=$script:updateRelease;$asset=Select-UpdateAsset $release
 if(-not $asset){$ui.Feedback.Text='新版本暂时没有可下载的安装包';return}
 $size=[math]::Round($asset.size/1MB,1)
 $text="发现新版本 $($release.tag_name)（当前 v$script:appVersion）`n`n$(Get-UpdateSummary $release)`n`n现在下载并安装吗？约 $size MB。设置和打卡记录都会保留，晚晚会自动重启。"
 $answer=[Windows.MessageBox]::Show($text,'晚晚 · 检查更新','YesNo','Information')
 if($answer -ne 'Yes'){$ui.Feedback.Text='好的，之后可以随时点「检查更新」';return}
 $script:updateStage='downloading';$ui.Feedback.Text="正在下载 $($release.tag_name)（$size MB）…"
 $work=Join-Path ([IO.Path]::GetTempPath()) 'WanwanUpdate'
 $script:updateJob=Start-BackgroundWork $script:UpdateDownloadWork @($asset.browser_download_url,[string]$asset.digest,$work);$script:updateTimer.Start()
 Write-Event ('Update download started: '+$asset.browser_download_url)
}
function Install-DownloadedUpdate([string]$Source){
 # 把安装脚本复制到临时目录运行，它会等晚晚退出、覆盖文件、再重新打开晚晚。
 $runner=Join-Path ([IO.Path]::GetTempPath()) 'WanwanUpdate\ApplyUpdate.ps1'
 New-Item -ItemType Directory -Force (Split-Path -Parent $runner)|Out-Null
 # 优先用新版本自带的安装脚本，这样安装逻辑的改进能在这次更新里就生效。
 $installer=Join-Path $Source 'app\ApplyUpdate.ps1';if(-not (Test-Path -LiteralPath $installer)){$installer=Join-Path $PSScriptRoot 'ApplyUpdate.ps1'}
 Copy-Item -LiteralPath $installer -Destination $runner -Force
 $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',('"'+$runner+'"'),'-WaitPid',$PID,'-Source',('"'+$Source+'"'),'-Target',('"'+$root+'"'),'-LogFile',('"'+(Join-Path $data 'update.log')+'"'))
 if($script:dialog -and -not $script:demoMode){$arguments+=@('-ResumeDeadline',('"'+$script:deadline.ToString('o')+'"'))}
 Write-Event 'Update downloaded and verified; restarting to install'
 if($script:isTestMode){$script:testUpdateArguments=$arguments;return}
 Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $arguments -WindowStyle Hidden
 $script:quitting=$true;if($script:dialog){$script:dialog.Close()};$win.Close()
}
$script:updateTimer.Add_Tick({
 $outcome=Receive-BackgroundWork $script:updateJob
 if(-not $outcome.Done){return}
 $script:updateTimer.Stop()
 if($script:updateStage -eq 'checking'){
  $script:updateStage='idle'
  if($outcome.Error -or -not $outcome.Result){if($script:updateManual){$ui.Feedback.Text='暂时连不上 GitHub，稍后再试试吧'};Write-Event ('Update check failed: '+$outcome.Error);return}
  $script:updateRelease=$outcome.Result
  if(Test-NewerRelease $script:appVersion $outcome.Result.tag_name){
   $ui.CheckUpdate.Content="有新版本 $($outcome.Result.tag_name) ↑";$ui.CheckUpdate.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#A7778B');$ui.CheckUpdate.Foreground=[Windows.Media.Brushes]::White
   if($script:updateManual){Request-UpdateInstall}else{$tray.ShowBalloonTip(4000,'晚晚有新版本啦',"$($outcome.Result.tag_name) 已发布，打开晚晚点「有新版本」即可一键更新。",[System.Windows.Forms.ToolTipIcon]::Info)}
  }elseif($script:updateManual){$ui.Feedback.Text="已经是最新版本 v$script:appVersion ♡"}
 }elseif($script:updateStage -eq 'downloading'){
  $script:updateStage='idle'
  if($outcome.Error -or -not $outcome.Result){$ui.Feedback.Text='下载更新失败：'+$outcome.Error;Write-Event ('Update download failed: '+$outcome.Error);return}
  $ui.Feedback.Text='下载完成，晚晚马上重启完成更新…';Install-DownloadedUpdate $outcome.Result.Source
 }
})
$ui.CheckUpdate.Add_Click({if($script:updateRelease -and (Test-NewerRelease $script:appVersion $script:updateRelease.tag_name)){Request-UpdateInstall}else{Start-UpdateCheck -Manual}})
$win.Add_Closed({$script:updateTimer.Stop()})
