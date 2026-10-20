# 桌面常驻小头像，提醒时展开。复用同一角色动作，不抢当前应用的键盘焦点。
$script:petExpanded=$false;$script:petDragging=$false
function Limit-PetPosition([double]$Left,[double]$Top,$Area,[double]$Width,[double]$Height){
 return @{Left=[math]::Max($Area.Left,[math]::Min($Left,$Area.Right-$Width));Top=[math]::Max($Area.Top,[math]::Min($Top,$Area.Bottom-$Height))}
}
function Set-PetPosition([double]$Left,[double]$Top){
 $area=Get-DesktopWorkArea $script:popup
 $position=Limit-PetPosition $Left $Top $area $script:popup.Width $script:popup.Height
 $script:popup.Left=$position.Left;$script:popup.Top=$position.Top
}
function Save-PetPosition {
 $cfg.PetLeft=$script:popup.Left+$script:popup.Width-142;$cfg.PetTop=$script:popup.Top+$script:popup.Height-180
 Save-Config
}
function Hide-DesktopPet {
 $cfg.DesktopPet=$false;$ui.PetToggle.IsChecked=$false
 if($script:popup){$script:popup.Close()};Save-Config
 $ui.Feedback.Text='桌宠已隐藏；定时守护状态没有改变'
}
function Update-PetGuardStatus {
 if(-not $script:popup){return}
 $state=Get-NightState (Get-Date) $cfg
 $script:popup.FindName('CompactStatus').Text=if(-not $cfg.Enabled){'到点守护未开启'}elseif($cfg.Cancelled -eq $state.Key){'今晚已取消守护'}else{'到点'+(Get-GuardActionName)+'已开启 ♡'}
 $script:popup.FindName('CompactStatus').Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($cfg.Enabled){'#7B8B74'}else{'#B76D79'}))
}
function Move-PetDrag($Cursor,[bool]$Pressed){
 if(-not $script:petDragArmed -or -not $Pressed){return}
 $delta=[Windows.Vector]::new($Cursor.X-$script:petDragStart.X,$Cursor.Y-$script:petDragStart.Y)
 $source=[Windows.PresentationSource]::FromVisual($script:popup);if($source){$delta=$source.CompositionTarget.TransformFromDevice.Transform($delta)}
 if($delta.Length -ge 4){$script:petDragging=$true}
 if($script:petDragging){Set-PetPosition ($script:petDragLeft+$delta.X) ($script:petDragTop+$delta.Y)}
}
function New-DesktopPet {
 if($script:popup){return}
 [xml]$px=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="晚晚 · 桌面陪伴" Width="142" Height="180" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Topmost="True" FontFamily="Microsoft YaHei UI">
 <Grid>
  <Grid x:Name="CompactPet" Margin="7"><Border CornerRadius="24" Background="#FDF4F8" BorderBrush="#E9CFDB" BorderThickness="1" Padding="8,5"><StackPanel>
   <DockPanel><Button x:Name="CompactHide" DockPanel.Dock="Right" Content="×" Padding="7,0" FontSize="15" ToolTip="隐藏桌宠，后台守护继续运行"/><TextBlock Text="拖动头像移动" FontSize="10" Foreground="#A37189" VerticalAlignment="Center"/></DockPanel>
   <Image x:Name="PetAvatar" Width="84" Height="84" Stretch="Uniform" Cursor="SizeAll" ToolTip="按住拖动；轻点打开晚晚；右键有更多操作"/>
   <TextBlock x:Name="CompactStatus" Text="到点守护未开启" HorizontalAlignment="Center" FontSize="11" Margin="0,3,0,5"/>
   <Button x:Name="CompactOpen" Content="打开晚晚 ↗" Padding="8,4" FontSize="11"/>
  </StackPanel></Border></Grid>
  <Grid x:Name="ExpandedPet" Visibility="Collapsed" Margin="12,10,12,8">
   <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="18"/><RowDefinition Height="*"/></Grid.RowDefinitions>
   <Border Background="#FFF7FA" CornerRadius="24" Padding="20,16" BorderBrush="#E7C8D7" BorderThickness="1"><Border.Effect><DropShadowEffect Color="#805065" BlurRadius="16" ShadowDepth="3" Opacity="0.14"/></Border.Effect><StackPanel>
    <DockPanel x:Name="PetDragHandle" Cursor="SizeAll"><Button x:Name="PopupClose" DockPanel.Dock="Right" Content="收起 ×" Padding="8,3" FontSize="11" Background="#F3E5EC"/><TextBlock x:Name="PetStatus" Text="晚晚来啦" FontSize="12" Foreground="#A7738C" VerticalAlignment="Center"/></DockPanel>
    <TextBlock x:Name="PopupText" TextWrapping="Wrap" FontSize="16" Foreground="#57424F" LineHeight="27" Margin="0,12,0,12"/>
    <DockPanel><Button x:Name="PetOpen" DockPanel.Dock="Right" Content="打开晚晚 ↗" Padding="10,6" FontSize="11" Background="#EFE1E8"/><TextBlock x:Name="PetPromise" FontSize="11" Foreground="#AD919F" VerticalAlignment="Center"/></DockPanel>
   </StackPanel></Border>
   <Path Grid.Row="1" Data="M 0,0 L 22,0 L 11,13 Z" Fill="#FFF7FA" HorizontalAlignment="Right" Margin="0,-1,83,0"/>
   <Grid Grid.Row="2" HorizontalAlignment="Right" Width="232"><Image x:Name="PopupPortrait" Stretch="Uniform" Cursor="Hand" ToolTip="轻轻点一下，收下晚晚的小回应"/><Image x:Name="PopupFade" Stretch="Uniform" Opacity="0" IsHitTestVisible="False"/></Grid>
  </Grid>
 </Grid>
</Window>
'@
 $script:popup=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($px));$script:popup.Resources.MergedDictionaries.Add($win.Resources);Set-WanwanIcon $script:popup
 $script:popup.FindName('PetAvatar').Source=[Windows.Media.Imaging.BitmapImage]::new([uri](Join-Path $root 'assets\icons\wanwan-256.png'))
 $script:popupSurface=Register-CharacterSurface ($script:popup.FindName('PopupPortrait')) ($script:popup.FindName('PopupFade')) $script:popup
 $compact=$script:popup.FindName('CompactPet')
 $compact.Add_PreviewMouseDown({param($sender,$e)
  if($e.ChangedButton -ne [Windows.Input.MouseButton]::Left -or $e.OriginalSource -isnot [Windows.Controls.Image]){return}
  $script:petDragStart=[Windows.Forms.Cursor]::Position;$script:petDragLeft=$script:popup.Left;$script:petDragTop=$script:popup.Top;$script:petDragging=$false;$script:petDragArmed=$true
  $sender.CaptureMouse()|Out-Null;$e.Handled=$true
 })
 $compact.Add_PreviewMouseMove({param($sender,$e)
  if(-not $script:petDragArmed){return}
  Move-PetDrag ([Windows.Forms.Cursor]::Position) ($e.LeftButton -eq [Windows.Input.MouseButtonState]::Pressed);$e.Handled=$true
 })
 $compact.Add_PreviewMouseUp({param($sender,$e)
  if($e.ChangedButton -eq [Windows.Input.MouseButton]::Left -and $script:petDragArmed){$moved=$script:petDragging;$script:petDragArmed=$false;$sender.ReleaseMouseCapture();$script:petDragging=$false;if($moved){Save-PetPosition}else{Open-Wanwan};$e.Handled=$true}
 })
 $compact.Add_LostMouseCapture({$script:petDragArmed=$false;$script:petDragging=$false})
 $script:popup.FindName('CompactOpen').Add_Click({Open-Wanwan})
 $script:popup.FindName('CompactHide').Add_Click({Hide-DesktopPet})
 $context=[Windows.Controls.ContextMenu]::new()
 $contextOpen=[Windows.Controls.MenuItem]::new();$contextOpen.Header='打开晚晚';$contextOpen.Add_Click({Open-Wanwan});$context.Items.Add($contextOpen)|Out-Null
 $contextHide=[Windows.Controls.MenuItem]::new();$contextHide.Header='隐藏桌宠（守护继续）';$contextHide.Add_Click({Hide-DesktopPet});$context.Items.Add($contextHide)|Out-Null
 $compact.ContextMenu=$context
 $script:popup.FindName('PopupClose').Add_Click({Stop-Voice;Complete-DesktopPetReminder})
 $script:popup.FindName('PetOpen').Add_Click({Open-Wanwan})
 $script:popup.FindName('PopupPortrait').Add_MouseLeftButtonDown({$poke=Invoke-Poke;Show-DesktopPet $poke.text;Extend-DesktopPetLifetime})
 $script:popup.FindName('PetDragHandle').Add_MouseLeftButtonDown({param($sender,$e) if($e.OriginalSource -is [Windows.Controls.TextBlock]){$script:petDragging=$true;try{$script:popup.DragMove();Set-PetPosition $script:popup.Left $script:popup.Top;Save-PetPosition}finally{$script:petDragging=$false}}})
 $script:popup.Add_Closed({param($sender,$e) $script:surfaces=@($script:surfaces|Where-Object {$_.Window -ne $sender});$script:popup=$null;$script:popupSurface=$null;$script:petExpanded=$false})
}
function Show-DesktopPet {
 param([string]$Caption='',[string]$Status='晚晚来啦',[switch]$Compact)
 if($script:dialog){return}
 New-DesktopPet
 $script:petExpanded=-not $Compact
 $script:popup.FindName('CompactPet').Visibility=if($Compact){[Windows.Visibility]::Visible}else{[Windows.Visibility]::Collapsed}
 $script:popup.FindName('ExpandedPet').Visibility=if($Compact){[Windows.Visibility]::Collapsed}else{[Windows.Visibility]::Visible}
 $script:popup.Width=if($Compact){142}else{390};$script:popup.Height=if($Compact){180}else{420}
 $script:popup.FindName('PopupText').Text=$Caption;$script:popup.FindName('PetStatus').Text=$Status
 $script:popup.FindName('PetPromise').Text='约好 '+(Get-NightState (Get-Date) $cfg).Bed.ToString('HH:mm')+' 休息'
 if($cfg.ContainsKey('PetLeft') -and $cfg.ContainsKey('PetTop')){Set-PetPosition ([double]$cfg.PetLeft+142-$script:popup.Width) ([double]$cfg.PetTop+180-$script:popup.Height)}else{Place-DesktopWindow $script:popup}
 Update-PetGuardStatus;$script:popup.Show()
 $script:popupUntil=if($Compact){[double]::PositiveInfinity}else{$script:animationClock.ElapsedMilliseconds+12000}
 if($script:motionEnabled -and -not $Compact){Animate-Double $script:popup ([Windows.UIElement]::OpacityProperty) 0 1 .28}
 else{$script:popup.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$script:popup.Opacity=1}
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
 $line=Speak-Line (Get-ClockReminder $Now $Cue);$message=$line.text
 if($script:dialog){$script:dialog.FindName('Info').Text=$message;$script:dialog.FindName('ReminderTime').Text='晚晚 · '+$line.time}
 else{Show-DesktopPet $message $(if($Demo){'提醒体验 · '+$line.time}else{'晚晚 · '+$line.time});Extend-DesktopPetLifetime}
}
$ui.PetPreview.Add_Click({Say-ClockReminder -Now (Get-Date) -Cue early -Demo})
$ui.PetToggle.IsChecked=[bool]$cfg.DesktopPet
$ui.PetToggle.Add_Checked({$cfg.DesktopPet=$true;if(-not $script:dialog){Show-DesktopPet -Compact}})
$ui.PetToggle.Add_Unchecked({$cfg.DesktopPet=$false;if($script:popup -and -not $script:petExpanded){$script:popup.Close()}})
$win.Add_ContentRendered({if($cfg.DesktopPet -and -not $script:popup){Show-DesktopPet -Compact}})
