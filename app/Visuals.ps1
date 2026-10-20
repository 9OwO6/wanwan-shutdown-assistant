# 透明角色关键帧；所有窗口共享动作时钟，托盘提醒仍可播放。
$script:motionEnabled=-not [bool]$cfg.ReducedMotion
$script:visualMode='陪伴';$script:frameIndex=-1
$script:interactionCatalog=Get-Content (Join-Path $root 'assets\interactions.json') -Raw -Encoding UTF8|ConvertFrom-Json
$script:interactionAssets=@{};$script:surfaces=@();$script:popup=$null;$script:gallery=$null
$script:animationClock=[Diagnostics.Stopwatch]::StartNew()
$script:action=$null;$script:actionHistory=[Collections.Generic.List[object]]::new()
foreach($item in $script:interactionCatalog){
 $cells=@()
 # 加载已经过轮廓检查的独立透明帧，避免运行时均分图集串入隔壁手臂。
 for($i=0;$i -lt 4;$i++){
  $path=Join-Path $root ('assets\frames\'+$item.id+'\'+$i+'.png')
  if(-not (Test-Path $path)){throw ('Missing reviewed character frame: '+$item.id+'/'+$i)}
  $cell=[Windows.Media.Imaging.BitmapImage]::new();$cell.BeginInit();$cell.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad;$cell.UriSource=[uri]$path;$cell.EndInit();$cell.Freeze();$cells+=,$cell
 }
 $script:interactionAssets[$item.id]=$cells
}
$script:frames=$script:interactionAssets['peek']
# 书桌场景（坐在电脑前的晚晚）：素材到位后放在 assets/desk/，桌宠小窗用它；主窗口仍用立绘。
$script:deskScene=$null
$deskManifest=Join-Path $root 'assets\desk\desk.json'
if(Test-Path $deskManifest){
 $desk=Get-Content $deskManifest -Raw -Encoding UTF8|ConvertFrom-Json
 function Read-DeskImage([string]$Relative){$path=Join-Path $root ('assets\desk\'+$Relative);if(-not (Test-Path $path)){return $null};$image=[Windows.Media.Imaging.BitmapImage]::new();$image.BeginInit();$image.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad;$image.UriSource=[uri]$path;$image.EndInit();$image.Freeze();return $image}
 # 叠放顺序：背景（含书桌后半）→ 晚晚 → 书桌前沿 → 杯子。台灯开 / 关各一套背景和前沿。
 $script:deskScene=@{Back=(Read-DeskImage $desk.layers.back);BackLampOff=(Read-DeskImage $desk.layers.back_lamp_off);Front=(Read-DeskImage $desk.layers.front);FrontLampOff=(Read-DeskImage $desk.layers.front_lamp_off);Cup=(Read-DeskImage $desk.layers.cup);LampOn=$true;NoCup=@{}}
 foreach($behavior in $desk.behaviors.PSObject.Properties){
  $cells=@();for($i=0;$i -lt 4;$i++){$cell=Read-DeskImage ('character\'+$behavior.Name+'\'+$i+'.png');if(-not $cell){throw ('Missing desk frame: '+$behavior.Name+'/'+$i)};$cells+=,$cell}
  $script:interactionAssets['desk-'+$behavior.Name]=$cells
  if($behavior.Value.hide_cup){$script:deskScene.NoCup['desk-'+$behavior.Name]=$true}
  $script:interactionCatalog+=[pscustomobject]@{id='desk-'+$behavior.Name;name=$behavior.Value.name;symbol='·';caption='';frames=@($behavior.Value.frames);step=[int]$behavior.Value.step}
 }
}
function Animate-Double($target,$property,[double]$from,[double]$to,[double]$seconds,[bool]$loop=$false){
 $a=[Windows.Media.Animation.DoubleAnimation]::new($from,$to,[Windows.Duration]::new([timespan]::FromSeconds($seconds)));$a.EasingFunction=[Windows.Media.Animation.SineEase]::new()
 if($loop){$a.AutoReverse=$true;$a.RepeatBehavior=[Windows.Media.Animation.RepeatBehavior]::Forever};$target.BeginAnimation($property,$a)
}
function Register-CharacterSurface($image,$fade,$window){
 $mask=[Windows.Media.LinearGradientBrush]::new();$mask.StartPoint=[Windows.Point]::new(.5,0);$mask.EndPoint=[Windows.Point]::new(.5,1)
 $mask.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Colors]::Transparent,0));$mask.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Colors]::White,.025));$mask.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Colors]::White,.96));$mask.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Colors]::Transparent,1))
 $image.OpacityMask=$mask;if($fade){$fade.OpacityMask=$mask}
 $group=[Windows.Media.TransformGroup]::new();$scale=[Windows.Media.ScaleTransform]::new(1,1);$rotate=[Windows.Media.RotateTransform]::new();$move=[Windows.Media.TranslateTransform]::new()
 $group.Children.Add($scale);$group.Children.Add($rotate);$group.Children.Add($move)
 $image.RenderTransformOrigin=[Windows.Point]::new(.5,.8);$image.RenderTransform=$group
 if($fade){$fade.RenderTransformOrigin=$image.RenderTransformOrigin;$fade.RenderTransform=$group}
 $surface=@{Image=$image;Fade=$fade;Window=$window;Scale=$scale;Rotate=$rotate;Move=$move;Key=''}
 $script:surfaces+=,$surface
 if($script:frames){$image.Source=$script:frames[0]}
 return $surface
}
function Set-SurfaceFrame($surface,[string]$id,[int]$index){
 # 书桌动作只在桌宠小窗里用；主窗口等立绘画面换成对应的站姿动作。
 if($id -like 'desk-*' -and -not $surface.Desk){$id=if($script:BehaviorFallback -and $script:BehaviorFallback.ContainsKey($id.Substring(5))){$script:BehaviorFallback[$id.Substring(5)]}else{'peek'}}
 # 反过来，桌宠小窗有书桌场景时，提醒用的站姿动作换成书桌上的近似动作。
 if($surface.Desk -and $id -notlike 'desk-*'){$deskId='desk-'+$(switch($id){'water'{'drink'}'yawn'{'yawn'}'goodnight'{'sleep'}default{'write'}});if($script:interactionAssets.ContainsKey($deskId)){$id=$deskId}}
 if(-not $script:interactionAssets.ContainsKey($id)){return}
 $key=$id+':'+$index;if($surface.Key -eq $key){return}
 # 只在更换动作时淡化；姿态间直接切帧，避免两张脸重叠。
 if($surface.Fade -and $script:motionEnabled -and $surface.Image.Source -and $surface.Key.Split(':')[0] -ne $id){$surface.Fade.Source=$surface.Image.Source;Animate-Double $surface.Fade ([Windows.UIElement]::OpacityProperty) 1 0 .12}
 $surface.Image.Source=$script:interactionAssets[$id][$index];$surface.Key=$key
 if($surface.Desk){Update-DeskFront $surface $id}
}
function Update-DeskFront($surface,[string]$id){
 # 前景层：喝水时杯子在她手里，桌上那只要藏起来；睡着时台灯关掉。
 if(-not $script:deskScene -or -not $surface.Front){return}
 $on=[bool]$script:deskScene.LampOn -or -not $script:deskScene.FrontLampOff
 $front=if($on){$script:deskScene.Front}else{$script:deskScene.FrontLampOff};if($surface.Front.Source -ne $front){$surface.Front.Source=$front}
 $back=if($on -or -not $script:deskScene.BackLampOff){$script:deskScene.Back}else{$script:deskScene.BackLampOff};if($surface.Back.Source -ne $back){$surface.Back.Source=$back}
 $surface.Cup.Visibility=if($script:deskScene.NoCup[$id] -or -not $script:deskScene.Cup){[Windows.Visibility]::Hidden}else{[Windows.Visibility]::Visible}
}
function Set-CharacterFrame([int]$index){Set-SurfaceFrame $script:mainSurface 'peek' $index;$script:frameIndex=$index}
function Show-CompanionPopup([string]$caption){Show-DesktopPet $caption}
function Start-Interaction {
 param([string]$Id,[string]$Caption='', [switch]$Popup)
 $item=$script:interactionCatalog|Where-Object {$_.id -eq $Id}|Select-Object -First 1
 if(-not $item -or -not $script:interactionAssets.ContainsKey($Id)){return}
 if(-not $Caption){$Caption=$item.caption}
 $script:action=@{Item=$item;Start=$script:animationClock.ElapsedMilliseconds;End=$script:animationClock.ElapsedMilliseconds+($item.frames.Count*$item.step);Caption=$Caption}
 $ui.Message.Text=$Caption;$ui.Mood.Text=$item.symbol+'  '+$item.name
 if($script:gallery){$gallery.FindName('SceneTitle').Text=$item.name;$gallery.FindName('SceneCaption').Text=$Caption}
 if($Popup){Show-CompanionPopup $Caption;$script:popupUntil=$script:animationClock.ElapsedMilliseconds+[math]::Max(5500,($item.frames.Count*$item.step)+1200)}
 foreach($surface in $script:surfaces){Set-SurfaceFrame $surface $Id $(if($script:motionEnabled){0}else{2})}
 $script:frameIndex=0
 $script:actionHistory.Add(@{id=$Id;popup=[bool]$Popup;time=$script:animationClock.ElapsedMilliseconds})
 if($script:actionHistory.Count -gt 100){$script:actionHistory.RemoveAt(0)}
}
function Invoke-ReminderInteraction([string]$message,[string]$lineId){
 $id=switch($lineId){'preview'{'peek'}'early'{'water'}'soon'{'stretch'}'bed'{'nod'}'final'{'yawn'}'dialog'{'goodnight'}'defer'{'nod'}'cancel'{'heart'}'goodnight'{'goodnight'}'bye'{'wave'}'hello'{'pat'}default{'peek'}}
 # 主窗口可见时在画面里回应；收起后通过独立小窗提醒。
 Start-Interaction $id $message -Popup:((-not $win.IsVisible -or $win.WindowState -eq [Windows.WindowState]::Minimized) -and -not $script:dialog)
}
function Set-CompanionMode([string]$mode){
 $script:visualMode=$mode
 $ui.Mood.Text=switch($mode){'晚安'{'☾  该睡啦'}'收尾'{'✦  快到睡觉时间了'}default{'✦  晚晚在这儿'}}
 $ui.Headline.Text=switch($mode){'晚安'{'今天就到这里吧。'}'收尾'{'该准备收尾啦。'}default{'早点睡，明天更有精神。'}}
 $ui.Message.Text=switch($mode){'晚安'{'保存好手上的东西，去睡吧。'}'收尾'{'把要紧的存好，别再开新的事情了。'}default{'设好睡觉时间，到点晚晚会来提醒你。'}}
}
function Set-Motion([bool]$enabled){
 $script:motionEnabled=$enabled
 if(-not $enabled -and $script:popup){$script:popup.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$script:popup.Opacity=1}
 foreach($surface in $script:surfaces){$surface.Scale.ScaleX=1;$surface.Scale.ScaleY=1;$surface.Rotate.Angle=0;$surface.Move.X=0;$surface.Move.Y=0;if($surface.Fade){$surface.Fade.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$surface.Fade.Opacity=0}}
 if($script:action -and -not $enabled){foreach($surface in $script:surfaces){Set-SurfaceFrame $surface $script:action.Item.id 2};$script:frameIndex=2}
 if($script:dialog){$remaining=$dialog.FindName('Remaining');$remaining.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$remaining.Opacity=1}
}
function New-InteractionGallery {
 if($script:gallery){$gallery.Activate()|Out-Null;return $gallery}
 [xml]$gx=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="晚晚 · 互动小剧场" Width="940" Height="730" MinWidth="880" MinHeight="650" WindowStartupLocation="CenterScreen" Background="#FFF7FA" FontFamily="Microsoft YaHei UI" Foreground="#594853">
 <Grid Margin="26"><Grid.ColumnDefinitions><ColumnDefinition Width="310"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Border CornerRadius="24" Background="#EDDFE7" Margin="0,0,24,0"><Grid><Image x:Name="ScenePortrait" Height="330" VerticalAlignment="Top" Margin="0,24,0,0" Stretch="Uniform"/><Image x:Name="SceneFade" Height="330" VerticalAlignment="Top" Margin="0,24,0,0" Stretch="Uniform" Opacity="0" IsHitTestVisible="False"/><StackPanel VerticalAlignment="Bottom" Margin="26,0,26,38"><TextBlock Text="一点点温柔，送给你" Foreground="#A47B90" FontSize="12"/><TextBlock x:Name="SceneTitle" Text="探头找你" FontSize="26" Margin="0,12,0,12"/><TextBlock x:Name="SceneCaption" Text="在忙吗？我探个头，看看你呀。" TextWrapping="Wrap" FontSize="16" LineHeight="27"/><TextBlock Text="点右边的小卡片，晚晚会回应你。" FontSize="12" Foreground="#9A8491" TextWrapping="Wrap" Margin="0,26,0,0"/></StackPanel></Grid></Border><Grid Grid.Column="1"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions><StackPanel Margin="0,5,0,18"><TextBlock Text="晚晚的小小回应" FontSize="27"/><TextBlock Text="10 个小动作，点一下看看" FontSize="14" Foreground="#9E8593" Margin="0,10,0,0"/></StackPanel><ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"><WrapPanel x:Name="Scenes"/></ScrollViewer><TextBlock Grid.Row="2" Text="互动预览不会开启守护或执行关机。" Foreground="#9E8593" FontSize="12" Margin="0,18,0,0"/></Grid></Grid>
</Window>
'@
 $script:gallery=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($gx));$gallery.Resources.MergedDictionaries.Add($win.Resources);$gallery.Owner=$win
 $script:gallerySurface=Register-CharacterSurface ($gallery.FindName('ScenePortrait')) ($gallery.FindName('SceneFade')) $gallery
 foreach($item in @($script:interactionCatalog|Where-Object {$_.id -notlike 'desk-*'})){
  $button=[Windows.Controls.Button]::new();$button.Width=170;$button.Margin=[Windows.Thickness]::new(0,0,10,10);$button.Padding=[Windows.Thickness]::new(10);$button.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#FFFFFF');$button.Tag=$item.id;$button.ToolTip=$item.caption
  $panel=[Windows.Controls.StackPanel]::new();$thumb=[Windows.Controls.Image]::new();$thumb.Height=70;$thumb.Stretch=[Windows.Media.Stretch]::Uniform;if($script:interactionAssets.ContainsKey($item.id)){$thumb.Source=$script:interactionAssets[$item.id][2]};$panel.Children.Add($thumb)|Out-Null
  $text=[Windows.Controls.TextBlock]::new();$text.Text=$item.symbol+'  '+$item.name;$text.FontSize=14;$text.Margin=[Windows.Thickness]::new(0,6,0,2);$text.HorizontalAlignment=[Windows.HorizontalAlignment]::Center;$panel.Children.Add($text)|Out-Null;$button.Content=$panel
  $button.Add_Click({param($sender,$e) Invoke-Gesture $sender.Tag})
  $gallery.FindName('Scenes').Children.Add($button)|Out-Null
 }
 $gallery.Add_Closed({$script:surfaces=@($script:surfaces|Where-Object {$_.Window -ne $script:gallery});$script:gallery=$null;$script:gallerySurface=$null})
 $gallery.Show();Start-Interaction 'peek';return $gallery
}
$ui.Mood=$win.FindName('Mood')
$script:mainSurface=Register-CharacterSurface $ui.Portrait ($win.FindName('PortraitFade')) $win
$ui.MotionToggle.IsChecked=[bool]$cfg.ReducedMotion
$ui.MotionToggle.Add_Checked({$cfg.ReducedMotion=$true;Set-Motion $false;Save-Config})
$ui.MotionToggle.Add_Unchecked({$cfg.ReducedMotion=$false;Set-Motion $true;Save-Config})
$ui.Interactions.Add_Click({New-InteractionGallery|Out-Null})
$script:touchCount=0
$ui.Portrait.Add_MouseLeftButtonDown({Invoke-Poke|Out-Null})
$script:visualTimer=[Windows.Threading.DispatcherTimer]::new();$script:visualTimer.Interval=[timespan]::FromMilliseconds(50)
$script:visualTimer.Add_Tick({
 $ms=$script:animationClock.ElapsedMilliseconds
 $badge=$win.FindName('VoiceBadge');if($badge){$badge.Text=if(-not $cfg.Voice){'♫  语音已关闭，只显示文字和动作'}elseif($script:voiceUntil -and (Get-Date) -lt $script:voiceUntil){'♫  晚晚正在轻轻和你说话…'}elseif($cfg.VoicePreset -ne 'System'){$p=Get-Persona;'♫  '+$p.name+'晚晚 · '+$p.voice_name}else{'♫  系统朗读 · 在设置里可以换回晚晚的声音'}}
 if($script:popup -and $ms -gt $script:popupUntil -and -not $script:petDragging){Complete-DesktopPetReminder}
 $active=$script:action -and $ms -lt $script:action.End
 $holding=$script:action -and $script:voiceUntil -and (Get-Date) -lt $script:voiceUntil
 $id=if($active -or $holding){$script:action.Item.id}elseif($script:restPose){$script:restPose.Id}else{'peek'}
 $index=if($active){if($script:motionEnabled){$script:action.Item.frames[[int][math]::Floor(($ms-$script:action.Start)/$script:action.Item.step)]}else{2}}elseif($holding){2}elseif($script:restPose){$script:restPose.Frame}else{0}
 $script:frameIndex=$index
 foreach($surface in @($script:surfaces)){
  if(-not $surface.Window.IsVisible){continue};Set-SurfaceFrame $surface $id $index
  if(-not $script:motionEnabled -or $surface.Static){continue}
  $t=if($active){[math]::Min(1,($ms-$script:action.Start)/($script:action.End-$script:action.Start))}else{0}
  $envelope=[math]::Sin([math]::PI*$t);$surface.Scale.ScaleX=1+(.007*[math]::Sin($ms/1100));$surface.Scale.ScaleY=$surface.Scale.ScaleX;$surface.Move.X=0;$surface.Move.Y=0;$surface.Rotate.Angle=0
  if($active){switch($id){'peek'{$surface.Move.X=-22*(1-$t)*[math]::Cos($t*6);$surface.Rotate.Angle=-3*$envelope}'pat'{$surface.Scale.ScaleX=1+.04*$envelope;$surface.Scale.ScaleY=$surface.Scale.ScaleX;$surface.Move.Y=4*$envelope}'water'{$surface.Move.Y=-5*$envelope}'stretch'{$surface.Move.Y=-9*$envelope}'nod'{$surface.Move.Y=4*[math]::Sin($t*4*[math]::PI)*$envelope}'heart'{$surface.Scale.ScaleX=1+.025*$envelope;$surface.Scale.ScaleY=$surface.Scale.ScaleX}'cheer'{$surface.Move.Y=-6*[math]::Abs([math]::Sin($t*4*[math]::PI))}'wave'{$surface.Rotate.Angle=1.5*[math]::Sin($t*4*[math]::PI)*$envelope}'yawn'{$surface.Move.Y=3*$envelope}'goodnight'{$surface.Rotate.Angle=2*$envelope}}}
 }
})
Set-CompanionMode '陪伴';Set-Motion $script:motionEnabled;$script:visualTimer.Start()
$win.Add_Closed({$script:visualTimer.Stop();if($script:popup){$popup.Close()};if($script:gallery){$gallery.Close()}})
