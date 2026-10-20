# 桌宠的日常：隔一阵做一个小动作，越接近睡觉时间越困。
# 打开「晚晚陪伴」后，还会看你在用哪一类程序（只看进程名）和有没有在操作电脑，跟着你做事、你离开时趴下睡。
. "$PSScriptRoot\BehaviorCore.ps1"
Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace Wanwan {
 public static class Activity {
  [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO info);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  public static double IdleSeconds() {
   LASTINPUTINFO info = new LASTINPUTINFO(); info.cbSize = (uint)Marshal.SizeOf(info);
   if (!GetLastInputInfo(ref info)) return 0;
   return unchecked((uint)Environment.TickCount - info.dwTime) / 1000.0;
  }
 }
}
'@
$script:activityRules=Get-Content (Join-Path $root 'assets\activity-rules.json') -Raw -Encoding UTF8|ConvertFrom-Json
$script:behaviorRandom=[Random]::new()
$script:petBehavior=@{Last='';NextAt=(Get-Date).AddSeconds(45);Away=$false;Activity='none';LastBack=[datetime]::MinValue}
$script:restPose=$null
# 测试时可以注入：$script:activityOverride=@{Process='vlc';Fullscreen=$false}；$script:idleOverride=秒数。
$script:activityOverride=$null;$script:idleOverride=$null

function Get-IdleSeconds {if($null -ne $script:idleOverride){return [double]$script:idleOverride};try{[Wanwan.Activity]::IdleSeconds()}catch{0}}
function Get-ForegroundActivity {
 if($script:activityOverride){return @{Process=$script:activityOverride.Process;Fullscreen=[bool]$script:activityOverride.Fullscreen;Category=(Get-ActivityCategory $script:activityOverride.Process ([bool]$script:activityOverride.Fullscreen) $script:activityRules)}}
 try{
  $handle=[Wanwan.Activity]::GetForegroundWindow();if($handle -eq [IntPtr]::Zero){return @{Process='';Fullscreen=$false;Category='none'}}
  $processId=[uint32]0;[Wanwan.Activity]::GetWindowThreadProcessId($handle,[ref]$processId)|Out-Null
  if($processId -eq $PID){return @{Process='wanwan';Fullscreen=$false;Category='none'}}
  $name=(Get-Process -Id $processId -ErrorAction Stop).ProcessName
  $rect=[Wanwan.Activity+RECT]::new();[Wanwan.Activity]::GetWindowRect($handle,[ref]$rect)|Out-Null
  $screen=[Windows.Forms.Screen]::FromHandle($handle).Bounds
  $fullscreen=($rect.Left -le $screen.Left -and $rect.Top -le $screen.Top -and $rect.Right -ge $screen.Right -and $rect.Bottom -ge $screen.Bottom)
  return @{Process=$name;Fullscreen=$fullscreen;Category=(Get-ActivityCategory $name $fullscreen $script:activityRules)}
 }catch{return @{Process='';Fullscreen=$false;Category='none'}}
}
function Get-CompanionBedtimeCue {
 # 到点时你还在打游戏 / 看视频 / 工作：换成对应的那句（只在「晚晚陪伴」打开时）。
 if(-not $cfg.Companion){return ''}
 $category=(Get-ForegroundActivity).Category
 if($category -in @('game','video','work')){return 'companion-'+$category}
 return ''
}
function Start-PetBehavior([string]$Behavior){
 # 安静地做一个动作：不改主窗口文字、不弹气泡、不说整句。
 $id=Get-BehaviorAnimation $Behavior @($script:interactionAssets.Keys)
 $item=$script:interactionCatalog|Where-Object id -eq $id|Select-Object -First 1
 if(-not $item){return}
 $script:action=@{Item=$item;Start=$script:animationClock.ElapsedMilliseconds;End=$script:animationClock.ElapsedMilliseconds+($item.frames.Count*$item.step);Caption=''}
 $script:petBehavior.Last=$Behavior;$script:petBehavior.LastAnimation=$id
 $script:actionHistory.Add(@{id=$id;behavior=$Behavior;popup=$false;time=$script:animationClock.ElapsedMilliseconds})
 if($script:actionHistory.Count -gt 100){$script:actionHistory.RemoveAt(0)}
}
function Update-PetBehavior([datetime]$Now=(Get-Date)){
 # 提醒、倒计时或语音进行中时不打扰。
 if($script:dialog -or $script:petExpanded -or ($script:voiceUntil -and $Now -lt $script:voiceUntil)){return}
 $bed=(Get-NightState $Now $cfg).Bed
 $sleepiness=Get-Sleepiness $Now $bed
 $away=[bool]($cfg.Companion -and (Get-IdleSeconds) -ge 600)
 $activity=if($cfg.Companion){(Get-ForegroundActivity).Category}else{'none'}
 $wasAway=$script:petBehavior.Away
 $script:petBehavior.Away=$away;$script:petBehavior.Activity=$activity;$script:petBehavior.Sleepiness=$sleepiness
 if($away){
  # 你离开了：趴下睡着，保持睡姿。
  if(-not $wasAway){Start-PetBehavior 'sleep';$script:restPose=@{Id=(Get-BehaviorAnimation 'sleep' @($script:interactionAssets.Keys));Frame=2}}
  return
 }
 if($wasAway){
  # 你回来了：醒过来，半小时内只打一次招呼。
  $script:restPose=$null
  if(($Now-$script:petBehavior.LastBack).TotalMinutes -ge 30){$script:petBehavior.LastBack=$Now;Say-Cue back}else{Start-PetBehavior 'peek'}
  $script:petBehavior.NextAt=$Now.AddSeconds((Get-NextBehaviorDelay $sleepiness $script:behaviorRandom));return
 }
 if($Now -lt $script:petBehavior.NextAt){return}
 $behavior=Select-PetBehavior @{Sleepiness=$sleepiness;Away=$false;Activity=$activity;Companion=[bool]$cfg.Companion;Last=$script:petBehavior.Last} $script:behaviorRandom
 Start-PetBehavior $behavior
 # 已经过了睡觉时间还在打哈欠：偶尔出声。
 if($behavior -eq 'yawn' -and $sleepiness -ge 3 -and $cfg.Voice -and $script:behaviorRandom.Next(0,3) -eq 0){Invoke-Gesture yawn}
 $script:petBehavior.NextAt=$Now.AddSeconds((Get-NextBehaviorDelay $sleepiness $script:behaviorRandom))
}
$script:behaviorTimer=[Windows.Threading.DispatcherTimer]::new();$script:behaviorTimer.Interval=[timespan]::FromSeconds(5)
$script:behaviorTimer.Add_Tick({try{Update-PetBehavior}catch{}})
