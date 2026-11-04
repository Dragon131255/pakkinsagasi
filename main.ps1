# パッキン探し：起動・画面（WinForms）

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Search.ps1"

$table = @(Get-ORingTable -Path "$PSScriptRoot\data\oring_jis_b2401.csv")

[System.Windows.Forms.Application]::EnableVisualStyles()

# 配色（図の寸法線と入力欄のラベルで同じ色を使う）
function RGB($hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
$colInner  = RGB '#1E88E5'   # d 溝の内径
$colOuter  = RGB '#43A047'   # D 溝の外径
$colWidth  = RGB '#FB8C00'   # G 溝幅
$colDepth  = RGB '#8E24AA'   # H 溝深さ
$colRing   = RGB '#E53935'   # Oリング
$colMain   = RGB '#1565C0'   # 見出し・ボタン
$colBg     = RGB '#F3F6FB'

$form = New-Object System.Windows.Forms.Form
$form.Text = 'パッキン探し（JIS B 2401 Oリング）'
$form.ClientSize = New-Object System.Drawing.Size(745, 740)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Yu Gothic UI', 10)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = $colBg
$iconPath = "$PSScriptRoot\pakkinsagasi.ico"
if (Test-Path $iconPath) { $form.Icon = New-Object System.Drawing.Icon $iconPath }

# 見出しの帯
$header = New-Object System.Windows.Forms.Label
$header.Text = '  ◎ パッキン探し　─　JIS B 2401 Oリング選定'
$header.Dock = 'Top'
$header.Height = 44
$header.TextAlign = 'MiddleLeft'
$header.BackColor = $colMain
$header.ForeColor = [System.Drawing.Color]::White
$header.Font = New-Object System.Drawing.Font('Yu Gothic UI', 13, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($header)

function New-Label($text, $x, $y, $color) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.AutoSize = $true
    if ($color) {
        $l.ForeColor = $color
        $l.Font = New-Object System.Drawing.Font('Yu Gothic UI', 10, [System.Drawing.FontStyle]::Bold)
    }
    $form.Controls.Add($l)
}

function New-Input($x, $y) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x, $y)
    $t.Width = 100
    $form.Controls.Add($t)
    $t
}

New-Label '● d 溝の内径 [mm]' 20 68 $colInner
$txtInner = New-Input 190 65
New-Label '● D 溝の外径 [mm]' 20 103 $colOuter
$txtOuter = New-Input 190 100
New-Label '● G 溝幅 [mm]' 20 138 $colWidth
$txtWidth = New-Input 190 135
New-Label '用途' 20 173

$cmbUse = New-Object System.Windows.Forms.ComboBox
$cmbUse.Location = New-Object System.Drawing.Point(190, 170)
$cmbUse.Width = 100
$cmbUse.DropDownStyle = 'DropDownList'
[void]$cmbUse.Items.AddRange(@('運動用', '固定用'))
$cmbUse.SelectedIndex = 1
$form.Controls.Add($cmbUse)

$colBR = RGB '#37474F'   # バックアップリング
New-Label '● バックアップリング' 20 208 $colBR
$cmbBR = New-Object System.Windows.Forms.ComboBox
$cmbBR.Location = New-Object System.Drawing.Point(190, 205)
$cmbBR.Width = 100
$cmbBR.DropDownStyle = 'DropDownList'
[void]$cmbBR.Items.AddRange(@('なし', '片側', '両側'))
$cmbBR.SelectedIndex = 0
$form.Controls.Add($cmbBR)

New-Label '空欄の寸法は判定に使いません' 128 247

$btn = New-Object System.Windows.Forms.Button
$btn.Text = '検索'
$btn.Location = New-Object System.Drawing.Point(20, 240)
$btn.Size = New-Object System.Drawing.Size(100, 32)
$btn.FlatStyle = 'Flat'
$btn.FlatAppearance.BorderSize = 0
$btn.BackColor = $colMain
$btn.ForeColor = [System.Drawing.Color]::White
$btn.Font = New-Object System.Drawing.Font('Yu Gothic UI', 10, [System.Drawing.FontStyle]::Bold)
$btn.Cursor = 'Hand'
$form.Controls.Add($btn)
$form.AcceptButton = $btn

# 溝の断面図（軸側に溝がある場合）
$fig = New-Object System.Windows.Forms.Panel
$fig.Location = New-Object System.Drawing.Point(330, 56)
$fig.Size = New-Object System.Drawing.Size(395, 215)
$fig.BackColor = [System.Drawing.Color]::White
$fig.BorderStyle = 'FixedSingle'
$fig.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'Instance,NonPublic').SetValue($fig, $true, $null)
$form.Controls.Add($fig)

function Draw-Dim($g, $color, $x1, $y1, $x2, $y2) {
    # 両矢印の寸法線
    $p = New-Object System.Drawing.Pen $color, 1.6
    $cap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap 4, 5
    $p.CustomStartCap = $cap; $p.CustomEndCap = $cap
    $g.DrawLine($p, $x1, $y1, $x2, $y2)
    $p.Dispose()
}

function Draw-Text($g, $text, $color, $x, $y, $bold) {
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $f = New-Object System.Drawing.Font('Yu Gothic UI', 9, $style)
    $b = New-Object System.Drawing.SolidBrush $color
    $g.DrawString($text, $f, $b, [single]$x, [single]$y)
    $f.Dispose(); $b.Dispose()
}

function Get-FigValue($textBox) {
    $s = $textBox.Text.Trim()
    if ($s -eq '') { '' } else { " = $s" }
}

$fig.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'ClearTypeGridFit'

    $gx1 = 170; $gx2 = 280       # 溝の左右の壁（G）
    $yBore = 48                  # 相手側（穴）の面 = D
    $yShaft = 70                 # 軸の外周面
    $yBottom = 128               # 溝底 = d
    $yCenter = 205               # 中心線

    # 相手側（穴・シリンダー）
    $boreBrush = New-Object System.Drawing.Drawing2D.HatchBrush 'BackwardDiagonal', (RGB '#90A4AE'), (RGB '#ECEFF1')
    $g.FillRectangle($boreBrush, 0, 20, 395, $yBore - 20)
    $g.DrawLine([System.Drawing.Pens]::SlateGray, 0, $yBore, 395, $yBore)
    Draw-Text $g '相手側（穴）' (RGB '#455A64') 6 24 $true

    # 軸（溝を切った形）
    $body = New-Object System.Drawing.Drawing2D.GraphicsPath
    $pts = @(
        (New-Object System.Drawing.PointF 0, $yShaft),
        (New-Object System.Drawing.PointF $gx1, $yShaft),
        (New-Object System.Drawing.PointF $gx1, $yBottom),
        (New-Object System.Drawing.PointF $gx2, $yBottom),
        (New-Object System.Drawing.PointF $gx2, $yShaft),
        (New-Object System.Drawing.PointF 395, $yShaft),
        (New-Object System.Drawing.PointF 395, $yCenter),
        (New-Object System.Drawing.PointF 0, $yCenter))
    $body.AddPolygon([System.Drawing.PointF[]]$pts)
    $shaftBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, $yShaft, 395, ($yCenter - $yShaft)), (RGB '#CFD8DC'), (RGB '#90A4AE'), 90.0
    $g.FillPath($shaftBrush, $body)
    $g.DrawPath([System.Drawing.Pens]::SlateGray, $body)
    Draw-Text $g '軸' (RGB '#37474F') 6 ($yShaft + 4) $true

    # バックアップリング（片側は右＝低圧側、両側は左右）
    $brW = 16
    $ox1 = $gx1 + 10; $ox2 = $gx2 - 10
    $brSides = switch ($cmbBR.SelectedIndex) { 1 { @('R') } 2 { @('L', 'R') } default { @() } }
    $brBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, $yBore, 10, ($yBottom - $yBore)), (RGB '#78909C'), $colBR, 0.0
    foreach ($side in $brSides) {
        $bx = if ($side -eq 'L') { $gx1 } else { $gx2 - $brW }
        $g.FillRectangle($brBrush, [single]$bx, [single]$yBore, [single]$brW, [single]($yBottom - $yBore))
        $g.DrawRectangle([System.Drawing.Pens]::Black, [single]$bx, [single]$yBore, [single]$brW, [single]($yBottom - $yBore))
        if ($side -eq 'L') { $ox1 = $gx1 + $brW + 2 } else { $ox2 = $gx2 - $brW - 2 }
    }
    if ($brSides.Count -gt 0) { Draw-Text $g 'BR' $colBR ($gx2 + 3) ($yBottom - 44) $true }
    $brBrush.Dispose()

    # Oリング（溝内で少しつぶれた楕円）
    $ringRect = New-Object System.Drawing.RectangleF $ox1, $yBore, ($ox2 - $ox1), ($yBottom - $yBore)
    $ringBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $ringRect, (RGB '#FF8A80'), (RGB '#B71C1C'), 45.0
    $g.FillEllipse($ringBrush, $ringRect)
    $g.DrawEllipse((New-Object System.Drawing.Pen (RGB '#7F0000'), 1.2), $ringRect)
    Draw-Text $g 'Oリング' $colRing 108 ($yBore + 2) $true

    # 中心線
    $cl = New-Object System.Drawing.Pen (RGB '#607D8B'), 1
    $cl.DashStyle = 'DashDot'
    $g.DrawLine($cl, 0, $yCenter - 2, 395, $yCenter - 2)
    Draw-Text $g '中心線' (RGB '#607D8B') 340 ($yCenter - 18) $false

    # D：中心線 → 穴の面
    Draw-Dim $g $colOuter 30 ($yCenter - 2) 30 $yBore
    Draw-Text $g ('D 溝の外径' + (Get-FigValue $txtOuter)) $colOuter 36 ($yShaft + 26) $true

    # d：中心線 → 溝底（溝の下に延長線）
    $ext = New-Object System.Drawing.Pen (RGB '#B0BEC5'), 1
    $ext.DashStyle = 'Dash'
    $g.DrawLine($ext, 140, $yBottom, $gx1, $yBottom)
    Draw-Dim $g $colInner 150 ($yCenter - 2) 150 $yBottom
    Draw-Text $g ('d 溝の内径' + (Get-FigValue $txtInner)) $colInner 156 ($yBottom + 50) $true

    # G：溝幅（溝の下に延長線を引いて寸法を入れる）
    $g.DrawLine($ext, $gx1, $yBottom, $gx1, $yBottom + 26)
    $g.DrawLine($ext, $gx2, $yBottom, $gx2, $yBottom + 26)
    Draw-Dim $g $colWidth $gx1 ($yBottom + 20) $gx2 ($yBottom + 20)
    Draw-Text $g ('G 溝幅' + (Get-FigValue $txtWidth)) $colWidth ($gx1 + 70) ($yBottom + 30) $true

    # H：溝深さ（穴の面 → 溝底）
    $g.DrawLine($ext, $gx2, $yBottom, $gx2 + 50, $yBottom)
    Draw-Dim $g $colDepth ($gx2 + 40) $yBore ($gx2 + 40) $yBottom
    Draw-Text $g 'H 溝深さ' $colDepth ($gx2 + 46) ($yBottom - 22) $true
    Draw-Text $g 'H = (D − d) / 2' $colDepth ($gx2 + 8) ($yBottom + 2) $false

    Draw-Text $g '溝の断面図（軸に溝を切る場合）' (RGB '#263238') 6 2 $true

    $boreBrush.Dispose(); $shaftBrush.Dispose(); $ringBrush.Dispose(); $cl.Dispose(); $ext.Dispose(); $body.Dispose()
})

# 入力したら図の数値を更新
foreach ($t in @($txtInner, $txtOuter, $txtWidth)) { $t.Add_TextChanged({ $fig.Invalidate() }) }
$cmbBR.Add_SelectedIndexChanged({ $fig.Invalidate() })

$list = New-Object System.Windows.Forms.ListView
$list.Location = New-Object System.Drawing.Point(20, 285)
$list.Size = New-Object System.Drawing.Size(705, 300)
$list.View = 'Details'
$list.FullRowSelect = $true
$list.GridLines = $true
[void]$list.Columns.Add('呼び番号', 80)
[void]$list.Columns.Add('線径 d2', 75)
[void]$list.Columns.Add('内径 d1', 75)
[void]$list.Columns.Add('溝内径 d（公差）', 155)
[void]$list.Columns.Add('溝外径 D（公差）', 155)
[void]$list.Columns.Add('溝幅 G（公差）', 140)
$form.Controls.Add($list)

$msg = New-Object System.Windows.Forms.TextBox
$msg.Location = New-Object System.Drawing.Point(20, 595)
$msg.Size = New-Object System.Drawing.Size(705, 130)
$msg.BackColor = RGB '#FFF8E1'
$msg.Multiline = $true
$msg.ReadOnly = $true
$msg.ScrollBars = 'Vertical'
$form.Controls.Add($msg)

function Read-Number($textBox, $label) {
    $s = $textBox.Text.Trim()
    if ($s -eq '') { return $null }   # 未入力は判定に使わない
    $v = 0.0
    if (-not [double]::TryParse($s, [ref]$v)) {
        throw "$label に数値を入力してください。"
    }
    $v
}

$btn.Add_Click({
    $list.Items.Clear()
    $msg.Text = ''
    try {
        $inner = Read-Number $txtInner '溝の内径'
        $outer = Read-Number $txtOuter '溝の外径'
        $width = Read-Number $txtWidth '溝幅'
        $use = if ($cmbUse.SelectedItem -eq '運動用') { 'Dynamic' } else { 'Static' }

        $br = @('None', 'One', 'Both')[$cmbBR.SelectedIndex]
        $result = Find-ORing -GrooveInner $inner -GrooveOuter $outer -GrooveWidth $width -Use $use -Table $table -BackupRing $br

        # P系列・G系列をグループに分けて表示
        $list.Groups.Clear()
        $groups = @{}
        foreach ($s in @($result.Candidates | ForEach-Object { $_.Series } | Select-Object -Unique)) {
            $n = @($result.Candidates | Where-Object { $_.Series -eq $s }).Count
            $groups[$s] = $list.Groups.Add($s, "$s系列（$n 件）")
        }
        $rank = @{}
        foreach ($r in $result.Candidates) {
            $i = [int]$rank[$r.Series]; $rank[$r.Series] = $i + 1
            $item = New-Object System.Windows.Forms.ListViewItem($r.Name)
            $item.Group = $groups[$r.Series]
            [void]$item.SubItems.Add(('{0:N1}' -f $r.D2))
            [void]$item.SubItems.Add(('{0:N1}' -f $r.D1))
            # 溝設計の標準寸法（公差）
            foreach ($pair in @(@($r.StdInner, $r.TolInner), @($r.StdOuter, $r.TolOuter), @($r.StdWidth, $r.TolWidth))) {
                $v = if ($null -ne $pair[0]) { '{0:0.0#}' -f $pair[0] } else { '—' }
                [void]$item.SubItems.Add("$v（$($pair[1])）")
            }
            # 各系列の1位は緑、以降は1行おきに薄い青
            $item.BackColor = if ($i -eq 0) { RGB '#C8E6C9' }
                              elseif ($i % 2 -eq 1) { RGB '#E3F2FD' }
                              else { [System.Drawing.Color]::White }
            if ($i -eq 0) { $item.Font = New-Object System.Drawing.Font('Yu Gothic UI', 10, [System.Drawing.FontStyle]::Bold) }
            [void]$list.Items.Add($item)
        }

        $lines = @()
        if ($null -ne $result.GrooveDepth) { $lines += ('溝深さ {0:N2} mm' -f $result.GrooveDepth) }
        $lines += '判定条件：' + ($result.Notes -join ' / ')
        if ($result.Candidates.Count -eq 0) {
            $lines += '条件に合うOリングはありませんでした。'
            $lines += $result.Reasons
        } else {
            $order = if ($null -ne $inner) { '内径の伸びが小さい順' }
                     elseif ($null -ne $outer) { 'つぶし率が推奨範囲の中央に近い順' }
                     else { '溝充填率が上限に近い順' }
            $lines += "$($result.Candidates.Count) 件見つかりました（系列ごとに最大 $MaxResults 件、$order）。"
        }
        $msg.Text = $lines -join "`r`n"
    } catch {
        $msg.Text = $_.Exception.Message
    }
})

[void]$form.ShowDialog()
