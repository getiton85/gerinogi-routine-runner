Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-SelfAsAdministratorIfNeeded {
    if (Test-IsAdministrator) { return }
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    if ([string]::IsNullOrWhiteSpace($scriptPath)) { return }
    $args = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $scriptPath + '"'
    Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WorkingDirectory $PSScriptRoot -Verb RunAs
    exit
}

Restart-SelfAsAdministratorIfNeeded

$script:UiConfigPath = Join-Path $PSScriptRoot 'ui_config.json'

function New-DefaultUiConfig {
    return [ordered]@{
        app = [ordered]@{
            title = 'Local State Routine Runner'
            versionPrefix = '현버전 '
            fontName = 'Malgun Gothic'
            fontSize = 8
            topMost = $true
        }
        window = [ordered]@{
            width = 460
            height = 920
            minWidth = 420
            minHeight = 760
        }
        colors = [ordered]@{
            background = '125,211,185'
            actionPrimary = '255,221,87'
            actionSecondary = '245,190,65'
            actionTertiary = '238,139,48'
            actionBorder = '170,122,24'
            actionText = '30,30,30'
            updateButton = '54,91,109'
            versionText = '35,55,65'
            progressActive = '0,122,204'
            progressInactive = '245,247,250'
            progressActiveText = '255,255,255'
            progressInactiveText = '0,0,0'
            brandText = '24,42,38'
            brandOutline = '255,255,255'
            brandLink = '0,82,155'
        }
        tabs = [ordered]@{
            main = '실험셋팅'
            options = '세부옵션'
        }
        labels = [ordered]@{
            targetGroup = '대상'
            targetWindow = '대상 창'
            monitor = '모니터'
            slotSelect = '슬롯 선택'
            slotPreview = '허상의 정박지'
            specialSlotPreview = '특수카테고리'
            combatSlotPreview = '전투관련 슬롯 미리보기'
            progress = '진행 상황'
            settings = '셋팅'
        }
        buttons = [ordered]@{
            searchWindows = '검색'
            capture = '영역(Shift+F8)'
            point = '촬영(Shift+F7)'
            start = '시작(Shift+F5)'
            stop = '중단(Shift+F6)'
            file = '파일'
            folder = '폴더'
            delete = '삭제'
            locate = '위치'
            probe = '클릭확인'
            diagnostic = '진단'
            report = '문제보고'
            log = '로그'
            exit = '종료'
            ignore = '제외(F9)'
            showIgnore = '제외확인'
            clearIgnore = '제외삭제'
            update = '업데이트 확인'
        }
        progress = [ordered]@{
            labels = @('메뉴','어비','던전','입장','상태','대기','전투','완료','종료','순환')
        }
        slots = @('협동','상태 기준','식사 버튼','메뉴','어비스','던전','입장','완료 확인','나가기','궁극기','스킵','팔라딘')
        brand = [ordered]@{
            title = '내 멋대로 게리노기'
            linkText = 'getiton85.github.io/gerinogi-pob'
            url = 'https://getiton85.github.io/gerinogi-pob/'
            imagePath = 'C:\Users\freem\Pictures\Mabinogi Mobile\screenshots\MabinogiMobile_2026070318471243.png'
        }
    }
}

function ConvertTo-JsonFile([object]$Data, [string]$Path) {
    ($Data | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Load-UiConfig {
    $default = New-DefaultUiConfig
    if (-not [System.IO.File]::Exists($script:UiConfigPath)) {
        ConvertTo-JsonFile $default $script:UiConfigPath
        return ($default | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
    }
    try {
        $loaded = Get-Content -Raw -Encoding UTF8 -LiteralPath $script:UiConfigPath | ConvertFrom-Json
        return $loaded
    }
    catch {
        $backup = $script:UiConfigPath + '.broken_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
        Copy-Item -LiteralPath $script:UiConfigPath -Destination $backup -Force
        ConvertTo-JsonFile $default $script:UiConfigPath
        return ($default | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
    }
}

function Get-UiValue([string]$Path, $Fallback) {
    $current = $script:UiConfig
    foreach ($part in $Path.Split('.')) {
        if ($null -eq $current) { return $Fallback }
        $prop = $current.PSObject.Properties[$part]
        if ($null -eq $prop) { return $Fallback }
        $current = $prop.Value
    }
    if ($null -eq $current) { return $Fallback }
    return $current
}

function Get-UiInt([string]$Path, [int]$Fallback) {
    try { return [int](Get-UiValue $Path $Fallback) } catch { return $Fallback }
}

function Get-UiBool([string]$Path, [bool]$Fallback) {
    try { return [bool](Get-UiValue $Path $Fallback) } catch { return $Fallback }
}

function Get-UiColor([string]$Path, [System.Drawing.Color]$Fallback) {
    $raw = [string](Get-UiValue $Path '')
    $parts = $raw.Split(',') | ForEach-Object { $_.Trim() }
    if ($parts.Count -ne 3) { return $Fallback }
    try { return [System.Drawing.Color]::FromArgb([int]$parts[0], [int]$parts[1], [int]$parts[2]) }
    catch { return $Fallback }
}

$script:UiConfig = Load-UiConfig
$script:DefaultSlots = @('협동','상태 기준','식사 버튼','메뉴','어비스','던전','입장','완료 확인','나가기','궁극기','스킵','팔라딘')
$script:SpecialSlots = @('협동')
$script:SpecialSlotEnabled = @{'협동' = $true}
$script:SpecialSlotChecks = @{}
$script:RouteSlots = @('메뉴','어비스','던전','입장','완료 확인','나가기')
$script:CombatSlots = @('상태 기준','식사 버튼','궁극기','스킵','팔라딘')
$script:SlotAliases = @{
    '메뉴' = @('1단계')
    '어비스' = @('2단계')
    '던전' = @('3단계')
    '입장' = @('4단계')
    '퀘스트' = @('5단계')
}
$configuredSlots = @(Get-UiValue 'slots' $script:DefaultSlots)
$requiredSlotCount = ($script:DefaultSlots | Where-Object { $configuredSlots -contains $_ }).Count
if ($requiredSlotCount -eq $script:DefaultSlots.Count) { $script:Slots = $configuredSlots } else { $script:Slots = $script:DefaultSlots }
$script:Samples = @{}
$script:SlotPoints = @{}
$script:MultiSampleLimits = @{
    '협동' = 3
    '완료 확인' = 10
    '나가기' = 3
    '식사 버튼' = 3
    '궁극기' = 3
    '스킵' = 3
    '팔라딘' = 3
}
foreach ($slot in $script:Slots) { $script:Samples[$slot] = $null; $script:SlotPoints[$slot] = $null }
$script:SelectedSlot = '상태 기준'
$script:ActiveSlot = ''
$script:SlotPreviewCollapsed = $false
$script:AdvancedToolsCollapsed = $true
$script:HarborEnabled = $true
$script:DungeonRoutineEnabled = @{
    '허상의 정박지' = $true
    '광기의 동굴' = $false
}
$script:SuppressDungeonRoutineToggleEvents = $false
$script:CombatSlotEnabled = @{}
foreach ($slot in $script:CombatSlots) { $script:CombatSlotEnabled[$slot] = $true }
$script:Running = $false
$script:StopRequested = $false
$script:TargetHandle = [IntPtr]::Zero
$script:CurrentCycle = 0
$script:DefaultSampleDir = Join-Path $PSScriptRoot 'state_samples'
$script:UserDataRoot = Join-Path $PSScriptRoot 'user_data'
$script:UserSampleDir = Join-Path $script:UserDataRoot 'state_samples'
foreach ($dir in @($script:UserDataRoot, $script:UserSampleDir)) {
    if (-not [System.IO.Directory]::Exists($dir)) { [System.IO.Directory]::CreateDirectory($dir) | Out-Null }
}
$script:LegacyUserDataFiles = @('slot_points.csv','slot_regions.csv','ignore_zones.csv','user_settings.json')
foreach ($name in $script:LegacyUserDataFiles) {
    $source = Join-Path $PSScriptRoot $name
    $target = Join-Path $script:UserDataRoot $name
    if ([System.IO.File]::Exists($source) -and -not [System.IO.File]::Exists($target)) { Copy-Item -LiteralPath $source -Destination $target -Force }
}

if ([System.IO.Directory]::Exists($script:DefaultSampleDir)) {
    Get-ChildItem -LiteralPath $script:DefaultSampleDir -File -Filter '*.png' -ErrorAction SilentlyContinue | ForEach-Object {
        $target = Join-Path $script:UserSampleDir $_.Name
        if (-not [System.IO.File]::Exists($target)) { Copy-Item -LiteralPath $_.FullName -Destination $target -Force }
    }
}
$script:SampleDir = $script:UserSampleDir
$script:LogPath = Join-Path $script:UserDataRoot 'local_state_routine_log.csv'
$script:SlotPointPath = Join-Path $script:UserDataRoot 'slot_points.csv'
$script:SlotRegionPath = Join-Path $script:UserDataRoot 'slot_regions.csv'
$script:IgnoreZonePath = Join-Path $script:UserDataRoot 'ignore_zones.csv'
$script:UserSettingsPath = Join-Path $script:UserDataRoot 'user_settings.json'
$script:ClickTracePath = Join-Path $script:UserDataRoot 'click_trace_log.csv'
$script:RoutineTracePath = Join-Path $script:UserDataRoot 'routine_trace_log.csv'
$script:CrashLogPath = Join-Path $script:UserDataRoot 'crash_log.txt'
$script:DiagnosticDir = Join-Path $script:UserDataRoot 'diagnostic_frames'
$script:ReportDir = Join-Path $script:UserDataRoot 'reports'
$script:AppVersion = '1.0.66'
$script:PendingCompleteSeen = 0
$script:InsideStartedAt = $null
$script:MinimumCompleteWaitMs = 30000
$script:LongCompleteFallbackMs = 60000
$script:CombatMarkerSeen = $false
$script:BossSkipSeen = $false
$script:CombatMarkerSeenAfterSkip = $false
$script:CoopClickAttempts = 0
$script:MaxCoopClickAttempts = 2
$script:DiagnosticFailureCount = 0
$script:DiagnosticDisabledUntil = [DateTime]::MinValue
$script:IgnoreZones = New-Object System.Collections.Generic.List[object]
$script:MaxIgnoreZones = 4
$script:SelectedUltimateProfileIndex = 0
$script:SuppressUltimateProfileEvents = $false
$script:UltimateProfiles = @()
for ($ui = 1; $ui -le 5; $ui++) {
    $script:UltimateProfiles += [pscustomobject]@{ Name = ('궁극기 설정 ' + $ui) }
    $script:Samples[('궁극기_' + $ui)] = $null
    $script:SlotPoints[('궁극기_' + $ui)] = $null
}
$script:SelectedQuestProfileIndex = 0
$script:QuestProfiles = @()
for ($qi = 1; $qi -le 4; $qi++) {
    $script:QuestProfiles += [pscustomobject]@{ Name = ('퀘스트 설정 ' + $qi) }
    $script:Samples[('퀘스트_' + $qi)] = $null
    $script:SlotPoints[('퀘스트_' + $qi)] = $null
}
$script:SlotRegions = @{}
foreach ($slot in $script:Slots) { $script:SlotRegions[$slot] = $null }
for ($ui = 1; $ui -le 5; $ui++) { $script:SlotRegions[('궁극기_' + $ui)] = $null }
for ($qi = 1; $qi -le 4; $qi++) { $script:SlotRegions[('퀘스트_' + $qi)] = $null }
$script:UpdateManifestPath = Join-Path $PSScriptRoot 'update_manifest_url.txt'
$script:BackupDir = Join-Path $PSScriptRoot 'update_backup'
$script:NewLine = [Environment]::NewLine

function Write-TextFileSafe([string]$Path, [string]$Text) {
    for ($i = 0; $i -lt 3; $i++) {
        try {
            [System.IO.File]::WriteAllText($Path, $Text, [System.Text.Encoding]::UTF8)
            return $true
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds (80 * ($i + 1))
        } catch {
            return $false
        }
    }
    return $false
}
function Add-TextLineSafe([string]$Path, [string]$Line) {
    for ($i = 0; $i -lt 3; $i++) {
        try {
            [System.IO.File]::AppendAllText($Path, $Line + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
            return $true
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds (80 * ($i + 1))
        } catch {
            return $false
        }
    }
    return $false
}
function Add-TextLinesSafe([string]$Path, [System.Collections.Generic.IEnumerable[string]]$Lines) {
    return (Add-TextLineSafe $Path ([string]::Join([Environment]::NewLine, $Lines)))
}

function Write-CrashLog([string]$Context, [object]$ErrorObject) {
    try {
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add(('==== {0} ====' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')))
        $lines.Add(('version={0}' -f $script:AppVersion))
        $lines.Add(('context={0}' -f $Context))
        if ($null -ne $ErrorObject) {
            if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) {
                $lines.Add(('message={0}' -f $ErrorObject.Exception.Message))
                $lines.Add(('type={0}' -f $ErrorObject.Exception.GetType().FullName))
                $lines.Add(('position={0}' -f $ErrorObject.InvocationInfo.PositionMessage))
                $lines.Add(('stack={0}' -f $ErrorObject.ScriptStackTrace))
            } elseif ($ErrorObject -is [System.Exception]) {
                $lines.Add(('message={0}' -f $ErrorObject.Message))
                $lines.Add(('type={0}' -f $ErrorObject.GetType().FullName))
                $lines.Add(('stack={0}' -f $ErrorObject.StackTrace))
            } else {
                $lines.Add(('object={0}' -f [string]$ErrorObject))
            }
        }
        [void](Add-TextLinesSafe $script:CrashLogPath $lines)
    } catch {
    }
}

function Remove-OldItemsSafe([string]$Path, [string]$Filter, [int]$KeepNewest, [int]$OlderThanDays) {
    try {
        if (-not [System.IO.Directory]::Exists($Path)) { return 0 }
        $cutoff = (Get-Date).AddDays(-1 * [Math]::Max(1, $OlderThanDays))
        $items = @(Get-ChildItem -LiteralPath $Path -File -Filter $Filter -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        $remove = @()
        if ($items.Count -gt $KeepNewest) { $remove += @($items | Select-Object -Skip $KeepNewest) }
        $remove += @($items | Where-Object { $_.LastWriteTime -lt $cutoff })
        $removed = 0
        foreach ($item in @($remove | Sort-Object FullName -Unique)) {
            try { Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop; $removed++ } catch { }
        }
        return $removed
    } catch { return 0 }
}

function Remove-OldDirectoriesSafe([string]$Path, [int]$KeepNewest, [int]$OlderThanDays) {
    try {
        if (-not [System.IO.Directory]::Exists($Path)) { return 0 }
        $cutoff = (Get-Date).AddDays(-1 * [Math]::Max(1, $OlderThanDays))
        $items = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        $remove = @()
        if ($items.Count -gt $KeepNewest) { $remove += @($items | Select-Object -Skip $KeepNewest) }
        $remove += @($items | Where-Object { $_.LastWriteTime -lt $cutoff })
        $removed = 0
        foreach ($item in @($remove | Sort-Object FullName -Unique)) {
            try { Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop; $removed++ } catch { }
        }
        return $removed
    } catch { return 0 }
}

function Invoke-MaintenanceCleanup {
    try {
        $removedDiag = Remove-OldItemsSafe $script:DiagnosticDir '*.png' 300 3
        $removedReports = Remove-OldItemsSafe $script:ReportDir 'problem_report_*.zip' 20 30
        $removedReportDirs = Remove-OldDirectoriesSafe $script:ReportDir 20 30
        $removedUpdateBackups = Remove-OldDirectoriesSafe $script:BackupDir 5 30
        $installBackup = Join-Path $PSScriptRoot 'install_backup'
        $removedInstallBackups = Remove-OldDirectoriesSafe $installBackup 5 30
        $detail = 'diagnostic_png=' + $removedDiag + '; report_zip=' + $removedReports + '; report_dirs=' + $removedReportDirs + '; update_backup_dirs=' + $removedUpdateBackups + '; install_backup_dirs=' + $removedInstallBackups
        Write-CrashLog ('maintenance-cleanup ' + $detail) $null
    } catch {
        Write-CrashLog 'maintenance-cleanup failed' $_
    }
}

New-Item -ItemType Directory -Force -Path $script:SampleDir | Out-Null
New-Item -ItemType Directory -Force -Path $script:BackupDir | Out-Null
New-Item -ItemType Directory -Force -Path $script:DiagnosticDir | Out-Null
Write-CrashLog 'app-launch' $null
Invoke-MaintenanceCleanup

$nativeSource = @'
using System;
using System.Text;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public static class NativeInput {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT lpPoint);
    [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr hWnd, ref POINT lpPoint);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool PostMessage(IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool MessageBeep(uint uType);
    [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    public const uint INPUT_MOUSE = 0;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
    public const uint KEYEVENTF_KEYUP = 0x0002;
    public const uint WM_MOUSEMOVE = 0x0200;
    public const uint WM_LBUTTONDOWN = 0x0201;
    public const uint WM_LBUTTONUP = 0x0202;
    public const uint MK_LBUTTON = 0x0001;
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public UIntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public MOUSEINPUT mi; }
}
public static class VisionFinder {
    public static string LastMode = "";
    public static double LastScore = 0.0;
    public static double LastSecondScore = 0.0;
    public static double LastScoreGap = 0.0;
    public static bool LastAmbiguous = false;

    private static void ResetLastMatch() {
        LastMode = "";
        LastScore = 0.0;
        LastSecondScore = 0.0;
        LastScoreGap = 0.0;
        LastAmbiguous = false;
    }

    private static bool IsFarCandidate(int x1, int y1, int x2, int y2, int templateWidth, int templateHeight) {
        if (x1 < 0 || y1 < 0 || x2 < 0 || y2 < 0) return true;
        int minDistance = Math.Max(12, Math.Min(templateWidth, templateHeight) / 3);
        return Math.Abs(x1 - x2) > minDistance || Math.Abs(y1 - y2) > minDistance;
    }

    private static void TrackCandidate(double score, int x, int y, int templateWidth, int templateHeight, ref double bestScore, ref int bestX, ref int bestY, ref double secondScore) {
        if (score > bestScore) {
            if (bestScore >= 0.0 && IsFarCandidate(bestX, bestY, x, y, templateWidth, templateHeight) && bestScore > secondScore) {
                secondScore = bestScore;
            }
            bestScore = score;
            bestX = x;
            bestY = y;
            return;
        }
        if (IsFarCandidate(bestX, bestY, x, y, templateWidth, templateHeight) && score > secondScore) {
            secondScore = score;
        }
    }

    private static void SetMatchResult(string mode, double score, double secondScore) {
        LastMode = mode;
        LastScore = score;
        LastSecondScore = Math.Max(0.0, secondScore);
        LastScoreGap = score - LastSecondScore;
        LastAmbiguous = LastSecondScore >= 0.0 && LastScoreGap < 0.035;
    }

    public static Bitmap Capture(Rectangle bounds) {
        Bitmap bmp = new Bitmap(bounds.Width, bounds.Height, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) { g.CopyFromScreen(bounds.Left, bounds.Top, 0, 0, bounds.Size, CopyPixelOperation.SourceCopy); }
        return bmp;
    }

    private static int Gray(byte b, byte g, byte r) {
        return (r * 299 + g * 587 + b * 114) / 1000;
    }

    private static int SaturationRange(byte b, byte g, byte r) {
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        return max - min;
    }

    private static int GrayAt(byte[] data, int stride, int width, int height, int x, int y) {
        if (x < 0) x = 0; if (y < 0) y = 0;
        if (x >= width) x = width - 1; if (y >= height) y = height - 1;
        int i = y * stride + x * 4;
        return Gray(data[i], data[i + 1], data[i + 2]);
    }

    private static int EdgeAt(byte[] data, int stride, int width, int height, int x, int y) {
        int c = GrayAt(data, stride, width, height, x, y);
        int l = GrayAt(data, stride, width, height, x - 1, y);
        int u = GrayAt(data, stride, width, height, x, y - 1);
        int e = Math.Abs(c - l) + Math.Abs(c - u);
        return e > 255 ? 255 : e;
    }

    private static int ChannelValue(int channel, byte b, byte g, byte r) {
        if (channel == 0) return b;
        if (channel == 1) return g;
        if (channel == 2) return r;
        return Gray(b, g, r);
    }

    private static bool IsBrightTextPixel(byte b, byte g, byte r, byte a, int threshold) {
        if (a < 24) return false;
        int gray = Gray(b, g, r);
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        return gray >= threshold && (max - min) <= 60;
    }

    public static Rectangle FindSaturatedColorSample(Rectangle screenBounds, string samplePath, int searchStep, int sampleStep, int tolerance, double requiredScore) {
        ResetLastMatch();
        using (Bitmap screen = Capture(screenBounds))
        using (Bitmap rawSample = new Bitmap(samplePath))
        using (Bitmap sample = new Bitmap(rawSample.Width, rawSample.Height, PixelFormat.Format32bppArgb)) {
            using (Graphics sg = Graphics.FromImage(sample)) { sg.DrawImage(rawSample, 0, 0, rawSample.Width, rawSample.Height); }
            if (sample.Width > screen.Width || sample.Height > screen.Height) return Rectangle.Empty;
            Rectangle sr = new Rectangle(0, 0, screen.Width, screen.Height);
            Rectangle tr = new Rectangle(0, 0, sample.Width, sample.Height);
            BitmapData sd = screen.LockBits(sr, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            BitmapData td = sample.LockBits(tr, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try {
                int ss = sd.Stride, ts = td.Stride, sw = screen.Width, sh = screen.Height, tw = sample.Width, th = sample.Height;
                byte[] s = new byte[ss * sh];
                byte[] t = new byte[ts * th];
                Marshal.Copy(sd.Scan0, s, 0, s.Length);
                Marshal.Copy(td.Scan0, t, 0, t.Length);
                int[] xs = new int[tw * th];
                int[] ys = new int[tw * th];
                int colorCount = 0;
                for (int ty = 0; ty < th; ty += sampleStep) {
                    int tRow = ty * ts;
                    for (int tx = 0; tx < tw; tx += sampleStep) {
                        int ti = tRow + tx * 4;
                        byte tb = t[ti], tg = t[ti + 1], trc = t[ti + 2], ta = t[ti + 3];
                        int sat = SaturationRange(tb, tg, trc);
                        int max = Math.Max(trc, Math.Max(tg, tb));
                        if (ta >= 24 && sat >= 45 && max >= 95) {
                            xs[colorCount] = tx;
                            ys[colorCount] = ty;
                            colorCount++;
                        }
                    }
                }
                if (colorCount < 12) return Rectangle.Empty;
                double bestScore = -1.0, secondScore = -1.0;
                int bestX = -1, bestY = -1;
                int colorTolerance = Math.Max(tolerance, 48);
                for (int y = 0; y <= sh - th; y += searchStep) {
                    if ((NativeInput.GetAsyncKeyState(0x75) & unchecked((short)0x8000)) != 0) { LastMode = "stopped-f6"; return Rectangle.Empty; }
                    for (int x = 0; x <= sw - tw; x += searchStep) {
                        int ok = 0;
                        for (int i = 0; i < colorCount; i++) {
                            int tx = xs[i], ty = ys[i];
                            int si = (y + ty) * ss + (x + tx) * 4;
                            int ti = ty * ts + tx * 4;
                            byte sb = s[si], sgc = s[si + 1], srcc = s[si + 2];
                            byte tb = t[ti], tg = t[ti + 1], trc = t[ti + 2];
                            if (SaturationRange(sb, sgc, srcc) < 35) continue;
                            if (Math.Abs(sb - tb) <= colorTolerance && Math.Abs(sgc - tg) <= colorTolerance && Math.Abs(srcc - trc) <= colorTolerance) ok++;
                        }
                        double score = (double)ok / colorCount;
                        TrackCandidate(score, x, y, tw, th, ref bestScore, ref bestX, ref bestY, ref secondScore);
                    }
                }
                if (bestScore >= requiredScore) {
                    SetMatchResult("saturated-color", bestScore, secondScore);
                    return new Rectangle(screenBounds.Left + bestX, screenBounds.Top + bestY, tw, th);
                }
                return Rectangle.Empty;
            } finally { screen.UnlockBits(sd); sample.UnlockBits(td); }
        }
    }

    public static bool HasQuestTextSignal(Rectangle screenBounds) {
        ResetLastMatch();
        if (screenBounds.Width < 40 || screenBounds.Height < 20) return false;
        using (Bitmap screen = Capture(screenBounds)) {
            BitmapData sd = screen.LockBits(new Rectangle(0, 0, screen.Width, screen.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try {
                int sw = screen.Width, sh = screen.Height, ss = Math.Abs(sd.Stride);
                byte[] s = new byte[ss * sh];
                Marshal.Copy(sd.Scan0, s, 0, s.Length);
                int textPixels = 0;
                int[] colHits = new int[sw];
                int[] rowHits = new int[sh];
                for (int y = 0; y < sh; y += 1) {
                    int row = y * ss;
                    for (int x = 0; x < sw; x += 1) {
                        int i = row + x * 4;
                        byte b = s[i], g = s[i + 1], r = s[i + 2];
                        int max = Math.Max(r, Math.Max(g, b));
                        int min = Math.Min(r, Math.Min(g, b));
                        bool white = (r >= 205 && g >= 205 && b >= 205 && (max - min) <= 70);
                        bool orange = (r >= 205 && g >= 115 && g <= 205 && b <= 95 && (r - g) >= 25 && (g - b) >= 35);
                        if (white || orange) {
                            textPixels++;
                            colHits[x]++;
                            rowHits[y]++;
                        }
                    }
                }
                int hitCols = 0, hitRows = 0;
                for (int x = 0; x < sw; x++) if (colHits[x] >= 2) hitCols++;
                for (int y = 0; y < sh; y++) if (rowHits[y] >= 8) hitRows++;
                double density = (double)textPixels / (double)(sw * sh);
                double spread = ((double)hitCols / Math.Max(1, sw)) * 0.65 + ((double)hitRows / Math.Max(1, sh)) * 0.35;
                SetMatchResult("quest-text-signal", Math.Min(1.0, density * 6.0 + spread * 0.75), -1.0);
                return textPixels >= 650 && hitCols >= Math.Min(110, sw / 3) && hitRows >= 18 && LastScore >= 0.62;
            } finally { screen.UnlockBits(sd); }
        }
    }

    public static Rectangle FindBrightTextSample(Rectangle screenBounds, string samplePath, int searchStep, int sampleStep, double requiredScore) {
        ResetLastMatch();
        using (Bitmap screen = Capture(screenBounds))
        using (Bitmap rawSample = new Bitmap(samplePath))
        using (Bitmap sample = new Bitmap(rawSample.Width, rawSample.Height, PixelFormat.Format32bppArgb)) {
            using (Graphics sg = Graphics.FromImage(sample)) { sg.DrawImage(rawSample, 0, 0, rawSample.Width, rawSample.Height); }
            if (sample.Width > screen.Width || sample.Height > screen.Height) return Rectangle.Empty;
            BitmapData sd = screen.LockBits(new Rectangle(0, 0, screen.Width, screen.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            BitmapData td = sample.LockBits(new Rectangle(0, 0, sample.Width, sample.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try {
                int sw = screen.Width, sh = screen.Height, tw = sample.Width, th = sample.Height;
                int ss = Math.Abs(sd.Stride), ts = Math.Abs(td.Stride);
                byte[] s = new byte[ss * sh];
                byte[] t = new byte[ts * th];
                Marshal.Copy(sd.Scan0, s, 0, s.Length);
                Marshal.Copy(td.Scan0, t, 0, t.Length);

                System.Collections.Generic.List<int> textXs = new System.Collections.Generic.List<int>();
                System.Collections.Generic.List<int> textYs = new System.Collections.Generic.List<int>();
                for (int ty = 0; ty < th; ty += sampleStep) {
                    int tRow = ty * ts;
                    for (int tx = 0; tx < tw; tx += sampleStep) {
                        int ti = tRow + tx * 4;
                        if (IsBrightTextPixel(t[ti], t[ti + 1], t[ti + 2], t[ti + 3], 170)) {
                            textXs.Add(tx);
                            textYs.Add(ty);
                        }
                    }
                }
                int textCount = textXs.Count;
                if (textCount < Math.Max(6, (tw * th) / Math.Max(1, sampleStep * sampleStep * 120))) return Rectangle.Empty;

                double bestScore = -1.0; int bestX = -1, bestY = -1; double secondScore = -1.0;
                for (int y = 0; y <= sh - th; y += searchStep) {
                    if ((NativeInput.GetAsyncKeyState(0x75) & unchecked((short)0x8000)) != 0) { LastMode = "stopped-f6"; return Rectangle.Empty; }
                    for (int x = 0; x <= sw - tw; x += searchStep) {
                        int ok = 0;
                        for (int i = 0; i < textCount; i++) {
                            int sx = x + textXs[i];
                            int sy = y + textYs[i];
                            int si = sy * ss + sx * 4;
                            if (IsBrightTextPixel(s[si], s[si + 1], s[si + 2], 255, 170)) ok++;
                        }
                        double score = (double)ok / textCount;
                        TrackCandidate(score, x, y, tw, th, ref bestScore, ref bestX, ref bestY, ref secondScore);
                    }
                }
                if (bestScore >= requiredScore) {
                    SetMatchResult("bright-text", bestScore, secondScore);
                    return new Rectangle(screenBounds.Left + bestX, screenBounds.Top + bestY, tw, th);
                }
                return Rectangle.Empty;
            } finally { screen.UnlockBits(sd); sample.UnlockBits(td); }
        }
    }

    public static Rectangle FindSample(Rectangle screenBounds, string samplePath, int searchStep, int sampleStep, int tolerance, double requiredScore) {
        ResetLastMatch();
        using (Bitmap screen = Capture(screenBounds))
        using (Bitmap rawSample = new Bitmap(samplePath))
        using (Bitmap sample = new Bitmap(rawSample.Width, rawSample.Height, PixelFormat.Format32bppArgb)) {
            using (Graphics sg = Graphics.FromImage(sample)) { sg.DrawImage(rawSample, 0, 0, rawSample.Width, rawSample.Height); }
            if (sample.Width > screen.Width || sample.Height > screen.Height) return Rectangle.Empty;
            BitmapData sd = screen.LockBits(new Rectangle(0, 0, screen.Width, screen.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            BitmapData td = sample.LockBits(new Rectangle(0, 0, sample.Width, sample.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try {
                int sw = screen.Width, sh = screen.Height, tw = sample.Width, th = sample.Height;
                int ss = Math.Abs(sd.Stride), ts = Math.Abs(td.Stride);
                byte[] s = new byte[ss * sh];
                byte[] t = new byte[ts * th];
                Marshal.Copy(sd.Scan0, s, 0, s.Length);
                Marshal.Copy(td.Scan0, t, 0, t.Length);
                int sampleCount = 0;
                for (int ty = 0; ty < th; ty += sampleStep) for (int tx = 0; tx < tw; tx += sampleStep) sampleCount++;
                int[] minCh = new int[] { 255, 255, 255, 255 };
                int[] maxCh = new int[] { 0, 0, 0, 0 };
                for (int ty = 0; ty < th; ty += sampleStep) {
                    int tRow = ty * ts;
                    for (int tx = 0; tx < tw; tx += sampleStep) {
                        int ti = tRow + tx * 4;
                        byte tb = t[ti], tg = t[ti + 1], tr = t[ti + 2];
                        for (int ch = 0; ch < 4; ch++) {
                            int v = ChannelValue(ch, tb, tg, tr);
                            if (v < minCh[ch]) minCh[ch] = v;
                            if (v > maxCh[ch]) maxCh[ch] = v;
                        }
                    }
                }
                int maskChannel = 3;
                int maskRange = -1;
                for (int ch = 0; ch < 4; ch++) {
                    int range = maxCh[ch] - minCh[ch];
                    if (range > maskRange) { maskRange = range; maskChannel = ch; }
                }
                int maskThreshold = (minCh[maskChannel] + maxCh[maskChannel]) / 2;
                int maskMargin = Math.Max(18, maskRange / 5);
                double bestPrimaryScore = -1; int bestPrimaryX = -1, bestPrimaryY = -1; string bestPrimaryMode = ""; double secondPrimaryScore = -1;
                double bestFallbackScore = -1; int bestFallbackX = -1, bestFallbackY = -1; string bestFallbackMode = ""; double secondFallbackScore = -1;
                int grayTolerance = Math.Max(tolerance, 22);
                int edgeTolerance = Math.Max(tolerance * 2, 55);
                int contrastSlack = Math.Max(tolerance, 30);

                for (int y = 0; y <= sh - th; y += searchStep) {
                    if ((NativeInput.GetAsyncKeyState(0x75) & unchecked((short)0x8000)) != 0) { LastMode = "stopped-f6"; return Rectangle.Empty; }
                    for (int x = 0; x <= sw - tw; x += searchStep) {
                        int originalOk = 0, grayOk = 0, contrastOk = 0, edgeOk = 0, edgeTotal = 0, maskOk = 0, maskTotal = 0;
                        for (int ty = 0; ty < th; ty += sampleStep) {
                            int sRow = (y + ty) * ss; int tRow = ty * ts;
                            for (int tx = 0; tx < tw; tx += sampleStep) {
                                int si = sRow + (x + tx) * 4; int ti = tRow + tx * 4;
                                byte sb = s[si], sg = s[si + 1], sr = s[si + 2];
                                byte tb = t[ti], tg = t[ti + 1], tr = t[ti + 2];
                                if (Math.Abs(sb - tb) <= tolerance && Math.Abs(sg - tg) <= tolerance && Math.Abs(sr - tr) <= tolerance) originalOk++;
                                int sgx = Gray(sb, sg, sr);
                                int tgx = Gray(tb, tg, tr);
                                if (Math.Abs(sgx - tgx) <= grayTolerance) grayOk++;
                                bool sc = sgx >= 128;
                                bool tc = tgx >= 128;
                                if (sc == tc || Math.Abs(sgx - tgx) <= contrastSlack) contrastOk++;
                                int sv = ChannelValue(maskChannel, sb, sg, sr);
                                int tv = ChannelValue(maskChannel, tb, tg, tr);
                                if (Math.Abs(tv - maskThreshold) >= maskMargin) {
                                    maskTotal++;
                                    if ((sv >= maskThreshold) == (tv >= maskThreshold)) maskOk++;
                                }
                                int se = EdgeAt(s, ss, sw, sh, x + tx, y + ty);
                                int te = EdgeAt(t, ts, tw, th, tx, ty);
                                if (te > 35 || se > 35) {
                                    edgeTotal++;
                                    if (Math.Abs(se - te) <= edgeTolerance) edgeOk++;
                                }
                            }
                        }
                        double originalScore = (double)originalOk / sampleCount;
                        double grayScore = (double)grayOk / sampleCount;
                        double contrastScore = (double)contrastOk / sampleCount;
                        double edgeScore = edgeTotal > 0 ? (double)edgeOk / edgeTotal : 0.0;
                        double maskScore = maskTotal > 0 ? (double)maskOk / maskTotal : 0.0;

                        bool originalStrong = originalScore >= requiredScore;
                        bool grayStrong = grayScore >= requiredScore;
                        bool maskStrong = maskTotal >= Math.Max(8, sampleCount / 4) && maskScore >= Math.Max(requiredScore + 0.04, 0.91);
                        bool edgeStrong = edgeTotal >= Math.Max(4, sampleCount / 12) && edgeScore >= Math.Max(requiredScore + 0.05, 0.92);
                        bool supportOk = originalScore >= requiredScore - 0.10 || grayScore >= requiredScore - 0.06 || contrastScore >= requiredScore - 0.04 || edgeStrong;
                        if (originalStrong || grayStrong) {
                            double primaryScore = originalScore;
                            string primaryMode = "original";
                            if (grayScore * 0.99 > primaryScore) { primaryScore = grayScore * 0.99; primaryMode = "gray"; }
                            if (primaryScore > bestPrimaryScore) { bestPrimaryMode = primaryMode; }
                            TrackCandidate(primaryScore, x, y, tw, th, ref bestPrimaryScore, ref bestPrimaryX, ref bestPrimaryY, ref secondPrimaryScore);
                        } else if (maskStrong && supportOk) {
                            double fallbackScore = maskScore * 0.98;
                            string fallbackMode = "channel-mask";
                            if (edgeStrong && edgeScore * 0.88 > fallbackScore) { fallbackScore = edgeScore * 0.88; fallbackMode = "channel-mask+edge"; }
                            if (fallbackScore > bestFallbackScore) { bestFallbackMode = fallbackMode; }
                            TrackCandidate(fallbackScore, x, y, tw, th, ref bestFallbackScore, ref bestFallbackX, ref bestFallbackY, ref secondFallbackScore);
                        }
                    }
                }
                if (bestPrimaryScore >= requiredScore) {
                    SetMatchResult("primary-" + bestPrimaryMode, bestPrimaryScore, secondPrimaryScore);
                    return new Rectangle(screenBounds.Left + bestPrimaryX, screenBounds.Top + bestPrimaryY, tw, th);
                }
                if (bestFallbackScore >= requiredScore) {
                    SetMatchResult("fallback-" + bestFallbackMode, bestFallbackScore, secondFallbackScore);
                    return new Rectangle(screenBounds.Left + bestFallbackX, screenBounds.Top + bestFallbackY, tw, th);
                }
                return Rectangle.Empty;
            } finally { screen.UnlockBits(sd); sample.UnlockBits(td); }
        }
    }
}
public class HotKeyWindowFilter : IMessageFilter {
    public Action<int> OnHotKey;
    public bool PreFilterMessage(ref Message m) {
        if (m.Msg == 0x0312) { if (OnHotKey != null) OnHotKey(m.WParam.ToInt32()); return true; }
        return false;
    }
}
'@
Add-Type -TypeDefinition $nativeSource -ReferencedAssemblies System.Drawing,System.Windows.Forms

function Get-WindowTitle([IntPtr]$Handle) {
    $length = [NativeInput]::GetWindowTextLength($Handle)
    if ($length -le 0) { return '' }
    $builder = New-Object System.Text.StringBuilder ($length + 1)
    [void][NativeInput]::GetWindowText($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}
function Get-VisibleWindows {
    $items = New-Object System.Collections.Generic.List[object]
    $callback = [NativeInput+EnumWindowsProc]{
        param([IntPtr]$hWnd, [IntPtr]$lParam)
        if ([NativeInput]::IsWindowVisible($hWnd)) {
            $title = Get-WindowTitle $hWnd
            if (-not [string]::IsNullOrWhiteSpace($title)) { $items.Add([pscustomobject]@{ Handle = $hWnd; Title = $title }) }
        }
        return $true
    }
    [void][NativeInput]::EnumWindows($callback, [IntPtr]::Zero)
    return $items | Sort-Object Title
}
function Find-WindowByTitlePart([string]$TitlePart) {
    foreach ($w in (Get-VisibleWindows)) {
        if ($w.Title.IndexOf($TitlePart, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $w }
    }
    return $null
}
function Get-WindowBounds([IntPtr]$Handle) {
    $rect = New-Object NativeInput+RECT
    if (-not [NativeInput]::GetWindowRect($Handle, [ref]$rect)) { return [System.Drawing.Rectangle]::Empty }
    $width = $rect.Right - $rect.Left; $height = $rect.Bottom - $rect.Top
    if ($width -le 0 -or $height -le 0) { return [System.Drawing.Rectangle]::Empty }
    return [System.Drawing.Rectangle]::new($rect.Left, $rect.Top, $width, $height)
}
function Get-WindowCenter([IntPtr]$Handle) {
    $bounds = Get-WindowBounds $Handle
    if ($bounds.IsEmpty) { return $null }
    return [System.Drawing.Point]::new([int]($bounds.Left + $bounds.Width / 2), [int]($bounds.Top + $bounds.Height / 2))
}
function Get-SearchBounds([System.Windows.Forms.Screen]$Screen) {
    if ($script:TargetHandle -ne [IntPtr]::Zero) {
        $windowBounds = Get-WindowBounds $script:TargetHandle
        if (-not $windowBounds.IsEmpty) {
            $left = [Math]::Max($windowBounds.Left, $Screen.Bounds.Left)
            $top = [Math]::Max($windowBounds.Top, $Screen.Bounds.Top)
            $right = [Math]::Min($windowBounds.Right, $Screen.Bounds.Right)
            $bottom = [Math]::Min($windowBounds.Bottom, $Screen.Bounds.Bottom)
            if ($right -gt $left -and $bottom -gt $top) { return [System.Drawing.Rectangle]::new($left, $top, $right - $left, $bottom - $top) }
        }
    }
    return $Screen.Bounds
}
function Get-MoveSettleMs {
    try {
        if ($script:MoveSettleBox -and -not $script:MoveSettleBox.IsDisposed) { return [int]$script:MoveSettleBox.Value }
    } catch { }
    return 1000
}
function Get-ClickHoldMs {
    try {
        if ($script:ClickHoldBox -and -not $script:ClickHoldBox.IsDisposed) { return [int]$script:ClickHoldBox.Value }
    } catch { }
    return 1200
}
function Get-ClickMode {
    try {
        if ($script:ClickModeBox -and -not $script:ClickModeBox.IsDisposed -and $script:ClickModeBox.SelectedItem) { return [string]$script:ClickModeBox.SelectedItem }
    } catch { }
    return '둘다'
}
function Write-ClickTrace([int]$X, [int]$Y, [string]$Mode, [int]$DownSent, [int]$UpSent, [int]$ErrorCode, [string]$Note) {
    if (-not [System.IO.File]::Exists($script:ClickTracePath)) { [void](Write-TextFileSafe $script:ClickTracePath 'time,x,y,mode,down_sent,up_sent,error_code,note') }
    $line = @((Get-Date).ToString('s'), $X, $Y, (Csv $Mode), $DownSent, $UpSent, $ErrorCode, (Csv $Note)) -join ','
    [void](Add-TextLineSafe $script:ClickTracePath $line)
}
function New-MouseLParam([int]$X, [int]$Y) {
    return [IntPtr]((($Y -band 0xFFFF) -shl 16) -bor ($X -band 0xFFFF))
}
function Invoke-BackgroundClick([int]$X, [int]$Y, [int]$HoldMs) {
    if ($script:TargetHandle -eq [IntPtr]::Zero) { return [pscustomobject]@{ Down = 0; Up = 0; Error = 0; Note = 'target_handle_empty' } }
    $point = New-Object 'NativeInput+POINT'
    $point.X = $X
    $point.Y = $Y
    [void][NativeInput]::ScreenToClient($script:TargetHandle, [ref]$point)
    $lParam = New-MouseLParam $point.X $point.Y
    [void][NativeInput]::PostMessage($script:TargetHandle, [NativeInput]::WM_MOUSEMOVE, [UIntPtr]::Zero, $lParam)
    Start-Sleep -Milliseconds 40
    $downOk = [NativeInput]::PostMessage($script:TargetHandle, [NativeInput]::WM_LBUTTONDOWN, [UIntPtr][NativeInput]::MK_LBUTTON, $lParam)
    $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Start-Sleep -Milliseconds $HoldMs
    $upOk = [NativeInput]::PostMessage($script:TargetHandle, [NativeInput]::WM_LBUTTONUP, [UIntPtr]::Zero, $lParam)
    if ($errorCode -eq 0) { $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error() }
    return [pscustomobject]@{ Down = [int]$downOk; Up = [int]$upOk; Error = $errorCode; Note = ('PostMessage client X=' + $point.X + ', Y=' + $point.Y) }
}
function Invoke-LeftClick([int]$X, [int]$Y, [int]$HoldOverrideMs = -1) {
    $holdMs = if ($HoldOverrideMs -gt 0) { $HoldOverrideMs } else { Get-ClickHoldMs }
    $settleMs = Get-MoveSettleMs
    $mode = Get-ClickMode
    if ($mode -ne '백그라운드') {
        [void][NativeInput]::SetCursorPos($X, $Y)
        Start-Sleep -Milliseconds $settleMs
        $current = Get-CurrentCursorPoint
        if ($null -ne $current -and ([Math]::Abs($current.X - $X) -gt 2 -or [Math]::Abs($current.Y - $Y) -gt 2)) {
            [void][NativeInput]::SetCursorPos($X, $Y)
            Start-Sleep -Milliseconds ([Math]::Max(250, [int]($settleMs / 2)))
        }
    }
    $downSent = 0
    $upSent = 0
    $errorCode = 0
    $note = ''
    if ($mode -eq '백그라운드') {
        $result = Invoke-BackgroundClick $X $Y $holdMs
        $downSent = $result.Down
        $upSent = $result.Up
        $errorCode = $result.Error
        $note = $result.Note
    }
    if ($mode -eq 'SendInput' -or $mode -eq '둘다') {
        $size = [System.Runtime.InteropServices.Marshal]::SizeOf([type]'NativeInput+INPUT')
        $down = New-Object 'NativeInput+INPUT[]' 1
        $down[0].type = [NativeInput]::INPUT_MOUSE
        $down[0].mi.dwFlags = [NativeInput]::MOUSEEVENTF_LEFTDOWN
        $downSent = [int][NativeInput]::SendInput(1, $down, $size)
        $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Start-Sleep -Milliseconds $holdMs
        $up = New-Object 'NativeInput+INPUT[]' 1
        $up[0].type = [NativeInput]::INPUT_MOUSE
        $up[0].mi.dwFlags = [NativeInput]::MOUSEEVENTF_LEFTUP
        $upSent = [int][NativeInput]::SendInput(1, $up, $size)
        if ($errorCode -eq 0) { $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error() }
        $note = 'SendInput'
    }
    if ($mode -eq 'mouse_event' -or $mode -eq '둘다') {
        if ($mode -eq '둘다') { Start-Sleep -Milliseconds 250 }
        [NativeInput]::mouse_event([NativeInput]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds $holdMs
        [NativeInput]::mouse_event([NativeInput]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
        if ($note.Length -gt 0) { $note += '+mouse_event' } else { $note = 'mouse_event'; $downSent = 1; $upSent = 1 }
    }
    Write-ClickTrace $X $Y $mode $downSent $upSent $errorCode $note
    Start-Sleep -Milliseconds 120
}
function Invoke-UltimateKey([string]$ProfileName) {
    if ($script:TargetHandle -ne [IntPtr]::Zero) {
        [void][NativeInput]::SetForegroundWindow($script:TargetHandle)
        Start-Sleep -Milliseconds 80
    }
    [NativeInput]::keybd_event(0x36, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 70
    [NativeInput]::keybd_event(0x36, 0, [NativeInput]::KEYEVENTF_KEYUP, [UIntPtr]::Zero)
    Write-RoutineTrace $script:CurrentCycle 'key' '궁극기' 'send-vk6' ([System.Drawing.Rectangle]::Empty) $ProfileName
    Start-Sleep -Milliseconds 120
}
function Invoke-BKey([string]$Reason) {
    if ($script:TargetHandle -ne [IntPtr]::Zero) {
        [void][NativeInput]::SetForegroundWindow($script:TargetHandle)
        Start-Sleep -Milliseconds 100
    }
    [System.Windows.Forms.SendKeys]::SendWait('b')
    Write-RoutineTrace $script:CurrentCycle 'key' '식사 버튼' 'send-b' ([System.Drawing.Rectangle]::Empty) $Reason
    Start-Sleep -Milliseconds 180
}
function Invoke-PaladinKey([string]$Reason) {
    if ($script:TargetHandle -ne [IntPtr]::Zero) {
        [void][NativeInput]::SetForegroundWindow($script:TargetHandle)
        Start-Sleep -Milliseconds 100
    }
    [System.Windows.Forms.SendKeys]::SendWait('{F5}')
    Write-RoutineTrace $script:CurrentCycle 'key' '팔라딘' 'send-f5' ([System.Drawing.Rectangle]::Empty) $Reason
    Start-Sleep -Milliseconds 180
}
function Invoke-EscapeTwice([string]$Reason) {
    if ($script:TargetHandle -ne [IntPtr]::Zero) {
        [void][NativeInput]::SetForegroundWindow($script:TargetHandle)
        Start-Sleep -Milliseconds 100
    }
    for ($i = 1; $i -le 2; $i++) {
        [NativeInput]::keybd_event(0x1B, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 70
        [NativeInput]::keybd_event(0x1B, 0, [NativeInput]::KEYEVENTF_KEYUP, [UIntPtr]::Zero)
        Write-RoutineTrace $script:CurrentCycle 'key' '입장_전투중' ('send-esc-' + $i) ([System.Drawing.Rectangle]::Empty) $Reason
        if ($i -lt 2) { Sleep-WithStop 500 }
    }
    Start-Sleep -Milliseconds 180
}
function Load-ImageUnlocked([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $stream = New-Object System.IO.MemoryStream(,$bytes)
    $image = [System.Drawing.Image]::FromStream($stream)
    $copy = New-Object System.Drawing.Bitmap($image)
    $image.Dispose(); $stream.Dispose(); return $copy
}
function Get-UltimateSlotKey([int]$Index = -1) {
    if ($Index -lt 0) { $Index = [int]$script:SelectedUltimateProfileIndex }
    $Index = [Math]::Max(0, [Math]::Min(4, $Index))
    return '궁극기_' + ($Index + 1)
}
function Get-QuestSlotKey([int]$Index = -1) {
    if ($Index -lt 0) { $Index = [int]$script:SelectedQuestProfileIndex }
    $Index = [Math]::Max(0, [Math]::Min(3, $Index))
    return '퀘스트_' + ($Index + 1)
}
function Get-DungeonRouteSlotKey([string]$DungeonName, [string]$Slot) {
    if (($DungeonName -eq '광기의 동굴') -and ($script:RouteSlots -contains $Slot)) { return '광기의 동굴_' + $Slot }
    return $Slot
}
function Get-SlotDisplayName([string]$Slot) {
    if ($Slot -like '광기의 동굴_*') { return $Slot.Substring('광기의 동굴_'.Length) }
    return $Slot
}
function Resolve-RouteSlotFromStorageKey([string]$Slot) {
    if ($Slot -like '광기의 동굴_*') {
        $base = $Slot.Substring('광기의 동굴_'.Length)
        if ($script:RouteSlots -contains $base) { return $base }
    }
    return $Slot
}
function Get-EffectiveSlotKey([string]$Slot) {
    if ($Slot -eq '궁극기') { return Get-UltimateSlotKey }
    if ($Slot -eq '퀘스트') { return Get-QuestSlotKey }
    if ($Slot -like '광기의 동굴_*') { return $Slot }
    return $Slot
}
function Get-SlotStorageKeys {
    $keys = New-Object System.Collections.Generic.List[string]
    foreach ($slot in $script:Slots) {
        if ($slot -eq '궁극기') {
            for ($i = 0; $i -lt 5; $i++) { [void]$keys.Add((Get-UltimateSlotKey $i)) }
        } elseif ($slot -eq '퀘스트') {
            for ($i = 0; $i -lt 4; $i++) { [void]$keys.Add((Get-QuestSlotKey $i)) }
        } else {
            [void]$keys.Add($slot)
        }
    }
    foreach ($slot in $script:RouteSlots) { [void]$keys.Add((Get-DungeonRouteSlotKey '광기의 동굴' $slot)) }
    return @($keys | Select-Object -Unique)
}
function Get-SlotFileStem([string]$Slot) {
    return (Get-EffectiveSlotKey $Slot).Replace(' ', '_')
}
function Get-SlotStatusName([string]$Slot) {
    if ($Slot -eq '궁극기') { return $Slot + ' 설정 ' + ([int]$script:SelectedUltimateProfileIndex + 1) }
    if ($Slot -eq '퀘스트') { return $Slot + ' 설정 ' + ([int]$script:SelectedQuestProfileIndex + 1) }
    return Get-SlotDisplayName $Slot
}
function Assign-ImageFileToSlot([string]$Slot, [string]$SourcePath) {
    if (-not [System.IO.File]::Exists($SourcePath)) { return }
    $ext = [System.IO.Path]::GetExtension($SourcePath).ToLowerInvariant()
    if ($ext -notin @('.png','.jpg','.jpeg','.bmp')) { [System.Windows.Forms.MessageBox]::Show('지원하는 이미지 파일은 PNG, JPG, BMP입니다.', '이미지 연결') | Out-Null; return }
    $slotKey = Get-EffectiveSlotKey $Slot
    $safe = Get-SlotFileStem $Slot
    $name = $safe + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '.png'
    $dest = Join-Path $script:SampleDir $name
    $image = [System.Drawing.Image]::FromFile($SourcePath)
    try { $bitmap = New-Object System.Drawing.Bitmap($image); try { $bitmap.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() } }
    finally { $image.Dispose() }
    if ($script:Samples[$slotKey] -and [System.IO.File]::Exists($script:Samples[$slotKey].Path)) { [System.IO.File]::Delete($script:Samples[$slotKey].Path) }
    $probe = Load-ImageUnlocked $dest
    try { $script:Samples[$slotKey] = [pscustomobject]@{ Path = $dest; Name = [System.IO.Path]::GetFileName($dest); Width = $probe.Width; Height = $probe.Height } }
    finally { $probe.Dispose() }
}
function Get-SlotLoadNames([string]$Slot) {
    $names = New-Object System.Collections.Generic.List[string]
    [void]$names.Add($Slot)
    if ($script:SlotAliases.ContainsKey($Slot)) {
        foreach ($alias in $script:SlotAliases[$Slot]) { [void]$names.Add([string]$alias) }
    }
    return @($names)
}
function Resolve-SlotName([string]$Name) {
    if ($script:Slots -contains $Name) { return $Name }
    foreach ($slot in $script:SlotAliases.Keys) {
        if ($script:SlotAliases[$slot] -contains $Name) { return $slot }
    }
    return $null
}
function Resolve-SlotStorageName([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    if ($Name -match '^궁극기_([1-5])$') { return $Name }
    if ($Name -match '^퀘스트_([1-4])$') { return $Name }
    if ($Name -like '광기의 동굴_*') { return $Name }
    if ($Name -eq '궁극기') { return '궁극기_1' }
    if ($Name -eq '퀘스트') { return '퀘스트_1' }
    return Resolve-SlotName $Name
}
function Load-SavedSamples {
    if (-not [System.IO.Directory]::Exists($script:SampleDir)) { return 0 }
    $loaded = 0
    foreach ($slot in (Get-SlotStorageKeys)) {
        $latest = $null
        $loadNames = @(Get-SlotLoadNames $slot)
        if ($slot -eq '궁극기_1') { $loadNames += '궁극기' }
        if ($slot -eq '퀘스트_1') { $loadNames += '퀘스트'; $loadNames += '5단계' }
        foreach ($loadName in $loadNames) {
            $prefix = $loadName.Replace(' ', '_') + '_'
            $candidate = Get-ChildItem -LiteralPath $script:SampleDir -File -Filter '*.png' | Where-Object { $_.Name.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($null -ne $candidate -and ($null -eq $latest -or $candidate.LastWriteTime -gt $latest.LastWriteTime)) { $latest = $candidate }
        }
        if ($null -ne $latest) {
            try { $img = Load-ImageUnlocked $latest.FullName; $w = $img.Width; $h = $img.Height; $img.Dispose(); $script:Samples[$slot] = [pscustomobject]@{ Path = $latest.FullName; Name = $latest.Name; Width = $w; Height = $h }; $loaded++ }
            catch { $script:Samples[$slot] = $null }
        }
    }
    return $loaded
}
function Test-MultiSampleSlot([string]$Slot) {
    return $script:MultiSampleLimits.ContainsKey($Slot)
}
function Get-MultiSampleFolder([string]$Slot) {
    if (-not (Test-MultiSampleSlot $Slot)) { return $null }
    $safe = Get-SlotFileStem $Slot
    return Join-Path $script:SampleDir ($safe + '_samples')
}
function Get-SlotSamplePaths([string]$Slot) {
    $paths = New-Object System.Collections.Generic.List[string]
    $slotKey = Get-EffectiveSlotKey $Slot
    if ($script:Samples[$slotKey] -and [System.IO.File]::Exists($script:Samples[$slotKey].Path)) {
        [void]$paths.Add([string]$script:Samples[$slotKey].Path)
    }
    $loadNames = @(Get-SlotLoadNames $slotKey)
    if ($slotKey -eq '궁극기_1') { $loadNames += '궁극기' }
    if ($slotKey -eq '퀘스트_1') { $loadNames += '퀘스트'; $loadNames += '5단계' }
    foreach ($loadName in ($loadNames | Select-Object -Unique)) {
        $prefix = $loadName.Replace(' ', '_') + '_'
        foreach ($file in (Get-ChildItem -LiteralPath $script:SampleDir -File -Filter '*.png' | Where-Object { $_.Name.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) } | Sort-Object LastWriteTime -Descending)) {
            [void]$paths.Add($file.FullName)
        }
    }
    $folder = Get-MultiSampleFolder $Slot
    if (-not [string]::IsNullOrWhiteSpace($folder) -and [System.IO.Directory]::Exists($folder)) {
        foreach ($file in (Get-ChildItem -LiteralPath $folder -File -Filter '*.png' | Sort-Object LastWriteTime -Descending)) {
            [void]$paths.Add($file.FullName)
        }
    }
    return @($paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}
function Select-ScreenRegion([System.Windows.Forms.Screen]$Screen) {
    $overlay = New-Object System.Windows.Forms.Form
    $overlay.FormBorderStyle = 'None'; $overlay.StartPosition = 'Manual'; $overlay.Bounds = $Screen.Bounds
    $overlay.TopMost = $true; $overlay.Opacity = 0.28; $overlay.BackColor = [System.Drawing.Color]::Black; $overlay.Cursor = [System.Windows.Forms.Cursors]::Cross; $overlay.KeyPreview = $true
    $state = [pscustomobject]@{ Down = $false; Start = [System.Drawing.Point]::Empty; Current = [System.Drawing.Point]::Empty; Result = [System.Drawing.Rectangle]::Empty }
    $overlay.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $overlay.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $overlay.Close() } })
    $overlay.Add_MouseDown({ $state.Down = $true; $state.Start = [System.Drawing.Point]::new($_.X, $_.Y); $state.Current = $state.Start; $overlay.Invalidate() })
    $overlay.Add_MouseMove({ if ($state.Down) { $state.Current = [System.Drawing.Point]::new($_.X, $_.Y); $overlay.Invalidate() } })
    $overlay.Add_MouseUp({
        if ($state.Down) {
            $state.Down = $false; $x1 = [Math]::Min($state.Start.X, $_.X); $y1 = [Math]::Min($state.Start.Y, $_.Y); $x2 = [Math]::Max($state.Start.X, $_.X); $y2 = [Math]::Max($state.Start.Y, $_.Y)
            if (($x2 - $x1) -ge 10 -and ($y2 - $y1) -ge 10) { $state.Result = [System.Drawing.Rectangle]::new($Screen.Bounds.Left + $x1, $Screen.Bounds.Top + $y1, $x2 - $x1, $y2 - $y1); $overlay.DialogResult = [System.Windows.Forms.DialogResult]::OK; $overlay.Close() }
        }
    })
    $overlay.Add_Paint({ if ($state.Down) { $x1 = [Math]::Min($state.Start.X, $state.Current.X); $y1 = [Math]::Min($state.Start.Y, $state.Current.Y); $x2 = [Math]::Max($state.Start.X, $state.Current.X); $y2 = [Math]::Max($state.Start.Y, $state.Current.Y); $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Lime, 3); $_.Graphics.DrawRectangle($pen, [System.Drawing.Rectangle]::new($x1, $y1, $x2 - $x1, $y2 - $y1)); $pen.Dispose() } })
    $result = $overlay.ShowDialog(); $overlay.Dispose()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) { return $state.Result }
    return [System.Drawing.Rectangle]::Empty
}
function Save-IgnoreZones {
    $rows = New-Object System.Collections.Generic.List[string]
    $rows.Add('index,x,y,width,height,mode,window_width,window_height')
    for ($i = 0; $i -lt $script:IgnoreZones.Count; $i++) {
        $zone = $script:IgnoreZones[$i]
        $mode = if ($zone.Mode) { [string]$zone.Mode } else { 'screen' }
        $windowWidth = if ($zone.WindowWidth) { [int]$zone.WindowWidth } else { 0 }
        $windowHeight = if ($zone.WindowHeight) { [int]$zone.WindowHeight } else { 0 }
        $rows.Add(('{0},{1},{2},{3},{4},"{5}",{6},{7}' -f ($i + 1), [int]$zone.X, [int]$zone.Y, [int]$zone.Width, [int]$zone.Height, $mode.Replace('"','""'), $windowWidth, $windowHeight))
    }
    $rows | Set-Content -LiteralPath $script:IgnoreZonePath -Encoding UTF8
}
function Load-IgnoreZones {
    $script:IgnoreZones.Clear()
    if (-not [System.IO.File]::Exists($script:IgnoreZonePath)) { return 0 }
    $loaded = 0
    foreach ($row in (Import-Csv -LiteralPath $script:IgnoreZonePath)) {
        if ($loaded -ge $script:MaxIgnoreZones) { break }
        try {
            $mode = if ($row.PSObject.Properties.Name -contains 'mode' -and -not [string]::IsNullOrWhiteSpace($row.mode)) { [string]$row.mode } else { 'screen' }
            $windowWidth = 0
            $windowHeight = 0
            if ($row.PSObject.Properties.Name -contains 'window_width' -and -not [string]::IsNullOrWhiteSpace($row.window_width)) { $windowWidth = [int]$row.window_width }
            if ($row.PSObject.Properties.Name -contains 'window_height' -and -not [string]::IsNullOrWhiteSpace($row.window_height)) { $windowHeight = [int]$row.window_height }
            $script:IgnoreZones.Add([pscustomobject]@{ X = [int]$row.x; Y = [int]$row.y; Width = [int]$row.width; Height = [int]$row.height; Mode = $mode; WindowWidth = $windowWidth; WindowHeight = $windowHeight }) | Out-Null
            $loaded++
        } catch { }
    }
    return $loaded
}
function Get-IgnoreZoneScreenRect($Zone) {
    if ($null -eq $Zone) { return [System.Drawing.Rectangle]::Empty }
    $mode = if ($Zone.Mode) { [string]$Zone.Mode } else { 'screen' }
    if ($mode -eq 'window') {
        $bounds = Get-ActiveTargetBounds
        if ($bounds.IsEmpty) { return [System.Drawing.Rectangle]::Empty }
        $x = [double]$Zone.X
        $y = [double]$Zone.Y
        $w = [double]$Zone.Width
        $h = [double]$Zone.Height
        if ([int]$Zone.WindowWidth -gt 0 -and [int]$Zone.WindowHeight -gt 0) {
            $x = $x * ([double]$bounds.Width / [double]$Zone.WindowWidth)
            $y = $y * ([double]$bounds.Height / [double]$Zone.WindowHeight)
            $w = $w * ([double]$bounds.Width / [double]$Zone.WindowWidth)
            $h = $h * ([double]$bounds.Height / [double]$Zone.WindowHeight)
        }
        return [System.Drawing.Rectangle]::new([int]($bounds.Left + $x), [int]($bounds.Top + $y), [int]$w, [int]$h)
    }
    return [System.Drawing.Rectangle]::new([int]$Zone.X, [int]$Zone.Y, [int]$Zone.Width, [int]$Zone.Height)
}
function Test-RectInIgnoreZone([System.Drawing.Rectangle]$Rect) {
    return $false
}
function Add-IgnoreZone {
    if ($script:IgnoreZones.Count -ge $script:MaxIgnoreZones) {
        [System.Windows.Forms.MessageBox]::Show('제외 구역은 최대 4개까지 저장합니다. 다시 지정하려면 제외삭제를 먼저 눌러주세요.', '제외 구역') | Out-Null
        return
    }
    $screen = $screens[$monitorBox.SelectedIndex]
    $rect = Select-ScreenRegion $screen
    if ($rect.IsEmpty) { return }
    $mode = Get-CoordinateMode
    if ($mode -eq 'window') {
        $bounds = Get-ActiveTargetBounds
        if (-not $bounds.IsEmpty) {
            $script:IgnoreZones.Add([pscustomobject]@{ X = ([int]$rect.Left - [int]$bounds.Left); Y = ([int]$rect.Top - [int]$bounds.Top); Width = [int]$rect.Width; Height = [int]$rect.Height; Mode = 'window'; WindowWidth = [int]$bounds.Width; WindowHeight = [int]$bounds.Height }) | Out-Null
        } else {
            $script:IgnoreZones.Add([pscustomobject]@{ X = [int]$rect.Left; Y = [int]$rect.Top; Width = [int]$rect.Width; Height = [int]$rect.Height; Mode = 'screen'; WindowWidth = 0; WindowHeight = 0 }) | Out-Null
        }
    } else {
        $script:IgnoreZones.Add([pscustomobject]@{ X = [int]$rect.Left; Y = [int]$rect.Top; Width = [int]$rect.Width; Height = [int]$rect.Height; Mode = 'screen'; WindowWidth = 0; WindowHeight = 0 }) | Out-Null
    }
    Save-IgnoreZones
    $statusLabel.Text = '제외 구역 ' + $script:IgnoreZones.Count + '/4 저장됨'
}
function Clear-IgnoreZones {
    $script:IgnoreZones.Clear()
    Save-IgnoreZones
    $statusLabel.Text = '제외 구역을 모두 삭제했습니다.'
}
function Show-IgnoreZones {
    $screen = $screens[$monitorBox.SelectedIndex]
    $allowed = New-Object System.Collections.Generic.List[object]
    foreach ($slot in $script:Slots) {
        if (-not (Test-SlotEnabled $slot)) { continue }
        $rect = Get-SlotRegionScreenRect $slot $screen
        if (-not $rect.IsEmpty -and $rect.Width -ge 5 -and $rect.Height -ge 5) {
            [void]$allowed.Add([pscustomobject]@{ Slot = $slot; Rect = $rect })
        }
    }
    if ($allowed.Count -le 0) {
        [System.Windows.Forms.MessageBox]::Show('등록된 슬롯 구역이 없습니다. Shift+F8로 각 슬롯 구역을 먼저 지정하세요.', '자동 제외 확인') | Out-Null
        return
    }
    $overlay = New-Object System.Windows.Forms.Form
    $overlay.FormBorderStyle = 'None'
    $overlay.StartPosition = 'Manual'
    $overlay.Bounds = $screen.Bounds
    $overlay.TopMost = $true
    $overlay.ShowInTaskbar = $false
    $overlay.BackColor = [System.Drawing.Color]::Magenta
    $overlay.TransparencyKey = [System.Drawing.Color]::Magenta
    $overlay.Add_Paint({
        param($sender, $e)
        $g = $e.Graphics
        $redBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(210, 104, 54, 66))
        $greenPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 236, 255, 210), 3)
        $labelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 36, 34, 38))
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $font = New-Object System.Drawing.Font('Malgun Gothic', 10, [System.Drawing.FontStyle]::Bold)
        $outsideRegion = New-Object System.Drawing.Region([System.Drawing.Rectangle]::new(0, 0, $sender.ClientSize.Width, $sender.ClientSize.Height))
        try {
            foreach ($item in $allowed) {
                $r = $item.Rect
                $local = [System.Drawing.Rectangle]::new($r.Left - $screen.Bounds.Left, $r.Top - $screen.Bounds.Top, $r.Width, $r.Height)
                $outsideRegion.Exclude($local)
            }
            $g.FillRegion($redBrush, $outsideRegion)
            foreach ($item in $allowed) {
                $r = $item.Rect
                $local = [System.Drawing.Rectangle]::new($r.Left - $screen.Bounds.Left, $r.Top - $screen.Bounds.Top, $r.Width, $r.Height)
                $g.DrawRectangle($greenPen, $local)
                $labelRect = [System.Drawing.RectangleF]::new([single]$local.Left, [single]([Math]::Max(0, $local.Top - 24)), [single][Math]::Max(84, $local.Width), 22)
                $g.FillRectangle($labelBrush, $labelRect)
                $g.DrawString([string]$item.Slot, $font, $textBrush, $labelRect.Location)
            }
        }
        finally {
            $outsideRegion.Dispose()
            $redBrush.Dispose(); $greenPen.Dispose(); $labelBrush.Dispose(); $textBrush.Dispose(); $font.Dispose()
        }
    }.GetNewClosure())
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1400
    $timer.Add_Tick({
        $timer.Stop()
        $timer.Dispose()
        $overlay.Close()
        $overlay.Dispose()
    }.GetNewClosure())
    $overlay.Show()
    $timer.Start()
    $statusLabel.Text = '자동 제외 확인: 슬롯 구역 ' + $allowed.Count + '개 외부를 붉게 표시했습니다.'
}
function Capture-Slot([string]$Slot, [System.Windows.Forms.Screen]$Screen) {
    $rect = Select-ScreenRegion $Screen
    if ($rect.IsEmpty) { return }
    Save-CapturedSlotRegion $Slot $rect
    Save-CapturedSlotPoint $Slot $rect
    Start-Sleep -Milliseconds 180
    $bmp = [VisionFinder]::Capture($rect)
    try {
        $slotKey = Get-EffectiveSlotKey $Slot
        $safe = Get-SlotFileStem $Slot
        $name = $safe + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '.png'
        $path = Join-Path $script:SampleDir $name
        $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        if ($script:Samples[$slotKey] -and [System.IO.File]::Exists($script:Samples[$slotKey].Path)) { [System.IO.File]::Delete($script:Samples[$slotKey].Path) }
        $script:Samples[$slotKey] = [pscustomobject]@{ Path = $path; Name = $name; Width = $rect.Width; Height = $rect.Height }
        $script:LastCaptureMessage = (Get-SlotStatusName $Slot) + ' 이미지가 저장되었습니다.'
    }
    finally { $bmp.Dispose() }
}
function Save-SlotRegionOnly([string]$Slot, [System.Windows.Forms.Screen]$Screen) {
    $rect = Select-ScreenRegion $Screen
    if ($rect.IsEmpty) { return }
    Save-CapturedSlotRegion $Slot $rect
    $slotKey = Get-EffectiveSlotKey $Slot
    if ($Slot -ne '상태 기준') {
        $script:SlotPoints[$slotKey] = $null
        Save-SlotPoints
    }
    $script:LastCaptureMessage = (Get-SlotStatusName $Slot) + ' 영역이 저장되었습니다. Shift+F7로 이 영역을 촬영하세요.'
}
function Capture-SlotFromSavedRegion([string]$Slot, [System.Windows.Forms.Screen]$Screen) {
    $rect = Get-SlotRegionScreenRect $Slot $Screen
    if ($rect.IsEmpty) {
        $script:LastCaptureMessage = (Get-SlotStatusName $Slot) + ' 저장 영역이 없습니다. Shift+F8로 영역을 먼저 지정하세요.'
        return
    }
    Start-Sleep -Milliseconds 180
    $bmp = [VisionFinder]::Capture($rect)
    try {
        $slotKey = Get-EffectiveSlotKey $Slot
        $safe = Get-SlotFileStem $Slot
        $name = $safe + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '.png'
        $path = Join-Path $script:SampleDir $name
        $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        if ($script:Samples[$slotKey] -and [System.IO.File]::Exists($script:Samples[$slotKey].Path)) {
            [System.IO.File]::Delete($script:Samples[$slotKey].Path)
        }
        $script:Samples[$slotKey] = [pscustomobject]@{ Path = $path; Name = $name; Width = $rect.Width; Height = $rect.Height }
        $script:LastCaptureMessage = (Get-SlotStatusName $Slot) + ' 저장 영역을 촬영했습니다.'
    }
    finally { $bmp.Dispose() }
}
function Capture-ExtraSlotSample([string]$Slot, [System.Windows.Forms.Screen]$Screen) {
    if (-not (Test-MultiSampleSlot $Slot)) {
        $script:LastCaptureMessage = $Slot + ' 슬롯은 추가 샘플 대상이 아닙니다.'
        return
    }
    $rect = Select-ScreenRegion $Screen
    if ($rect.IsEmpty) { return }
    Start-Sleep -Milliseconds 180
    $bmp = [VisionFinder]::Capture($rect)
    try {
        $safe = Get-SlotFileStem $Slot
        $folder = Get-MultiSampleFolder $Slot
        [System.IO.Directory]::CreateDirectory($folder) | Out-Null
        $name = $safe + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '.png'
        $path = Join-Path $folder $name
        $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $limit = [int]$script:MultiSampleLimits[$Slot]
        Get-ChildItem -LiteralPath $folder -File -Filter '*.png' |
            Sort-Object LastWriteTime -Descending |
            Select-Object -Skip $limit |
            ForEach-Object { try { [System.IO.File]::Delete($_.FullName) } catch {} }
        $count = (Get-ChildItem -LiteralPath $folder -File -Filter '*.png' | Measure-Object).Count
        $script:LastCaptureMessage = (Get-SlotStatusName $Slot) + ' 추가 샘플 저장: ' + $count + '/' + $limit
    }
    finally { $bmp.Dispose() }
}
function Save-CapturedSlotRegion([string]$Slot, [System.Drawing.Rectangle]$Rect) {
    $slotKey = Get-EffectiveSlotKey $Slot
    $mode = Get-CoordinateMode
    if ($mode -eq 'window') {
        $bounds = Get-ActiveTargetBounds
        if (-not $bounds.IsEmpty) {
            $script:SlotRegions[$slotKey] = [pscustomobject]@{ X = ([int]$Rect.Left - [int]$bounds.Left); Y = ([int]$Rect.Top - [int]$bounds.Top); Width = [int]$Rect.Width; Height = [int]$Rect.Height; Mode = 'window'; WindowWidth = [int]$bounds.Width; WindowHeight = [int]$bounds.Height }
            Save-SlotRegions
            return
        }
    }
    $script:SlotRegions[$slotKey] = [pscustomobject]@{ X = [int]$Rect.Left; Y = [int]$Rect.Top; Width = [int]$Rect.Width; Height = [int]$Rect.Height; Mode = 'screen'; WindowWidth = 0; WindowHeight = 0 }
    Save-SlotRegions
}
function Save-CapturedSlotPoint([string]$Slot, [System.Drawing.Rectangle]$Rect) {
    if ($Slot -eq '상태 기준') { return }
    $slotKey = Get-EffectiveSlotKey $Slot
    $cx = [int]($Rect.Left + $Rect.Width / 2)
    $cy = [int]($Rect.Top + $Rect.Height / 2)
    $mode = Get-CoordinateMode
    if ($mode -eq 'window') {
        $bounds = Get-ActiveTargetBounds
        if (-not $bounds.IsEmpty) {
            $script:SlotPoints[$slotKey] = [pscustomobject]@{ X = ($cx - [int]$bounds.Left); Y = ($cy - [int]$bounds.Top); Mode = 'window'; WindowWidth = [int]$bounds.Width; WindowHeight = [int]$bounds.Height }
            Save-SlotPoints
            return
        }
    }
    $script:SlotPoints[$slotKey] = [pscustomobject]@{ X = $cx; Y = $cy; Mode = 'screen'; WindowWidth = 0; WindowHeight = 0 }
    Save-SlotPoints
}
function Get-MatchRequired {
    if ($matchPercentBox) { return [Math]::Max(0.91, [double]$matchPercentBox.Value / 100.0) }
    return 0.91
}
function Get-ColorTolerance {
    if ($colorToleranceBox) { return [Math]::Min(22, [int]$colorToleranceBox.Value) }
    return 22
}
function Save-SlotPoints {
    $rows = New-Object System.Collections.Generic.List[string]
    $rows.Add('slot,x,y,mode,window_width,window_height')
    foreach ($slot in (Get-SlotStorageKeys)) {
        if ($slot -eq '상태 기준') { continue }
        $point = $script:SlotPoints[$slot]
        if ($null -ne $point) {
            $mode = if ($point.Mode) { [string]$point.Mode } else { 'screen' }
            $windowWidth = if ($point.WindowWidth) { [int]$point.WindowWidth } else { 0 }
            $windowHeight = if ($point.WindowHeight) { [int]$point.WindowHeight } else { 0 }
            $rows.Add(('"{0}",{1},{2},"{3}",{4},{5}' -f $slot.Replace('"','""'), [int]$point.X, [int]$point.Y, $mode.Replace('"','""'), $windowWidth, $windowHeight))
        }
    }
    $rows | Set-Content -LiteralPath $script:SlotPointPath -Encoding UTF8
}
function Save-SlotRegions {
    $rows = New-Object System.Collections.Generic.List[string]
    $rows.Add('slot,x,y,width,height,mode,window_width,window_height')
    foreach ($slot in (Get-SlotStorageKeys)) {
        $region = $script:SlotRegions[$slot]
        if ($null -ne $region) {
            $mode = if ($region.Mode) { [string]$region.Mode } else { 'screen' }
            $windowWidth = if ($region.WindowWidth) { [int]$region.WindowWidth } else { 0 }
            $windowHeight = if ($region.WindowHeight) { [int]$region.WindowHeight } else { 0 }
            $rows.Add(('"{0}",{1},{2},{3},{4},"{5}",{6},{7}' -f $slot.Replace('"','""'), [int]$region.X, [int]$region.Y, [int]$region.Width, [int]$region.Height, $mode.Replace('"','""'), $windowWidth, $windowHeight))
        }
    }
    $rows | Set-Content -LiteralPath $script:SlotRegionPath -Encoding UTF8
}
function Load-SlotPoints {
    foreach ($slot in (Get-SlotStorageKeys)) { $script:SlotPoints[$slot] = $null }
    if (-not [System.IO.File]::Exists($script:SlotPointPath)) { return 0 }
    $loaded = 0
    foreach ($row in (Import-Csv -LiteralPath $script:SlotPointPath)) {
        $resolvedSlot = Resolve-SlotStorageName ([string]$row.slot)
        if (($null -ne $resolvedSlot) -and $resolvedSlot -ne '상태 기준') {
            $mode = if ($row.PSObject.Properties.Name -contains 'mode' -and -not [string]::IsNullOrWhiteSpace($row.mode)) { [string]$row.mode } else { 'screen' }
            $windowWidth = 0
            $windowHeight = 0
            if ($row.PSObject.Properties.Name -contains 'window_width' -and -not [string]::IsNullOrWhiteSpace($row.window_width)) { $windowWidth = [int]$row.window_width }
            if ($row.PSObject.Properties.Name -contains 'window_height' -and -not [string]::IsNullOrWhiteSpace($row.window_height)) { $windowHeight = [int]$row.window_height }
            $script:SlotPoints[$resolvedSlot] = [pscustomobject]@{ X = [int]$row.x; Y = [int]$row.y; Mode = $mode; WindowWidth = $windowWidth; WindowHeight = $windowHeight }
            $loaded++
        }
    }
    return $loaded
}
function Load-SlotRegions {
    foreach ($slot in (Get-SlotStorageKeys)) { $script:SlotRegions[$slot] = $null }
    if (-not [System.IO.File]::Exists($script:SlotRegionPath)) { return 0 }
    $loaded = 0
    foreach ($row in (Import-Csv -LiteralPath $script:SlotRegionPath)) {
        $resolvedSlot = Resolve-SlotStorageName ([string]$row.slot)
        if ($null -ne $resolvedSlot) {
            try {
                $mode = if ($row.PSObject.Properties.Name -contains 'mode' -and -not [string]::IsNullOrWhiteSpace($row.mode)) { [string]$row.mode } else { 'screen' }
                $windowWidth = 0
                $windowHeight = 0
                if ($row.PSObject.Properties.Name -contains 'window_width' -and -not [string]::IsNullOrWhiteSpace($row.window_width)) { $windowWidth = [int]$row.window_width }
                if ($row.PSObject.Properties.Name -contains 'window_height' -and -not [string]::IsNullOrWhiteSpace($row.window_height)) { $windowHeight = [int]$row.window_height }
                $script:SlotRegions[$resolvedSlot] = [pscustomobject]@{ X = [int]$row.x; Y = [int]$row.y; Width = [int]$row.width; Height = [int]$row.height; Mode = $mode; WindowWidth = $windowWidth; WindowHeight = $windowHeight }
                $loaded++
            } catch { }
        }
    }
    return $loaded
}
function Invoke-AbyssCoordinateMigration {
    $changedPoint = $false
    $changedRegion = $false
    try {
        $oldPoint = $script:SlotPoints['어비스']
        if ($null -eq $oldPoint -or (([Math]::Abs([int]$oldPoint.X - 2940) -le 100) -and ([Math]::Abs([int]$oldPoint.Y - 1032) -le 130))) {
            $script:SlotPoints['어비스'] = [pscustomobject]@{ X = 2818; Y = 716; Mode = 'window'; WindowWidth = 3440; WindowHeight = 1440 }
            $changedPoint = $true
        }
        $oldRegion = $script:SlotRegions['어비스']
        if ($null -eq $oldRegion -or (([Math]::Abs([int]$oldRegion.X - 2894) -le 100) -and ([Math]::Abs([int]$oldRegion.Y - 976) -le 130))) {
            $script:SlotRegions['어비스'] = [pscustomobject]@{ X = 2774; Y = 660; Width = 87; Height = 112; Mode = 'window'; WindowWidth = 3440; WindowHeight = 1440 }
            $changedRegion = $true
        }
        if ($changedPoint) { Save-SlotPoints }
        if ($changedRegion) { Save-SlotRegions }
        if ($changedPoint -or $changedRegion) {
            Write-CrashLog ('abyss-coordinate-migration point=' + $changedPoint + '; region=' + $changedRegion) $null
            return $true
        }
    } catch {
        Write-CrashLog 'abyss-coordinate-migration failed' $_
    }
    return $false
}

function Get-CurrentCursorPoint {
    $point = New-Object 'NativeInput+POINT'
    if ([NativeInput]::GetCursorPos([ref]$point)) { return [pscustomobject]@{ X = [int]$point.X; Y = [int]$point.Y } }
    return $null
}
function Get-CoordinateMode {
    try {
        if ($coordinateModeBox -and -not $coordinateModeBox.IsDisposed -and $coordinateModeBox.SelectedItem) {
            if ([string]$coordinateModeBox.SelectedItem -eq '대상 창 기준') { return 'window' }
        }
    } catch { }
    return 'screen'
}
function Get-CoordinateModeLabel([string]$Mode) {
    if ($Mode -eq 'window') { return '창' }
    return '화면'
}
function Get-ActiveTargetBounds {
    if ($script:TargetHandle -ne [IntPtr]::Zero) {
        $bounds = Get-WindowBounds $script:TargetHandle
        if (-not $bounds.IsEmpty) { return $bounds }
    }
    try {
        $titlePart = $titleBox.Text.Trim()
        if (-not [string]::IsNullOrWhiteSpace($titlePart)) {
            $target = Get-SelectedTargetWindow $titlePart
            if ($null -ne $target) {
                $script:TargetHandle = $target.Handle
                $bounds = Get-WindowBounds $target.Handle
                if (-not $bounds.IsEmpty) { return $bounds }
            }
        }
    } catch { }
    return [System.Drawing.Rectangle]::Empty
}
function Save-CurrentPointForSelectedSlot {
    $point = Get-CurrentCursorPoint
    if ($null -eq $point) { $statusLabel.Text = '현재 마우스 좌표를 읽지 못했습니다.'; return }
    $slot = $script:SelectedSlot
    if ($slot -eq '상태 기준') { $script:SlotPoints[$slot] = $null; Save-SlotPoints; Refresh-Slots; $statusLabel.Text = '상태 기준은 좌표 저장 대상이 아닙니다.'; return }
    $slotKey = Get-EffectiveSlotKey $slot
    $mode = Get-CoordinateMode
    if ($mode -eq 'window') {
        $bounds = Get-ActiveTargetBounds
        if ($bounds.IsEmpty) {
            $statusLabel.Text = '대상 창을 찾지 못해 화면 기준으로 좌표를 저장했습니다.'
            $script:SlotPoints[$slotKey] = [pscustomobject]@{ X = [int]$point.X; Y = [int]$point.Y; Mode = 'screen'; WindowWidth = 0; WindowHeight = 0 }
        } else {
            $script:SlotPoints[$slotKey] = [pscustomobject]@{ X = ([int]$point.X - [int]$bounds.Left); Y = ([int]$point.Y - [int]$bounds.Top); Mode = 'window'; WindowWidth = [int]$bounds.Width; WindowHeight = [int]$bounds.Height }
        }
    } else {
        $script:SlotPoints[$slotKey] = [pscustomobject]@{ X = [int]$point.X; Y = [int]$point.Y; Mode = 'screen'; WindowWidth = 0; WindowHeight = 0 }
    }
    Save-SlotPoints
    Refresh-Slots
    $saved = $script:SlotPoints[$slotKey]
    $statusLabel.Text = (Get-SlotStatusName $slot) + ' 좌표 저장(' + (Get-CoordinateModeLabel $saved.Mode) + '): X=' + $saved.X + ', Y=' + $saved.Y
}
function Get-PointTolerance { try { if ($pointToleranceBox) { return [int]$pointToleranceBox.Value } } catch { }; return 120 }
function Check-SlotPointMatch([string]$Slot, [System.Drawing.Rectangle]$Rect) {
    if ($Slot -eq '상태 기준') { return [pscustomobject]@{ Ok = $true; Message = '' } }
    if (-not $pointCheck.Checked) { return [pscustomobject]@{ Ok = $true; Message = '' } }
    $slotKey = Get-EffectiveSlotKey $Slot
    $point = $script:SlotPoints[$slotKey]
    if ($null -eq $point) { return [pscustomobject]@{ Ok = $true; Message = '' } }
    if (Test-SlotUsesBrightTextFirst $Slot) {
        return [pscustomobject]@{ Ok = $true; Message = 'text sample matched inside slot region' }
    }
    $cx = [int]($Rect.Left + $Rect.Width / 2)
    $cy = [int]($Rect.Top + $Rect.Height / 2)
    $mode = if ($point.Mode) { [string]$point.Mode } else { 'screen' }
    $compareX = $cx
    $compareY = $cy
    $expectedX = [double]$point.X
    $expectedY = [double]$point.Y
    $basis = '화면'
    if ($mode -eq 'window') {
        $bounds = Get-ActiveTargetBounds
        if ($bounds.IsEmpty) { return [pscustomobject]@{ Ok = $true; Message = '' } }
        $compareX = [double]($cx - $bounds.Left)
        $compareY = [double]($cy - $bounds.Top)
        $basis = '창'
        if ([int]$point.WindowWidth -gt 0 -and [int]$point.WindowHeight -gt 0) {
            $expectedX = [double]$point.X * ([double]$bounds.Width / [double]$point.WindowWidth)
            $expectedY = [double]$point.Y * ([double]$bounds.Height / [double]$point.WindowHeight)
        }
    }
    $dx = [Math]::Abs($compareX - $expectedX)
    $dy = [Math]::Abs($compareY - $expectedY)
    $distance = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
    $limit = Get-PointTolerance
    if ($Slot -eq '완료 확인') {
        $region = $script:SlotRegions[$slotKey]
        if ($null -ne $region) {
            $regionWidth = [double]$region.Width
            $regionHeight = [double]$region.Height
            if ($mode -eq 'window' -and [int]$region.WindowWidth -gt 0 -and [int]$region.WindowHeight -gt 0) {
                $bounds = Get-ActiveTargetBounds
                if (-not $bounds.IsEmpty) {
                    $regionWidth = $regionWidth * ([double]$bounds.Width / [double]$region.WindowWidth)
                    $regionHeight = $regionHeight * ([double]$bounds.Height / [double]$region.WindowHeight)
                }
            }
            $regionBasedLimit = [Math]::Ceiling(([Math]::Max($regionWidth, $regionHeight) / 2.0) + 10)
            $limit = [Math]::Max($limit, [int]$regionBasedLimit)
        }
    }
    if ($distance -le $limit) { return [pscustomobject]@{ Ok = $true; Message = '' } }
    return [pscustomobject]@{ Ok = $false; Message = ($Slot + ' 좌표 검증 실패(' + $basis + ' 기준): 이미지 중심 X=' + ([int]$compareX) + ', Y=' + ([int]$compareY) + ' / 저장 X=' + ([int]$expectedX) + ', Y=' + ([int]$expectedY) + ' / 거리 ' + ('{0:F1}' -f $distance) + 'px') }
}
function Get-SlotPointScreenPoint([string]$Slot) {
    if ($Slot -eq '상태 기준') { return $null }
    $slotKey = Get-EffectiveSlotKey $Slot
    $point = $script:SlotPoints[$slotKey]
    if ($null -eq $point) { return $null }
    $mode = if ($point.Mode) { [string]$point.Mode } else { 'screen' }
    if ($mode -eq 'window') {
        $bounds = Get-ActiveTargetBounds
        if ($bounds.IsEmpty) { return $null }
        $x = [double]$point.X
        $y = [double]$point.Y
        if ([int]$point.WindowWidth -gt 0 -and [int]$point.WindowHeight -gt 0) {
            $x = $x * ([double]$bounds.Width / [double]$point.WindowWidth)
            $y = $y * ([double]$bounds.Height / [double]$point.WindowHeight)
        }
        return [System.Drawing.Point]::new(([int]($bounds.Left + $x)), ([int]($bounds.Top + $y)))
    }
    return [System.Drawing.Point]::new([int]$point.X, [int]$point.Y)
}
function Click-SlotTarget([string]$Slot, [System.Drawing.Rectangle]$Rect, [int]$DelayMs, [int]$HoldOverrideMs = -1) {
    if (-not $Rect.IsEmpty) {
        $x = [int]($Rect.Left + $Rect.Width / 2)
        $y = [int]($Rect.Top + $Rect.Height / 2)
        Write-RoutineTrace $script:CurrentCycle 'click-target' $Slot 'image-center' $Rect ('x=' + $x + '; y=' + $y)
        Invoke-LeftClick -X $x -Y $y -HoldOverrideMs $HoldOverrideMs
        Start-Sleep -Milliseconds $DelayMs
        return $true
    }
    $point = Get-SlotPointScreenPoint $Slot
    if ($null -eq $point) { return $false }
    if (-not (Test-SlotAllowsCoordinateFallback $Slot)) {
        Write-RoutineTrace $script:CurrentCycle 'click-target' $Slot 'blocked-coordinate-fallback' ([System.Drawing.Rectangle]::Empty) 'mask mode requires image match'
        return $false
    }
    Write-RoutineTrace $script:CurrentCycle 'click-target' $Slot 'coordinate-fallback' ([System.Drawing.Rectangle]::Empty) ('x=' + $point.X + '; y=' + $point.Y)
    Invoke-LeftClick -X $point.X -Y $point.Y -HoldOverrideMs $HoldOverrideMs
    Start-Sleep -Milliseconds $DelayMs
    return $true
}
function Get-CurrentSearchBounds([System.Windows.Forms.Screen]$Screen) {
    if ($fullMonitorCheck -and $fullMonitorCheck.Checked) { return $Screen.Bounds }
    return Get-SearchBounds $Screen
}
function Test-SlotRequiresRegion([string]$Slot) {
    return @('협동','메뉴','어비스','던전','입장','완료 확인','나가기','식사 버튼','궁극기','스킵','팔라딘') -contains $Slot
}
function Test-SlotAllowsCoordinateFallback([string]$Slot) {
    return @('메뉴','어비스','던전','입장') -contains $Slot
}
function Test-PointInsideSlotRegion([string]$Slot, [System.Drawing.Point]$Point, [System.Windows.Forms.Screen]$Screen) {
    $rect = Get-SlotRegionScreenRect $Slot $Screen
    if ($rect.IsEmpty) { return $true }
    return $rect.Contains($Point)
}
function Test-SlotNeedsStableConfirm([string]$Slot) {
    return @('협동','메뉴','어비스','던전','입장','완료 확인','나가기') -contains $Slot
}
function Test-SlotRejectsAmbiguousMatch([string]$Slot) {
    return @('협동','메뉴','어비스','던전','입장','완료 확인','나가기') -contains $Slot
}
function Test-SlotUsesBrightTextFirst([string]$Slot) {
    return @('협동','메뉴','어비스','던전','입장','완료 확인','나가기','식사 버튼','스킵') -contains $Slot
}
function Find-EntryBusyGuard([System.Windows.Forms.Screen]$Screen) {
    $guardPath = Join-Path $script:SampleDir '입장_전투중_가드.png'
    if (-not [System.IO.File]::Exists($guardPath)) { return [System.Drawing.Rectangle]::Empty }
    $bounds = Get-SlotSearchBounds '입장' $Screen
    if ($bounds.IsEmpty) { return [System.Drawing.Rectangle]::Empty }
    $searchBounds = Expand-SearchBoundsForSample $bounds $guardPath $Screen
    $rect = [VisionFinder]::FindBrightTextSample($searchBounds, $guardPath, 3, 5, 0.72)
    if ($rect.IsEmpty) {
        $rect = [VisionFinder]::FindSample($searchBounds, $guardPath, 4, 8, [Math]::Max((Get-ColorTolerance), 45), 0.78)
    }
    if (-not $rect.IsEmpty) {
        Save-DiagnosticFrame '입장_전투중' 'found' $searchBounds $rect ('entry busy guard ' + [VisionFinder]::LastMode + ' ' + ('{0:P1}' -f [VisionFinder]::LastScore))
    }
    return $rect
}
function Get-SlotRegionScreenRect([string]$Slot, [System.Windows.Forms.Screen]$Screen) {
    $slotKey = Get-EffectiveSlotKey $Slot
    $region = $script:SlotRegions[$slotKey]
    if ($null -eq $region) { return [System.Drawing.Rectangle]::Empty }
    $mode = if ($region.Mode) { [string]$region.Mode } else { 'screen' }
    if ($mode -eq 'window') {
        $bounds = Get-ActiveTargetBounds
        if ($bounds.IsEmpty) { return [System.Drawing.Rectangle]::Empty }
        $x = [double]$region.X
        $y = [double]$region.Y
        $w = [double]$region.Width
        $h = [double]$region.Height
        if ([int]$region.WindowWidth -gt 0 -and [int]$region.WindowHeight -gt 0) {
            $x = $x * ([double]$bounds.Width / [double]$region.WindowWidth)
            $y = $y * ([double]$bounds.Height / [double]$region.WindowHeight)
            $w = $w * ([double]$bounds.Width / [double]$region.WindowWidth)
            $h = $h * ([double]$bounds.Height / [double]$region.WindowHeight)
        }
        return [System.Drawing.Rectangle]::new([int]($bounds.Left + $x), [int]($bounds.Top + $y), [int]$w, [int]$h)
    }
    return [System.Drawing.Rectangle]::new([int]$region.X, [int]$region.Y, [int]$region.Width, [int]$region.Height)
}
function Intersect-RectWithin([System.Drawing.Rectangle]$Rect, [System.Drawing.Rectangle]$Limit) {
    if ($Rect.IsEmpty) { return [System.Drawing.Rectangle]::Empty }
    $left = [Math]::Max($Limit.Left, $Rect.Left)
    $top = [Math]::Max($Limit.Top, $Rect.Top)
    $right = [Math]::Min($Limit.Right, $Rect.Right)
    $bottom = [Math]::Min($Limit.Bottom, $Rect.Bottom)
    if ($right -le $left -or $bottom -le $top) { return [System.Drawing.Rectangle]::Empty }
    return [System.Drawing.Rectangle]::new([int]$left, [int]$top, [int]($right - $left), [int]($bottom - $top))
}
function Expand-SearchBoundsForSample([System.Drawing.Rectangle]$Bounds, [string]$SamplePath, [System.Windows.Forms.Screen]$Screen) {
    if ($Bounds.IsEmpty -or -not [System.IO.File]::Exists($SamplePath)) { return $Bounds }
    $sampleWidth = 0
    $sampleHeight = 0
    try {
        $img = Load-ImageUnlocked $SamplePath
        try {
            $sampleWidth = [int]$img.Width
            $sampleHeight = [int]$img.Height
        } finally {
            $img.Dispose()
        }
    } catch {
        return $Bounds
    }
    if ($sampleWidth -gt $Bounds.Width -or $sampleHeight -gt $Bounds.Height) {
        $extraWidth = [Math]::Max(0, $sampleWidth - $Bounds.Width)
        $extraHeight = [Math]::Max(0, $sampleHeight - $Bounds.Height)
        if ($extraWidth -le 24 -and $extraHeight -le 24) {
            $padLeft = [int][Math]::Ceiling($extraWidth / 2.0)
            $padTop = [int][Math]::Ceiling($extraHeight / 2.0)
            $expanded = [System.Drawing.Rectangle]::new(
                [int]($Bounds.Left - $padLeft),
                [int]($Bounds.Top - $padTop),
                [int]([Math]::Max($Bounds.Width, $sampleWidth) + $extraWidth + 4),
                [int]([Math]::Max($Bounds.Height, $sampleHeight) + $extraHeight + 4)
            )
            $limitedExpanded = Intersect-RectWithin $expanded $Screen.Bounds
            if (-not $limitedExpanded.IsEmpty -and $limitedExpanded.Width -ge $sampleWidth -and $limitedExpanded.Height -ge $sampleHeight) {
                Write-RoutineTrace $script:CurrentCycle 'vision' '' 'sample-region-expanded' $limitedExpanded (
                    ('sample={0}; original={1}x{2}; sampleSize={3}x{4}' -f
                        [System.IO.Path]::GetFileName($SamplePath), $Bounds.Width, $Bounds.Height, $sampleWidth, $sampleHeight)
                )
                return $limitedExpanded
            }
        }
        Write-RoutineTrace $script:CurrentCycle 'vision' '' 'sample-too-large-for-region' $Bounds (
            ('sample={0}; region={1}x{2}; sampleSize={3}x{4}' -f
                [System.IO.Path]::GetFileName($SamplePath), $Bounds.Width, $Bounds.Height, $sampleWidth, $sampleHeight)
        )
        return [System.Drawing.Rectangle]::Empty
    }
    return $Bounds
}
function Get-SlotSearchBounds([string]$Slot, [System.Windows.Forms.Screen]$Screen) {
    $bounds = Get-CurrentSearchBounds $Screen
    $regionRect = Get-SlotRegionScreenRect $Slot $Screen
    if ($Slot -eq '식사 버튼') {
        $fallback = [System.Drawing.Rectangle]::new(
            [int]$bounds.Left,
            [int]$bounds.Top,
            [int]($bounds.Width * 0.25),
            [int]($bounds.Height * 0.20)
        )
        if (-not $regionRect.IsEmpty) {
            $limitedRegion = Intersect-RectWithin $regionRect $bounds
            if (-not $limitedRegion.IsEmpty) {
                $left = [Math]::Min($limitedRegion.Left, $fallback.Left)
                $top = [Math]::Min($limitedRegion.Top, $fallback.Top)
                $right = [Math]::Max($limitedRegion.Right, $fallback.Right)
                $bottom = [Math]::Max($limitedRegion.Bottom, $fallback.Bottom)
                return [System.Drawing.Rectangle]::new([int]$left, [int]$top, [int]($right - $left), [int]($bottom - $top))
            }
        }
        return $fallback
    }
    if (-not $regionRect.IsEmpty) {
        $limited = Intersect-RectWithin $regionRect $bounds
        if (-not $limited.IsEmpty) { return $limited }
    }
    if (Test-SlotRequiresRegion $Slot) {
        return [System.Drawing.Rectangle]::Empty
    }
    if ($Slot -eq '완료 확인') {
        $x = [int]($bounds.Left + ($bounds.Width * 0.18))
        $y = [int]($bounds.Top + ($bounds.Height * 0.48))
        $w = [int]($bounds.Width * 0.64)
        $h = [int]($bounds.Height * 0.48)
        return [System.Drawing.Rectangle]::new($x, $y, $w, $h)
    }
    if ($Slot -eq '나가기') {
        $x = [int]($bounds.Left + ($bounds.Width * 0.28))
        $y = [int]($bounds.Top + ($bounds.Height * 0.76))
        $w = [int]($bounds.Width * 0.44)
        $h = [int]($bounds.Height * 0.22)
        return [System.Drawing.Rectangle]::new($x, $y, $w, $h)
    }
    if ($Slot -eq '궁극기') {
        $x = [int]($bounds.Left + ($bounds.Width * 0.55))
        $y = [int]($bounds.Top + ($bounds.Height * 0.58))
        $w = [int]($bounds.Width * 0.43)
        $h = [int]($bounds.Height * 0.40)
        return [System.Drawing.Rectangle]::new($x, $y, $w, $h)
    }
    return $bounds
}
function Get-RectangleLightProbe([System.Drawing.Rectangle]$Rect) {
    if ($Rect.IsEmpty -or $Rect.Width -le 0 -or $Rect.Height -le 0) {
        return [pscustomobject]@{ Avg = 0.0; BrightRatio = 0.0; Samples = 0; IsDark = $true }
    }
    $bmp = $null
    $g = $null
    try {
        $bmp = New-Object System.Drawing.Bitmap($Rect.Width, $Rect.Height)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($Rect.Left, $Rect.Top, 0, 0, $Rect.Size)
        $stepX = [Math]::Max(1, [int]($Rect.Width / 24))
        $stepY = [Math]::Max(1, [int]($Rect.Height / 12))
        $sum = 0.0
        $bright = 0
        $count = 0
        for ($y = 0; $y -lt $Rect.Height; $y += $stepY) {
            for ($x = 0; $x -lt $Rect.Width; $x += $stepX) {
                $c = $bmp.GetPixel($x, $y)
                $luma = (0.2126 * $c.R) + (0.7152 * $c.G) + (0.0722 * $c.B)
                $sum += $luma
                if ($luma -ge 70) { $bright++ }
                $count++
            }
        }
        if ($count -le 0) {
            return [pscustomobject]@{ Avg = 0.0; BrightRatio = 0.0; Samples = 0; IsDark = $true }
        }
        $avg = $sum / $count
        $ratio = $bright / $count
        return [pscustomobject]@{
            Avg = [Math]::Round($avg, 2)
            BrightRatio = [Math]::Round($ratio, 4)
            Samples = $count
            IsDark = (($avg -lt 42) -and ($ratio -lt 0.015))
        }
    } catch {
        return [pscustomobject]@{ Avg = 255.0; BrightRatio = 1.0; Samples = 0; IsDark = $false }
    } finally {
        if ($null -ne $g) { $g.Dispose() }
        if ($null -ne $bmp) { $bmp.Dispose() }
    }
}
function Test-InternalTransitionFrame([System.Windows.Forms.Screen]$Screen) {
    $slots = @('상태 기준','협동','완료 확인')
    $probes = New-Object System.Collections.Generic.List[string]
    $checked = 0
    $dark = 0
    foreach ($slot in $slots) {
        $bounds = Get-SlotSearchBounds $slot $Screen
        if ($bounds.IsEmpty) { continue }
        $probe = Get-RectangleLightProbe $bounds
        $checked++
        if ($probe.IsDark) { $dark++ }
        $probes.Add(('{0}:avg={1},bright={2},dark={3}' -f $slot, $probe.Avg, $probe.BrightRatio, $probe.IsDark))
    }
    if ($checked -eq 3 -and $dark -eq $checked) {
        Write-RoutineTrace $script:CurrentCycle 'stage-scan' '__전환대기' 'dark-transition-wait' ([System.Drawing.Rectangle]::Empty) ($probes -join '; ')
        return $true
    }
    return $false
}
function Find-Slot([string]$Slot, [System.Windows.Forms.Screen]$Screen) {
    if (-not (Test-SlotEnabled $Slot)) {
        Write-RoutineTrace $script:CurrentCycle 'vision' $Slot 'disabled' ([System.Drawing.Rectangle]::Empty) 'slot disabled'
        return [System.Drawing.Rectangle]::Empty
    }
    $bounds = Get-SlotSearchBounds $Slot $Screen
    if ($bounds.IsEmpty) {
        Write-RoutineTrace $script:CurrentCycle 'vision' $Slot 'no-search-region' ([System.Drawing.Rectangle]::Empty) 'slot region is required'
        return [System.Drawing.Rectangle]::Empty
    }
    $paths = Get-SlotSamplePaths $Slot
    if ($paths.Count -eq 0) { return [System.Drawing.Rectangle]::Empty }
    foreach ($samplePath in $paths) {
        $searchBounds = Expand-SearchBoundsForSample $bounds $samplePath $Screen
        if ($searchBounds.IsEmpty) {
            Write-RoutineTrace $script:CurrentCycle 'vision' $Slot 'sample-skip-empty-region' $bounds ([System.IO.Path]::GetFileName($samplePath))
            continue
        }
        $slotTolerance = Get-ColorTolerance
        $slotRequired = Get-MatchRequired
        if ($Slot -eq '궁극기') {
            $slotTolerance = [Math]::Max($slotTolerance, 38)
            $slotRequired = [Math]::Min($slotRequired, 0.82)
        }
        if (@('궁극기','팔라딘') -contains $Slot) {
            $colorRect = [VisionFinder]::FindSaturatedColorSample($searchBounds, $samplePath, 3, 5, [Math]::Max($slotTolerance, 48), 0.58)
            if (-not $colorRect.IsEmpty) {
                if (Test-RectInIgnoreZone $colorRect) {
                    Write-RoutineTrace $script:CurrentCycle 'vision' $Slot 'ignored-zone' $colorRect ([System.IO.Path]::GetFileName($samplePath) + ' / saturated-color')
                    continue
                }
                $scoreDetail = [VisionFinder]::LastMode + ' ' + ('{0:P1}' -f [VisionFinder]::LastScore) + '; second=' + ('{0:P1}' -f [VisionFinder]::LastSecondScore) + '; gap=' + ('{0:P1}' -f [VisionFinder]::LastScoreGap)
                $script:LastMatchedSample = [System.IO.Path]::GetFileName($samplePath) + ' / ' + $scoreDetail
                Save-DiagnosticFrame $Slot 'found' $searchBounds $colorRect ($script:LastMatchedSample)
                return $colorRect
            }
        }
        if (Test-SlotUsesBrightTextFirst $Slot) {
            $slotTolerance = [Math]::Min($slotTolerance, 45)
            $slotRequired = [Math]::Max($slotRequired, 0.82)
        $brightRequired = if ($Slot -eq '스킵') { 0.55 } elseif ($Slot -eq '상태 기준') { 0.62 } elseif ($Slot -eq '완료 확인') { 0.82 } elseif ($Slot -eq '던전') { 0.68 } else { 0.72 }
            $brightRect = [VisionFinder]::FindBrightTextSample($searchBounds, $samplePath, 3, 5, $brightRequired)
            if (-not $brightRect.IsEmpty) {
                if (Test-RectInIgnoreZone $brightRect) {
                    Write-RoutineTrace $script:CurrentCycle 'vision' $Slot 'ignored-zone' $brightRect ([System.IO.Path]::GetFileName($samplePath) + ' / bright-text')
                    continue
                }
                $scoreDetail = [VisionFinder]::LastMode + ' ' + ('{0:P1}' -f [VisionFinder]::LastScore) + '; second=' + ('{0:P1}' -f [VisionFinder]::LastSecondScore) + '; gap=' + ('{0:P1}' -f [VisionFinder]::LastScoreGap)
                if ((Test-SlotRejectsAmbiguousMatch $Slot) -and [VisionFinder]::LastAmbiguous) {
                    Write-RoutineTrace $script:CurrentCycle 'vision' $Slot 'ambiguous-match' $brightRect ([System.IO.Path]::GetFileName($samplePath) + ' / ' + $scoreDetail)
                    continue
                }
                $script:LastMatchedSample = [System.IO.Path]::GetFileName($samplePath) + ' / ' + $scoreDetail
                Save-DiagnosticFrame $Slot 'found' $searchBounds $brightRect ($script:LastMatchedSample)
                return $brightRect
            }
        }
        $rect = [VisionFinder]::FindSample($searchBounds, $samplePath, 4, 8, $slotTolerance, $slotRequired)
        if (-not $rect.IsEmpty) {
            if (Test-RectInIgnoreZone $rect) {
                Write-RoutineTrace $script:CurrentCycle 'vision' $Slot 'ignored-zone' $rect ([System.IO.Path]::GetFileName($samplePath))
                continue
            }
            $scoreDetail = [VisionFinder]::LastMode + ' ' + ('{0:P1}' -f [VisionFinder]::LastScore) + '; second=' + ('{0:P1}' -f [VisionFinder]::LastSecondScore) + '; gap=' + ('{0:P1}' -f [VisionFinder]::LastScoreGap)
            if ((Test-SlotRejectsAmbiguousMatch $Slot) -and [VisionFinder]::LastAmbiguous) {
                Write-RoutineTrace $script:CurrentCycle 'vision' $Slot 'ambiguous-match' $rect ([System.IO.Path]::GetFileName($samplePath) + ' / ' + $scoreDetail)
                continue
            }
            $script:LastMatchedSample = [System.IO.Path]::GetFileName($samplePath) + ' / ' + $scoreDetail
            Save-DiagnosticFrame $Slot 'found' $searchBounds $rect ($script:LastMatchedSample)
            return $rect
        }
    }
    if (($script:CurrentCycle % 10) -eq 0) {
        Save-DiagnosticFrame $Slot 'miss' $bounds ([System.Drawing.Rectangle]::Empty) 'no match in slot search bounds'
    }
    $script:LastMatchedSample = ''
    return [System.Drawing.Rectangle]::Empty
}
function Test-CompleteWaitElapsed {
    if ($null -eq $script:InsideStartedAt) { return $false }
    $elapsedMs = ((Get-Date) - $script:InsideStartedAt).TotalMilliseconds
    return ($elapsedMs -ge [double]$script:MinimumCompleteWaitMs)
}
function Test-CompleteAllowed {
    if (-not (Test-CompleteWaitElapsed)) { return $false }
    if ($null -eq $script:InsideStartedAt) { return $false }
    $elapsedMs = ((Get-Date) - $script:InsideStartedAt).TotalMilliseconds
    $longFallbackReady = ($elapsedMs -ge [double]$script:LongCompleteFallbackMs)
    if (-not $script:CombatMarkerSeen -and -not $longFallbackReady) { return $false }
    if ($script:BossSkipSeen -and -not $script:CombatMarkerSeenAfterSkip -and -not $longFallbackReady) { return $false }
    return $true
}
function Test-CompleteVisualCandidateAllowed {
    if (-not (Test-CompleteWaitElapsed)) { return $false }
    return $true
}
function Test-CompleteRecoveryScanAllowed([string]$Stage) {
    if (Test-CompleteAllowed) { return $true }
    if ($null -ne $script:InsideStartedAt) { return $false }
    return @('던전','입장','메뉴확인','어비스') -contains $Stage
}
function Get-CompleteGateDetail {
    if ($null -eq $script:InsideStartedAt) { return 'inside start time missing' }
    $elapsedMs = [int](((Get-Date) - $script:InsideStartedAt).TotalMilliseconds)
    return ('elapsedMs={0}; requiredMs={1}; fallbackMs={2}; fallbackReady={3}; combatSeen={4}; skipSeen={5}; combatAfterSkip={6}' -f $elapsedMs, $script:MinimumCompleteWaitMs, $script:LongCompleteFallbackMs, ($elapsedMs -ge [int]$script:LongCompleteFallbackMs), $script:CombatMarkerSeen, $script:BossSkipSeen, $script:CombatMarkerSeenAfterSkip)
}
function Test-StableCompleteCandidate([System.Drawing.Rectangle]$Rect, [string]$Context) {
    if ($Rect.IsEmpty) {
        $script:PendingCompleteSeen = 0
        return $false
    }
    $script:PendingCompleteSeen++
    Write-RoutineTrace $script:CurrentCycle 'stage-scan' '완료 확인' 'candidate-pending' $Rect ($Context + '; stable=' + $script:PendingCompleteSeen + '/2')
    if ($script:PendingCompleteSeen -lt 2) { return $false }
    $script:PendingCompleteSeen = 0
    return $true
}
function Test-StopRequested {
    if ($script:StopRequested) { return $true }
    if (([NativeInput]::GetAsyncKeyState(0x75) -band 0x8000) -ne 0) {
        $script:StopRequested = $true
        return $true
    }
    return $false
}
function Sleep-WithStop([int]$Milliseconds) {
    if ($Milliseconds -le 0) { return $true }
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($watch.ElapsedMilliseconds -lt $Milliseconds) {
        if (Test-StopRequested) { return $false }
        [System.Windows.Forms.Application]::DoEvents()
        $remaining = $Milliseconds - [int]$watch.ElapsedMilliseconds
        if ($remaining -le 0) { break }
        Start-Sleep -Milliseconds ([Math]::Max(1, [Math]::Min(100, $remaining)))
    }
    return $true
}
function Find-ValidSlotOnce([string]$Slot, [System.Windows.Forms.Screen]$Screen, [bool]$UsePointCheck = $true) {
    $rect = Find-Slot $Slot $Screen
    if ($rect.IsEmpty) {
        $point = Get-SlotPointScreenPoint $Slot
        if ($null -ne $point -and (Test-SlotAllowsCoordinateFallback $Slot) -and (Test-PointInsideSlotRegion $Slot $point $Screen)) {
            $fallbackRect = [System.Drawing.Rectangle]::new([int]($point.X - 8), [int]($point.Y - 8), 16, 16)
            Write-RoutineTrace $script:CurrentCycle 'single-find' $Slot 'coordinate-fallback' $fallbackRect 'image miss; saved point inside slot region'
            return $fallbackRect
        }
        if ($null -ne $point) {
            Write-RoutineTrace $script:CurrentCycle 'single-find' $Slot 'image-miss-no-fallback' ([System.Drawing.Rectangle]::Empty) 'image miss; coordinate fallback disabled for this slot or point unavailable'
        }
        return [System.Drawing.Rectangle]::Empty
    }
    if ($UsePointCheck) {
        $pointResult = Check-SlotPointMatch $Slot $rect
        if (-not $pointResult.Ok) {
            Write-RoutineTrace $script:CurrentCycle 'single-find' $Slot 'found-invalid' $rect $pointResult.Message
            return [System.Drawing.Rectangle]::Empty
        }
    }
    if (Test-SlotNeedsStableConfirm $Slot) {
        Start-Sleep -Milliseconds 120
        $confirmRect = Find-Slot $Slot $Screen
        if ($confirmRect.IsEmpty) {
            Write-RoutineTrace $script:CurrentCycle 'single-find' $Slot 'found-unstable' $rect 'second sample check missed'
            return [System.Drawing.Rectangle]::Empty
        }
        if ($UsePointCheck) {
            $confirmPointResult = Check-SlotPointMatch $Slot $confirmRect
            if (-not $confirmPointResult.Ok) {
                Write-RoutineTrace $script:CurrentCycle 'single-find' $Slot 'found-unstable' $confirmRect ('second sample point mismatch; ' + $confirmPointResult.Message)
                return [System.Drawing.Rectangle]::Empty
            }
        }
        $cx1 = [int]($rect.Left + $rect.Width / 2)
        $cy1 = [int]($rect.Top + $rect.Height / 2)
        $cx2 = [int]($confirmRect.Left + $confirmRect.Width / 2)
        $cy2 = [int]($confirmRect.Top + $confirmRect.Height / 2)
        if ([Math]::Abs($cx1 - $cx2) -gt 35 -or [Math]::Abs($cy1 - $cy2) -gt 35) {
            Write-RoutineTrace $script:CurrentCycle 'single-find' $Slot 'found-unstable' $confirmRect ('second sample center moved; first=' + $cx1 + ',' + $cy1 + '; second=' + $cx2 + ',' + $cy2)
            return [System.Drawing.Rectangle]::Empty
        }
        Write-RoutineTrace $script:CurrentCycle 'single-find' $Slot 'stable-confirmed' $confirmRect ('first=' + $cx1 + ',' + $cy1 + '; second=' + $cx2 + ',' + $cy2)
    }
    Write-RoutineTrace $script:CurrentCycle 'single-find' $Slot 'found-valid' $rect ''
    return $rect
}
function Test-ExitClosedConfirmed([System.Windows.Forms.Screen]$Screen) {
    $menuRect = Find-Slot '메뉴' $Screen
    if (-not $menuRect.IsEmpty) {
        Write-RoutineTrace $script:CurrentCycle 'post-clear' '나가기' 'closed-confirmed-menu' $menuRect 'menu image visible after exit'
        return $true
    }
    if (Test-SpecialSlotEnabled '협동') {
        $coopRect = Find-Slot '협동' $Screen
        if (-not $coopRect.IsEmpty) {
            Write-RoutineTrace $script:CurrentCycle 'post-clear' '나가기' 'closed-confirmed-coop' $coopRect 'coop confirmation visible after exit'
            return $true
        }
    }
    Write-RoutineTrace $script:CurrentCycle 'post-clear' '나가기' 'closed-confirmed-disappeared' ([System.Drawing.Rectangle]::Empty) 'exit button disappeared; accept closed and advance to menu recovery'
    return $true
}

function Invoke-ExitActionUntilClosed([System.Windows.Forms.Screen]$Screen, [System.Windows.Forms.Label]$StatusLabel, [System.Drawing.Rectangle]$ExitRect) {
    for ($try = 1; $try -le 2; $try++) {
        $StatusLabel.Text = '나가기 감지: 종료 처리 ' + $try + '/2'
        [System.Windows.Forms.Application]::DoEvents()
        Write-RoutineTrace $script:CurrentCycle 'post-clear' '나가기' 'click-before' $ExitRect ('try=' + $try)
        [void](Click-SlotTarget '나가기' $ExitRect ([int]$stepDelayBox.Value) 520)
        Write-RoutineTrace $script:CurrentCycle 'post-clear' '나가기' 'click-after' $ExitRect ('try=' + $try)
        [void](Sleep-WithStop 1400)
        if ($script:StopRequested) { return [pscustomobject]@{ Closed = $false; Clicks = $try; Rect = [System.Drawing.Rectangle]::Empty } }
        $stillExit = Find-ValidSlotOnce '나가기' $Screen $true
        if ($stillExit.IsEmpty) {
            if (Test-ExitClosedConfirmed $Screen) {
                Write-RoutineTrace $script:CurrentCycle 'post-clear' '나가기' 'closed' ([System.Drawing.Rectangle]::Empty) ('clicks=' + $try)
                return [pscustomobject]@{ Closed = $true; Clicks = $try; Rect = [System.Drawing.Rectangle]::Empty }
            }
            Write-RoutineTrace $script:CurrentCycle 'post-clear' '나가기' 'closed-rejected' $ExitRect ('clicks=' + $try + '; keep exit stage')
            continue
        }
        Write-RoutineTrace $script:CurrentCycle 'post-clear' '나가기' 'still-visible' $stillExit ('after-click-try=' + $try)
        $ExitRect = $stillExit
    }
    Write-RoutineTrace $script:CurrentCycle 'post-clear' '나가기' 'retry-without-space' $ExitRect 'space fallback disabled; keep exit stage'
    return [pscustomobject]@{ Closed = $false; Clicks = 2; Rect = $ExitRect }
}
function Invoke-FoodButtonIfVisible([System.Windows.Forms.Screen]$Screen, [System.Windows.Forms.Label]$StatusLabel) {
    if ($null -eq $script:Samples['식사 버튼']) { return $false }
    $rect = Find-Slot '식사 버튼' $Screen
    if ($rect.IsEmpty) { return $false }
    $pointResult = Check-SlotPointMatch '식사 버튼' $rect
    if (-not $pointResult.Ok) {
        Write-RoutineTrace $script:CurrentCycle 'food' '식사 버튼' 'point-blocked' $rect $pointResult.Message
        return $false
    }
    Write-RoutineTrace $script:CurrentCycle 'food' '식사 버튼' 'found-click' $rect 'image and coordinate confirmed'
    $StatusLabel.Text = '식사 버튼 감지: 클릭 후 B 보강'
    [System.Windows.Forms.Application]::DoEvents()
    [void](Click-SlotTarget '식사 버튼' $rect 500 120)
    $stillFood = Find-Slot '식사 버튼' $Screen
    if (-not $stillFood.IsEmpty) {
        $stillPoint = Check-SlotPointMatch '식사 버튼' $stillFood
        if ($stillPoint.Ok) {
            Write-RoutineTrace $script:CurrentCycle 'food' '식사 버튼' 'still-visible-send-b' $stillFood 'click did not clear food prompt'
            Invoke-BKey 'food still visible after click'
        }
    }
    return $true
}
function Test-CoopAttemptAllowed {
    return ([int]$script:CoopClickAttempts -lt [int]$script:MaxCoopClickAttempts)
}
function Reset-CoopAttempts {
    if ([int]$script:CoopClickAttempts -ne 0) { Write-RoutineTrace $script:CurrentCycle 'coop' '협동' 'attempt-reset' ([System.Drawing.Rectangle]::Empty) ('attempts=' + $script:CoopClickAttempts) }
    $script:CoopClickAttempts = 0
}

function Get-NextRoutineStage([string]$Slot) {
    switch ($Slot) {
        '__전환대기' { return '내부' }
        '협동' { if (Test-CoopAttemptAllowed) { return '협동' }; return '메뉴' }
        '메뉴' { return '어비스' }
        '어비스' { return '던전' }
        '던전' { return '입장' }
        '입장' { return '내부' }
        '상태 기준' { return '내부' }
        '식사 버튼' { return '내부' }
        '궁극기' { return '내부' }
        '스킵' { return '내부' }
        '팔라딘' { return '내부' }
        '입장_전투중' { return '내부' }
        '완료 확인' { return '나가기' }
        '나가기' {
            if ((Test-SpecialSlotEnabled '협동') -and (Get-SlotSamplePaths '협동').Count -gt 0) { return '협동' }
            return '메뉴'
        }
        '__협동없음' { return '메뉴' }
        default { return '' }
    }
}
function Find-RoutineCandidate([System.Windows.Forms.Screen]$Screen, [string]$Stage) {
    if ([string]::IsNullOrWhiteSpace($Stage)) { $Stage = '메뉴' }
    if ($Stage -ne '내부' -and (Get-SlotSamplePaths '상태 기준').Count -gt 0) {
        $globalStateRect = Find-ValidSlotOnce '상태 기준' $Screen $true
        if (-not $globalStateRect.IsEmpty) {
            Write-RoutineTrace $script:CurrentCycle 'stage-scan' '상태 기준' 'global-inside-guard' $globalStateRect ('stage=' + $Stage + '; route/special blocked while inside marker is visible')
            return [pscustomobject]@{ Slot = '상태 기준'; Rect = $globalStateRect; Stage = $Stage }
        }
    }
    if ($Stage -eq '협동') {
        if (-not (Test-CoopAttemptAllowed)) {
            Write-RoutineTrace $script:CurrentCycle 'stage-scan' '협동' 'attempt-limit-skip' ([System.Drawing.Rectangle]::Empty) ('attempts=' + $script:CoopClickAttempts + '; max=' + $script:MaxCoopClickAttempts)
            return [pscustomobject]@{ Slot = '__협동없음'; Rect = [System.Drawing.Rectangle]::Empty; Stage = $Stage }
        }
        if (-not (Test-SpecialSlotEnabled '협동') -or (Get-SlotSamplePaths '협동').Count -eq 0) {
            Write-RoutineTrace $script:CurrentCycle 'stage-scan' '협동' 'skip-special-after-loop' ([System.Drawing.Rectangle]::Empty) 'special disabled or missing sample; continue to menu'
            return [pscustomobject]@{ Slot = '__협동없음'; Rect = [System.Drawing.Rectangle]::Empty; Stage = $Stage }
        }
        $coopRect = Find-ValidSlotOnce '협동' $Screen $true
        if (-not $coopRect.IsEmpty) {
            Write-RoutineTrace $script:CurrentCycle 'stage-scan' '협동' 'candidate-after-loop' $coopRect ('stage=협동; special after loop; attempts=' + $script:CoopClickAttempts)
            return [pscustomobject]@{ Slot = '협동'; Rect = $coopRect; Stage = $Stage }
        }
        Write-RoutineTrace $script:CurrentCycle 'stage-scan' '협동' 'miss-special-after-loop' ([System.Drawing.Rectangle]::Empty) 'special not visible; continue to menu'
        return [pscustomobject]@{ Slot = '__협동없음'; Rect = [System.Drawing.Rectangle]::Empty; Stage = $Stage }
    }
    if ($Stage -eq '입장') {
        $entryBusyRect = Find-EntryBusyGuard $Screen
        if (-not $entryBusyRect.IsEmpty) {
            Write-RoutineTrace $script:CurrentCycle 'stage-scan' '입장_전투중' 'route-guard-candidate' $entryBusyRect ('stage=' + $Stage + '; entry screen already in battle')
            return [pscustomobject]@{ Slot = '입장_전투중'; Rect = $entryBusyRect; Stage = $Stage }
        }
    }
    if ($Stage -eq '내부') {
        $stateRect = [System.Drawing.Rectangle]::Empty
        if ($null -ne $script:Samples['상태 기준']) {
            $stateRect = Find-ValidSlotOnce '상태 기준' $Screen $true
        }
        $stateNote = 'state marker not visible'
        if (-not $stateRect.IsEmpty) {
            $stateNote = 'state marker visible'
            $script:CombatMarkerSeen = $true
            if ($script:BossSkipSeen) { $script:CombatMarkerSeenAfterSkip = $true }
            Write-RoutineTrace $script:CurrentCycle 'stage-scan' '상태 기준' 'inside-lock' $stateRect 'stage=내부; allowed=스킵|식사 버튼|궁극기|팔라딘|상태 기준'
        }
        if ((Get-SlotSamplePaths '스킵').Count -gt 0) {
            $skipRect = Find-ValidSlotOnce '스킵' $Screen $true
            if (-not $skipRect.IsEmpty) {
                Write-RoutineTrace $script:CurrentCycle 'stage-scan' '스킵' 'candidate-inside-only' $skipRect $stateNote
                return [pscustomobject]@{ Slot = '스킵'; Rect = $skipRect; Stage = $Stage }
            }
            Write-RoutineTrace $script:CurrentCycle 'stage-scan' '스킵' 'miss-inside' ([System.Drawing.Rectangle]::Empty) $stateNote
        } else {
            Write-RoutineTrace $script:CurrentCycle 'stage-scan' '스킵' 'missing-sample-inside' ([System.Drawing.Rectangle]::Empty) $stateNote
        }
        if ($stateRect.IsEmpty) {
            $insideBusyRect = Find-EntryBusyGuard $Screen
            if (-not $insideBusyRect.IsEmpty) {
                $script:PendingCompleteSeen = 0
                Write-RoutineTrace $script:CurrentCycle 'stage-scan' '입장_전투중' 'internal-entry-busy-recovery' $insideBusyRect 'inside stage lost state marker on entry combat screen; restore with ESC'
                return [pscustomobject]@{ Slot = '입장_전투중'; Rect = $insideBusyRect; Stage = $Stage }
            }
        }
        if ($stateRect.IsEmpty -and (Test-InternalTransitionFrame $Screen)) {
            return [pscustomobject]@{ Slot = '__전환대기'; Rect = [System.Drawing.Rectangle]::Empty; Stage = $Stage }
        }
        if ($stateRect.IsEmpty) {
            Write-RoutineTrace $script:CurrentCycle 'stage-scan' '전투슬롯' 'blocked-state-missing' ([System.Drawing.Rectangle]::Empty) 'state marker not visible; skip food/ultimate/paladin'
        }
        foreach ($slot in @('식사 버튼','궁극기','팔라딘')) {
            if (Test-StopRequested) { return $null }
            $allowCombatScan = (-not $stateRect.IsEmpty)
            if (-not $allowCombatScan) {
                Write-RoutineTrace $script:CurrentCycle 'stage-scan' $slot 'blocked-state-missing' ([System.Drawing.Rectangle]::Empty) 'state marker not visible; active combat slot skipped'
                continue
            }
            if ((Get-SlotSamplePaths $slot).Count -eq 0) {
                Write-RoutineTrace $script:CurrentCycle 'stage-scan' $slot 'missing-sample-inside' ([System.Drawing.Rectangle]::Empty) $stateNote
                continue
            }
            $rect = Find-ValidSlotOnce $slot $Screen $true
            if (-not $rect.IsEmpty) {
                Write-RoutineTrace $script:CurrentCycle 'stage-scan' $slot 'candidate-inside-only' $rect $stateNote
                return [pscustomobject]@{ Slot = $slot; Rect = $rect; Stage = $Stage }
            }
            Write-RoutineTrace $script:CurrentCycle 'stage-scan' $slot 'miss-inside' ([System.Drawing.Rectangle]::Empty) $stateNote
        }
        if (-not $stateRect.IsEmpty) {
            $script:PendingCompleteSeen = 0
            Write-RoutineTrace $script:CurrentCycle 'stage-scan' '상태 기준' 'inside-keep-block-route' $stateRect 'state marker visible; skip complete/exit scan'
            return [pscustomobject]@{ Slot = '상태 기준'; Rect = $stateRect; Stage = $Stage }
        }
        if ($null -ne $script:Samples['완료 확인']) {
            $completeRect = Find-ValidSlotOnce '완료 확인' $Screen $true
            if (-not $completeRect.IsEmpty) {
                if (Test-CompleteVisualCandidateAllowed) {
                    $completeContext = $stateNote + '; visual-confirmed; ' + (Get-CompleteGateDetail)
                    if (Test-StableCompleteCandidate $completeRect $completeContext) {
                        Write-RoutineTrace $script:CurrentCycle 'stage-scan' '완료 확인' 'candidate-after-inside' $completeRect ($completeContext + '; stable-confirmed')
                        return [pscustomobject]@{ Slot = '완료 확인'; Rect = $completeRect; Stage = $Stage }
                    }
                    return $null
                }
                $script:PendingCompleteSeen = 0
                Write-RoutineTrace $script:CurrentCycle 'stage-scan' '완료 확인' 'candidate-blocked-by-strict-gate' $completeRect ($stateNote + '; visual-confirmed; ' + (Get-CompleteGateDetail))
            } elseif (-not (Test-CompleteRecoveryScanAllowed $Stage)) {
                Write-RoutineTrace $script:CurrentCycle 'stage-scan' '완료 확인' 'blocked-by-gate' ([System.Drawing.Rectangle]::Empty) (Get-CompleteGateDetail)
            }
        }
        Write-RoutineTrace $script:CurrentCycle 'stage-scan' '' 'none' ([System.Drawing.Rectangle]::Empty) 'stage=내부; checked=상태 기준|스킵|식사 버튼|궁극기|팔라딘|완료 확인'
        return $null
    }
    $expectedSlot = $Stage
    if ($Stage -eq '메뉴확인') { $expectedSlot = '메뉴' }
    if ($Stage -eq '완료') { $expectedSlot = '완료 확인' }
    if ($Stage -eq '종료') { $expectedSlot = '나가기' }
    if ((Get-SlotSamplePaths $expectedSlot).Count -eq 0) {
        Write-RoutineTrace $script:CurrentCycle 'stage-scan' $expectedSlot 'missing-sample' ([System.Drawing.Rectangle]::Empty) ('stage=' + $Stage)
        return $null
    }
    $rect = Find-ValidSlotOnce $expectedSlot $Screen $true
    if (-not $rect.IsEmpty) {
        Write-RoutineTrace $script:CurrentCycle 'stage-scan' $expectedSlot 'candidate' $rect ('stage=' + $Stage)
        return [pscustomobject]@{ Slot = $expectedSlot; Rect = $rect; Stage = $Stage }
    }
    if ($Stage -eq '입장') {
        $busyRect = Find-EntryBusyGuard $Screen
        if (-not $busyRect.IsEmpty) {
            Write-RoutineTrace $script:CurrentCycle 'stage-scan' '입장_전투중' 'busy-route-candidate' $busyRect 'entry screen is in battle state; enter inside monitor without clicking'
            return [pscustomobject]@{ Slot = '입장_전투중'; Rect = $busyRect; Stage = $Stage }
        }
    }
    if (@('던전','입장','메뉴확인','어비스') -contains $Stage) {
        if ((Get-SlotSamplePaths '상태 기준').Count -gt 0) {
            $recoveryStateRect = Find-ValidSlotOnce '상태 기준' $Screen $true
            if (-not $recoveryStateRect.IsEmpty) {
                Write-RoutineTrace $script:CurrentCycle 'stage-scan' '상태 기준' 'recovery-candidate' $recoveryStateRect ('expected=' + $expectedSlot + '; stage=' + $Stage)
                return [pscustomobject]@{ Slot = '상태 기준'; Rect = $recoveryStateRect; Stage = $Stage }
            }
        }
        if ((Get-SlotSamplePaths '완료 확인').Count -gt 0) {
            $recoveryCompleteRect = Find-ValidSlotOnce '완료 확인' $Screen $true
            if (-not $recoveryCompleteRect.IsEmpty) {
                if (Test-CompleteVisualCandidateAllowed) {
                    $recoveryCompleteContext = 'expected=' + $expectedSlot + '; stage=' + $Stage + '; visual-confirmed; ' + (Get-CompleteGateDetail)
                    if (Test-StableCompleteCandidate $recoveryCompleteRect $recoveryCompleteContext) {
                        Write-RoutineTrace $script:CurrentCycle 'stage-scan' '완료 확인' 'recovery-candidate' $recoveryCompleteRect ($recoveryCompleteContext + '; stable-confirmed')
                        return [pscustomobject]@{ Slot = '완료 확인'; Rect = $recoveryCompleteRect; Stage = $Stage }
                    }
                    return $null
                }
                $script:PendingCompleteSeen = 0
                Write-RoutineTrace $script:CurrentCycle 'stage-scan' '완료 확인' 'recovery-candidate-blocked-by-strict-gate' $recoveryCompleteRect ('expected=' + $expectedSlot + '; stage=' + $Stage + '; visual-confirmed; ' + (Get-CompleteGateDetail))
            } elseif (-not (Test-CompleteRecoveryScanAllowed $Stage)) {
                Write-RoutineTrace $script:CurrentCycle 'stage-scan' '완료 확인' 'recovery-blocked-by-gate' ([System.Drawing.Rectangle]::Empty) ('expected=' + $expectedSlot + '; stage=' + $Stage + '; ' + (Get-CompleteGateDetail))
            }
        }
    }
    Write-RoutineTrace $script:CurrentCycle 'stage-scan' $expectedSlot 'miss' ([System.Drawing.Rectangle]::Empty) ('stage=' + $Stage)
    return $null
}
function Get-StateActionSettleMs([string]$Slot) {
    switch ($Slot) {
        '__전환대기' { return 800 }
        '협동' { return 600 }
        '메뉴' { return 900 }
        '어비스' { return 900 }
        '던전' { return 900 }
        '입장' { return 1800 }
        '상태 기준' { return 450 }
        '완료 확인' { return 1800 }
        '식사 버튼' { return 900 }
        '궁극기' { return 600 }
        '스킵' { return 700 }
        '팔라딘' { return 900 }
        default { return 900 }
    }
}
function Wait-StateActionSettle([string]$Slot) {
    $delay = Get-StateActionSettleMs $Slot
    Write-RoutineTrace $script:CurrentCycle 'state-action' $Slot 'settle-wait' ([System.Drawing.Rectangle]::Empty) ('ms=' + $delay)
    [void](Sleep-WithStop $delay)
}
function Invoke-RoutineCandidateAction($Candidate, [System.Windows.Forms.Screen]$Screen, [System.Windows.Forms.Label]$StatusLabel, [ref]$InsidePhase) {
    if ($null -eq $Candidate) { return [pscustomobject]@{ Clicks = 0; Completed = $false; Message = ''; NextStage = '' } }
    $slot = [string]$Candidate.Slot
    $rect = $Candidate.Rect
    $nextStage = Get-NextRoutineStage $slot
    Mark-ActiveSlot $slot
    switch ($slot) {
        '__전환대기' {
            $StatusLabel.Text = '전환 화면 대기: 클릭하지 않고 재감시'
            [System.Windows.Forms.Application]::DoEvents()
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'wait-no-click' $rect 'dark transition frame; keep inside stage'
            Wait-StateActionSettle $slot
            return [pscustomobject]@{ Clicks = 0; Completed = $false; Message = '전환 대기'; NextStage = $nextStage }
        }
        '__협동없음' {
            $StatusLabel.Text = '협동 없음: 메뉴 단계로 이동'
            [System.Windows.Forms.Application]::DoEvents()
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'advance-no-click' $rect 'next=메뉴'
            return [pscustomobject]@{ Clicks = 0; Completed = $false; Message = '협동 없음'; NextStage = $nextStage }
        }
        '협동' {
            $script:CoopClickAttempts++
            $StatusLabel.Text = '협동 감지: 확인 처리 ' + $script:CoopClickAttempts + '/' + $script:MaxCoopClickAttempts
            [System.Windows.Forms.Application]::DoEvents()
            [void](Click-SlotTarget '협동' $rect ([int]$stepDelayBox.Value) ([int]$clickHoldBox.Value))
            if (-not (Test-CoopAttemptAllowed)) { $nextStage = '메뉴' }
        }
        '입장' {
            Reset-CoopAttempts
            $StatusLabel.Text = '입장 감지: 클릭 후 내부 진행 감시'
            [System.Windows.Forms.Application]::DoEvents()
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'click-before' $rect 'enter-to-inside; quest removed'
            [void](Click-SlotTarget $slot $rect ([int]$stepDelayBox.Value))
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'click-after' $rect 'inside phase enabled'
            $InsidePhase.Value = $true
            $script:InsideStartedAt = Get-Date
            $script:CombatMarkerSeen = $false
            $script:BossSkipSeen = $false
            $script:CombatMarkerSeenAfterSkip = $false
            Set-ProgressStep 5
            Wait-StateActionSettle $slot
            return [pscustomobject]@{ Clicks = 1; Completed = $false; Message = '입장 클릭 후 내부 감시'; NextStage = $nextStage }
        }
        '나가기' {
            $exitResult = Invoke-ExitActionUntilClosed $Screen $StatusLabel $rect
            if ($exitResult.Closed) {
                $InsidePhase.Value = $false
                $script:InsideStartedAt = $null
                $script:CombatMarkerSeen = $false
                $script:BossSkipSeen = $false
                $script:CombatMarkerSeenAfterSkip = $false
                Set-ProgressStep 10
                return [pscustomobject]@{ Clicks = [int]$exitResult.Clicks; Completed = $true; Message = '순환 완료'; NextStage = '메뉴' }
            }
            return [pscustomobject]@{ Clicks = [int]$exitResult.Clicks; Completed = $false; Message = '나가기 재탐색'; NextStage = '나가기' }
        }
        '입장_전투중' {
            Reset-CoopAttempts
            $StatusLabel.Text = '전투중 화면 감지: ESC 복구 후 내부 감시'
            [System.Windows.Forms.Application]::DoEvents()
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'inside-monitor-restore-before-esc' $rect 'entry screen is already in combat; press ESC twice and return to state monitor'
            Invoke-EscapeTwice 'entry busy guard'
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'inside-monitor-restore-after-esc' $rect 'esc recovery sent'
            $InsidePhase.Value = $true
            if ($null -eq $script:InsideStartedAt) { $script:InsideStartedAt = Get-Date }
            if (-not $script:CombatMarkerSeen) { $script:CombatMarkerSeen = $true }
            $script:PendingCompleteSeen = 0
            Set-ProgressStep 5
            Wait-StateActionSettle '상태 기준'
            return [pscustomobject]@{ Clicks = 0; Completed = $false; Message = '전투중 화면 ESC 복구'; NextStage = $nextStage }
        }
        '완료 확인' {
            Reset-CoopAttempts
            $StatusLabel.Text = '완료 확인 감지: 클릭'
            [System.Windows.Forms.Application]::DoEvents()
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'click-before' $rect ''
            [void](Click-SlotTarget $slot $rect ([int]$stepDelayBox.Value))
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'click-after' $rect ''
            $InsidePhase.Value = $false
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'keep-combat-history-until-exit' $rect 'exit screen has not closed yet'
            Set-ProgressStep 8
            Wait-StateActionSettle $slot
            return [pscustomobject]@{ Clicks = 1; Completed = $false; Message = '완료 확인 클릭'; NextStage = $nextStage }
        }
        '식사 버튼' {
            if (-not $InsidePhase.Value) { return [pscustomobject]@{ Clicks = 0; Completed = $false; Message = '식사 무시: 내부 진행 아님'; NextStage = '' } }
            $StatusLabel.Text = '식사 버튼 감지: B 입력'
            [System.Windows.Forms.Application]::DoEvents()
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'send-b-direct' $rect 'candidate already verified'
            Invoke-BKey 'food image matched'
            Wait-StateActionSettle $slot
            return [pscustomobject]@{ Clicks = 1; Completed = $false; Message = '식사 B 입력'; NextStage = $nextStage }
        }
        '궁극기' {
            if (-not $InsidePhase.Value) { return [pscustomobject]@{ Clicks = 0; Completed = $false; Message = '궁극기 무시: 내부 진행 아님'; NextStage = '' } }
            Save-SelectedUltimateProfileFromControls
            $ultimateProfile = Get-SelectedUltimateProfile
            $StatusLabel.Text = '궁극기 감지: ' + [string]$ultimateProfile.Name + ' / 6 입력'
            [System.Windows.Forms.Application]::DoEvents()
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'send-6-direct' $rect ('profile=' + [string]$ultimateProfile.Name)
            Invoke-UltimateKey ([string]$ultimateProfile.Name)
            Wait-StateActionSettle $slot
            return [pscustomobject]@{ Clicks = 1; Completed = $false; Message = '궁극기 6 입력'; NextStage = $nextStage }
        }
        '스킵' {
            if (-not $InsidePhase.Value) { return [pscustomobject]@{ Clicks = 0; Completed = $false; Message = '스킵 무시: 내부 진행 아님'; NextStage = '' } }
            $StatusLabel.Text = '스킵 감지: 클릭'
            [System.Windows.Forms.Application]::DoEvents()
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'click-before' $rect 'inside-only'
            [void](Click-SlotTarget $slot $rect 250 120)
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'click-after' $rect ''
            $script:BossSkipSeen = $true
            $script:CombatMarkerSeenAfterSkip = $false
            Wait-StateActionSettle $slot
            return [pscustomobject]@{ Clicks = 1; Completed = $false; Message = '스킵 클릭'; NextStage = $nextStage }
        }
        '팔라딘' {
            if (-not $InsidePhase.Value) { return [pscustomobject]@{ Clicks = 0; Completed = $false; Message = '팔라딘 무시: 내부 진행 아님'; NextStage = '' } }
            $StatusLabel.Text = '팔라딘 감지: F5 입력'
            [System.Windows.Forms.Application]::DoEvents()
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'send-f5-direct' $rect 'inside-only'
            Invoke-PaladinKey 'paladin image matched'
            Wait-StateActionSettle $slot
            return [pscustomobject]@{ Clicks = 1; Completed = $false; Message = '팔라딘 F5 입력'; NextStage = $nextStage }
        }
        '상태 기준' {
            $StatusLabel.Text = '상태 기준 감지: 내부 진행 중, 스킵/식사/궁극기/팔라딘만 감시'
            [System.Windows.Forms.Application]::DoEvents()
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'inside-observe-only' $rect 'blocked route slots while visible'
            $InsidePhase.Value = $true
            $script:CombatMarkerSeen = $true
            if ($script:BossSkipSeen) { $script:CombatMarkerSeenAfterSkip = $true }
            if ($null -eq $script:InsideStartedAt) { $script:InsideStartedAt = Get-Date }
            Set-ProgressStep 5
            Wait-StateActionSettle $slot
            return [pscustomobject]@{ Clicks = 0; Completed = $false; Message = '상태 기준 확인'; NextStage = $nextStage }
        }
        '퀘스트' {
            $StatusLabel.Text = '퀘스트 감지: 진행 시작'
            [System.Windows.Forms.Application]::DoEvents()
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'click-before' $rect ''
            [void](Click-SlotTarget $slot $rect ([int]$stepDelayBox.Value) 120)
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'click-after' $rect ''
            $InsidePhase.Value = $true
            $script:InsideStartedAt = Get-Date
            $script:CombatMarkerSeen = $false
            $script:BossSkipSeen = $false
            $script:CombatMarkerSeenAfterSkip = $false
            Set-ProgressStep 7
            Wait-StateActionSettle $slot
            return [pscustomobject]@{ Clicks = 1; Completed = $false; Message = '퀘스트 클릭'; NextStage = $nextStage }
        }
        default {
            $StatusLabel.Text = $slot + ' 감지: 클릭'
            [System.Windows.Forms.Application]::DoEvents()
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'click-before' $rect ''
            [void](Click-SlotTarget $slot $rect ([int]$stepDelayBox.Value))
            Write-RoutineTrace $script:CurrentCycle 'state-action' $slot 'click-after' $rect ''
            Wait-StateActionSettle $slot
            return [pscustomobject]@{ Clicks = 1; Completed = $false; Message = $slot + ' 클릭'; NextStage = $nextStage }
        }
    }
}
function Ensure-LogHeader { if (-not [System.IO.File]::Exists($script:LogPath)) { [void](Write-TextFileSafe $script:LogPath 'started_at,ended_at,target_title,matched_window,monitor,requested_cycles,completed_cycles,completed_clicks,interval_ms,elapsed_seconds,average_cycle_seconds,status,message') } }
function Csv([string]$Value) { if ($null -eq $Value) { $Value = '' }; return '"' + $Value.Replace('"', '""') + '"' }
function Ensure-RoutineTraceHeader { if (-not [System.IO.File]::Exists($script:RoutineTracePath)) { [void](Write-TextFileSafe $script:RoutineTracePath 'time,cycle,phase,slot,event,x,y,detail') } }
function Write-RoutineTrace([int]$Cycle, [string]$Phase, [string]$Slot, [string]$Event, [System.Drawing.Rectangle]$Rect, [string]$Detail) {
    Ensure-RoutineTraceHeader
    $x = ''
    $y = ''
    if ($null -ne $Rect -and -not $Rect.IsEmpty) { $x = [int]($Rect.Left + $Rect.Width / 2); $y = [int]($Rect.Top + $Rect.Height / 2) }
    $line = @((Get-Date).ToString('s'), $Cycle, (Csv $Phase), (Csv $Slot), (Csv $Event), $x, $y, (Csv $Detail)) -join ','
    [void](Add-TextLineSafe $script:RoutineTracePath $line)
}
function Save-DiagnosticFrame([string]$Slot, [string]$Event, [System.Drawing.Rectangle]$Bounds, [System.Drawing.Rectangle]$MatchRect, [string]$Detail) {
    if ($null -eq $Bounds -or $Bounds.IsEmpty -or $Bounds.Width -lt 4 -or $Bounds.Height -lt 4) { return }
    if ([DateTime]::Now -lt $script:DiagnosticDisabledUntil) { return }
    try {
        New-Item -ItemType Directory -Force -Path $script:DiagnosticDir | Out-Null
        $safeSlot = if ([string]::IsNullOrWhiteSpace($Slot)) { 'none' } else { $Slot -replace '[\\/:*?"<>| ]', '_' }
        $safeEvent = if ([string]::IsNullOrWhiteSpace($Event)) { 'event' } else { $Event -replace '[\\/:*?"<>| ]', '_' }
        $name = ('{0:yyyyMMdd_HHmmss_fff}_c{1}_{2}_{3}.png' -f (Get-Date), $script:CurrentCycle, $safeSlot, $safeEvent)
        $path = Join-Path $script:DiagnosticDir $name
        $captureBounds = $Bounds
        $drawRect = $MatchRect
        if ($Bounds.Width * $Bounds.Height -gt 700000 -and $null -ne $MatchRect -and -not $MatchRect.IsEmpty) {
            $pad = 90
            $left = [Math]::Max($Bounds.Left, $MatchRect.Left - $pad)
            $top = [Math]::Max($Bounds.Top, $MatchRect.Top - $pad)
            $right = [Math]::Min($Bounds.Right, $MatchRect.Right + $pad)
            $bottom = [Math]::Min($Bounds.Bottom, $MatchRect.Bottom + $pad)
            if ($right -gt $left -and $bottom -gt $top) {
                $captureBounds = [System.Drawing.Rectangle]::new([int]$left, [int]$top, [int]($right - $left), [int]($bottom - $top))
            }
        }
        $bmp = [VisionFinder]::Capture($captureBounds)
        try {
            if ($null -ne $drawRect -and -not $drawRect.IsEmpty) {
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                try {
                    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Red, 3)
                    $local = [System.Drawing.Rectangle]::new([int]($drawRect.Left - $captureBounds.Left), [int]($drawRect.Top - $captureBounds.Top), [int]$drawRect.Width, [int]$drawRect.Height)
                    $g.DrawRectangle($pen, $local)
                    $pen.Dispose()
                    $font = New-Object System.Drawing.Font('Malgun Gothic', 10, [System.Drawing.FontStyle]::Bold)
                    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Yellow)
                    $g.DrawString(($Slot + ' ' + $Event), $font, $brush, 6, 6)
                    $brush.Dispose()
                    $font.Dispose()
                } finally { $g.Dispose() }
            }
            $tmpPath = $path + '.tmp'
            if ([System.IO.File]::Exists($tmpPath)) { [System.IO.File]::Delete($tmpPath) }
            $bmp.Save($tmpPath, [System.Drawing.Imaging.ImageFormat]::Png)
            if ([System.IO.File]::Exists($path)) { [System.IO.File]::Delete($path) }
            [System.IO.File]::Move($tmpPath, $path)
        } finally { $bmp.Dispose() }
        $script:DiagnosticFailureCount = 0
        Write-RoutineTrace $script:CurrentCycle 'diagnostic-frame' $Slot $Event ([System.Drawing.Rectangle]::Empty) (([System.IO.Path]::GetFileName($path)) + '; ' + $Detail)
    } catch {
        $script:DiagnosticFailureCount++
        if ($script:DiagnosticFailureCount -ge 3) {
            $script:DiagnosticDisabledUntil = [DateTime]::Now.AddMinutes(10)
            Write-RoutineTrace $script:CurrentCycle 'diagnostic-frame' $Slot 'auto-disabled' ([System.Drawing.Rectangle]::Empty) 'diagnostic save failed 3 times; disabled for 10 minutes'
        }
        Write-RoutineTrace $script:CurrentCycle 'diagnostic-frame' $Slot 'save-failed' ([System.Drawing.Rectangle]::Empty) $_.Exception.Message
    }
}
function Write-RunLog($Started, $Ended, $TitlePart, $MatchedTitle, $MonitorName, $Requested, $CompletedCycles, $CompletedClicks, $Interval, $Elapsed, $Average, $Status, $Message) { Ensure-LogHeader; $line = @($Started.ToString('s'), $Ended.ToString('s'), (Csv $TitlePart), (Csv $MatchedTitle), (Csv $MonitorName), $Requested, $CompletedCycles, $CompletedClicks, $Interval, ('{0:F3}' -f $Elapsed), ('{0:F3}' -f $Average), (Csv $Status), (Csv $Message)) -join ','; [void](Add-TextLineSafe $script:LogPath $line) }

function Test-HarborEnabled {
    try { if ($harborEnabledCheck) { return [bool]$harborEnabledCheck.Checked } } catch { }
    return [bool]$script:HarborEnabled
}

function Test-DungeonRoutineEnabled([string]$Name) {
    try {
        if ($Name -eq '허상의 정박지' -and $harborEnabledCheck) { return [bool]$harborEnabledCheck.Checked }
        if ($Name -eq '광기의 동굴' -and $caveEnabledCheck) { return [bool]$caveEnabledCheck.Checked }
    } catch { }
    if ($script:DungeonRoutineEnabled.ContainsKey($Name)) { return [bool]$script:DungeonRoutineEnabled[$Name] }
    return $false
}

function Test-AnyDungeonRoutineEnabled {
    return ((Test-DungeonRoutineEnabled '허상의 정박지') -or (Test-DungeonRoutineEnabled '광기의 동굴'))
}

function Test-CombatSlotEnabled([string]$Slot) {
    if (-not ($script:CombatSlots -contains $Slot)) { return $true }
    try {
        if ($script:CombatSlotChecks -and $script:CombatSlotChecks.ContainsKey($Slot)) {
            return [bool]$script:CombatSlotChecks[$Slot].Checked
        }
    } catch { }
    if ($script:CombatSlotEnabled.ContainsKey($Slot)) { return [bool]$script:CombatSlotEnabled[$Slot] }
    return $true
}

function Test-SpecialSlotEnabled([string]$Slot) {
    if (-not ($script:SpecialSlots -contains $Slot)) { return $true }
    try {
        if ($script:SpecialSlotChecks -and $script:SpecialSlotChecks.ContainsKey($Slot)) {
            return [bool]$script:SpecialSlotChecks[$Slot].Checked
        }
    } catch { }
    if ($script:SpecialSlotEnabled.ContainsKey($Slot)) { return [bool]$script:SpecialSlotEnabled[$Slot] }
    return $true
}

function Test-SlotEnabled([string]$Slot) {
    if ($script:SpecialSlots -contains $Slot) { return (Test-SpecialSlotEnabled $Slot) }
    $baseSlot = Resolve-RouteSlotFromStorageKey $Slot
    if ($script:RouteSlots -contains $baseSlot) { return (Test-AnyDungeonRoutineEnabled) }
    if ($script:CombatSlots -contains $Slot) { return (Test-CombatSlotEnabled $Slot) }
    return $true
}

function Get-SelectedUltimateProfile {
    $index = [Math]::Max(0, [Math]::Min($script:UltimateProfiles.Count - 1, [int]$script:SelectedUltimateProfileIndex))
    return $script:UltimateProfiles[$index]
}

function Get-UltimateProfileLabel([int]$Index) {
    if ($Index -lt 0 -or $Index -ge $script:UltimateProfiles.Count) { return '' }
    $profile = $script:UltimateProfiles[$Index]
    return (($Index + 1).ToString() + '. ' + [string]$profile.Name)
}

function Save-SelectedUltimateProfileFromControls {
    try {
        if ($script:UltimateProfiles.Count -le 0) { return }
        $index = [Math]::Max(0, [Math]::Min($script:UltimateProfiles.Count - 1, [int]$script:SelectedUltimateProfileIndex))
        $name = $ultimateNameBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($name)) { $name = '궁극기 설정 ' + ($index + 1) }
        $script:UltimateProfiles[$index] = [pscustomobject]@{ Name = $name }
    } catch { }
}

function Refresh-UltimateProfileCombo {
    $previousSuppress = [bool]$script:SuppressUltimateProfileEvents
    $script:SuppressUltimateProfileEvents = $true
    try {
        $selected = [int]$script:SelectedUltimateProfileIndex
        $ultimateProfileBox.Items.Clear()
        for ($i = 0; $i -lt $script:UltimateProfiles.Count; $i++) { [void]$ultimateProfileBox.Items.Add((Get-UltimateProfileLabel $i)) }
        if ($ultimateProfileBox.Items.Count -gt 0) { $ultimateProfileBox.SelectedIndex = [Math]::Max(0, [Math]::Min($ultimateProfileBox.Items.Count - 1, $selected)) }
    } catch { }
    finally { $script:SuppressUltimateProfileEvents = $previousSuppress }
}

function Apply-UltimateProfileToControls {
    try {
        $profile = Get-SelectedUltimateProfile
        $ultimateNameBox.Text = [string]$profile.Name
        Refresh-UltimateProfileCombo
    } catch { }
}

function Get-QuestProfileLabel([int]$Index) {
    if ($Index -lt 0 -or $Index -ge $script:QuestProfiles.Count) { return '' }
    $profile = $script:QuestProfiles[$Index]
    return (($Index + 1).ToString() + '. ' + [string]$profile.Name)
}

function Refresh-QuestProfileCombo {
    try {
        $selected = [int]$script:SelectedQuestProfileIndex
        $questProfileBox.Items.Clear()
        for ($i = 0; $i -lt $script:QuestProfiles.Count; $i++) { [void]$questProfileBox.Items.Add((Get-QuestProfileLabel $i)) }
        if ($questProfileBox.Items.Count -gt 0) { $questProfileBox.SelectedIndex = [Math]::Max(0, [Math]::Min($questProfileBox.Items.Count - 1, $selected)) }
    } catch { }
}

function Save-UserSettings {
    try {
        Save-SelectedUltimateProfileFromControls
        $combatEnabled = [ordered]@{}
        foreach ($slot in $script:CombatSlots) { $combatEnabled[$slot] = [bool](Test-CombatSlotEnabled $slot) }
        $ultimateProfiles = @()
        foreach ($profile in $script:UltimateProfiles) {
            $ultimateProfiles += [ordered]@{ name = [string]$profile.Name }
        }
        $settings = [ordered]@{
            target_title = $titleBox.Text
            monitor_index = [int]$monitorBox.SelectedIndex
            selected_slot = [string]$script:SelectedSlot
            harbor_enabled = [bool](Test-HarborEnabled)
            dungeon_routine_enabled = [ordered]@{
                harbor = [bool](Test-DungeonRoutineEnabled '허상의 정박지')
                cave = [bool](Test-DungeonRoutineEnabled '광기의 동굴')
            }
            special_enabled = [ordered]@{
                coop = [bool](Test-SpecialSlotEnabled '협동')
            }
            combat_enabled = $combatEnabled
            ultimate_profile_index = [int]$script:SelectedUltimateProfileIndex
            ultimate_profiles = $ultimateProfiles
            quest_profile_index = [int]$script:SelectedQuestProfileIndex
            top_most = [bool]$topMostCheck.Checked
            beep = [bool]$beepCheck.Checked
            full_monitor_search = [bool]$fullMonitorCheck.Checked
            minimize_on_run = [bool]$minimizeOnRunCheck.Checked
            center_before_run = [bool]$centerBeforeRunCheck.Checked
            point_check = [bool]$pointCheck.Checked
            coordinate_mode_index = [int]$coordinateModeBox.SelectedIndex
            click_mode_index = [int]$clickModeBox.SelectedIndex
            interval_ms = [int]$intervalBox.Value
            point_tolerance_px = [int]$pointToleranceBox.Value
            match_percent = [int]$matchPercentBox.Value
            color_tolerance = [int]$colorToleranceBox.Value
            retry_count = [int]$retryCountBox.Value
            retry_interval_ms = [int]$retryIntervalBox.Value
            step_delay_ms = [int]$stepDelayBox.Value
            move_settle_ms = [int]$moveSettleBox.Value
            click_hold_ms = [int]$clickHoldBox.Value
            gone_delay_ms = [int]$goneDelayBox.Value
        }
        ($settings | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $script:UserSettingsPath -Encoding UTF8
    } catch { }
}
function Set-NumericValueSafe($Control, $Value) {
    try {
        if ($null -eq $Value) { return }
        $number = [decimal]$Value
        if ($number -lt $Control.Minimum) { $number = $Control.Minimum }
        if ($number -gt $Control.Maximum) { $number = $Control.Maximum }
        $Control.Value = $number
    } catch { }
}
function Set-ComboIndexSafe($Control, $Value) {
    try {
        if ($null -eq $Value) { return }
        $index = [int]$Value
        if ($index -ge 0 -and $index -lt $Control.Items.Count) { $Control.SelectedIndex = $index }
    } catch { }
}
function Load-UserSettings {
    if (-not [System.IO.File]::Exists($script:UserSettingsPath)) { return $false }
    try {
        $settings = Get-Content -LiteralPath $script:UserSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($settings.target_title) { $titleBox.Text = [string]$settings.target_title }
        Set-ComboIndexSafe $monitorBox $settings.monitor_index
        if ($null -ne $settings.harbor_enabled) { $script:HarborEnabled = [bool]$settings.harbor_enabled }
        if ($settings.dungeon_routine_enabled) {
            $harborProp = $settings.dungeon_routine_enabled.PSObject.Properties['harbor']
            $caveProp = $settings.dungeon_routine_enabled.PSObject.Properties['cave']
            if ($null -ne $harborProp) { $script:DungeonRoutineEnabled['허상의 정박지'] = [bool]$harborProp.Value }
            if ($null -ne $caveProp) { $script:DungeonRoutineEnabled['광기의 동굴'] = [bool]$caveProp.Value }
            $script:HarborEnabled = [bool]$script:DungeonRoutineEnabled['허상의 정박지']
        } else {
            $script:DungeonRoutineEnabled['허상의 정박지'] = [bool]$script:HarborEnabled
            $script:DungeonRoutineEnabled['광기의 동굴'] = $false
        }
        if ($settings.special_enabled) {

            $coopProp = $settings.special_enabled.PSObject.Properties['coop']

            if ($null -ne $coopProp) {

                $script:SpecialSlotEnabled['협동'] = [bool]$coopProp.Value

                if ($script:SpecialSlotChecks.ContainsKey('협동')) { $script:SpecialSlotChecks['협동'].Checked = [bool]$coopProp.Value }

            }

        }

        if ($settings.combat_enabled) {

            foreach ($slot in $script:CombatSlots) {
                $prop = $settings.combat_enabled.PSObject.Properties[$slot]
                if ($null -ne $prop) { $script:CombatSlotEnabled[$slot] = [bool]$prop.Value }
            }
        }
        if ($settings.ultimate_profiles) {
            $loadedProfiles = @()
            foreach ($profile in @($settings.ultimate_profiles)) {
                $name = [string]$profile.name
                if ([string]::IsNullOrWhiteSpace($name)) { $name = '궁극기 설정 ' + ($loadedProfiles.Count + 1) }
                $loadedProfiles += [pscustomobject]@{ Name = $name }
            }
            if ($loadedProfiles.Count -gt 0) {
                while ($loadedProfiles.Count -lt 5) {
                    $loadedProfiles += [pscustomobject]@{ Name = ('궁극기 설정 ' + ($loadedProfiles.Count + 1)) }
                }
                $script:UltimateProfiles = @($loadedProfiles | Select-Object -First 5)
            }
        }
        if ($null -ne $settings.ultimate_profile_index) {
            $script:SelectedUltimateProfileIndex = [Math]::Max(0, [Math]::Min($script:UltimateProfiles.Count - 1, [int]$settings.ultimate_profile_index))
        }
        if ($null -ne $settings.quest_profile_index) {
            $script:SelectedQuestProfileIndex = [Math]::Max(0, [Math]::Min($script:QuestProfiles.Count - 1, [int]$settings.quest_profile_index))
        }
        if ($null -ne $settings.top_most) { $topMostCheck.Checked = [bool]$settings.top_most }
        if ($null -ne $settings.beep) { $beepCheck.Checked = [bool]$settings.beep }
        if ($null -ne $settings.full_monitor_search) { $fullMonitorCheck.Checked = [bool]$settings.full_monitor_search }
        if ($null -ne $settings.minimize_on_run) { $minimizeOnRunCheck.Checked = [bool]$settings.minimize_on_run }
        if ($null -ne $settings.center_before_run) { $centerBeforeRunCheck.Checked = [bool]$settings.center_before_run }
        if ($null -ne $settings.point_check) { $pointCheck.Checked = [bool]$settings.point_check }
        Set-ComboIndexSafe $coordinateModeBox $settings.coordinate_mode_index
        Set-ComboIndexSafe $clickModeBox $settings.click_mode_index
        Set-NumericValueSafe $intervalBox $settings.interval_ms
        Set-NumericValueSafe $pointToleranceBox $settings.point_tolerance_px
        Set-NumericValueSafe $matchPercentBox $settings.match_percent
        Set-NumericValueSafe $colorToleranceBox $settings.color_tolerance
        Set-NumericValueSafe $retryCountBox $settings.retry_count
        Set-NumericValueSafe $retryIntervalBox $settings.retry_interval_ms
        Set-NumericValueSafe $stepDelayBox $settings.step_delay_ms
        Set-NumericValueSafe $moveSettleBox $settings.move_settle_ms
        Set-NumericValueSafe $clickHoldBox $settings.click_hold_ms
        Set-NumericValueSafe $goneDelayBox $settings.gone_delay_ms
        if ($settings.selected_slot -and ($script:Slots -contains [string]$settings.selected_slot)) { $script:SelectedSlot = [string]$settings.selected_slot }
        return $true
    } catch { return $false }
}
function Compare-VersionString([string]$A, [string]$B) {
    try { return ([version]$A).CompareTo([version]$B) } catch { return [string]::Compare($A, $B, [StringComparison]::OrdinalIgnoreCase) }
}
function Get-UpdateManifestUrl {
    if (-not [System.IO.File]::Exists($script:UpdateManifestPath)) { return '' }
    return ([System.IO.File]::ReadAllText($script:UpdateManifestPath, [System.Text.Encoding]::UTF8)).Trim()
}
function Ensure-UpdateManifestUrlFile {
    if (-not [System.IO.File]::Exists($script:UpdateManifestPath)) {
        [System.IO.File]::WriteAllText($script:UpdateManifestPath, "GitHub version.json raw URL을 여기에 붙여넣으세요.
", [System.Text.Encoding]::UTF8)
    }
}
function Get-RemoteText([string]$Url) {
    $client = New-Object System.Net.WebClient
    $client.Headers.Add('User-Agent', 'GerinogiRoutineUpdater/' + $script:AppVersion)
    try { return $client.DownloadString($Url) } finally { $client.Dispose() }
}
function Invoke-AppInstallerUpdate($Manifest) {
    if ($script:Running) { [System.Windows.Forms.MessageBox]::Show('실행 중에는 업데이트할 수 없습니다. 먼저 중단하세요.', '업데이트') | Out-Null; return }
    $installer = $Manifest.installer
    if ($null -eq $installer -or [string]::IsNullOrWhiteSpace([string]$installer.url)) { throw 'installer.url 값이 없습니다.' }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $targetBackup = Join-Path $script:BackupDir $stamp
    New-Item -ItemType Directory -Force -Path $targetBackup | Out-Null
    $installerPath = Join-Path $targetBackup '상태루틴 설치.exe'
    $client = New-Object System.Net.WebClient
    $client.Headers.Add('User-Agent', 'GerinogiRoutineInstallerUpdater/' + $script:AppVersion)
    try {
        $client.DownloadFile([string]$installer.url, $installerPath)
    }
    finally { $client.Dispose() }
    if ($installer.sha256) {
        $hash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne ([string]$installer.sha256).ToLowerInvariant()) { throw '설치파일 해시 검증 실패' }
    }
    [System.Windows.Forms.MessageBox]::Show('이 업데이트는 설치파일로 적용됩니다.' + $script:NewLine + '프로그램을 종료하고 설치를 시작합니다.' + $script:NewLine + '기존 설정과 샘플은 유지됩니다.', '업데이트') | Out-Null
    Start-Process -FilePath $installerPath -WorkingDirectory $targetBackup
    $script:StopRequested = $true
    $form.Close()
}
function Invoke-AppUpdateCheck([bool]$Silent) {
    $url = Get-UpdateManifestUrl
    if ([string]::IsNullOrWhiteSpace($url) -or $url.StartsWith('GitHub version.json')) {
        Ensure-UpdateManifestUrlFile
        if (-not $Silent) {
            [System.Windows.Forms.MessageBox]::Show('업데이트 주소가 아직 등록되지 않았습니다.' + $script:NewLine + 'update_manifest_url.txt 파일에 GitHub version.json raw URL을 넣어주세요.', '업데이트 확인') | Out-Null
            Start-Process -FilePath $script:UpdateManifestPath
        }
        return
    }
    try {
        $manifest = (Get-RemoteText $url) | ConvertFrom-Json
        if ($null -eq $manifest.version) { throw 'version 값이 없습니다.' }
        if ((Compare-VersionString $script:AppVersion ([string]$manifest.version)) -ge 0) {
            if (-not $Silent) { [System.Windows.Forms.MessageBox]::Show('현재 최신 버전입니다. 현재 버전: ' + $script:AppVersion, '업데이트 확인') | Out-Null }
            return
        }
        $msg = '새 버전이 있습니다.' + $script:NewLine + '현재: ' + $script:AppVersion + $script:NewLine + '최신: ' + $manifest.version + $script:NewLine + '업데이트할까요?'
        if ([System.Windows.Forms.MessageBox]::Show($msg, '업데이트 확인', [System.Windows.Forms.MessageBoxButtons]::YesNo) -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        $mode = if ($manifest.update_mode) { [string]$manifest.update_mode } else { 'files' }
        if ($mode -eq 'installer') {
            Invoke-AppInstallerUpdate $manifest
        } elseif ($mode -eq 'package') {
            Invoke-AppPackageUpdate $manifest
        } else {
            Invoke-AppUpdateApply $manifest
        }
    }
    catch {
        if (-not $Silent) { [System.Windows.Forms.MessageBox]::Show('업데이트 확인 실패: ' + $_.Exception.Message, '업데이트 확인') | Out-Null }
    }
}
function Invoke-AppPackageUpdate($Manifest) {
    if ($script:Running) { [System.Windows.Forms.MessageBox]::Show('실행 중에는 업데이트할 수 없습니다. 먼저 중단하세요.', '업데이트') | Out-Null; return }
    $package = $Manifest.package
    if ($null -eq $package -or [string]::IsNullOrWhiteSpace([string]$package.url)) { throw 'package.url 값이 없습니다.' }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $targetBackup = Join-Path $script:BackupDir $stamp
    New-Item -ItemType Directory -Force -Path $targetBackup | Out-Null
    $manifestPath = Join-Path $targetBackup 'manifest.json'
    $workerPath = Join-Path $targetBackup 'package_update_worker.ps1'
    $restartPath = Join-Path $PSScriptRoot '상태루틴 실행.vbs'
    if (-not [System.IO.File]::Exists($restartPath)) { $restartPath = Join-Path $PSScriptRoot '상태루틴 실행.bat' }
    ($Manifest | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    $worker = @'
param(
    [string]$Root,
    [string]$ManifestPath,
    [string]$BackupRoot,
    [int]$ParentPid,
    [string]$RestartPath
)
$ErrorActionPreference = 'Stop'
function Write-WorkerLog([string]$Message) {
    $line = (Get-Date).ToString('s') + ' ' + $Message
    Add-Content -LiteralPath (Join-Path $BackupRoot 'update_worker.log') -Value $line -Encoding UTF8
}
function Add-DownloadCacheBuster([string]$Url, [string]$Hash) {
    if ([string]::IsNullOrWhiteSpace($Url)) { return $Url }
    $token = if ([string]::IsNullOrWhiteSpace($Hash)) { [guid]::NewGuid().ToString('N') } else { $Hash }
    $separator = if ($Url.Contains('?')) { '&' } else { '?' }
    return ($Url + $separator + 'cache_bust=' + [System.Uri]::EscapeDataString($token))
}
function Start-RoutineAgain([string]$RestartPath, [string]$Root) {
    if (-not [string]::IsNullOrWhiteSpace($RestartPath) -and [System.IO.File]::Exists($RestartPath)) {
        $ext = [System.IO.Path]::GetExtension($RestartPath).ToLowerInvariant()
        if ($ext -eq '.vbs') {
            Start-Process -FilePath 'wscript.exe' -ArgumentList ('"' + $RestartPath + '"') -WorkingDirectory $Root
        } else {
            Start-Process -FilePath $RestartPath -WorkingDirectory $Root
        }
        return
    }
    $scriptPath = Join-Path $Root 'local_state_routine_runner.ps1'
    if ([System.IO.File]::Exists($scriptPath)) {
        $args = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $scriptPath + '"'
        Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WorkingDirectory $Root -Verb RunAs
    }
}
function Copy-PackageDirectory([string]$Source, [string]$Destination, [string]$BackupRoot) {
    foreach ($dir in Get-ChildItem -LiteralPath $Source -Directory -Recurse) {
        $relative = $dir.FullName.Substring($Source.Length).TrimStart('\','/')
        New-Item -ItemType Directory -Force -Path (Join-Path $Destination $relative) | Out-Null
    }
    foreach ($file in Get-ChildItem -LiteralPath $Source -File -Recurse) {
        $relative = $file.FullName.Substring($Source.Length).TrimStart('\','/')
        if ($relative -match '(^|\\)(slot_points|slot_regions|ignore_zones|local_state_routine_log|routine_trace_log|click_trace_log)\\.csv$') { continue }
        if ($relative -match '(^|\\)user_settings\\.json$') { continue }
        $target = Join-Path $Destination $relative
        if ($relative -match '^state_samples\\' -and [System.IO.File]::Exists($target)) { continue }
        New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($target)) | Out-Null
        if ([System.IO.File]::Exists($target)) {
            $backupPath = Join-Path $BackupRoot $relative
            New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($backupPath)) | Out-Null
            Copy-Item -LiteralPath $target -Destination $backupPath -Force
        }
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    }
}
try {
    Write-WorkerLog 'waiting parent process'
    if ($ParentPid -gt 0) {
        try { Wait-Process -Id $ParentPid -Timeout 20 -ErrorAction SilentlyContinue } catch { }
    }
    Start-Sleep -Milliseconds 800
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $manifest.package) { throw 'package 정보가 없습니다.' }
    $packageUrl = [string]$manifest.package.url
    $expectedHash = if ($manifest.package.sha256) { ([string]$manifest.package.sha256).ToLowerInvariant() } else { '' }
    $packagePath = Join-Path $BackupRoot 'update_package.zip'
    $extractRoot = Join-Path $BackupRoot 'package_extract'
    $client = New-Object System.Net.WebClient
    $client.Headers.Add('User-Agent', 'GerinogiRoutinePackageUpdater')
    try {
        Write-WorkerLog 'download package'
        $client.DownloadFile((Add-DownloadCacheBuster $packageUrl $expectedHash), $packagePath)
    }
    finally { $client.Dispose() }
    if (-not [string]::IsNullOrWhiteSpace($expectedHash)) {
        $hash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $expectedHash) {
            Write-WorkerLog ('package hash mismatch expected=' + $expectedHash + ' actual=' + $hash)
            throw '패키지 해시 검증 실패'
        }
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($packagePath, $extractRoot)
    $releaseRoot = Join-Path $extractRoot 'release'
    if (-not [System.IO.Directory]::Exists($releaseRoot)) {
        if ([System.IO.File]::Exists((Join-Path $extractRoot 'local_state_routine_runner.ps1'))) {
            $releaseRoot = $extractRoot
        } else {
            throw '패키지 안에 release 폴더가 없습니다.'
        }
    }
    Copy-PackageDirectory $releaseRoot $Root $BackupRoot
    Write-WorkerLog 'package update complete'
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show('패치가 완료되었습니다.' + [Environment]::NewLine + '새 버전으로 다시 실행합니다.', '업데이트') | Out-Null
    Start-RoutineAgain $RestartPath $Root
}
catch {
    Write-WorkerLog ('failed: ' + $_.Exception.Message)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show('업데이트 실패: ' + $_.Exception.Message + [Environment]::NewLine + '로그: ' + (Join-Path $BackupRoot 'update_worker.log'), '업데이트') | Out-Null
    Start-RoutineAgain $RestartPath $Root
}
'@
    Set-Content -LiteralPath $workerPath -Value $worker -Encoding UTF8
    [System.Windows.Forms.MessageBox]::Show('업데이트 패키지를 적용하기 위해 프로그램을 종료합니다.' + $script:NewLine + '잠시 후 자동으로 다시 실행됩니다.', '업데이트') | Out-Null
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File', $workerPath, '-Root', $PSScriptRoot, '-ManifestPath', $manifestPath, '-BackupRoot', $targetBackup, '-ParentPid', ([System.Diagnostics.Process]::GetCurrentProcess().Id), '-RestartPath', $restartPath) -WindowStyle Hidden
    $script:StopRequested = $true
    $form.Close()
}
function Invoke-AppUpdateApply($Manifest) {
    if ($script:Running) { [System.Windows.Forms.MessageBox]::Show('실행 중에는 업데이트할 수 없습니다. 먼저 중단하세요.', '업데이트') | Out-Null; return }
    if ($null -eq $Manifest.files) { throw 'files 목록이 없습니다.' }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $targetBackup = Join-Path $script:BackupDir $stamp
    New-Item -ItemType Directory -Force -Path $targetBackup | Out-Null
    $manifestPath = Join-Path $targetBackup 'manifest.json'
    $workerPath = Join-Path $targetBackup 'update_worker.ps1'
    $restartPath = Join-Path $PSScriptRoot '상태루틴 실행.vbs'
    if (-not [System.IO.File]::Exists($restartPath)) { $restartPath = Join-Path $PSScriptRoot '상태루틴 실행.bat' }
    ($Manifest | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    $worker = @'
param(
    [string]$Root,
    [string]$ManifestPath,
    [string]$BackupRoot,
    [int]$ParentPid,
    [string]$RestartPath
)
$ErrorActionPreference = 'Stop'
function Write-WorkerLog([string]$Message) {
    $line = (Get-Date).ToString('s') + ' ' + $Message
    Add-Content -LiteralPath (Join-Path $BackupRoot 'update_worker.log') -Value $line -Encoding UTF8
}
function Add-DownloadCacheBuster([string]$Url, [string]$Hash) {
    if ([string]::IsNullOrWhiteSpace($Url)) { return $Url }
    $token = if ([string]::IsNullOrWhiteSpace($Hash)) { [guid]::NewGuid().ToString('N') } else { $Hash }
    $separator = if ($Url.Contains('?')) { '&' } else { '?' }
    return ($Url + $separator + 'cache_bust=' + [System.Uri]::EscapeDataString($token))
}
function Start-RoutineAgain([string]$RestartPath, [string]$Root) {
    if (-not [string]::IsNullOrWhiteSpace($RestartPath) -and [System.IO.File]::Exists($RestartPath)) {
        $ext = [System.IO.Path]::GetExtension($RestartPath).ToLowerInvariant()
        if ($ext -eq '.vbs') {
            Start-Process -FilePath 'wscript.exe' -ArgumentList ('"' + $RestartPath + '"') -WorkingDirectory $Root
        } else {
            Start-Process -FilePath $RestartPath -WorkingDirectory $Root
        }
        return
    }
    $scriptPath = Join-Path $Root 'local_state_routine_runner.ps1'
    if ([System.IO.File]::Exists($scriptPath)) {
        $args = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $scriptPath + '"'
        Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WorkingDirectory $Root -Verb RunAs
    }
}
try {
    Write-WorkerLog 'waiting parent process'
    if ($ParentPid -gt 0) {
        try { Wait-Process -Id $ParentPid -Timeout 20 -ErrorAction SilentlyContinue } catch { }
    }
    Start-Sleep -Milliseconds 800
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $manifest.files) { throw 'files 목록이 없습니다.' }
    $client = New-Object System.Net.WebClient
    $client.Headers.Add('User-Agent', 'GerinogiRoutineExternalUpdater')
    try {
        foreach ($file in $manifest.files) {
            $rel = [string]$file.path
            $src = [string]$file.url
            if ([string]::IsNullOrWhiteSpace($rel) -or [string]::IsNullOrWhiteSpace($src)) { continue }
            if ($rel.Contains('..') -or [System.IO.Path]::IsPathRooted($rel)) { throw '허용되지 않는 파일 경로: ' + $rel }
            $dest = Join-Path $Root $rel
            $destFull = [System.IO.Path]::GetFullPath($dest)
            $rootFull = [System.IO.Path]::GetFullPath($Root)
            if (-not $destFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) { throw '허용되지 않는 대상 경로: ' + $rel }
            $tmp = $destFull + '.download'
            New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($destFull)) | Out-Null
            $expectedHash = if ($file.sha256) { ([string]$file.sha256).ToLowerInvariant() } else { '' }
            $downloadUrl = Add-DownloadCacheBuster $src $expectedHash
            Write-WorkerLog ('download ' + $rel)
            $client.DownloadFile($downloadUrl, $tmp)
            if ($file.sha256) {
                $hash = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($hash -ne $expectedHash) {
                    Write-WorkerLog ('hash mismatch ' + $rel + ' expected=' + $expectedHash + ' actual=' + $hash)
                    Remove-Item -LiteralPath $tmp -Force
                    throw '해시 검증 실패: ' + $rel
                }
            }
            if ([System.IO.File]::Exists($destFull)) {
                $backupPath = Join-Path $BackupRoot $rel
                New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($backupPath)) | Out-Null
                Copy-Item -LiteralPath $destFull -Destination $backupPath -Force
            }
            Move-Item -LiteralPath $tmp -Destination $destFull -Force
        }
    }
    finally { $client.Dispose() }
    Write-WorkerLog 'update complete'
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show('패치가 완료되었습니다.' + [Environment]::NewLine + '새 버전으로 다시 실행합니다.', '업데이트') | Out-Null
    Start-RoutineAgain $RestartPath $Root
}
catch {
    Write-WorkerLog ('failed: ' + $_.Exception.Message)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show('업데이트 실패: ' + $_.Exception.Message + [Environment]::NewLine + '로그: ' + (Join-Path $BackupRoot 'update_worker.log'), '업데이트') | Out-Null
    Start-RoutineAgain $RestartPath $Root
}
'@
    Set-Content -LiteralPath $workerPath -Value $worker -Encoding UTF8
    [System.Windows.Forms.MessageBox]::Show('업데이트를 위해 프로그램을 종료합니다.' + $script:NewLine + '잠시 후 자동으로 다시 실행됩니다.', '업데이트') | Out-Null
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File', $workerPath, '-Root', $PSScriptRoot, '-ManifestPath', $manifestPath, '-BackupRoot', $targetBackup, '-ParentPid', ([System.Diagnostics.Process]::GetCurrentProcess().Id), '-RestartPath', $restartPath) -WindowStyle Hidden
    $script:StopRequested = $true
    $form.Close()
}
$form = New-Object System.Windows.Forms.Form
$uiFontName = [string](Get-UiValue 'app.fontName' 'Malgun Gothic')
$uiFontSize = [float](Get-UiValue 'app.fontSize' 8)
$uiBackground = Get-UiColor 'colors.background' ([System.Drawing.Color]::FromArgb(125,211,185))
$form.Text = [string](Get-UiValue 'app.title' 'Gerinogi Mask Routine Runner')
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size((Get-UiInt 'window.width' 460), (Get-UiInt 'window.height' 920))
$form.MinimumSize = New-Object System.Drawing.Size((Get-UiInt 'window.minWidth' 420), (Get-UiInt 'window.minHeight' 760))
$form.Font = New-Object System.Drawing.Font($uiFontName, $uiFontSize)
$form.TopMost = Get-UiBool 'app.topMost' $true
$tabs = New-Object System.Windows.Forms.TabControl; $tabs.Dock = 'Fill'; $tabs.Appearance = 'Normal'
$gamePage = New-Object System.Windows.Forms.TabPage; $gamePage.Text = [string](Get-UiValue 'tabs.main' '자동 인식'); $gamePage.Padding = New-Object System.Windows.Forms.Padding(8); $gamePage.BackColor = $uiBackground
$optionPage = New-Object System.Windows.Forms.TabPage; $optionPage.Text = [string](Get-UiValue 'tabs.options' '설정'); $optionPage.Padding = New-Object System.Windows.Forms.Padding(8)
[void]$tabs.TabPages.Add($gamePage); [void]$tabs.TabPages.Add($optionPage); $form.Controls.Add($tabs)

$gameTable = New-Object System.Windows.Forms.TableLayoutPanel; $gameTable.Dock = 'Fill'; $gameTable.ColumnCount = 1; $gameTable.RowCount = 8; $gameTable.Padding = New-Object System.Windows.Forms.Padding(0); $gameTable.BackColor = $uiBackground
foreach ($style in @(
    (New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 118)),
    (New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 48)),
    (New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 430)),
    (New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 164)),
    (New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)),
    (New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 52)),
    (New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)),
    (New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))) { $gameTable.RowStyles.Add($style) | Out-Null }
$gamePage.Controls.Add($gameTable)

$targetGroup = New-Object System.Windows.Forms.GroupBox; $targetGroup.Text = [string](Get-UiValue 'labels.targetGroup' '대상'); $targetGroup.Dock = 'Fill'; $targetGroup.Padding = New-Object System.Windows.Forms.Padding(8)
$targetTable = New-Object System.Windows.Forms.TableLayoutPanel; $targetTable.Dock = 'Fill'; $targetTable.ColumnCount = 2; $targetTable.RowCount = 2
$targetTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 82))) | Out-Null
$targetTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$targetTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50))) | Out-Null
$targetTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50))) | Out-Null
$targetGroup.Controls.Add($targetTable); $gameTable.Controls.Add($targetGroup, 0, 0)
$targetTitleLabel = New-Object System.Windows.Forms.Label; $targetTitleLabel.Text = [string](Get-UiValue 'labels.targetWindow' '대상 창'); $targetTitleLabel.Dock = 'Fill'; $targetTitleLabel.TextAlign = 'MiddleLeft'; $targetTable.Controls.Add($targetTitleLabel, 0, 0)
$titlePanel = New-Object System.Windows.Forms.TableLayoutPanel; $titlePanel.Dock = 'Fill'; $titlePanel.ColumnCount = 3
$titlePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 42))) | Out-Null
$titlePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 42))) | Out-Null
$titlePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 72))) | Out-Null
$titleBox = New-Object System.Windows.Forms.TextBox; $titleBox.Dock = 'Fill'
$windowBox = New-Object System.Windows.Forms.ComboBox; $windowBox.DropDownStyle = 'DropDownList'; $windowBox.Dock = 'Fill'
$refreshWindowsButton = New-Object System.Windows.Forms.Button; $refreshWindowsButton.Text = [string](Get-UiValue 'buttons.searchWindows' '검색'); $refreshWindowsButton.Dock = 'Fill'
$titlePanel.Controls.Add($titleBox, 0, 0); $titlePanel.Controls.Add($windowBox, 1, 0); $titlePanel.Controls.Add($refreshWindowsButton, 2, 0); $targetTable.Controls.Add($titlePanel, 1, 0)
$monitorLabel = New-Object System.Windows.Forms.Label; $monitorLabel.Text = [string](Get-UiValue 'labels.monitor' '모니터'); $monitorLabel.Dock = 'Fill'; $monitorLabel.TextAlign = 'MiddleLeft'; $targetTable.Controls.Add($monitorLabel, 0, 1)
$monitorBox = New-Object System.Windows.Forms.ComboBox; $monitorBox.DropDownStyle = 'DropDownList'; $monitorBox.Dock = 'Fill'
$screens = [System.Windows.Forms.Screen]::AllScreens
for ($i = 0; $i -lt $screens.Count; $i++) { $b = $screens[$i].Bounds; [void]$monitorBox.Items.Add(('Monitor {0} ({1},{2} - {3},{4})' -f ($i + 1), $b.Left, $b.Top, $b.Right, $b.Bottom)) }
if ($monitorBox.Items.Count -gt 0) { $monitorBox.SelectedIndex = 0 }
$targetTable.Controls.Add($monitorBox, 1, 1)

$slotSelectGroup = New-Object System.Windows.Forms.GroupBox; $slotSelectGroup.Text = '퀘스트 설정'; $slotSelectGroup.Dock = 'Fill'; $slotSelectGroup.Padding = New-Object System.Windows.Forms.Padding(8,4,8,4)
$slotBox = New-Object System.Windows.Forms.ComboBox; $slotBox.DropDownStyle = 'DropDownList'; $slotBox.Dock = 'Fill'
foreach ($slot in $script:Slots) { [void]$slotBox.Items.Add($slot) }; $slotBox.SelectedIndex = 0
$questProfileBox = New-Object System.Windows.Forms.ComboBox; $questProfileBox.DropDownStyle = 'DropDownList'; $questProfileBox.Dock = 'Fill'; $questProfileBox.Font = New-Object System.Drawing.Font($uiFontName, 8)
$slotSelectGroup.Controls.Add($questProfileBox); $slotSelectGroup.Visible = $false; $gameTable.Controls.Add($slotSelectGroup, 0, 1)

$slotPreviewGroup = New-Object System.Windows.Forms.GroupBox; $slotPreviewGroup.Text = '슬롯 분류'; $slotPreviewGroup.Dock = 'Fill'; $slotPreviewGroup.Padding = New-Object System.Windows.Forms.Padding(6)
$slotPreviewTable = New-Object System.Windows.Forms.TableLayoutPanel; $slotPreviewTable.Dock = 'Fill'; $slotPreviewTable.ColumnCount = 1; $slotPreviewTable.RowCount = 5
$slotPreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 26))) | Out-Null
$slotPreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 78))) | Out-Null
$slotPreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 118))) | Out-Null
$slotPreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 118))) | Out-Null
$slotPreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 150))) | Out-Null
$slotPreviewToggleButton = New-Object System.Windows.Forms.Button; $slotPreviewToggleButton.Text = '접기'; $slotPreviewToggleButton.Dock = 'Right'; $slotPreviewToggleButton.Width = 66

$specialPreviewGroup = New-Object System.Windows.Forms.GroupBox; $specialPreviewGroup.Text = [string](Get-UiValue 'labels.specialSlotPreview' '특수 카테고리'); $specialPreviewGroup.Dock = 'Fill'; $specialPreviewGroup.Padding = New-Object System.Windows.Forms.Padding(5)
$specialPreviewTable = New-Object System.Windows.Forms.TableLayoutPanel; $specialPreviewTable.Dock = 'Fill'; $specialPreviewTable.ColumnCount = 1; $specialPreviewTable.RowCount = 2
$specialPreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 22))) | Out-Null
$specialPreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$specialEnabledCheck = New-Object System.Windows.Forms.CheckBox; $specialEnabledCheck.Text = '협동 ON'; $specialEnabledCheck.Checked = $true; $specialEnabledCheck.Dock = 'Left'
$script:SpecialSlotChecks['협동'] = $specialEnabledCheck
$specialSlotPanel = New-Object System.Windows.Forms.TableLayoutPanel; $specialSlotPanel.Dock = 'Fill'; $specialSlotPanel.ColumnCount = 1; $specialSlotPanel.RowCount = 1; $specialSlotPanel.AutoScroll = $false; $specialSlotPanel.Padding = New-Object System.Windows.Forms.Padding(0)
$specialSlotPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$specialSlotPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$specialPreviewTable.Controls.Add($specialEnabledCheck, 0, 0)
$specialPreviewTable.Controls.Add($specialSlotPanel, 0, 1)
$specialPreviewGroup.Controls.Add($specialPreviewTable)

$routePreviewGroup = New-Object System.Windows.Forms.GroupBox; $routePreviewGroup.Text = '던전 루틴'; $routePreviewGroup.Dock = 'Fill'; $routePreviewGroup.Padding = New-Object System.Windows.Forms.Padding(5)
$routePreviewTable = New-Object System.Windows.Forms.TableLayoutPanel; $routePreviewTable.Dock = 'Fill'; $routePreviewTable.ColumnCount = 1; $routePreviewTable.RowCount = 2
$routePreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 22))) | Out-Null
$routePreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$routeTogglePanel = New-Object System.Windows.Forms.TableLayoutPanel; $routeTogglePanel.Dock = 'Fill'; $routeTogglePanel.ColumnCount = 2; $routeTogglePanel.RowCount = 1
$routeTogglePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50))) | Out-Null
$routeTogglePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50))) | Out-Null
$harborEnabledCheck = New-Object System.Windows.Forms.CheckBox; $harborEnabledCheck.Text = '허상의 정박지 ON'; $harborEnabledCheck.Checked = $true; $harborEnabledCheck.Dock = 'Fill'; $harborEnabledCheck.Font = New-Object System.Drawing.Font($uiFontName, 7)
$caveEnabledCheck = New-Object System.Windows.Forms.CheckBox; $caveEnabledCheck.Text = '광기의 동굴 ON'; $caveEnabledCheck.Checked = $false; $caveEnabledCheck.Dock = 'Fill'; $caveEnabledCheck.Font = New-Object System.Drawing.Font($uiFontName, 7)
$routeTogglePanel.Controls.Add($harborEnabledCheck, 0, 0)
$routeTogglePanel.Controls.Add($caveEnabledCheck, 1, 0)
$routeSlotPanel = New-Object System.Windows.Forms.TableLayoutPanel; $routeSlotPanel.Dock = 'Fill'; $routeSlotPanel.ColumnCount = 7; $routeSlotPanel.RowCount = 1; $routeSlotPanel.AutoScroll = $false; $routeSlotPanel.Padding = New-Object System.Windows.Forms.Padding(0)
for ($si = 0; $si -lt 7; $si++) { $routeSlotPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 14.28))) | Out-Null }
$routeSlotPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$routePreviewTable.Controls.Add($routeTogglePanel, 0, 0)
$routePreviewTable.Controls.Add($routeSlotPanel, 0, 1)
$routePreviewGroup.Controls.Add($routePreviewTable)
$cavePreviewGroup = New-Object System.Windows.Forms.GroupBox; $cavePreviewGroup.Text = '광기의 동굴'; $cavePreviewGroup.Dock = 'Fill'; $cavePreviewGroup.Padding = New-Object System.Windows.Forms.Padding(5)
$cavePreviewTable = New-Object System.Windows.Forms.TableLayoutPanel; $cavePreviewTable.Dock = 'Fill'; $cavePreviewTable.ColumnCount = 1; $cavePreviewTable.RowCount = 2
$cavePreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 22))) | Out-Null
$cavePreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$caveTogglePanel = New-Object System.Windows.Forms.TableLayoutPanel; $caveTogglePanel.Dock = 'Fill'; $caveTogglePanel.ColumnCount = 2; $caveTogglePanel.RowCount = 1
$caveTogglePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50))) | Out-Null
$caveTogglePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50))) | Out-Null
$caveToggleSpacer = New-Object System.Windows.Forms.Label; $caveToggleSpacer.Text = ''; $caveToggleSpacer.Dock = 'Fill'
$caveTogglePanel.Controls.Add($caveEnabledCheck, 0, 0)
$caveTogglePanel.Controls.Add($caveToggleSpacer, 1, 0)
$caveSlotPanel = New-Object System.Windows.Forms.TableLayoutPanel; $caveSlotPanel.Dock = 'Fill'; $caveSlotPanel.ColumnCount = 7; $caveSlotPanel.RowCount = 1; $caveSlotPanel.AutoScroll = $false; $caveSlotPanel.Padding = New-Object System.Windows.Forms.Padding(0)
for ($si = 0; $si -lt 7; $si++) { $caveSlotPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 14.28))) | Out-Null }
$caveSlotPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$cavePreviewTable.Controls.Add($caveTogglePanel, 0, 0)
$cavePreviewTable.Controls.Add($caveSlotPanel, 0, 1)
$cavePreviewGroup.Controls.Add($cavePreviewTable)

$combatPreviewGroup = New-Object System.Windows.Forms.GroupBox; $combatPreviewGroup.Text = [string](Get-UiValue 'labels.combatSlotPreview' '전투관련 슬롯 미리보기'); $combatPreviewGroup.Dock = 'Fill'; $combatPreviewGroup.Padding = New-Object System.Windows.Forms.Padding(5)
$combatPreviewTable = New-Object System.Windows.Forms.TableLayoutPanel; $combatPreviewTable.Dock = 'Fill'; $combatPreviewTable.ColumnCount = 1; $combatPreviewTable.RowCount = 3
$combatPreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24))) | Out-Null
$combatPreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24))) | Out-Null
$combatPreviewTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$combatTogglePanel = New-Object System.Windows.Forms.TableLayoutPanel; $combatTogglePanel.Dock = 'Fill'; $combatTogglePanel.ColumnCount = 5; $combatTogglePanel.RowCount = 1
for ($si = 0; $si -lt 5; $si++) { $combatTogglePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 20))) | Out-Null }
$script:CombatSlotChecks = @{}
$combatToggleIndex = 0
foreach ($slot in $script:CombatSlots) {
    $check = New-Object System.Windows.Forms.CheckBox
    $check.Text = $slot
    $check.Checked = $true
    $check.Dock = 'Fill'
    $check.Font = New-Object System.Drawing.Font($uiFontName, 7)
    $script:CombatSlotChecks[$slot] = $check
    $combatTogglePanel.Controls.Add($check, $combatToggleIndex, 0)
    $combatToggleIndex++
}
$combatSlotPanel = New-Object System.Windows.Forms.TableLayoutPanel; $combatSlotPanel.Dock = 'Fill'; $combatSlotPanel.ColumnCount = 5; $combatSlotPanel.RowCount = 1; $combatSlotPanel.AutoScroll = $false; $combatSlotPanel.Padding = New-Object System.Windows.Forms.Padding(0)
for ($si = 0; $si -lt 5; $si++) { $combatSlotPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 20))) | Out-Null }
$combatSlotPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$ultimateProfilePanel = New-Object System.Windows.Forms.TableLayoutPanel; $ultimateProfilePanel.Dock = 'Fill'; $ultimateProfilePanel.ColumnCount = 2; $ultimateProfilePanel.RowCount = 1
$ultimateProfilePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 78))) | Out-Null
$ultimateProfilePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$ultimateProfileLabel = New-Object System.Windows.Forms.Label; $ultimateProfileLabel.Text = '궁극기 설정'; $ultimateProfileLabel.Dock = 'Fill'; $ultimateProfileLabel.TextAlign = 'MiddleLeft'; $ultimateProfileLabel.Font = New-Object System.Drawing.Font($uiFontName, 7, [System.Drawing.FontStyle]::Bold)
$ultimateProfileBox = New-Object System.Windows.Forms.ComboBox; $ultimateProfileBox.DropDownStyle = 'DropDownList'; $ultimateProfileBox.Dock = 'Fill'; $ultimateProfileBox.Font = New-Object System.Drawing.Font($uiFontName, 7)
$ultimateProfilePanel.Controls.Add($ultimateProfileLabel, 0, 0)
$ultimateProfilePanel.Controls.Add($ultimateProfileBox, 1, 0)
$combatPreviewTable.Controls.Add($combatTogglePanel, 0, 0)
$combatPreviewTable.Controls.Add($ultimateProfilePanel, 0, 1)
$combatPreviewTable.Controls.Add($combatSlotPanel, 0, 2)
$combatPreviewGroup.Controls.Add($combatPreviewTable)

$slotPreviewTable.Controls.Add($slotPreviewToggleButton, 0, 0)
$slotPreviewTable.Controls.Add($specialPreviewGroup, 0, 1)
$slotPreviewTable.Controls.Add($routePreviewGroup, 0, 2)
$slotPreviewTable.Controls.Add($cavePreviewGroup, 0, 3)
$slotPreviewTable.Controls.Add($combatPreviewGroup, 0, 4)
$slotPreviewTable.Dock = 'Top'
$slotPreviewTable.AutoSize = $true
$slotPreviewTable.AutoSizeMode = 'GrowAndShrink'
$slotPreviewScrollPanel = New-Object System.Windows.Forms.Panel
$slotPreviewScrollPanel.Dock = 'Fill'
$slotPreviewScrollPanel.AutoScroll = $true
$slotPreviewScrollPanel.Controls.Add($slotPreviewTable)
$slotPreviewGroup.Controls.Add($slotPreviewScrollPanel); $gameTable.Controls.Add($slotPreviewGroup, 0, 2)

$buttonPanel = New-Object System.Windows.Forms.TableLayoutPanel; $buttonPanel.Dock = 'Fill'; $buttonPanel.ColumnCount = 4; $buttonPanel.RowCount = 4
$buttonPanel.Padding = New-Object System.Windows.Forms.Padding(0,2,0,2)
for ($bi = 0; $bi -lt 4; $bi++) { $buttonPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25))) | Out-Null }
$buttonPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34))) | Out-Null
$buttonPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34))) | Out-Null
$buttonPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28))) | Out-Null
$buttonPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 0))) | Out-Null
function Set-ActionButtonStyle([System.Windows.Forms.Button]$Button, [System.Drawing.Color]$BackColor) {
    $Button.Dock = 'Fill'
    $Button.Margin = New-Object System.Windows.Forms.Padding(3)
    $Button.FlatStyle = 'Flat'
    $Button.FlatAppearance.BorderColor = Get-UiColor 'colors.actionBorder' ([System.Drawing.Color]::FromArgb(170,122,24))
    $Button.BackColor = $BackColor
    $Button.ForeColor = Get-UiColor 'colors.actionText' ([System.Drawing.Color]::FromArgb(30,30,30))
    $Button.Font = New-Object System.Drawing.Font($uiFontName, 8, [System.Drawing.FontStyle]::Bold)
}
$primaryColor = Get-UiColor 'colors.actionPrimary' ([System.Drawing.Color]::FromArgb(255,221,87))
$secondaryColor = Get-UiColor 'colors.actionSecondary' ([System.Drawing.Color]::FromArgb(245,190,65))
$thirdColor = Get-UiColor 'colors.actionTertiary' ([System.Drawing.Color]::FromArgb(238,139,48))
$addButton = New-Object System.Windows.Forms.Button; $addButton.Text = [string](Get-UiValue 'buttons.capture' '영역(Shift+F8)'); Set-ActionButtonStyle $addButton $primaryColor
$pointButton = New-Object System.Windows.Forms.Button; $pointButton.Text = [string](Get-UiValue 'buttons.point' '촬영(Shift+F7)'); Set-ActionButtonStyle $pointButton $primaryColor
$startButton = New-Object System.Windows.Forms.Button; $startButton.Text = [string](Get-UiValue 'buttons.start' '시작(Shift+F5)'); Set-ActionButtonStyle $startButton $primaryColor
$stopButton = New-Object System.Windows.Forms.Button; $stopButton.Text = [string](Get-UiValue 'buttons.stop' '중단(Shift+F6)'); Set-ActionButtonStyle $stopButton $primaryColor
$fileButton = New-Object System.Windows.Forms.Button; $fileButton.Text = [string](Get-UiValue 'buttons.file' '파일'); Set-ActionButtonStyle $fileButton $secondaryColor
$reloadButton = New-Object System.Windows.Forms.Button; $reloadButton.Text = [string](Get-UiValue 'buttons.folder' '폴더'); Set-ActionButtonStyle $reloadButton $secondaryColor
$deleteButton = New-Object System.Windows.Forms.Button; $deleteButton.Text = [string](Get-UiValue 'buttons.delete' '삭제'); Set-ActionButtonStyle $deleteButton $secondaryColor
$locateButton = New-Object System.Windows.Forms.Button; $locateButton.Text = [string](Get-UiValue 'buttons.locate' '위치'); Set-ActionButtonStyle $locateButton $secondaryColor
$probeButton = New-Object System.Windows.Forms.Button; $probeButton.Text = [string](Get-UiValue 'buttons.probe' '클릭확인'); Set-ActionButtonStyle $probeButton $thirdColor
$diagnosticButton = New-Object System.Windows.Forms.Button; $diagnosticButton.Text = [string](Get-UiValue 'buttons.diagnostic' '진단'); Set-ActionButtonStyle $diagnosticButton $thirdColor
$reportButton = New-Object System.Windows.Forms.Button; $reportButton.Text = [string](Get-UiValue 'buttons.report' '문제보고'); Set-ActionButtonStyle $reportButton $thirdColor
$logButton = New-Object System.Windows.Forms.Button; $logButton.Text = [string](Get-UiValue 'buttons.log' '로그'); Set-ActionButtonStyle $logButton $thirdColor
$exitButton = New-Object System.Windows.Forms.Button; $exitButton.Text = [string](Get-UiValue 'buttons.exit' '종료'); Set-ActionButtonStyle $exitButton $thirdColor
$showIgnoreButton = New-Object System.Windows.Forms.Button; $showIgnoreButton.Text = '자동제외 확인'; Set-ActionButtonStyle $showIgnoreButton $thirdColor
$advancedToggleButton = New-Object System.Windows.Forms.Button; $advancedToggleButton.Text = '고급 도구 열기'; Set-ActionButtonStyle $advancedToggleButton ([System.Drawing.Color]::FromArgb(232,232,232))
$advancedPanel = New-Object System.Windows.Forms.TableLayoutPanel; $advancedPanel.Dock = 'Fill'; $advancedPanel.ColumnCount = 4; $advancedPanel.RowCount = 2; $advancedPanel.Visible = $false
for ($ai = 0; $ai -lt 4; $ai++) { $advancedPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25))) | Out-Null }
for ($ar = 0; $ar -lt 2; $ar++) { $advancedPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50))) | Out-Null }
$buttonPanel.Controls.Add($addButton,0,0); $buttonPanel.Controls.Add($pointButton,1,0); $buttonPanel.Controls.Add($startButton,2,0); $buttonPanel.Controls.Add($stopButton,3,0)
$buttonPanel.Controls.Add($reportButton,0,1); $buttonPanel.Controls.Add($showIgnoreButton,1,1); $buttonPanel.Controls.Add($logButton,2,1); $buttonPanel.Controls.Add($exitButton,3,1)
$buttonPanel.Controls.Add($advancedToggleButton,0,2); $buttonPanel.SetColumnSpan($advancedToggleButton,4)
$advancedPanel.Controls.Add($fileButton,0,0); $advancedPanel.Controls.Add($reloadButton,1,0); $advancedPanel.Controls.Add($deleteButton,2,0); $advancedPanel.Controls.Add($locateButton,3,0)
$advancedPanel.Controls.Add($probeButton,0,1); $advancedPanel.Controls.Add($diagnosticButton,1,1)
$buttonPanel.Controls.Add($advancedPanel,0,3); $buttonPanel.SetColumnSpan($advancedPanel,4)
$gameTable.Controls.Add($buttonPanel, 0, 3)
$updatePanel = New-Object System.Windows.Forms.TableLayoutPanel; $updatePanel.Dock = 'Fill'; $updatePanel.ColumnCount = 2; $updatePanel.RowCount = 1
$updatePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$updatePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 130))) | Out-Null
$versionLabel = New-Object System.Windows.Forms.Label; $versionLabel.Text = [string](Get-UiValue 'app.versionPrefix' '현버전 ') + $script:AppVersion; $versionLabel.Dock = 'Fill'; $versionLabel.TextAlign = 'MiddleRight'; $versionLabel.ForeColor = Get-UiColor 'colors.versionText' ([System.Drawing.Color]::FromArgb(35,55,65)); $versionLabel.Font = New-Object System.Drawing.Font($uiFontName, 8, [System.Drawing.FontStyle]::Bold); $versionLabel.Padding = New-Object System.Windows.Forms.Padding(0,0,8,0)
$updateButton = New-Object System.Windows.Forms.Button; $updateButton.Text = [string](Get-UiValue 'buttons.update' '업데이트 확인'); $updateButton.Dock = 'Fill'; $updateButton.Margin = New-Object System.Windows.Forms.Padding(3); $updateButton.FlatStyle = 'Flat'; $updateButton.BackColor = Get-UiColor 'colors.updateButton' ([System.Drawing.Color]::FromArgb(54,91,109)); $updateButton.ForeColor = [System.Drawing.Color]::White; $updateButton.Font = New-Object System.Drawing.Font($uiFontName, 8, [System.Drawing.FontStyle]::Bold)
$updatePanel.Controls.Add($versionLabel, 0, 0)
$updatePanel.Controls.Add($updateButton, 1, 0)
$gameTable.Controls.Add($updatePanel, 0, 4)

$progressGroup = New-Object System.Windows.Forms.GroupBox; $progressGroup.Text = [string](Get-UiValue 'labels.progress' '진행 상황'); $progressGroup.Dock = 'Fill'; $progressGroup.Padding = New-Object System.Windows.Forms.Padding(5,8,5,5); $progressGroup.BackColor = $uiBackground
$progressPanel = New-Object System.Windows.Forms.TableLayoutPanel; $progressPanel.Dock = 'Fill'; $progressPanel.ColumnCount = 10; $progressPanel.RowCount = 1
for ($pi = 0; $pi -lt 10; $pi++) { $progressPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 10))) | Out-Null }
$script:ProgressCells = @()
$progressNames = @(Get-UiValue 'progress.labels' @('메뉴','어비','던전','입장','상태','대기','전투','완료','종료','순환'))
if ($progressNames.Count -lt 10) { $progressNames = @('메뉴','어비','던전','입장','상태','대기','전투','완료','종료','순환') }
$progressActiveColor = Get-UiColor 'colors.progressActive' ([System.Drawing.Color]::FromArgb(0,122,204))
$progressInactiveColor = Get-UiColor 'colors.progressInactive' ([System.Drawing.Color]::FromArgb(245,247,250))
$progressActiveTextColor = Get-UiColor 'colors.progressActiveText' ([System.Drawing.Color]::White)
$progressInactiveTextColor = Get-UiColor 'colors.progressInactiveText' ([System.Drawing.Color]::Black)
for ($pi = 0; $pi -lt 10; $pi++) {
    $cell = New-Object System.Windows.Forms.Label
    $cell.Text = $progressNames[$pi]
    $cell.Dock = 'Fill'
    $cell.TextAlign = 'MiddleCenter'
    $cell.Margin = New-Object System.Windows.Forms.Padding(1)
    $cell.BackColor = $progressInactiveColor
    $cell.ForeColor = $progressInactiveTextColor
    $cell.BorderStyle = 'None'
    $cell.Padding = New-Object System.Windows.Forms.Padding(1)
    $cell.Font = New-Object System.Drawing.Font($uiFontName, 7.5)
    $progressPanel.Controls.Add($cell, $pi, 0)
    $script:ProgressCells += $cell
}
$progressGroup.Controls.Add($progressPanel); $gameTable.Controls.Add($progressGroup, 0, 5)
function Set-ProgressStep([int]$Index) {
    if ($null -eq $script:ProgressCells) { return }
    for ($i = 0; $i -lt $script:ProgressCells.Count; $i++) {
        if ($i -eq ($Index - 1)) {
            $script:ProgressCells[$i].BackColor = $progressActiveColor
            $script:ProgressCells[$i].ForeColor = $progressActiveTextColor
            $script:ProgressCells[$i].Font = New-Object System.Drawing.Font($uiFontName, 7.5, [System.Drawing.FontStyle]::Bold)
        } else {
            $script:ProgressCells[$i].BackColor = $progressInactiveColor
            $script:ProgressCells[$i].ForeColor = $progressInactiveTextColor
            $script:ProgressCells[$i].Font = New-Object System.Drawing.Font($uiFontName, 7.5)
        }
    }
}

$statusLabel = New-Object System.Windows.Forms.Label; $statusLabel.Text = ''; $statusLabel.Dock = 'Fill'; $statusLabel.TextAlign = 'MiddleLeft'; $statusLabel.AutoEllipsis = $true; $statusLabel.BackColor = $uiBackground; $gameTable.Controls.Add($statusLabel, 0, 6)
$portraitPanel = New-Object System.Windows.Forms.Panel; $portraitPanel.Dock = 'Fill'; $portraitPanel.BackColor = $uiBackground
$portraitPath = [string](Get-UiValue 'brand.imagePath' 'C:\Users\freem\Pictures\Mabinogi Mobile\screenshots\MabinogiMobile_2026070318471243.png')
if ([System.IO.File]::Exists($portraitPath)) {
    $script:PortraitImage = Load-ImageUnlocked $portraitPath
    $portraitPanel.Add_Paint({
        param($sender, $e)
        if ($null -eq $script:PortraitImage) { return }
        $w = [double]$sender.ClientSize.Width
        $h = [double]$sender.ClientSize.Height
        if ($w -le 0 -or $h -le 0) { return }
        $iw = [double]$script:PortraitImage.Width
        $ih = [double]$script:PortraitImage.Height
        $scale = [Math]::Max($w / $iw, $h / $ih)
        $dw = [int][Math]::Ceiling($iw * $scale)
        $dh = [int][Math]::Ceiling($ih * $scale)
        $dx = [int](($w - $dw) / 2) - [int]($w * 0.18)
        $dy = [int](($h - $dh) / 2)
        $e.Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $e.Graphics.DrawImage($script:PortraitImage, $dx, $dy, $dw, $dh)
    })
    $form.Add_FormClosed({ if ($null -ne $script:PortraitImage) { $script:PortraitImage.Dispose() } })
}
$brandTitleText = [string](Get-UiValue 'brand.title' '내 멋대로 게리노기')
$brandLinkText = [string](Get-UiValue 'brand.linkText' 'getiton85.github.io/gerinogi-pob')
$brandUrl = [string](Get-UiValue 'brand.url' 'https://getiton85.github.io/gerinogi-pob/')
$openBrandLink = { Start-Process $brandUrl }
$portraitTitleOutlines = @()
foreach ($offset in @(@(-2,0),@(2,0),@(0,-2),@(0,2),@(-1,-1),@(1,1))) {
    $outline = New-Object System.Windows.Forms.Label
    $outline.Text = $brandTitleText
    $outline.AutoSize = $false
    $outline.TextAlign = 'MiddleCenter'
    $outline.BackColor = [System.Drawing.Color]::Transparent
    $outline.ForeColor = Get-UiColor 'colors.brandOutline' ([System.Drawing.Color]::White)
    $outline.Font = New-Object System.Drawing.Font($uiFontName, 17, [System.Drawing.FontStyle]::Bold)
    $outline.Width = 220
    $outline.Height = 46
    $outline.Tag = $offset
    $outline.Cursor = [System.Windows.Forms.Cursors]::Hand
    $outline.Add_Click($openBrandLink)
    $portraitTitleOutlines += $outline
    $portraitPanel.Controls.Add($outline)
}
$portraitTitle = New-Object System.Windows.Forms.Label
$portraitTitle.Text = $brandTitleText
$portraitTitle.AutoSize = $false
$portraitTitle.TextAlign = 'MiddleCenter'
$portraitTitle.BackColor = [System.Drawing.Color]::Transparent
$portraitTitle.ForeColor = Get-UiColor 'colors.brandText' ([System.Drawing.Color]::FromArgb(24,42,38))
$portraitTitle.Font = New-Object System.Drawing.Font($uiFontName, 17, [System.Drawing.FontStyle]::Bold)
$portraitTitle.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Top
$portraitTitle.Width = 220
$portraitTitle.Height = 46
$portraitTitle.Left = 210
$portraitTitle.Top = 90
$portraitTitle.Cursor = [System.Windows.Forms.Cursors]::Hand
$portraitTitle.Add_Click($openBrandLink)
$portraitLink = New-Object System.Windows.Forms.LinkLabel
$portraitLink.Text = $brandLinkText
$portraitLink.AutoSize = $false
$portraitLink.TextAlign = 'MiddleCenter'
$portraitLink.BackColor = [System.Drawing.Color]::Transparent
$portraitLink.LinkColor = Get-UiColor 'colors.brandLink' ([System.Drawing.Color]::FromArgb(0,82,155))
$portraitLink.ActiveLinkColor = Get-UiColor 'colors.progressActive' ([System.Drawing.Color]::FromArgb(0,122,204))
$portraitLink.Font = New-Object System.Drawing.Font($uiFontName, 8, [System.Drawing.FontStyle]::Underline)
$portraitLink.Anchor = [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Top
$portraitLink.Width = 220
$portraitLink.Height = 24
$portraitLink.Left = 210
$portraitLink.Top = 136
$portraitLink.Add_LinkClicked($openBrandLink)
$portraitPanel.Controls.Add($portraitTitle)
$portraitPanel.Controls.Add($portraitLink)
$portraitPanel.Add_Resize({
    $baseLeft = [Math]::Max(180, $portraitPanel.ClientSize.Width - $portraitTitle.Width - 12)
    $portraitTitle.Left = $baseLeft
    $portraitTitle.Top = 90
    foreach ($outline in $portraitTitleOutlines) {
        $offset = $outline.Tag
        $outline.Left = $baseLeft + [int]$offset[0]
        $outline.Top = 90 + [int]$offset[1]
    }
    $portraitLink.Left = $portraitTitle.Left
})
$gameTable.Controls.Add($portraitPanel, 0, 7)


$settingsGroup = New-Object System.Windows.Forms.GroupBox; $settingsGroup.Text = [string](Get-UiValue 'labels.settings' '셋팅'); $settingsGroup.Dock = 'Top'; $settingsGroup.Height = 560; $settingsGroup.Padding = New-Object System.Windows.Forms.Padding(10)
$optionPage.Controls.Add($settingsGroup)
$settingsTable = New-Object System.Windows.Forms.TableLayoutPanel; $settingsTable.Dock = 'Fill'; $settingsTable.ColumnCount = 2; $settingsTable.RowCount = 17
$settingsTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 56))) | Out-Null
$settingsTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 44))) | Out-Null
$settingsGroup.Controls.Add($settingsTable)
$checkPanel = New-Object System.Windows.Forms.TableLayoutPanel; $checkPanel.Dock = 'Fill'; $checkPanel.ColumnCount = 3; $checkPanel.RowCount = 2
for ($ci = 0; $ci -lt 3; $ci++) { $checkPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.33))) | Out-Null }
$topMostCheck = New-Object System.Windows.Forms.CheckBox; $topMostCheck.Text = '항상 위'; $topMostCheck.Checked = $true; $topMostCheck.Dock = 'Fill'
$beepCheck = New-Object System.Windows.Forms.CheckBox; $beepCheck.Text = '실패음'; $beepCheck.Checked = $true; $beepCheck.Dock = 'Fill'
$fullMonitorCheck = New-Object System.Windows.Forms.CheckBox; $fullMonitorCheck.Text = '전체검색'; $fullMonitorCheck.Checked = $false; $fullMonitorCheck.Dock = 'Fill'
$minimizeOnRunCheck = New-Object System.Windows.Forms.CheckBox; $minimizeOnRunCheck.Text = '최소화'; $minimizeOnRunCheck.Checked = $false; $minimizeOnRunCheck.Dock = 'Fill'
$centerBeforeRunCheck = New-Object System.Windows.Forms.CheckBox; $centerBeforeRunCheck.Text = '중앙이동'; $centerBeforeRunCheck.Checked = $false; $centerBeforeRunCheck.Dock = 'Fill'
$pointCheck = New-Object System.Windows.Forms.CheckBox; $pointCheck.Text = '좌표검증'; $pointCheck.Checked = $true; $pointCheck.Dock = 'Fill'
$checkPanel.Controls.Add($topMostCheck,0,0); $checkPanel.Controls.Add($beepCheck,1,0); $checkPanel.Controls.Add($fullMonitorCheck,2,0); $checkPanel.Controls.Add($minimizeOnRunCheck,0,1); $checkPanel.Controls.Add($centerBeforeRunCheck,1,1); $checkPanel.Controls.Add($pointCheck,2,1)
$settingsTable.Controls.Add($checkPanel, 0, 0); $settingsTable.SetColumnSpan($checkPanel, 2)
function Add-OptionRow([int]$Row, [string]$Text, [System.Windows.Forms.Control]$Control) {
    $label = New-Object System.Windows.Forms.Label; $label.Text = $Text; $label.Dock = 'Fill'; $label.TextAlign = 'MiddleLeft'
    $Control.Dock = 'Right'; $Control.Width = 110
    $settingsTable.Controls.Add($label, 0, $Row); $settingsTable.Controls.Add($Control, 1, $Row)
}
$intervalBox = New-Object System.Windows.Forms.NumericUpDown; $intervalBox.Minimum = 1000; $intervalBox.Maximum = 60000; $intervalBox.Increment = 100; $intervalBox.Value = 10000
$pointToleranceBox = New-Object System.Windows.Forms.NumericUpDown; $pointToleranceBox.Minimum = 10; $pointToleranceBox.Maximum = 1000; $pointToleranceBox.Increment = 10; $pointToleranceBox.Value = 80
$coordinateModeBox = New-Object System.Windows.Forms.ComboBox; $coordinateModeBox.DropDownStyle = 'DropDownList'; [void]$coordinateModeBox.Items.Add('대상 창 기준'); [void]$coordinateModeBox.Items.Add('화면 기준'); $coordinateModeBox.SelectedIndex = 0
$clickModeBox = New-Object System.Windows.Forms.ComboBox; $clickModeBox.DropDownStyle = 'DropDownList'; [void]$clickModeBox.Items.Add('둘다'); [void]$clickModeBox.Items.Add('SendInput'); [void]$clickModeBox.Items.Add('mouse_event'); [void]$clickModeBox.Items.Add('백그라운드'); $clickModeBox.SelectedIndex = 0; $script:ClickModeBox = $clickModeBox
$matchPercentBox = New-Object System.Windows.Forms.NumericUpDown; $matchPercentBox.Minimum = 50; $matchPercentBox.Maximum = 100; $matchPercentBox.Value = 91
$colorToleranceBox = New-Object System.Windows.Forms.NumericUpDown; $colorToleranceBox.Minimum = 10; $colorToleranceBox.Maximum = 100; $colorToleranceBox.Value = 22
$retryCountBox = New-Object System.Windows.Forms.NumericUpDown; $retryCountBox.Minimum = 1; $retryCountBox.Maximum = 20; $retryCountBox.Value = 5
$retryIntervalBox = New-Object System.Windows.Forms.NumericUpDown; $retryIntervalBox.Minimum = 500; $retryIntervalBox.Maximum = 10000; $retryIntervalBox.Increment = 100; $retryIntervalBox.Value = 1000
$stepDelayBox = New-Object System.Windows.Forms.NumericUpDown; $stepDelayBox.Minimum = 100; $stepDelayBox.Maximum = 10000; $stepDelayBox.Increment = 100; $stepDelayBox.Value = 900
$moveSettleBox = New-Object System.Windows.Forms.NumericUpDown; $moveSettleBox.Minimum = 100; $moveSettleBox.Maximum = 5000; $moveSettleBox.Increment = 100; $moveSettleBox.Value = 250; $script:MoveSettleBox = $moveSettleBox
$clickHoldBox = New-Object System.Windows.Forms.NumericUpDown; $clickHoldBox.Minimum = 50; $clickHoldBox.Maximum = 3000; $clickHoldBox.Increment = 50; $clickHoldBox.Value = 350; $script:ClickHoldBox = $clickHoldBox
$goneDelayBox = New-Object System.Windows.Forms.NumericUpDown; $goneDelayBox.Minimum = 1000; $goneDelayBox.Maximum = 120000; $goneDelayBox.Increment = 1000; $goneDelayBox.Value = 20000
$ultimateNameBox = New-Object System.Windows.Forms.TextBox; $ultimateNameBox.Text = '궁극기 설정 1'
Add-OptionRow 1 '반복 간격ms' $intervalBox
Add-OptionRow 2 '좌표 허용px' $pointToleranceBox
Add-OptionRow 3 '좌표 기준' $coordinateModeBox
Add-OptionRow 4 '클릭 방식' $clickModeBox
Add-OptionRow 5 '일치율%' $matchPercentBox
Add-OptionRow 6 '색 허용' $colorToleranceBox
Add-OptionRow 7 '재시도' $retryCountBox
Add-OptionRow 8 '재시도 간격ms' $retryIntervalBox
Add-OptionRow 9 '클릭 후 대기ms' $stepDelayBox
Add-OptionRow 10 '이동 후 대기ms' $moveSettleBox
Add-OptionRow 11 '누름 유지ms' $clickHoldBox
Add-OptionRow 12 '사라짐 후 대기ms' $goneDelayBox
Add-OptionRow 13 '궁극기 이름' $ultimateNameBox
function Refresh-WindowList {
    $windowBox.Items.Clear()
    $script:WindowItems = @()
    foreach ($w in (Get-VisibleWindows)) {
        $script:WindowItems += $w
        [void]$windowBox.Items.Add($w.Title)
    }
}
function Get-SelectedTargetWindow([string]$TitlePart) {
    if ($windowBox.SelectedIndex -ge 0 -and $null -ne $script:WindowItems -and $windowBox.SelectedIndex -lt $script:WindowItems.Count) {
        $selected = $script:WindowItems[$windowBox.SelectedIndex]
        if ($null -ne $selected -and [NativeInput]::IsWindowVisible($selected.Handle)) {
            $currentTitle = Get-WindowTitle $selected.Handle
            if (-not [string]::IsNullOrWhiteSpace($currentTitle)) { return [pscustomobject]@{ Handle = $selected.Handle; Title = $currentTitle } }
        }
    }
    foreach ($w in (Get-VisibleWindows)) {
        if ($w.Title.Equals($TitlePart, [StringComparison]::OrdinalIgnoreCase)) { return $w }
    }
    return Find-WindowByTitlePart $TitlePart
}
function Update-SlotPreviewCollapsed {
    $specialPreviewGroup.Visible = -not $script:SlotPreviewCollapsed
    $routePreviewGroup.Visible = -not $script:SlotPreviewCollapsed
    $combatPreviewGroup.Visible = -not $script:SlotPreviewCollapsed
    $slotPreviewTable.RowStyles[1].Height = if ($script:SlotPreviewCollapsed) { 0 } else { 96 }
    $slotPreviewTable.RowStyles[2].Height = if ($script:SlotPreviewCollapsed) { 0 } else { 146 }
    $slotPreviewTable.RowStyles[3].Height = if ($script:SlotPreviewCollapsed) { 0 } else { 162 }
    $slotPreviewToggleButton.Text = if ($script:SlotPreviewCollapsed) { '열기' } else { '접기' }
    $gameTable.RowStyles[2].Height = if ($script:SlotPreviewCollapsed) { 56 } else { 508 }
}
function Toggle-SlotPreview {
    $script:SlotPreviewCollapsed = -not $script:SlotPreviewCollapsed
    Update-SlotPreviewCollapsed
}
function Update-AdvancedToolsCollapsed {
    $advancedPanel.Visible = -not $script:AdvancedToolsCollapsed
    $advancedToggleButton.Text = if ($script:AdvancedToolsCollapsed) { '고급 도구 열기' } else { '고급 도구 닫기' }
    $buttonPanel.RowStyles[3].Height = if ($script:AdvancedToolsCollapsed) { 0 } else { 68 }
    $gameTable.RowStyles[3].Height = if ($script:AdvancedToolsCollapsed) { 106 } else { 164 }
}
function Toggle-AdvancedTools {
    $script:AdvancedToolsCollapsed = -not $script:AdvancedToolsCollapsed
    Update-AdvancedToolsCollapsed
}
function Bring-MainWindowToFront {
    try {
        if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
            $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        }
        $wasTopMost = [bool]$form.TopMost
        $form.TopMost = $true
        $form.Show()
        $form.BringToFront()
        [void]$form.Activate()
        [void][NativeInput]::SetForegroundWindow($form.Handle)
        $form.TopMost = $wasTopMost
    } catch { }
}
function Apply-RoutineToggleStates {
    try {
        $script:SuppressDungeonRoutineToggleEvents = $true
        if ($harborEnabledCheck) { $harborEnabledCheck.Checked = [bool]$script:DungeonRoutineEnabled['허상의 정박지'] }
        if ($caveEnabledCheck) { $caveEnabledCheck.Checked = [bool]$script:DungeonRoutineEnabled['광기의 동굴'] }
    } catch { }
    finally { $script:SuppressDungeonRoutineToggleEvents = $false }
    try {
        foreach ($slot in $script:CombatSlots) {
            if ($script:CombatSlotChecks.ContainsKey($slot)) {
                $script:CombatSlotChecks[$slot].Checked = [bool]$script:CombatSlotEnabled[$slot]
            }
        }
    } catch { }
}

function Set-DungeonRoutineToggle([string]$Name, [bool]$Enabled) {
    if ($script:SuppressDungeonRoutineToggleEvents) { return }
    $script:DungeonRoutineEnabled[$Name] = $Enabled
    if ($Name -eq '허상의 정박지') { $script:HarborEnabled = $Enabled }
    if ($Enabled) {
        $other = if ($Name -eq '허상의 정박지') { '광기의 동굴' } else { '허상의 정박지' }
        $script:DungeonRoutineEnabled[$other] = $false
        if ($other -eq '허상의 정박지') { $script:HarborEnabled = $false }
        try {
            $script:SuppressDungeonRoutineToggleEvents = $true
            if ($other -eq '허상의 정박지' -and $harborEnabledCheck) { $harborEnabledCheck.Checked = $false }
            if ($other -eq '광기의 동굴' -and $caveEnabledCheck) { $caveEnabledCheck.Checked = $false }
        } catch { }
        finally { $script:SuppressDungeonRoutineToggleEvents = $false }
    }
    Refresh-Slots
}
function Select-Slot([string]$Slot) { $script:SelectedSlot = $Slot; $baseSlot = Resolve-RouteSlotFromStorageKey $Slot; if ($slotBox.Items.Contains($baseSlot) -and $slotBox.SelectedItem -ne $baseSlot) { $slotBox.SelectedItem = $baseSlot }; Refresh-Slots }
function Mark-ActiveSlot([string]$Slot) { $script:ActiveSlot = $Slot; switch ($Slot) { '메뉴' { Set-ProgressStep 1 } '어비스' { Set-ProgressStep 2 } '던전' { Set-ProgressStep 3 } '입장' { Set-ProgressStep 4 } '상태 기준' { Set-ProgressStep 5 } '완료 확인' { Set-ProgressStep 8 } '나가기' { Set-ProgressStep 9 } default { } } }
function Handle-FileDrop([string]$Slot, $Data) { $paths = $Data.GetData([System.Windows.Forms.DataFormats]::FileDrop); if ($paths -and $paths.Length -gt 0) { Select-Slot $Slot; Assign-ImageFileToSlot $Slot $paths[0]; Refresh-Slots; $statusLabel.Text = (Get-SlotStatusName $Slot) + ' 슬롯에 이미지 파일을 연결했습니다.' } }
function Add-DropHandlers($Control, [string]$Slot) { $Control.AllowDrop = $true; $Control.Add_DragEnter({ if ($_.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $_.Effect = [System.Windows.Forms.DragDropEffects]::Copy } }.GetNewClosure()); $Control.Add_DragDrop({ Handle-FileDrop $Slot $_.Data }.GetNewClosure()) }
function New-SlotPreviewCard([string]$CardSlot) {
    $slotKey = Get-EffectiveSlotKey $CardSlot
    $card = New-Object System.Windows.Forms.Panel
    $card.Dock = 'Fill'
    $card.Margin = New-Object System.Windows.Forms.Padding(3)
    $card.BorderStyle = 'FixedSingle'
    if (-not (Test-SlotEnabled $CardSlot)) {
        $card.BackColor = [System.Drawing.Color]::Gainsboro
    } elseif ($CardSlot -eq $script:ActiveSlot) {
        $card.BackColor = [System.Drawing.Color]::Honeydew
    } elseif ($CardSlot -eq $script:SelectedSlot) {
        $card.BackColor = [System.Drawing.Color]::FromArgb(255,236,148)
    } else {
        $card.BackColor = [System.Drawing.Color]::White
    }
    Add-DropHandlers $card $CardSlot

    if ($script:Samples[$slotKey]) {
        $image = Load-ImageUnlocked $script:Samples[$slotKey].Path
        $card.Tag = $image
        $pic = New-Object System.Windows.Forms.PictureBox
        $pic.Image = $image
        $pic.SizeMode = 'Zoom'
        $pic.Width = 62
        $pic.Height = 56
        $pic.Left = 1
        $pic.Top = 3
        Add-DropHandlers $pic $CardSlot
        $pic.Add_Click({ Select-Slot $CardSlot }.GetNewClosure())
        $card.Controls.Add($pic)
    }

    $label = New-Object System.Windows.Forms.Label
    $label.Text = (Get-SlotDisplayName $CardSlot)
    $label.TextAlign = 'MiddleCenter'
    $label.Width = 62
    $label.Height = 18
    $label.Left = 1
    $label.Top = 60
    if ($CardSlot -eq $script:ActiveSlot) {
        $label.ForeColor = [System.Drawing.Color]::DarkGreen
        $label.Font = New-Object System.Drawing.Font('Malgun Gothic', 7, [System.Drawing.FontStyle]::Bold)
    } elseif ($CardSlot -eq $script:SelectedSlot) {
        $label.ForeColor = [System.Drawing.Color]::FromArgb(120,72,0)
        $label.Font = New-Object System.Drawing.Font('Malgun Gothic', 7, [System.Drawing.FontStyle]::Bold)
    } else {
        $label.Font = New-Object System.Drawing.Font('Malgun Gothic', 7)
    }
    Add-DropHandlers $label $CardSlot
    $label.Add_Click({ Select-Slot $CardSlot }.GetNewClosure())

    $pointLabel = New-Object System.Windows.Forms.Label
    $point = $script:SlotPoints[$slotKey]
    $region = $script:SlotRegions[$slotKey]
    $regionMark = if ($null -ne $region) { ' / 구역' } else { '' }
    if ($CardSlot -eq '상태 기준') {
        $pointLabel.Text = '좌표 제외' + $regionMark
    } elseif ($null -eq $point) {
        $pointLabel.Text = '좌표 없음' + $regionMark
    } else {
        $pointLabel.Text = 'X=' + $point.X + ', Y=' + $point.Y + $regionMark
    }
    $pointLabel.TextAlign = 'MiddleCenter'
    $pointLabel.Width = 62
    $pointLabel.Height = 15
    $pointLabel.Left = 1
    $pointLabel.Top = 78
    $pointLabel.ForeColor = [System.Drawing.Color]::DimGray
    $pointLabel.Font = New-Object System.Drawing.Font('Malgun Gothic', 5.8)
    Add-DropHandlers $pointLabel $CardSlot
    $pointLabel.Add_Click({ Select-Slot $CardSlot }.GetNewClosure())
    $card.Add_Click({ Select-Slot $CardSlot }.GetNewClosure())
    $card.Controls.Add($label)
    $card.Controls.Add($pointLabel)
    return $card
}

function Refresh-Slots {
    foreach ($panel in @($specialSlotPanel, $routeSlotPanel, $caveSlotPanel, $combatSlotPanel)) {
        foreach ($control in @($panel.Controls)) {
            if ($control.Tag -is [System.Drawing.Image]) { $control.Tag.Dispose() }
            $control.Dispose()
        }
        $panel.Controls.Clear()
    }
    foreach ($slot in $script:SpecialSlots) {
        $specialSlotPanel.Controls.Add((New-SlotPreviewCard $slot), ([array]::IndexOf($script:SpecialSlots, $slot)), 0)
    }
    foreach ($slot in $script:RouteSlots) {
        $idx = [array]::IndexOf($script:RouteSlots, $slot)
        $routeSlotPanel.Controls.Add((New-SlotPreviewCard $slot), $idx, 0)
        $caveSlotPanel.Controls.Add((New-SlotPreviewCard (Get-DungeonRouteSlotKey '광기의 동굴' $slot)), $idx, 0)
    }
    foreach ($slot in $script:CombatSlots) {
        $combatSlotPanel.Controls.Add((New-SlotPreviewCard $slot), ([array]::IndexOf($script:CombatSlots, $slot)), 0)
    }
}
function Add-SlotRegionOnly { $screen = $screens[$monitorBox.SelectedIndex]; $script:LastCaptureMessage = ''; Save-SlotRegionOnly $script:SelectedSlot $screen; Refresh-Slots; if (-not [string]::IsNullOrWhiteSpace($script:LastCaptureMessage)) { $statusLabel.Text = $script:LastCaptureMessage } else { $statusLabel.Text = $script:SelectedSlot + ' 영역 지정이 취소되었습니다.' } }
function Add-SlotSample { $screen = $screens[$monitorBox.SelectedIndex]; $script:LastCaptureMessage = ''; Capture-SlotFromSavedRegion $script:SelectedSlot $screen; Refresh-Slots; if (-not [string]::IsNullOrWhiteSpace($script:LastCaptureMessage)) { $statusLabel.Text = $script:LastCaptureMessage } else { $statusLabel.Text = $script:SelectedSlot + ' 영역 촬영이 취소되었습니다.' } }
function Add-ExtraSlotSample { $screen = $screens[$monitorBox.SelectedIndex]; $script:LastCaptureMessage = ''; Capture-ExtraSlotSample $script:SelectedSlot $screen; if (-not [string]::IsNullOrWhiteSpace($script:LastCaptureMessage)) { $statusLabel.Text = $script:LastCaptureMessage } else { $statusLabel.Text = $script:SelectedSlot + ' 추가 샘플 저장이 취소되었습니다.' } }
function Import-SelectedSlotFile { $dialog = New-Object System.Windows.Forms.OpenFileDialog; $dialog.Title = '슬롯 이미지 선택'; $dialog.InitialDirectory = $script:SampleDir; $dialog.Filter = 'Image files (*.png;*.jpg;*.jpeg;*.bmp)|*.png;*.jpg;*.jpeg;*.bmp'; if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Assign-ImageFileToSlot $script:SelectedSlot $dialog.FileName; Refresh-Slots; $statusLabel.Text = (Get-SlotStatusName $script:SelectedSlot) + ' 슬롯에 이미지 파일을 연결했습니다.' } }
function Reload-SavedSamplesToSlots { $count = Load-SavedSamples; Refresh-Slots; $statusLabel.Text = '저장 폴더에서 ' + $count + '개 슬롯을 불러왔습니다.' }
function Run-ClickDiagnostic {
    if (-not [System.IO.File]::Exists($script:ClickTracePath)) { 'time,x,y,mode,down_sent,up_sent,error_code,note' | Set-Content -LiteralPath $script:ClickTracePath -Encoding UTF8 }
    Ensure-RoutineTraceHeader
    New-Item -ItemType Directory -Force -Path $script:DiagnosticDir | Out-Null
    Start-Process -FilePath $script:RoutineTracePath
    Start-Process -FilePath $script:ClickTracePath
    Start-Process -FilePath $script:DiagnosticDir
}
function Copy-ReportFile([string]$Source, [string]$DestinationDir) {
    if ([string]::IsNullOrWhiteSpace($Source) -or -not [System.IO.File]::Exists($Source)) { return $false }
    Copy-Item -LiteralPath $Source -Destination (Join-Path $DestinationDir ([System.IO.Path]::GetFileName($Source))) -Force
    return $true
}
function New-ProblemReportPackage {
    Save-UserSettings
    Ensure-LogHeader
    Ensure-RoutineTraceHeader
    if (-not [System.IO.File]::Exists($script:ClickTracePath)) { 'time,x,y,mode,down_sent,up_sent,error_code,note' | Set-Content -LiteralPath $script:ClickTracePath -Encoding UTF8 }
    New-Item -ItemType Directory -Force -Path $script:ReportDir | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $stageDir = Join-Path $script:ReportDir ('problem_report_' + $stamp)
    $diagnosticOut = Join-Path $stageDir 'diagnostic_frames_recent'
    New-Item -ItemType Directory -Force -Path $stageDir | Out-Null
    New-Item -ItemType Directory -Force -Path $diagnosticOut | Out-Null
    $copied = 0
    foreach ($path in @(
        $script:RoutineTracePath,
        $script:ClickTracePath,
        $script:LogPath,
        $script:UserSettingsPath,
        $script:SlotRegionPath,
        $script:SlotPointPath,
        $script:IgnoreZonePath,
        $script:UpdateManifestPath,
        (Join-Path $PSScriptRoot 'install_info.txt'),
        (Join-Path $PSScriptRoot 'version.json')
    )) {
        if (Copy-ReportFile $path $stageDir) { $copied++ }
    }
    $metaPath = Join-Path $stageDir 'report_info.txt'
    @(
        'created_at=' + (Get-Date).ToString('s'),
        'app_version=' + $script:AppVersion,
        'install_root=' + $PSScriptRoot,
        'selected_slot=' + $script:SelectedSlot,
        'active_slot=' + $script:ActiveSlot,
        'running=' + $script:Running,
        'target_title_text=' + $titleBox.Text,
        'monitor=' + [string]$monitorBox.SelectedItem,
        'package_note=logs and recent diagnostic frames for troubleshooting'
    ) | Set-Content -LiteralPath $metaPath -Encoding UTF8
    if ([System.IO.Directory]::Exists($script:DiagnosticDir)) {
        Get-ChildItem -LiteralPath $script:DiagnosticDir -File -Filter '*.png' |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 30 |
            ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $diagnosticOut $_.Name) -Force }
    }
    $zipPath = Join-Path $script:ReportDir ('problem_report_' + $stamp + '.zip')
    if ([System.IO.File]::Exists($zipPath)) { [System.IO.File]::Delete($zipPath) }
    Compress-Archive -Path (Join-Path $stageDir '*') -DestinationPath $zipPath -CompressionLevel Optimal -Force
    Write-RoutineTrace $script:CurrentCycle 'report' '' 'created' ([System.Drawing.Rectangle]::Empty) $zipPath
    Start-Process -FilePath $script:ReportDir
    [System.Windows.Forms.MessageBox]::Show('문제 보고용 압축 파일을 만들었습니다.' + $script:NewLine + $zipPath, '문제 보고') | Out-Null
    $statusLabel.Text = '문제 보고 파일 생성: ' + [System.IO.Path]::GetFileName($zipPath)
    return $zipPath
}
function Run-LocateSelectedSlot {
    if ($monitorBox.SelectedIndex -lt 0) { return }
    $screen = $screens[$monitorBox.SelectedIndex]
    $slot = $script:SelectedSlot
    if ((Get-SlotSamplePaths $slot).Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('현재 선택 슬롯에 이미지가 없습니다.', '위치 확인') | Out-Null
        return
    }
    $rect = Find-Slot $slot $screen
    if ($rect.IsEmpty) {
        [System.Windows.Forms.MessageBox]::Show('선택 슬롯 이미지를 화면에서 찾지 못했습니다.' + $script:NewLine + '일치율을 낮추거나 색허용 값을 올려보세요. 도구 창이 대상 화면을 가리면 다른 모니터로 옮기거나 전체 모니터 검색을 사용하세요.', '위치 확인') | Out-Null
        return
    }
    $x = [int]($rect.Left + $rect.Width / 2)
    $y = [int]($rect.Top + $rect.Height / 2)
    [void][NativeInput]::SetCursorPos($x, $y)
    $statusLabel.Text = (Get-SlotStatusName $slot) + ' 위치 확인: X=' + $x + ', Y=' + $y
}
function Run-ActualClickProbe { $slot=$script:SelectedSlot; $titlePart=$titleBox.Text.Trim(); if([string]::IsNullOrWhiteSpace($titlePart)){[System.Windows.Forms.MessageBox]::Show('대상 창 제목을 먼저 입력하세요.','실제 클릭 확인')|Out-Null;return}; $target=Find-WindowByTitlePart $titlePart; if($null -eq $target){[System.Windows.Forms.MessageBox]::Show('대상 창을 찾지 못했습니다.','실제 클릭 확인')|Out-Null;return}; $script:TargetHandle=$target.Handle; $screen=$screens[$monitorBox.SelectedIndex]; if((Get-SlotSamplePaths $slot).Count -eq 0){[System.Windows.Forms.MessageBox]::Show('현재 선택 슬롯에 이미지가 없습니다.','실제 클릭 확인')|Out-Null;return}; $rect=Find-Slot $slot $screen; if($rect.IsEmpty){[System.Windows.Forms.MessageBox]::Show('현재 선택 슬롯 이미지를 화면에서 찾지 못했습니다.','실제 클릭 확인')|Out-Null;return}; if([System.Windows.Forms.MessageBox]::Show('선택 슬롯을 한 번 클릭합니다. 반응 여부를 눈으로 확인하세요.','실제 클릭 확인',[System.Windows.Forms.MessageBoxButtons]::OKCancel) -eq [System.Windows.Forms.DialogResult]::OK){[void][NativeInput]::SetForegroundWindow($target.Handle); Start-Sleep -Milliseconds 200; [void](Click-SlotTarget $slot $rect ([int]$stepDelayBox.Value))} }
$refreshWindowsButton.Add_Click({ Refresh-WindowList })
$windowBox.Add_SelectedIndexChanged({ if ($windowBox.SelectedItem) { $titleBox.Text = [string]$windowBox.SelectedItem } })
$slotBox.Add_SelectedIndexChanged({ if ($slotBox.SelectedItem) { $script:SelectedSlot = [string]$slotBox.SelectedItem; Refresh-Slots } })
$addButton.Add_Click({ Add-SlotRegionOnly })
$pointButton.Add_Click({ Add-SlotSample })
$fileButton.Add_Click({ Import-SelectedSlotFile })
$reloadButton.Add_Click({ Reload-SavedSamplesToSlots })
$deleteButton.Add_Click({ $slot=$script:SelectedSlot; $slotKey=Get-EffectiveSlotKey $slot; if($script:Samples[$slotKey] -and [System.IO.File]::Exists($script:Samples[$slotKey].Path)){[System.IO.File]::Delete($script:Samples[$slotKey].Path)}; $script:Samples[$slotKey]=$null; $script:SlotRegions[$slotKey]=$null; $script:SlotPoints[$slotKey]=$null; Save-SlotRegions; Save-SlotPoints; Refresh-Slots; $statusLabel.Text=(Get-SlotStatusName $slot)+' 슬롯 정보를 삭제했습니다.' })
$locateButton.Add_Click({ Run-LocateSelectedSlot })
$probeButton.Add_Click({ Run-ActualClickProbe })
$diagnosticButton.Add_Click({ Run-ClickDiagnostic })
$reportButton.Add_Click({ [void](New-ProblemReportPackage) })
$showIgnoreButton.Add_Click({ Show-IgnoreZones })
$stopButton.Add_Click({ $script:StopRequested = $true; $statusLabel.Text = '중단 요청됨.' })
$logButton.Add_Click({ Ensure-LogHeader; Start-Process -FilePath $script:LogPath })
$updateButton.Add_Click({ Invoke-AppUpdateCheck $false })
$exitButton.Add_Click({ $script:StopRequested = $true; $form.Close() })
$advancedToggleButton.Add_Click({ Toggle-AdvancedTools })
$topMostCheck.Add_CheckedChanged({ $form.TopMost = $topMostCheck.Checked })
$harborEnabledCheck.Add_CheckedChanged({ Set-DungeonRoutineToggle '허상의 정박지' ([bool]$harborEnabledCheck.Checked) })
$caveEnabledCheck.Add_CheckedChanged({ Set-DungeonRoutineToggle '광기의 동굴' ([bool]$caveEnabledCheck.Checked) })
$specialEnabledCheck.Add_CheckedChanged({ $script:SpecialSlotEnabled['협동'] = [bool]$specialEnabledCheck.Checked; Save-UserSettings; Refresh-Slots })
$ultimateProfileBox.Add_SelectedIndexChanged({
    if ($script:SuppressUltimateProfileEvents) { return }
    $previousUltimateProfileIndex = [int]$script:SelectedUltimateProfileIndex
    Save-SelectedUltimateProfileFromControls
    if ($ultimateProfileBox.SelectedIndex -ge 0) { $script:SelectedUltimateProfileIndex = [int]$ultimateProfileBox.SelectedIndex }
    Write-RoutineTrace $script:CurrentCycle 'ui' '궁극기' 'profile-select' ([System.Drawing.Rectangle]::Empty) ('from=' + ($previousUltimateProfileIndex + 1) + '; to=' + ([int]$script:SelectedUltimateProfileIndex + 1))
    $script:SelectedSlot = '궁극기'
    if ($slotBox.SelectedItem -ne '궁극기') { $slotBox.SelectedItem = '궁극기' }
    try { $ultimateNameBox.Text = [string](Get-SelectedUltimateProfile).Name } catch { }
    Refresh-Slots
    $statusLabel.Text = '궁극기 설정 ' + ([int]$script:SelectedUltimateProfileIndex + 1) + ' 선택됨. Shift+F8로 영역 지정 후 Shift+F7로 촬영하세요.'
})
$questProfileBox.Add_SelectedIndexChanged({
    if ($questProfileBox.SelectedIndex -ge 0) { $script:SelectedQuestProfileIndex = [int]$questProfileBox.SelectedIndex }
    $script:SelectedSlot = '퀘스트'
    if ($slotBox.SelectedItem -ne '퀘스트') { $slotBox.SelectedItem = '퀘스트' }
    Refresh-Slots
    $statusLabel.Text = '퀘스트 설정 ' + ([int]$script:SelectedQuestProfileIndex + 1) + ' 선택됨. Shift+F8로 영역 지정 후 Shift+F7로 촬영하세요.'
})
$ultimateNameBox.Add_Leave({ Save-SelectedUltimateProfileFromControls; Refresh-UltimateProfileCombo; Refresh-Slots })
foreach ($slot in $script:CombatSlots) {
    $script:CombatSlotChecks[$slot].Add_CheckedChanged({ param($sender, $eventArgs) $script:CombatSlotEnabled[[string]$sender.Text] = [bool]$sender.Checked; Refresh-Slots })
}
$windowBox.Add_SelectedIndexChanged({ if ($windowBox.SelectedIndex -ge 0) { $titleBox.Text = [string]$windowBox.SelectedItem } })
$slotPreviewToggleButton.Add_Click({ Toggle-SlotPreview })
Refresh-WindowList
$settingsLoadedOnStart = Load-UserSettings
Apply-RoutineToggleStates
Apply-UltimateProfileToControls
Refresh-QuestProfileCombo
$loadedOnStart = Load-SavedSamples
$loadedPointsOnStart = Load-SlotPoints
$loadedRegionsOnStart = Load-SlotRegions
$abyssMigratedOnStart = Invoke-AbyssCoordinateMigration
$loadedIgnoreZonesOnStart = Load-IgnoreZones
Refresh-Slots
Update-SlotPreviewCollapsed
Update-AdvancedToolsCollapsed
$statusLabel.Text = '저장 폴더에서 ' + $loadedOnStart + '개 슬롯, 좌표 ' + $loadedPointsOnStart + '개, 슬롯구역 ' + $loadedRegionsOnStart + '개, 제외구역 ' + $loadedIgnoreZonesOnStart + '개를 불러왔습니다.'
function Start-StateRoutine {
    if ($script:Running) { [System.Windows.Forms.MessageBox]::Show('이미 실행 중입니다.', '실행') | Out-Null; return }
    if (-not (Test-AnyDungeonRoutineEnabled)) { [System.Windows.Forms.MessageBox]::Show('사용할 던전 루틴이 OFF 상태입니다. 허상의 정박지 또는 광기의 동굴 ON을 체크하세요.', '실행') | Out-Null; return }
    $optionalSlots = @('식사 버튼','궁극기','스킵','팔라딘')
    foreach ($slot in $script:RouteSlots + @('상태 기준')) { if ($optionalSlots -contains $slot) { continue }; if (-not (Test-SlotEnabled $slot)) { continue }; if ((Get-SlotSamplePaths $slot).Count -eq 0) { [System.Windows.Forms.MessageBox]::Show((Get-SlotStatusName $slot) + ' 슬롯 이미지가 필요합니다.', '실행') | Out-Null; return } }
    $titlePart = $titleBox.Text.Trim(); if ([string]::IsNullOrWhiteSpace($titlePart)) { [System.Windows.Forms.MessageBox]::Show('대상 창 제목을 반드시 입력해야 합니다.', '실행') | Out-Null; return }
    $target = Get-SelectedTargetWindow $titlePart; if ($null -eq $target) { [System.Windows.Forms.MessageBox]::Show('대상 창을 찾지 못했습니다.', '실행') | Out-Null; return }
    $script:TargetHandle = $target.Handle; $screen = $screens[$monitorBox.SelectedIndex]
    if ($centerBeforeRunCheck.Checked) {
        $center = Get-WindowCenter $target.Handle
        if ($null -eq $center) { [System.Windows.Forms.MessageBox]::Show('대상 창 중심 좌표를 계산하지 못했습니다.', '실행') | Out-Null; return }
        [void][NativeInput]::SetCursorPos($center.X, $center.Y)
        $statusLabel.Text = '시작 확인: 커서를 대상 창 중심으로 이동했습니다.'
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 500
    }
    $previousWindowState = $form.WindowState
    if ($minimizeOnRunCheck.Checked) {
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 800
    }
    Ensure-RoutineTraceHeader
    Write-RoutineTrace 0 'run' '' 'start' ([System.Drawing.Rectangle]::Empty) ('target=' + $titlePart + '; matched=' + (Get-WindowTitle $target.Handle) + '; monitor=' + $monitorBox.SelectedItem)
    $script:Running=$true; $script:StopRequested=$false; $startButton.Enabled=$false; $started=Get-Date; $timer=[System.Diagnostics.Stopwatch]::StartNew(); $completedCycles=0; $completedClicks=0; $status='completed'; $message=''
    try {
        $cycle=0
        $insidePhase = $false
        $script:InsideStartedAt = $null
        $script:CombatMarkerSeen = $false
        $script:BossSkipSeen = $false
        $script:CombatMarkerSeenAfterSkip = $false
        $routineStage = '메뉴'
        while(-not $script:StopRequested) {
            $cycle++
            $script:CurrentCycle = $cycle
            Write-RoutineTrace $cycle 'cycle' '' 'start' ([System.Drawing.Rectangle]::Empty) ('stage=' + $routineStage + '; inside=' + $insidePhase)
            if($script:StopRequested){ $status='stopped'; $message='사용자 중단'; break }
            [void][NativeInput]::SetForegroundWindow($target.Handle)
            [void](Sleep-WithStop 150)
            $candidate = Find-RoutineCandidate $screen $routineStage
            if ($null -eq $candidate) {
                $statusLabel.Text = '현재 단계 대기 중: ' + $routineStage
                [System.Windows.Forms.Application]::DoEvents()
                [void](Sleep-WithStop ([Math]::Max(120, [Math]::Min(500, [int]$retryIntervalBox.Value))))
                continue
            }
            $actionResult = Invoke-RoutineCandidateAction $candidate $screen $statusLabel ([ref]$insidePhase)
            $completedClicks += [int]$actionResult.Clicks
            if (-not [string]::IsNullOrWhiteSpace([string]$actionResult.NextStage)) {
                Write-RoutineTrace $cycle 'stage' ([string]$candidate.Slot) 'advance' ([System.Drawing.Rectangle]::Empty) ('from=' + $routineStage + '; to=' + [string]$actionResult.NextStage)
                $routineStage = [string]$actionResult.NextStage
            }
            if ($actionResult.Completed) {
                $completedCycles++
                Write-RoutineTrace $cycle 'cycle' '' 'completed' ([System.Drawing.Rectangle]::Empty) ('clicks=' + $completedClicks + '; message=' + $actionResult.Message)
                $routineStage = '메뉴'
                $sleepWatch = [System.Diagnostics.Stopwatch]::StartNew()
                while((-not $script:StopRequested) -and $sleepWatch.ElapsedMilliseconds -lt [int]$intervalBox.Value) { Start-Sleep -Milliseconds 100; [System.Windows.Forms.Application]::DoEvents() }
            }
        }
        if($script:StopRequested -and $status -eq 'completed'){ $status='stopped'; $message='사용자 중단' }
    }
    catch {
        $status='error'
        $message=$_.Exception.Message
        Write-CrashLog 'Start-StateRoutine catch' $_
    }
    finally { Write-RoutineTrace $script:CurrentCycle 'run' '' ('end-' + $status) ([System.Drawing.Rectangle]::Empty) $message; $ended=Get-Date; $elapsed=$timer.Elapsed.TotalSeconds; $average=if($completedCycles -gt 0){$elapsed/$completedCycles}else{0}; Write-RunLog $started $ended $titlePart (Get-WindowTitle $target.Handle) $monitorBox.SelectedItem 0 $completedCycles $completedClicks ([int]$intervalBox.Value) $elapsed $average $status $message; if ($minimizeOnRunCheck.Checked) { $form.WindowState = $previousWindowState; [void]$form.Activate() }; $script:ActiveSlot=''; Refresh-Slots; $statusLabel.Text='종료: '+$status+', 완료 '+$completedCycles+'회'; Set-ProgressStep 0; $startButton.Enabled=$true; $script:Running=$false }
}
$startButton.Add_Click({ Start-StateRoutine })
$form.Add_Shown({
    [void][NativeInput]::RegisterHotKey($form.Handle,801,4,0x77)
    [void][NativeInput]::RegisterHotKey($form.Handle,803,4,0x74)
    [void][NativeInput]::RegisterHotKey($form.Handle,804,4,0x75)
    [void][NativeInput]::RegisterHotKey($form.Handle,805,4,0x76)
    Bring-MainWindowToFront
    $frontTimer = New-Object System.Windows.Forms.Timer
    $frontTimer.Interval = 450
    $frontTimer.Add_Tick({
        $frontTimer.Stop()
        $frontTimer.Dispose()
        Bring-MainWindowToFront
    }.GetNewClosure())
    $frontTimer.Start()
})
$form.Add_FormClosed({ Write-CrashLog 'form-closed' $null; Save-UserSettings; [void][NativeInput]::UnregisterHotKey($form.Handle,801); [void][NativeInput]::UnregisterHotKey($form.Handle,803); [void][NativeInput]::UnregisterHotKey($form.Handle,804); [void][NativeInput]::UnregisterHotKey($form.Handle,805) })
$script:HotKeyFilter = New-Object HotKeyWindowFilter
$script:HotKeyFilter.OnHotKey = [Action[int]]{ param($id) if($id -eq 801 -and -not $script:Running){ Add-SlotRegionOnly }; if($id -eq 803 -and -not $script:Running){ Start-StateRoutine }; if($id -eq 804){ $script:StopRequested=$true; $statusLabel.Text='중단 요청됨.' }; if($id -eq 805 -and -not $script:Running){ Add-SlotSample } }
[System.Windows.Forms.Application]::AddMessageFilter($script:HotKeyFilter)
try {
    [System.Windows.Forms.Application]::add_ThreadException({
        param($sender, $eventArgs)
        Write-CrashLog 'winforms-thread-exception' $eventArgs.Exception
    })
    [AppDomain]::CurrentDomain.add_UnhandledException({
        param($sender, $eventArgs)
        Write-CrashLog 'appdomain-unhandled-exception' $eventArgs.ExceptionObject
    })
    [void]$form.ShowDialog()
} catch {
    Write-CrashLog 'show-dialog catch' $_
    throw
} finally {
    Write-CrashLog 'app-exit' $null
}









