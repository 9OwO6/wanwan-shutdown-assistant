# 桌面常驻小头像，提醒时展开。复用同一角色动作，不抢当前应用的键盘焦点。
$script:petExpanded=$false;$script:petDragging=$false
# 桌宠尺寸：晚晚本身（透明、无边框）。提醒时在她头顶冒一个气泡，窗口向左上方变大，晚晚的位置不动。
$script:petSize=210;$script:petBubbleWidth=390;$script:petBubbleHeight=470
function Limit-PetPosition([double]$Left,[double]$Top,$Area,[double]$Width,[double]$Height){
 return @{Left=[math]::Max($Area.Left,[math]::Min($Left,$Area.Right-$Width));Top=[math]::Max($Area.Top,[math]::Min($Top,$Area.Bottom-$Height))}
}
function Set-PetPosition([double]$Left,[double]$Top){
 $area=Get-DesktopWorkArea $script:popup
 $position=Limit-PetPosition $Left $Top $area $script:popup.Width $script:popup.Height
 $script:popup.Left=$position.Left;$script:popup.Top=$position.Top
}
function Save-PetPosition {
 # 记的是晚晚本身（右下角那块）的位置，展开气泡时她不跟着跳。
 $cfg.PetLeft=$script:popup.Left+$script:popup.Width-$script:petSize;$cfg.PetTop=$script:popup.Top+$script:popup.Height-$script:petSize
 Save-Config
}
function Hide-DesktopPet {
 $cfg.DesktopPet=$false;$ui.PetToggle.IsChecked=$false
 if($script:popup){$script:popup.Close()};Save-Config
 $ui.Feedback.Text='桌宠已隐藏；定时守护状态没有改变'
}
function Get-PetGuardStatus {
 $state=Get-NightState (Get-Date) $cfg
 if(-not $cfg.Enabled){return '到点守护未开启'}elseif($cfg.Cancelled -eq $state.Key){return '今晚已取消守护'}else{return '到点'+(Get-GuardActionName)+'已开启 ♡'}
}
function Update-PetGuardStatus {
 # 平时不显示文字；鼠标放到晚晚身上时，头顶的小气泡里写着今晚的状态。
 if(-not $script:popup -or -not $script:petStatusText){return}
 $script:petStatusText.Text=Get-PetGuardStatus
 $script:petStatusText.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($cfg.Enabled){'#7B8B74'}else{'#B76D79'}))
 $script:petPromiseText.Text='约好 '+(Get-NightState (Get-Date) $cfg).Bed.ToString('HH:mm')+' 休息'
}
function Move-PetDrag($Cursor,[bool]$Pressed){
 if(-not $script:petDragArmed -or -not $Pressed){return}
 $delta=[Windows.Vector]::new($Cursor.X-$script:petDragStart.X,$Cursor.Y-$script:petDragStart.Y)
 $source=[Windows.PresentationSource]::FromVisual($script:popup);if($source){$delta=$source.CompositionTarget.TransformFromDevice.Transform($delta)}
 if($delta.Length -ge 4){$script:petDragging=$true}
 if($script:petDragging){Set-PetPosition ($script:petDragLeft+$delta.X) ($script:petDragTop+$delta.Y)}
}
function Invoke-PetTap {
 # 单击晚晚：戳她一下，她在头顶的气泡里回你一句。
 $poke=Invoke-Poke;Show-DesktopPet $poke.text '晚晚';Extend-DesktopPetLifetime
}
function New-DesktopPet {
 if($script:popup){return}
 [xml]$px=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="晚晚 · 桌面陪伴" Width="210" Height="210" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Topmost="True" FontFamily="Microsoft YaHei UI">
 <Grid>
  <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="210"/></Grid.RowDefinitions>
  <Border x:Name="ExpandedPet" Visibility="Collapsed" VerticalAlignment="Bottom" Margin="8,8,8,0" Background="#FFF7FA" CornerRadius="24" Padding="20,16" BorderBrush="#E7C8D7" BorderThickness="1"><Border.Effect><DropShadowEffect Color="#805065" BlurRadius="16" ShadowDepth="3" Opacity="0.14"/></Border.Effect><StackPanel>
   <DockPanel x:Name="PetDragHandle" Cursor="SizeAll"><Button x:Name="PopupClose" DockPanel.Dock="Right" Content="收起 ×" Padding="8,3" FontSize="11" Background="#F3E5EC"/><TextBlock x:Name="PetStatus" Text="晚晚来啦" FontSize="12" Foreground="#A7738C" VerticalAlignment="Center"/></DockPanel>
   <TextBlock x:Name="PopupText" TextWrapping="Wrap" FontSize="16" Foreground="#57424F" LineHeight="27" Margin="0,12,0,12"/>
   <DockPanel><Button x:Name="PetOpen" DockPanel.Dock="Right" Content="打开晚晚 ↗" Padding="10,6" FontSize="11" Background="#EFE1E8"/><TextBlock x:Name="PetPromise" FontSize="11" Foreground="#AD919F" VerticalAlignment="Center"/></DockPanel>
  </StackPanel></Border>
  <Path x:Name="BubbleTail" Grid.Row="1" Visibility="Collapsed" Data="M 0,0 L 22,0 L 11,13 Z" Fill="#FFF7FA" HorizontalAlignment="Right" Margin="0,-1,94,1"/>
  <Grid x:Name="CompactPet" Grid.Row="2" Width="210" Height="210" HorizontalAlignment="Right" Background="{x:Null}">
   <Image x:Name="DeskBack" Stretch="Uniform" IsHitTestVisible="False"/><Image x:Name="PetAvatar" Stretch="Uniform" Cursor="Hand"/><Image x:Name="DeskFront" Stretch="Uniform" IsHitTestVisible="False"/><Image x:Name="DeskCup" Stretch="Uniform" IsHitTestVisible="False"/>
  </Grid>
 </Grid>
</Window>
'@
 $script:popup=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($px));$script:popup.Resources.MergedDictionaries.Add($win.Resources);Set-WanwanIcon $script:popup
 # 桌宠就是会动的晚晚：平时做自己的小动作，越晚越困（见 Behavior.ps1）；提醒时的手势也在她身上做。
 $script:petAvatarSurface=Register-CharacterSurface ($script:popup.FindName('PetAvatar')) $null $script:popup
 if($script:deskScene){
  # 书桌场景：人物夹在背景和桌面之间；不加立绘用的上下渐隐，也不做身体位移。
  $script:petAvatarSurface.Desk=$true;$script:petAvatarSurface.Image.OpacityMask=$null;$script:petAvatarSurface.Static=$true;$script:petAvatarSurface.Front=$script:popup.FindName('DeskFront');$script:petAvatarSurface.Back=$script:popup.FindName('DeskBack');$script:petAvatarSurface.Cup=$script:popup.FindName('DeskCup')
  $script:popup.FindName('DeskBack').Source=$script:deskScene.Back;$script:popup.FindName('DeskFront').Source=$script:deskScene.Front;$script:popup.FindName('DeskCup').Source=$script:deskScene.Cup
 }
 $script:popupSurface=$script:petAvatarSurface
 # 鼠标放上去时的小气泡：今晚的状态和约好的时间。
 [xml]$tx=@'
<ToolTip xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Placement="Top" HasDropShadow="False">
 <ToolTip.Template><ControlTemplate TargetType="ToolTip"><Border CornerRadius="16" Background="#FFF7FA" BorderBrush="#E7C8D7" BorderThickness="1" Padding="14,8"><ContentPresenter/></Border></ControlTemplate></ToolTip.Template>
 <StackPanel><TextBlock FontSize="12" FontFamily="Microsoft YaHei UI"/><TextBlock FontSize="11" FontFamily="Microsoft YaHei UI" Foreground="#AD919F" Margin="0,2,0,0"/><TextBlock FontSize="10" FontFamily="Microsoft YaHei UI" Foreground="#C0A6B3" Margin="0,4,0,0" Text="点她一下 · 双击打开 · 右键更多"/></StackPanel>
</ToolTip>
'@
 $tip=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($tx));$script:petStatusText=$tip.Content.Children[0];$script:petPromiseText=$tip.Content.Children[1]
 $avatar=$script:popup.FindName('PetAvatar');$avatar.ToolTip=$tip;[Windows.Controls.ToolTipService]::SetInitialShowDelay($avatar,500)
 $compact=$script:popup.FindName('CompactPet')
 # 按住拖动；点一下戳她；双击打开晚晚。
 $script:petTapTimer=[Windows.Threading.DispatcherTimer]::new();$script:petTapTimer.Interval=[timespan]::FromMilliseconds([math]::Min(500,[Windows.Forms.SystemInformation]::DoubleClickTime))
 $script:petTapTimer.Add_Tick({$script:petTapTimer.Stop();if($script:popup){Invoke-PetTap}})
 $compact.Add_PreviewMouseDown({param($sender,$e)
  if($e.ChangedButton -ne [Windows.Input.MouseButton]::Left -or $e.OriginalSource -isnot [Windows.Controls.Image]){return}
  if($e.ClickCount -ge 2){$script:petTapTimer.Stop();$script:petDragArmed=$false;Open-Wanwan;$e.Handled=$true;return}
  $script:petDragStart=[Windows.Forms.Cursor]::Position;$script:petDragLeft=$script:popup.Left;$script:petDragTop=$script:popup.Top;$script:petDragging=$false;$script:petDragArmed=$true
  $sender.CaptureMouse()|Out-Null;$e.Handled=$true
 })
 $compact.Add_PreviewMouseMove({param($sender,$e)
  if(-not $script:petDragArmed){return}
  Move-PetDrag ([Windows.Forms.Cursor]::Position) ($e.LeftButton -eq [Windows.Input.MouseButtonState]::Pressed);$e.Handled=$true
 })
 $compact.Add_PreviewMouseUp({param($sender,$e)
  if($e.ChangedButton -eq [Windows.Input.MouseButton]::Left -and $script:petDragArmed){$moved=$script:petDragging;$script:petDragArmed=$false;$sender.ReleaseMouseCapture();$script:petDragging=$false;if($moved){Save-PetPosition}else{$script:petTapTimer.Stop();$script:petTapTimer.Start()};$e.Handled=$true}
 })
 $compact.Add_LostMouseCapture({$script:petDragArmed=$false;$script:petDragging=$false})
 $context=[Windows.Controls.ContextMenu]::new()
 foreach($entry in @(@('打开晚晚',{Open-Wanwan}),@('设置…',{Open-Settings}),@('隐藏桌宠（守护继续）',{Hide-DesktopPet}))){$item=[Windows.Controls.MenuItem]::new();$item.Header=$entry[0];$item.Add_Click($entry[1]);$context.Items.Add($item)|Out-Null}
 $compact.ContextMenu=$context
 $script:popup.FindName('PopupClose').Add_Click({Stop-Voice;Complete-DesktopPetReminder})
 $script:popup.FindName('PetOpen').Add_Click({Open-Wanwan})
 $script:popup.FindName('PetDragHandle').Add_MouseLeftButtonDown({param($sender,$e) if($e.OriginalSource -is [Windows.Controls.TextBlock]){$script:petDragging=$true;try{$script:popup.DragMove();Set-PetPosition $script:popup.Left $script:popup.Top;Save-PetPosition}finally{$script:petDragging=$false}}})
 $script:popup.Add_Closed({param($sender,$e) $script:surfaces=@($script:surfaces|Where-Object {$_.Window -ne $sender});if($script:petTapTimer){$script:petTapTimer.Stop()};$script:popup=$null;$script:popupSurface=$null;$script:petAvatarSurface=$null;$script:petStatusText=$null;$script:petExpanded=$false})
}
function Show-DesktopPet {
 param([string]$Caption='',[string]$Status='晚晚来啦',[switch]$Compact)
 if($script:dialog){return}
 New-DesktopPet
 $script:petExpanded=-not $Compact
 $bubble=if($Compact){[Windows.Visibility]::Collapsed}else{[Windows.Visibility]::Visible}
 $script:popup.FindName('ExpandedPet').Visibility=$bubble;$script:popup.FindName('BubbleTail').Visibility=$bubble
 [Windows.Controls.ToolTipService]::SetIsEnabled($script:popup.FindName('PetAvatar'),[bool]$Compact)
 $script:popup.Width=if($Compact){$script:petSize}else{$script:petBubbleWidth};$script:popup.Height=if($Compact){$script:petSize}else{$script:petBubbleHeight}
 $script:popup.FindName('PopupText').Text=$Caption;$script:popup.FindName('PetStatus').Text=$Status
 $script:popup.FindName('PetPromise').Text='约好 '+(Get-NightState (Get-Date) $cfg).Bed.ToString('HH:mm')+' 休息'
 if($cfg.ContainsKey('PetLeft') -and $cfg.ContainsKey('PetTop')){Set-PetPosition ([double]$cfg.PetLeft+$script:petSize-$script:popup.Width) ([double]$cfg.PetTop+$script:petSize-$script:popup.Height)}else{Place-DesktopWindow $script:popup}
 Update-PetGuardStatus;$script:popup.Show()
 $script:popupUntil=if($Compact){[double]::PositiveInfinity}else{$script:animationClock.ElapsedMilliseconds+12000}
 if($script:motionEnabled -and -not $Compact){Animate-Double ($script:popup.FindName('ExpandedPet')) ([Windows.UIElement]::OpacityProperty) 0 1 .28}
 else{$script:popup.FindName('ExpandedPet').BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$script:popup.FindName('ExpandedPet').Opacity=1}
 $script:popup.Opacity=1
}
function Extend-DesktopPetLifetime {
 $seconds=12
 if($script:voiceUntil -gt (Get-Date)){$seconds=[math]::Max($seconds,($script:voiceUntil-(Get-Date)).TotalSeconds+2)}
 $script:popupUntil=$script:animationClock.ElapsedMilliseconds+$seconds*1000
}
function Complete-DesktopPetReminder {
 if(-not $script:popup){return}
 if($cfg.DesktopPet -and -not $script:quitting -and -not $script:dialog){Show-DesktopPet -Compact}
 else{$script:popup.Close()}
}
function Say-ClockReminder {
 param([datetime]$Now=(Get-Date),[string]$Cue='early',[switch]$Demo)
 # 晚晚陪伴：到点时你还在打游戏 / 看视频 / 工作，就说对应的那句。
 $companionCue=if($Cue -eq 'bed' -and -not $Demo){Get-CompanionBedtimeCue}else{''}
 $line=if($companionCue){$l=Speak-Line (Get-CompanionLine $companionCue);$l|Add-Member -NotePropertyName time -NotePropertyValue $Now.ToString('HH:mm') -Force;$l}else{Speak-Line (Get-ClockReminder $Now $Cue)};$message=$line.text
 if($script:dialog){$script:dialog.FindName('Info').Text=$message;$script:dialog.FindName('ReminderTime').Text='晚晚 · '+$line.time}
 else{Show-DesktopPet $message $(if($Demo){'提醒体验 · '+$line.time}else{'晚晚 · '+$line.time});Extend-DesktopPetLifetime}
}
$ui.PetPreview.Add_Click({Say-ClockReminder -Now (Get-Date) -Cue early -Demo})
$ui.PetToggle.IsChecked=[bool]$cfg.DesktopPet
$ui.PetToggle.Add_Checked({$cfg.DesktopPet=$true;if(-not $script:dialog){Show-DesktopPet -Compact}})
$ui.PetToggle.Add_Unchecked({$cfg.DesktopPet=$false;if($script:popup -and -not $script:petExpanded){$script:popup.Close()}})
$win.Add_ContentRendered({if($cfg.DesktopPet -and -not $script:popup){Show-DesktopPet -Compact}})
