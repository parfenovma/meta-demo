const fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
for(const id of ['mass','bulk','prism','absorber']){
  const d=JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(root,'data/canonical',id+'.json.gz'))));
  const p=d.plot;
  assert(p&&p.series.length,`${id}: missing frequency response`);
  for(const s of p.series){
    const x=s.x||p.x;
    assert.equal(x.length,s.y.length,`${id}: frequency/response lengths differ`);
    assert(x.every(Number.isFinite)&&s.y.every(Number.isFinite),`${id}: nonfinite frequency response`);
    for(const set of d.sets)assert(set.frequency>=Math.min(...x)&&set.frequency<=Math.max(...x),
      `${id}: carrier ${set.frequency} Hz is outside chart domain [${Math.min(...x)}, ${Math.max(...x)}] Hz`);
  }
}
for(const id of ['mass','bulk']){
  const d=JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(root,'data/canonical',id+'.json.gz'))));
  assert.equal(d.plot.series.length,2,`${id}: show both the reference and the resonant sample`);
  assert(d.plot.series[1].y.some(v=>v<0)&&d.plot.series[1].y.some(v=>v>0),`${id}: both sign bands must be visible`);
}
const html=fs.readFileSync(path.join(root,'src/assets/canonical.html'),'utf8');
assert(!/<h3>Сигнал датчика<\/h3>\s*<p/.test(html),'probe help must not push only the left canvas down');
assert(fs.readFileSync(path.join(root,'src/assets/canonical.css'),'utf8').includes('.cn-bottom h3{min-height:46px}'),'paired plot headings reserve equal height');
console.log('PASS: every displayed carrier lies inside its prepared frequency response');
