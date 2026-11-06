$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
. "$root\Config.ps1"
. "$root\Search.ps1"

$table = @(Get-ORingTable -Path "$root\data\oring_jis_b2401.csv")

Describe 'Find-ORing' {
    It '固定用：G25 の溝で G25 が先頭に出る' {
        $r = Find-ORing -GrooveInner 25 -GrooveOuter 30 -GrooveWidth 4.1 -Use Static -Table $table
        $r.GrooveDepth | Should Be 2.5
        $g = @($r.Candidates | Where-Object { $_.Series -eq 'G' })
        $g[0].Name | Should Be 'G25'
        [math]::Round($g[0].Squeeze, 1) | Should Be 19.4
    }

    It '運動用：P20 の溝で P20 が出て、G系列は出ない' {
        $r = Find-ORing -GrooveInner 20 -GrooveOuter 24 -GrooveWidth 3.2 -Use Dynamic -Table $table
        $r.Candidates[0].Name | Should Be 'P20'
        @($r.Candidates | Where-Object { $_.Name -like 'G*' }).Count | Should Be 0
    }

    It '候補は系列ごとに最大2件で、P → G の順に並ぶ' {
        $r = Find-ORing -GrooveInner 100 -GrooveOuter 108 -GrooveWidth 7.5 -Use Static -Table $table
        @($r.Candidates | Where-Object { $_.Series -eq 'P' }).Count -le 2 | Should Be $true
        @($r.Candidates | Where-Object { $_.Series -eq 'G' }).Count -le 2 | Should Be $true
        $s = @($r.Candidates | ForEach-Object { $_.Series })
        ($s -join '') -match '^P*G*$' | Should Be $true
    }

    It '合わないときは理由を返す' {
        $r = Find-ORing -GrooveInner 25 -GrooveOuter 26 -GrooveWidth 4.1 -Use Static -Table $table
        $r.Candidates.Count | Should Be 0
        $r.Reasons.Count -gt 0 | Should Be $true
    }

    It '外径が内径以下ならエラー' {
        { Find-ORing -GrooveInner 30 -GrooveOuter 25 -GrooveWidth 4 -Use Static -Table $table } | Should Throw
    }

    It '内径だけ：伸び 0〜5% の候補が出て、つぶし率は計算しない' {
        $r = Find-ORing -GrooveInner 25 -Use Static -Table $table
        $r.Candidates.Count -gt 0 | Should Be $true
        @($r.Candidates | Where-Object { $_.Stretch -lt 0 -or $_.Stretch -gt 5 }).Count | Should Be 0
        $r.Candidates[0].Squeeze | Should Be $null
        $r.GrooveDepth | Should Be $null
    }

    It '外径だけ：d1 にはまる前提でつぶし率を計算し、つぶれないものは除く' {
        $r = Find-ORing -GrooveOuter 30 -Use Static -Table $table
        $r.Candidates.Count -gt 0 | Should Be $true
        @($r.Candidates | Where-Object { $_.Squeeze -le 0 }).Count | Should Be 0
    }

    It 'つぶし率の範囲判定なし：G300 の溝（つぶし率 12.3%）で G300 が出る' {
        $r = Find-ORing -GrooveInner 300 -GrooveOuter 310 -GrooveWidth 7.5 -Use Static -Table $table
        @($r.Candidates | Where-Object { $_.Series -eq 'G' })[0].Name | Should Be 'G300'
    }

    It '溝幅だけ：充填率 85% 以下の候補が出る' {
        $r = Find-ORing -GrooveWidth 4.1 -Use Static -Table $table
        $r.Candidates.Count -gt 0 | Should Be $true
        @($r.Candidates | Where-Object { $_.Fill -gt 85 }).Count | Should Be 0
    }

    It 'バックアップリング両側：G25 の BR両側溝（7.3）で G25 が出て、標準溝幅 7.3 を返す' {
        $r = Find-ORing -GrooveInner 25 -GrooveOuter 30 -GrooveWidth 7.3 -Use Static -Table $table -BackupRing Both
        $g = @($r.Candidates | Where-Object { $_.Series -eq 'G' })
        $g[0].Name | Should Be 'G25'
        $g[0].StdWidth | Should Be 7.3
    }

    It 'バックアップリング両側：BRなしの溝幅（4.1）では G25 は充填率オーバーで出ない' {
        $r = Find-ORing -GrooveInner 25 -GrooveOuter 30 -GrooveWidth 4.1 -Use Static -Table $table -BackupRing Both
        @($r.Candidates | Where-Object { $_.Name -eq 'G25' }).Count | Should Be 0
    }

    It '標準溝寸法：P22A は d=22、D=28、P400 は d=400、D=415' {
        $r = Find-ORing -GrooveInner 22 -GrooveOuter 28 -GrooveWidth 4.7 -Use Static -Table $table
        $p = $r.Candidates | Where-Object { $_.Name -eq 'P22A' }
        $p.StdInner | Should Be 22
        $p.StdOuter | Should Be 28
        $r = Find-ORing -GrooveInner 400 -GrooveOuter 415 -GrooveWidth 11 -Use Static -Table $table
        $p = $r.Candidates | Where-Object { $_.Name -eq 'P400' }
        $p.StdOuter | Should Be 415
    }

    It '何も入力しないとエラー' {
        { Find-ORing -Use Static -Table $table } | Should Throw
    }

    It '0以下の寸法はエラー' {
        { Find-ORing -GrooveInner 0 -GrooveOuter 25 -GrooveWidth 4 -Use Static -Table $table } | Should Throw
    }
}

Describe 'Find-Packing' {
    $ptable = @(Get-PackingTable -Path "$root\data\sakagami_hydraulic.csv")
    $allProducts = @('GPY', 'GNY', 'RGY', 'RNY', 'ⓉSGY', 'ⓉSNY', 'SKY', 'KY', 'UHP', 'MLP', 'MLR', 'UPH')

    It '製品を指定しないときは Config.ps1 の $PackingProducts（今は SKY・KY・UHP・MLP・MLR・UPH）が出る' {
        $r = Find-Packing -GrooveInner 40 -GrooveOuter 50 -Table $ptable
        $r.Candidates.Count -gt 0 | Should Be $true
        @($r.Candidates | Where-Object { $PackingProducts -notcontains $_.Product }).Count | Should Be 0
    }

    It 'サイズ表を読める（12製品・757サイズ）' {
        $ptable.Count | Should Be 757
        @($ptable | Select-Object -ExpandProperty Product -Unique).Count | Should Be 12
    }

    It 'd30・D40・溝幅7：寸法がぴったりのサイズが製品ごとに出る' {
        $r = Find-Packing -GrooveInner 30 -GrooveOuter 40 -GrooveWidth 7 -Table $ptable -Products $allProducts
        $codes = @($r.Candidates | ForEach-Object { $_.Code })
        $codes -contains 'GPY-40'  | Should Be $true
        $codes -contains 'GNY-30'  | Should Be $true
        $codes -contains 'SKY-30'  | Should Be $true
        @($r.Candidates | Where-Object { $_.Deviation -ne 0 }).Count | Should Be 0
    }

    It '製品ごとに最大2件' {
        $r = Find-Packing -GrooveWidth 7 -Table $ptable -Products $allProducts
        $r.Candidates | Group-Object Product | ForEach-Object { $_.Count -le 2 | Should Be $true }
    }

    It 'バックアップリングありは GB の溝幅で判定し、バックアップのコードを返す' {
        $r = Find-Packing -GrooveInner 40 -GrooveOuter 50 -GrooveWidth 9 -BackupRing One -Table $ptable -Products $allProducts
        $g = @($r.Candidates | Where-Object { $_.Product -eq 'GPY' })
        $g[0].Code   | Should Be 'GPY-50'
        $g[0].Width  | Should Be 9
        $g[0].Backup | Should Be 'TC-GPY-50'
    }

    It '許容差を超えると出ない' {
        $r = Find-Packing -GrooveInner 30.6 -GrooveOuter 40 -Table $ptable -Products $allProducts
        @($r.Candidates | Where-Object { $_.D1 -eq 30 }).Count | Should Be 0
    }

    It '合わないときは理由を返す' {
        $r = Find-Packing -GrooveInner 3 -GrooveOuter 3.5 -Table $ptable -Products $allProducts
        $r.Candidates.Count | Should Be 0
        $r.Reasons.Count -gt 0 | Should Be $true
    }

    It '公差：寸法指示図どおり、はめあい記号は ISO 286 の数値にする' {
        $r = Find-Packing -GrooveInner 40 -GrooveOuter 50 -Table $ptable -Products $allProducts
        $g = @($r.Candidates | Where-Object { $_.Code -eq 'GPY-50' })[0]
        $g.TolInner | Should Be 'h8 0 / -0.039'
        $g.TolOuter | Should Be 'H9 +0.062 / 0'
        $g.TolWidth | Should Be '+0.25 / 0'
        $n = @($r.Candidates | Where-Object { $_.Code -eq 'GNY-40' })[0]
        $n.TolInner | Should Be 'f8 -0.025 / -0.064'
        $n.TolOuter | Should Be 'H8 +0.039 / 0'
        $s = @($r.Candidates | Where-Object { $_.Code -eq 'SKY-40' })[0]
        $s.TolInner | Should Be '+0.2 / 0'   # 両用も d の公差はピストン用だけ（「ピストン」の文字は付けない）
        $s.TolWidth | Should Be '±0.2'
    }

    It '公差：寸法区分の境目（30 は 18〜30 の区分）' {
        Format-PackingTol 'H9' 30 | Should Be 'H9 +0.052 / 0'
        Format-PackingTol 'H9' 30.1 | Should Be 'H9 +0.062 / 0'
    }

    It '外径が内径以下ならエラー' {
        { Find-Packing -GrooveInner 40 -GrooveOuter 30 -Table $ptable -Products $allProducts } | Should Throw
    }
}

Describe 'Find-Packing（ダストシール）' {
    $dtable = @(Get-PackingTable -Path "$root\data\dust_seal.csv")

    It 'd=40 で4製品すべてが候補になる' {
        $r = Find-Packing -GrooveInner 40 -Table $dtable -Products $DustProducts -Label 'ダストシール'
        @($r.Candidates | ForEach-Object Product | Select-Object -Unique).Count | Should Be 4
    }
    It 'DKI の溝幅の公差は d の範囲で切り替わる' {
        $r = Find-Packing -GrooveInner 100 -Table $dtable -Products @('DKI')
        $r.Candidates[0].TolWidth | Should Be '+0.6 / +0.4'
    }
    It '合わないときはダストシールの名前で理由を出す' {
        $r = Find-Packing -GrooveInner 999 -Table $dtable -Products $DustProducts -Label 'ダストシール'
        $r.Reasons[0] | Should Match 'ダストシール'
    }
}

Describe '呼び番号で探す' {
    $ptable = @(Get-PackingTable -Path "$root\data\sakagami_hydraulic.csv")
    It 'Oリング：全角・小文字でも探せ、完全一致があればそれだけ。寸法・用途は使わない' {
        $r = Find-ORing -GrooveInner 999 -Use Dynamic -Table $table -Name 'ｇ２５'
        $r.ByName | Should Be $true
        $r.Candidates.Count | Should Be 1
        $r.Candidates[0].Name | Should Be 'G25'
        $r.Candidates[0].StdOuter | Should Be 30
    }
    It '完全一致がないときは含むものを出す' {
        $r = Find-ORing -Use Static -Table $table -Name 'P2'
        $r.Candidates[0].Name | Should Be 'P20'
        $r.Candidates.Count | Should BeGreaterThan 1
    }
    It '種類をまとめて探し、どれかに完全一致があれば部分一致の種類は出さない' {
        $dt = @(Get-PackingTable -Path "$root\data\dust_seal.csv")
        $a = Find-AllByName -Name 'P20' -ORingTable $table -PackingTable $ptable -DustTable $dt
        $a.ORing.Candidates[0].Name | Should Be 'P20'
        $a.Packing.Total | Should Be 0   # UHP200 などは出さない
        $a = Find-AllByName -Name 'lbh20' -ORingTable $table -PackingTable $ptable -DustTable $dt
        $a.Dust.Candidates[0].Code | Should Be 'LBH-20'
        $a.ORing.Total | Should Be 0
        $a = Find-AllByName -Name '40' -ORingTable $table -PackingTable $ptable -DustTable $dt
        ($a.ORing.Total -gt 0 -and $a.Packing.Total -gt 0 -and $a.Dust.Total -gt 0) | Should Be $true
    }
    It 'Uパッキン：ハイフンなしでも探せ、件数は上限まで' {
        $r = Find-Packing -Table $ptable -Name 'sky40'
        $r.Candidates.Count | Should Be 1
        $r.Candidates[0].Code | Should Be 'SKY-40'
        $r = Find-Packing -Table $ptable -Name 'UPH'
        $r.Total | Should BeGreaterThan $NameMaxResults
        $r.Candidates.Count | Should Be $NameMaxResults
    }
    It '検索対象外の製品は出さず、ないときは理由を出す' {
        $r = Find-Packing -Table $ptable -Name 'GPY'
        $r.Candidates.Count | Should Be 0
        $r.Reasons[0] | Should Match 'GPY'
    }
}
