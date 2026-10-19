function Assert-Control([bool]$Pass,[string]$Message){if(-not $Pass){throw $Message}}
function Pump-Controls([int]$Milliseconds){$frame=[Windows.Threading.DispatcherFrame]::new();$wait=[Windows.Threading.DispatcherTimer]::new();$wait.Interval=[timespan]::FromMilliseconds($Milliseconds);$wait.Add_Tick({$frame.Continue=$false;$wait.Stop()});$wait.Start();[Windows.Threading.Dispatcher]::PushFrame($frame);$wait.Stop()}
$cfg.Voice=$false;$cfg.Enabled=$false;$cfg.DesktopPet=$true
Show-DesktopPet -Compact;Pump-Controls 100
Assert-Control ($popup.FindName('CompactStatus').Text -eq '到点守护未开启') 'Guard-off status not visible on avatar'
$win.Hide();$beforeLeft=$popup.Left;$beforeTop=$popup.Top
$down=[Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice,0,[Windows.Input.MouseButton]::Left);$down.RoutedEvent=[Windows.UIElement]::PreviewMouseDownEvent
$popup.FindName('PetAvatar').RaiseEvent($down)
Assert-Control $script:petDragArmed 'Actual image routed mouse-down did not arm dragging'
$dragPointer=[Drawing.Point]::new($script:petDragStart.X-180,$script:petDragStart.Y-140)
Move-PetDrag $dragPointer $true
Assert-Control ($popup.Left -lt $beforeLeft-100 -and $popup.Top -lt $beforeTop-80 -and -not $win.IsVisible) 'Drag must move avatar without opening main window'
$up=[Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice,0,[Windows.Input.MouseButton]::Left);$up.RoutedEvent=[Windows.UIElement]::PreviewMouseUpEvent
$popup.FindName('CompactPet').RaiseEvent($up)
Assert-Control (-not $script:petDragging -and -not $win.IsVisible) 'Drag release incorrectly opened main window'
$persisted=Get-Content $configFile -Raw -Encoding UTF8|ConvertFrom-Json
Assert-Control ($persisted.PetLeft -eq $popup.Left -and $persisted.PetTop -eq $popup.Top) 'Dragged position did not persist'
$left=$popup.Left;$top=$popup.Top;Show-DesktopPet '位置测试';Show-DesktopPet -Compact
Assert-Control ($popup.Left -eq $left -and $popup.Top -eq $top) 'Reminder expansion lost saved compact position'
$limited=Limit-PetPosition -9000 9000 ([Windows.Rect]::new(-1920,0,1920,1040)) 142 180
Assert-Control ($limited.Left -eq -1920 -and $limited.Top -eq 860) 'Negative monitor/taskbar constraints failed'
$cfg.Enabled=$true
$popup.FindName('CompactHide').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert-Control (-not $popup -and -not $cfg.DesktopPet -and $cfg.Enabled) 'Hide button must close pet and preserve guard'
$persisted=Get-Content $configFile -Raw -Encoding UTF8|ConvertFrom-Json
Assert-Control (-not $persisted.DesktopPet -and $persisted.Enabled) 'Hidden state failed to persist independently of guard'
$cfg.Enabled=$false;$cfg.DesktopPet=$true;Show-DesktopPet -Compact
$popup.FindName('CompactPet').ContextMenu.Items[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
Assert-Control (-not $popup -and -not $cfg.DesktopPet) 'Right-click Hide command failed'
$ui.BedInput.Text='02:00';$ui.GraceInput.Text='30';$ui.EnabledToggle.IsChecked=$false;$ui.VoiceToggle.IsChecked=$false
$ui.ArmGuard.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
$persisted=Get-Content $configFile -Raw -Encoding UTF8|ConvertFrom-Json
Assert-Control ($persisted.Enabled -and $cfg.Enabled -and $ui.EnabledToggle.IsChecked) 'Activation button failed to enable and persist guard'
Invoke-GuardTick ([datetime]'2026-10-12T03:42:00')
Assert-Control ($dialog -and $script:deadline -eq [datetime]'2026-10-12T03:44:00' -and $script:lastSpokenLine.cue -eq 'due') 'Hidden pet blocked overdue reminder at 03:42'
$cfg.Enabled=$false;$dialog.Close();$cfg.DesktopPet=$true;Show-DesktopPet -Compact;Pump-Controls 100
$popup.UpdateLayout();$bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(142,180,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($popup);$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$file=[IO.File]::Create((Join-Path $root 'output\pet-controls-preview.png'));$encoder.Save($file);$file.Dispose()
@{draggedWithoutOpening=$true;dragPositionPersisted=$true;hideButtonPassed=$true;contextHidePassed=$true;hiddenPetPreservesGuard=$true;activationButtonPersistsEnabled=$true;overdueReminderAt0342=$true;nativeShutdownCalled=$false}|ConvertTo-Json|Set-Content (Join-Path $root 'output\pet-controls-report.json') -Encoding UTF8
$cfg.DesktopPet=$false;$popup.Close();$win.Show()
Write-Output 'Pet controls passed: actual routed down/up, movement, persisted position, hide button/context, guard preservation, actual activation/persistence and hidden-pet overdue at 03:42. No native shutdown.'
