$script:iconPath=Join-Path $root 'assets\icons\wanwan.ico'
$script:appIcon=[Windows.Media.Imaging.BitmapFrame]::Create([uri]$script:iconPath)
$script:trayIcon=[Drawing.Icon]::new($script:iconPath,32,32)
Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace Wanwan {
 public static class Desktop {
  [DllImport("shell32.dll",CharSet=CharSet.Unicode)] public static extern int SetCurrentProcessExplicitAppUserModelID(string id);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hwnd,int msg,IntPtr w,IntPtr l);
 }
}
'@
$script:appIdentityResult=[Wanwan.Desktop]::SetCurrentProcessExplicitAppUserModelID('Wanwan.ShutdownAssistant')
function Set-WanwanIcon($Window){$Window.Icon=$script:appIcon}
function Get-DesktopWorkArea($Window=$win) {
 $handle=[Windows.Interop.WindowInteropHelper]::new($Window).Handle
 if($handle -eq [IntPtr]::Zero){return [Windows.SystemParameters]::WorkArea}
 $area=[Windows.Forms.Screen]::FromHandle($handle).WorkingArea
 $source=[Windows.PresentationSource]::FromVisual($Window)
 if($source -and $source.CompositionTarget){
  $matrix=$source.CompositionTarget.TransformFromDevice
  $top=$matrix.Transform([Windows.Point]::new($area.Left,$area.Top));$bottom=$matrix.Transform([Windows.Point]::new($area.Right,$area.Bottom))
  return [Windows.Rect]::new($top,$bottom)
 }
 return [Windows.Rect]::new($area.Left,$area.Top,$area.Width,$area.Height)
}
function Get-PetPlacement($Area,[double]$Width,[double]$Height){
 return @{Left=[math]::Max($Area.Left,$Area.Right-$Width-18);Top=[math]::Max($Area.Top,$Area.Bottom-$Height-18)}
}
function Place-DesktopWindow($Window){
 $area=Get-DesktopWorkArea;$position=Get-PetPlacement $area $Window.Width $Window.Height
 $Window.Left=$position.Left;$Window.Top=$position.Top
}
