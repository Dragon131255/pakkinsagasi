// 計算・判定・並べ替えと判定基準の定数（画面は index.html）。計算はこのファイルだけ
// 判定基準や計算式を変えたら tests/search.test.js も直す
(function (root) {
  'use strict';

  // ---- 判定基準（JIS B 2401 の推奨値。2026-11-09 にユーザーが照合済み） ----
  var Criteria = {
    Dynamic: { SqueezeMin: 8, SqueezeMax: 20, Series: ['P'] },
    Static: { SqueezeMin: 15, SqueezeMax: 30, Series: ['P', 'G'] },
    // 平面固定・内圧用（2026-11-12 追加、ユーザー指示。出典：さくらシール G規格サイズ表の「平面溝-内圧用」）
    FaceInner: { SqueezeMin: 15, SqueezeMax: 30, Series: ['G'], Face: true }
  };
  // 平面溝・内圧用：Oリング外周を溝の外壁に当てる。外径の縮み = (Oリング外径 − 溝外径 D) / Oリング外径 [%]
  // ※ 範囲は仮の値（JIS 未照合）。標準溝は D = Oリング外径（縮み 0%）
  var FaceOuterCompMin = 0, FaceOuterCompMax = 3;
  // 平面溝の標準寸法（さくらシール G規格サイズ表）：G＝溝幅（+0.25/0）、H＝溝深さ（±0.05）
  var FaceGroove = { G: { 3.1: { G: 4.1, H: 2.4 }, 5.7: { G: 7.5, H: 4.6 } } };
  var FaceDepthTolerance = 0.05;
  var FaceNote = '※ 平面溝（内圧用）：Oリングの外周を溝の外壁（D）に当てる。溝外径 D の標準は Oリング外径';
  var FillMax = 85, StretchMin = 0, StretchMax = 5, MaxResults = 2, NameMaxResults = 30;
  var RodSideNote = '※ 軸側の溝（ピストン・軸に溝がある）だけに対応。穴側の溝（ハウジングに溝がある）は未対応';
  // 記号・空白だけの検索語（比較用の文字が残らない）はエラーにする
  function assertNameKey(name) { if (nameKey(name) === '') throw new Error('検索には英数字を1文字以上入力してください。'); }

  // 呼び番号の比較用：全角→半角、大文字にし、ハイフン・空白・* などを除く
  function nameKey(s) { return String(s == null ? '' : s).normalize('NFKC').toUpperCase().replace(/[\s\-_*・－ー]/g, ''); }
  // 呼び番号が name と完全に一致する行があればそれだけ。なければ name を含む行を 前方一致 → 部分一致、表の順で返す
  function selectByName(table, prop, name) {
    var key = nameKey(name);
    var hits = table.map(function (r, i) {
      var k = nameKey(r[prop]);
      return { r: r, i: i, rank: k.indexOf(key) < 0 ? -1 : k === key ? 0 : k.indexOf(key) === 0 ? 1 : 2 };
    }).filter(function (x) { return x.rank >= 0; });
    var exact = hits.filter(function (x) { return x.rank === 0; });
    return (exact.length ? exact : hits)
      .sort(function (a, b) { return a.rank - b.rank || a.i - b.i; })
      .map(function (x) { return x.r; });
  }
  var GrooveTolerance = {
    P: { 1.9: 0.05, 2.4: 0.06, 3.5: 0.08, 5.7: 0.10, 8.4: 0.10 },
    G: { 3.1: 0.10, 5.7: 0.10 }
  };
  var GrooveWidthTolerance = 0.25;
  var GrooveDiff = {
    P: { 1.9: 3.0, 2.4: 4.0, 3.5: 6.0, 5.7: 10.0, 8.4: 15.0 },
    G: { 3.1: 5.0, 5.7: 10.0 }
  };
  var GrooveWidthStd = {
    P: { 1.9: [2.5, 3.9, 5.4], 2.4: [3.2, 4.4, 6.0], 3.5: [4.7, 6.0, 7.8], 5.7: [7.5, 9.0, 11.5], 8.4: [11.0, 13.0, 17.0] },
    G: { 3.1: [4.1, 5.6, 7.3], 5.7: [7.5, 9.0, 11.5] }
  };

  function parseTable(csv) {
    var lines = csv.replace(/^﻿/, '').trim().split(/\r?\n/);
    var head = lines.shift().split(',');
    return lines.map(function (line) {
      var c = line.split(','), o = {};
      head.forEach(function (h, i) { o[h.trim()] = (c[i] || '').trim(); });
      return { Series: o.Series, Name: o.Name, D1: +o.D1, D2: +o.D2, Source: o.Source || '', Verified: o.Verified || '' };
    });
  }

  function f(v, n) { return v.toFixed(n); }

  // 平面溝・内圧用：入力は 溝外径 D（outer）・溝幅 G（width）・溝深さ H（depth）
  function findORingFace(opt, c) {
    var go = opt.outer, gw = opt.width, gh = opt.depth;
    var hasOuter = go != null, hasWidth = gw != null, hasDepth = gh != null;
    if (!(hasOuter || hasWidth || hasDepth)) throw new Error('溝の外径・溝幅・溝深さのどれか1つ以上を入力してください。');
    [go, gw, gh].forEach(function (v) {
      if (v != null && v <= 0) throw new Error('寸法には0より大きい値を入力してください。');
    });
    var mid = (c.SqueezeMin + c.SqueezeMax) / 2;

    var notes = [];
    if (hasOuter) notes.push('外径の縮み ' + FaceOuterCompMin + '〜' + FaceOuterCompMax + '%');
    if (hasDepth) notes.push('つぶし率 0%超・' + c.SqueezeMax + '% 以下');
    if (hasWidth) {
      notes.push('溝充填率 ' + FillMax + '% 以下');
      if (!hasDepth) notes.push('（溝深さは未入力のため、つぶし率 ' + mid + '% になる溝深さを仮定）');
    }
    notes.push(FaceNote);

    var evaluated = [];
    opt.table.forEach(function (r) {
      if (c.Series.indexOf(r.Series) < 0) return;
      var od = r.D1 + 2 * r.D2;
      var comp = hasOuter ? (od - go) / od * 100 : null;
      var h = hasDepth ? gh : r.D2 * (1 - mid / 100);
      var squeeze = hasDepth ? (r.D2 - h) / r.D2 * 100 : null;
      var fill = hasWidth ? (Math.PI * r.D2 * r.D2 / 4) / (h * gw) * 100 : null;
      var std = (FaceGroove[r.Series] || {})[r.D2] || null;
      evaluated.push({
        Series: r.Series, Name: r.Name, D1: r.D1, D2: r.D2, Source: r.Source || '', Verified: r.Verified || '', Face: true,
        TolInner: '—', TolOuter: '—',
        TolWidth: '+' + f(GrooveWidthTolerance, 2) + ' / 0',
        TolDepth: '±' + f(FaceDepthTolerance, 2),
        StdInner: null, StdOuter: +od.toFixed(2),
        StdWidth: std ? std.G : null, StdDepth: std ? std.H : null,
        Depth: h, Squeeze: squeeze, Fill: fill, OuterComp: comp, Stretch: null,
        CompOk: !hasOuter || (comp >= FaceOuterCompMin - 1e-9 && comp <= FaceOuterCompMax),
        SqueezeOk: !hasDepth || (squeeze > 0 && squeeze <= c.SqueezeMax),
        FillOk: !hasWidth || fill <= FillMax
      });
    });

    var key = hasOuter ? function (x) { return x.OuterComp; }
      : hasDepth ? function (x) { return Math.abs(x.Squeeze - mid); }
        : function (x) { return FillMax - x.Fill; };
    var candidates = [];
    c.Series.forEach(function (s) {
      candidates = candidates.concat(evaluated
        .filter(function (x) { return x.Series === s && x.CompOk && x.SqueezeOk && x.FillOk; })
        .sort(function (a, b) { return key(a) - key(b); })
        .slice(0, MaxResults));
    });

    var reasons = [];
    if (!candidates.length) {
      var fitting = evaluated.filter(function (x) { return x.CompOk; });
      if (!fitting.length) {
        reasons.push(hasOuter
          ? '溝外径に合う外径のOリングがありません（外径の縮み ' + FaceOuterCompMin + '〜' + FaceOuterCompMax + '% の範囲外）。'
          : '入力した寸法に合うOリングがありません。');
      } else {
        fitting.forEach(function (x) {
          var ng = [];
          if (!x.SqueezeOk) ng.push('つぶし率 ' + f(x.Squeeze, 1) + (x.Squeeze <= 0 ? '%（つぶれないためシールしない）' : '%（上限 ' + c.SqueezeMax + '%）'));
          if (!x.FillOk) ng.push('溝充填率 ' + f(x.Fill, 1) + '%（上限 ' + FillMax + '%）');
          reasons.push(x.Name + '：' + ng.join('、'));
        });
        if (reasons.length > 10) reasons = reasons.slice(0, 10).concat('…ほか ' + (reasons.length - 10) + ' 件');
      }
    }
    return { GrooveDepth: hasDepth ? gh : null, Candidates: candidates, Reasons: reasons, Notes: notes, ByName: false, Total: candidates.length, Face: true };
  }

  function findORing(opt) {
    if (!(opt.name || '').trim() && Criteria[opt.use] && Criteria[opt.use].Face) return findORingFace(opt, Criteria[opt.use]);
    var gi = opt.inner, go = opt.outer, gw = opt.width;
    var hasInner = gi != null, hasOuter = go != null, hasWidth = gw != null;
    var brIndex = { None: 0, One: 1, Both: 2 }[opt.backupRing || 'None'];
    var name = (opt.name || '').trim(), byName = !!name, table = opt.table;
    if (byName) { assertNameKey(name); gi = go = gw = null; hasInner = hasOuter = hasWidth = false; table = selectByName(table, 'Name', name); }

    if (!(hasInner || hasOuter || hasWidth || byName)) throw new Error('溝の内径・外径・溝幅のどれか1つ以上を入力してください。');
    [gi, go, gw].forEach(function (v) {
      if (v != null && v <= 0) throw new Error('寸法には0より大きい値を入力してください。');
    });
    if (hasInner && hasOuter && go <= gi) throw new Error('溝の外径は内径より大きい値を入力してください。');

    var c = Criteria[opt.use];
    var mid = (c.SqueezeMin + c.SqueezeMax) / 2;

    var notes = [];
    if (hasInner) notes.push('内径の伸び ' + StretchMin + '〜' + StretchMax + '%');
    if (hasOuter) {
      notes.push('つぶし率 0%超・' + c.SqueezeMax + '% 以下');
      if (!hasInner) notes.push('（溝内径は未入力のため、Oリング内径 d1 にはまる前提で溝深さを計算）');
    }
    if (hasWidth) {
      notes.push('溝充填率 ' + FillMax + '% 以下');
      if (brIndex > 0) notes.push('（溝幅からバックアップリングの分＝標準溝幅のBRありとBRなしの差を引いて計算）');
      if (!hasOuter) notes.push('（溝外径は未入力のため、つぶし率 ' + mid + '% になる溝深さを仮定）');
    }
    notes.push(RodSideNote);

    var evaluated = [];
    table.forEach(function (r) {
      if (!byName && c.Series.indexOf(r.Series) < 0) return;

      var stretch = null;
      if (hasInner) stretch = (gi - r.D1) / r.D1 * 100;

      var squeeze = null, h;
      if (hasOuter) {
        var seat = hasInner ? gi : r.D1;
        h = (go - seat) / 2;
        if (h <= 0) return;
        squeeze = (r.D2 - h) / r.D2 * 100;
      } else {
        h = r.D2 * (1 - mid / 100);
      }

      var std = (GrooveWidthStd[r.Series] || {})[r.D2] || null;
      var brSpace = std ? std[brIndex] - std[0] : 0;

      var fill = null;
      if (hasWidth) {
        var w = gw - brSpace;
        fill = w <= 0 ? Infinity : (Math.PI * r.D2 * r.D2 / 4) / (h * w) * 100;
      }

      var tol = (GrooveTolerance[r.Series] || {})[r.D2];
      var stdD1 = null, stdD2 = null, m = /^[A-Z]+([\d.]+)/.exec(r.Name);
      if (m) {
        stdD1 = +m[1];
        var diff = (GrooveDiff[r.Series] || {})[r.D2];
        if (diff != null) stdD2 = stdD1 + diff;
      }

      evaluated.push({
        Series: r.Series, Name: r.Name, D1: r.D1, D2: r.D2, Source: r.Source || '', Verified: r.Verified || '',
        TolInner: tol != null ? '0 / -' + f(tol, 2) : '—',
        TolOuter: tol != null ? '+' + f(tol, 2) + ' / 0' : '—',
        TolWidth: '+' + f(GrooveWidthTolerance, 2) + ' / 0',
        StdWidth: std ? std[brIndex] : null,
        StdInner: stdD1, StdOuter: stdD2,
        Depth: h, Squeeze: squeeze, Fill: fill, Stretch: stretch,
        StretchOk: !hasInner || (stretch >= StretchMin && stretch <= StretchMax),
        // つぶし率は 0% 超 かつ 用途ごとの上限以下（下限では絞り込まない）
        SqueezeOk: !hasOuter || (squeeze > 0 && squeeze <= c.SqueezeMax),
        FillOk: !hasWidth || fill <= FillMax
      });
    });

    var key = hasInner ? function (x) { return x.Stretch; }
      : hasOuter ? function (x) { return Math.abs(x.Squeeze - mid); }
        : function (x) { return FillMax - x.Fill; };

    var candidates = [];
    c.Series.forEach(function (s) {
      candidates = candidates.concat(evaluated
        .filter(function (x) { return x.Series === s && x.StretchOk && x.SqueezeOk && x.FillOk; })
        .sort(function (a, b) { return key(a) - key(b); })
        .slice(0, MaxResults));
    });

    var total = candidates.length;
    if (byName) {   // 一致の近い順に最大 NameMaxResults 件
      total = evaluated.length; candidates = evaluated.slice(0, NameMaxResults);
      notes = ['呼び番号に「' + name + '」を含むもの（寸法・用途は使いません）'];
    }

    var reasons = [];
    if (byName) { if (!candidates.length) reasons.push('呼び番号に「' + name + '」を含むOリングはありません。'); }
    else if (candidates.length === 0) {
      var fitting = evaluated.filter(function (x) { return x.StretchOk; });
      if (fitting.length === 0) {
        reasons.push(hasInner
          ? '溝内径に合う内径のOリングがありません（内径の伸び ' + StretchMin + '〜' + StretchMax + '% の範囲外）。'
          : '入力した寸法に合うOリングがありません。');
      } else {
        fitting.forEach(function (x) {
          var ng = [];
          if (!x.SqueezeOk) ng.push('つぶし率 ' + f(x.Squeeze, 1) + (x.Squeeze <= 0 ? '%（つぶれないためシールしない）' : '%（上限 ' + c.SqueezeMax + '%）'));
          if (!x.FillOk) ng.push('溝充填率 ' + f(x.Fill, 1) + '%（上限 ' + FillMax + '%）');
          reasons.push(x.Name + '：' + ng.join('、'));
        });
        if (reasons.length > 10) reasons = reasons.slice(0, 10).concat('…ほか ' + (reasons.length - 10) + ' 件');
      }
    }

    return {
      GrooveDepth: hasInner && hasOuter ? (go - gi) / 2 : null,
      Candidates: candidates, Reasons: reasons, Notes: notes, ByName: byName, Total: total
    };
  }

  // ---- 阪上パッキン（油圧シリンダ用） ----
  var PackingDiaTol = 0.5, PackingWidthTol = 0.5;   // d・D・溝幅の許容差 [mm]
  var PackingProducts = ['SKY', 'KY', 'UHP', 'MLP', 'MLR', 'UPH'];   // 検索結果に出す製品（阪上は一時的に SKY・KY だけ）

  // 溝寸法の公差（出典：阪上製作所の寸法指示図）
  var PackingTolerance = {
    'GPY': { Piston: { Inner: 'h8', Outer: 'H9' }, Width: '+0.25/0' },
    'GNY': { Rod: { Inner: 'f8', Outer: 'H8' }, Width: '+0.25/0' },
    'RGY': { Piston: { Inner: '+0.2/0', Outer: 'H9' }, Width: '±0.2' },
    'RNY': { Rod: { Inner: 'f8', Outer: '0/-0.2' }, Width: '±0.2' },
    'ⓉSGY': { Piston: { Inner: '+0.2/0', Outer: 'H9' }, Width: '±0.2' },
    'ⓉSNY': { Rod: { Inner: 'f8', Outer: '0/-0.2' }, Width: '±0.2' },
    'SKY': { Piston: { Inner: '+0.2/0', Outer: 'H9' }, Rod: { Inner: 'f8', Outer: '0/-0.2' }, Width: '±0.2', D1: '±0.2' },
    'KY': { Piston: { Inner: 'h8', Outer: 'H9' }, Rod: { Inner: 'f8', Outer: 'H9' }, Width: '±0.2', D1: '±0.2' },
    // バルカー（カタログ p.4・6・17）。WidthByCode：呼び番号ごとの溝幅の公差 [GA, GB]
    'UHP': { Piston: { Inner: '+0.2/0', Outer: 'H9' }, Width: '+0.5/0', D1: '±0.2',
      WidthByCode: { UHP40: ['+0.3/0', '+0.3/0'], UHP50: ['+0.3/0', '+0.3/0'], UHP63: ['+0.3/0', '+0.3/0'], UHP80: ['+0.3/0', '+0.3/0'], UHP90: ['+0.3/0', '+0.3/0'],
        UHP125: ['+0.3/0', '+0.5/0'], UHP150: ['+0.3/0', '+0.5/0'] } },
    'MLP': { Piston: { Inner: '+0.2/0', Outer: 'H9' }, Width: '+0.5/0', D1: '±0.2',
      WidthByCode: { MLP40: ['+0.3/0', '+0.3/0'], MLP50: ['+0.3/0', '+0.3/0'], MLP63: ['+0.3/0', '+0.3/0'], MLP80: ['+0.3/0', '+0.3/0'] } },
    'MLR': { Rod: { Inner: 'f8', Outer: '0/-0.2' }, Width: '+0.5/0' },
    // NOK（UPH 型 E-92 ピストン、E-94 ロッド）
    'UPH': { Piston: { Inner: 'h10', Outer: 'H9' }, Rod: { Inner: 'f8', Outer: 'H10' }, Width: '±0.2', D1: '±0.2' },
    // ---- ダストシール（data/dust_seal.csv）。WidthByD：d の範囲ごとの溝幅の公差 [d の上限, 公差] ----
    'SDR': { Rod: { Inner: 'f8', Outer: '0/-0.2' }, Width: '±0.2', D1: '±0.1' },
    'DHS': { Rod: { Inner: 'f8', Outer: '0/-0.2' }, Width: '+0.3/0', D1: '±0.1' },
    'DKI': { Rod: { Inner: 'f8', Outer: 'H8' }, Width: '+0.5/+0.3',
      WidthByD: [[50, '+0.5/+0.3'], [175, '+0.6/+0.4'], [300, '+0.7/+0.5']] },
    'LBH': { Rod: { Inner: 'f8', Outer: '0/-0.2' }, Width: '±0.2', D1: '±0.1' },
    // ---- ウェアリング（data/wear_ring.csv。すべてピストン用）。InnerByCode：呼び番号ごとに d の公差が違うとき ----
    'SW': { Piston: { Inner: 'e7', Outer: 'H9' }, Width: '±0.1', D1: '0/-0.05' },
    'SWA': { Piston: { Inner: 'e7', Outer: 'H9' }, Width: '±0.1', D1: 'h8' },
    'SWB': { Piston: { Inner: '+0.07/+0.02', Outer: 'H9' }, Width: '+0.2/0', D1: 'h8' },
    'SWO': { Piston: { Inner: '0/-0.05', Outer: 'H9' }, Width: '+0.2/0', D1: 'h8', InnerByCode: { 'SWO-125': '0/-0.08' } },
    'WR': { Piston: { Inner: '0/-0.05', Outer: 'H9' }, Width: '+0.1/0' },
    'WPL': { Piston: { Inner: 'h9', Outer: 'H9' }, Width: '+0.1/0' },
    'WPG': { Piston: { Inner: 'h9', Outer: 'H9' }, Width: '+0.1/0' },
    // ---- 海外：トレルボルグ（data/trelleborg.csv。出典 Hydraulic Seals Catalog (Metric) 2026年10月版）----
    // ロッド径の公差はカタログでは f8/h9。ここでは f8 で数値にする
    'TGR-P': { Piston: { Inner: 'h9', Outer: 'H9' }, Width: '+0.2/0' },
    'TSS2K-P': { Piston: { Inner: 'h9', Outer: 'H9' }, Width: '+0.2/0' },
    'TSS2K-R': { Rod: { Inner: 'f8', Outer: 'H9' }, Width: '+0.2/0' },
    'TGR-R': { Rod: { Inner: 'f8', Outer: 'H9' }, Width: '+0.2/0' },
    'TEX2': { Rod: { Inner: 'f8', Outer: 'H9' }, Width: '+0.2/0' },
    'WRM': { Rod: { Inner: 'f8', Outer: 'H9' }, Width: '+0.2/0', D1: '+0.2/0' },
    'SLY-P': { Piston: { Inner: 'h8', Outer: 'H9' }, Width: '+0.2/0' }
  };
  // 海外（トレルボルグ）の種類ごとの検索対象。all は「シール（すべて）」
  var TrelleborgProducts = { piston: ['TGR-P', 'TSS2K-P'], rod: ['TSS2K-R', 'TGR-R'], scraper: ['TEX2', 'WRM'], wear: ['SLY-P'] };
  TrelleborgProducts.all = [].concat(TrelleborgProducts.piston, TrelleborgProducts.rod, TrelleborgProducts.scraper, TrelleborgProducts.wear);
  var DustProducts = ['SDR', 'LBH', 'DHS', 'DKI'];   // ダストシールの検索対象
  var WearProducts = ['SW', 'SWA', 'SWB', 'SWO', 'WR', 'WPL', 'WPG'];   // ウェアリングの検索対象
  // ISO 286（JIS B 0401）[µm]：寸法区分の上限 [mm]、IT8、IT9、f の上の寸法許容差
  var FitSizeUpper = [3, 6, 10, 18, 30, 50, 80, 120, 180, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600];
  var FitIT8 = [14, 18, 22, 27, 33, 39, 46, 54, 63, 72, 81, 89, 97, 110, 125, 140, 165, 195];
  var FitIT9 = [25, 30, 36, 43, 52, 62, 74, 87, 100, 115, 130, 140, 155, 175, 200, 230, 260, 310];
  var FitIT10 = [40, 48, 58, 70, 84, 100, 120, 140, 160, 185, 210, 230, 250, 280, 320, 360, 420, 500];
  // IT7 と e の上の寸法許容差（ウェアリングの e7 用）
  var FitIT7 = [10, 12, 15, 18, 21, 25, 30, 35, 40, 46, 52, 57, 63, 70, 80, 90, 105, 125];
  var FitEsE = [-14, -20, -25, -32, -40, -50, -60, -72, -85, -100, -110, -125, -135, -145, -160, -170, -195, -220];
  var FitEsF = [-6, -10, -13, -16, -20, -25, -30, -36, -43, -50, -56, -62, -68, -76, -80, -86, -98, -110];

  function formatPackingTol(spec, size) {
    var um = function (v) { return v === 0 ? '0' : (v > 0 ? '+' : '-') + (Math.abs(v) / 1000).toFixed(3); };
    var m = /^([Hhfe])(7|8|9|10)$/.exec(spec);
    if (m) {
      var i = 0;
      while (i < FitSizeUpper.length && size > FitSizeUpper[i]) i++;
      if (i >= FitSizeUpper.length) return spec;
      var it = { '7': FitIT7, '8': FitIT8, '9': FitIT9, '10': FitIT10 }[m[2]][i], hi, lo;
      if (m[1] === 'H') { hi = it; lo = 0; } else if (m[1] === 'h') { hi = 0; lo = -it; }
      else { var es = (m[1] === 'e' ? FitEsE : FitEsF)[i]; hi = es; lo = es - it; }
      return spec + ' ' + um(hi) + ' / ' + um(lo);
    }
    m = /^([+\-]?[\d.]+)\/([+\-]?[\d.]+)$/.exec(spec);
    return m ? m[1] + ' / ' + m[2] : spec;
  }

  function getPackingTol(r, withBR) {
    var t = PackingTolerance[r.Product];
    if (!t) return { Inner: '—', Outer: '—', Width: '—', D1: '' };
    var w = t.WidthByCode && t.WidthByCode[r.Code] ? t.WidthByCode[r.Code][withBR ? 1 : 0] : t.Width;
    if (t.WidthByD) for (var b = 0; b < t.WidthByD.length; b++) if (r.D1 <= t.WidthByD[b][0]) { w = t.WidthByD[b][1]; break; }
    var d1 = t.D1 && r.DiaD1 !== '' ? formatPackingTol(t.D1, +r.DiaD1 || 0) : '';   // D1 のはめあい記号は D1 の寸法で決める
    var inner = [], outer = [];
    ['Piston', 'Rod'].forEach(function (u) {
      if (!t[u]) return;
      var label = r.Use === 'Both' ? { Piston: 'ピストン ', Rod: 'ロッド ' }[u] : '';
      inner.push(label + formatPackingTol(t[u].Inner, r.D1));
      outer.push(label + formatPackingTol(t[u].Outer, r.D2));
    });
    // d の公差はピストン用だけを出す（両用もロッド用は出さず「ピストン」の文字も付けない。ロッド専用の製品はロッド用）
    var innerTol = t.Piston ? formatPackingTol(t.Piston.Inner, r.D1) : inner.join('／');
    if (t.InnerByCode && t.InnerByCode[r.Code]) innerTol = formatPackingTol(t.InnerByCode[r.Code], r.D1);
    return { Inner: innerTol, Outer: outer.join('／'), Width: formatPackingTol(w, 0), D1: d1 };
  }

  function parsePackingTable(csv) {
    var lines = csv.replace(/^﻿/, '').trim().split(/\r?\n/);
    var head = lines.shift().split(',');
    return lines.map(function (line) {
      var c = line.split(','), o = {};
      head.forEach(function (h, i) { o[h.trim()] = (c[i] || '').trim(); });
      return { Product: o.Product, Use: o.Use, Code: o.Code, D1: +o.Inner, D2: +o.Outer, H: o.H, GA: +o.GA, GB: +o.GB, Backup: o.Backup, DiaD1: o.D1Dia || '', Source: o.Source || '', Verified: o.Verified || '' };
    });
  }

  function findPacking(opt) {
    var gi = opt.inner, go = opt.outer, gw = opt.width;
    var products = opt.products || PackingProducts, table = opt.table;
    var name = (opt.name || '').trim(), byName = !!name;
    if (byName) { assertNameKey(name); gi = go = gw = null; table = selectByName(table.filter(function (r) { return products.indexOf(r.Product) >= 0; }), 'Code', name); }
    var hasInner = gi != null, hasOuter = go != null, hasWidth = gw != null;
    if (!(hasInner || hasOuter || hasWidth || byName)) throw new Error('溝の内径・外径・溝幅のどれか1つ以上を入力してください。');
    [gi, go, gw].forEach(function (v) {
      if (v != null && v <= 0) throw new Error('寸法には0より大きい値を入力してください。');
    });
    if (hasInner && hasOuter && go <= gi) throw new Error('溝の外径は内径より大きい値を入力してください。');
    var br = opt.backupRing || 'None', withBR = br !== 'None';

    var notes = [];
    if (hasInner) notes.push('d の差 ±' + PackingDiaTol + ' mm 以内');
    if (hasOuter) notes.push('D の差 ±' + PackingDiaTol + ' mm 以内');
    if (hasWidth) {
      notes.push('溝幅の差 ±' + PackingWidthTol + ' mm 以内（' + (withBR ? 'バックアップリングありの溝幅 GB' : 'バックアップリングなしの溝幅 GA') + '）');
      if (br === 'Both') notes.push('（サイズ表に両側の溝幅はないため、バックアップリングありの溝幅で判定）');
    }

    var matched = [];
    table.forEach(function (r, i) {
      if (products.indexOf(r.Product) < 0) return;
      var w = withBR ? r.GB : r.GA, dev = 0, e;
      if (hasInner) { e = Math.abs(gi - r.D1); if (e > PackingDiaTol + 1e-9) return; dev += e; }
      if (hasOuter) { e = Math.abs(go - r.D2); if (e > PackingDiaTol + 1e-9) return; dev += e; }
      if (hasWidth) { e = Math.abs(gw - w); if (e > PackingWidthTol + 1e-9) return; dev += e; }
      var tol = getPackingTol(r, withBR);
      matched.push({ Product: r.Product, Use: r.Use, Code: r.Code, D1: r.D1, D2: r.D2, DiaD1: r.DiaD1, H: r.H, Width: w,
        TolInner: tol.Inner, TolOuter: tol.Outer, TolWidth: tol.Width, TolD1: tol.D1,
        Backup: withBR ? r.Backup : '', Source: r.Source || '', Verified: r.Verified || '', Deviation: dev, Order: i });
    });

    var byDev = function (a, b) { return a.Deviation - b.Deviation || a.Order - b.Order; };
    var groups = {}, names = [];
    matched.forEach(function (m) { if (!groups[m.Product]) { groups[m.Product] = []; names.push(m.Product); } groups[m.Product].push(m); });
    var tops = names.map(function (n) { return groups[n].sort(byDev).slice(0, MaxResults); });
    tops.sort(function (a, b) { return byDev(a[0], b[0]); });
    var candidates = [].concat.apply([], tops), total = candidates.length;
    var reasons = candidates.length ? [] : ['入力した寸法に合う' + (opt.label || 'パッキン') + 'はありません（許容差の範囲外）。'];
    if (byName) {   // 一致の近い順（selectByName の順）に最大 NameMaxResults 件
      total = matched.length; candidates = matched.slice(0, NameMaxResults);
      notes = ['呼び番号に「' + name + '」を含むもの（寸法は使いません）'];
      reasons = candidates.length ? [] : ['呼び番号に「' + name + '」を含む' + (opt.label || 'パッキン') + 'はありません。'];
    }

    return { Candidates: candidates, Reasons: reasons, Notes: notes, ByName: byName, Total: total };
  }

  // 呼び番号で、種類（Oリング・Uパッキン・ダストシール）を選ばずにまとめて探す
  // どれかの種類に完全一致があれば、完全一致のない種類の結果は出さない（Total も 0 にする）
  function findAllByName(opt) {
    var key = nameKey(opt.name), br = opt.backupRing || 'None';
    var all = {
      ORing: findORing({ use: 'Static', backupRing: br, table: opt.oringTable, name: opt.name }),
      Packing: findPacking({ backupRing: br, table: opt.packingTable, name: opt.name }),
      Dust: findPacking({ table: opt.dustTable, products: DustProducts, label: 'ダストシール', name: opt.name }),
      Wear: findPacking({ table: opt.wearTable || [], products: WearProducts, label: 'ウェアリング', name: opt.name }),
      Trelleborg: findPacking({ table: opt.tbTable || [], products: TrelleborgProducts.all, label: 'トレルボルグの製品', name: opt.name })
    };
    var exact = {};
    Object.keys(all).forEach(function (k) {
      var prop = k === 'ORing' ? 'Name' : 'Code';
      exact[k] = all[k].Candidates.some(function (c) { return nameKey(c[prop]) === key; });
    });
    if (Object.keys(exact).some(function (k) { return exact[k]; })) {
      Object.keys(all).forEach(function (k) { if (!exact[k]) { all[k].Candidates = []; all[k].Total = 0; } });
    }
    return all;
  }

  var api = { findAllByName: findAllByName, parseTable: parseTable, findORing: findORing, parsePackingTable: parsePackingTable, findPacking: findPacking, DustProducts: DustProducts, WearProducts: WearProducts, MaxResults: MaxResults,
    PackingProducts: PackingProducts, TrelleborgProducts: TrelleborgProducts, NameMaxResults: NameMaxResults, formatPackingTol: formatPackingTol };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.Pakkin = api;
})(this);
