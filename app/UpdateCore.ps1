# 检查更新的纯逻辑：版本比较、发布资源挑选。不依赖 WPF，可单独测试。
$script:UpdateRepo='9OwO6/wanwan-shutdown-assistant'
$script:UpdateApi="https://api.github.com/repos/$script:UpdateRepo/releases/latest"
$script:UpdateDownloadPrefix="https://github.com/$script:UpdateRepo/releases/download/"

function ConvertTo-WanwanVersion([string]$Text) {
    $clean = ($Text -replace '^[vV]', '').Trim()
    $parsed = $null
    if ([version]::TryParse($clean, [ref]$parsed)) { return $parsed }
    return $null
}

function Test-NewerRelease([string]$Current, [string]$Tag) {
    $a = ConvertTo-WanwanVersion $Current; $b = ConvertTo-WanwanVersion $Tag
    return ($a -and $b -and $b -gt $a)
}

function Select-UpdateAsset($Release) {
    # 只接受本仓库发布页里命名规范的便携包，防止把别处的文件当成更新。
    foreach ($asset in @($Release.assets)) {
        if ($asset.name -match '^Wanwan-v\d+(\.\d+){1,3}-windows\.zip$' -and ([string]$asset.browser_download_url).StartsWith($script:UpdateDownloadPrefix)) { return $asset }
    }
    return $null
}

function Get-UpdateSummary($Release, [int]$MaxChars = 520) {
    $notes = ([string]$Release.body) -replace '\r', '' -replace '(?m)^#+\s*', '' -replace '\*\*', ''
    $notes = ($notes -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 14) -join "`n"
    if ($notes.Length -gt $MaxChars) { $notes = $notes.Substring(0, $MaxChars) + '…' }
    return $notes
}

# 后台线程执行的工作；结果通过 Dispatcher 计时器轮询取回，界面不卡顿。
$script:UpdateCheckWork = {
    param([string]$Api)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Invoke-RestMethod -Uri $Api -Headers @{ 'User-Agent' = 'Wanwan-Updater'; 'Accept' = 'application/vnd.github+json' } -TimeoutSec 15
}
$script:UpdateDownloadWork = {
    param([string]$Url, [string]$Digest, [string]$WorkDir)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if (Test-Path -LiteralPath $WorkDir) { Remove-Item -LiteralPath $WorkDir -Recurse -Force }
    New-Item -ItemType Directory -Force $WorkDir | Out-Null
    $zip = Join-Path $WorkDir 'update.zip'
    $client = New-Object Net.WebClient
    $client.Headers['User-Agent'] = 'Wanwan-Updater'
    try { $client.DownloadFile($Url, $zip) } finally { $client.Dispose() }
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($Digest -and $Digest -ne "sha256:$hash") { throw '下载的文件校验不一致，已停止更新。' }
    $extract = Join-Path $WorkDir 'extracted'
    Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
    $source = Join-Path $extract 'Wanwan'
    if (-not (Test-Path -LiteralPath (Join-Path $source 'app\Main.ps1'))) { throw '更新包里没有找到晚晚的程序文件。' }
    [pscustomobject]@{ Source = $source; Sha256 = $hash }
}

# 旧版本留下、新版本已不再使用的程序文件。更新只覆盖不删除，所以由新版本启动时清理。
$script:ObsoleteWanwanPaths = @(
    'app\Auditions.ps1',
    'assets\voice-lines.json',
    'assets\voices\manifest.json',
    'assets\voices\A', 'assets\voices\B', 'assets\voices\C', 'assets\voices\D',
    'assets\voices\auditions', 'assets\voices\C-cleanup.json',
    # v0.4.0：两种性格的新录音替换了旧 N1 整句包和旧台词表
    'app\Dialogue.ps1', 'app\GuardVoice.ps1', 'app\VoiceBank.ps1',
    'assets\companion-lines.json', 'assets\clock-lines.json', 'assets\clock-parts.json', 'assets\guard-lines.json', 'assets\watch-lines.json',
    'assets\voice-script.json', 'assets\voices.json',
    'assets\voices\N1', 'assets\voices\N1-clock', 'assets\voices\N1-guard', 'assets\voices\N1-watch', 'assets\voices\V3'
)
function Remove-ObsoleteWanwanFiles([string]$Root) {
    # 只在发布包目录里清理（开发仓库里有 .git，交给 git 管理）。
    if (-not (Test-Path -LiteralPath (Join-Path $Root 'app\Main.ps1')) -or -not (Test-Path -LiteralPath (Join-Path $Root 'VERSION')) -or (Test-Path -LiteralPath (Join-Path $Root '.git'))) { return @() }
    $removed = @()
    foreach ($relative in $script:ObsoleteWanwanPaths) {
        $path = Join-Path $Root $relative
        if (Test-Path -LiteralPath $path) {
            try { Remove-Item -LiteralPath $path -Recurse -Force; $removed += $relative } catch {}
        }
    }
    return $removed
}

function Start-BackgroundWork([scriptblock]$Work, [object[]]$Arguments) {
    $ps = [powershell]::Create()
    $ps.AddScript($Work.ToString()) | Out-Null
    foreach ($argument in $Arguments) { $ps.AddArgument($argument) | Out-Null }
    return [pscustomobject]@{ Shell = $ps; Handle = $ps.BeginInvoke() }
}

function Receive-BackgroundWork($Job) {
    # 返回 @{Done; Result; Error}
    if (-not $Job.Handle.IsCompleted) { return @{ Done = $false } }
    try {
        $output = $Job.Shell.EndInvoke($Job.Handle)
        $failure = if ($Job.Shell.Streams.Error.Count) { $Job.Shell.Streams.Error[0].Exception.Message } else { '' }
        return @{ Done = $true; Result = ($output | Select-Object -Last 1); Error = $failure }
    } catch {
        $inner = $_.Exception; while ($inner.InnerException) { $inner = $inner.InnerException }
        return @{ Done = $true; Result = $null; Error = $inner.Message }
    } finally { $Job.Shell.Dispose() }
}
