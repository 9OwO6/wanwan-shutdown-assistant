function Set-CountdownView([ValidateSet('Expanded','Compact','Hidden')][string]$View){
 if(-not $script:dialog){return}
 $script:countdownView=$View
 if($View -eq 'Hidden'){$script:dialog.Hide();Write-Event 'Countdown hidden; deadline unchanged';return}
 $left=$script:dialog.Left;$top=$script:dialog.Top;$width=$script:dialog.Width;$height=$script:dialog.Height
 $compact=$View -eq 'Compact'
 $script:dialog.FindName('FullReminder').Visibility=if($compact){[Windows.Visibility]::Collapsed}else{[Windows.Visibility]::Visible}
 $script:dialog.FindName('MiniReminder').Visibility=if($compact){[Windows.Visibility]::Visible}else{[Windows.Visibility]::Collapsed}
 $script:dialog.Width=if($compact){190}else{410};$script:dialog.Height=if($compact){284}else{650}
 $area=Get-DesktopWorkArea $script:dialog
 $position=Limit-PetPosition ($left+$width-$script:dialog.Width) ($top+$height-$script:dialog.Height) $area $script:dialog.Width $script:dialog.Height
 $script:dialog.Left=$position.Left;$script:dialog.Top=$position.Top
 $script:dialog.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$script:dialog.Opacity=1;$script:dialog.Show()
 Write-Event ('Countdown view='+$View+'; deadline unchanged')
}
function Update-CountdownText([datetime]$Now){
 if(-not $script:dialog){return}
 $left=[math]::Max(0,[int][math]::Ceiling(($script:deadline-$Now).TotalSeconds))
 $text=('{0:00}:{1:00}' -f [math]::Floor($left/60),($left%60))
 $script:dialog.FindName('Remaining').Text=$text;$script:dialog.FindName('MiniRemaining').Text=$text
 $script:dialog.FindName('MiniStatus').Text=if($script:demoMode){'体验倒计时 · 不会关机'}elseif($script:shutdownAfter){'晚晚说完晚安就关机'}else{'时间照常走，记得保存 ♡'}
 return $left
}
