# 判定基準（JIS B 2401 の推奨値を元にした初期値。規格本文で要確認）
# SqueezeMin/Max は絞り込みには使わない。並び順（中央に近い順）と、溝幅だけ入力時の溝深さの仮定にだけ使う
# 値を変えるときはこのファイルだけを直す

$Criteria = @{
    # 運動用：P系列のみ
    Dynamic = @{ SqueezeMin = 8;  SqueezeMax = 20; Series = @('P') }
    # 固定用：P系列・G系列
    Static  = @{ SqueezeMin = 15; SqueezeMax = 30; Series = @('P', 'G') }
}

$FillMax    = 85   # 溝充填率の上限 [%]
$StretchMin = 0    # 内径の伸びの下限 [%]
$StretchMax = 5    # 内径の伸びの上限 [%]
$MaxResults = 2    # 表示する候補の最大件数

# 溝寸法の公差 [mm]（線径 d2 ごと）
# 出典：さくらシール Oリングサイズ表（P規格 https://www.sakura-seal.co.jp/category/1982811.html、
#       G規格 https://www.sakura-seal.co.jp/category/1982819.html）。JIS B 2401 原本との照合は未実施
# Inner = 溝内径 d の公差（0 / -値）、Outer = 溝外径 D の公差（+値 / 0）
$GrooveTolerance = @{
    'P' = @{ 1.9 = 0.05; 2.4 = 0.06; 3.5 = 0.08; 5.7 = 0.10; 8.4 = 0.10 }
    'G' = @{ 3.1 = 0.10; 5.7 = 0.10 }
}
$GrooveWidthTolerance = 0.25   # 溝幅 G の公差（+値 / 0）、全サイズ共通

# 標準の溝寸法：d = 呼び番号の数値、D = d + 下の値 [mm]（線径 d2 ごと、出典同上）
$GrooveDiff = @{
    'P' = @{ 1.9 = 3.0; 2.4 = 4.0; 3.5 = 6.0; 5.7 = 10.0; 8.4 = 15.0 }
    'G' = @{ 3.1 = 5.0; 5.7 = 10.0 }
}

# 標準の溝幅 G [mm]（線径 d2 ごと）：@(バックアップリングなし, 片側, 両側)
# 出典は上の公差と同じ（さくらシール）。JIS B 2401 原本との照合は未実施
$GrooveWidthStd = @{
    'P' = @{ 1.9 = @(2.5, 3.9, 5.4); 2.4 = @(3.2, 4.4, 6.0); 3.5 = @(4.7, 6.0, 7.8); 5.7 = @(7.5, 9.0, 11.5); 8.4 = @(11.0, 13.0, 17.0) }
    'G' = @{ 3.1 = @(4.1, 5.6, 7.3); 5.7 = @(7.5, 9.0, 11.5) }
}

# 阪上パッキン（油圧シリンダ用）の検索
# 入力した d・D・溝幅と、サイズ表の値との差がこの範囲内なら候補にする [mm]
$PackingDiaTol   = 0.5   # d・D の許容差
$PackingWidthTol = 0.5   # 溝幅の許容差（バックアップリングなし＝GA、あり＝GB と比べる）

# 阪上パッキンの溝寸法の公差（出典：阪上製作所の各製品ページの寸法指示図）
# Inner＝表の d、Outer＝表の D、Width＝溝幅 GA・GB。はめあい記号（H8 など）は下の ISO 286 の表から数値にする
# 両用（SKY・KY）はピストンに使うときとロッドに使うときで公差が違うので両方持つ
$PackingTolerance = @{
    'GPY'  = @{ Piston = @{ Inner = 'h8';     Outer = 'H9' };                                         Width = '+0.25/0' }
    'GNY'  = @{ Rod    = @{ Inner = 'f8';     Outer = 'H8' };                                         Width = '+0.25/0' }
    'RGY'  = @{ Piston = @{ Inner = '+0.2/0'; Outer = 'H9' };                                         Width = '±0.2' }
    'RNY'  = @{ Rod    = @{ Inner = 'f8';     Outer = '0/-0.2' };                                     Width = '±0.2' }
    'ⓉSGY' = @{ Piston = @{ Inner = '+0.2/0'; Outer = 'H9' };                                         Width = '±0.2' }
    'ⓉSNY' = @{ Rod    = @{ Inner = 'f8';     Outer = '0/-0.2' };                                     Width = '±0.2' }
    'SKY'  = @{ Piston = @{ Inner = '+0.2/0'; Outer = 'H9' }; Rod = @{ Inner = 'f8'; Outer = '0/-0.2' }; Width = '±0.2' }
    'KY'   = @{ Piston = @{ Inner = 'h8';     Outer = 'H9' }; Rod = @{ Inner = 'f8'; Outer = 'H9' };     Width = '±0.2' }
}

# ISO 286（JIS B 0401）の基本公差と f の基礎となる寸法許容差 [µm]
# 寸法区分の上限 [mm]（「を超え〜以下」）。IT8・IT9・f の上の寸法許容差 es
$FitSizeUpper = @(3, 6, 10, 18, 30, 50, 80, 120, 180, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600)
$FitIT8       = @(14, 18, 22, 27, 33, 39, 46, 54, 63, 72, 81, 89, 97, 110, 125, 140, 165, 195)
$FitIT9       = @(25, 30, 36, 43, 52, 62, 74, 87, 100, 115, 130, 140, 155, 175, 200, 230, 260, 310)
$FitEsF       = @(-6, -10, -13, -16, -20, -25, -30, -36, -43, -50, -56, -62, -68, -76, -80, -86, -98, -110)

# 検索結果に出す Uパッキンの製品（阪上は一時的に SKY・KY だけにしている）
# 全製品：'GPY', 'GNY', 'RGY', 'RNY', 'ⓉSGY', 'ⓉSNY', 'SKY', 'KY', 'UHP', 'MLP', 'MLR', 'UPH'
$PackingProducts = @('SKY', 'KY', 'UHP', 'MLP', 'MLR', 'UPH')

# バルカーの U パッキン（出典：バルカー 油圧用パッキン カタログ hydraulic-packing_doc.pdf）。UHP・MLP はピストン用、MLR はロッド用
$ValquaProducts = @('UHP', 'MLP', 'MLR')

# NOK の U パッキン（出典：NOK UPH 型 寸法表 UPH.pdf、edccorp.com.tw 掲載）。ピストン・ロッド両用
$NokProducts = @('UPH')
