// Pure helpers are also exercised without a browser in test/workbench_assets.cjs.
function sameSettings(a,b) {
    return !!a && !!b && ['experiment','frequency','thickness','preset','polarization','regime'].every(k=>a[k]===b[k]);
}
function plotLimits(curves, xrange=null) {
    const points=curves.flatMap(c=>c.x.map((x,i)=>[x,c.y[i]]))
        .filter(p=>Number.isFinite(p[0])&&Number.isFinite(p[1])&&(!xrange||(p[0]>=xrange[0]&&p[0]<=xrange[1])));
    if(!points.length)return null;
    let xmin=xrange?xrange[0]:Math.min(...points.map(p=>p[0])),xmax=xrange?xrange[1]:Math.max(...points.map(p=>p[0]));
    let ymin=Math.min(...points.map(p=>p[1])),ymax=Math.max(...points.map(p=>p[1]));
    for(const c of curves)if(Number.isFinite(c.reference)){ymin=Math.min(ymin,c.reference);ymax=Math.max(ymax,c.reference);}
    if(xmax===xmin){xmin-=.5;xmax+=.5;}
    const pad=Math.max((ymax-ymin)*.1,Math.abs(ymax)*.01,1e-9);
    return {xmin,xmax,ymin:ymin>=0?0:ymin-pad,ymax:ymax+pad};
}
function ramp(value,signed=false) {
    const t=Math.min(1,Math.max(signed?-1:0,value));
    const base=[16,44,61], target=signed?(t<0?[67,134,223]:[255,150,105]):(t<.5?[23,167,186]:[255,223,128]);
    const u=signed?Math.abs(t):(t<.5?t*2:(t-.5)*2);
    const start=!signed&&t>=.5?[23,167,186]:base;
    return start.map((v,i)=>Math.round(v+(target[i]-v)*u));
}
function fieldPoint(x,y,width,height,halfwidth,halfheight){
    const ph=height-25;
    if(![x,y,width,height,halfwidth,halfheight].every(Number.isFinite)||width<=0||ph<=0||x<0||x>width||y<0||y>=ph)return null;
    return [(2*x/width-1)*halfwidth,(1-2*y/ph)*halfheight];
}
function phasorValue(phasor,phase){return phasor[0]*Math.cos(phase)+phasor[1]*Math.sin(phase);}
function pulseContrast(value,limit){return Math.sign(value)*Math.sqrt(Math.min(1,Math.abs(value)/limit));}
async function decodePulseFrames(encoded,limit){
    const bytes=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0));
    const stream=new Blob([bytes]).stream().pipeThrough(new DecompressionStream('deflate'));
    const buffer=await new Response(stream).arrayBuffer(),view=new DataView(buffer),values=new Float32Array(buffer.byteLength/2);
    for(let i=0;i<values.length;i++)values[i]=view.getInt16(i*2,true)*limit/32767;
    return values;
}
function nearestTime(times,t){
    let lo=0,hi=times.length-1;
    while(lo<hi){const m=Math.floor((lo+hi)/2);if(times[m]<t)lo=m+1;else hi=m;}
    return lo>0&&t-times[lo-1]<times[lo]-t?lo-1:lo;
}
function playbackFrame(start,elapsed,count){return Math.min(count-1,start+Math.floor(Math.max(0,elapsed)/70));}
function runGroup(r){return `${r.kind}-${r.settings.regime||'harmonic'}`;}

const root=document.getElementById('meta-workbench'),get=s=>root.querySelector(s),all=s=>Array.from(root.querySelectorAll(s));
const palette=['#008f96','#de7337','#5e7ed8','#af69b8','#70952b','#b24d66'];
const draft={cloak:{...catalog.defaults.cloak},solid:{...catalog.defaults.solid}};
let kind='cloak',state={current:null,pinned:[],handled:0,limit:6,error:''},pending=0,lastNonce=0,busy=false;
let lastRaw='',phase=0,playing=false,frame=0,frameIndex=0,playStart=0,playStamp=0,tab='home',urls=[],rasters=new WeakMap(),decoded=new WeakMap(),pendingAction='';
const transient=()=>state.current?.data.field.domain==='time';
const currentTime=()=>state.current.data.field.frame_times_us[frameIndex];
const clockNow=()=>Date.now();
let submitted={action:'init',nonce:0};
Object.defineProperty(root,'value',{get:()=>submitted,set:value=>{
    // Pluto restores the last bond on reconnect. Adopt it without resubmitting.
    if(value&&Number.isSafeInteger(value.nonce)){submitted=value;lastNonce=Math.max(lastNonce,value.nonce);}
}});

function option(select,value,text){const o=document.createElement('option');o.value=value;o.textContent=text;select.append(o);}
for(let f=5000;f<=60000;f+=5000)option(get('[data-setting="cloak-frequency"]'),f,`${f/1000} kHz`);
option(get('[data-setting="cloak-frequency"]'),catalog.resonance,`≈${(catalog.resonance/1000).toFixed(3)} kHz · резонанс`);
for(const p of catalog.solidPresets)option(get('[data-setting="preset"]'),p.id,p.name);

function schematic(type) {
    const svg=get(`[data-schematic="${type}"]`),ns='http://www.w3.org/2000/svg';
    const add=(tag,attrs)=>{const e=document.createElementNS(ns,tag);for(const [k,v]of Object.entries(attrs))e.setAttribute(k,v);svg.append(e);return e;};
    if(type==='cloak'){
        for(let x=25;x<160;x+=25)add('path',{d:`M${x} 28 V132`,stroke:'#53c9c1','stroke-width':2,opacity:.65});
        for(const [r,fill]of [[58,'#a5d8cd'],[44,'#9aaeba'],[35,'#102c3d']])add('circle',{cx:238,cy:80,r,fill});
        add('path',{d:'M325 80 H406 m-9 -6 9 6 -9 6',stroke:'#53c9c1',fill:'none','stroke-width':2});
    }else{
        add('rect',{x:18,y:18,width:116,height:124,fill:'#6f8997'});add('rect',{x:240,y:18,width:180,height:124,fill:'#6f8997'});
        // Schematic repeats the actual brick polygon, not a striped material model.
        for(let j=0;j<5;j++){
            const points=catalog.brick.map(p=>[134+(p[0]+catalog.brickLength/2)*106/catalog.brickLength,30+j*24-p[1]*20/catalog.brickHeight].join(',')).join(' ');
            add('polygon',{points,fill:'#9aafbb',stroke:'#c3d4de','stroke-width':.6});
        }
        add('path',{d:'M285 34 Q335 42 370 80 Q335 118 285 126',stroke:'#53c9c1',fill:'none','stroke-width':2,'stroke-dasharray':'5 4'});
    }
}
schematic('cloak');schematic('solid');

function showTab(value){tab=value;all('[data-panel]').forEach(e=>e.hidden=e.dataset.panel!==tab);all('[data-tab]').forEach(e=>{if(e.dataset.tab===tab)e.setAttribute('aria-current','page');else e.removeAttribute('aria-current');});requestAnimationFrame(drawVisible);}
function applyDraft(){
    get('[data-setting="experiment"]').value=kind;
    for(const k of ['cloak','solid'])get(`[data-controls="${k}"]`).hidden=k!==kind;
    get('[data-setting="cloak-frequency"]').value=draft.cloak.frequency;
    get('[data-setting="thickness"]').value=draft.cloak.thickness;
    get('[data-setting="cloak-regime"]').value=draft.cloak.regime;
    get('[data-setting="solid-frequency"]').value=draft.solid.frequency;
    get('[data-setting="preset"]').value=draft.solid.preset;
    get('[data-setting="polarization"]').value=draft.solid.polarization;
    get('[data-setting="regime"]').value=draft.solid.regime;
    refreshStatus();
}
function readDraft(){
    const s=draft[kind];
    if(kind==='cloak'){s.frequency=Number(get('[data-setting="cloak-frequency"]').value);s.thickness=Number(get('[data-setting="thickness"]').value);s.regime=get('[data-setting="cloak-regime"]').value;}
    else {s.frequency=Number(get('[data-setting="solid-frequency"]').value);s.preset=get('[data-setting="preset"]').value;s.polarization=get('[data-setting="polarization"]').value;s.regime=get('[data-setting="regime"]').value;}
}
function relevant(){return state.current&&state.current.kind===kind;}
function refreshStatus(){
    const dirty=!sameSettings(draft[kind],state.current?.settings),status=get('[data-status]');
    status.dataset.state=busy?'running':dirty?'dirty':'done';
    status.textContent=busy?(pendingAction==='probe'?'Опрос готового решения в точке датчика — без нового FEM-расчёта.':draft[kind].experiment==='solid'?'Считаем STG. Первый запуск включает калибровку и компиляцию — это может занять несколько минут.':draft.cloak.regime==='pulse'?'Считаем импульс: вода, голая трубка и трубка с оболочкой.':'Считаем трубку и перебор частот. Первый запуск каждой толщины дольше повторного.'):
        !relevant()?'Этот опыт пока не рассчитан.':dirty?'Параметры изменены. Ниже — предыдущий расчёт, не новый.':state.message||'Расчёт готов.';
    get('[data-error]').hidden=!state.error;get('[data-error]').textContent=state.error||'';
    all('[data-setting]').forEach(e=>e.disabled=busy);
    all('[data-action="run"],[data-action="pin"],[data-action="probe"],[data-saved-action],[data-choose]').forEach(e=>e.disabled=busy);
    get('[data-action="run"]').textContent=busy&&pendingAction==='run'?'Расчёт…':'Рассчитать опыт';
    get('[data-action="pin"]').disabled=busy||!relevant()||dirty;
    get('[data-pin-hint]').textContent=dirty?'Чтобы закрепить эти настройки, сначала рассчитайте их.':'Закрепляется весь запуск с контрольными случаями. Полка — в памяти сессии.';
    get('[data-result]').hidden=!relevant();get('[data-empty]').hidden=!!relevant();
}
function submit(action,extra={}){
    if(busy)return;
    pending=Math.max(clockNow(),lastNonce+1);lastNonce=pending;busy=true;
    pendingAction=action;submitted={action,nonce:pending,...extra};refreshStatus();
    root.dispatchEvent(new CustomEvent('input',{bubbles:true}));
}
function text(selector,value){get(selector).textContent=value;}
function metric(m){return m.value===null?'не определена':`${Number(m.value).toFixed(2)} ${m.unit}`;}
function receive(next){
    const previous=state.current?.id;
    // The server output stays self-contained for reconnect/reload. Within a
    // mounted widget reuse unchanged field objects and decoded frame buffers.
    if(next.current&&next.current.id===previous&&state.current.data)next.current.data=state.current.data;
    state=next;
    if(state.handled>=pending)busy=false;
    if(state.current&&(state.current.id!==previous||pendingAction==='restore')){
        stopAnimation();kind=state.current.kind;draft[kind]={...state.current.settings};phase=0;frameIndex=0;get('[data-view="phase"]').value=0;
        applyDraft();renderResult();
    }else if(state.current&&pendingAction==='pin')get('[data-note]').value=state.current.note;
    if(state.current)renderProbe();
    pendingAction='';
    renderShelf();refreshStatus();requestAnimationFrame(drawVisible);
}
function readUpdate(){
    const node=document.getElementById('meta-workbench-data');
    if(!node||node.textContent===lastRaw)return;
    lastRaw=node.textContent;
    try{receive(JSON.parse(lastRaw));}catch(error){text('[data-error]',`Не удалось прочитать результат: ${error.message}`);get('[data-error]').hidden=false;}
}
const observer=new MutationObserver(readUpdate);observer.observe(document.body,{childList:true,subtree:true,characterData:true});

function blobLink(file){const a=document.createElement('a'),url=URL.createObjectURL(new Blob([file.text],{type:file.mime}));urls.push(url);a.href=url;a.download=file.name;a.textContent=file.name;return a;}
function renderResult(){
    const r=state.current,d=r.data,f=d.field;
    text('[data-run-id]',`#${r.id} · ${d.label}`);text('[data-result-title]',d.title);text('[data-applied]',d.applied);text('[data-context]',d.context);
    text('[data-metric-label]',d.metric.label);text('[data-metric-value]',metric(d.metric));text('[data-metric-text]',d.metric.text);
    const cases=get('[data-view="case"]');cases.replaceChildren();f.cases.forEach((c,i)=>option(cases,i,c.name));cases.value=f.selected;
    const modes=get('[data-view="mode"]');modes.replaceChildren();
    if(d.kind==='cloak'&&transient()){option(modes,'pressure','Полное давление p(t), Pa');option(modes,'scattered','Рассеянное давление pₛ(t), Pa');}
    else if(d.kind==='cloak'){option(modes,'amplitude','Рассеянный звук |pₛ| / p₀');option(modes,'phase','Всё давление Re(p) / p₀');}
    else if(transient()){option(modes,'uy','Смещение uᵧ(t), nm');option(modes,'ux','Смещение uₓ(t), nm');}
    else {option(modes,'amplitude','Энергия ⟨K⟩ / Pвх');option(modes,'phase','Смещение Re(uᵧ) / √Pвх');}
    const timeline=get('[data-view="phase"]');timeline.max=transient()?f.frame_times_us.length-1:360;
    timeline.setAttribute('aria-label',transient()?'Время импульсного расчёта':'Фаза гармонического колебания');
    get('[data-source-panel]').hidden=!transient();
    text('[data-source-title]',f.source_title||'Импульс источника · после шести периодов сила равна нулю');
    const quantity=get('[data-view="quantity"]');quantity.replaceChildren();
    if(d.kind==='cloak'){option(quantity,'pressure','Полное давление p(t)');option(quantity,'scattered','Рассеянное pₛ(t), падающая вычтена');}
    else {option(quantity,'uy','Смещение uᵧ(t)');option(quantity,'ux','Смещение uₓ(t)');}
    get('[data-view="compare"]').checked=f.cases.length>1;get('[data-view="compare"]').disabled=f.cases.length<2;
    get('[data-zoom-label]').hidden=d.kind!=='cloak'||transient();get('[data-view="zoom"]').value='all';
    text('[data-plot-title]',d.plot_title||(d.kind==='cloak'?'Покрытие помогает на любой частоте?':'Профиль за стенкой: одинаковые оси, без нормировки пиков'));
    text('[data-plot-caption]',d.plot_caption||(d.kind==='cloak'?'Ниже 0 dB — меньше полного рассеяния. Выше — покрытие мешает. Точки сгущены около воздушных резонансов; линии лишь соединяют рассчитанные точки.':transient()?'Кинетическая энергия, интегрированная по всему временному окну / работа источника. Одинаковое сечение, без отдельной нормировки пиков.':'Полная средняя кинетическая энергия / принятая мощность в одном и том же сечении. Узкий пик сам по себе ещё не доказывает выигрыш в разрешении.'));
    get('[data-method]').replaceChildren(...d.method.map(s=>{const li=document.createElement('li');li.textContent=s;return li;}));
    text('[data-diagnostics]',JSON.stringify(d.diagnostics,null,2));
    urls.forEach(URL.revokeObjectURL);urls=[];get('[data-downloads]').replaceChildren(...d.downloads.map(blobLink));
    get('[data-note]').value=r.note;rasters=new WeakMap();decoded=new WeakMap();
}
function canvasContext(canvas,height){
    const width=Math.max(200,Math.round(canvas.getBoundingClientRect().width));
    canvas.style.height=`${height}px`;const dpr=Math.min(window.devicePixelRatio||1,2);
    canvas.width=Math.round(width*dpr);canvas.height=Math.round(height*dpr);
    const ctx=canvas.getContext('2d');ctx.scale(dpr,dpr);return {ctx,w:width,h:height};
}
function interpolate(raster,values,index){const a=raster.a[index];if(a<0)return null;return (1-raster.u[index]-raster.v[index])*values[a]+raster.u[index]*values[raster.b[index]]+raster.v[index]*values[raster.d[index]];}
function fieldScale(f,mode){
    if(f.domain==='time')return Math.max(f.kind==='water'?f.limits[mode]:f.limit_nm,1e-30);
    let limit=1e-20;
    for(const c of f.cases){
        const values=f.kind==='water'?(mode==='amplitude'?c.scatter:c.real.map((x,i)=>Math.hypot(x,c.imag[i]))):
            mode==='amplitude'?c.profile:c.vr.map((x,i)=>Math.hypot(x,c.vi[i])/Math.sqrt(c.diag.input_power_W_m));
        for(const value of values)limit=Math.max(limit,value);
    }
    return f.kind==='solid'&&mode==='amplitude'?limit*1.5:limit;
}
function decodedFrame(c,f,channel,count){
    if(!decoded.has(c)){
        decoded.set(c,null);
        const channels=f.kind==='solid'?[['ux',c.frames_x,f.limit_nm/1e9],['uy',c.frames_y,f.limit_nm/1e9]]:
            [['pressure',c.frames_pressure,f.limits.pressure],['scattered',c.frames_scattered,f.limits.scattered]];
        Promise.all(channels.map(async([key,encoded,limit])=>[key,await decodePulseFrames(encoded,limit)])).then(entries=>{
            decoded.set(c,Object.fromEntries(entries));requestAnimationFrame(drawVisible);
        }).catch(error=>{text('[data-error]',`Не удалось распаковать кадры: ${error.message}`);get('[data-error]').hidden=false;});
    }
    return decoded.get(c)?.[channel].subarray(frameIndex*count,(frameIndex+1)*count);
}
function drawField(canvas,c,f,mode,scale,index){
    const solid=f.kind==='solid',aspect=solid?f.height/f.width:1;
    const width=Math.max(220,canvas.getBoundingClientRect().width),height=Math.round(width*aspect)+25;
    const {ctx,w,h}=canvasContext(canvas,height),ph=h-25;
    ctx.fillStyle='#102c3d';ctx.fillRect(0,0,w,h);
    if(solid){
        const key=`${w}:${ph}`;let cache=rasters.get(c);if(!cache){cache=new Map();rasters.set(c,cache);}
        if(!cache.has(key))cache.set(key,makeTriangleRaster(c,w,ph,x=>(x+f.width/2)*w/f.width,y=>(f.height/2-y)*ph/f.height));
        const raster=cache.get(key),pixels=raster.image.data,power=c.diag.input_power_W_m,omega=2*Math.PI*f.frequency;
        let nodal;
        if(f.domain==='time'){
            nodal=decodedFrame(c,f,mode,c.xy.length);if(!nodal)return;
        }
        for(let j=0;j<raster.a.length;j++){
            let value=null;
            if(raster.a[j]>=0){
                if(nodal)value=interpolate(raster,nodal,j)*1e9;
                else {
                    const ur=interpolate(raster,c.ur,j),ui=interpolate(raster,c.ui,j),vr=interpolate(raster,c.vr,j),vi=interpolate(raster,c.vi,j);
                    value=mode==='amplitude'?f.density*omega**2*(ur*ur+ui*ui+vr*vr+vi*vi)/(4*power):(vr*Math.cos(phase)+vi*Math.sin(phase))/Math.sqrt(power);
                }
            }
            const rgb=value===null?[7,20,29]:ramp(f.domain==='time'?pulseContrast(value,scale):value/scale,f.domain==='time'||mode==='phase');
            pixels[j*4]=rgb[0];pixels[j*4+1]=rgb[1];pixels[j*4+2]=rgb[2];pixels[j*4+3]=255;
        }
        raster.oc.putImageData(raster.image,0,0);ctx.drawImage(raster.off,0,0,w,ph);
        const X=x=>(x+f.width/2)*w/f.width,Y=y=>(f.height/2-y)*ph/f.height;
        ctx.strokeStyle='#b2ced8';ctx.lineWidth=.7;
        for(const poly of c.outlines){ctx.beginPath();poly.forEach((p,i)=>i?ctx.lineTo(X(p[0]),Y(p[1])):ctx.moveTo(X(p[0]),Y(p[1])));ctx.closePath();ctx.stroke();}
        ctx.setLineDash([4,4]);ctx.strokeStyle='#ffc56d';ctx.beginPath();ctx.moveTo(X(f.focus),0);ctx.lineTo(X(f.focus),ph);ctx.stroke();ctx.setLineDash([]);
        ctx.fillStyle='#c6e3ec';ctx.font='10px system-ui';ctx.fillText('источник →',Math.max(4,X(f.source)-25),13);ctx.fillText('сечение',Math.min(w-50,X(f.focus)+4),ph-8);
    }else{
        const n=f.count,off=document.createElement('canvas');off.width=n;off.height=n;const oc=off.getContext('2d'),im=oc.createImageData(n,n);
        const values=f.domain==='time'?decodedFrame(c,f,mode,n*n):null;
        if(f.domain==='time'&&!values)return;
        for(let y=0;y<n;y++)for(let x=0;x<n;x++){
            const j=y*n+x,k=(n-1-y)*n+x;
            const v=values?values[j]:mode==='amplitude'?c.scatter[j]:c.real[j]*Math.cos(phase)+c.imag[j]*Math.sin(phase);
            const rgb=ramp(values?pulseContrast(v,scale):v/scale,!!values||mode==='phase');
            im.data.set([...rgb,255],k*4);
        }
        oc.putImageData(im,0,0);ctx.imageSmoothingEnabled=true;ctx.drawImage(off,0,0,w,ph);
        if(c.case!=='empty'){
            const circle=(r,fill)=>{ctx.beginPath();ctx.ellipse(w/2,ph/2,r*w/(2*f.extent),r*ph/(2*f.extent),0,0,2*Math.PI);ctx.fillStyle=fill;ctx.fill();ctx.strokeStyle='#b8d4dd';ctx.lineWidth=.8;ctx.stroke();};
            if(c.case==='coated')circle(f.coatR,'#7fbaaf');circle(f.steelR,'#8299a7');circle(f.airR,'#142631');
        }
    }
    const probe=state.current.probe;
    if(probe){
        const halfwidth=solid?f.width/2:f.extent,halfheight=solid?f.height/2:f.extent;
        const x=(probe.point_mm[0]/halfwidth+1)*w/2,y=(1-probe.point_mm[1]/halfheight)*ph/2,valid=probe.cases[index].valid;
        ctx.strokeStyle=valid?'#ffe06c':'#ff8b8b';ctx.lineWidth=2;ctx.fillStyle='#102c3d';ctx.beginPath();ctx.arc(x,y,6,0,2*Math.PI);ctx.fill();ctx.stroke();
        ctx.beginPath();ctx.moveTo(x-10,y);ctx.lineTo(x+10,y);ctx.moveTo(x,y-10);ctx.lineTo(x,y+10);ctx.stroke();
        ctx.font='bold 11px system-ui';ctx.fillStyle=ctx.strokeStyle;ctx.fillText(valid?'D1':'D1 ×',Math.max(3,Math.min(w-40,x+10)),Math.max(13,y-10));
    }
    ctx.fillStyle='#bfd6e1';ctx.font='10px system-ui';ctx.textAlign='left';const extent=solid?f.width/2:f.extent;
    ctx.fillText(`x: −${extent.toFixed(0)} mm`,6,h-8);ctx.textAlign='right';ctx.fillText(`+${extent.toFixed(0)} mm`,w-6,h-8);ctx.textAlign='left';
}
function drawMaps(){
    if(!relevant()||tab!=='lab')return;
    const d=state.current.data,f=d.field,mode=get('[data-view="mode"]').value,selected=Number(get('[data-view="case"]').value);
    const compare=get('[data-view="compare"]').checked;get('[data-control-map]').hidden=!compare;get('.wb-fields').classList.toggle('single',!compare);
    const scale=fieldScale(f,mode),signed=transient()||mode==='phase';
    text('[data-map-title="selected"]',f.cases[selected].name);text('[data-map-title="control"]',`Контроль: ${f.cases[f.baseline].name}`);
    drawField(get('[data-map="selected"]'),f.cases[selected],f,mode,scale,selected);
    if(compare)drawField(get('[data-map="control"]'),f.cases[f.baseline],f,mode,scale,f.baseline);
    get('.wb-color-key').classList.toggle('signed',signed);
    text('[data-color-label]',transient()?(f.kind==='water'?`${mode==='scattered'?'pₛ':'p'}(t), Pa`:`${mode==='ux'?'uₓ':'uᵧ'}(t), nm`):f.kind==='water'?(signed?'Давление / p₀':'Рассеянное давление / p₀'):(signed?'uᵧ / √Pвх, m/√(W/m)':'⟨K⟩ / Pвх, s/m²'));
    text('[data-color-range]',`${signed?'±':'0 … '}${scale.toPrecision(3)}${f.kind==='solid'&&!signed?' · выше — насыщение шкалы':''} · общая шкала${transient()?` · контраст √|${f.kind==='water'?'p':'u'}|`:''}`);
    text('[data-phase-value]',transient()?`${currentTime().toFixed(2)} μs`:`${Math.round(phase*180/Math.PI)}°`);
    text('[data-playback-caption]',transient()?`${frameIndex+1}/${f.frame_times_us.length} · ${currentTime()<f.source_end_us?'источник возбуждается':'источник выключен'} · замедленное физическое время, без зацикливания`:'Замедленное гармоническое колебание, не приход импульса');
}
function tick(v){const a=Math.abs(v);return a!==0&&(a>=10000||a<.01)?v.toExponential(1):Number(v.toPrecision(4)).toString();}
function drawPlot(canvas,curves,xrange=null,marker=null){
    const {ctx,w,h}=canvasContext(canvas,245),style=getComputedStyle(root),ink=style.getPropertyValue('--muted').trim(),line=style.getPropertyValue('--line').trim();
    ctx.fillStyle=style.getPropertyValue('--panel');ctx.fillRect(0,0,w,h);
    const limits=plotLimits(curves,xrange);if(!limits)return;
    const {xmin,xmax,ymin,ymax}=limits,L=65,R=16,T=18,B=47,X=x=>L+(x-xmin)/(xmax-xmin)*(w-L-R),Y=y=>h-B-(y-ymin)/(ymax-ymin)*(h-T-B);
    ctx.font='10px system-ui';ctx.fillStyle=ink;ctx.strokeStyle=line;ctx.lineWidth=1;
    for(let i=0;i<=4;i++){
        const x=xmin+(xmax-xmin)*i/4,y=ymin+(ymax-ymin)*i/4;
        ctx.beginPath();ctx.moveTo(X(x),T);ctx.lineTo(X(x),h-B);ctx.moveTo(L,Y(y));ctx.lineTo(w-R,Y(y));ctx.stroke();
        ctx.textAlign='center';ctx.fillText(tick(x),X(x),h-B+16);ctx.textAlign='right';ctx.fillText(tick(y),L-6,Y(y)+3);
    }
    ctx.save();ctx.beginPath();ctx.rect(L,T,w-L-R,h-T-B);ctx.clip();
    curves.forEach((c,index)=>{
        if(Number.isFinite(c.reference)){ctx.strokeStyle=ink;ctx.setLineDash([4,4]);ctx.beginPath();ctx.moveTo(L,Y(c.reference));ctx.lineTo(w-R,Y(c.reference));ctx.stroke();ctx.setLineDash([]);}
        ctx.strokeStyle=c.color||palette[index%palette.length];ctx.lineWidth=2;ctx.beginPath();let started=false;
        c.x.forEach((x,i)=>{const y=c.y[i];if(!Number.isFinite(y)||!Number.isFinite(x)){started=false;return;}if(!started){ctx.moveTo(X(x),Y(y));started=true;}else ctx.lineTo(X(x),Y(y));});ctx.stroke();
        if(xrange){ctx.fillStyle=ctx.strokeStyle;c.x.forEach((x,i)=>{if(x>=xmin&&x<=xmax&&Number.isFinite(c.y[i])){ctx.beginPath();ctx.arc(X(x),Y(c.y[i]),1.7,0,2*Math.PI);ctx.fill();}});}
    });
    if(Number.isFinite(marker)){ctx.strokeStyle=ink;ctx.setLineDash([3,3]);ctx.beginPath();ctx.moveTo(X(marker),T);ctx.lineTo(X(marker),h-B);ctx.stroke();ctx.setLineDash([]);}
    ctx.restore();
    ctx.fillStyle=ink;ctx.textAlign='center';ctx.fillText(curves[0].x_label,w/2,h-8);ctx.save();ctx.translate(12,h/2);ctx.rotate(-Math.PI/2);ctx.fillText(curves[0].y_label,0,0);ctx.restore();ctx.textAlign='left';
}
function legend(parent,curves){const e=document.createElement('div');e.className='wb-legend';curves.forEach((c,i)=>{const s=document.createElement('span');s.textContent=`● ${c.label}`;s.style.color=c.color||palette[i%palette.length];e.append(s);});parent.append(e);}
function drawMain(){
    if(!relevant()||tab!=='lab')return;
    const d=state.current.data;let curves,xrange=null;
    if(d.kind==='cloak'&&!transient()){
        curves=[d.curve];if(get('[data-view="zoom"]').value==='resonance'){const f=d.resonances[0];xrange=[f-.03,f+.03];}
    }else {
        const selected=Number(get('[data-view="case"]').value);
        curves=d.field.cases.map((c,i)=>({...d.curve,y:c.profile,label:c.name,color:palette[i===selected?0:i===d.field.baseline?1:i+2]}));
    }
    drawPlot(get('[data-plot="main"]'),curves,xrange);
    const section=get('[data-plot="main"]').parentElement;
    section.querySelector('.wb-legend')?.remove();if(d.kind==='solid'||transient())legend(section,curves);
}
function probeCases(){
    if(!relevant()||!state.current.probe)return [];
    const f=state.current.data.field,selected=Number(get('[data-view="case"]').value);
    return [selected,...(get('[data-view="compare"]').checked&&selected!==f.baseline?[f.baseline]:[])];
}
function renderProbe(){
    if(!relevant())return;
    const probe=state.current.probe,q=get('[data-view="quantity"]').value;
    get('[data-plot="probe"]').hidden=!probe;get('[data-action="probe-export"]').disabled=!probe;
    const container=get('[data-probe-readings]');container.replaceChildren();get('[data-probe-legend]').replaceChildren();
    text('[data-probe-caption]',state.current.kind==='cloak'?(transient()?'Идеальный микрофон в воде. Полное давление = падающий импульс + рассчитанное рассеянное поле; опрос каждого шага FEM, без нового расчёта и без шума.':'Идеальный микрофон измеряет полное давление в воде. Рассеянный сигнал — обработка с вычитанием известной падающей волны. Это не цвет карты и не новый импульсный расчёт.'):'Идеальный точечный датчик смещения. Здесь фактические nm, без нормировки на принятую мощность или цветовую шкалу. В вырезах твёрдого тела нет.');
    if(!probe){text('[data-probe-status]','Датчик ещё не установлен. Нажмите в поле или задайте координаты.');return;}
    get('[data-probe-x]').value=probe.point_mm[0].toFixed(3);get('[data-probe-y]').value=probe.point_mm[1].toFixed(3);
    text('[data-probe-status]',`D1: x = ${probe.point_mm[0].toFixed(3)} mm, y = ${probe.point_mm[1].toFixed(3)} mm · ${(probe.frequency/1000).toFixed(3)} kHz · ${probe.domain==='time'?`${probe.time_us.length} расчётных шагов, 0–${probe.time_us.at(-1).toFixed(1)} μs`:'два периода установившегося сигнала'}, без шума.`);
    const legends=[];
    for(const [position,index]of probeCases().entries()){
        const c=probe.cases[index],card=document.createElement('div');card.className='wb-reading';
        const name=document.createElement('div');name.textContent=`${position?'Контроль: ':''}${c.name}`;card.append(name);
        if(!c.valid){const reason=document.createElement('span');reason.textContent=c.reason;card.append(reason);}
        else {
            const signal=c.signals[q],a=signal.phasor,peak=document.createElement('strong'),details=document.createElement('span'),now=document.createElement('span');
            if(probe.domain==='time'){
                const amplitude=Math.max(...signal.values.map(Math.abs)),rms=Math.sqrt(signal.values.reduce((sum,v)=>sum+v*v,0)/signal.values.length);
                peak.textContent=`Пик |${probe.unit==='Pa'?(q==='scattered'?'pₛ':'p'):'u'}| ${tick(amplitude)} ${probe.unit}`;details.textContent=`RMS всего окна ${tick(rms)} ${probe.unit} · история FEM, не синус из фазы`;
            }else {
                const amplitude=Math.hypot(...a);
                peak.textContent=`Амплитуда ${tick(amplitude)} ${probe.unit}`;details.textContent=`RMS ${tick(amplitude/Math.sqrt(2))} ${probe.unit} · arg A = ${Math.round(Math.atan2(a[1],a[0])*180/Math.PI)}°`;
            }
            now.dataset.probeInstant=index;card.append(peak,details,now);legends.push({label:`${position?'Контроль: ':''}${c.name}`,color:palette[position]});
        }
        container.append(card);
    }
    for(const l of legends){const span=document.createElement('span');span.textContent=`● ${l.label}`;span.style.color=l.color;get('[data-probe-legend]').append(span);}
    drawProbe();
}
function drawProbe(){
    if(!relevant()||tab!=='lab'||!state.current.probe)return;
    const p=state.current.probe,q=get('[data-view="quantity"]').value,curves=[];
    for(const [position,index]of probeCases().entries()){
        const c=p.cases[index];if(!c.valid)continue;
        const a=c.signals[q],node=get(`[data-probe-instant="${index}"]`);
        if(node)node.textContent=p.domain==='time'?`В t = ${currentTime().toFixed(2)} μs: ${tick(a.values[nearestTime(p.time_us,currentTime())])} ${p.unit}`:`При текущей фазе: ${tick(phasorValue(a.phasor,phase))} ${p.unit}`;
        curves.push({x:p.time_us,y:a.values,x_label:'Время, μs',y_label:`${q==='pressure'?'p':q==='scattered'?'pₛ':q==='ux'?'uₓ':'uᵧ'}(t), ${p.unit}`,reference:0,color:palette[position]});
    }
    drawPlot(get('[data-plot="probe"]'),curves,null,p.domain==='time'?currentTime():phase/(2*Math.PI*p.frequency)*1e6);
}
function placeProbe(point,target){
    if(busy||!relevant()||!point)return;
    submit('probe',{id:state.current.id,point_mm:point,case:target});
}
all('[data-map]').forEach(canvas=>canvas.onclick=event=>{
    if(!relevant())return;
    const box=canvas.getBoundingClientRect(),f=state.current.data.field;
    const point=fieldPoint(event.clientX-box.left,event.clientY-box.top,box.width,box.height,f.kind==='water'?f.extent:f.width/2,f.kind==='water'?f.extent:f.height/2);
    placeProbe(point,canvas.dataset.map==='control'?f.baseline:Number(get('[data-view="case"]').value));
});
get('[data-action="probe"]').onclick=()=>placeProbe([Number(get('[data-probe-x]').value),Number(get('[data-probe-y]').value)],Number(get('[data-view="case"]').value));
get('[data-action="probe-export"]').onclick=()=>{
    const p=state.current.probe,q=get('[data-view="quantity"]').value;
    const lines=['case,domain,quantity,x_m,y_m,frequency_Hz,time_s,value_'+p.unit];
    p.cases.forEach(c=>{if(c.valid)c.signals[q].values.forEach((v,i)=>lines.push(['"'+c.name.replace(/"/g,'""')+'"',p.domain,q,p.point_mm[0]/1000,p.point_mm[1]/1000,p.frequency,p.time_us[i]/1e6,v].join(',')));});
    blobLink({name:`sensor_D1_run_${state.current.id}_${q}.csv`,mime:'text/csv',text:lines.join('\n')}).click();
};
function renderShelf(){
    text('[data-count]',state.pinned.length);get('[data-shelf-empty]').hidden=state.pinned.length>0;get('[data-action="export"]').disabled=state.pinned.length===0;
    get('[data-shelf-list]').replaceChildren(...state.pinned.map(r=>{
        const row=document.createElement('article');row.className='wb-saved';const info=document.createElement('div'),title=document.createElement('strong'),note=document.createElement('p');
        title.textContent=`#${r.id} · ${r.kind==='cloak'?'Трубка':'STG'} · ${r.label} · ${metric(r.metric)}`;note.textContent=r.note||'Без заметки';info.append(title,note);
        const actions=document.createElement('div');actions.className='wb-saved-actions';
        for(const [action,label]of [['restore','Открыть'],['remove','Убрать']]){const b=document.createElement('button');b.dataset.savedAction=action;b.textContent=label;b.onclick=()=>{if(action==='restore')showTab('lab');submit(action,{id:r.id});};actions.append(b);}
        row.append(info,actions);return row;
    }));
    get('[data-shelf-plots]').replaceChildren();
    for(const group of ['cloak-pulse','cloak-harmonic','solid-pulse','solid-harmonic']){
        const runs=state.pinned.filter(r=>runGroup(r)===group);if(!runs.length)continue;
        const section=document.createElement('section');section.className='wb-plot-section wb-shelf-plot';section.dataset.group=group;
        const title=document.createElement('h3');title.textContent=group==='cloak-pulse'?'Трубка · импульс: интеграл pₛ² на контуре':group==='cloak-harmonic'?'Трубка · гармоника: полное рассеяние / голая трубка':group==='solid-pulse'?'STG · импульс: ∫K dt / работа источника':'STG · гармоника: энергия / принятая мощность';
        const canvas=document.createElement('canvas');canvas.dataset.plot='shelf';canvas.setAttribute('aria-label',title.textContent);section.append(title,canvas);legend(section,runs.map(r=>({label:`#${r.id} ${r.label}`})));get('[data-shelf-plots]').append(section);
    }
}
function drawSource(){if(relevant()&&transient()&&tab==='lab'){const f=state.current.data.field;drawPlot(get('[data-plot="source"]'),[{x:f.source_times_us,y:f.source_drive,x_label:'Время, μs',y_label:f.source_y_label||'Сила / заданный масштаб',reference:0}],null,currentTime());}}
get('[data-source-panel]').ontoggle=drawSource;
function drawVisible(){drawMaps();drawMain();drawProbe();drawSource();if(tab==='shelf')all('[data-group]').forEach(e=>drawPlot(e.querySelector('canvas'),state.pinned.filter(r=>runGroup(r)===e.dataset.group).map(r=>r.curve)));}

all('[data-tab]').forEach(e=>e.onclick=()=>showTab(e.dataset.tab));
all('[data-choose]').forEach(e=>e.onclick=()=>{kind=e.dataset.choose;applyDraft();showTab('lab');});
all('[data-setting]').forEach(e=>{e.onchange=()=>{if(e.dataset.setting==='experiment'){readDraft();kind=e.value;applyDraft();}else {readDraft();refreshStatus();}drawVisible();};});
// Draft controls must not bubble an input to Pluto's one submitted-command bond.
root.addEventListener('input',event=>{if(event.target!==root)event.stopPropagation();});
get('[data-action="run"]').onclick=()=>{readDraft();submit('run',{settings:{...draft[kind]}});};
get('[data-action="pin"]').onclick=()=>submit('pin',{id:state.current.id,note:get('[data-note]').value});
all('[data-view]').forEach(e=>{e.oninput=()=>{
    if(e.dataset.view==='phase'){stopAnimation();if(transient())frameIndex=Number(e.value);else get('[data-view="mode"]').value='phase';}
    if(!transient()&&e.dataset.view==='mode'&&e.value!=='phase')stopAnimation();
    phase=Number(get('[data-view="phase"]').value)*Math.PI/180;renderProbe();drawVisible();
};});
function stopAnimation(){playing=false;cancelAnimationFrame(frame);get('[data-action="play"]').textContent='▶ Анимация волны';get('[data-action="play"]').setAttribute('aria-pressed','false');}
get('[data-action="play"]').onclick=()=>{
    if(playing){stopAnimation();return;}
    if(transient()){if(frameIndex===state.current.data.field.frame_times_us.length-1)frameIndex=0;playStart=frameIndex;playStamp=performance.now();}
    else get('[data-view="mode"]').value='phase';
    playing=true;get('[data-action="play"]').textContent='Ⅱ Пауза';get('[data-action="play"]').setAttribute('aria-pressed','true');animate();
};
function animate(){
    if(!playing)return;
    if(transient()){
        const count=state.current.data.field.frame_times_us.length;
        frameIndex=playbackFrame(playStart,performance.now()-playStamp,count);get('[data-view="phase"]').value=frameIndex;
        drawMaps();drawProbe();drawSource();
        if(frameIndex===count-1){stopAnimation();return;}
    }else {phase=(phase+.06)%(2*Math.PI);get('[data-view="phase"]').value=phase*180/Math.PI;drawMaps();drawProbe();}
    frame=requestAnimationFrame(animate);
}
get('[data-action="export"]').onclick=()=>{
    const file={name:'metandt-runs.json',mime:'application/json',text:JSON.stringify({format:'metandt-workbench-1',runs:state.pinned},null,2)};
    const a=blobLink(file);a.click();
};
const resize=new ResizeObserver(()=>requestAnimationFrame(drawVisible));resize.observe(root);
const media=matchMedia('(prefers-color-scheme: dark)');media.addEventListener('change',drawVisible);
if(typeof invalidation!=='undefined')invalidation.then(()=>{observer.disconnect();resize.disconnect();playing=false;cancelAnimationFrame(frame);media.removeEventListener('change',drawVisible);urls.forEach(URL.revokeObjectURL);});
applyDraft();readUpdate();
