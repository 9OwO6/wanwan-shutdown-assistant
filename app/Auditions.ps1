$script:auditionPlayer=[System.Media.SoundPlayer]::new()
function New-VoicePicker {
 param([switch]$NoSave)
 [xml]$voiceXaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="晚晚 · 选一个喜欢的声音" Width="580" Height="670" ResizeMode="NoResize" WindowStartupLocation="CenterOwner" Background="#FFF5FA" FontFamily="Microsoft YaHei UI">
 <StackPanel Margin="28"><TextBlock Text="♫  想听我用什么声音陪你？" FontSize="23" Foreground="#754B64"/><TextBlock Text="推荐 N1：完整的 191 句台词和整点报时。A–D 是早期试验音色，只录了 11 句，其余用系统声音朗读。" TextWrapping="Wrap" Margin="0,12,0,18" Foreground="#93798A"/>
 <Button x:Name="N1" Content="▶  N1 · 清甜温柔（推荐 · 完整台词）♡" Padding="12" Background="#EED7E3" Margin="0,0,0,10"/>
 <Button x:Name="A" Content="▶  A · 温柔原声（试验版）" Padding="12" Margin="0,0,0,10"/><Button x:Name="B" Content="▶  B · 原声稍亮（试验版）" Padding="12" Margin="0,0,0,10"/><Button x:Name="C" Content="▶  C · 明亮女声（试验版）" Padding="12" Margin="0,0,0,10"/><Button x:Name="D" Content="▶  D · 另一种女声（试验版）" Padding="12" Margin="0,0,0,10"/>
 <WrapPanel HorizontalAlignment="Center" Margin="0,8,0,12"><RadioButton x:Name="ChooseN1" Content="选 N1" GroupName="VoicePreset" Margin="10,0"/><RadioButton x:Name="ChooseA" Content="选 A" GroupName="VoicePreset" Margin="10,0"/><RadioButton x:Name="ChooseB" Content="选 B" GroupName="VoicePreset" Margin="10,0"/><RadioButton x:Name="ChooseC" Content="选 C" GroupName="VoicePreset" Margin="10,0"/><RadioButton x:Name="ChooseD" Content="选 D" GroupName="VoicePreset" Margin="10,0"/></WrapPanel>
 <Button x:Name="UseVoice" Content="♡  用这个声音陪我" Padding="12" Background="#A7778B" Foreground="White" IsEnabled="False"/>
 <WrapPanel HorizontalAlignment="Center" Margin="0,12,0,0"><Button x:Name="StopAudio" Content="停止播放" Padding="10,8" Margin="0,0,10,0"/><Button x:Name="ResetVoice" Content="恢复系统声音" Padding="10,8"/></WrapPanel>
 <TextBlock x:Name="VoiceStatus" Text="试听后，选中喜欢的编号再保存。" Foreground="#967C8C" TextWrapping="Wrap" Margin="0,16,0,0"/>
 </StackPanel>
</Window>
'@
 $voiceWindow=[Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($voiceXaml));$voiceWindow.Owner=$win;$voiceWindow.Resources.MergedDictionaries.Add($win.Resources);Set-WanwanIcon $voiceWindow
 foreach($id in @('N1','A','B','C','D')){
  $candidate=$id;$auditionWindow=$voiceWindow;$player=$script:auditionPlayer
  $handler={
   $file=if($candidate -eq 'N1'){Join-Path $root 'assets\voices\N1\preview-01.mp3'}else{Join-Path $root "assets\voices\auditions\$candidate.mp3"}
   # MP3 试听走与正式提醒相同的 WPF MediaPlayer（SoundPlayer 只能播放 WAV）。
   if(Test-Path $file){Stop-Voice;$script:voicePlayer.Open([uri]$file);$script:voicePlayer.Play();$auditionWindow.FindName('VoiceStatus').Text="正在试听 $candidate · 喜欢的话，选中编号再保存"}else{$auditionWindow.FindName('VoiceStatus').Text='试听文件尚未生成'}
  }.GetNewClosure()
  $voiceWindow.FindName($id).Add_Click($handler)
  $choose={$auditionWindow.Tag=$candidate;$ready=Test-VoicePresetReady $candidate;$auditionWindow.FindName('UseVoice').IsEnabled=$ready;if(-not $ready){$auditionWindow.FindName('VoiceStatus').Text='完整语音包正在准备，请先试听'}}.GetNewClosure()
  $voiceWindow.FindName("Choose$id").Add_Checked($choose)
 }
 $auditionWindow=$voiceWindow
 $voiceWindow.FindName('UseVoice').Add_Click({Set-VoicePreset $auditionWindow.Tag -NoSave:$NoSave;Stop-Voice;$auditionWindow.Close()}.GetNewClosure())
 $voiceWindow.FindName('ResetVoice').Add_Click({Set-VoicePreset 'System' -NoSave:$NoSave;Stop-Voice;$auditionWindow.Close()}.GetNewClosure())
 $voiceWindow.FindName('StopAudio').Add_Click({Stop-Voice})
 $voiceWindow.Add_Closed({$script:auditionPlayer.Stop();$script:voicePlayer.Stop()})
 if($cfg.VoicePreset -in @('N1','A','B','C','D')){$voiceWindow.FindName('Choose'+$cfg.VoicePreset).IsChecked=$true}
 return $voiceWindow
}
$win.FindName('Auditions').Add_Click({$voiceWindow=New-VoicePicker;$voiceWindow.ShowDialog()|Out-Null})
$win.Add_Closed({$script:auditionPlayer.Dispose()})
