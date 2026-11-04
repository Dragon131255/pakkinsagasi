# 計算・判定・並べ替え（画面に依存しない）
# 使う前に Config.ps1 をドットソースしておくこと

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
        [ValidateSet('None', 'One', 'Both')][string]$BackupRing = 'None'
    )
    $brIndex = @{ None = 0; One = 1; Both = 2 }[$BackupRing]

    $hasInner = $null -ne $GrooveInner
    $hasOuter = $null -ne $GrooveOuter
    $hasWidth = $null -ne $GrooveWidth

    if (-not ($hasInner -or $hasOuter -or $hasWidth)) {
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
        if ($c.Series -notcontains $r.Series) { continue }

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

    $candidates = @($evaluated |
        Where-Object { $_.StretchOk -and $_.SqueezeOk -and $_.FillOk } |
        Sort-Object $sortKey |
        Select-Object -First $MaxResults)

    $reasons = @()
    if ($candidates.Count -eq 0) {
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
        Reasons     = $reasons
        Notes       = $notes
    }
}
