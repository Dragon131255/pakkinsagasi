# pakkinsagasi（パッキン探し）

溝の寸法または呼び番号から、Oリング（JIS B 2401）・Uパッキン・ダストシール・ウェアリングの候補と標準溝寸法・公差を表示する Web アプリ（スマホ・PC のブラウザで使う）。

## 技術構成
- 素の HTML + JavaScript（ビルドなし・外部ライブラリなし）。GitHub Pages で公開
- 計算は `search.js` だけ（2026-11-09 に PowerShell 版を廃止して一本化。ユーザー指示）
- `pakkinsagasi.bat` は公開 URL をブラウザで開くだけのランチャー
- テストは Node.js の標準テスト：`node --test tests/search.test.js`（追加インストールなし）
- 単位はすべて mm、画面の表示は日本語

## 入力
- 溝の内径 [mm]
- 溝の外径 [mm]
- 溝幅 [mm]
- 用途：運動用 / 固定用（選んだ用途で判定基準を切り替える）
- バックアップリング：なし / 片側 / 両側。溝充填率は「入力溝幅 −（標準溝幅のBRあり − BRなし）」で計算し、結果に選んだBR条件の標準溝幅を出す（標準溝幅は `search.js`、出典さくらシール）
- 寸法は1つだけ・2つだけの入力も可。入力された寸法で判定できる条件だけ使う
  - 内径あり → 内径の伸び
  - 外径あり → つぶし率（内径がなければ Oリング内径 d1 にはまる前提で溝深さを出す）
  - 溝幅あり → 溝充填率（外径がなければ つぶし率が推奨範囲の中央になる溝深さを仮定）
  - 並び順：内径あり→伸びが小さい順／内径なし・外径あり→つぶし率の中央に近い順／溝幅のみ→充填率が上限に近い順
- 呼び番号で探す（2026-11-06 追加、ユーザー指示。Oリング・Uパッキン・ダストシールとも）
  - 入力欄の名前は「検索」（2026-11-06 ユーザー指示）。この欄に入れると寸法（と Oリングの用途）を使わず、呼び番号にその文字を含むものを出す（search.js の findORing / findPacking の `name`）
  - 比較は全角→半角・大文字にし、ハイフン・空白・* などを除いて行う（`nameKey`。例 `sky40` で SKY-40）
  - 除いたあとに文字が残らない検索語（`-` だけなど）はエラー（`assertNameKey`。全件に一致してしまうため）
  - 完全に一致するものがあればそれだけを出す（例 `P20` で P20 だけ。2026-11-06 ユーザー指示）。ないときだけ、含むものを 前方一致 → 部分一致、同じなら表の順で出す。最大 `NameMaxResults`（30）件。結果に `ByName`・`Total`（全件数）を付ける
  - Oリングは用途に関係なく P・G 両系列、Uパッキン・ダストシールは検索対象の製品（`PackingProducts`・`DustProducts`）だけ
  - 「検索」欄は入力欄の一番上。種類を選ばなくても全種類から探す（2026-11-06 ユーザー指示）。`findAllByName` で3種類をまとめて探し、どれかの種類に完全一致があれば完全一致のない種類は出さない
    - Web版：全種類の結果を1つの一覧に出す（Oリング → Uパッキン → ダストシール）。カードを選ぶと、その種類の図（断面図／寸法指示図）に切り替わる

## 対象データ
- 4つの CSV の最後に `Source`（出典）・`Verified`（原本と照合した日。空＝未照合）の列がある（2026-11-09 追加、ユーザー指示）
  - 未照合の行は、検索結果の呼び番号の横に「未照合」の札を出す（index.html の `unverified`）。照合したら `Verified` に日付を入れる
  - 2026-11-09 全データ照合済み：阪上 13製品（製品ページと自動照合）・バルカー 6製品（カタログ PDF と照合）は Claude が照合。Oリング（JIS B 2401）と NOK 4製品（NOK 公式資料）はユーザーが照合（ユーザー申告。デスクトップのチェック表は使っていない）
  - データを追加・修正したら、その行の `Verified` は空にして札を出し、照合後に日付を入れる
- JIS B 2401 のOリング規格表のうち **P系列・G系列**
- 規格表は `data/oring_jis_b2401.csv` に持つ（列：Series, Name, D1=内径, D2=太さ, Source, Verified）
  - JIS B 2401 原本との照合は 2026-11-09 にユーザーが実施
- G系列は固定用のみ。運動用を選んだときは P系列だけを候補にする

## 計算と判定
- 溝深さ H = (溝外径 − 溝内径) / 2
- つぶし率 = (d2 − H) / d2 × 100 [%]
- 溝充填率 = Oリング断面積 (π·d2²/4) / 溝断面積 (H × 溝幅) × 100 [%]
- 内径の伸び = (溝内径 − d1) / d1 × 100 [%]（Oリングを溝内径にはめる前提）
- 判定基準は JIS B 2401 の推奨値を使い、`search.js` に定数でまとめる。値はコードに直接書かない
  - 値（2026-11-09 にユーザーが JIS と照合済み）：
    - つぶし率：運動用 8〜20%、固定用 15〜30%。**上限（SqueezeMax）を超えるものと 0% 以下は除く**（上限での絞り込みは 2026-11-09 ユーザー指示）。下限では絞り込まない。範囲の中央は並び順の基準と溝深さの仮定に使う
    - 溝充填率：85% 以下
    - 内径の伸び：0〜5%
- 計算は軸側の溝（ピストン・軸に溝がある）だけ。穴側の溝は未対応で、判定条件に `RodSideNote` を必ず出す

## 出力
- 基準をすべて満たす候補を **P系列・G系列に分けて、系列ごとに最大2件** 表示する（一覧はグループ表示、P → G の順）
- 表示項目：呼び番号、線径（d2）、内径（d1）、溝内径 d（公差）、溝外径 D（公差）、溝幅 G（公差）
  - d・D・G は各Oリングの標準溝寸法（d = 呼び番号の数値、D = d + 線径ごとの差、G = BR条件ごとの標準溝幅）
  - 公差は `search.js` に線径ごとに持つ（出典：さくらシールのサイズ表。2026-11-09 にユーザーが JIS と照合済み）
- 並び順：内径の伸びが小さい順（内径未入力時は上の「入力」の並び順に従う）
- 候補がないときは、その旨と、どの条件で外れたかを表示する

## Uパッキン（油圧シリンダ用）
- 画面の「種類」で Oリング／Uパッキンを切り替える。入力は Oリングと同じ d・D・溝幅・バックアップリング（「用途」は使わない）
- 対象は阪上製作所の油圧用パッキンのうち主用途に「油圧シリンダ」とある NBR の8製品：GPY, GNY, RGY, RNY, ⓉSGY, ⓉSNY, SKY, KY(KKY)
  - PTFE の5製品（STシール ST/STS、SMJ、STK STR、STC）は対象外（ユーザー判断）
  - バルカーの Uパッキン UHP・MLP（ピストン用）、MLR（ロッド用）も同じサイズ表に入れている（2026-11-06 追加、ユーザー指示）
    - 出典：バルカー 油圧用パッキン カタログ https://23330894.fs1.hubspotusercontent-na2.net/hubfs/23330894/product_document/hydraulic-packing_doc.pdf（p.4 UHP、p.6 MLP、p.17 MLR）
    - H は表の書き方のまま両方入れている（例 `16(16.5)`。括弧の外＝タフレタン、括弧内＝No.2060・4060）。H は表示だけなので文字列で読む。Backup は空欄（カタログにバックアップの指示コードがない）
    - 公差は `PackingTolerance` に入れていない（表示しないため）。`ValquaProducts` は図・出典の表示切り替えに使う
  - NOK の Uパッキン UPH 型（ピストン・ロッド両用、Use=Both）も同じサイズ表に入れている（2026-11-06 追加、ユーザー指示）
    - 出典：NOK UPH 型 寸法表 https://www.edccorp.com.tw/UploadFile/PK/UPH.pdf（E-92〜E-97、大径寸法表を含む全 236 サイズ）
    - 列の対応：d→Inner、D→Outer、h→H、HA→GA、HB→GB、Backup＝併用バックアップリング BRT3 の部品番号（GN…、大径寸法表は空欄）。Code は呼び番号（UPH-6.3 など）
    - 図は `images/uph-piston.png`（E-92 の装着図）・`images/uph-rod.png`（E-94 の装着図）。右側の注記枠は白で消した。`NokProducts` は出典の表示切り替えに使う
- サイズ表は `data/sakagami_hydraulic.csv`（列：Product, Use=Piston/Rod/Both, Code=標準の指示コード, Inner=表の d, Outer=表の D, H, GA=溝幅 BRなし, GB=溝幅 BRあり, Backup=併用バックアップの指示コード, D1Dia=表の D1）
  - 出典：阪上製作所の製品ページ（https://www.sakagami-ltd.co.jp/products/hydraulic-seals/<製品>）の寸法表をそのまま転記（2026-11-05）
- 判定：d・D・溝幅それぞれ、表の値との差が許容差以内（`search.js` の `PackingDiaTol`・`PackingWidthTol`、初期値 0.5mm）。BR なし→GA、片側・両側→GB で比べる（表に両側の溝幅はない）
- 出力：製品ごとに最大 `MaxResults` 件、寸法の差が小さい順
  - 一覧の列：指示コード・使用箇所・d・D1・GA（BR 片側・両側のときは GB）・バックアップリング・メーカー（D の代わりに D1、H と溝幅の代わりに GA/GB を出す。2026-11-06 ユーザー指示）
  - D1 は各出典の表の D1：阪上は製品ページの寸法表（GNY・RNY・ⓉSNY は D1 がないので空欄）、バルカーは UHP・MLP の表（MLR は D1 がないので空欄）、NOK UPH は φD1。空欄は「—」と表示
- 検索結果に出す製品は search.js の `PackingProducts`。阪上は **2026-11-05 から一時的に SKY・KY だけ**（ユーザー指示）＋ UHP・MLP・MLR・UPH。サイズ表のデータは阪上8製品とも残している
- 公差：検索結果の d・D1・GA/GB の数値の後ろに表示する（2026-11-06 いったん削除後、ユーザー指示で再表示。色付きの枠）。D1 の公差は `D1`、呼び番号で溝幅の公差が違う製品（UHP・MLP）は `WidthByCode`（[GA, GB]）。h10 用に `FitIT10` を追加。公差の指定は `search.js` の `PackingTolerance`（出典：各製品ページの寸法指示図、2026-11-05 確認）
  - はめあい記号（H8・H9・h8・f8）は ISO 286（JIS B 0401）の表（`FitIT8` など、1600mm まで）から数値にする
  - d の公差はピストン用だけを表示する（両用の SKY・KY・UPH もロッド用は出さず、「ピストン」の文字も付けない。2026-11-06 ユーザー指示）。ロッド専用の製品（MLR など）はロッド用を出す
- 図：Uパッキンを選んだときは、溝の断面図の代わりに寸法指示図（`images/<製品>-piston.png`・`images/<製品>-rod.png`、今は SKY・KY・UHP・MLP・MLR・UPH。UHP・MLP はピストン用だけ、MLR はロッド用だけ、UPH は両方）を出す。最初は検索結果の先頭の製品、検索結果の行（Web版はカード）を選ぶとその製品の図に切り替わる
  - 出典：https://www.sakagami-ltd.co.jp/products/hydraulic-seals/<製品> の寸法指示図の余白を切り取ったもの。UHP・MLP・MLR はバルカーのカタログの図を切り取り、B寸法の注記枠は白で消した

## ダストシール（ロッド用）（2026-11-06 追加、ユーザー指示）
- 「種類」でダストシールを選ぶ。判定は Uパッキンと同じ `findPacking`（`products: DustProducts, label: 'ダストシール'`）。バックアップリング・用途は使わない（溝幅は GA で判定）
- 対象は SDR（阪上）・DHS（バルカー）・LBH・DKI（NOK）の4製品（ユーザー指定。DH は不要）
- サイズ表 `data/dust_seal.csv`（列は sakagami_hydraulic.csv と同じ。Inner=d、Outer=D、H=シール高さ、GA=GB=溝幅、D1Dia=入口側の穴径（SDR・DHS は表の C、LBH は φS、DKI は空欄））
  - 出典：SDR https://www.sakagami-ltd.co.jp/products/wipers/sdr ／ DHS バルカー 油圧用パッキン カタログ p.29 ／ LBH https://www.edccorp.com.tw/UploadFile/PK/LBH.pdf ／ DKI https://www.edccorp.com.tw/UploadFile/PK/DKI.pdf
  - DKI は圧入形で D＝ハウジング穴径。溝幅の公差は d の範囲で違うので `WidthByD` で持つ
- Web版：結果カードを選ぶと、図の D（緑）・溝幅（橙）・C（紫）の寸法記号を色付きの枠で示し、図の下にその数値を出す。枠の位置は index.html の `FIG_MARKS`（画像名ごとのピクセル座標）。図を差し替えたら座標も直す（2026-11-06 ユーザー指示）
- Uパッキン・Oリングも同じ色分け（2026-11-06 ユーザー指示）：d＝青、D＝緑、D1・C＝紫、溝幅（G・GA/GB）＝橙
  - Uパッキンは結果を選ぶと寸法指示図の d・D1・GA（BR ありは GB）に枠を付ける。D1 はピストン用の図だけ。UPH の図は HA・HB なので表示名も HA/HB
  - Oリングは結果を選ぶと、断面図の d・D・G の文字を色付きの枠で囲み、その呼び番号の標準溝寸法を出す（図の下）。最初は先頭の結果
- 入力はロッド径 d だけ（D・溝幅の欄は隠し、判定にも使わない。d のラベルは「ロッド径」。2026-11-06 ユーザー指示）
- 一覧の列：呼び番号・D・溝幅・C（各公差）・メーカー（d は出さない。2026-11-06 ユーザー指示）
  - 溝幅の記号は図に合わせ SDR・DHS は「G」、LBH・DKI は「H」と表示する（Web版 `W_LABEL`）
  - C はデータの D1Dia（公差は `D1`）。記号は図に合わせ SDR・DHS は「C」、LBH は「S」。DKI は図にないので出さない。Web版は図の C/S も紫の枠で示す
- Web版はメーカーごとに色分けする（カード左端の帯・見出しとメーカー欄の札。阪上=青、バルカー=青緑、NOK=赤。Uパッキンも同じ。2026-11-06 ユーザー指示）
- 図：`images/sdr-rod.png`（阪上製品ページの寸法指示図）、`lbh-rod.png`・`dki-rod.png`（NOK PDF の装着図、右下の注記枠は白で消した）、`dhs-rod.png`（バルカー カタログ p.29）。PDF は WinRT の Windows.Data.Pdf で画像化して切り出し

## ウェアリング（ピストン用）（2026-11-06 追加、ユーザー指示）
- 「種類」でウェアリングを選ぶ。判定は `findPacking`（`products: WearProducts, label: 'ウェアリング'`）。入力は d・D・溝幅（GA で判定）。用途・バックアップリングは使わない
- ユーザーは阪上・バルカー・NOK の ピストン用・ロッド用 を希望したが、各社の資料にあるのはピストン用だけだった（ロッド用は未対応）
- 対象：阪上 SW・SWA・SWB・SWO、NOK WR 型、バルカー WPL・WPG（`WearProducts`）
- サイズ表 `data/wear_ring.csv`（列は sakagami_hydraulic.csv と同じ。Inner＝d（溝底径）、Outer＝D（シリンダ内径）、H＝ウェアリングの幅、GA＝GB＝溝幅、D1Dia＝阪上の表の D1（ピストン外径。NOK・バルカーは空欄）、Backup は空欄）
  - 出典：阪上 https://www.sakagami-ltd.co.jp/products/wear-rings-and-bearings/<sw|swa|swb|swo> の寸法表（HTML からそのまま取得）／ NOK https://www.edccorp.com.tw/UploadFile/PK/WR.pdf（E-162〜E-164。WR-○○W は SPG・SPGW 用。呼び番号は `WR-18`・`WR-30W` の形）／ バルカー 油圧用パッキン カタログ p.33 WPL・p.34 WPG（呼び番号は `WPL100` の形）
  - NOK・バルカーは PDF を画像にして読み取り、d = D − 2t で検算した
- 公差（`PackingTolerance`）：SW・SWA の d は e7（ISO 286 の `FitIT7`・`FitEsE` を追加）。SWO-125 だけ d の公差が違うので `InnerByCode` で持つ。D1 の h8 は D1 の寸法で数値にする（それまで D1 は寸法 0 として計算していた）
- 一覧の列：呼び番号・d・D・溝幅（WR は H、ほかは G）・D1・メーカー（各公差付き）
- 図：`images/<製品>-piston.png`（阪上は製品ページの寸法指示図、WR・WPL・WPG はカタログの装着図を切り出し。WR は左上のロゴを白で消した）。枠は d・D・W・D1
- 呼び番号でまとめて探すときもウェアリングを含める（`findAllByName` の `wearTable`）

## 海外（トレルボルグ）（2026-11-10 追加、ユーザー指示）
- 「種類」で「海外（トレルボルグ）」を選ぶと「海外の種類」の欄が出る：油圧用ピストンシール／ロッドシール／スクレーパー/ワイパー／シール（すべて）／ウェアリング（ピストン用）。分類は https://www.trelleborg.com/ja-jp/seals/products-and-solutions の5分類（「油圧用シール」は製品一覧のない総合ページなので、4分類すべてを探す）
- 判定は `findPacking`（`products: TrelleborgProducts[種類]`）。入力は d・D・溝幅（GA で判定）。用途・バックアップリングは使わない
- 対象は代表製品だけ（ユーザー判断。各分類に約20製品あるが、まず代表製品で作り確認後に増やす）：`TrelleborgProducts`
  - ピストン：TGR-P（Turcon Glyd Ring、PG4x）、TSS2K-P（Turcon Stepseal 2K、PSK）
  - ロッド：TSS2K-R（Turcon Stepseal 2K、RSK）、TGR-R（Turcon Glyd Ring、RG4x）
  - スクレーパー：TEX2（Turcon Excluder 2、WE3）、WRM（Scraper WRM、WAP）
  - ウェアリング：SLY-P（Turcite Slydring ピストン用、GP）
- サイズ表 `data/trelleborg.csv`（列は sakagami_hydraulic.csv と同じ。Inner＝小さい方の径（ピストンは溝径 d1/d2、ロッドはロッド径 dN）、Outer＝大きい方の径（ピストンはボア径 DN、ロッドは溝径 D1/D3）、GA＝GB＝溝幅 L1/L2/L3、H＝Oリングのサイズ（WRM は Polypac 品番、SLY-P は厚さ W）、D1Dia＝WRM の D4、Code＝TSS 品番（材質コードなし））
  - 出典：Hydraulic Seals Catalog (Metric) Edition October 2026（https://www.trelleborg.com/seals/-/media/tss-media-repository/tss_website/pdf-and-other-literature/catalogs/hydraulic_complete_gb_en.pdf）の Table 83・104・13・48・146・170・190。`pdftotext -table` で読み取り、品番に入っている径（×10、X 付きは ×1）と表の径が全行一致することを確認（テストでも確認）。カタログで重複していた RG4305700 の1行は除いた
  - TEX2 の * 印（ISO 6195 Type D の溝）は Source の末尾に書いた
  - 全行 `Verified` は空（未照合の札が出る）。原本との照合はまだ
- 公差（`PackingTolerance`）：カタログの表の見出しどおり。ロッド径はカタログでは f8/h9 だが f8 で数値にする
- Web版：結果カードの記号は各製品の装着図に合わせる（index.html の `TB`）。メーカー色は紫（`mk-tb`）
- 図：`images/<製品キー小文字>-piston.png`／`-rod.png`（カタログの Installation Drawing を切り出し）。枠は `FIG_MARKS`
- 呼び番号でまとめて探すときも含める（`findAllByName` の `tbTable`、結果は `Trelleborg`）

## 構成
```
pakkinsagasi/
├─ pakkinsagasi.bat # 公開 URL をブラウザで開く（PC 用ランチャー）
├─ index.html       # Web版の画面（スマホ用。GitHub Pages で公開）
├─ search.js        # 計算・判定・並べ替えと判定基準の定数（画面に依存しない）
├─ manifest.webmanifest, sw.js, icon-*.png, apple-touch-icon.png  # ホーム画面に追加する用（sw.js は通信優先、圏外時のみキャッシュ。正常な応答だけ保存。公開ファイルを変えたら CACHE の版を上げる）
├─ data/
│  ├─ oring_jis_b2401.csv
│  ├─ sakagami_hydraulic.csv   # Uパッキン（油圧）のサイズ表
│  ├─ dust_seal.csv
│  ├─ wear_ring.csv
│  └─ trelleborg.csv           # 海外（トレルボルグ）のサイズ表
└─ tests/
   └─ search.test.js
```

## 公開
- 社内向け。公開先は https://dragon131255.github.io/pakkinsagasi/ （このリポジトリの main を GitHub Pages で公開）
- 旧 pakkinsagasi-web リポジトリは 2026-11-09 に Pages 停止・アーカイブ済み
- 画面に「検索結果は参考値」の注意書きを出す（結果の下）

## 開発ルール
- 計算処理（search.js）と画面（index.html）を分ける。計算はテストで確認できるようにする
- 規格表の数値は JIS B 2401 の原本から転記し、推測で埋めない
- 入力値が不正（0以下、外径 ≤ 内径など）のときは画面でエラーを表示する
- 判定基準・計算式を変えたら tests/search.test.js も直し、テストを通してから push する（push すると公開サイトにすぐ反映される）
  - 規格表は `data/oring_jis_b2401.csv` を読む（fetch するため、ローカルではファイルを直接開かず HTTP サーバー経由で確認する）

## 未決事項
- 外側シール（溝が穴側にある場合）の判定式は今は扱わない。必要になったら追加する
