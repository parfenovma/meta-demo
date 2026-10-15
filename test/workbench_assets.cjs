// Pure geometry/plot/state helpers, not a substitute for real Pluto/UI tests.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const assets=path.join(__dirname,'..','src','assets');
const grid=fs.readFileSync(path.join(assets,'field-grid.js'),'utf8');
const {triangleWeights}=new Function(grid+';return {triangleWeights};')();
const raster=triangleWeights([[0,0],[4,0],[0,4]],[[0,1,2]],5,5,x=>x,y=>y);
let covered=0;
for(let y=0;y<5;y++)for(let x=0;x<5;x++){
    const j=y*5+x;
    if(raster.a[j]<0){assert(x+y>=4);continue;}
    covered++;
    const values=[1,9,13],v=(1-raster.u[j]-raster.v[j])*values[0]+raster.u[j]*values[1]+raster.v[j]*values[2];
    assert(Math.abs(v-(1+2*(x+.5)+3*(y+.5)))<1e-6);
}
assert.equal(covered,10);
const degenerate=triangleWeights([[0,0],[1,1],[2,2]],[[0,1,2]],3,3,x=>x,y=>y);
assert([...degenerate.a].every(v=>v===-1));
const script=fs.readFileSync(path.join(assets,'workbench.js'),'utf8');
const pure=script.split('const root=')[0];
const {sameSettings,plotLimits,ramp,fieldPoint,phasorValue,pulseContrast,decodePulseFrames,nearestTime,playbackFrame,runGroup}=new Function(pure+';return {sameSettings,plotLimits,ramp,fieldPoint,phasorValue,pulseContrast,decodePulseFrames,nearestTime,playbackFrame,runGroup};')();
const a={experiment:'cloak',frequency:10000,thickness:.001,preset:'focused',polarization:'shear'};
assert(sameSettings(a,{...a}));assert(!sameSettings(a,{...a,frequency:20000}));assert(!sameSettings(a,null));
const limits=plotLimits([{x:[5,10,15],y:[-20,2,-5],reference:0},{x:[5,15],y:[-40,10]}]);
assert(limits.ymin<-40&&limits.ymax>10&&limits.xmin===5&&limits.xmax===15);
const zoom=plotLimits([{x:[0,1,2,3],y:[100,2,3,100],reference:0}],[1,2]);
assert(zoom.ymax<4&&zoom.ymin===0);assert.equal(plotLimits([{x:[1],y:[null]}]),null);
assert.equal(plotLimits([{x:[0,1],y:[.01,.2]}]).ymin,0); // no negative energy axis
assert.deepEqual(ramp(0),[16,44,61]);assert.deepEqual(ramp(1),[255,223,128]);assert.deepEqual(ramp(-1,true),[67,134,223]);
assert.deepEqual(fieldPoint(0,0,400,425,25,25),[-25,25]);
assert.equal(fieldPoint(400,399,400,425,25,25)[0],25);
assert(Math.abs(fieldPoint(400,399,400,425,25,25)[1]+24.875)<1e-12);
assert.deepEqual(fieldPoint(200,200,400,425,90,56),[0,0]);
assert.equal(fieldPoint(200,405,400,425,25,25),null); // axis, not the material
assert.equal(fieldPoint(-1,200,400,425,25,25),null);
assert.equal(fieldPoint(0,0,0,0,25,25),null);
assert.equal(phasorValue([2,3],0),2);assert(Math.abs(phasorValue([2,3],Math.PI/2)-3)<1e-12);
assert(!script.includes("get('.wb-phase').hidden")); // animation always discoverable
assert(!sameSettings({...a,regime:'pulse'},{...a,regime:'harmonic'}));
const packed=Buffer.alloc(8);[0,1,-2,32767].forEach((v,i)=>packed.writeInt16LE(v,i*2));
decodePulseFrames(require('node:zlib').deflateSync(packed).toString('base64'),3e-9).then(decoded=>{
    assert.deepEqual([...decoded],[0,1,-2,32767].map(v=>Math.fround(v*3e-9/32767)));
    console.log('Compressed little-endian transient frames: OK');
}).catch(error=>{console.error(error);process.exitCode=1;});
assert.equal(nearestTime([0,.1,.2,.3],.19),2);assert.equal(nearestTime([0,.1,.2],-.1),0);assert.equal(nearestTime([0,.1,.2],9),2);
assert.equal(playbackFrame(0,0,141),0);assert.equal(playbackFrame(0,700,141),10);
assert.equal(playbackFrame(60,700,141),70);assert.equal(playbackFrame(0,1e6,141),140); // stop, never wrap
assert.equal(pulseContrast(0,10),0);assert.equal(pulseContrast(10,10),1);assert.equal(pulseContrast(-2.5,10),-.5);
assert.equal(runGroup({kind:'solid',settings:{regime:'pulse'}}),'solid-pulse');
assert.equal(runGroup({kind:'solid',settings:{regime:'harmonic'}}),'solid-harmonic');
assert.equal(runGroup({kind:'cloak',settings:{regime:'pulse'}}),'cloak-pulse');
assert.equal(runGroup({kind:'cloak',settings:{regime:'harmonic'}}),'cloak-harmonic');
// Execute the real legend renderer with a minimal DOM: control order can differ
// from selected/control color roles, so indexed colors alone are wrong.
const element=()=>({style:{},children:[],append(child){this.children.push(child);}});
const legendCode=script.slice(script.indexOf('function legend('),script.indexOf('function drawMain('));
const renderLegend=new Function('document','palette',legendCode+';return legend;')({createElement:element},['teal','orange']);
const parent=element();renderLegend(parent,[{label:'control',color:'orange'},{label:'selected',color:'teal'},{label:'fallback'}]);
assert.deepEqual(parent.children[0].children.map(e=>[e.textContent,e.style.color]),[['● control','orange'],['● selected','teal'],['● fallback','teal']]);
console.log('Workbench pure JS: interpolation, void masking, shared axes, draft equality, colour scales OK');
