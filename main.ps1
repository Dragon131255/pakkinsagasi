# パッキン探し：起動・画面（WinForms）

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Search.ps1"

$table = @(Get-ORingTable -Path "$PSScriptRoot\data\oring_jis_b2401.csv")
$ptable = @(Get-PackingTable -Path "$PSScriptRoot\data\sakagami_hydraulic.csv")
$dtable = @(Get-PackingTable -Path "$PSScriptRoot\data\dust_seal.csv")

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
$form.Text = 'パッキン探し（JIS B 2401 Oリング・Uパッキン・ダストシール）'
$form.ClientSize = New-Object System.Drawing.Size(945, 760)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Yu Gothic UI', 10)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = $colBg
$iconPath = "$PSScriptRoot\pakkinsagasi.ico"
if (Test-Path $iconPath) { $form.Icon = New-Object System.Drawing.Icon $iconPath }

# 見出しの帯
$header = New-Object System.Windows.Forms.Label
$header.Text = '  ◎ パッキン探し　─　Oリング・油圧パッキン選定'
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

New-Label '種類' 20 68
$cmbKind = New-Object System.Windows.Forms.ComboBox
$cmbKind.Location = New-Object System.Drawing.Point(190, 65)
$cmbKind.Width = 130
$cmbKind.DropDownStyle = 'DropDownList'
[void]$cmbKind.Items.AddRange(@('Oリング', 'Uパッキン', 'ダストシール'))
$cmbKind.SelectedIndex = 0
$form.Controls.Add($cmbKind)

New-Label '● d 溝の内径 [mm]' 20 100 $colInner
$lblInner = $form.Controls[$form.Controls.Count - 1]   # ダストシールのときは「ロッド径」にする
$txtInner = New-Input 190 97
New-Label '● D 溝の外径 [mm]' 20 132 $colOuter
$lblOuter = $form.Controls[$form.Controls.Count - 1]   # ダストシールのときは D・G を隠す（ロッド径だけで検索）
$txtOuter = New-Input 190 129
New-Label '● G 溝幅 [mm]' 20 164 $colWidth
$lblWidth = $form.Controls[$form.Controls.Count - 1]
$txtWidth = New-Input 190 161
New-Label '用途' 20 196

$cmbUse = New-Object System.Windows.Forms.ComboBox
$cmbUse.Location = New-Object System.Drawing.Point(190, 193)
$cmbUse.Width = 100
$cmbUse.DropDownStyle = 'DropDownList'
[void]$cmbUse.Items.AddRange(@('運動用', '固定用'))
$cmbUse.SelectedIndex = 1
$form.Controls.Add($cmbUse)

$colBR = RGB '#37474F'   # バックアップリング
New-Label '● バックアップリング' 20 228 $colBR
$cmbBR = New-Object System.Windows.Forms.ComboBox
$cmbBR.Location = New-Object System.Drawing.Point(190, 225)
$cmbBR.Width = 100
$cmbBR.DropDownStyle = 'DropDownList'
[void]$cmbBR.Items.AddRange(@('なし', '片側', '両側'))
$cmbBR.SelectedIndex = 0
$form.Controls.Add($cmbBR)

# 呼び番号で探す（入れたときは寸法を使わない）
New-Label '検索' 150 269
$txtName = New-Object System.Windows.Forms.TextBox
$txtName.Location = New-Object System.Drawing.Point(190, 266)
$txtName.Width = 130
$form.Controls.Add($txtName)
$tip = New-Object System.Windows.Forms.ToolTip
$tip.SetToolTip($txtName, '一部だけでも探せます（例 P20、SKY40）。入れたときは寸法を使いません')

$btn = New-Object System.Windows.Forms.Button
$btn.Text = '検索'
$btn.Location = New-Object System.Drawing.Point(20, 262)
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

# 製品のメーカー名（検索結果の一覧に出す）
function Get-Maker($product) {
    if ($ValquaProducts -contains $product) { 'バルカー' } elseif ($NokProducts -contains $product) { 'NOK' } else { '阪上製作所' }
}

function Draw-Text($g, $text, $color, $x, $y, $bold) {
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $f = New-Object System.Drawing.Font('Yu Gothic UI', 9, $style)
    $b = New-Object System.Drawing.SolidBrush $color
    $g.DrawString($text, $f, $b, [single]$x, [single]$y)
    $f.Dispose(); $b.Dispose()
}

# Oリングの断面図：選んだ結果があるとき、寸法の文字（d・D・G）を色付きの枠で囲む
function Draw-OringMark($g, $text, $color, $x, $y, $key) {
    $m = $script:figMark
    if (-not $m -or -not (@($m.Vals) | Where-Object { $_.k -ceq $key })) { return }
    $f = New-Object System.Drawing.Font('Yu Gothic UI', 9, [System.Drawing.FontStyle]::Bold)
    $sz = $g.MeasureString($text, $f); $f.Dispose()
    $fill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(50, $color))
    $pen = New-Object System.Drawing.Pen $color, 2
    $g.FillRectangle($fill, [single]($x - 2), [single]($y - 1), [single]($sz.Width + 2), [single]($sz.Height + 2))
    $g.DrawRectangle($pen, [single]($x - 2), [single]($y - 1), [single]($sz.Width + 2), [single]($sz.Height + 2))
    $fill.Dispose(); $pen.Dispose()
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

    # 阪上パッキンのときは阪上製作所の寸法指示図を出す（クリックでピストン用／ロッド用、検索結果の行を選ぶと製品を切り替え）
    if ($cmbKind.SelectedIndex -ge 1) {
        $p = $script:figProduct
        # 図がない製品（ダストシールなど）は図の代わりに案内を出す
        if (-not $p -or -not $figImages.ContainsKey($p) -or -not ($figImages[$p].Piston -or $figImages[$p].Rod)) {
            $t = if ($p) { "$p の寸法指示図はありません" } else { '検索すると製品の寸法指示図を表示します' }
            Draw-Text $g $t (RGB '#607D8B') 6 2 $true
            return
        }
        $useRod = $script:figRod
        # ピストン用だけ・ロッド用だけの製品（UHP・MLP・MLR）は、ある方の図を出す
        if (-not $figImages[$p][$(if ($useRod) { 'Rod' } else { 'Piston' })]) { $useRod = -not $useRod }
        $img = $figImages[$p][$(if ($useRod) { 'Rod' } else { 'Piston' })]
        $title = "$p 寸法指示図（" + $(if ($useRod) { 'ロッド用' } else { 'ピストン用' }) + '）'
        Draw-Text $g $title (RGB '#263238') 6 2 $true
        if ($figImages[$p]['Piston'] -and $figImages[$p]['Rod']) { Draw-Text $g 'クリックで切替' (RGB '#607D8B') 300 2 $false }
        if ($img) {
            $g.InterpolationMode = 'HighQualityBicubic'
            # 枠（幅 ClientSize−8、高さ 168）に収まるように縮小（縦長の図は高さに合わせる）
            $w = $fig.ClientSize.Width - 8
            $h = [int]($img.Height * $w / $img.Width)
            if ($h -gt 168) { $h = 168; $w = [int]($img.Width * $h / $img.Height) }
            $ox = 4 + [int](($fig.ClientSize.Width - 8 - $w) / 2); $oy = 24 + [int]((168 - $h) / 2)
            $g.DrawImage($img, $ox, $oy, $w, $h)
            # 選んだ行の寸法を図の記号の場所に色付きの枠で示し、図の右下に数値を出す（Uパッキン・ダストシール）
            $m = $script:figMark
            $key = "$($p.ToLower())-" + $(if ($useRod) { 'rod' } else { 'piston' })
            if ($m -and $m.Product -eq $p -and $FigMarks.ContainsKey($key)) {
                $k = $w / $img.Width
                $bf = New-Object System.Drawing.Font('Yu Gothic UI', 9, [System.Drawing.FontStyle]::Bold)
                $tx = $fig.ClientSize.Width - 6
                $vals = @($m.Vals); [array]::Reverse($vals)   # 右から詰めて書く
                foreach ($x in $vals) {
                    $c = $MarkColors[$x.k]
                    $b = $FigMarks[$key][$x.k]
                    if ($b) {
                        $rx = $ox + $b[0] * $k; $ry = $oy + $b[1] * $k; $rw = $b[2] * $k; $rh = $b[3] * $k
                        $fill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(50, $c))
                        $pen = New-Object System.Drawing.Pen $c, 2
                        $g.FillRectangle($fill, [single]$rx, [single]$ry, [single]$rw, [single]$rh)
                        $g.DrawRectangle($pen, [single]$rx, [single]$ry, [single]$rw, [single]$rh)
                        $fill.Dispose(); $pen.Dispose()
                    }
                    $t = "$($x.l)=$($x.v)"
                    $tx -= $g.MeasureString($t, $bf).Width
                    Draw-Text $g $t $c $tx 194 $true
                    $tx -= 2
                }
                $bf.Dispose()
            }
        }
        $src = if ($ValquaProducts -contains $p) { "出典：バルカー 油圧用パッキン カタログ $($p)シリーズ" }
               elseif ($NokProducts -contains $p) { "出典：NOK $($p)型 寸法表" }
               elseif ($DustProducts -contains $p) { "出典：阪上製作所 $($p) 製品ページ" }
               else { "出典：阪上製作所 $($p)パッキン 製品ページ" }
        Draw-Text $g $src (RGB '#90A4AE') 6 194 $false
        return
    }

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
    Draw-Text $g $(if ($cmbKind.SelectedIndex -ge 1) { 'パッキン' } else { 'Oリング' }) $colRing 108 ($yBore + 2) $true

    # 中心線
    $cl = New-Object System.Drawing.Pen (RGB '#607D8B'), 1
    $cl.DashStyle = 'DashDot'
    $g.DrawLine($cl, 0, $yCenter - 2, 395, $yCenter - 2)
    Draw-Text $g '中心線' (RGB '#607D8B') 340 ($yCenter - 18) $false

    # D：中心線 → 穴の面
    Draw-Dim $g $colOuter 30 ($yCenter - 2) 30 $yBore
    Draw-OringMark $g ('D 溝の外径' + (Get-FigValue $txtOuter)) $colOuter 36 ($yShaft + 26) 'D'
    Draw-Text $g ('D 溝の外径' + (Get-FigValue $txtOuter)) $colOuter 36 ($yShaft + 26) $true

    # d：中心線 → 溝底（溝の下に延長線）
    $ext = New-Object System.Drawing.Pen (RGB '#B0BEC5'), 1
    $ext.DashStyle = 'Dash'
    $g.DrawLine($ext, 140, $yBottom, $gx1, $yBottom)
    Draw-Dim $g $colInner 150 ($yCenter - 2) 150 $yBottom
    Draw-OringMark $g ('d 溝の内径' + (Get-FigValue $txtInner)) $colInner 156 ($yBottom + 50) 'd'
    Draw-Text $g ('d 溝の内径' + (Get-FigValue $txtInner)) $colInner 156 ($yBottom + 50) $true

    # G：溝幅（溝の下に延長線を引いて寸法を入れる）
    $g.DrawLine($ext, $gx1, $yBottom, $gx1, $yBottom + 26)
    $g.DrawLine($ext, $gx2, $yBottom, $gx2, $yBottom + 26)
    Draw-Dim $g $colWidth $gx1 ($yBottom + 20) $gx2 ($yBottom + 20)
    Draw-OringMark $g ('G 溝幅' + (Get-FigValue $txtWidth)) $colWidth ($gx1 + 70) ($yBottom + 30) 'W'
    Draw-Text $g ('G 溝幅' + (Get-FigValue $txtWidth)) $colWidth ($gx1 + 70) ($yBottom + 30) $true

    # 選んだOリングの標準溝寸法を右上に出す
    $m = $script:figMark
    if ($m) {
        $bf = New-Object System.Drawing.Font('Yu Gothic UI', 9, [System.Drawing.FontStyle]::Bold)
        $tx = $fig.ClientSize.Width - 6
        $vals = @($m.Vals); [array]::Reverse($vals)
        foreach ($x in $vals) {
            $t = "$($x.l)=$($x.v)"
            $tx -= $g.MeasureString($t, $bf).Width
            Draw-Text $g $t $MarkColors[$x.k] $tx 2 $true
            $tx -= 2
        }
        $t = "$($m.Product)："
        $tx -= $g.MeasureString($t, $bf).Width
        Draw-Text $g $t (RGB '#263238') $tx 2 $true
        $bf.Dispose()
    }

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

# 阪上パッキンの図（images/<製品>-piston.png・<製品>-rod.png に置いた寸法指示図）
$figImages = @{}
foreach ($p in @('SKY', 'KY', 'UHP', 'MLP', 'MLR', 'UPH') + $DustProducts) {
    $figImages[$p] = @{}
    foreach ($u in @('Piston', 'Rod')) {
        $f = "$PSScriptRoot\images\$($p.ToLower())-$($u.ToLower()).png"
        $figImages[$p][$u] = if (Test-Path $f) { [System.Drawing.Image]::FromFile($f) } else { $null }
    }
}
$script:figProduct = 'SKY'
$script:figRod = $false
# 寸法指示図で各寸法の記号がある場所（画像のピクセル座標 x, y, 幅, 高さ。キーは画像名。index.html の FIG_MARKS と同じ）
# ダストシール：D・W（溝幅）・C ／ Uパッキン：d・D1・GA・GB（UPH の図では HA・HB）
$FigMarks = @{
    'sdr-rod'    = @{ D = @(128, 240, 48, 110); W = @(214, 66, 88, 32); C = @(324, 238, 34, 110) }
    'dhs-rod'    = @{ D = @(264, 170, 40, 130); W = @(408, 48, 32, 26); C = @(494, 168, 32, 95) }
    'lbh-rod'    = @{ D = @(552, 385, 36, 88);  W = @(772, 22, 92, 32); C = @(904, 378, 34, 108) }
    'dki-rod'    = @{ D = @(562, 360, 38, 105); W = @(812, 14, 42, 32) }
    'sky-piston' = @{ d = @(452, 190, 36, 80); D1 = @(302, 178, 32, 115); GA = @(380, 170, 70, 28); GB = @(570, 170, 70, 28) }
    'sky-rod'    = @{ d = @(272, 205, 32, 75); GA = @(172, 48, 80, 30); GB = @(176, 396, 80, 30) }
    'ky-piston'  = @{ d = @(302, 135, 26, 70); D1 = @(192, 120, 26, 95); GA = @(242, 118, 58, 22); GB = @(377, 118, 58, 22) }
    'ky-rod'     = @{ d = @(322, 210, 32, 80); GA = @(172, 62, 82, 30); GB = @(172, 393, 82, 30) }
    'uhp-piston' = @{ d = @(420, 188, 30, 70); D1 = @(274, 175, 30, 85); GA = @(350, 178, 34, 26); GB = @(508, 178, 40, 26) }
    'mlp-piston' = @{ d = @(418, 182, 32, 70); D1 = @(270, 172, 30, 90); GA = @(344, 180, 38, 28); GB = @(500, 178, 46, 28) }
    'mlr-rod'    = @{ d = @(418, 118, 32, 72); GA = @(356, 8, 44, 28); GB = @(355, 294, 46, 30) }
    'uph-piston' = @{ d = @(442, 268, 30, 68); D1 = @(768, 243, 32, 90); GA = @(434, 502, 66, 26); GB = @(632, 502, 74, 26) }
    'uph-rod'    = @{ d = @(378, 298, 32, 100); GA = @(606, 592, 78, 28); GB = @(598, 48, 84, 28) }
}
# d と D を区別するため大文字小文字を区別する表にする（@{} は区別しない）
$MarkColors = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
$MarkColors['d'] = $colInner; $MarkColors['D'] = $colOuter; $MarkColors['D1'] = $colDepth; $MarkColors['C'] = $colDepth
$MarkColors['W'] = $colWidth; $MarkColors['GA'] = $colWidth; $MarkColors['GB'] = $colWidth
$script:figMark = $null   # 選んだ行の @{ Product; Vals = @( @{ k = 図のキー; l = 表示名; v = 値 }, ... ) }
$fig.Add_Click({
    if ($cmbKind.SelectedIndex -ge 1) { $script:figRod = -not $script:figRod; $fig.Invalidate() }
})

$list = New-Object System.Windows.Forms.ListView
$list.Location = New-Object System.Drawing.Point(20, 305)
$list.Size = New-Object System.Drawing.Size(905, 300)
$list.View = 'Details'
$list.FullRowSelect = $true
$list.GridLines = $true
# 列名を色付けするため見出しだけ自前で描く（行は標準の描画のまま）。ダストシールの D・G/H・C/S は図の枠と同じ色
$list.OwnerDraw = $true
$list.Add_DrawItem({ $_.DrawDefault = $true })
$list.Add_DrawSubItem({ $_.DrawDefault = $true })
$list.Add_DrawColumnHeader({
    $e = $_
    $e.DrawBackground()
    $t = $e.Header.Text
    # 列名の頭の記号で色を決める（Oリング：溝内径 d・溝外径 D・溝幅 G／Uパッキン：d・D1・GA/GB／ダストシール：D・G/H・C/S）
    $c = if ($t -clike 'd（*' -or $t -like '溝内径*') { $colInner } elseif ($t -clike 'D（*' -or $t -like '溝外径*') { $colOuter }
         elseif ($t -like 'G・H*' -or $t -clike 'G[AB]（*' -or $t -like '溝幅*') { $colWidth } elseif ($t -like 'C・S*' -or $t -clike 'D1（*') { $colDepth } else { $null }
    $f = if ($c) { New-Object System.Drawing.Font('Yu Gothic UI', 9, [System.Drawing.FontStyle]::Bold) } else { $e.Font }
    $r = New-Object System.Drawing.Rectangle ($e.Bounds.X + 4), $e.Bounds.Y, ($e.Bounds.Width - 4), $e.Bounds.Height
    [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $t, $f, $r, $(if ($c) { $c } else { [System.Drawing.SystemColors]::ControlText }),
        [System.Windows.Forms.TextFormatFlags]'Left, VerticalCenter, EndEllipsis')
    if ($c) { $f.Dispose() }
})
function Set-Columns {
    $list.Items.Clear(); $list.Groups.Clear(); $list.Columns.Clear()
    if ($cmbKind.SelectedIndex -eq 2) {
        # ダストシール：D・溝幅・C（バックアップリングは使わない。d は出さない。C＝データの D1Dia、LBH の図では S、DKI はなし）
        [void]$list.Columns.Add('呼び番号', 100)
        [void]$list.Columns.Add('D（公差）', 170)
        [void]$list.Columns.Add('G・H（公差）', 140)
        [void]$list.Columns.Add('C・S（公差）', 130)
        [void]$list.Columns.Add('メーカー', 90)
    } elseif ($cmbKind.SelectedIndex -eq 1) {
        [void]$list.Columns.Add('指示コード', 95)
        [void]$list.Columns.Add('使用箇所', 70)
        [void]$list.Columns.Add('d（公差）', 170)
        [void]$list.Columns.Add('D1（公差）', 95)
        [void]$list.Columns.Add('GA（公差）', 100)
        [void]$list.Columns.Add('バックアップリング', 110)
        [void]$list.Columns.Add('メーカー', 80)
    } else {
        [void]$list.Columns.Add('呼び番号', 80)
        [void]$list.Columns.Add('線径 d2', 75)
        [void]$list.Columns.Add('内径 d1', 75)
        [void]$list.Columns.Add('溝内径 d（公差）', 155)
        [void]$list.Columns.Add('溝外径 D（公差）', 155)
        [void]$list.Columns.Add('溝幅 G（公差）', 140)
    }
}
Set-Columns
$form.Controls.Add($list)

# 阪上パッキンの検索結果で行を選ぶと、図をその製品の寸法指示図にする（図がある製品だけ）
$list.Add_SelectedIndexChanged({
    if ($list.SelectedItems.Count -eq 0) { return }
    $script:figMark = $list.SelectedItems[0].Tag
    if ($cmbKind.SelectedIndex -lt 1) { $fig.Invalidate(); return }   # Oリング：断面図の d・D・G に枠を付け直す
    $grp = $list.SelectedItems[0].Group
    if ($grp -and $figImages.ContainsKey($grp.Name)) { $script:figProduct = $grp.Name; $fig.Invalidate() }
})

# 種類を切り替えたら一覧の列を入れ替える。阪上パッキンは運動用なので「用途」は使わない
$cmbKind.Add_SelectedIndexChanged({
    Set-Columns
    $cmbUse.Enabled = $cmbKind.SelectedIndex -eq 0
    $cmbBR.Enabled = $cmbKind.SelectedIndex -ne 2   # ダストシールはバックアップリングを使わない
    $lblInner.Text = if ($cmbKind.SelectedIndex -eq 2) { '● d ロッド径 [mm]' } else { '● d 溝の内径 [mm]' }
    foreach ($c in @($lblOuter, $txtOuter, $lblWidth, $txtWidth)) { $c.Visible = $cmbKind.SelectedIndex -ne 2 }
    $script:figProduct = if ($cmbKind.SelectedIndex -eq 1) { 'SKY' } else { '' }
    $script:figMark = $null
    $fig.Cursor = if ($cmbKind.SelectedIndex -ge 1) { 'Hand' } else { 'Default' }
    $msg.Text = ''
    $fig.Invalidate()
})

$msg = New-Object System.Windows.Forms.TextBox
$msg.Location = New-Object System.Drawing.Point(20, 615)
$msg.Size = New-Object System.Drawing.Size(905, 130)
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

# 件数の行。呼び番号で探したときは全件数と表示した件数を出す
function Get-CountLine($result, $how) {
    if (-not $result.ByName) { return "$($result.Candidates.Count) 件見つかりました$how。" }
    $t = "$($result.Total) 件見つかりました（一致の近い順）。"
    if ($result.Total -gt $result.Candidates.Count) { $t += "先頭 $($result.Candidates.Count) 件を表示しています。もう少し詳しく入れると絞り込めます。" }
    $t
}

$btn.Add_Click({
    $list.Items.Clear()
    $msg.Text = ''
    try {
        $name = $txtName.Text.Trim()   # 呼び番号を入れたときは寸法を読まない
        if ($name) { $inner = $null; $outer = $null; $width = $null } else {
            $inner = Read-Number $txtInner $(if ($cmbKind.SelectedIndex -eq 2) { 'ロッド径' } else { '溝の内径' })
            $outer = if ($cmbKind.SelectedIndex -eq 2) { $null } else { Read-Number $txtOuter '溝の外径' }   # ダストシールはロッド径だけ
            $width = if ($cmbKind.SelectedIndex -eq 2) { $null } else { Read-Number $txtWidth '溝幅' }
        }

        if ($cmbKind.SelectedIndex -eq 2) {
            # ダストシール：製品ごとにグループ表示（溝幅は GA で判定）
            $result = Find-Packing -GrooveInner $inner -GrooveOuter $outer -GrooveWidth $width -Table $dtable -Products $DustProducts -Label 'ダストシール' -Name $name
            $list.Groups.Clear()
            $groups = @{}; $rank = @{}
            foreach ($r in $result.Candidates) {
                if (-not $groups.ContainsKey($r.Product)) {
                    $n = @($result.Candidates | Where-Object { $_.Product -eq $r.Product }).Count
                    $groups[$r.Product] = $list.Groups.Add($r.Product, "$($r.Product)（$n 件）")
                }
                $i = [int]$rank[$r.Product]; $rank[$r.Product] = $i + 1
                $item = New-Object System.Windows.Forms.ListViewItem($r.Code)
                $item.Group = $groups[$r.Product]
                $vC = if ($r.DiaD1) { $(if ($r.Product -eq 'LBH') { 'S ' } else { 'C ' }) + $(if ($r.TolD1) { "$($r.DiaD1)（$($r.TolD1)）" } else { $r.DiaD1 }) } else { '—' }
                $wl = if (@('LBH', 'DKI') -contains $r.Product) { 'H' } else { 'G' }   # 溝幅の記号（図に合わせる）
                foreach ($v in @("$($r.D2)（$($r.TolOuter)）", "$wl $($r.Width)（$($r.TolWidth)）", $vC, (Get-Maker $r.Product))) {
                    [void]$item.SubItems.Add([string]$v)
                }
                $tv = @(@{ k = 'D'; l = 'D'; v = "$($r.D2)" }, @{ k = 'W'; l = $wl; v = "$($r.Width)" })
                if ($r.DiaD1 -and $r.Product -ne 'DKI') { $tv += @{ k = 'C'; l = $(if ($r.Product -eq 'LBH') { 'S' } else { 'C' }); v = "$($r.DiaD1)" } }
                $item.Tag = @{ Product = $r.Product; Vals = $tv }
                $item.BackColor = if ($i -eq 0) { RGB '#C8E6C9' } else { RGB '#E3F2FD' }
                if ($i -eq 0) { $item.Font = New-Object System.Drawing.Font('Yu Gothic UI', 10, [System.Drawing.FontStyle]::Bold) }
                [void]$list.Items.Add($item)
            }
            $lines = @('判定条件：' + ($result.Notes -join ' / '))
            if ($result.Candidates.Count -eq 0) { $lines += $result.Reasons }
            else {
                $lines += Get-CountLine $result "（製品ごとに最大 $MaxResults 件、寸法の差が小さい順）"
                $lines += $DustSourceNote
            }
            $msg.Text = $lines -join "`r`n"
            $script:figProduct = if ($result.Candidates.Count -gt 0) { $result.Candidates[0].Product } else { '' }
            $script:figMark = if ($list.Items.Count -gt 0) { $list.Items[0].Tag } else { $null }   # 最初は先頭の結果を図に示す
            $fig.Invalidate()
            return
        }
        if ($cmbKind.SelectedIndex -eq 1) {
            # 阪上パッキン：製品ごとにグループ表示
            $br = @('None', 'One', 'Both')[$cmbBR.SelectedIndex]
            $result = Find-Packing -GrooveInner $inner -GrooveOuter $outer -GrooveWidth $width -Table $ptable -BackupRing $br -Name $name
            # 溝幅の列名：バックアップリングなし＝GA、あり（片側・両側）＝GB
            $list.Columns[4].Text = if ($br -eq 'None') { 'GA（公差）' } else { 'GB（公差）' }
            $wk = if ($br -eq 'None') { 'GA' } else { 'GB' }
            $useName = @{ Piston = 'ピストン用'; Rod = 'ロッド用'; Both = '両用' }
            $list.Groups.Clear()
            $groups = @{}
            $rank = @{}
            foreach ($r in $result.Candidates) {
                if (-not $groups.ContainsKey($r.Product)) {
                    $n = @($result.Candidates | Where-Object { $_.Product -eq $r.Product }).Count
                    $groups[$r.Product] = $list.Groups.Add($r.Product, "$($r.Product)パッキン（$n 件）")
                }
                $i = [int]$rank[$r.Product]; $rank[$r.Product] = $i + 1
                $item = New-Object System.Windows.Forms.ListViewItem($r.Code)
                $item.Group = $groups[$r.Product]
                # 数値の後ろに公差を（ ）で付ける（両用はピストン用／ロッド用を並べる）
                $vd  = "$($r.D1)（$($r.TolInner)）"
                $vD1 = if ($r.DiaD1) { $(if ($r.TolD1) { "$($r.DiaD1)（$($r.TolD1)）" } else { $r.DiaD1 }) } else { '—' }
                $vW  = "$($r.Width)（$($r.TolWidth)）"
                foreach ($v in @($useName[$r.Use], $vd, $vD1, $vW, $(if ($r.Backup) { $r.Backup } else { '—' }), (Get-Maker $r.Product))) {
                    [void]$item.SubItems.Add([string]$v)
                }
                # 図に示す寸法（溝幅の記号は UPH の図では HA・HB）
                $tv = @(@{ k = 'd'; l = 'd'; v = "$($r.D1)" })
                if ($r.DiaD1) { $tv += @{ k = 'D1'; l = 'D1'; v = "$($r.DiaD1)" } }
                $tv += @{ k = $wk; l = $(if ($r.Product -eq 'UPH') { $wk -replace 'G', 'H' } else { $wk }); v = "$($r.Width)" }
                $item.Tag = @{ Product = $r.Product; Vals = $tv }
                $item.BackColor = if ($i -eq 0) { RGB '#C8E6C9' } else { RGB '#E3F2FD' }
                if ($i -eq 0) { $item.Font = New-Object System.Drawing.Font('Yu Gothic UI', 10, [System.Drawing.FontStyle]::Bold) }
                [void]$list.Items.Add($item)
            }
            $lines = @('判定条件：' + ($result.Notes -join ' / '))
            if ($result.Candidates.Count -eq 0) {
                $lines += $result.Reasons
            } else {
                $lines += Get-CountLine $result "（製品ごとに最大 $MaxResults 件、寸法の差が小さい順）"
                $lines += '出典：GPY〜KY は阪上製作所の製品ページ、UHP・MLP・MLR はバルカーの油圧用パッキン カタログ、UPH は NOK の UPH 型 寸法表。使用条件（圧力・速度・温度）は各社のカタログで確認してください。'
            }
            $msg.Text = $lines -join "`r`n"
            # 図は検索結果の先頭の製品にする
            if ($result.Candidates.Count -gt 0 -and $figImages.ContainsKey($result.Candidates[0].Product)) {
                $script:figProduct = $result.Candidates[0].Product
                $script:figMark = $list.Items[0].Tag   # 最初は先頭の結果を図に示す
                $fig.Invalidate()
            }
            return
        }
        $use = if ($cmbUse.SelectedItem -eq '運動用') { 'Dynamic' } else { 'Static' }

        $br = @('None', 'One', 'Both')[$cmbBR.SelectedIndex]
        $result = Find-ORing -GrooveInner $inner -GrooveOuter $outer -GrooveWidth $width -Use $use -Table $table -BackupRing $br -Name $name

        # P系列・G系列をグループに分けて表示
        $list.Groups.Clear()
        $groups = @{}
        foreach ($s in @($result.Candidates | ForEach-Object { $_.Series } | Select-Object -Unique)) {
            $n = @($result.Candidates | Where-Object { $_.Series -eq $s }).Count
            $groups[$s] = $list.Groups.Add($s, "$($s)系列（$n 件）")   # "$s系列" だと「s系列」という変数名になるので $() で囲む
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
            # 図に示す標準溝寸法（断面図の d・D・G の文字に枠を付ける）
            $item.Tag = @{ Product = $r.Name; Vals = @(
                @{ k = 'd'; l = 'd'; v = $(if ($null -ne $r.StdInner) { '{0:0.0#}' -f $r.StdInner } else { '—' }) },
                @{ k = 'D'; l = 'D'; v = $(if ($null -ne $r.StdOuter) { '{0:0.0#}' -f $r.StdOuter } else { '—' }) },
                @{ k = 'W'; l = 'G'; v = $(if ($null -ne $r.StdWidth) { '{0:0.0#}' -f $r.StdWidth } else { '—' }) }) }
            [void]$list.Items.Add($item)
        }
        $script:figMark = if ($list.Items.Count -gt 0) { $list.Items[0].Tag } else { $null }   # 最初は先頭の結果を図に示す
        $fig.Invalidate()

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
            $lines += Get-CountLine $result "（系列ごとに最大 $MaxResults 件、$order）"
        }
        $msg.Text = $lines -join "`r`n"
    } catch {
        $msg.Text = $_.Exception.Message
    }
})

[void]$form.ShowDialog()
