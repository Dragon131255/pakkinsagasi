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
$NameMaxResults = 30   # 呼び番号で探したときに表示する最大件数

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
# 両用（SKY・KY・UPH）はピストンに使うときとロッドに使うときで公差が違うので両方持つ
# D1＝表の D1 の公差（ピストン側）。WidthByCode＝呼び番号ごとに溝幅の公差が違うとき @(GA の公差, GB の公差)
# GPY・RGY・ⓉSGY の D1 の公差は未確認（検索結果に出していないため）
$PackingTolerance = @{
    'GPY'  = @{ Piston = @{ Inner = 'h8';     Outer = 'H9' };                                         Width = '+0.25/0' }
    'GNY'  = @{ Rod    = @{ Inner = 'f8';     Outer = 'H8' };                                         Width = '+0.25/0' }
    'RGY'  = @{ Piston = @{ Inner = '+0.2/0'; Outer = 'H9' };                                         Width = '±0.2' }
    'RNY'  = @{ Rod    = @{ Inner = 'f8';     Outer = '0/-0.2' };                                     Width = '±0.2' }
    'ⓉSGY' = @{ Piston = @{ Inner = '+0.2/0'; Outer = 'H9' };                                         Width = '±0.2' }
    'ⓉSNY' = @{ Rod    = @{ Inner = 'f8';     Outer = '0/-0.2' };                                     Width = '±0.2' }
    'SKY'  = @{ Piston = @{ Inner = '+0.2/0'; Outer = 'H9' }; Rod = @{ Inner = 'f8'; Outer = '0/-0.2' }; Width = '±0.2'; D1 = '±0.2' }
    'KY'   = @{ Piston = @{ Inner = 'h8';     Outer = 'H9' }; Rod = @{ Inner = 'f8'; Outer = 'H9' };     Width = '±0.2'; D1 = '±0.2' }
    # バルカー（カタログ p.4・6・17 の図と表）
    'UHP'  = @{ Piston = @{ Inner = '+0.2/0'; Outer = 'H9' }; Width = '+0.5/0'; D1 = '±0.2'
                WidthByCode = @{ 'UHP40' = @('+0.3/0', '+0.3/0'); 'UHP50' = @('+0.3/0', '+0.3/0'); 'UHP63' = @('+0.3/0', '+0.3/0')
                                 'UHP80' = @('+0.3/0', '+0.3/0'); 'UHP90' = @('+0.3/0', '+0.3/0')
                                 'UHP125' = @('+0.3/0', '+0.5/0'); 'UHP150' = @('+0.3/0', '+0.5/0') } }
    'MLP'  = @{ Piston = @{ Inner = '+0.2/0'; Outer = 'H9' }; Width = '+0.5/0'; D1 = '±0.2'
                WidthByCode = @{ 'MLP40' = @('+0.3/0', '+0.3/0'); 'MLP50' = @('+0.3/0', '+0.3/0'); 'MLP63' = @('+0.3/0', '+0.3/0'); 'MLP80' = @('+0.3/0', '+0.3/0') } }
    'MLR'  = @{ Rod    = @{ Inner = 'f8';     Outer = '0/-0.2' };                                     Width = '+0.5/0' }
    # NOK（UPH 型 E-92 ピストン、E-94 ロッドの装着図）
    'UPH'  = @{ Piston = @{ Inner = 'h10';    Outer = 'H9' }; Rod = @{ Inner = 'f8'; Outer = 'H10' };    Width = '±0.2'; D1 = '±0.2' }
    # ---- ダストシール（data/dust_seal.csv）----
    # 阪上 SDR（製品ページの寸法指示図 2024.12-1）。D1＝表の C
    'SDR'  = @{ Rod = @{ Inner = 'f8'; Outer = '0/-0.2' }; Width = '±0.2'; D1 = '±0.1' }
    # バルカー DHS（カタログ p.29 の図）。D1＝表の C
    'DHS'  = @{ Rod = @{ Inner = 'f8'; Outer = '0/-0.2' }; Width = '+0.3/0'; D1 = '±0.1' }
    # NOK DKI（E-116 の装着図）：D はハウジング穴径（圧入）。溝幅の公差は d の範囲で違う
    'DKI'  = @{ Rod = @{ Inner = 'f8'; Outer = 'H8' }; Width = '+0.5/+0.3'
                WidthByD = @(@(50, '+0.5/+0.3'), @(175, '+0.6/+0.4'), @(300, '+0.7/+0.5')) }
    # NOK LBH（E-140 の装着図）
    'LBH'  = @{ Rod = @{ Inner = 'f8'; Outer = '0/-0.2' }; Width = '±0.2'; D1 = '±0.1' }
}

# ISO 286（JIS B 0401）の基本公差と f の基礎となる寸法許容差 [µm]
# 寸法区分の上限 [mm]（「を超え〜以下」）。IT8・IT9・f の上の寸法許容差 es
$FitSizeUpper = @(3, 6, 10, 18, 30, 50, 80, 120, 180, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600)
$FitIT8       = @(14, 18, 22, 27, 33, 39, 46, 54, 63, 72, 81, 89, 97, 110, 125, 140, 165, 195)
$FitIT9       = @(25, 30, 36, 43, 52, 62, 74, 87, 100, 115, 130, 140, 155, 175, 200, 230, 260, 310)
$FitIT10      = @(40, 48, 58, 70, 84, 100, 120, 140, 160, 185, 210, 230, 250, 280, 320, 360, 420, 500)
$FitEsF       = @(-6, -10, -13, -16, -20, -25, -30, -36, -43, -50, -56, -62, -68, -76, -80, -86, -98, -110)

# 検索結果に出す Uパッキンの製品（阪上は一時的に SKY・KY だけにしている）
# 全製品：'GPY', 'GNY', 'RGY', 'RNY', 'ⓉSGY', 'ⓉSNY', 'SKY', 'KY', 'UHP', 'MLP', 'MLR', 'UPH'
$PackingProducts = @('SKY', 'KY', 'UHP', 'MLP', 'MLR', 'UPH')

# バルカーの U パッキン（出典：バルカー 油圧用パッキン カタログ hydraulic-packing_doc.pdf）。UHP・MLP はピストン用、MLR はロッド用
$ValquaProducts = @('UHP', 'MLP', 'MLR', 'DHS')

# NOK の U パッキン（出典：NOK UPH 型 寸法表 UPH.pdf、edccorp.com.tw 掲載）。ピストン・ロッド両用
$NokProducts = @('UPH', 'DKI', 'LBH')

# ダストシール（ロッド用）。サイズ表は data/dust_seal.csv（列は sakagami_hydraulic.csv と同じ。GA＝GB＝溝幅、Backup は空欄）
$DustProducts = @('SDR', 'LBH', 'DHS', 'DKI')
$DustSourceNote = '出典：SDR は阪上製作所の製品ページ、DHS はバルカーの油圧用パッキン カタログ、LBH・DKI は NOK の寸法表。使用条件は各社のカタログで確認してください。'
