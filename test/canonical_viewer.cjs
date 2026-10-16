const fs=require('node:fs'),path=require('node:path'),z=require('node:zlib'),vm=require('node:vm'),assert=require('node:assert/strict');
const repo=path.resolve(__dirname,'..');
const script=fs.readFileSync(path.join(repo,'src/assets/canonical.js'),'utf8');
const noop=()=>{};
const lessons=JSON.parse(fs.readFileSync(path.join(repo,'src/assets/canonical_lessons.json'),'utf8'));
const bundle=id=>{
  const d=JSON.parse(z.gunzipSync(fs.readFileSync(path.join(repo,'data/canonical',id+'.json.gz'))));
  d.lessons={main:lessons[id]};if(id==='cloak')d.lessons.tube=lessons.tube;
  Object.assign(d,lessons[id].intro);
  for(const set of d.sets)if(set.cases[0].geometry.type==='tube')Object.assign(set,lessons.tube.intro);
  return d;
};
function viewer(id){
  const elements=new Map(),ellipses=[];
  function element(tag='div'){
    const e={tag,children:[],width:640,height:360,style:{},textContent:'',disabled:false,hidden:false,className:'',classList:{toggle:noop},append(...a){this.children.push(...a)},replaceChildren(...a){this.children=a},querySelectorAll(){return this.children.filter(c=>c.tag==='button')},getBoundingClientRect(){return {left:0,top:0,width:this.width,height:this.height}}};
    const finite=(...args)=>assert(args.every(Number.isFinite),'canvas received nonfinite coordinates');
    const ctx=new Proxy({ellipse(...args){finite(...args.slice(0,7));ellipses.push(args)},clearRect:noop,moveTo:finite,lineTo:finite,arc:finite,fillRect:finite,strokeRect:finite},{get:(t,p)=>p in t?t[p]:noop});
    e.getContext=()=>ctx;return e;
  }
  const root=element();root.querySelector=s=>{if(!elements.has(s))elements.set(s,element(s.startsWith('.cn-control')||s.startsWith('.cn-selected')?'canvas':'div'));return elements.get(s)};
  const sandbox={console,canonicalData:bundle(id),document:{getElementById:()=>root,createElement:element,createTextNode:text=>({textContent:text})},getComputedStyle:()=>({color:'#fff'}),cancelAnimationFrame:noop,requestAnimationFrame:()=>1,ImageData:class{constructor(w,h){this.width=w;this.height=h;this.data=new Uint8ClampedArray(w*h*4)}},atob,Response,Blob,Uint8Array,DataView,Float32Array,DecompressionStream};
  const context=vm.createContext(sandbox);
  vm.runInContext(script.replace(/cnChooseSet\(cnData\.sets\.length>1&&\['mass','bulk'\]\.includes\(cnData\.id\)\?1:0\);\s*$/,''),context);
  vm.runInContext('const cnLastPlots={};const cnRealPlot=cnPlot;cnPlot=(...args)=>{cnLastPlots[args[0]]=args;return cnRealPlot(...args)}',context);
  return {context,e:s=>root.querySelector(s),run:code=>vm.runInContext(code,context),ellipses};
}
function duringLoading(v){
  const c=v.e('.cn-selected');
  c.onclick({currentTarget:c,clientX:300,clientY:150});
  v.e('.cn-play').onclick();v.e('.cn-reset').onclick();v.e('.cn-time').oninput({target:{value:999}});
  v.e('.cn-echo').onchange({target:{checked:true}});v.run('cnChooseCase(0)');
  assert.equal(v.run('cnReady'),false);assert.equal(v.run('cnFrame'),0);
}
(async()=>{
  const mass=viewer('mass'),pending=mass.run('cnChooseSet(1)');duringLoading(mass);await pending;
  assert.equal(mass.run('cnReady'),true);assert.equal(mass.e('.cn-error').textContent,'');
  mass.run('const cnOriginalDecode=cnDecode,cnDeferred=[];cnDecode=encoded=>new Promise(resolve=>{const f=()=>cnOriginalDecode(encoded).then(resolve);cnDeferred.push(f)});');
  const first=mass.run('cnChooseSet(0)');duringLoading(mass);
  const second=mass.run('cnChooseSet(2)');duringLoading(mass);
  await mass.run('cnChooseSet(1)');
  assert.equal(mass.run('cnReady'),true);assert.equal(mass.run('cnSet'),1);
  await mass.run('Promise.all(cnDeferred.splice(0).reverse().map(f=>f()))');await Promise.all([first,second]);
  assert.equal(mass.run('cnReady'),true);assert.equal(mass.run('cnSet'),1);assert.equal(mass.e('.cn-error').textContent,'');
  assert(mass.e('.cn-frequency').children[1].textContent.includes('Отрицательная'));
  console.log('PASS: loading guards and out-of-order frequency completion retain newest selection');
  for(const id of ['mass','bulk','absorber','cloak','focus']){
    const v=id==='mass'?mass:viewer(id),sets=v.run('cnData.sets.length');
    for(let s=0;s<sets;s++){
      await v.run(`cnChooseSet(${s})`);assert.equal(v.e('.cn-error').textContent,'');assert.equal(v.run('cnReady'),true);
      const lesson=lessons[id==='cloak'&&s===1?'tube':id];
      assert.equal(v.e('.cn-title').textContent,lesson.intro.title);
      assert.equal(v.e('.cn-question').textContent,lesson.intro.question);
      assert.equal(v.e('.cn-instruction').textContent,lesson.intro.instruction);
      assert.equal(v.e('.cn-lesson-title').textContent,lesson.title);
      assert.equal(v.e('.cn-mechanism').textContent,lesson.mechanism);
      assert.equal(v.e('.cn-symbols').textContent,lesson.symbols);
      assert.equal(v.e('.cn-lesson-boundary').textContent,lesson.boundary);
      assert.deepEqual(v.e('.cn-watch').children.map(c=>c.textContent),lesson.watch);
      assert.deepEqual(v.e('.cn-equations').children.map(c=>c.textContent),lesson.equations);
      assert.equal(lesson.cases.length,v.run('cnCases().length'));
      for(let j=0;j<v.run('cnCases().length');j++){
        v.run(`cnChooseCase(${j})`);assert.equal(v.e('.cn-selected-name').textContent,v.run('cnCases()[cnActive].name'));
        assert(v.e('.cn-scale-title').textContent.length>10,`${id}: field needs a named quantity and unit`);
        assert.equal(v.e('.cn-scale-ticks').children.length,5,`${id}: field needs five numerical color-scale ticks`);
        assert(v.e('.cn-field-reading').textContent.length>40,`${id}: explain what to look for next to the field`);
        assert(v.e('.cn-trace-legend').children.length===2,`${id}: both sensor curves need named legends`);
        assert(v.e('.cn-trace-explanation').textContent.length>40,`${id}: explain the sensor record`);
        assert.equal(v.e('.cn-cavity-scale').hidden,id!=='bulk');
        if(id==='bulk')assert.equal(v.e('.cn-cavity-scale-ticks').children.length,5,'cavities have their own calibrated pressure scale');
        assert.equal(v.e('.cn-field-reading').textContent,id==='focus'&&j===0?lesson.control_field:lesson.field,'observation matches the current experiment and control selection');
        const ticks=v.e('.cn-scale-ticks').children.map(c=>Number(c.textContent));
        assert.deepEqual(ticks,[-1,-.5,0,.5,1].map(vv=>Number((vv*v.run('cnLimit')).toPrecision(3))),'wave ticks use the same physical limit as both maps');
        for(const vv of [-1,0,1])assert(v.e('.cn-scale-bar').style.background.includes(v.run(`'rgb('+cnWaveColor(${vv}).map(Math.round).join(',')+')'`)),'scale uses actual field palette');
        assert.equal(v.e('.cn-case-note').textContent,lesson.cases[j]);
        v.e('.cn-time').oninput({target:{value:v.run('cnCases()[0].times.length-1')}});
        assert(Number.isFinite(v.run('cnFrame')));
        if(lesson.chart){assert.equal(v.e('.cn-plot-title').textContent,lesson.chart.title);assert.equal(v.e('.cn-explanation').textContent,lesson.chart.explanation);if(v.run('!!cnData.plot'))assert(v.e('.cn-reading').textContent.includes('На '));}
      }
      const right=JSON.parse(v.run('JSON.stringify(cnLastPlots[".cn-spectrum"])'));
      if(['mass','bulk','absorber'].includes(id)){
        const frequencies=right[1].flatMap(curve=>curve.x),marker=right[4];
        assert(marker>=Math.min(...frequencies)&&marker<=Math.max(...frequencies),`${id}: current-frequency line must be on the visible chart`);
        assert(right[1].some(curve=>Number.isFinite(curve.markerValue)),`${id}: mark current values with dots`);
      }
      if(id==='bulk'){
        const before=v.run('JSON.stringify(cnPoint)'),c=v.e('.cn-selected');
        c.onclick({currentTarget:c,clientX:490,clientY:100});assert.equal(v.run('JSON.stringify(cnPoint)'),before,'magnified cavity is not a physical 2D sensor area');
        c.onclick({currentTarget:c,clientX:400,clientY:245});assert.notEqual(v.run('JSON.stringify(cnPoint)'),before,'sensor moves along the actual channel');
        assert.equal(v.run('cnPoint[1]'),0);
      }
      if(v.run('cnCases()[0].y.length')>1){
        const sx=v.run('(cnGet(".cn-selected").width-58)/(cnCases()[0].x.at(-1)-cnCases()[0].x[0])');
        const sy=v.run('(cnGet(".cn-selected").height-65)/(cnCases()[0].y.at(-1)-cnCases()[0].y[0])');
        assert(Math.abs(sx/sy-1)<.002,`${id} has unequal physical scales`);
      }
      if(id==='cloak'){
        if(s===0){assert(v.e('.cn-plot-title').textContent.includes('ровной поверхности'));assert(v.e('.cn-explanation').textContent.includes('ровной'))}
        else{
          assert(v.e('.cn-plot-title').textContent.includes('трубки без резины'));assert(v.e('.cn-explanation').textContent.includes('без резины'));assert(v.e('.cn-control-name').textContent.includes('без резины'));assert(v.ellipses.every(a=>Math.abs(a[2]-a[3])<1e-8));
          assert(v.e('.cn-scale-title').textContent.includes('pₛ'));
          v.e('.cn-echo').onchange({target:{checked:false}});
          assert(v.e('.cn-scale-title').textContent.includes('давление p,'));assert(!v.e('.cn-scale-title').textContent.includes('pₛ'),'full-pressure scale must not retain echo label');
          assert(v.run('cnLastPlots[".cn-trace"][3]').includes('Давление p'));
          v.e('.cn-echo').onchange({target:{checked:true}});
          assert(v.e('.cn-trace-title').textContent.includes('эхо'));assert(v.run('cnLastPlots[".cn-trace"][3]').includes('pₛ'));
          v.run('cnPoint=[999,999];cnUpdateProbe();cnDraw()');
          assert.equal(v.run('cnLastPlots[".cn-spectrum"][1].length'),0,'invalid reference is not silently replaced by zero');
        }
      }
    }
    if(id==='cloak'){
      await v.run('cnChooseSet(0)');
      assert.equal(v.e('.cn-lesson-title').textContent,lessons.cloak.title,'ground explanation restored after tube');
      assert.equal(v.e('.cn-title').textContent,lessons.cloak.intro.title,'ground title restored after tube');
      assert(!v.e('.cn-symbols').textContent.includes('силикон'));
    }
    if(id==='focus'){
      const names=v.run('cnData.profile.series.map(s=>s.name)'),legend=v.e('.cn-plot-legend').children;
      assert.equal(legend.length,names.length);legend.forEach((e,i)=>assert.equal(e.children[1].textContent,names[i]));
      assert.equal(legend.at(-1).children[0].style.background,'#2bbba9');
      assert.equal(v.run('cnLastPlots[".cn-spectrum"][2]'),'Координата y, мм');
      assert(Math.abs(v.run('Math.max(...cnLastPlots[".cn-spectrum"][1].flatMap(s=>s.y))')-100)<1e-10,'one shared normalization across samples');
      assert(v.e('.cn-reading').textContent.includes('мм'));
      assert.equal(v.run('cnProfileWidth({x:[-2,-1,0,1,2],y:[0,1,2,1,0]})'),2000);
      assert.equal(v.run('cnProfileWidth({x:[-1,0,1],y:[1,1,1]})'),null,'unbounded peak does not get a made-up width');
      assert.equal(v.e('.cn-focus-controls').hidden,false);
      const signals=v.run('JSON.stringify(cnSignals.map(s=>s.values))');
      v.e('.cn-view-path').onclick();assert.equal(v.run('cnView'),'path');assert.equal(v.e('.cn-time').disabled,true);
      assert(v.e('.cn-scale-title').textContent.includes('%'),'accumulated field is a relative squared-displacement integral, not energy');
      assert(v.e('.cn-scale-note').textContent.includes('не энергия'));
      assert.equal(v.e('.cn-field-reading').textContent,lessons.focus.path_field);
      assert.deepEqual(v.e('.cn-scale-ticks').children.map(c=>c.textContent),['0','25','50','75','100+']);
      assert(v.run('cnLastPlots[".cn-spectrum"][6].widthSpan.right>cnLastPlots[".cn-spectrum"][6].widthSpan.left'),'show actual FWHM span on the normalized profile');
      const colors=v.e('.cn-scale-bar').style.background;
      assert(colors.includes('rgb('),'color scale uses the actual rendered palette');
      assert(v.e('.cn-clock').textContent.includes('Вся запись'));assert.equal(v.run('cnLastPlots[".cn-trace"][4]'),null,'static integral has no fictitious time cursor');
      const scale=v.run('cnPathLimit');v.run('cnChooseCase(0)');assert.equal(v.run('cnPathLimit'),scale,'same path color scale for every sample');
      assert.equal(v.e('.cn-field-reading').textContent,lessons.focus.control_field,'do not promise a narrower right beam when both samples are identical');
      v.run('cnChooseCase(cnCases().length-1)');assert.equal(v.run('JSON.stringify(cnSignals.map(s=>s.values))'),signals,'switching the view never changes the physical microphone signal');
      v.e('.cn-focus-jump').onclick();assert.equal(v.run('cnView'),'wave');assert.equal(v.e('.cn-time').disabled,false);
      assert.equal(v.run('cnFrame'),v.run('cnFocusFrame(cnCases().at(-1))'));assert(v.run('cnFrame')>0);
      v.e('.cn-view-path').onclick();v.e('.cn-play').onclick();assert.equal(v.run('cnView'),'wave');assert.equal(v.run('cnFrame'),0,'play from static map starts the true time-domain record');
      v.e('.cn-reset').onclick();assert.equal(v.run('cnPlaying'),false);
    }
    console.log(`PASS: ${id} all sets/cases, matching observation/formula/case notes, full-time slider, field scale${id==='cloak'?', separate tube explanation and restored ground text, tube reference and circular geometry':''}${id==='focus'?', named and selected-color profile legend':''}`);
  }
})().catch(e=>{console.error(e);process.exitCode=1});
