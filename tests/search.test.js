// search.js（Web版の計算）のテスト。実行：node --test tests
// tests/Search.Tests.ps1（PowerShell版）と同じ内容を確認する
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const P = require('../search.js');

const read = (f) => fs.readFileSync(path.join(__dirname, '..', 'data', f), 'utf8');
const table = P.parseTable(read('oring_jis_b2401.csv'));
const ptable = P.parsePackingTable(read('sakagami_hydraulic.csv'));
const dtable = P.parsePackingTable(read('dust_seal.csv'));
const wtable = P.parsePackingTable(read('wear_ring.csv'));
const allProducts = ['GPY', 'GNY', 'RGY', 'RNY', 'ⓉSGY', 'ⓉSNY', 'SKY', 'KY', 'UHP', 'MLP', 'MLR', 'UPH'];

const names = (r) => r.Candidates.map((c) => c.Name);
const codes = (r) => r.Candidates.map((c) => c.Code);
const ofSeries = (r, s) => r.Candidates.filter((c) => c.Series === s);

test.describe('findORing', () => {
  test.it('固定用：G25 の溝で G25 が先頭に出る', () => {
    const r = P.findORing({ inner: 25, outer: 30, width: 4.1, use: 'Static', table });
    assert.equal(r.GrooveDepth, 2.5);
    const g = ofSeries(r, 'G');
    assert.equal(g[0].Name, 'G25');
    assert.equal(Math.round(g[0].Squeeze * 10) / 10, 19.4);
  });

  test.it('運動用：P20 の溝で P20 が出て、G系列は出ない', () => {
    const r = P.findORing({ inner: 20, outer: 24, width: 3.2, use: 'Dynamic', table });
    assert.equal(r.Candidates[0].Name, 'P20');
    assert.equal(names(r).filter((n) => n.startsWith('G')).length, 0);
  });

  test.it('候補は系列ごとに最大2件で、P → G の順に並ぶ', () => {
    const r = P.findORing({ inner: 100, outer: 108, width: 7.5, use: 'Static', table });
    assert.ok(ofSeries(r, 'P').length <= 2);
    assert.ok(ofSeries(r, 'G').length <= 2);
    assert.match(r.Candidates.map((c) => c.Series).join(''), /^P*G*$/);
  });

  test.it('合わないときは理由を返す', () => {
    const r = P.findORing({ inner: 25, outer: 26, width: 4.1, use: 'Static', table });
    assert.equal(r.Candidates.length, 0);
    assert.ok(r.Reasons.length > 0);
  });

  test.it('外径が内径以下ならエラー', () => {
    assert.throws(() => P.findORing({ inner: 30, outer: 25, width: 4, use: 'Static', table }));
  });

  test.it('内径だけ：伸び 0〜5% の候補が出て、つぶし率は計算しない', () => {
    const r = P.findORing({ inner: 25, use: 'Static', table });
    assert.ok(r.Candidates.length > 0);
    assert.equal(r.Candidates.filter((c) => c.Stretch < 0 || c.Stretch > 5).length, 0);
    assert.equal(r.Candidates[0].Squeeze, null);
    assert.equal(r.GrooveDepth, null);
  });

  test.it('外径だけ：d1 にはまる前提でつぶし率を計算し、つぶれないものは除く', () => {
    const r = P.findORing({ outer: 30, use: 'Static', table });
    assert.ok(r.Candidates.length > 0);
    assert.equal(r.Candidates.filter((c) => c.Squeeze <= 0).length, 0);
  });

  test.it('つぶし率の下限では絞り込まない：G300 の溝（つぶし率 12.3%）で G300 が出る', () => {
    const r = P.findORing({ inner: 300, outer: 310, width: 7.5, use: 'Static', table });
    assert.equal(ofSeries(r, 'G')[0].Name, 'G300');
  });

  test.it('つぶし率の上限：溝深さ 0.1mm（P20 でつぶし率 95.8%）は候補に出ず、理由に上限を出す', () => {
    const r = P.findORing({ inner: 20, outer: 20.2, use: 'Dynamic', table });
    assert.equal(r.Candidates.length, 0);
    assert.match(r.Reasons.join(''), /上限 20%/);
  });

  test.it('つぶし率の上限：固定用は 30% まで（G25 の 29.0% は出る、32.3% は出ない）', () => {
    assert.ok(names(P.findORing({ inner: 25, outer: 29.4, use: 'Static', table })).includes('G25'));
    assert.ok(!names(P.findORing({ inner: 25, outer: 29.2, use: 'Static', table })).includes('G25'));
  });

  test.it('判定条件に、穴側の溝は未対応と出す', () => {
    const r = P.findORing({ inner: 25, use: 'Static', table });
    assert.match(r.Notes.join(''), /穴側の溝.*未対応/);
  });

  test.it('記号だけの検索語はエラー', () => {
    assert.throws(() => P.findORing({ use: 'Static', table, name: '-' }));
    assert.throws(() => P.findPacking({ table: [], name: '* ' }));
  });

  test.it('溝幅だけ：充填率 85% 以下の候補が出る', () => {
    const r = P.findORing({ width: 4.1, use: 'Static', table });
    assert.ok(r.Candidates.length > 0);
    assert.equal(r.Candidates.filter((c) => c.Fill > 85).length, 0);
  });

  test.it('バックアップリング両側：G25 の BR両側溝（7.3）で G25 が出て、標準溝幅 7.3 を返す', () => {
    const r = P.findORing({ inner: 25, outer: 30, width: 7.3, use: 'Static', table, backupRing: 'Both' });
    const g = ofSeries(r, 'G');
    assert.equal(g[0].Name, 'G25');
    assert.equal(g[0].StdWidth, 7.3);
  });

  test.it('バックアップリング両側：BRなしの溝幅（4.1）では G25 は充填率オーバーで出ない', () => {
    const r = P.findORing({ inner: 25, outer: 30, width: 4.1, use: 'Static', table, backupRing: 'Both' });
    assert.ok(!names(r).includes('G25'));
  });

  test.it('標準溝寸法：P22A は d=22、D=28、P400 は d=400、D=415', () => {
    let p = P.findORing({ inner: 22, outer: 28, width: 4.7, use: 'Static', table }).Candidates.find((c) => c.Name === 'P22A');
    assert.equal(p.StdInner, 22);
    assert.equal(p.StdOuter, 28);
    p = P.findORing({ inner: 400, outer: 415, width: 11, use: 'Static', table }).Candidates.find((c) => c.Name === 'P400');
    assert.equal(p.StdOuter, 415);
  });

  test.it('何も入力しないとエラー', () => {
    assert.throws(() => P.findORing({ use: 'Static', table }));
  });

  test.it('0以下の寸法はエラー', () => {
    assert.throws(() => P.findORing({ inner: 0, outer: 25, width: 4, use: 'Static', table }));
  });
});

test.describe('findPacking', () => {
  test.it('製品を指定しないときは PackingProducts（SKY・KY・UHP・MLP・MLR・UPH）が出る', () => {
    const r = P.findPacking({ inner: 40, outer: 50, table: ptable });
    assert.ok(r.Candidates.length > 0);
    assert.equal(r.Candidates.filter((c) => !P.PackingProducts.includes(c.Product)).length, 0);
  });

  test.it('サイズ表を読める（12製品・757サイズ）', () => {
    assert.equal(ptable.length, 757);
    assert.equal(new Set(ptable.map((r) => r.Product)).size, 12);
  });

  test.it('d30・D40・溝幅7：寸法がぴったりのサイズが製品ごとに出る', () => {
    const r = P.findPacking({ inner: 30, outer: 40, width: 7, table: ptable, products: allProducts });
    for (const c of ['GPY-40', 'GNY-30', 'SKY-30']) assert.ok(codes(r).includes(c), c);
    assert.equal(r.Candidates.filter((c) => c.Deviation !== 0).length, 0);
  });

  test.it('製品ごとに最大2件', () => {
    const r = P.findPacking({ width: 7, table: ptable, products: allProducts });
    const n = {};
    r.Candidates.forEach((c) => { n[c.Product] = (n[c.Product] || 0) + 1; });
    Object.values(n).forEach((v) => assert.ok(v <= 2));
  });

  test.it('バックアップリングありは GB の溝幅で判定し、バックアップのコードを返す', () => {
    const r = P.findPacking({ inner: 40, outer: 50, width: 9, backupRing: 'One', table: ptable, products: allProducts });
    const g = r.Candidates.filter((c) => c.Product === 'GPY');
    assert.equal(g[0].Code, 'GPY-50');
    assert.equal(g[0].Width, 9);
    assert.equal(g[0].Backup, 'TC-GPY-50');
  });

  test.it('許容差を超えると出ない', () => {
    const r = P.findPacking({ inner: 30.6, outer: 40, table: ptable, products: allProducts });
    assert.equal(r.Candidates.filter((c) => c.D1 === 30).length, 0);
  });

  test.it('合わないときは理由を返す', () => {
    const r = P.findPacking({ inner: 3, outer: 3.5, table: ptable, products: allProducts });
    assert.equal(r.Candidates.length, 0);
    assert.ok(r.Reasons.length > 0);
  });

  test.it('公差：寸法指示図どおり、はめあい記号は ISO 286 の数値にする', () => {
    const r = P.findPacking({ inner: 40, outer: 50, table: ptable, products: allProducts });
    const by = (code) => r.Candidates.find((c) => c.Code === code);
    assert.equal(by('GPY-50').TolInner, 'h8 0 / -0.039');
    assert.equal(by('GPY-50').TolOuter, 'H9 +0.062 / 0');
    assert.equal(by('GPY-50').TolWidth, '+0.25 / 0');
    assert.equal(by('GNY-40').TolInner, 'f8 -0.025 / -0.064');
    assert.equal(by('GNY-40').TolOuter, 'H8 +0.039 / 0');
    assert.equal(by('SKY-40').TolInner, '+0.2 / 0');   // 両用も d の公差はピストン用だけ
    assert.equal(by('SKY-40').TolWidth, '±0.2');
  });

  test.it('公差：寸法区分の境目（30 は 18〜30 の区分）', () => {
    assert.equal(P.formatPackingTol('H9', 30), 'H9 +0.052 / 0');
    assert.equal(P.formatPackingTol('H9', 30.1), 'H9 +0.062 / 0');
  });

  test.it('外径が内径以下ならエラー', () => {
    assert.throws(() => P.findPacking({ inner: 40, outer: 30, table: ptable, products: allProducts }));
  });
});

test.describe('findPacking（ダストシール）', () => {
  test.it('d=40 で4製品すべてが候補になる', () => {
    const r = P.findPacking({ inner: 40, table: dtable, products: P.DustProducts, label: 'ダストシール' });
    assert.equal(new Set(r.Candidates.map((c) => c.Product)).size, 4);
  });
  test.it('DKI の溝幅の公差は d の範囲で切り替わる', () => {
    const r = P.findPacking({ inner: 100, table: dtable, products: ['DKI'] });
    assert.equal(r.Candidates[0].TolWidth, '+0.6 / +0.4');
  });
  test.it('合わないときはダストシールの名前で理由を出す', () => {
    const r = P.findPacking({ inner: 999, table: dtable, products: P.DustProducts, label: 'ダストシール' });
    assert.match(r.Reasons[0], /ダストシール/);
  });
});

test.describe('呼び番号で探す', () => {
  test.it('Oリング：全角・小文字でも探せ、完全一致があればそれだけ。寸法・用途は使わない', () => {
    const r = P.findORing({ inner: 999, use: 'Dynamic', table, name: 'ｇ２５' });
    assert.equal(r.ByName, true);
    assert.equal(r.Candidates.length, 1);
    assert.equal(r.Candidates[0].Name, 'G25');
    assert.equal(r.Candidates[0].StdOuter, 30);
  });
  test.it('完全一致がないときは含むものを出す', () => {
    const r = P.findORing({ use: 'Static', table, name: 'P2' });
    assert.equal(r.Candidates[0].Name, 'P20');
    assert.ok(r.Candidates.length > 1);
  });
  test.it('種類をまとめて探し、どれかに完全一致があれば部分一致の種類は出さない', () => {
    let a = P.findAllByName({ name: 'P20', oringTable: table, packingTable: ptable, dustTable: dtable });
    assert.equal(a.ORing.Candidates[0].Name, 'P20');
    assert.equal(a.Packing.Total, 0);
    a = P.findAllByName({ name: 'lbh20', oringTable: table, packingTable: ptable, dustTable: dtable });
    assert.equal(a.Dust.Candidates[0].Code, 'LBH-20');
    assert.equal(a.ORing.Total, 0);
    a = P.findAllByName({ name: '40', oringTable: table, packingTable: ptable, dustTable: dtable });
    assert.ok(a.ORing.Total > 0 && a.Packing.Total > 0 && a.Dust.Total > 0);
  });
  test.it('Uパッキン：ハイフンなしでも探せ、件数は上限まで', () => {
    let r = P.findPacking({ table: ptable, name: 'sky40' });
    assert.equal(r.Candidates.length, 1);
    assert.equal(r.Candidates[0].Code, 'SKY-40');
    r = P.findPacking({ table: ptable, name: 'UPH' });
    assert.ok(r.Total > P.NameMaxResults);
    assert.equal(r.Candidates.length, P.NameMaxResults);
  });
  test.it('検索対象外の製品は出さず、ないときは理由を出す', () => {
    const r = P.findPacking({ table: ptable, name: 'GPY' });
    assert.equal(r.Candidates.length, 0);
    assert.match(r.Reasons[0], /GPY/);
  });
});

test.describe('findPacking（ウェアリング）', () => {
  const wear = (opt) => P.findPacking(Object.assign({ table: wtable, products: P.WearProducts, label: 'ウェアリング' }, opt));
  test.it('D=100・d=94・溝幅=25 で SW-100 と WR-100 が出る', () => {
    const r = wear({ inner: 94, outer: 100, width: 25 });
    assert.ok(codes(r).includes('SW-100'));
    assert.ok(codes(r).includes('WR-100'));
  });
  test.it('e7・h8 の公差を数値にする（SWA-100：d=95 e7、D1=99.4 h8）', () => {
    const c = wear({ name: 'SWA-100' }).Candidates[0];
    assert.equal(c.TolInner, 'e7 -0.072 / -0.107');
    assert.equal(c.TolOuter, 'H9 +0.087 / 0');
    assert.equal(c.TolD1, 'h8 0 / -0.054');
  });
  test.it('SWO-125 だけ d の公差が違う', () => {
    assert.equal(wear({ name: 'SWO-125' }).Candidates[0].TolInner, '0 / -0.08');
    assert.equal(wear({ name: 'SWO-100' }).Candidates[0].TolInner, '0 / -0.05');
  });
  test.it('呼び番号でまとめて探すとウェアリングも出る', () => {
    const a = P.findAllByName({ name: 'wpl100', oringTable: table, packingTable: ptable, dustTable: dtable, wearTable: wtable });
    assert.equal(a.Wear.Candidates[0].Code, 'WPL100');
    assert.equal(a.Packing.Total, 0);
  });
});
