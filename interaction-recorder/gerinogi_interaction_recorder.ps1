$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:AppVersion = '0.1.0'
$script:MaskRoot = 'C:\gerinogi-mask'
$script:RecordRoot = Join-Path $PSScriptRoot 'records'
$script:SessionDir = $null
$script:RecordCsv = $null
$script:Recording = $false
$script:LastLeftDown = $false
$script:LastRightDown = $false
$script:ClickCount = 0
$script:IgnoredCount = 0
$script:SlotRegions = @()

Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class NativeInputProbe {
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int X;
        public int Y;
    }

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
}
'@

function Get-NowStamp {
    return (Get-Date).ToString('yyyyMMdd_HHmmss_fff')
}

function Convert-CsvNumber($Value) {
    $text = [string]$Value
    $number = 0
    if ([int]::TryParse($text, [ref]$number)) { return $number }
    return 0
}

function Load-SlotRegions {
    $path = Join-Path $script:MaskRoot 'slot_regions.csv'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "slot_regions.csv를 찾을 수 없습니다: $path"
    }

    $rows = Import-Csv -LiteralPath $path
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $rows) {
        $x = Convert-CsvNumber $row.x
        $y = Convert-CsvNumber $row.y
        $w = Convert-CsvNumber $row.width
        $h = Convert-CsvNumber $row.height
        if ($w -le 0 -or $h -le 0) { continue }
        $items.Add([pscustomobject]@{
            Slot = [string]$row.slot
            Rect = [System.Drawing.Rectangle]::new($x, $y, $w, $h)
            CenterX = [int]($x + ($w / 2))
            CenterY = [int]($y + ($h / 2))
        })
    }
    $script:SlotRegions = @($items)
}

function Get-ActiveWindowTitle {
    $handle = [NativeInputProbe]::GetForegroundWindow()
    if ($handle -eq [IntPtr]::Zero) { return '' }
    $builder = New-Object System.Text.StringBuilder 512
    [void][NativeInputProbe]::GetWindowText($handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-CursorPoint {
    $point = New-Object NativeInputProbe+POINT
    [void][NativeInputProbe]::GetCursorPos([ref]$point)
    return [System.Drawing.Point]::new($point.X, $point.Y)
}

function Get-VirtualScreenBounds {
    $left = [System.Windows.Forms.SystemInformation]::VirtualScreen.Left
    $top = [System.Windows.Forms.SystemInformation]::VirtualScreen.Top
    $width = [System.Windows.Forms.SystemInformation]::VirtualScreen.Width
    $height = [System.Windows.Forms.SystemInformation]::VirtualScreen.Height
    return [System.Drawing.Rectangle]::new($left, $top, $width, $height)
}

function Find-ContainingSlot([System.Drawing.Point]$Point) {
    foreach ($item in $script:SlotRegions) {
        if ($item.Rect.Contains($Point)) { return $item }
    }
    return $null
}

function Get-NearestSlot([System.Drawing.Point]$Point) {
    $best = $null
    $bestDistance = [double]::MaxValue
    foreach ($item in $script:SlotRegions) {
        $dx = [double]($Point.X - $item.CenterX)
        $dy = [double]($Point.Y - $item.CenterY)
        $distance = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
        if ($distance -lt $bestDistance) {
            $best = $item
            $bestDistance = $distance
        }
    }
    return [pscustomobject]@{ Slot = $best; Distance = $bestDistance }
}

function Save-ScreenImages([System.Drawing.Point]$Point, $SlotItem, [string]$Stamp) {
    $screenBounds = Get-VirtualScreenBounds
    $fullPath = Join-Path $script:SessionDir ($Stamp + '_full.png')
    $cropPath = Join-Path $script:SessionDir ($Stamp + '_region.png')
    $clickPath = Join-Path $script:SessionDir ($Stamp + '_click.png')

    $bitmap = [System.Drawing.Bitmap]::new([int]$screenBounds.Width, [int]$screenBounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($screenBounds.Left, $screenBounds.Top, 0, 0, $bitmap.Size)
        $bitmap.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)

        if ($null -ne $SlotItem) {
            $rect = $SlotItem.Rect
            $localRect = [System.Drawing.Rectangle]::new($rect.X - $screenBounds.Left, $rect.Y - $screenBounds.Top, $rect.Width, $rect.Height)
            $localRect.Intersect([System.Drawing.Rectangle]::new(0, 0, $bitmap.Width, $bitmap.Height))
            if (-not $localRect.IsEmpty) {
                $regionBitmap = $bitmap.Clone($localRect, $bitmap.PixelFormat)
                try { $regionBitmap.Save($cropPath, [System.Drawing.Imaging.ImageFormat]::Png) } finally { $regionBitmap.Dispose() }
            } else {
                $cropPath = ''
            }
        } else {
            $cropPath = ''
        }

        $clickRect = [System.Drawing.Rectangle]::new($Point.X - $screenBounds.Left - 80, $Point.Y - $screenBounds.Top - 80, 160, 160)
        $clickRect.Intersect([System.Drawing.Rectangle]::new(0, 0, $bitmap.Width, $bitmap.Height))
        if (-not $clickRect.IsEmpty) {
            $clickBitmap = $bitmap.Clone($clickRect, $bitmap.PixelFormat)
            try { $clickBitmap.Save($clickPath, [System.Drawing.Imaging.ImageFormat]::Png) } finally { $clickBitmap.Dispose() }
        } else {
            $clickPath = ''
        }
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }

    return [pscustomobject]@{
        Full = $fullPath
        Region = $cropPath
        Click = $clickPath
    }
}

function Write-RecordHeader {
    $header = 'timestamp,button,x,y,slot,nearest_slot,nearest_distance,region_x,region_y,region_width,region_height,active_window,full_image,region_image,click_image'
    [System.IO.File]::WriteAllText($script:RecordCsv, $header + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
}

function Escape-Csv([string]$Text) {
    if ($null -eq $Text) { return '""' }
    return '"' + $Text.Replace('"', '""') + '"'
}

function Write-ClickRecord([string]$Button, [System.Drawing.Point]$Point) {
    $slotItem = Find-ContainingSlot $Point
    if ($null -eq $slotItem) {
        $script:IgnoredCount++
        $statusLabel.Text = "제외 영역 클릭 무시: $($Point.X), $($Point.Y) / 기록 $script:ClickCount, 무시 $script:IgnoredCount"
        return
    }

    $nearest = Get-NearestSlot $Point
    $stamp = Get-NowStamp
    $images = Save-ScreenImages $Point $slotItem $stamp
    $activeTitle = Get-ActiveWindowTitle
    $distanceText = if ($nearest.Distance -eq [double]::MaxValue) { '' } else { '{0:F2}' -f $nearest.Distance }
    $nearestSlotName = if ($null -ne $nearest.Slot) { $nearest.Slot.Slot } else { '' }

    $values = @(
        (Escape-Csv ((Get-Date).ToString('o'))),
        (Escape-Csv $Button),
        $Point.X,
        $Point.Y,
        (Escape-Csv $slotItem.Slot),
        (Escape-Csv $nearestSlotName),
        (Escape-Csv $distanceText),
        $slotItem.Rect.X,
        $slotItem.Rect.Y,
        $slotItem.Rect.Width,
        $slotItem.Rect.Height,
        (Escape-Csv $activeTitle),
        (Escape-Csv $images.Full),
        (Escape-Csv $images.Region),
        (Escape-Csv $images.Click)
    )
    [System.IO.File]::AppendAllText($script:RecordCsv, (($values -join ',') + [Environment]::NewLine), [System.Text.Encoding]::UTF8)
    $script:ClickCount++
    $statusLabel.Text = "기록됨: $($slotItem.Slot) / $Button / $($Point.X), $($Point.Y) / 기록 $script:ClickCount, 무시 $script:IgnoredCount"
}

function Start-TestRecording {
    Load-SlotRegions
    if (-not (Test-Path -LiteralPath $script:RecordRoot)) {
        [void][System.IO.Directory]::CreateDirectory($script:RecordRoot)
    }
    $sessionName = 'interaction_' + (Get-Date).ToString('yyyyMMdd_HHmmss')
    $script:SessionDir = Join-Path $script:RecordRoot $sessionName
    [void][System.IO.Directory]::CreateDirectory($script:SessionDir)
    $script:RecordCsv = Join-Path $script:SessionDir 'interaction_records.csv'
    Write-RecordHeader
    Copy-Item -LiteralPath (Join-Path $script:MaskRoot 'slot_regions.csv') -Destination (Join-Path $script:SessionDir 'slot_regions_snapshot.csv') -Force
    Copy-Item -LiteralPath (Join-Path $script:MaskRoot 'slot_points.csv') -Destination (Join-Path $script:SessionDir 'slot_points_snapshot.csv') -Force
    $script:ClickCount = 0
    $script:IgnoredCount = 0
    $script:LastLeftDown = $false
    $script:LastRightDown = $false
    $script:Recording = $true
    $timer.Start()
    $startButton.Enabled = $false
    $stopButton.Enabled = $true
    $statusLabel.Text = "테스트 기록 중: $script:SessionDir"
    Refresh-SlotList
}

function Stop-TestRecording {
    $script:Recording = $false
    $timer.Stop()
    $startButton.Enabled = $true
    $stopButton.Enabled = $false
    $statusLabel.Text = "테스트 정지: 기록 $script:ClickCount, 무시 $script:IgnoredCount / $script:SessionDir"
}

function Refresh-SlotList {
    $slotList.Items.Clear()
    foreach ($item in $script:SlotRegions) {
        [void]$slotList.Items.Add(('{0}  X={1}, Y={2}, W={3}, H={4}' -f $item.Slot, $item.Rect.X, $item.Rect.Y, $item.Rect.Width, $item.Rect.Height))
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Gerinogi Interaction Recorder'
$form.Width = 560
$form.Height = 520
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true

$title = New-Object System.Windows.Forms.Label
$title.Text = '자동제외 영역 기반 수동 클릭 기록기'
$title.Left = 12
$title.Top = 12
$title.Width = 500
$title.Height = 24
$title.Font = New-Object System.Drawing.Font -ArgumentList '맑은 고딕', 11, ([System.Drawing.FontStyle]::Bold)
$form.Controls.Add($title)

$pathLabel = New-Object System.Windows.Forms.Label
$pathLabel.Text = "설정 참조: $script:MaskRoot"
$pathLabel.Left = 12
$pathLabel.Top = 42
$pathLabel.Width = 520
$pathLabel.Height = 22
$form.Controls.Add($pathLabel)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = '테스트 시작'
$startButton.Left = 12
$startButton.Top = 72
$startButton.Width = 130
$startButton.Height = 34
$startButton.Add_Click({ try { Start-TestRecording } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, '오류') } })
$form.Controls.Add($startButton)

$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Text = '테스트 정지'
$stopButton.Left = 150
$stopButton.Top = 72
$stopButton.Width = 130
$stopButton.Height = 34
$stopButton.Enabled = $false
$stopButton.Add_Click({ Stop-TestRecording })
$form.Controls.Add($stopButton)

$openButton = New-Object System.Windows.Forms.Button
$openButton.Text = '기록 폴더 열기'
$openButton.Left = 288
$openButton.Top = 72
$openButton.Width = 130
$openButton.Height = 34
$openButton.Add_Click({
    if (-not (Test-Path -LiteralPath $script:RecordRoot)) { [void][System.IO.Directory]::CreateDirectory($script:RecordRoot) }
    Start-Process explorer.exe $script:RecordRoot
})
$form.Controls.Add($openButton)

$reloadButton = New-Object System.Windows.Forms.Button
$reloadButton.Text = '영역 새로고침'
$reloadButton.Left = 426
$reloadButton.Top = 72
$reloadButton.Width = 110
$reloadButton.Height = 34
$reloadButton.Add_Click({ try { Load-SlotRegions; Refresh-SlotList; $statusLabel.Text = "영역 로드: $($script:SlotRegions.Count)개" } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, '오류') } })
$form.Controls.Add($reloadButton)

$slotList = New-Object System.Windows.Forms.ListBox
$slotList.Left = 12
$slotList.Top = 120
$slotList.Width = 524
$slotList.Height = 280
$form.Controls.Add($slotList)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Left = 12
$statusLabel.Top = 414
$statusLabel.Width = 524
$statusLabel.Height = 44
$statusLabel.Text = '대기 중. 테스트 시작 후 등록된 슬롯 영역 안에서 발생한 클릭만 기록합니다.'
$form.Controls.Add($statusLabel)

$versionLabel = New-Object System.Windows.Forms.Label
$versionLabel.Left = 12
$versionLabel.Top = 462
$versionLabel.Width = 300
$versionLabel.Height = 22
$versionLabel.Text = "버전 $script:AppVersion"
$form.Controls.Add($versionLabel)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 20
$timer.Add_Tick({
    if (-not $script:Recording) { return }
    $point = Get-CursorPoint
    $leftDown = (([NativeInputProbe]::GetAsyncKeyState(0x01) -band 0x8000) -ne 0)
    $rightDown = (([NativeInputProbe]::GetAsyncKeyState(0x02) -band 0x8000) -ne 0)
    if ($leftDown -and -not $script:LastLeftDown) {
        Write-ClickRecord 'Left' $point
    }
    if ($rightDown -and -not $script:LastRightDown) {
        Write-ClickRecord 'Right' $point
    }
    $script:LastLeftDown = $leftDown
    $script:LastRightDown = $rightDown
})

$form.Add_Shown({ try { Load-SlotRegions; Refresh-SlotList; $statusLabel.Text = "영역 로드: $($script:SlotRegions.Count)개" } catch { $statusLabel.Text = $_.Exception.Message } })
$form.Add_FormClosing({ if ($script:Recording) { Stop-TestRecording } })

[void][System.Windows.Forms.Application]::Run($form)
