const fs=require('node:fs'),assert=require('node:assert/strict'),zlib=require('node:zlib'),path=require('node:path');
const js=fs.readFileSync(path.join(__dirname,'../src/assets/canonical.js'),'utf8');
const pure=js.split('const cnRoot=')[0];
const {cnTrace,cnBilinear,cnClosest,cnAccumulation,cnFocusFrame,cnAxisTicks}=new Function(pure+';return {cnTrace,cnBilinear,cnClosest,cnAccumulation,cnFocusFrame,cnAxisTicks};')();
assert.deepEqual(cnAxisTicks(-1.73,1.7300426).ticks,[-2,-1,0,1,2],'near-zero noise must not turn the zero tick into a long clipped decimal');
for(const [min,max] of [[-.001,.001],[-20,20],[0,105],[-.01,.3]]){
  const axis=cnAxisTicks(min,max);assert(axis.min<=min&&axis.max>=max);assert(axis.ticks.includes(0));assert(axis.ticks.length<=8);
}
const c={x:[0,1],y:[0,1],times:[0,1],samples:[0,1,2,3,10,11,12,13],valid:[true,true,true,true]};
assert.deepEqual(cnTrace(c,[.25,.5]),[1.25,11.25]);
assert.equal(cnTrace(c,[-.1,.5]),null);assert.equal(cnClosest([0,.1,.2],.19),2);
assert.equal(cnBilinear({...c,valid:[true,false,true,true]},[.5,.5]),null);
const one={x:[0,1],y:[0],times:[0,1],samples:[0,2,10,12],valid:[true,true]};
assert.deepEqual(cnTrace(one,[.5,0]),[1,11]);
const varying={...one,times:[0,1,3],samples:[1,2,2,2,3,2],geometry:{focus:.5}};
assert.deepEqual([...cnAccumulation(varying)],[15.5,12],'actual nonuniform-time trapezoidal integral, not a decorative beam');
assert.deepEqual([...cnAccumulation({...varying,samples:varying.samples.map(v=>2*v)})],[62,48],'accumulated response scales with amplitude squared');
assert.equal(cnFocusFrame(varying),2,'jump to the peak of the calculated point signal');
for(const id of ['mass','bulk','absorber','cloak','focus']){
  const file=path.join(__dirname,'../data/canonical',id+'.json.gz');
  assert(fs.existsSync(file),'Missing prepared experiment: '+id);
  const d=JSON.parse(zlib.gunzipSync(fs.readFileSync(file)));
  assert.equal(d.schema,1);assert.equal(d.id,id);assert(d.source_digest.length===64);
  for(const s of d.sets)for(const c of s.cases){
    const samples=zlib.inflateSync(Buffer.from(c.values,'base64'));
    assert.equal(samples.length,c.x.length*c.y.length*c.times.length*4);
    assert.equal(c.valid.length,c.x.length*c.y.length);
    assert(c.times.length>30);assert(s.frequency*(c.times[1]-c.times[0])<.15);
    const a=new Float32Array(samples.buffer,samples.byteOffset,samples.length/4);
    assert(a.every(Number.isFinite));
  }
}
assert(!js.includes('fetch('));assert(!js.includes('WebSocket'));assert(!js.includes('dispatchEvent'));
console.log('Canonical data decoding, spatial probes, cadence, finite histories and local-only interaction: OK');
