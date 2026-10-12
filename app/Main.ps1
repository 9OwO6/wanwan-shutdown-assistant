param([switch]$SmokeTest,[switch]$InteractionTest,[switch]$AnimationTest,[switch]$VoiceTest,[switch]$CompanionTest,[switch]$DialogueTest,[switch]$PetTest,[switch]$GuardTest,[switch]$LifecycleTest,[switch]$PetControlsTest,[switch]$ShowcaseTest)
$ErrorActionPreference='Stop'
$script:isTestMode=[bool]($SmokeTest -or $InteractionTest -or $AnimationTest -or $VoiceTest -or $CompanionTest -or $DialogueTest -or $PetTest -or $GuardTest -or $LifecycleTest -or $PetControlsTest -or $ShowcaseTest)
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
$script:cfg=@{Bedtime='23:30';Grace=10;Nickname='你';Voice=$true;VoicePreset='N1';DesktopPet=$true;Enabled=$false;Cancelled='';Deferred=''}
if(Test-Path $configFile){try{$saved=Get-Content $configFile -Raw -Encoding UTF8|ConvertFrom-Json; foreach($p in $saved.PSObject.Properties){$script:cfg[$p.Name]=$p.Value}}catch{}}
if($script:isTestMode){$configFile=Join-Path $root 'output\isolated-test-settings.json';$data=Join-Path $root 'output\isolated-test-data';New-Item -ItemType Directory -Force $data|Out-Null}
if($ShowcaseTest){$script:cfg=@{Bedtime='23:30';Grace=10;Nickname='宝贝';Voice=$false;VoicePreset='N1';DesktopPet=$true;Enabled=$false;Cancelled='';Deferred=''}}
function Save-Config { $script:cfg|ConvertTo-Json|Set-Content $configFile -Encoding UTF8 }
$script:synth=New-Object System.Speech.Synthesis.SpeechSynthesizer
$voice=$script:synth.GetInstalledVoices()|Where-Object {$_.VoiceInfo.Culture.Name -eq 'zh-CN' -and $_.VoiceInfo.Gender -eq 'Female'}|Select-Object -Last 1
if($voice){$script:synth.SelectVoice($voice.VoiceInfo.Name)}
$script:synth.Rate=-2; $script:synth.Volume=80
function Say([string]$message){if($script:cfg.Voice){$script:synth.SpeakAsyncCancelAll();$script:synth.SpeakAsync($message)|Out-Null}}
[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="晚晚 · 关机助理" Width="1080" Height="840" MinWidth="940" MinHeight="800" WindowStartupLocation="CenterScreen" Background="#FFF7FA" FontFamily="Microsoft YaHei UI" Foreground="#363138">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Cursor" Value="Hand"/><Setter Property="Padding" Value="20,12"/><Setter Property="Background" Value="#EFE7E2"/><Setter Property="Foreground" Value="#54454C"/><Setter Property="BorderThickness" Value="0"/><Setter Property="FontSize" Value="14"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="b" CornerRadius="14" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.82"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.65"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.4"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
  <Style TargetType="TextBox"><Setter Property="Padding" Value="12,10"/><Setter Property="FontSize" Value="15"/><Setter Property="BorderBrush" Value="#DED4D1"/><Setter Property="Background" Value="#FFFCFA"/></Style>
 </Window.Resources>
 <Grid Margin="26"><Grid.ColumnDefinitions><ColumnDefinition Width="0.95*"/><ColumnDefinition Width="1.2*"/></Grid.ColumnDefinitions>
  <Border Grid.Column="0" CornerRadius="24" ClipToBounds="True" Margin="0,0,24,0">
   <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#E9D7DF" Offset="0"/><GradientStop Color="#99808F" Offset="0.65"/><GradientStop Color="#564759" Offset="1"/></LinearGradientBrush></Border.Background>
   <Grid><Image x:Name="Portrait" Height="400" Margin="0,42,0,0" Stretch="Uniform" VerticalAlignment="Top" Cursor="Hand" ToolTip="轻轻点一下晚晚，收下一个小动作"/><Image x:Name="PortraitFade" Height="400" Margin="0,42,0,0" Stretch="Uniform" VerticalAlignment="Top" IsHitTestVisible="False" Opacity="0"/><Canvas x:Name="Stars" IsHitTestVisible="False" VerticalAlignment="Top" Height="180"/><Border VerticalAlignment="Top" HorizontalAlignment="Left" Margin="22" Background="#993D3341" CornerRadius="14" Padding="14,9"><TextBlock x:Name="Mood" Text="✦  晚晚在你身边" Foreground="#FFF1E7" FontSize="12"/></Border>
    <Border VerticalAlignment="Top" Margin="22,450,22,0" Background="#22FFF2F8" CornerRadius="20" Padding="18"><StackPanel><TextBlock Text="♡  点点我，收下一点小温柔" Foreground="#FFF1F7" FontSize="15"/><TextBlock Text="探头  ·  拍一拍  ·  给你一颗心" Foreground="#E8D5DF" FontSize="12" Margin="0,10,0,0"/></StackPanel></Border><StackPanel VerticalAlignment="Bottom" Margin="28,0,28,32"><TextBlock Text="WANWAN / 晚晚" Foreground="#F2DED4" FontSize="12"/><TextBlock Text="夜深了，&#10;还有我陪你。" Foreground="White" FontSize="32" Margin="0,12,0,12"/><TextBlock Text="把今天轻轻放下，明天再继续。" Foreground="#F1E2DE" FontSize="13"/></StackPanel>
   </Grid>
  </Border>
  <Grid Grid.Column="1"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
   <DockPanel Margin="0,8,0,20"><TextBlock Text="☾  关机助理" FontSize="19" FontWeight="SemiBold"/><TextBlock x:Name="Clock" Text="" HorizontalAlignment="Right" Foreground="#8A7E85" FontSize="14"/></DockPanel>
   <StackPanel Grid.Row="1">
    <TextBlock Text="今晚的约定" Foreground="#9B7B88" FontSize="12" Margin="0,8,0,10"/>
    <TextBlock x:Name="Headline" Text="早点睡，是给自己的温柔。" FontSize="28" FontWeight="SemiBold" TextWrapping="Wrap"/>
    <TextBlock x:Name="Message" Text="忙了一天，辛苦啦。我们约个时间，慢慢收尾，然后安心休息。" TextWrapping="Wrap" FontSize="15" Foreground="#81727B" LineHeight="26" Margin="0,14,0,22"/>
    <Border Background="#FFFFFF" CornerRadius="20" Padding="22" Margin="0,0,0,18"><StackPanel>
     <DockPanel><TextBlock Text="今晚休息时间" Foreground="#95868E"/><TextBlock x:Name="ModeLabel" Text="守护未开启" HorizontalAlignment="Right" Foreground="#A47C8B"/></DockPanel>
     <TextBlock x:Name="TimeDisplay" Text="23:30" FontSize="46" Margin="0,8,0,3"/>
     <TextBlock x:Name="Countdown" Text="我会提前半小时轻轻提醒你" Foreground="#95868E"/>
     <ProgressBar x:Name="Progress" Height="4" Margin="0,16,0,0" Maximum="100" Value="0" Foreground="#BE91A1" Background="#F2EBEE" BorderThickness="0"/><TextBlock x:Name="VoiceBadge" Text="♫  选一个喜欢的声音" Foreground="#AD8B9C" FontSize="12" Margin="0,12,0,0"/>
    </StackPanel></Border>
    <WrapPanel Margin="0,0,0,17"><Button x:Name="Preview" Content="♡  听听晚晚的提醒" Background="#A7778B" Foreground="White" Margin="0,0,10,8"/><Button x:Name="Demo" Content="体验睡前倒计时" Margin="0,0,8,8"/><Button x:Name="Auditions" Content="♫ 音色试听" Padding="12,12" Margin="0,0,0,8"/></WrapPanel>
    <WrapPanel Margin="0,0,0,14"><Button x:Name="MoodIdle" Content="陪伴" Padding="12,8" Margin="0,0,6,0"/><Button x:Name="MoodWrap" Content="收尾" Padding="12,8" Margin="0,0,6,0"/><Button x:Name="MoodNight" Content="晚安" Padding="12,8" Margin="0,0,6,0"/><Button x:Name="Interactions" Content="♡ 互动小剧场" Padding="12,8" Margin="0,0,10,0"/><CheckBox x:Name="MotionToggle" Content="减少动态" VerticalAlignment="Center"/></WrapPanel><Border Background="#F6E8EE" CornerRadius="16" Padding="16"><StackPanel>
     <Grid><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
      <StackPanel Margin="0,0,12,0"><TextBlock Text="睡觉时间" Margin="0,0,0,7" Foreground="#87767F"/><TextBox x:Name="BedInput" Text="23:30" MaxLength="5"/></StackPanel>
      <StackPanel Grid.Column="1" Margin="0,0,12,0"><TextBlock Text="收尾分钟" Margin="0,0,0,7" Foreground="#87767F"/><TextBox x:Name="GraceInput" Text="10" MaxLength="2"/></StackPanel>
      <StackPanel Grid.Column="2"><TextBlock Text="系统语音称呼" Margin="0,0,0,7" Foreground="#87767F"/><TextBox x:Name="NameInput" Text="你" MaxLength="12" ToolTip="系统声音会使用这个称呼；N1 的录音会自然轮换宝贝、宝宝、亲爱的等称呼。"/></StackPanel>
     </Grid>
     <WrapPanel Margin="0,13,0,0"><CheckBox x:Name="VoiceToggle" Content="温柔语音" IsChecked="True" Margin="0,0,18,0"/><CheckBox x:Name="EnabledToggle" Content="到点自动关机" ToolTip="勾选并保存后生效；超过截止时间时先提醒保存，倒计时后请求正常关机。" Margin="0,0,18,0"/><CheckBox x:Name="StartupToggle" Content="开机陪伴" ToolTip="登录 Windows 后启动晚晚；是否自动关机由旁边的开关决定。" Margin="0,0,18,0"/><CheckBox x:Name="PetToggle" Content="桌面陪伴"/></WrapPanel>
     <DockPanel Margin="0,14,0,0"><Button x:Name="Save" Content="保存约定" Padding="12,8" Background="#E3D5DB"/><Button x:Name="ArmGuard" Content="保存并开启关机" Padding="12,8" Margin="8,0,0,0" Background="#A7778B" Foreground="White" ToolTip="保存当前时间并开启自动关机。已超时会立即开始两分钟保存倒计时。"/><TextBlock x:Name="Feedback" Text="" Foreground="#8A6878" VerticalAlignment="Center" Margin="12,0,0,0" TextWrapping="Wrap"/></DockPanel>
    </StackPanel></Border>
   </StackPanel>
   <DockPanel Grid.Row="2" Margin="0,16,0,0"><TextBlock Text="本地陪伴 · 正常关机前会提醒保存" Foreground="#A3979D" FontSize="11"/><Button x:Name="PetPreview" Content="桌宠提醒体验 ♡" FontSize="11" Padding="8,6" Margin="10,0,8,0"/><Button x:Name="Hide" Content="收起到托盘 ↗" FontSize="11" Padding="8,6" HorizontalAlignment="Right"/></DockPanel>
  </Grid>
 </Grid>
</Window>
'@
$reader=New-Object System.Xml.XmlNodeReader $xaml
$script:win=[Windows.Markup.XamlReader]::Load($reader)
Set-WanwanIcon $script:win
$ui=@{}; foreach($n in 'Portrait','Clock','Headline','Message','ModeLabel','TimeDisplay','Countdown','Progress','Preview','Demo','BedInput','GraceInput','NameInput','VoiceToggle','EnabledToggle','Save','Feedback','Hide'){$ui[$n]=$win.FindName($n)}
$ui.StartupToggle=$win.FindName('StartupToggle')
$startupFile=Join-Path ([Environment]::GetFolderPath('Startup')) '晚晚关机助理.lnk'
$ui.StartupToggle.IsChecked=Test-Path $startupFile
$art=Join-Path $root 'assets\wanwan.png';if(Test-Path $art){$ui.Portrait.Source=[Windows.Media.Imaging.BitmapImage]::new([uri]$art)}
$ui.BedInput.Text=$cfg.Bedtime;$ui.GraceInput.Text=[string]$cfg.Grace;$ui.NameInput.Text=$cfg.Nickname;$ui.VoiceToggle.IsChecked=[bool]$cfg.Voice;$ui.EnabledToggle.IsChecked=[bool]$cfg.Enabled
$script:lastPhase='';$script:dialog=$null;$script:demoMode=$false;$script:deadline=$null;$script:lastAttempt=[datetime]::MinValue
. "$PSScriptRoot\Visuals.ps1"
. "$PSScriptRoot\Dialogue.ps1"
. "$PSScriptRoot\Voice.ps1"
. "$PSScriptRoot\DesktopPet.ps1"
. "$PSScriptRoot\Auditions.ps1"
function Write-Event([string]$event){Add-Content (Join-Path $data 'events.log') ((Get-Date -Format o)+' '+$event) -Encoding UTF8}
function Show-BedDialog([bool]$demo,[datetime]$Now=(Get-Date)){
 $state=Get-NightState $Now $cfg
 if($script:dialog){return}
 $script:demoMode=$demo
 $script:deadline=if($demo){$Now.AddSeconds(35)}elseif($state.Phase -eq 'Due'){$Now.AddMinutes(2)}else{$state.End}
 [xml]$dx=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="晚晚 · 该休息啦" Width="410" Height="610" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" ShowActivated="False" ShowInTaskbar="False" Topmost="True" FontFamily="Microsoft YaHei UI">
 <Grid Margin="12"><Grid.RowDefinitions><RowDefinition Height="190"/><RowDefinition Height="*"/></Grid.RowDefinitions>
  <Grid><StackPanel Margin="12,72,0,0" HorizontalAlignment="Left"><TextBlock Text="今天辛苦啦" Foreground="#A7778B" FontSize="16"/><TextBlock Text="晚晚陪你，&#10;慢慢收尾 ♡" Foreground="#9B7589" FontSize="12" LineHeight="22" Margin="0,8,0,0"/></StackPanel><Image x:Name="DialogPortrait" Width="245" Stretch="Uniform" HorizontalAlignment="Right"/><Image x:Name="DialogFade" Width="245" Stretch="Uniform" HorizontalAlignment="Right" Opacity="0" IsHitTestVisible="False"/></Grid>
  <Border Grid.Row="1" Background="#FFF7FA" CornerRadius="24" BorderBrush="#E7C8D7" BorderThickness="1" Padding="21,18"><Border.Effect><DropShadowEffect Color="#805065" BlurRadius="16" ShadowDepth="3" Opacity="0.14"/></Border.Effect><StackPanel>
   <TextBlock x:Name="ReminderTime" Text="晚晚陪你收尾" Foreground="#AD7991" FontSize="12"/>
   <TextBlock Text="好啦，该睡觉了～" FontSize="25" Margin="0,12,0,10" Foreground="#40313C"/>
   <TextBlock x:Name="Info" Text="先保存文件，我陪你收尾。" TextWrapping="Wrap" FontSize="14" LineHeight="24" Foreground="#85717D"/>
   <DockPanel Margin="0,12,0,10"><TextBlock x:Name="Remaining" FontSize="37" Foreground="#A7778B"/><TextBlock Text="  留给你保存的时间" Foreground="#AA8E9C" FontSize="11" VerticalAlignment="Center"/></DockPanel>
   <TextBlock x:Name="Safety" Text="正常关机保留应用的未保存提示。" TextWrapping="Wrap" Foreground="#9C8793" FontSize="11" Margin="0,0,0,14"/>
   <Button x:Name="Defer" Content="再给我一点收尾时间" Padding="10,9" Margin="0,0,0,8"/><Button x:Name="CancelNight" Content="紧急取消今晚关机…" Padding="10,9"/>
  </StackPanel></Border>
 </Grid>
</Window>
'@
 $script:dialog=[Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($dx))
 $script:dialog.Resources.MergedDictionaries.Add($win.Resources);Set-WanwanIcon $script:dialog;Place-DesktopWindow $script:dialog
 if($script:popup){$script:popup.Close()}
 $script:dialogSurface=Register-CharacterSurface ($dialog.FindName('DialogPortrait')) ($dialog.FindName('DialogFade')) $dialog
 $dialog.Add_Closed({param($sender,$e) $script:surfaces=@($script:surfaces|Where-Object {$_.Window -ne $sender});$script:dialogSurface=$null})
 $script:dialog.Background=[Windows.Media.Brushes]::Transparent
 $initialLeft=[math]::Max(0,[int][math]::Ceiling(($script:deadline-$Now).TotalSeconds));$dialog.FindName('Remaining').Text=('{0:00}:{1:00}' -f [math]::Floor($initialLeft/60),($initialLeft%60))
 if($demo){$dialog.FindName('Info').Text='这是 35 秒体验，结束后不会关闭电脑。';$dialog.FindName('Safety').Text='演示模式 · 不执行任何关机操作'}
 $dialog.FindName('Defer').IsEnabled=($demo -or ($cfg.Deferred -ne $state.Key -and (Get-Date) -lt $state.End.AddMinutes(-2)))
 $dialog.FindName('Defer').Add_Click({
  if($script:demoMode){$script:deadline=(Get-Date).AddSeconds(15)}else{$s=Get-NightState (Get-Date) $cfg;$cfg.Deferred=$s.Key;Save-Config;Write-Event 'Deferred'}
  Say-Cue defer;$script:dialog.Close()
 })
 $dialog.FindName('CancelNight').Add_Click({
  if($script:demoMode){Stop-Voice;$script:dialog.Close();$ui.Feedback.Text='体验已结束，今晚的守护设置没有改变';Start-Interaction 'heart' '好呀，体验先到这里。';return}
  $answer=[Windows.MessageBox]::Show('取消后，今晚不会再自动关机。确实有紧急事情要继续吗？','取消今晚的约定','YesNo','Question')
  if($answer -eq 'Yes'){$cfg.Cancelled=(Get-NightState (Get-Date) $cfg).Key;Save-Config;Write-Event 'Cancelled';$script:dialog.Close();Say-Cue cancel}
 })
 $dialog.Add_Closing({param($sender,$e) if(-not $script:demoMode -and $cfg.Enabled -and $cfg.Cancelled -ne (Get-NightState (Get-Date) $cfg).Key -and (Get-Date) -ge (Get-NightState (Get-Date) $cfg).End.AddMinutes(-2)){$e.Cancel=$true}})
 $dialog.Add_Closed({$script:dialog=$null;$script:demoMode=$false;if($cfg.DesktopPet -and -not $script:quitting){Show-DesktopPet -Compact}})
 $dialog.Show(); Set-CompanionMode '晚安'; if($script:motionEnabled){Animate-Double $dialog ([Windows.UIElement]::OpacityProperty) 0 1 0.4;Animate-Double ($dialog.FindName('Remaining')) ([Windows.UIElement]::OpacityProperty) 0.55 1 1.8 $true}; if($demo){Say-Cue dialog -Demo}else{Say-ClockReminder -Now $Now -Cue $(if($state.Phase -eq 'Due'){'due'}elseif($state.Phase -eq 'Final'){'final'}else{'bed'})}
}
$ui.Preview.Add_Click({$cfg.Voice=[bool]$ui.VoiceToggle.IsChecked;Say-Cue preview;$ui.Feedback.Text=if($cfg.Voice){$(if($cfg.VoicePreset -eq 'System'){'正在播放系统女声'}else{'正在播放 AI 音色 '+$cfg.VoicePreset})}else{'语音已关闭'}})
$ui.Demo.Add_Click({Show-BedDialog $true})
function Save-WanwanSettings([switch]$EnableGuard){
 $parsed=[datetime]::MinValue;$minutes=0
 if(-not [datetime]::TryParseExact($ui.BedInput.Text,'HH:mm',[cultureinfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$parsed) -or -not [int]::TryParse($ui.GraceInput.Text,[ref]$minutes) -or $minutes -lt 2 -or $minutes -gt 30){$ui.Feedback.Text='时间格式 23:30；收尾时间 2–30 分钟';return}
 if($EnableGuard){$ui.EnabledToggle.IsChecked=$true}
 $cfg.Bedtime=$ui.BedInput.Text;$cfg.Grace=$minutes;$cfg.Nickname=$ui.NameInput.Text.Trim();$cfg.Voice=[bool]$ui.VoiceToggle.IsChecked;$cfg.Enabled=[bool]$ui.EnabledToggle.IsChecked
 if(-not $script:isTestMode){if($ui.StartupToggle.IsChecked){$shortcut=(New-Object -ComObject WScript.Shell).CreateShortcut($startupFile);$shortcut.TargetPath=Join-Path $env:WINDIR 'System32\wscript.exe';$shortcut.Arguments='"'+(Join-Path $root '启动晚晚.vbs')+'"';$shortcut.WorkingDirectory=$root;$shortcut.IconLocation=$script:iconPath+',0';$shortcut.Save()}elseif(Test-Path $startupFile){Remove-Item -LiteralPath $startupFile}}
 if(-not $cfg.Enabled -and $script:dialog -and -not $script:demoMode){$script:dialog.Close()}
 Save-Config;$script:lastPhase='';$script:lastAttempt=[datetime]::MinValue;$script:shutdownAfter=$null;
 $ui.Feedback.Text=if($cfg.Enabled){'已保存 · 到点会提醒并正常关机 ♡'}else{'已保存 · 仅陪伴，自动关机未开启'};Write-Event ('Settings saved; guard='+$cfg.Enabled);
 if($cfg.Enabled){Say-Cue saved -Interaction}else{Say-GuardLine disabled}
 Update-PetGuardStatus
}
$ui.Save.Add_Click({Save-WanwanSettings})
$win.FindName('ArmGuard').Add_Click({Save-WanwanSettings -EnableGuard})
$tray=New-Object System.Windows.Forms.NotifyIcon
$tray.Icon=$script:trayIcon;$tray.Text='晚晚 · 关机助理';$tray.Visible=$true
$menu=New-Object System.Windows.Forms.ContextMenuStrip
function Open-Wanwan {$win.Show();$win.WindowState=[Windows.WindowState]::Normal;$win.Activate()|Out-Null}
function Hide-Wanwan {$win.Hide();if($cfg.DesktopPet -and -not $script:dialog){Show-DesktopPet -Compact};Write-Event 'Hidden; scheduler stays active'}
$open=$menu.Items.Add('打开晚晚');$open.Add_Click({Open-Wanwan})
$petMenu=$menu.Items.Add('叫晚晚出来 · 桌宠提醒体验');$petMenu.Add_Click({Say-ClockReminder -Now (Get-Date) -Cue early -Demo})
$showPet=$menu.Items.Add('显示常驻桌宠');$showPet.Add_Click({$ui.PetToggle.IsChecked=$true;Save-Config;Show-DesktopPet -Compact})
$quit=$menu.Items.Add('退出助理（停止自动守护）');$quit.Add_Click({$script:quitting=$true;$cfg.Enabled=$false;if($script:dialog){$script:dialog.Close()};$win.Close()})
$tray.ContextMenuStrip=$menu;$tray.Add_DoubleClick({Open-Wanwan})
$ui.Hide.Add_Click({Hide-Wanwan;$tray.ShowBalloonTip(2500,'晚晚在这里','右下角的小头像、托盘图标或桌面快捷方式，都能找回晚晚。',[System.Windows.Forms.ToolTipIcon]::Info)})
$win.Add_Closing({param($sender,$e) if(-not $script:quitting){$e.Cancel=$true;Hide-Wanwan}})
$timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[timespan]::FromSeconds(1)
$script:shutdownAfter=$null;$script:testShutdownRequests=0
function Invoke-GuardTick([datetime]$now=(Get-Date)){
 try{
 if($script:openSignal -and $script:openSignal.WaitOne(0)){Open-Wanwan}
 $s=Get-NightState $now $cfg
 Update-PetGuardStatus
 $ui.Clock.Text=$now.ToString('HH:mm');$ui.TimeDisplay.Text=$cfg.Bedtime
 $ui.ModeLabel.Text=if($cfg.Enabled){'守护已开启 ♡'}else{'仅陪伴 · 不会自动关机'}
 $ui.Countdown.Text=if(-not $cfg.Enabled){'要自动关机，请勾选「到点自动关机」并保存'}elseif($cfg.Cancelled -eq $s.Key){'今晚已取消，好好照顾自己'}elseif($s.Phase -eq 'Day' -or $s.Phase -eq 'Quiet'){'我会提前半小时轻轻提醒你'}else{'最晚 '+$s.End.ToString('HH:mm')+'，我们就休息'}
 $ui.Progress.Value=[math]::Max(0,[math]::Min(100,(($now-$s.Bed.AddMinutes(-30)).TotalMinutes/(30+$cfg.Grace))*100))
 if($script:dialog){
  $left=[math]::Max(0,[int][math]::Ceiling(($script:deadline-$now).TotalSeconds));$script:dialog.FindName('Remaining').Text=('{0:00}:{1:00}' -f [math]::Floor($left/60),($left%60))
  if($left -eq 0 -and $script:demoMode){$script:dialog.Close();$ui.Feedback.Text='体验结束：没有执行关机';Say-Cue goodnight}
 }
 if(-not $cfg.Enabled -or $cfg.Cancelled -eq $s.Key){$script:shutdownAfter=$null;return}
 if($s.Phase -ne $script:lastPhase){
  $script:lastPhase=$s.Phase
  $cue=switch($s.Phase){'Early'{'early'}'Soon'{'soon'}'Bed'{'bed'}'Final'{'final'}default{''}}
  if($cue){if($s.Phase -in @('Bed','Final')){Set-CompanionMode '晚安'}else{Set-CompanionMode '收尾'};if(-not $script:dialog -and ($s.Phase -eq 'Final' -or ($s.Phase -eq 'Bed' -and $cfg.Deferred -ne $s.Key))){Show-BedDialog $false $now}else{Say-ClockReminder -Now $now -Cue $cue}}
 }
 if($s.Phase -eq 'Bed' -and $cfg.Deferred -ne $s.Key -and -not $script:dialog){Show-BedDialog $false $now}
 if(($s.Phase -eq 'Final' -or $s.Phase -eq 'Due') -and -not $script:dialog){Show-BedDialog $false $now}
 if($s.Phase -eq 'Due' -and $script:dialog -and -not $script:demoMode -and $now -ge $script:deadline -and ($now-$script:lastAttempt).TotalSeconds -ge 180){
  if(-not $script:shutdownAfter){
   Say-GuardLine shutdown
   $seconds=if($cfg.Voice){[math]::Max(2,$script:lastGuardDuration+1)}else{2}
   $script:shutdownAfter=$now.AddSeconds($seconds)
   $script:dialog.FindName('Info').Text=$script:lastSpokenLine.text
   Write-Event 'Shutdown announcement started; waiting for voice to finish'
  }elseif($now -ge $script:shutdownAfter){
   $script:shutdownAfter=$null;$script:lastAttempt=$now
   if($script:isTestMode){$script:testShutdownRequests++;$ok=$true;Write-Event 'TEST simulated normal shutdown; native API not called'}
   else{$ok=[Wanwan.Power]::ExitWindowsEx(1,0);Write-Event ('Normal shutdown requested; accepted='+$ok+'; error='+[Wanwan.Power]::LastError)}
   $script:dialog.FindName('Info').Text=if($ok){'已请求正常关机。如有未保存提示，请先保存；三分钟后重试。'}else{'关机请求失败（系统错误 '+[Wanwan.Power]::LastError+'）。请保存后从开始菜单关机。'}
  }
 }
 }catch{Write-Event ('Error: '+$_.Exception.Message)}
}
$timer.Add_Tick({Invoke-GuardTick})
. "$PSScriptRoot\Power.ps1"
if($SmokeTest -or $InteractionTest -or $AnimationTest -or $VoiceTest -or $CompanionTest -or $DialogueTest -or $PetTest -or $GuardTest -or $PetControlsTest -or $ShowcaseTest){
 $cfg.Enabled=$false;$cfg.DesktopPet=$false;$ui.PetToggle.IsChecked=$false;$cfg.Voice=$false;$ui.EnabledToggle.IsChecked=$false;$ui.VoiceToggle.IsChecked=$false;$win.Show();$win.UpdateLayout()
 Start-Interaction 'peek'
 $initialFrame=[Windows.Threading.DispatcherFrame]::new();$initialWait=[Windows.Threading.DispatcherTimer]::new();$initialWait.Interval=[timespan]::FromMilliseconds(250);$initialWait.Add_Tick({$initialFrame.Continue=$false;$initialWait.Stop()});$initialWait.Start();[Windows.Threading.Dispatcher]::PushFrame($initialFrame)
 if($GuardTest){. "$PSScriptRoot\Guard.Tests.ps1"}
 if($PetControlsTest){. "$PSScriptRoot\PetControls.Tests.ps1"}
 if($ShowcaseTest){. "$PSScriptRoot\Showcase.Tests.ps1"}
 if($PetTest){. "$PSScriptRoot\DesktopPet.Tests.ps1"}
 if($DialogueTest){. "$PSScriptRoot\Dialogue.Tests.ps1"}
 if($CompanionTest){. "$PSScriptRoot\Companion.Tests.ps1"}
 if($VoiceTest){
  $originalConfigFile=$configFile;$configFile=Join-Path $root 'output\voice-test-settings.json'
  foreach($preset in @('A','B','C','D')){
   if(-not (Test-VoicePresetReady $preset)){throw "Incomplete voice bank: $preset"}
   foreach($line in $script:voiceLines){$resolved=Get-VoiceAsset -Message $line.text -Preset $preset;if(-not $resolved -or -not (Test-Path $resolved)){throw "Voice route failed: $preset/$($line.id)"}}
   $picker=New-VoicePicker;$picker.Show();$picker.UpdateLayout();$picker.FindName('Choose'+$preset).IsChecked=$true
   if(-not $picker.FindName('UseVoice').IsEnabled -or $picker.Tag -ne $preset){throw "Picker selection failed: $preset"}
   $picker.FindName('UseVoice').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
   if($cfg.VoicePreset -ne $preset){throw "Picker commit failed: $preset"}
   $persisted=Get-Content $configFile -Raw -Encoding UTF8|ConvertFrom-Json;if($persisted.VoicePreset -ne $preset){throw "Voice preference persistence failed: $preset"}
   $cfg.Voice=$true;$script:voicePlayer.Volume=0;$script:voiceMediaReady=$false;$audioFrame=[Windows.Threading.DispatcherFrame]::new()
   $mediaReadyHandler=[System.EventHandler]{$script:voiceMediaReady=$true;$audioFrame.Continue=$false};$script:voicePlayer.Add_MediaOpened($mediaReadyHandler)
   Say $script:voiceLines[0].text
   $audioTimeout=[Windows.Threading.DispatcherTimer]::new();$audioTimeout.Interval=[timespan]::FromSeconds(3);$audioTimeout.Add_Tick({$audioFrame.Continue=$false;$audioTimeout.Stop()});$audioTimeout.Start();[Windows.Threading.Dispatcher]::PushFrame($audioFrame);$audioTimeout.Stop();$script:voicePlayer.Remove_MediaOpened($mediaReadyHandler)
   if(-not $script:voiceMediaReady -or $script:lastVoiceAsset -notlike "*\$preset\preview.wav"){throw "Native audio playback failed: $preset"};Stop-Voice;$cfg.Voice=$false
  }
  $unknown=Get-VoiceAsset -Message 'unknown phrase' -Preset 'A';if($unknown){throw 'Unknown phrase must not play unrelated clip'}
  $previewAsset=Get-VoiceAsset -Message 'nickname prefix' -Preset 'B' -LineId preview;if(-not $previewAsset){throw 'Personalized preview route failed'}
  $picker=New-VoicePicker -NoSave;$picker.Show();$picker.UpdateLayout()
  $pickerRender=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$picker.ActualWidth,[int]$picker.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$pickerRender.Render($picker);$pickerEncoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$pickerEncoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($pickerRender));$pickerStream=[IO.File]::Create((Join-Path $root 'output\voice-picker.png'));$pickerEncoder.Save($pickerStream);$pickerStream.Dispose()
  $picker.FindName('ResetVoice').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));if($cfg.VoicePreset -ne 'System'){throw 'Reset voice failed'}
  $configFile=$originalConfigFile
  Write-Output 'Voice tests passed: 44 clip routes, four picker commits and persisted preferences, four native audio opens (muted), personalized preview and reset; real settings unchanged'
 }
 if($AnimationTest){
  if($script:interactionAssets.Count -ne 10){throw 'Ten interaction sheets required'}
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
  Set-CompanionMode '收尾';if($ui.Mood.Text -ne '♡  我陪你慢慢收尾'){throw 'Companion state failed'}
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
if($LifecycleTest){
 $cfg.Enabled=$false;$cfg.Voice=$false;$cfg.DesktopPet=$true
 $script:lifecycleStep=0;$script:backgroundTicks=0
 $timer.Add_Tick({if(-not $win.IsVisible){$script:backgroundTicks++}})
 $lifecycleTimer=[Windows.Threading.DispatcherTimer]::new();$lifecycleTimer.Interval=[timespan]::FromSeconds(2)
 $lifecycleTimer.Add_Tick({
  $script:lifecycleStep++
  switch($script:lifecycleStep){
   1 {Hide-Wanwan}
   2 {if($win.IsVisible -or -not $tray.Visible -or -not $popup.IsVisible -or $script:backgroundTicks -lt 1){throw 'Background lifetime failed after hiding'};Open-Wanwan}
   3 {if(-not $win.IsVisible){throw 'Restore failed'};@{hideKeepsApplicationAlive=$true;trayVisible=$tray.Visible;petVisible=$popup.IsVisible;backgroundTicks=$script:backgroundTicks;restored=$win.IsVisible}|ConvertTo-Json|Set-Content (Join-Path $root 'output\lifecycle-runtime-report.json') -Encoding UTF8;$lifecycleTimer.Stop();$script:quitting=$true;$win.Close()}
  }
 });$lifecycleTimer.Start()
}
$timer.Start()
try{$script:application.Run($win)|Out-Null}finally{$timer.Stop();$tray.Dispose();$script:trayIcon.Dispose();$synth.Dispose();if($script:openSignal){$script:openSignal.Dispose()};if($script:instanceMutex){$script:instanceMutex.ReleaseMutex();$script:instanceMutex.Dispose()}}
