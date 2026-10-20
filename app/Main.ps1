param([switch]$SmokeTest,[switch]$InteractionTest,[switch]$AnimationTest,[switch]$VoiceTest,[switch]$CompanionTest,[switch]$DialogueTest,[switch]$PetTest,[switch]$GuardTest,[switch]$LifecycleTest,[switch]$PetControlsTest,[switch]$ShowcaseTest,[switch]$CountdownTest,[switch]$WatchTest,[switch]$BehaviorTest,[datetime]$ResumeCountdownDeadline=[datetime]::MinValue)
$ErrorActionPreference='Stop'
$script:isTestMode=[bool]($SmokeTest -or $InteractionTest -or $AnimationTest -or $VoiceTest -or $CompanionTest -or $DialogueTest -or $PetTest -or $GuardTest -or $LifecycleTest -or $PetControlsTest -or $ShowcaseTest -or $CountdownTest -or $WatchTest -or $BehaviorTest)
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing,System.Speech
. "$PSScriptRoot\Schedule.ps1"
$root = Split-Path $PSScriptRoot
. "$PSScriptRoot\Icons.ps1"
$script:instanceMutex=$null
$script:openSignal=$null
if(-not $script:isTestMode){
 $script:openSignal=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::AutoReset,'Local\WanwanShutdownAssistant.Open')
 $created=$false;$script:instanceMutex=[Threading.Mutex]::new($true,'Local\WanwanShutdownAssistant',[ref]$created)
 if(-not $created){$script:openSignal.Set()|Out-Null;$script:openSignal.Dispose();$script:instanceMutex.Dispose();exit}
}
$data = Join-Path $env:LOCALAPPDATA 'WanwanShutdown'
New-Item -ItemType Directory -Force $data | Out-Null
$configFile=Join-Path $data 'settings.json'
$script:cfg=@{Bedtime='23:30';WeekendBedtime='';Action='Shutdown';SleepHours=6;WakeGrace=5;AutoUpdate=$true;GuardedNight='';GreetedNight='';CaughtNight='';CaughtCount=0;Grace=10;Nickname='';Voice=$true;VoicePreset='Recorded';Persona='girlfriend';Address='baobao';Companion=$false;DesktopPet=$true;Enabled=$false;Cancelled='';Deferred=''}
if(Test-Path $configFile){try{$saved=Get-Content $configFile -Raw -Encoding UTF8|ConvertFrom-Json; foreach($p in $saved.PSObject.Properties){$script:cfg[$p.Name]=$p.Value}}catch{}}
if($script:isTestMode){$configFile=Join-Path $root 'output\isolated-test-settings.json';$data=Join-Path $root 'output\isolated-test-data';New-Item -ItemType Directory -Force $data|Out-Null}
if($ShowcaseTest){$script:cfg=@{Bedtime='23:30';WeekendBedtime='01:00';Action='Shutdown';SleepHours=6;WakeGrace=5;AutoUpdate=$true;GuardedNight='';GreetedNight='';CaughtNight='';CaughtCount=0;Grace=10;Nickname='';Voice=$false;VoicePreset='Recorded';Persona='girlfriend';Address='baobao';Companion=$false;DesktopPet=$true;Enabled=$false;Cancelled='';Deferred=''}}
function Save-Config { $script:cfg|ConvertTo-Json|Set-Content $configFile -Encoding UTF8 }
function Get-GuardActionName { if($script:cfg.Action -eq 'Sleep'){'睡眠'}else{'关机'} }
function Set-LauncherShortcut([string]$Path){
 # 直接以隐藏窗口启动 PowerShell，不依赖正在被 Windows 淘汰的 VBScript。
 $shortcut=(New-Object -ComObject WScript.Shell).CreateShortcut($Path)
 $shortcut.TargetPath=Join-Path $PSHOME 'powershell.exe'
 $shortcut.Arguments='-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+(Join-Path $root 'app\Main.ps1')+'"'
 $shortcut.WorkingDirectory=$root;$shortcut.WindowStyle=7;$shortcut.IconLocation=(Join-Path $root 'assets\icons\wanwan.ico')+',0';$shortcut.Description='晚晚 · 睡前陪伴与到点关机/睡眠';$shortcut.Save()
}
$script:synth=New-Object System.Speech.Synthesis.SpeechSynthesizer
$voice=$script:synth.GetInstalledVoices()|Where-Object {$_.VoiceInfo.Culture.Name -eq 'zh-CN' -and $_.VoiceInfo.Gender -eq 'Female'}|Select-Object -Last 1
if($voice){$script:synth.SelectVoice($voice.VoiceInfo.Name)}
$script:synth.Rate=-2; $script:synth.Volume=80
function Say([string]$message){if($script:cfg.Voice){$script:synth.SpeakAsyncCancelAll();$script:synth.SpeakAsync($message)|Out-Null}}
[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="晚晚 · 关机助理" Width="1080" Height="800" MinWidth="940" MinHeight="780" WindowStartupLocation="CenterScreen" Background="#FFF7FA" FontFamily="Microsoft YaHei UI" Foreground="#363138">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Cursor" Value="Hand"/><Setter Property="Padding" Value="20,12"/><Setter Property="Background" Value="#EFE7E2"/><Setter Property="Foreground" Value="#54454C"/><Setter Property="BorderThickness" Value="0"/><Setter Property="FontSize" Value="14"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="b" CornerRadius="14" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.82"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.65"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.4"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
  <Style TargetType="TextBox"><Setter Property="Padding" Value="12,10"/><Setter Property="FontSize" Value="15"/><Setter Property="BorderBrush" Value="#DED4D1"/><Setter Property="Background" Value="#FFFCFA"/></Style>
 </Window.Resources>
 <Grid Margin="26"><Grid.ColumnDefinitions><ColumnDefinition Width="0.95*"/><ColumnDefinition Width="1.2*"/></Grid.ColumnDefinitions>
  <Border Grid.Column="0" CornerRadius="24" ClipToBounds="True" Margin="0,0,24,0">
   <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#E9D7DF" Offset="0"/><GradientStop Color="#99808F" Offset="0.65"/><GradientStop Color="#564759" Offset="1"/></LinearGradientBrush></Border.Background>
   <Grid><Image x:Name="Portrait" Height="400" Margin="0,42,0,0" Stretch="Uniform" VerticalAlignment="Top" Cursor="Hand" ToolTip="轻轻点一下晚晚，收下一个小动作"/><Image x:Name="PortraitFade" Height="400" Margin="0,42,0,0" Stretch="Uniform" VerticalAlignment="Top" IsHitTestVisible="False" Opacity="0"/><Canvas x:Name="Stars" IsHitTestVisible="False" VerticalAlignment="Top" Height="180"/><Border VerticalAlignment="Top" HorizontalAlignment="Left" Margin="22" Background="#993D3341" CornerRadius="14" Padding="14,9"><TextBlock x:Name="Mood" Text="✦  晚晚在你身边" Foreground="#FFF1E7" FontSize="12"/></Border>
    <Border VerticalAlignment="Top" Margin="22,450,22,0" Background="#22FFF2F8" CornerRadius="20" Padding="18"><StackPanel><TextBlock Text="♡  点点我，收下一点小温柔" Foreground="#FFF1F7" FontSize="15"/><TextBlock Text="探头  ·  拍一拍  ·  给你一颗心" Foreground="#E8D5DF" FontSize="12" Margin="0,10,0,0"/></StackPanel></Border><StackPanel VerticalAlignment="Bottom" Margin="28,0,28,32"><TextBlock Text="WANWAN / 晚晚" Foreground="#F2DED4" FontSize="12"/><TextBlock Text="夜深了，&#10;早点休息吧。" Foreground="White" FontSize="32" Margin="0,12,0,12"/><TextBlock Text="把今天轻轻放下，明天再继续。" Foreground="#F1E2DE" FontSize="13"/></StackPanel>
   </Grid>
  </Border>
  <Grid Grid.Column="1"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
   <DockPanel Margin="0,8,0,20"><TextBlock Text="☾  关机助理" FontSize="19" FontWeight="SemiBold" VerticalAlignment="Center"/><Button x:Name="OpenSettings" DockPanel.Dock="Right" Content="⚙  设置" FontSize="13" Padding="14,8" Margin="14,0,0,0" ToolTip="睡觉时间、到点关机或睡眠、起夜监督、声音和桌宠"/><TextBlock x:Name="Clock" Text="" HorizontalAlignment="Right" VerticalAlignment="Center" Foreground="#8A7E85" FontSize="14"/></DockPanel>
   <StackPanel Grid.Row="1">
    <TextBlock Text="今晚的约定" Foreground="#9B7B88" FontSize="12" Margin="0,8,0,10"/>
    <TextBlock x:Name="Headline" Text="早点睡，是给自己的温柔。" FontSize="28" FontWeight="SemiBold" TextWrapping="Wrap"/>
    <TextBlock x:Name="Message" Text="忙了一天，辛苦啦。我们约个时间，慢慢收尾，然后安心休息。" TextWrapping="Wrap" FontSize="15" Foreground="#81727B" LineHeight="26" Margin="0,14,0,22"/>
    <Border Background="#FFFFFF" CornerRadius="20" Padding="22" Margin="0,0,0,18"><StackPanel>
     <DockPanel><TextBlock Text="今晚休息时间" Foreground="#95868E"/><TextBlock x:Name="ModeLabel" Text="守护未开启" HorizontalAlignment="Right" Foreground="#A47C8B"/></DockPanel>
     <TextBlock x:Name="TimeDisplay" Text="23:30" FontSize="46" Margin="0,8,0,3"/>
     <TextBlock x:Name="Countdown" Text="我会提前半小时轻轻提醒你" Foreground="#95868E"/>
     <ProgressBar x:Name="Progress" Height="4" Margin="0,16,0,0" Maximum="100" Value="0" Foreground="#BE91A1" Background="#F2EBEE" BorderThickness="0"/><DockPanel Margin="0,12,0,0"><TextBlock x:Name="StreakText" DockPanel.Dock="Right" Text="" Foreground="#A47C8B" FontSize="12"/><TextBlock x:Name="VoiceBadge" Text="♫  选一个喜欢的声音" Foreground="#AD8B9C" FontSize="12"/></DockPanel>
    </StackPanel></Border>
    <WrapPanel Margin="0,0,0,14"><Button x:Name="Preview" Content="♡  听听晚晚的提醒" Background="#A7778B" Foreground="White" Margin="0,0,10,8"/><Button x:Name="Demo" Content="体验睡前倒计时" Margin="0,0,10,8"/><Button x:Name="Interactions" Content="♡ 互动小剧场" Margin="0,0,0,8"/></WrapPanel>
    <Border Background="#F6E8EE" CornerRadius="16" Padding="18,14"><DockPanel><Button x:Name="GuardSwitch" DockPanel.Dock="Right" Content="开启到点守护" Padding="14,9" Background="#A7778B" Foreground="White" Margin="14,0,0,0" VerticalAlignment="Center"/><StackPanel VerticalAlignment="Center"><TextBlock x:Name="GuardSummary" Text="" Foreground="#6E5A64" FontSize="13" TextWrapping="Wrap" LineHeight="21"/><TextBlock x:Name="Feedback" Text="" Foreground="#8A6878" FontSize="12" Margin="0,4,0,0" TextWrapping="Wrap"/></StackPanel></DockPanel></Border>
    <Border Background="#FFFFFF" CornerRadius="16" Padding="18,12" Margin="0,12,0,0"><StackPanel><TextBlock Text="今晚的节奏" Foreground="#95868E" FontSize="12" Margin="0,0,0,6"/><UniformGrid x:Name="Timeline" Columns="4"/></StackPanel></Border>
   </StackPanel>
   <DockPanel Grid.Row="2" Margin="0,16,0,0"><TextBlock x:Name="FooterText" Text="本地运行 · 不上传数据" Foreground="#A3979D" FontSize="11" VerticalAlignment="Center"/><Button x:Name="PetPreview" Content="桌宠提醒体验 ♡" FontSize="11" Padding="8,6" Margin="10,0,6,0"/><Button x:Name="CheckUpdate" Content="检查更新" FontSize="11" Padding="8,6" Margin="0,0,8,0" ToolTip="从 GitHub 检查并一键安装新版本；设置和打卡记录会保留"/><Button x:Name="Hide" Content="收起到托盘 ↗" FontSize="11" Padding="8,6" HorizontalAlignment="Right"/></DockPanel>
  </Grid>
 </Grid>
</Window>
'@
$reader=New-Object System.Xml.XmlNodeReader $xaml
$script:win=[Windows.Markup.XamlReader]::Load($reader)
Set-WanwanIcon $script:win
[xml]$settingsXaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="晚晚 · 设置" Width="640" SizeToContent="Height" ResizeMode="NoResize" WindowStartupLocation="CenterOwner" ShowInTaskbar="False" Background="#FFF7FA" FontFamily="Microsoft YaHei UI" Foreground="#363138">
 <StackPanel Margin="28,24,28,24">
  <TextBlock Text="⚙  设置" FontSize="21" FontWeight="SemiBold"/>
  <TextBlock Text="改完点「保存」才会生效；声音、桌宠和动态开关会立即生效。" Foreground="#9B8B93" FontSize="12" Margin="0,6,0,4"/>
  <Border Background="#FFFFFF" CornerRadius="16" Padding="18" Margin="0,14,0,0"><StackPanel>
   <TextBlock Text="今晚的约定" Foreground="#9B7B88" FontSize="12" Margin="0,0,0,10"/>
   <Grid><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
      <StackPanel Margin="0,0,10,0"><TextBlock Text="睡觉时间" Margin="0,0,0,7" Foreground="#87767F"/><TextBox x:Name="BedInput" Text="23:30" MaxLength="5"/></StackPanel>
      <StackPanel Grid.Column="1" Margin="0,0,10,0"><TextBlock Text="周五六晚" Margin="0,0,0,7" Foreground="#87767F" ToolTip="周五、周六晚上的睡觉时间；留空则与平时相同。例如 01:00 表示周六、周日凌晨一点。"/><TextBox x:Name="WeekendInput" Text="" MaxLength="5" ToolTip="留空 = 和平时一样；例如 00:30 或 01:00"/></StackPanel>
      <StackPanel Grid.Column="2" Margin="0,0,10,0"><TextBlock Text="收尾分钟" Margin="0,0,0,7" Foreground="#87767F"/><TextBox x:Name="GraceInput" Text="10" MaxLength="2"/></StackPanel>
     </Grid>
   <WrapPanel Margin="0,10,0,0"><TextBlock Text="到点后" Foreground="#87767F" VerticalAlignment="Center" Margin="0,0,12,0"/><RadioButton x:Name="ActionShutdown" Content="正常关机" GroupName="GuardAction" IsChecked="True" VerticalAlignment="Center" Margin="0,0,16,0"/><RadioButton x:Name="ActionSleep" Content="睡眠（窗口和文件都保留）" GroupName="GuardAction" VerticalAlignment="Center" ToolTip="怕丢进度就选睡眠：到点让电脑进入睡眠，醒来一切都在。"/></WrapPanel>
   <WrapPanel Margin="0,12,0,0"><CheckBox x:Name="EnabledToggle" Content="到点自动守护" ToolTip="勾选并保存后生效；超过截止时间时先提醒保存，倒计时后按下方选择正常关机或睡眠。" Margin="0,0,22,8"/></WrapPanel>
  </StackPanel></Border>
  <Border Background="#FFFFFF" CornerRadius="16" Padding="18" Margin="0,12,0,0"><StackPanel>
   <TextBlock Text="起夜监督" Foreground="#9B7B88" FontSize="12" Margin="0,0,0,10"/>
   <WrapPanel ToolTip="睡后守护时间内重新开机或唤醒电脑，晚晚会出来催你回去睡觉，并留几分钟处理急事。需要勾选「开机自动启动」，晚晚才能在开机后出现。"><TextBlock Text="睡后" Foreground="#87767F" VerticalAlignment="Center"/><TextBox x:Name="SleepHoursInput" Text="6" MaxLength="2" Width="44" Padding="6,4" Margin="6,0" FontSize="13"/><TextBlock Text="小时内再开机，给" Foreground="#87767F" VerticalAlignment="Center"/><TextBox x:Name="WakeGraceInput" Text="5" MaxLength="2" Width="44" Padding="6,4" Margin="6,0" FontSize="13"/><TextBlock Text="分钟处理急事" Foreground="#87767F" VerticalAlignment="Center"/></WrapPanel>
   <TextBlock Text="需要同时打开下面的「开机自动启动」，晚晚才能在你重新开机后出现。" Foreground="#AA97A0" FontSize="11" Margin="0,8,0,0" TextWrapping="Wrap"/>
  </StackPanel></Border>
  <Border Background="#FFFFFF" CornerRadius="16" Padding="18" Margin="0,12,0,0"><StackPanel>
   <TextBlock Text="晚晚" Foreground="#9B7B88" FontSize="12" Margin="0,0,0,10"/>
   <WrapPanel><TextBlock Text="晚晚是你的" Foreground="#87767F" VerticalAlignment="Center" Margin="0,0,12,8"/><RadioButton x:Name="PersonaGirlfriend" Content="女友" GroupName="Persona" Margin="0,0,18,8" VerticalAlignment="Center" ToolTip="爱撒娇、黏人，清甜温柔的声音"/><RadioButton x:Name="PersonaSister" Content="姐姐" GroupName="Persona" Margin="0,0,18,8" VerticalAlignment="Center" ToolTip="成熟温柔、会照顾人，御姐声音"/><Button x:Name="VoicePreview" Content="▶ 试听" FontSize="12" Padding="10,5" Margin="0,0,0,8" ToolTip="用选中的性格和称呼读一句，不会保存"/></WrapPanel>
   <DockPanel Margin="0,4,0,4"><TextBlock Text="称呼" Foreground="#87767F" VerticalAlignment="Center" Margin="0,0,12,0"/><ComboBox x:Name="AddressInput" Width="200" FontSize="13" Padding="8,5" VerticalAlignment="Center"/><TextBox x:Name="NameInput" Text="" MaxLength="12" Width="140" Margin="10,0,0,0" Padding="8,5" FontSize="13" ToolTip="自定义名字会显示在提醒气泡里；选「系统朗读」时也会读出来"/></DockPanel>
   <TextBlock x:Name="AddressHint" Text="" Foreground="#AA97A0" FontSize="11" Margin="0,2,0,8" TextWrapping="Wrap"/>
   <WrapPanel><CheckBox x:Name="VoiceToggle" Content="说话" IsChecked="True" Margin="0,0,22,8" ToolTip="关掉后只显示文字和动作"/><CheckBox x:Name="VoiceSystem" Content="改用系统朗读" Margin="0,0,22,8" ToolTip="用 Windows 自带的中文语音朗读，自定义名字也能读出来"/><CheckBox x:Name="PetToggle" Content="显示桌宠" Margin="0,0,22,8"/><CheckBox x:Name="MotionToggle" Content="减少动态" Margin="0,0,22,8"/></WrapPanel>
   <CheckBox x:Name="CompanionToggle" Content="晚晚陪伴：根据你在做什么，晚晚跟着做" Margin="0,6,0,2" ToolTip="你看视频她一起看，打游戏她也玩，工作她就学习；你离开电脑她会趴下睡。"/>
   <TextBlock Text="只在这台电脑上判断你在用哪一类程序、有没有在操作电脑，不记录内容、不联网。默认关闭。" Foreground="#AA97A0" FontSize="11" Margin="22,0,0,0" TextWrapping="Wrap"/>
  </StackPanel></Border>
  <Border Background="#FFFFFF" CornerRadius="16" Padding="18" Margin="0,12,0,0"><StackPanel>
   <TextBlock Text="启动与更新" Foreground="#9B7B88" FontSize="12" Margin="0,0,0,10"/>
   <WrapPanel><CheckBox x:Name="StartupToggle" Content="开机自动启动" ToolTip="登录 Windows 后启动晚晚；是否自动关机由旁边的开关决定。" Margin="0,0,22,8"/><CheckBox x:Name="AutoUpdateToggle" Content="每天自动检查更新" Margin="0,0,22,8" ToolTip="只访问 GitHub 的发布信息；有新版本时由你决定是否安装"/></WrapPanel>
  </StackPanel></Border>
  <DockPanel Margin="0,18,0,0"><Button x:Name="Save" Content="保存" Padding="18,9" Background="#E3D5DB"/><Button x:Name="ArmGuard" Content="保存并开启守护" Padding="14,9" Margin="8,0,0,0" Background="#A7778B" Foreground="White" ToolTip="保存当前时间并开启到点守护。已超时会立即开始两分钟保存倒计时。"/><Button x:Name="CloseSettings" Content="关闭" DockPanel.Dock="Right" Padding="14,9"/><TextBlock x:Name="SettingsFeedback" Text="" Foreground="#8A6878" VerticalAlignment="Center" Margin="12,0,8,0" TextWrapping="Wrap"/></DockPanel>
 </StackPanel>
</Window>
'@
$script:settingsWin=[Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($settingsXaml))
$settingsWin.Resources.MergedDictionaries.Add($win.Resources);Set-WanwanIcon $settingsWin
# 主窗口只放今晚的状态和快捷操作；所有可改的约定都在「设置」窗口里。
$ui=@{}
foreach($n in 'Portrait','Clock','Headline','Message','ModeLabel','TimeDisplay','Countdown','Progress','Preview','Demo','Interactions','GuardSwitch','GuardSummary','Timeline','Feedback','Hide','StreakText','CheckUpdate','FooterText','OpenSettings','PetPreview'){$ui[$n]=$win.FindName($n)}
foreach($n in 'BedInput','WeekendInput','GraceInput','NameInput','VoiceToggle','PersonaGirlfriend','PersonaSister','VoiceSystem','CompanionToggle','VoicePreview','AddressInput','AddressHint','EnabledToggle','StartupToggle','PetToggle','MotionToggle','AutoUpdateToggle','ActionShutdown','ActionSleep','SleepHoursInput','WakeGraceInput','Save','ArmGuard','CloseSettings','SettingsFeedback'){$ui[$n]=$settingsWin.FindName($n)}
foreach($n in @($ui.Keys)){if(-not $ui[$n]){throw "Missing control: $n"}}
$startupFile=Join-Path ([Environment]::GetFolderPath('Startup')) '晚晚关机助理.lnk'
# 旧版本的开机快捷方式指向 wscript.exe + VBS；启动时静默迁移到直接调用 PowerShell。
if(-not $script:isTestMode -and (Test-Path $startupFile)){try{$existing=(New-Object -ComObject WScript.Shell).CreateShortcut($startupFile);if($existing.TargetPath -like '*wscript.exe'){Set-LauncherShortcut $startupFile}}catch{}}
$art=Join-Path $root 'assets\wanwan.png';if(Test-Path $art){$ui.Portrait.Source=[Windows.Media.Imaging.BitmapImage]::new([uri]$art)}
function Sync-SettingsForm {
 $ui.BedInput.Text=$cfg.Bedtime;$ui.WeekendInput.Text=[string]$cfg.WeekendBedtime;if($cfg.Action -eq 'Sleep'){$ui.ActionSleep.IsChecked=$true}else{$ui.ActionShutdown.IsChecked=$true};$ui.GraceInput.Text=[string]$cfg.Grace;$ui.SleepHoursInput.Text=[string]$cfg.SleepHours;$ui.WakeGraceInput.Text=[string]$cfg.WakeGrace;$ui.VoiceToggle.IsChecked=[bool]$cfg.Voice;$ui.EnabledToggle.IsChecked=[bool]$cfg.Enabled
 if($cfg.Persona -eq 'sister'){$ui.PersonaSister.IsChecked=$true}else{$ui.PersonaGirlfriend.IsChecked=$true}
 $ui.VoiceSystem.IsChecked=($cfg.VoicePreset -eq 'System');$ui.CompanionToggle.IsChecked=[bool]$cfg.Companion
 Fill-AddressItems $cfg.Persona;Select-AddressItem $cfg.Address;$ui.NameInput.Text=if($cfg.Address -eq 'custom'){[string]$cfg.Nickname}else{''};Update-AddressHint
 $ui.AutoUpdateToggle.IsChecked=[bool]$cfg.AutoUpdate;$ui.StartupToggle.IsChecked=Test-Path $startupFile
}
function Update-GuardSummary {
 $parts=@('平时 '+$cfg.Bedtime);if($cfg.WeekendBedtime){$parts+='周五六晚 '+$cfg.WeekendBedtime}
 $parts+=('到点'+(Get-GuardActionName));$parts+=('起夜监督 '+$cfg.SleepHours+' 小时')
 $ui.GuardSummary.Text=($parts -join ' · ')
 $bed=(Get-NightState (Get-Date) $cfg).Bed;$end=$bed.AddMinutes([int]$cfg.Grace)
 $steps=@(@($bed.AddMinutes(-30),'轻声提醒'),@($bed.AddMinutes(-10),'记得保存'),@($bed,'收尾 '+$cfg.Grace+' 分钟'),@($end,$(if($cfg.Enabled){'帮你'+(Get-GuardActionName)}else{'只提醒，不'+(Get-GuardActionName)})))
 $ui.Timeline.Children.Clear()
 foreach($step in $steps){$cell=[Windows.Controls.StackPanel]::new();$t=[Windows.Controls.TextBlock]::new();$t.Text=$step[0].ToString('HH:mm');$t.FontSize=17;$t.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#6E5A64');$l=[Windows.Controls.TextBlock]::new();$l.Text=$step[1];$l.FontSize=11;$l.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#A08C96');$l.Margin=[Windows.Thickness]::new(0,2,0,0);$cell.Children.Add($t)|Out-Null;$cell.Children.Add($l)|Out-Null;$ui.Timeline.Children.Add($cell)|Out-Null}
 $ui.GuardSwitch.Content=if($cfg.Enabled){'暂停守护'}else{'开启到点守护'}
 $ui.GuardSwitch.Background=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($cfg.Enabled){'#E3D5DB'}else{'#A7778B'}))
 $ui.GuardSwitch.Foreground=if($cfg.Enabled){[Windows.Media.BrushConverter]::new().ConvertFromString('#54454C')}else{[Windows.Media.Brushes]::White}
}
$script:lastPhase='';$script:dialog=$null;$script:demoMode=$false;$script:caughtMode=$false;$script:deadline=$null;$script:lastAttempt=[datetime]::MinValue
. "$PSScriptRoot\Visuals.ps1"
. "$PSScriptRoot\Voice.ps1"
. "$PSScriptRoot\Persona.ps1"
$script:voiceGapTimer.Interval=[timespan]::FromMilliseconds($script:personaScript.clock_pause_ms)
# 设置里的性格和称呼：称呼下拉框按所选性格列出（女友：宝宝 / 亲爱的；姐姐：小笨蛋），另有「不叫称呼」和「自定义名字」。
function Get-FormPersona {if($ui.PersonaSister.IsChecked){'sister'}else{'girlfriend'}}
function Fill-AddressItems([string]$Persona){
 $current=if($ui.AddressInput.SelectedItem){[string]$ui.AddressInput.SelectedItem.Tag}else{''}
 $ui.AddressInput.Items.Clear()
 $items=[ordered]@{};foreach($row in @($script:personas[$Persona].addresses)){$items[$row.id]=$row.label};$items['none']='不叫称呼';$items['custom']='自定义名字…'
 foreach($key in $items.Keys){$item=[Windows.Controls.ComboBoxItem]::new();$item.Tag=$key;$item.Content=$items[$key];$ui.AddressInput.Items.Add($item)|Out-Null}
 if($current -and $items.Contains($current)){Select-AddressItem $current}else{Select-AddressItem $script:personas[$Persona].default_address}
}
function Select-AddressItem([string]$Id){foreach($item in $ui.AddressInput.Items){if($item.Tag -eq $Id){$ui.AddressInput.SelectedItem=$item;return}};$ui.AddressInput.SelectedIndex=0}
function Get-FormAddress {if($ui.AddressInput.SelectedItem){[string]$ui.AddressInput.SelectedItem.Tag}else{'none'}}
function Update-AddressHint {
 $address=Get-FormAddress
 $ui.NameInput.IsEnabled=($address -eq 'custom');$ui.NameInput.Visibility=if($address -eq 'custom'){[Windows.Visibility]::Visible}else{[Windows.Visibility]::Collapsed}
 $ui.AddressHint.Text=if($address -eq 'custom' -and -not $ui.VoiceSystem.IsChecked){'自定义名字会显示在提醒气泡里；录音里不叫称呼。想听到名字，可以勾选「改用系统朗读」。'}elseif(-not (Test-PersonaBank (Get-FormPersona)) -and -not $ui.VoiceSystem.IsChecked){'这个性格的录音还没装好，暂时用系统朗读。'}else{''}
}
$ui.AddressInput.Add_SelectionChanged({Update-AddressHint})
$ui.PersonaGirlfriend.Add_Checked({Fill-AddressItems 'girlfriend';Update-AddressHint})
$ui.PersonaSister.Add_Checked({Fill-AddressItems 'sister';Update-AddressHint})
$ui.VoiceSystem.Add_Checked({Update-AddressHint});$ui.VoiceSystem.Add_Unchecked({Update-AddressHint})
$ui.VoicePreview.Add_Click({
 # 用表单里的性格和称呼读一句，读完不改设置。
 $saved=@{Voice=$cfg.Voice;VoicePreset=$cfg.VoicePreset;Address=$cfg.Address;Nickname=$cfg.Nickname;Persona=$cfg.Persona}
 $cfg.Voice=$true;$cfg.Persona=Get-FormPersona;$cfg.VoicePreset=if($ui.VoiceSystem.IsChecked){'System'}else{'Recorded'};$cfg.Address=Get-FormAddress;if($cfg.Address -eq 'custom'){$cfg.Nickname=$ui.NameInput.Text.Trim()}
 try{Say-Cue preview;$ui.SettingsFeedback.Text='试听：'+$script:lastSpokenLine.text}finally{foreach($key in $saved.Keys){$cfg[$key]=$saved[$key]}}
})
Sync-SettingsForm
. "$PSScriptRoot\DesktopPet.ps1"
. "$PSScriptRoot\CountdownView.ps1"
function Write-Event([string]$event){Add-Content (Join-Path $data 'events.log') ((Get-Date -Format o)+' '+$event) -Encoding UTF8}
. "$PSScriptRoot\Watch.ps1"
. "$PSScriptRoot\Behavior.ps1"
$ui.FooterText.Text='本地运行 · 不上传数据 · v'+$script:appVersion
if(-not $script:isTestMode){$obsolete=Remove-ObsoleteWanwanFiles $root;if($obsolete){Write-Event ('Removed files from older versions: '+($obsolete -join ', '))}}
Update-StreakDisplay
function Show-BedDialog([bool]$demo,[datetime]$Now=(Get-Date),[switch]$Quiet,[switch]$Caught){
 $state=Get-NightState $Now $cfg
 if($script:dialog){return}
 $script:demoMode=$demo
 $script:deadline=if($demo){$Now.AddSeconds(35)}elseif($state.Phase -eq 'Due'){$Now.AddMinutes(2)}else{$state.End}
 [xml]$dx=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="晚晚 · 该休息啦" Width="410" Height="650" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" ShowActivated="False" ShowInTaskbar="False" Topmost="True" FontFamily="Microsoft YaHei UI">
 <Grid>
 <Grid x:Name="FullReminder" Margin="12"><Grid.RowDefinitions><RowDefinition Height="190"/><RowDefinition Height="*"/></Grid.RowDefinitions>
  <Grid><StackPanel Margin="12,72,0,0" HorizontalAlignment="Left"><TextBlock Text="今天辛苦啦" Foreground="#A7778B" FontSize="16"/><TextBlock Text="晚晚在这儿，&#10;别熬太晚啦 ♡" Foreground="#9B7589" FontSize="12" LineHeight="22" Margin="0,8,0,0"/></StackPanel><Image x:Name="DialogPortrait" Width="245" Stretch="Uniform" HorizontalAlignment="Right"/><Image x:Name="DialogFade" Width="245" Stretch="Uniform" HorizontalAlignment="Right" Opacity="0" IsHitTestVisible="False"/></Grid>
  <Border Grid.Row="1" Background="#FFF7FA" CornerRadius="24" BorderBrush="#E7C8D7" BorderThickness="1" Padding="21,18"><Border.Effect><DropShadowEffect Color="#805065" BlurRadius="16" ShadowDepth="3" Opacity="0.14"/></Border.Effect><StackPanel>
   <TextBlock x:Name="ReminderTime" Text="晚晚 · 睡前提醒" Foreground="#AD7991" FontSize="12"/>
   <TextBlock x:Name="Headline" Text="好啦，该睡觉了～" FontSize="25" Margin="0,12,0,10" Foreground="#40313C"/>
   <TextBlock x:Name="Info" Text="先保存文件，再准备休息。" TextWrapping="Wrap" FontSize="14" LineHeight="24" Foreground="#85717D"/>
   <DockPanel Margin="0,12,0,10"><TextBlock x:Name="Remaining" FontSize="37" Foreground="#A7778B"/><TextBlock Text="  留给你保存的时间" Foreground="#AA8E9C" FontSize="11" VerticalAlignment="Center"/></DockPanel>
   <TextBlock x:Name="Safety" Text="正常关机保留应用的未保存提示。" TextWrapping="Wrap" Foreground="#9C8793" FontSize="11" Margin="0,0,0,14"/>
   <Button x:Name="Acknowledge" Content="好啦，我收完尾就睡 ♡" Padding="10,9" Background="#A7778B" Foreground="White" Margin="0,0,0,8"/>
   <Button x:Name="Defer" Content="再给我一点收尾时间" Padding="10,9" Margin="0,0,0,8"/><Button x:Name="CancelNight" Content="紧急取消今晚关机…" Padding="10,9"/>
  </StackPanel></Border>
 </Grid>
 <Border x:Name="MiniReminder" Visibility="Collapsed" Margin="7" CornerRadius="24" Background="#FFF7FA" BorderBrush="#E7C8D7" BorderThickness="1" Padding="10,8">
  <StackPanel>
   <DockPanel x:Name="MiniDragHandle" Cursor="SizeAll"><Button x:Name="MiniHide" Content="×" DockPanel.Dock="Right" Padding="7,0" FontSize="16" ToolTip="隐藏倒计时，后台计时与关机继续"/><TextBlock Text="晚晚帮你计时 ♡" Foreground="#9B7589" FontSize="12" VerticalAlignment="Center"/></DockPanel>
   <Grid Height="132"><Image x:Name="MiniPortrait" Stretch="Uniform"/><Image x:Name="MiniFade" Stretch="Uniform" Opacity="0" IsHitTestVisible="False"/></Grid>
   <TextBlock x:Name="MiniRemaining" FontSize="32" FontWeight="SemiBold" Foreground="#A7778B" HorizontalAlignment="Center"/>
   <TextBlock x:Name="MiniStatus" Text="时间照常走，记得保存 ♡" FontSize="10" Foreground="#9B7589" HorizontalAlignment="Center" Margin="0,2,0,8"/>
   <Button x:Name="MiniExpand" Content="展开倒计时 ↗" Padding="8,6" FontSize="11" ToolTip="展开后可延期或紧急取消关机"/>
  </StackPanel>
 </Border>
 </Grid>
</Window>
'@
 $script:dialog=[Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($dx))
 $script:dialog.Resources.MergedDictionaries.Add($win.Resources);Set-WanwanIcon $script:dialog;Place-DesktopWindow $script:dialog
 if($script:popup){$script:popup.Close()}
 $script:dialogSurface=Register-CharacterSurface ($dialog.FindName('DialogPortrait')) ($dialog.FindName('DialogFade')) $dialog
 $script:miniDialogSurface=Register-CharacterSurface ($dialog.FindName('MiniPortrait')) ($dialog.FindName('MiniFade')) $dialog
 $script:countdownView='Expanded'
 $dialog.Add_Closed({param($sender,$e) $script:surfaces=@($script:surfaces|Where-Object {$_.Window -ne $sender});$script:dialogSurface=$null})
 $script:dialog.Background=[Windows.Media.Brushes]::Transparent
 Update-CountdownText $Now|Out-Null
 $dialog.FindName('Acknowledge').Add_Click({Set-CountdownView Compact;if(-not $script:shutdownAfter){Say-Cue nod -Interaction};Write-Event 'Countdown acknowledged; deadline unchanged'})
 $dialog.FindName('MiniHide').Add_Click({Set-CountdownView Hidden})
 $dialog.FindName('MiniExpand').Add_Click({Set-CountdownView Expanded})
 $dialog.FindName('MiniDragHandle').Add_MouseLeftButtonDown({param($sender,$e) if($e.OriginalSource -is [Windows.Controls.TextBlock] -and $e.LeftButton -eq [Windows.Input.MouseButtonState]::Pressed){$script:dialog.DragMove()}})
 if($demo){$dialog.FindName('Info').Text='这是 35 秒体验，结束后不会关闭电脑。';$dialog.FindName('Safety').Text='演示模式 · 不执行任何关机操作'}
 elseif($cfg.Action -eq 'Sleep'){$dialog.FindName('Safety').Text='到点进入睡眠：窗口和文件都会保留，醒来接着用。'}
 $dialog.FindName('Defer').IsEnabled=($demo -or ($cfg.Deferred -ne $state.Key -and (Get-Date) -lt $state.End.AddMinutes(-2)))
 $dialog.FindName('Defer').Add_Click({
  if($script:demoMode){$script:deadline=(Get-Date).AddSeconds(15)}else{$s=Get-NightState (Get-Date) $cfg;$cfg.Deferred=$s.Key;Save-Config;Write-Event 'Deferred'}
  Say-Cue defer;$script:dialog.Close()
 })
 $dialog.FindName('CancelNight').Add_Click({
  if($script:demoMode){Stop-Voice;$script:dialog.Close();$ui.Feedback.Text='体验已结束，今晚的守护设置没有改变';Start-Interaction 'heart' '好呀，体验先到这里。';return}
  $answer=[Windows.MessageBox]::Show($(if($script:caughtMode){'取消后，今晚晚晚不再监督，明天照常守护。真的有急事要处理吗？'}else{'取消后，今晚不会再自动关机。确实有紧急事情要继续吗？'}),'取消今晚的约定','YesNo','Question')
  if($answer -eq 'Yes'){$key=(Get-NightState (Get-Date) $cfg).Key;$cfg.Cancelled=$key;Save-Config;Set-TonightResult $key 'cancelled';Write-Event 'Cancelled';$script:dialog.Close();Say-Cue cancel}
 })
 $dialog.Add_Closing({param($sender,$e) if(-not $script:nightWindowOver -and -not $script:demoMode -and $cfg.Enabled -and $cfg.Cancelled -ne (Get-NightState (Get-Date) $cfg).Key -and (Get-Date) -ge (Get-NightState (Get-Date) $cfg).End.AddMinutes(-2)){$e.Cancel=$true}})
 $dialog.Add_Closed({$script:dialog=$null;$script:miniDialogSurface=$null;$script:countdownView='Expanded';$script:demoMode=$false;$script:caughtMode=$false;if($cfg.DesktopPet -and -not $script:quitting){Show-DesktopPet -Compact}})
 $dialog.Show(); Set-CompanionMode '晚安'; if($script:motionEnabled){Animate-Double $dialog ([Windows.UIElement]::OpacityProperty) 0 1 0.4;Animate-Double ($dialog.FindName('Remaining')) ([Windows.UIElement]::OpacityProperty) 0.55 1 1.8 $true}; if($Caught){Enter-CaughtMode $Now -Quiet:$Quiet}elseif(-not $Quiet){if($demo){Say-Cue dialog -Demo}else{Say-ClockReminder -Now $Now -Cue $(if($state.Phase -eq 'Due'){if($cfg.Action -eq 'Sleep'){'final'}else{'due'}}elseif($state.Phase -eq 'Final'){'final'}else{'bed'})}}
}
$ui.Preview.Add_Click({$cfg.Voice=[bool]$ui.VoiceToggle.IsChecked;Say-Cue preview;$ui.Feedback.Text=if($cfg.Voice){$(if($cfg.VoicePreset -eq 'System' -or -not $script:lastVoiceAsset){'正在用系统声音朗读'}else{'正在播放'+(Get-Persona).name+'晚晚的声音'})}else{'语音已关闭'}})
$ui.Demo.Add_Click({Show-BedDialog $true})
function Set-SettingsMessage([string]$Text){$ui.Feedback.Text=$Text;$ui.SettingsFeedback.Text=$Text}
function Save-WanwanSettings([switch]$EnableGuard){
 $parsed=[datetime]::MinValue;$minutes=0;$weekend=$ui.WeekendInput.Text.Trim()
 if($weekend -and -not [datetime]::TryParseExact($weekend,'HH:mm',[cultureinfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$parsed)){Set-SettingsMessage '周五六晚请填 01:00 这样的时间，或留空';return}
 $sleepHours=0;$wakeGrace=0
 if(-not [int]::TryParse($ui.SleepHoursInput.Text,[ref]$sleepHours) -or $sleepHours -lt 1 -or $sleepHours -gt 12 -or -not [int]::TryParse($ui.WakeGraceInput.Text,[ref]$wakeGrace) -or $wakeGrace -lt 1 -or $wakeGrace -gt 15){Set-SettingsMessage '起夜监督：睡后 1–12 小时，急事时间 1–15 分钟';return}
 if(-not [datetime]::TryParseExact($ui.BedInput.Text,'HH:mm',[cultureinfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$parsed) -or -not [int]::TryParse($ui.GraceInput.Text,[ref]$minutes) -or $minutes -lt 2 -or $minutes -gt 30){Set-SettingsMessage '时间格式 23:30；收尾时间 2–30 分钟';return}
 if($EnableGuard){$ui.EnabledToggle.IsChecked=$true}
 $cfg.Bedtime=$ui.BedInput.Text;$cfg.WeekendBedtime=$weekend;$cfg.Action=if($ui.ActionSleep.IsChecked){'Sleep'}else{'Shutdown'};$cfg.Grace=$minutes;$cfg.SleepHours=$sleepHours;$cfg.WakeGrace=$wakeGrace;$cfg.Voice=[bool]$ui.VoiceToggle.IsChecked;$cfg.Enabled=[bool]$ui.EnabledToggle.IsChecked;$cfg.Persona=Get-FormPersona;$cfg.VoicePreset=if($ui.VoiceSystem.IsChecked){'System'}else{'Recorded'};$cfg.Address=Get-FormAddress;if($cfg.Address -eq 'custom'){$cfg.Nickname=$ui.NameInput.Text.Trim()};$cfg.Companion=[bool]$ui.CompanionToggle.IsChecked;$cfg.AutoUpdate=[bool]$ui.AutoUpdateToggle.IsChecked
 if(-not $script:isTestMode){if($ui.StartupToggle.IsChecked){Set-LauncherShortcut $startupFile}elseif(Test-Path $startupFile){Remove-Item -LiteralPath $startupFile}}
 if(-not $cfg.Enabled -and $script:dialog -and -not $script:demoMode){$script:dialog.Close()}
 Save-Config;$script:lastPhase='';$script:lastAttempt=[datetime]::MinValue;$script:shutdownAfter=$null;
 Set-SettingsMessage if($cfg.Enabled){if($cfg.Action -eq 'Sleep'){'已保存 · 到点会提醒并进入睡眠 ♡'}else{'已保存 · 到点会提醒并正常关机 ♡'}}else{'已保存 · 只提醒，到点守护未开启'};Write-Event ('Settings saved; guard='+$cfg.Enabled+'; action='+$cfg.Action+'; weekend='+$cfg.WeekendBedtime);
 if($cfg.Enabled){Say-Cue saved}else{Say-GuardLine disabled|Out-Null}
 Update-PetGuardStatus;Update-StreakDisplay;Update-GuardSummary
}
$ui.Save.Add_Click({Save-WanwanSettings})
$ui.ArmGuard.Add_Click({Save-WanwanSettings -EnableGuard})
function Open-Settings {
 if(-not $win.IsVisible -or $win.WindowState -eq [Windows.WindowState]::Minimized){Open-Wanwan}
 if(-not $settingsWin.IsVisible){Sync-SettingsForm;$ui.SettingsFeedback.Text='';if($win.IsVisible){$settingsWin.Owner=$win}}
 $settingsWin.Show();$settingsWin.Activate()|Out-Null
}
$ui.OpenSettings.Add_Click({Open-Settings})
$ui.CloseSettings.Add_Click({$settingsWin.Hide()})
$settingsWin.Add_Closing({param($sender,$e) if(-not $script:quitting){$e.Cancel=$true;$sender.Hide()}})
# 主窗口上的守护开关只切换开/关，其余约定沿用已保存的设置。
$ui.GuardSwitch.Add_Click({$wasOn=[bool]$cfg.Enabled;Sync-SettingsForm;$ui.EnabledToggle.IsChecked=-not $wasOn;Save-WanwanSettings})
Update-GuardSummary
$tray=New-Object System.Windows.Forms.NotifyIcon
$tray.Icon=$script:trayIcon;$tray.Text='晚晚 · 关机助理';$tray.Visible=$true
$menu=New-Object System.Windows.Forms.ContextMenuStrip
function Open-Wanwan {$win.Show();$win.WindowState=[Windows.WindowState]::Normal;$win.Activate()|Out-Null;if($script:dialog -and -not $script:dialog.IsVisible){Set-CountdownView Compact}}
function Hide-Wanwan {$win.Hide();if($cfg.DesktopPet -and -not $script:dialog){Show-DesktopPet -Compact};if($settingsWin.IsVisible){$settingsWin.Hide()};Write-Event 'Hidden; scheduler stays active'}
$open=$menu.Items.Add('打开晚晚');$open.Add_Click({Open-Wanwan})
$settingsMenu=$menu.Items.Add('设置…');$settingsMenu.Add_Click({Open-Settings})
$petMenu=$menu.Items.Add('叫晚晚出来 · 桌宠提醒体验');$petMenu.Add_Click({Say-ClockReminder -Now (Get-Date) -Cue early -Demo})
$showPet=$menu.Items.Add('显示常驻桌宠');$showPet.Add_Click({$ui.PetToggle.IsChecked=$true;Save-Config;Show-DesktopPet -Compact})
$desktopShortcut=$menu.Items.Add('在桌面创建晚晚快捷方式');$desktopShortcut.Add_Click({$path=Join-Path ([Environment]::GetFolderPath('Desktop')) '晚晚 · 睡前陪伴.lnk';Set-LauncherShortcut $path;$tray.ShowBalloonTip(2500,'快捷方式已创建','以后双击桌面上的晚晚头像就能打开。',[System.Windows.Forms.ToolTipIcon]::Info);Write-Event 'Desktop shortcut created'})
$showCountdown=$menu.Items.Add('查看睡前倒计时');$showCountdown.Add_Click({if($script:dialog){Set-CountdownView Compact}else{$ui.Feedback.Text='当前没有正在运行的睡前倒计时';Open-Wanwan}})
$updateMenu=$menu.Items.Add('检查更新');$updateMenu.Add_Click({Open-Wanwan;Start-UpdateCheck -Manual})
$quit=$menu.Items.Add('退出助理（停止自动守护）');$quit.Add_Click({$script:quitting=$true;$cfg.Enabled=$false;if($script:dialog){$script:dialog.Close()};$win.Close()})
$tray.ContextMenuStrip=$menu;$tray.Add_DoubleClick({Open-Wanwan})
$ui.Hide.Add_Click({Hide-Wanwan;$tray.ShowBalloonTip(2500,'晚晚在这里','右下角的小头像、托盘图标或桌面快捷方式，都能找回晚晚。',[System.Windows.Forms.ToolTipIcon]::Info)})
$win.Add_Closing({param($sender,$e) if(-not $script:quitting){$e.Cancel=$true;Hide-Wanwan}})
$timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[timespan]::FromSeconds(1)
$script:shutdownAfter=$null;$script:testShutdownRequests=0;$script:lastRealTick=[datetime]::MinValue
function Invoke-GuardTick([datetime]$now=(Get-Date)){
 try{
 if($script:openSignal -and $script:openSignal.WaitOne(0)){Open-Wanwan}
 # 用真实时钟发现电脑睡眠后被唤醒：截止时间已过的倒计时重新给两分钟保存，而不是一醒来就立刻再次关机/睡眠。
 $realNow=[datetime]::UtcNow
 if($script:lastRealTick -ne [datetime]::MinValue -and ($realNow-$script:lastRealTick).TotalSeconds -gt 60 -and $script:dialog -and -not $script:demoMode -and $script:deadline -lt $now.AddMinutes(2)){
  if($cfg.Enabled -and $cfg.GuardedNight -eq (Get-NightState $now $cfg).Key -and (Get-NightState $now $cfg).Phase -eq 'Due'){Enter-CaughtMode $now}
  else{
   $script:deadline=$now.AddMinutes(2);$script:shutdownAfter=$null
   $script:dialog.FindName('Info').Text='欢迎回来～再给你两分钟保存，之后晚晚会继续帮你休息。';Write-Event 'Resumed after a pause; two-minute save window'
  }
 }
 $script:lastRealTick=$realNow
 $s=Get-NightState $now $cfg
 Invoke-HistoryTick $now $s.Phase
 if($script:summaryKey -ne $s.Key){$script:summaryKey=$s.Key;Update-GuardSummary}
 Update-PetGuardStatus
 $ui.Clock.Text=$now.ToString('HH:mm');$ui.TimeDisplay.Text=$s.Bed.ToString('HH:mm')
 $ui.ModeLabel.Text=if($cfg.Enabled){'守护已开启 · 到点'+(Get-GuardActionName)+' ♡'}else{'仅陪伴 · 不会自动关机'}
 $weekendNote=if($cfg.WeekendBedtime){' · 周五六晚 '+$cfg.WeekendBedtime}else{''}
 $ui.Countdown.Text=if(-not $cfg.Enabled){'要到点关机或睡眠，点下面的「开启到点守护」'}elseif($cfg.Cancelled -eq $s.Key){'今晚已取消，好好照顾自己'}elseif($s.Phase -eq 'Day' -or $s.Phase -eq 'Quiet'){'我会提前半小时轻轻提醒你'+$weekendNote}else{'最晚 '+$s.End.ToString('HH:mm')+'，我们就休息'}
 # 夜晚区间结束（例如睡眠到第二天才唤醒）时，收起遗留的倒计时。
 # 用这次检查的时间判断（不是系统当前时间），睡眠唤醒或测试时都能正确收起。
 if($script:dialog -and -not $script:demoMode -and $s.Phase -in @('Day','Quiet','Early','Soon')){$script:nightWindowOver=$true;try{$script:dialog.Close()}finally{$script:nightWindowOver=$false};if(-not $script:dialog){Write-Event 'Night window ended; countdown closed'}}
 $ui.Progress.Value=[math]::Max(0,[math]::Min(100,(($now-$s.Bed.AddMinutes(-30)).TotalMinutes/(30+$cfg.Grace))*100))
 if($script:dialog){
  $left=Update-CountdownText $now
  if($left -eq 0 -and $script:demoMode){$script:dialog.Close();$ui.Feedback.Text='体验结束：没有执行关机';Say-Cue goodnight}
 }
 if(-not $cfg.Enabled -or $cfg.Cancelled -eq $s.Key){$script:shutdownAfter=$null;return}
 if($s.Phase -ne $script:lastPhase){
  $script:lastPhase=$s.Phase
  $cue=switch($s.Phase){'Early'{'early'}'Soon'{'soon'}'Bed'{'bed'}'Final'{'final'}default{''}}
  if($cue){if($s.Phase -in @('Bed','Final')){Set-CompanionMode '晚安'}else{Set-CompanionMode '收尾'};if(-not $script:dialog -and ($s.Phase -eq 'Final' -or ($s.Phase -eq 'Bed' -and $cfg.Deferred -ne $s.Key))){Show-BedDialog $false $now}else{Say-ClockReminder -Now $now -Cue $cue}}
 }
 if($s.Phase -eq 'Bed' -and $cfg.Deferred -ne $s.Key -and -not $script:dialog){Show-BedDialog $false $now}
 if(($s.Phase -eq 'Final' -or $s.Phase -eq 'Due') -and -not $script:dialog){Show-BedDialog $false $now -Caught:($s.Phase -eq 'Due' -and $cfg.GuardedNight -eq $s.Key)}
 if($s.Phase -eq 'Due' -and $script:dialog -and -not $script:demoMode -and $now -ge $script:deadline -and ($now-$script:lastAttempt).TotalSeconds -ge 180){
  if(-not $script:shutdownAfter){
   if(-not $script:dialog.IsVisible){Set-CountdownView Compact}
   if($script:caughtMode){Say-WatchLine final|Out-Null}
   elseif($cfg.Action -eq 'Sleep'){
    # 睡眠模式用不提「关机」的那句。
    Say-GuardLine sleep|Out-Null
   }else{Say-GuardLine shutdown|Out-Null}
   $seconds=if($cfg.Voice){[math]::Max(2,$script:lastGuardDuration+1)}else{2}
   $script:shutdownAfter=$now.AddSeconds($seconds)
   $script:dialog.FindName('Info').Text=$script:lastSpokenLine.text
   Write-Event 'Shutdown announcement started; waiting for voice to finish'
  }elseif($now -ge $script:shutdownAfter){
   $script:shutdownAfter=$null;$script:lastAttempt=$now
   $sleep=$cfg.Action -eq 'Sleep'
   if($script:isTestMode){$script:testShutdownRequests++;$ok=$true;Write-Event ('TEST simulated '+$cfg.Action+' request; native API not called')}
   elseif($sleep){$ok=[System.Windows.Forms.Application]::SetSuspendState([System.Windows.Forms.PowerState]::Suspend,$false,$false);Write-Event ('Sleep requested; accepted='+$ok)}
   else{$ok=[Wanwan.Power]::ExitWindowsEx(1,0);Write-Event ('Normal shutdown requested; accepted='+$ok+'; error='+[Wanwan.Power]::LastError)}
   if($ok){$cfg.GuardedNight=$s.Key;Save-Config;Set-TonightResult $s.Key 'slept'}
   if($sleep){
    # 睡眠后进程继续运行：唤醒时重新给两分钟保存时间。
    $script:deadline=$now.AddMinutes(2)
    $script:dialog.FindName('Info').Text=if($ok){'晚晚帮你进入睡眠啦。醒来后会再给你两分钟收尾。'}else{'睡眠请求没有成功，请手动让电脑睡眠，或在设置里改用关机。'}
   }else{$script:dialog.FindName('Info').Text=if($ok){'已请求正常关机。如有未保存提示，请先保存；三分钟后重试。'}else{'关机请求失败（系统错误 '+[Wanwan.Power]::LastError+'）。请保存后从开始菜单关机。'}}
  }
 }
 }catch{Write-Event ('Error: '+$_.Exception.Message)}
}
$timer.Add_Tick({Invoke-GuardTick})
. "$PSScriptRoot\Power.ps1"
if($SmokeTest -or $InteractionTest -or $AnimationTest -or $VoiceTest -or $CompanionTest -or $DialogueTest -or $PetTest -or $GuardTest -or $PetControlsTest -or $ShowcaseTest -or $CountdownTest -or $WatchTest -or $BehaviorTest){
 $cfg.Enabled=$false;$cfg.DesktopPet=$false;$ui.PetToggle.IsChecked=$false;$cfg.Voice=$false;$ui.EnabledToggle.IsChecked=$false;$ui.VoiceToggle.IsChecked=$false;$win.Show();$win.UpdateLayout()
 Start-Interaction 'peek'
 $initialFrame=[Windows.Threading.DispatcherFrame]::new();$initialWait=[Windows.Threading.DispatcherTimer]::new();$initialWait.Interval=[timespan]::FromMilliseconds(250);$initialWait.Add_Tick({$initialFrame.Continue=$false;$initialWait.Stop()});$initialWait.Start();[Windows.Threading.Dispatcher]::PushFrame($initialFrame)
 if($GuardTest){. "$PSScriptRoot\Guard.Tests.ps1"}
 if($CountdownTest){. "$PSScriptRoot\Countdown.Tests.ps1"}
 if($WatchTest){. "$PSScriptRoot\Watch.Tests.ps1"}
 if($BehaviorTest){. "$PSScriptRoot\Behavior.Tests.ps1"}
 if($PetControlsTest){. "$PSScriptRoot\PetControls.Tests.ps1"}
 if($ShowcaseTest){. "$PSScriptRoot\Showcase.Tests.ps1"}
 if($PetTest){. "$PSScriptRoot\DesktopPet.Tests.ps1"}
 if($DialogueTest){. "$PSScriptRoot\Dialogue.Tests.ps1"}
 if($CompanionTest){. "$PSScriptRoot\Companion.Tests.ps1"}
 if($VoiceTest){
  # 两种性格（女友 N1 / 姐姐 V3）：旧设置迁移、设置保存、称呼整句录音、整点两段播放、系统朗读兜底。
  $originalConfigFile=$configFile;$configFile=Join-Path $root 'output\voice-test-settings.json'
  if(Test-Path (Join-Path $root 'app\Auditions.ps1')){throw 'Voice picker must be removed'}
  $cfg.Remove('Persona');$cfg.Remove('Address');$cfg.VoicePreset='V3';$cfg.Nickname='宝贝';Repair-PersonaSettings
  if($cfg.Persona -ne 'sister' -or $cfg.VoicePreset -ne 'Recorded' -or $cfg.Address -ne 'xiaobendan' -and $cfg.Address -ne 'none'){throw "V3 must migrate to the sister persona: $($cfg.Persona)/$($cfg.Address)"}
  $cfg.Remove('Persona');$cfg.Remove('Address');$cfg.VoicePreset='N1';$cfg.Nickname='小明';Repair-PersonaSettings
  if($cfg.Persona -ne 'girlfriend' -or $cfg.Address -ne 'custom'){throw 'Old custom nickname must stay a custom name'}
  # 设置窗口：切换性格会换称呼列表，保存后写进配置。
  Sync-SettingsForm;$ui.PersonaSister.IsChecked=$true
  if(@($ui.AddressInput.Items|ForEach-Object Tag) -join ',' -ne 'xiaobendan,none,custom'){throw 'Sister address list wrong'}
  Select-AddressItem 'xiaobendan';Save-WanwanSettings
  $persisted=Get-Content $configFile -Raw -Encoding UTF8|ConvertFrom-Json
  if($persisted.Persona -ne 'sister' -or $persisted.Address -ne 'xiaobendan'){throw 'Sister persona not saved'}
  $ui.PersonaGirlfriend.IsChecked=$true
  if(@($ui.AddressInput.Items|ForEach-Object Tag) -join ',' -ne 'baobao,qinaide,none,custom'){throw 'Girlfriend address list wrong'}
  Select-AddressItem 'qinaide';$ui.CompanionToggle.IsChecked=$true;Save-WanwanSettings
  $persisted=Get-Content $configFile -Raw -Encoding UTF8|ConvertFrom-Json
  if($persisted.Persona -ne 'girlfriend' -or $persisted.Address -ne 'qinaide' -or -not $persisted.Companion){throw 'Girlfriend persona not saved'}
  $ui.CompanionToggle.IsChecked=$false;Save-WanwanSettings
  $ui.VoiceToggle.IsChecked=$true;$cfg.Voice=$true;$script:voicePlayer.Volume=0;$script:synth.Volume=0
  $report=@()
  foreach($personaId in @('girlfriend','sister')){
   $cfg.Persona=$personaId;$cfg.VoicePreset='Recorded'
   $preview=$script:personaLines|Where-Object {$_.persona -eq $personaId -and $_.cue -eq 'preview'}|Select-Object -First 1
   $label=$script:personas[$personaId].addresses[0]
   if(-not (Test-PersonaBank $personaId)){
    $cfg.Address=$label.id;$r=Resolve-Speech $preview
    if($r.Clips.Count -or $r.Text -notlike ($label.label+'*')){throw "$personaId without a bank must fall back to system speech"}
    $report+="$personaId (no bank yet: system speech)";continue
   }
   # 每个片段都能被 WPF 原生打开（静音）。
   $opened=0
   foreach($clip in $script:personaBanks[$personaId].Values){
    $script:clipOpened=$false;$clipFrame=[Windows.Threading.DispatcherFrame]::new();$clipHandler=[System.EventHandler]{$script:clipOpened=$true;$clipFrame.Continue=$false};$script:voicePlayer.Add_MediaOpened($clipHandler)
    $script:voicePlayer.Open([uri]$clip.file);$clipWait=[Windows.Threading.DispatcherTimer]::new();$clipWait.Interval=[timespan]::FromSeconds(3);$clipWait.Add_Tick({$clipFrame.Continue=$false;$clipWait.Stop()});$clipWait.Start();[Windows.Threading.Dispatcher]::PushFrame($clipFrame);$clipWait.Stop();$script:voicePlayer.Remove_MediaOpened($clipHandler)
    if(-not $script:clipOpened){throw "$personaId clip did not open: $($clip.file)"};$opened++
   }
   $script:voicePlayer.Stop()
   # 称呼：整句录音、文字和录音一致。
   $cfg.Address=$label.id;Speak-Line $preview|Out-Null
   if($script:lastVoiceClips.Count -ne 1 -or $script:lastVoiceClips[0] -notlike ('*@'+$label.id+'.mp3') -or $script:lastSpokenLine.text -notlike ('*'+$label.label+'*')){throw "$personaId address routing failed"};Stop-Voice
   $cfg.Address='none';Speak-Line $preview|Out-Null
   if($script:lastVoiceClips[0] -like '*@*' -or $script:lastSpokenLine.text.Contains($label.label) -or $script:lastSpokenLine.text.Contains('{')){throw "$personaId no-address routing failed"};Stop-Voice
   $cfg.Address='custom';$cfg.Nickname='小明';Speak-Line $preview|Out-Null
   if($script:lastVoiceClips[0] -like '*@*' -or -not $script:lastSpokenLine.text.Contains('小明')){throw "$personaId custom name must be text-only"};Stop-Voice
   # 整点报时：两段依次播放。
   $cfg.Address=$label.id;Speak-Line (Get-ClockReminder ([datetime]'2026-10-12T23:00:00') early)|Out-Null
   if($script:lastVoiceClips.Count -ne 2){throw "$personaId clock must be hour + reminder"}
   $queueFrame=[Windows.Threading.DispatcherFrame]::new();$queueWait=[Windows.Threading.DispatcherTimer]::new();$queueWait.Interval=[timespan]::FromMilliseconds(250)
   $script:queueDeadline=(Get-Date).AddSeconds(8);$queueWait.Add_Tick({if(($script:voicePlayer.Source -and [string]$script:voicePlayer.Source.LocalPath -eq $script:lastVoiceClips[1]) -or (Get-Date) -gt $script:queueDeadline){$queueFrame.Continue=$false;$queueWait.Stop()}});$queueWait.Start();[Windows.Threading.Dispatcher]::PushFrame($queueFrame)
   if([string]$script:voicePlayer.Source.LocalPath -ne $script:lastVoiceClips[1]){throw "$personaId clock did not continue to the reminder"};Stop-Voice
   $report+="$personaId ($opened clips opened)"
  }
  # 系统朗读：不播录音，自定义名字也会读出来。
  $cfg.Persona='girlfriend';$cfg.VoicePreset='System';$cfg.Address='custom';$cfg.Nickname='小明';Say-Cue preview
  if($script:lastVoiceAsset -or -not $script:lastSpokenLine.text.Contains('小明')){throw 'System voice must read the custom name without clips'};Stop-Voice
  $cfg.VoicePreset='Recorded';$cfg.Address='baobao';$cfg.Nickname='';$ui.VoiceToggle.IsChecked=$false;$cfg.Voice=$false
  $configFile=$originalConfigFile
  Write-Output ('Voice tests passed: persona migration, settings persona/address lists saved, '+($report -join ', ')+', whole-sentence address routing, two-part clock, system speech with custom name; real settings unchanged')
 }
 if($AnimationTest){
  if(@($script:interactionAssets.Keys|Where-Object {$_ -notlike 'desk-*'}).Count -ne 10){throw 'Ten interaction sheets required'}
  $captureDirectory=Join-Path $root 'output\animation';New-Item -ItemType Directory -Force $captureDirectory|Out-Null
  Start-Interaction 'wave';$script:captureNumber=0;$script:seenFrames=@()
  $captureTimer=[Windows.Threading.DispatcherTimer]::new();$captureTimer.Interval=[timespan]::FromMilliseconds(160)
  $captureFrame=[Windows.Threading.DispatcherFrame]::new()
  $captureTimer.Add_Tick({
   $render=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$win.ActualWidth,[int]$win.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$render.Render($win)
   $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($render))
   $captureFile=Join-Path $captureDirectory ('frame-{0:00}.png' -f $script:captureNumber);$captureStream=[IO.File]::Create($captureFile);$encoder.Save($captureStream);$captureStream.Dispose()
   $script:seenFrames+=,$script:frameIndex;$script:captureNumber++
   if($script:captureNumber -ge 24){$captureTimer.Stop();$captureFrame.Continue=$false}
  })
  $captureTimer.Start();[Windows.Threading.Dispatcher]::PushFrame($captureFrame)
  if(@($script:seenFrames|Select-Object -Unique).Count -lt 4){throw 'Character animation did not advance through wave frames'}
  Set-Motion $false;$heldFrame=$script:frameIndex
  $script:seenFrames|ConvertTo-Json|Set-Content (Join-Path $captureDirectory 'frame-indices.json')
  Write-Output 'Runtime animation captured; wave advanced through four distinct frames'
 }
 if($InteractionTest){
  if($script:frames.Count -ne 4){throw 'Missing character animation frames'}
  Set-CompanionMode '收尾';if($ui.Mood.Text -ne '✦  快到睡觉时间了'){throw 'Companion state failed'}
  Set-Motion $false;if($script:motionEnabled){throw 'Reduced motion failed'};Set-Motion $true
  $ui.Demo.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  if(-not $script:dialog -or -not $script:demoMode){throw 'Demo did not open safely'}
  $script:dialog.FindName('Defer').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  if($script:dialog){throw 'Defer did not close demo'}
  $ui.Demo.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  $script:dialog.FindName('CancelNight').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  if($script:dialog){throw 'Cancel did not close demo'}
  $ui.Demo.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));$script:deadline=(Get-Date).AddSeconds(-1)
  $timer.Start();$frame=[Windows.Threading.DispatcherFrame]::new();$stop=New-Object Windows.Threading.DispatcherTimer;$stop.Interval=[timespan]::FromSeconds(2);$stop.Add_Tick({$frame.Continue=$false;$stop.Stop()});$stop.Start();[Windows.Threading.Dispatcher]::PushFrame($frame);$timer.Stop()
  if($script:dialog -or $ui.Feedback.Text -ne '体验结束：没有执行关机'){throw 'Demo timer completion failed'}
  Write-Output 'Interaction tests passed: demo, defer, cancel, timer completion; no shutdown invoked'
 }
 $bmp=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$win.ActualWidth,[int]$win.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($win);$enc=[Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp));$stream=[IO.File]::Create((Join-Path $root 'output\desktop-preview.png'));$enc.Save($stream);$stream.Dispose();$script:quitting=$true;$win.Close();$tray.Dispose();$script:trayIcon.Dispose();$synth.Dispose();Write-Output 'WPF smoke test passed';exit
}
$script:application=[Windows.Application]::new()
$script:application.ShutdownMode=[Windows.ShutdownMode]::OnExplicitShutdown
$win.Add_Closed({$script:application.Shutdown()})
if($ResumeCountdownDeadline -gt [datetime]::MinValue){
 if($script:isTestMode){$cfg.Enabled=$true;$cfg.Cancelled='';$cfg.Bedtime=(Get-Date).AddMinutes(-10).ToString('HH:mm');$cfg.Grace=10;$cfg.Voice=$false}
 $resumeNow=Get-Date;$resumeState=Get-NightState $resumeNow $cfg
 if($cfg.Enabled -and $cfg.Cancelled -ne $resumeState.Key -and $resumeState.Phase -in @('Bed','Final','Due') -and $ResumeCountdownDeadline -gt $resumeNow -and $ResumeCountdownDeadline -le $resumeState.End.AddHours(4)){
  Show-BedDialog $false $resumeNow -Quiet;$script:deadline=$ResumeCountdownDeadline;Update-CountdownText $resumeNow|Out-Null;Set-CountdownView Compact;$script:lastPhase=$resumeState.Phase;Say-Cue nod -Interaction
  $win.Add_ContentRendered({$win.Hide()});Write-Event ('Existing countdown resumed for update; deadline='+$script:deadline.ToString('o'))
 }
}
if($LifecycleTest){
 $cfg.Enabled=$false;$cfg.Voice=$false;$cfg.DesktopPet=$true
 $script:lifecycleStep=0;$script:backgroundTicks=0
 $timer.Add_Tick({if(-not $win.IsVisible){$script:backgroundTicks++}})
 $lifecycleTimer=[Windows.Threading.DispatcherTimer]::new();$lifecycleTimer.Interval=[timespan]::FromSeconds(2)
 $lifecycleTimer.Add_Tick({
  $script:lifecycleStep++
  switch($script:lifecycleStep){
   1 {Hide-Wanwan}
   2 {if($win.IsVisible -or -not $tray.Visible -or (-not $popup.IsVisible -and -not $dialog.IsVisible) -or $script:backgroundTicks -lt 1){throw 'Background lifetime failed after hiding'};if($ResumeCountdownDeadline -gt [datetime]::MinValue -and $script:deadline -ne $ResumeCountdownDeadline){throw 'Resume changed existing deadline'};Open-Wanwan}
   3 {if(-not $win.IsVisible){throw 'Restore failed'};@{hideKeepsApplicationAlive=$true;trayVisible=$tray.Visible;petVisible=$popup.IsVisible;countdownVisible=$dialog.IsVisible;resumedDeadline=$script:deadline;backgroundTicks=$script:backgroundTicks;restored=$win.IsVisible}|ConvertTo-Json|Set-Content (Join-Path $root 'output\lifecycle-runtime-report.json') -Encoding UTF8;$lifecycleTimer.Stop();$script:quitting=$true;$win.Close()}
  }
 });$lifecycleTimer.Start()
}
$timer.Start();if(-not $script:isTestMode){$script:behaviorTimer.Start()}
if(-not $script:isTestMode -and $cfg.AutoUpdate){
 # 每天最多自动检查一次，启动 20 秒后在后台进行；只访问 GitHub 的发布信息。
 $lastCheck=[datetime]::MinValue;if($cfg.LastUpdateCheck){[datetime]::TryParse([string]$cfg.LastUpdateCheck,[ref]$lastCheck)|Out-Null}
 if(((Get-Date)-$lastCheck).TotalHours -ge 20){$script:autoUpdateTimer=New-Object Windows.Threading.DispatcherTimer;$script:autoUpdateTimer.Interval=[timespan]::FromSeconds(20);$script:autoUpdateTimer.Add_Tick({$script:autoUpdateTimer.Stop();Start-UpdateCheck});$script:autoUpdateTimer.Start()}
}
try{$script:application.Run($win)|Out-Null}finally{$timer.Stop();$tray.Dispose();$script:trayIcon.Dispose();$synth.Dispose();if($script:openSignal){$script:openSignal.Dispose()};if($script:instanceMutex){$script:instanceMutex.ReleaseMutex();$script:instanceMutex.Dispose()}}
