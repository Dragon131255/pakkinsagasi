# 計算・判定・並べ替え（画面に依存しない）
# 使う前に Config.ps1 をドットソースしておくこと

# 呼び番号の比較用：全角→半角、大文字にし、ハイフン・空白・* などを除く（例 'sky-40' → 'SKY40'、'ⓉSGY' → 'TSGY'）
function ConvertTo-NameKey([string]$s) {
    if ($null -eq $s) { return '' }
    ($s.Normalize([Text.NormalizationForm]::FormKC).ToUpperInvariant()) -replace '[\s\-_*・－ー]', ''
}

# 呼び番号が $Name と完全に一致する行があればそれだけを返す。なければ $Name を含む行を 前方一致 → 部分一致、表の順で返す
function Select-ByName {
    param([object[]]$Table, [string]$Property, [string]$Name)
    $key = ConvertTo-NameKey $Name
    $i = 0
    $hits = foreach ($r in $Table) {
        $k = ConvertTo-NameKey $r.$Property
        $i++
        if (-not $k.Contains($key)) { continue }
        $rank = if ($k -eq $key) { 0 } elseif ($k.StartsWith($key)) { 1 } else { 2 }
        [pscustomobject]@{ Row = $r; Rank = $rank; Order = $i }
    }
    $hits = @($hits)
    if (@($hits | Where-Object { $_.Rank -eq 0 }).Count -gt 0) { $hits = @($hits | Where-Object { $_.Rank -eq 0 }) }
    @($hits | Sort-Object Rank, Order | ForEach-Object { $_.Row })
}

function Get-ORingTable {
    param([Parameter(Mandatory)][string]$Path)
    Import-Csv -Path $Path -Encoding UTF8 | ForEach-Object {
        [pscustomobject]@{
            Series = $_.Series
            Name   = $_.Name
            D1     = [double]$_.D1
            D2     = [double]$_.D2
        }
    }
}

function Find-ORing {
    param(
        # 寸法は入力されたものだけ使う（1つ以上必須）
        [Nullable[double]]$GrooveInner,
        [Nullable[double]]$GrooveOuter,
        [Nullable[double]]$GrooveWidth,
        [Parameter(Mandatory)][ValidateSet('Dynamic', 'Static')][string]$Use,
        [Parameter(Mandatory)][object[]]$Table,
        # バックアップリング：なし / 片側 / 両側
        [ValidateSet('None', 'One', 'Both')][string]$BackupRing = 'None',
        # 呼び番号（一部でよい）。入れたときは寸法・用途を使わず、呼び番号に含むものを出す
        [string]$Name
    )
    $brIndex = @{ None = 0; One = 1; Both = 2 }[$BackupRing]

    $byName = -not [string]::IsNullOrWhiteSpace($Name)
    if ($byName) {
        $GrooveInner = $null; $GrooveOuter = $null; $GrooveWidth = $null
        $Table = Select-ByName $Table 'Name' $Name
    }

    $hasInner = $null -ne $GrooveInner
    $hasOuter = $null -ne $GrooveOuter
    $hasWidth = $null -ne $GrooveWidth

    if (-not ($hasInner -or $hasOuter -or $hasWidth -or $byName)) {
        throw '溝の内径・外径・溝幅のどれか1つ以上を入力してください。'
    }
    foreach ($v in @($GrooveInner, $GrooveOuter, $GrooveWidth)) {
        if ($null -ne $v -and $v -le 0) { throw '寸法には0より大きい値を入力してください。' }
    }
    if ($hasInner -and $hasOuter -and $GrooveOuter -le $GrooveInner) {
        throw '溝の外径は内径より大きい値を入力してください。'
    }

    $c   = $Criteria[$Use]
    $mid = ($c.SqueezeMin + $c.SqueezeMax) / 2

    # 判定に使った条件（画面表示用）
    $notes = @()
    if ($hasInner) { $notes += "内径の伸び $StretchMin〜$StretchMax%" }
    if ($hasOuter) {
        $notes += 'つぶし率 0%超（範囲の判定なし）'
        if (-not $hasInner) { $notes += '（溝内径は未入力のため、Oリング内径 d1 にはまる前提で溝深さを計算）' }
    }
    if ($hasWidth) {
        $notes += "溝充填率 $FillMax% 以下"
        if ($brIndex -gt 0) { $notes += '（溝幅からバックアップリングの分＝標準溝幅のBRありとBRなしの差を引いて計算）' }
        if (-not $hasOuter) { $notes += "（溝外径は未入力のため、つぶし率 $mid% になる溝深さを仮定）" }
    }

    $evaluated = foreach ($r in $Table) {
        if (-not $byName -and $c.Series -notcontains $r.Series) { continue }

        $stretch = $null
        if ($hasInner) { $stretch = ($GrooveInner - $r.D1) / $r.D1 * 100 }

        # 溝深さ：外径があれば実寸、なければ推奨つぶし率の中央から仮定
        $squeeze = $null
        if ($hasOuter) {
            $seat = if ($hasInner) { $GrooveInner } else { $r.D1 }
            $h = ($GrooveOuter - $seat) / 2
            if ($h -le 0) { continue }
            $squeeze = ($r.D2 - $h) / $r.D2 * 100
        } else {
            $h = $r.D2 * (1 - $mid / 100)
        }

        # 標準溝幅と、バックアップリングが占める幅
        $std = $null; $brSpace = 0
        if ($GrooveWidthStd.ContainsKey($r.Series)) { $std = $GrooveWidthStd[$r.Series][[double]$r.D2] }
        if ($null -ne $std) { $brSpace = $std[$brIndex] - $std[0] }

        $fill = $null
        if ($hasWidth) {
            $w = $GrooveWidth - $brSpace   # Oリングが使える溝幅
            if ($w -le 0) { $fill = [double]::PositiveInfinity }
            else { $fill = ([math]::PI * $r.D2 * $r.D2 / 4) / ($h * $w) * 100 }
        }

        $tol = $null
        if ($GrooveTolerance.ContainsKey($r.Series)) { $tol = $GrooveTolerance[$r.Series][[double]$r.D2] }

        # 標準の溝寸法：d = 呼び番号の数値、D = d + 線径ごとの差
        $stdD1 = $null; $stdD2 = $null
        if ($r.Name -match '^[A-Z]+([\d.]+)') {
            $stdD1 = [double]$Matches[1]
            if ($GrooveDiff.ContainsKey($r.Series) -and $null -ne $GrooveDiff[$r.Series][[double]$r.D2]) {
                $stdD2 = $stdD1 + $GrooveDiff[$r.Series][[double]$r.D2]
            }
        }

        [pscustomobject]@{
            Series    = $r.Series
            Name      = $r.Name
            D1        = $r.D1
            D2        = $r.D2
            TolInner  = if ($null -ne $tol) { '0 / -{0:N2}' -f $tol } else { '—' }
            TolOuter  = if ($null -ne $tol) { '+{0:N2} / 0' -f $tol } else { '—' }
            TolWidth  = '+{0:N2} / 0' -f $GrooveWidthTolerance
            StdWidth  = if ($null -ne $std) { $std[$brIndex] } else { $null }
            StdInner  = $stdD1
            StdOuter  = $stdD2
            Depth     = $h
            Squeeze   = $squeeze
            Fill      = $fill
            Stretch   = $stretch
            StretchOk = (-not $hasInner) -or ($stretch -ge $StretchMin -and $stretch -le $StretchMax)
            # つぶし率の範囲判定はしない。つぶれない（0%以下＝シールしない）ものだけ除く
            SqueezeOk = (-not $hasOuter) -or ($squeeze -gt 0)
            FillOk    = (-not $hasWidth) -or ($fill -le $FillMax)
        }
    }

    # 並び順：内径があれば伸びが小さい順。内径がなければ つぶし率の中央に近い順 → 充填率が上限に近い順
    $sortKey = if ($hasInner) { { $_.Stretch } }
               elseif ($hasOuter) { { [math]::Abs($_.Squeeze - $mid) } }
               else { { $FillMax - $_.Fill } }

    # 系列ごと（P → G）に最大 $MaxResults 件ずつ
    $candidates = @(foreach ($s in $c.Series) {
        $evaluated |
            Where-Object { $_.Series -eq $s -and $_.StretchOk -and $_.SqueezeOk -and $_.FillOk } |
            Sort-Object $sortKey |
            Select-Object -First $MaxResults
    })
    # 呼び番号で探したときは、一致の近い順（Select-ByName の順）に最大 $NameMaxResults 件
    $total = $candidates.Count
    if ($byName) {
        $evaluated = @($evaluated)
        $total = $evaluated.Count
        $candidates = @($evaluated | Select-Object -First $NameMaxResults)
        $notes = @("呼び番号に「$($Name.Trim())」を含むもの（寸法・用途は使いません）")
    }

    $reasons = @()
    if ($byName) {
        if ($candidates.Count -eq 0) { $reasons += "呼び番号に「$($Name.Trim())」を含むOリングはありません。" }
    }
    elseif ($candidates.Count -eq 0) {
        $fitting = @($evaluated | Where-Object { $_.StretchOk })
        if ($fitting.Count -eq 0) {
            if ($hasInner) {
                $reasons += "溝内径に合う内径のOリングがありません（内径の伸び $StretchMin〜$StretchMax% の範囲外）。"
            } else {
                $reasons += '入力した寸法に合うOリングがありません。'
            }
        } else {
            foreach ($f in $fitting) {
                $ng = @()
                if (-not $f.SqueezeOk) {
                    $ng += ('つぶし率 {0:N1}%（つぶれないためシールしない）' -f $f.Squeeze)
                }
                if (-not $f.FillOk) {
                    $ng += ('溝充填率 {0:N1}%（上限 {1}%）' -f $f.Fill, $FillMax)
                }
                $reasons += "$($f.Name)：$($ng -join '、')"
            }
            if ($reasons.Count -gt 10) {
                $reasons = @($reasons[0..9]) + "…ほか $($reasons.Count - 10) 件"
            }
        }
    }

    $depth = $null
    if ($hasInner -and $hasOuter) { $depth = ($GrooveOuter - $GrooveInner) / 2 }

    [pscustomobject]@{
        GrooveDepth = $depth
        Candidates  = $candidates
        ByName      = $byName
        Total       = $total
        Reasons     = $reasons
        Notes       = $notes
    }
}

# ---- 阪上パッキン（油圧シリンダ用） ----
# サイズ表：data/sakagami_hydraulic.csv（出典：阪上製作所の製品ページの寸法表）
# 列 Inner＝表の d、Outer＝表の D。溝内径・溝外径として扱う（ピストン用：D＝シリンダ内径、d＝溝底径／ロッド用：d＝ロッド径、D＝溝底径）

function Get-PackingTable {
    param([Parameter(Mandatory)][string]$Path)
    Import-Csv -Path $Path -Encoding UTF8 | ForEach-Object {
        [pscustomobject]@{
            Product = $_.Product
            Use     = $_.Use
            Code    = $_.Code
            D1      = [double]$_.Inner
            D2      = [double]$_.Outer
            H       = [string]$_.H   # 文字列（バルカーは「16(16.5)」のように括弧内に No.2060・4060 用の値も持つ）
            GA      = [double]$_.GA
            GB      = [double]$_.GB
            Backup  = $_.Backup
            DiaD1   = $_.D1Dia   # 表の D1（ピストン側のランド径など。ない製品は空欄）
        }
    }
}

# 公差の指定（'H9' などのはめあい記号、または '+0.2/0'・'±0.2' などの数値）を表示用の文字列にする
function Format-PackingTol {
    param([string]$Spec, [double]$Size)
    $um = { param($v) if ($v -eq 0) { '0' } else { ('{0}{1:0.000}' -f $(if ($v -gt 0) { '+' } else { '-' }), ([math]::Abs($v) / 1000)) } }
    if ($Spec -match '^([HhfF])(8|9|10)$') {
        $i = 0
        while ($i -lt $FitSizeUpper.Count -and $Size -gt $FitSizeUpper[$i]) { $i++ }
        if ($i -ge $FitSizeUpper.Count) { return $Spec }
        $it = switch ($Matches[2]) { '8' { $FitIT8[$i] } '9' { $FitIT9[$i] } default { $FitIT10[$i] } }
        switch -CaseSensitive ($Matches[1]) {
            'H' { $hi = $it;         $lo = 0 }
            'h' { $hi = 0;           $lo = -$it }
            'f' { $hi = $FitEsF[$i]; $lo = $FitEsF[$i] - $it }
        }
        return "$Spec $(& $um $hi) / $(& $um $lo)"
    }
    if ($Spec -match '^([+\-]?[\d.]+)/([+\-]?[\d.]+)$') { return "$($Matches[1]) / $($Matches[2])" }
    $Spec
}

# 製品・使用箇所ごとの d・D・D1・溝幅の公差（両用はピストン用・ロッド用を並べる）
# WithBR：バックアップリングあり（溝幅 GB）なら $true、なし（GA）なら $false
function Get-PackingTol {
    param($Row, [bool]$WithBR = $false)
    $t = $PackingTolerance[$Row.Product]
    if ($null -eq $t) { return @{ Inner = '—'; Outer = '—'; Width = '—'; D1 = '' } }
    $w = $t.Width
    if ($t.WidthByCode -and $t.WidthByCode.ContainsKey($Row.Code)) { $w = $t.WidthByCode[$Row.Code][[int]$WithBR] }
    # WidthByD：d の範囲で溝幅の公差が違うとき @(@(d の上限, 公差), ...)（小さい順）
    if ($t.WidthByD) { foreach ($b in $t.WidthByD) { if ($Row.D1 -le $b[0]) { $w = $b[1]; break } } }
    $d1 = if ($t.D1 -and "$($Row.DiaD1)" -ne '') { Format-PackingTol $t.D1 0 } else { '' }
    $inner = @(); $outer = @()
    foreach ($u in @('Piston', 'Rod')) {
        if (-not $t.ContainsKey($u)) { continue }
        $label = if ($Row.Use -eq 'Both') { @{ Piston = 'ピストン '; Rod = 'ロッド ' }[$u] } else { '' }
        $inner += $label + (Format-PackingTol $t[$u].Inner $Row.D1)
        $outer += $label + (Format-PackingTol $t[$u].Outer $Row.D2)
    }
    # d の公差はピストン用だけを出す（両用もロッド用は出さず「ピストン」の文字も付けない。ロッド専用の製品はロッド用）
    $innerTol = if ($t.ContainsKey('Piston')) { Format-PackingTol $t.Piston.Inner $Row.D1 } else { $inner -join '／' }
    @{ Inner = $innerTol; Outer = $outer -join '／'; Width = Format-PackingTol $w 0; D1 = $d1 }
}

function Find-Packing {
    param(
        [Nullable[double]]$GrooveInner,
        [Nullable[double]]$GrooveOuter,
        [Nullable[double]]$GrooveWidth,
        [Parameter(Mandatory)][object[]]$Table,
        # サイズ表の溝幅は「バックアップリングなし（GA）」と「あり（GB）」の2種類。片側・両側はどちらも GB で判定する
        [ValidateSet('None', 'One', 'Both')][string]$BackupRing = 'None',
        # 検索対象の製品（省略時は Config.ps1 の $PackingProducts）
        [string[]]$Products = $PackingProducts,
        # 候補がないときのメッセージに使う名前
        [string]$Label = 'パッキン',
        # 呼び番号（一部でよい）。入れたときは寸法を使わず、呼び番号に含むものを出す
        [string]$Name
    )
    $byName = -not [string]::IsNullOrWhiteSpace($Name)
    if ($byName) {
        $GrooveInner = $null; $GrooveOuter = $null; $GrooveWidth = $null
        $Table = Select-ByName @($Table | Where-Object { $Products -contains $_.Product }) 'Code' $Name
    }
    $hasInner = $null -ne $GrooveInner
    $hasOuter = $null -ne $GrooveOuter
    $hasWidth = $null -ne $GrooveWidth

    if (-not ($hasInner -or $hasOuter -or $hasWidth -or $byName)) {
        throw '溝の内径・外径・溝幅のどれか1つ以上を入力してください。'
    }
    foreach ($v in @($GrooveInner, $GrooveOuter, $GrooveWidth)) {
        if ($null -ne $v -and $v -le 0) { throw '寸法には0より大きい値を入力してください。' }
    }
    if ($hasInner -and $hasOuter -and $GrooveOuter -le $GrooveInner) {
        throw '溝の外径は内径より大きい値を入力してください。'
    }
    $withBR = $BackupRing -ne 'None'

    $notes = @()
    if ($hasInner) { $notes += "d の差 ±$PackingDiaTol mm 以内" }
    if ($hasOuter) { $notes += "D の差 ±$PackingDiaTol mm 以内" }
    if ($hasWidth) {
        $notes += "溝幅の差 ±$PackingWidthTol mm 以内（" + $(if ($withBR) { 'バックアップリングありの溝幅 GB' } else { 'バックアップリングなしの溝幅 GA' }) + '）'
        if ($BackupRing -eq 'Both') { $notes += '（サイズ表に両側の溝幅はないため、バックアップリングありの溝幅で判定）' }
    }

    $i = 0
    $matched = foreach ($r in $Table) {
        if ($Products -notcontains $r.Product) { $i++; continue }
        $i++
        $w = if ($withBR) { $r.GB } else { $r.GA }
        $dev = 0.0
        if ($hasInner) { $e = [math]::Abs($GrooveInner - $r.D1); if ($e -gt $PackingDiaTol + 1e-9) { continue }; $dev += $e }
        if ($hasOuter) { $e = [math]::Abs($GrooveOuter - $r.D2); if ($e -gt $PackingDiaTol + 1e-9) { continue }; $dev += $e }
        if ($hasWidth) { $e = [math]::Abs($GrooveWidth - $w);   if ($e -gt $PackingWidthTol + 1e-9) { continue }; $dev += $e }
        $tol = Get-PackingTol $r $withBR
        [pscustomobject]@{
            Product = $r.Product; Use = $r.Use; Code = $r.Code
            D1 = $r.D1; D2 = $r.D2; DiaD1 = $r.DiaD1; H = $r.H; Width = $w
            Backup = if ($withBR) { $r.Backup } else { '' }
            TolInner = $tol.Inner; TolOuter = $tol.Outer; TolWidth = $tol.Width; TolD1 = $tol.D1
            Deviation = $dev; Order = $i
        }
    }
    $matched = @($matched)

    # 製品ごとに最大 $MaxResults 件（差が小さい順）。製品の並びは、いちばん差が小さい候補の順
    $groups = @($matched | Group-Object Product | ForEach-Object {
        $top = @($_.Group | Sort-Object Deviation, Order | Select-Object -First $MaxResults)
        [pscustomobject]@{ Best = $top[0].Deviation; Order = $top[0].Order; Items = $top }
    } | Sort-Object Best, Order)
    $candidates = @(foreach ($g in $groups) { $g.Items })
    $total = $candidates.Count

    $reasons = @()
    if ($byName) {
        # 一致の近い順（Select-ByName の順）に最大 $NameMaxResults 件
        $total = $matched.Count
        $candidates = @($matched | Select-Object -First $NameMaxResults)
        $notes = @("呼び番号に「$($Name.Trim())」を含むもの（寸法は使いません）")
        if ($candidates.Count -eq 0) { $reasons += "呼び番号に「$($Name.Trim())」を含む$($Label)はありません。" }
    }
    elseif ($candidates.Count -eq 0) { $reasons += "入力した寸法に合う$($Label)はありません（許容差の範囲外）。" }

    [pscustomobject]@{
        ByName     = $byName
        Total      = $total
        Candidates = $candidates
        Reasons    = $reasons
        Notes      = $notes
    }
}
