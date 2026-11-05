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
