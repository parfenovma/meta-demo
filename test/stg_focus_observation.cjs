// Acceptance check on the actual shipped time-domain fields, not a phase screen.
// A marked focal plane must agree with the measured central waist to within
// a quarter shear wavelength. This is a demo-design tolerance, not a universal
// theorem about finite-aperture lenses.
const fs=require('node:fs'),zlib=require('node:zlib'),path=require('node:path'),assert=require('node:assert/strict');
const file=process.argv[2]||path.join(__dirname,'../data/canonical/focus.json.gz');
const data=JSON.parse(zlib.gunzipSync(fs.readFileSync(file)));
function width(x,y){
  const peak=Math.max(...y),i=y.indexOf(peak),half=peak/2;
  let l=i,r=i;while(l>0&&y[l]>=half)l--;while(r<y.length-1&&y[r]>=half)r++;
  if(!(peak>0)||y[l]>=half||y[r]>=half)return Infinity;
  const cross=(a,b)=>x[a]+(half-y[a])/(y[b]-y[a])*(x[b]-x[a]);
  return cross(r-1,r)-cross(l,l+1);
}
const c=data.sets[0].cases.at(-1),buffer=zlib.inflateSync(Buffer.from(c.values,'base64'));
const values=new Float32Array(buffer.buffer,buffer.byteOffset,buffer.byteLength/4),nx=c.x.length,ny=c.y.length;
const cs=c.diagnostics.shear_speed_m_s||Math.sqrt(70e9/(2*(1+.33)*2700)),wavelength=cs/data.sets[0].frequency;
const focus=c.geometry.focus,exit=c.geometry.lens_exit||.0085,distance=(c.geometry.design_focus||focus)-exit;
const window=data.focus_measurement?.search_window_m||[exit+.4*distance,exit+1.7*distance];
const slices=c.x.map((x,i)=>{
  const p=c.y.map((_,j)=>{let sum=0;for(let t=0;t<c.times.length;t++)sum+=values[t*nx*ny+j*nx+i]**2;return sum});
  return {x,width:width(c.y,p),peakY:c.y[p.indexOf(Math.max(...p))]};
}).filter(s=>s.x>=window[0]&&s.x<=window[1]&&Math.abs(s.peakY)<=wavelength/4);
assert(slices.length,'no central transmitted beam found');
const waist=slices.reduce((a,b)=>a.width<b.width?a:b);
console.log(JSON.stringify({marked_focus_mm:focus*1000,measured_waist_mm:waist.x*1000,width_mm:waist.width*1000,tolerance_mm:wavelength/4*1000}));
assert(Math.abs(waist.x-focus)<=wavelength/4,'marked focal plane misses the time-domain beam waist');
if(data.focus_measurement){
  const widths=data.profile.series.map(p=>width(p.x,p.y));
  assert(widths.at(-1)<.7*widths[0],'phase-selected STG must have a substantially narrower spot than identical STG cells');
  assert.equal(data.sets[0].cases[0].name,'Одинаковые STG-кирпичики','main reference is an ungraded wall, not a scrambled lens');
  assert.equal(c.geometry.design_focus,data.focus_measurement.nominal_plane_m,'keep the original phase-design target explicit');
  assert.equal(c.geometry.focus,data.focus_measurement.plane_m);
  console.log(JSON.stringify({profile_widths_mm:widths.map(w=>w*1000),nominal_plane_mm:data.focus_measurement.nominal_plane_m*1000}));
}
console.log('PASS: marked focal plane agrees with the measured STG waist');
