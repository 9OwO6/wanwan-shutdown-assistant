# Render precisely clipped atlas frames to individual transparent PNGs at native scale.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$taskRoot=Split-Path $PSScriptRoot
$layout=Get-Content (Join-Path $taskRoot 'assets\character-frame-layout.json') -Raw -Encoding UTF8|ConvertFrom-Json
$sheets=@{}
foreach($frame in $layout.frames){
 if(-not $sheets.ContainsKey($frame.source)){
  $sourceFile=Join-Path $taskRoot $frame.source
  if((Get-FileHash $sourceFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne $frame.source_sha256){throw 'Atlas changed; regenerate and review the layout first'}
  $bitmap=[Windows.Media.Imaging.BitmapImage]::new();$bitmap.BeginInit();$bitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad;$bitmap.UriSource=[uri]$sourceFile;$bitmap.EndInit();$bitmap.Freeze();$sheets[$frame.source]=$bitmap
 }
 $r=$frame.source_rect
 $cell=[Windows.Media.Imaging.CroppedBitmap]::new($sheets[$frame.source],[Windows.Int32Rect]::new($r[0],$r[1],$r[2],$r[3]))
 $full=[Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(0,0,$r[2],$r[3]))
 $clip=$full
 if($frame.excluded_spans.Count){
  $excluded=[Windows.Media.GeometryGroup]::new();$excluded.FillRule=[Windows.Media.FillRule]::Nonzero
  foreach($span in $frame.excluded_spans){$excluded.Children.Add([Windows.Media.RectangleGeometry]::new([Windows.Rect]::new($span[0],$span[1],$span[2],$span[3])))}
  $clip=[Windows.Media.CombinedGeometry]::new([Windows.Media.GeometryCombineMode]::Exclude,$full,$excluded)
 }
 $visual=[Windows.Media.DrawingVisual]::new();$context=$visual.RenderOpen()
 $context.PushTransform([Windows.Media.TranslateTransform]::new($frame.offset[0],$frame.offset[1]));$context.PushClip($clip)
 $context.DrawImage($cell,[Windows.Rect]::new(0,0,$r[2],$r[3]));$context.Pop();$context.Pop();$context.Close()
 $target=[Windows.Media.Imaging.RenderTargetBitmap]::new(640,640,96,96,[Windows.Media.PixelFormats]::Pbgra32);$target.Render($visual)
 $destination=Join-Path $taskRoot $frame.file;New-Item -ItemType Directory -Force (Split-Path $destination)|Out-Null
 $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($target));$stream=[IO.File]::Create($destination);$encoder.Save($stream);$stream.Dispose()
}
Write-Output 'Exported forty 640x640 RGBA frames through native WPF; no AI redraw or source atlas overwrite.'
