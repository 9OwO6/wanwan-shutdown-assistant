# 在真实 WPF Dispatcher 中操作按钮、抓帧，所有测试均禁用声音和关机。
if($script:interactionAssets.Count -ne 10){throw 'Expected ten independent interaction sheets'}
foreach($entry in $script:interactionAssets.GetEnumerator()){
 if($entry.Value.Count -ne 4){throw 'Each action must load four reviewed frames'}
 foreach($frame in $entry.Value){if($frame.PixelWidth -ne 640 -or $frame.PixelHeight -ne 640 -or $frame -isnot [Windows.Media.Imaging.BitmapImage]){throw 'Runtime must load independent 640x640 frames instead of re-splitting source atlases'}}
}
$captureDirectory=Join-Path $root 'output\interaction-review';New-Item -ItemType Directory -Force $captureDirectory|Out-Null
function Wait-Visual([int]$milliseconds){
 $waitFrame=[Windows.Threading.DispatcherFrame]::new();$waitTimer=[Windows.Threading.DispatcherTimer]::new();$waitTimer.Interval=[timespan]::FromMilliseconds($milliseconds)
 $waitTimer.Add_Tick({$waitFrame.Continue=$false;$waitTimer.Stop()});$waitTimer.Start();[Windows.Threading.Dispatcher]::PushFrame($waitFrame);$waitTimer.Stop()
}
function Save-Visual($window,[string]$name){
 $window.UpdateLayout();$render=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$window.ActualWidth,[int]$window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$render.Render($window)
 $enc=[Windows.Media.Imaging.PngBitmapEncoder]::new();$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($render));$file=[IO.File]::Create((Join-Path $captureDirectory $name));$enc.Save($file);$file.Dispose()
}
$ui.Interactions.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
if(-not $script:gallery -or $gallery.FindName('Scenes').Children.Count -ne 10){throw 'Gallery must expose ten working buttons'}
Wait-Visual 200;Save-Visual $gallery 'gallery.png'
$report=@()
foreach($item in $script:interactionCatalog){
 $button=$gallery.FindName('Scenes').Children|Where-Object {$_.Tag -eq $item.id}|Select-Object -First 1
 $button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
 $seen=[Collections.Generic.HashSet[int]]::new();$saved=[Collections.Generic.HashSet[int]]::new();$deadline=[datetime]::Now.AddMilliseconds($item.step*$item.frames.Count+80)
 while([datetime]::Now -lt $deadline){
  Wait-Visual 90;$seen.Add($script:frameIndex)|Out-Null
  if($script:action.Item.id -ne $item.id){throw 'Gallery started incorrect action'}
  if($saved.Add($script:frameIndex)){Save-Visual $gallery ($item.id+'-'+$script:frameIndex+'.png')}
 }
 if($seen.Count -lt 4){throw ('Action did not play four poses: '+$item.id)}
 $report+=@{id=$item.id;frames=@($seen);caption=$item.caption;verified=$true}
}
Start-Interaction 'pat';Wait-Visual 650;Set-Motion $false;Wait-Visual 100;$held=$script:frameIndex;Wait-Visual 800
if($script:frameIndex -ne $held -or $script:mainSurface.Move.X -ne 0 -or $script:mainSurface.Rotate.Angle -ne 0){throw 'Reduced motion must hold a static gesture'}
Set-Motion $true;$gallery.Close();$win.Hide()
Say '还有半小时，我们慢慢把今天的事情收个尾，好不好？' -LineId early
Wait-Visual 700
if(-not $script:popup -or -not $popup.IsVisible -or $popup.ShowActivated -or $script:action.Item.id -ne 'water'){throw 'Muted tray reminder must animate in a nonactivating popup'}
$first=$script:popupSurface.Key;Wait-Visual 500;if($script:popupSurface.Key -eq $first){throw 'Hidden main window stopped popup frames'}
Save-Visual $popup 'tray-reminder.png';$popup.FindName('PopupClose').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));if($script:popup){throw 'Popup dismiss failed'}
$win.Show();Show-BedDialog $true;Wait-Visual 700;Save-Visual $dialog 'bedtime-dialog.png'
if(-not $script:dialogSurface -or $script:dialogSurface.Key -notlike 'goodnight:*'){throw 'Bed dialog must show animated character'}
$dialog.FindName('CancelNight').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
if($script:surfaces.Count -ne 1){throw 'Closed window leaked animation surfaces'}
Start-Interaction 'peek';$win.Width=940;$win.Height=800;Wait-Visual 180;Save-Visual $win 'minimum-window.png';$win.Width=1080;$win.Height=840;Wait-Visual 100
$report|ConvertTo-Json -Depth 5|Set-Content (Join-Path $captureDirectory 'runtime-report.json') -Encoding UTF8
Write-Output 'Companion tests passed: ten gallery buttons, forty distinct poses, muted tray popup, reduced motion, animated bedtime dialog; no shutdown or preference write'
