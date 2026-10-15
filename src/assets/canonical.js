// All scientific arrays were prepared offline. No requests to a numerical
// backend occur in this viewer, including when a microphone moves.
function cnBilinear(c,point){
  const nx=c.x.length,ny=c.y.length,x=point[0],y=point[1];
  if(x<c.x[0]||x>c.x.at(-1)||y<c.y[0]||y>c.y.at(-1))return null;
  const gx=(x-c.x[0])/(c.x.at(-1)-c.x[0])*(nx-1),gy=ny===1?0:(y-c.y[0])/(c.y.at(-1)-c.y[0])*(ny-1);
  const i=Math.min(nx-2,Math.floor(gx)),j=ny===1?0:Math.min(ny-2,Math.floor(gy)),u=gx-i,v=ny===1?0:gy-j;
  const indices=ny===1?[i,i+1]:[i+j*nx,i+1+j*nx,i+(j+1)*nx,i+1+(j+1)*nx];
  if(indices.some(k=>!c.valid[k]))return null;
  return {indices,weights:ny===1?[1-u,u]:[(1-u)*(1-v),u*(1-v),(1-u)*v,u*v]};
}
function cnTrace(c,point,values=c.samples){const stencil=cnBilinear(c,point);if(!stencil)return null;const n=c.x.length*c.y.length;return c.times.map((_,t)=>stencil.indices.reduce((sum,k,j)=>sum+values[t*n+k]*stencil.weights[j],0))}
function cnAccumulation(c){
  const n=c.x.length*c.y.length,out=new Float64Array(n);
  for(let t=1;t<c.times.length;t++){const dt=(c.times[t]-c.times[t-1])/2;
    for(let k=0;k<n;k++)out[k]+=dt*(c.samples[(t-1)*n+k]**2+c.samples[t*n+k]**2)}
  return out;
}
function cnFocusFrame(c){const trace=cnTrace(c,[c.geometry.focus,0]);if(!trace)return 0;let i=0;for(let j=1;j<trace.length;j++)if(Math.abs(trace[j])>Math.abs(trace[i]))i=j;return i}
function cnAxisTicks(min,max){
  const raw=(max-min)/5,power=10**Math.floor(Math.log10(raw));
  const step=([1,2,2.5,5,10].find(n=>n>=raw/power-1e-12)||10)*power;
  const low=Math.floor(min/step+1e-12)*step,high=Math.ceil(max/step-1e-12)*step;
  return {min:low,max:high,ticks:Array.from({length:Math.round((high-low)/step)+1},(_,i)=>{const v=low+i*step;return Math.abs(v)<step*1e-10?0:Number(v.toPrecision(12))})};
}
function cnClosest(times,time){let lo=0,hi=times.length-1;while(lo<hi){const m=Math.floor((lo+hi)/2);if(times[m]<time)lo=m+1;else hi=m}return lo>0&&Math.abs(times[lo-1]-time)<Math.abs(times[lo]-time)?lo-1:lo}
async function cnDecode(encoded){
  if(typeof DecompressionStream==='undefined')throw new Error('Нужен современный Chrome, Edge, Firefox или Safari с DecompressionStream.');
  const raw=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0));
  const buffer=await new Response(new Blob([raw]).stream().pipeThrough(new DecompressionStream('deflate'))).arrayBuffer();
  if(buffer.byteLength%4)throw new Error('Повреждённый массив временных данных');
  const view=new DataView(buffer),out=new Float32Array(buffer.byteLength/4);for(let i=0;i<out.length;i++)out[i]=view.getFloat32(4*i,true);return out;
}

const cnRoot=document.getElementById('canonical-lab'),cnGet=s=>cnRoot.querySelector(s),cnData=canonicalData;
const cnColors=['#9caebb','#2bbba9','#efab58','#ae8bd7'];
let cnSet=0,cnActive=cnData.id==='absorber'?2:cnData.sets[0].cases.length-1,cnFrame=0,cnPlaying=false,cnRaf=0,cnStart=0,cnStartFrame=0,cnPoint=null,cnSignals=[],cnLimit=1,cnMotionLimit=1,cnEcho=false,cnDisposed=false,cnLoadVersion=0,cnReady=false;
let cnView='wave',cnPathLimit=1;
const cnTheme=()=>({fg:getComputedStyle(cnRoot).color,muted:getComputedStyle(cnGet('.cn-caption')).color,line:'#50738355'});
const cnFormat=(n,d=3)=>Number(n).toPrecision(d),cnTime=t=>t>=.01?(t*1000).toFixed(2)+' ms':(t*1e6).toFixed(1)+' μs';
const cnTickLabel=n=>{const label=String(Number(Number(n).toPrecision(3)));return label.length>8?n.toExponential(2).replace('e+','e'):label};
const cnFrequency=f=>f>=1000?(f/1000).toLocaleString('ru-RU',{maximumFractionDigits:2})+' kHz':f.toLocaleString('ru-RU',{maximumFractionDigits:1})+' Hz';
const cnCases=()=>cnData.sets[cnSet].cases;
const cnReference=()=>cnData.sets[cnSet].reference||0;
const cnValues=c=>cnEcho&&c.echo?c.echo:c.samples;
cnGet('.cn-title').textContent=cnData.title;cnGet('.cn-question').textContent=cnData.question;cnGet('.cn-instruction').textContent=cnData.instruction;
cnGet('.cn-model').textContent=cnData.model;cnGet('.cn-bound').textContent=cnData.limit;
cnGet('.cn-paper').textContent=cnData.source;cnGet('.cn-paper').href=cnData.url;

function cnStop(){cnPlaying=false;cancelAnimationFrame(cnRaf);cnGet('.cn-play').textContent=cnView==='path'?'▶ Смотреть импульс':'▶ Запустить импульс'}
function cnContext(selector){const canvas=cnGet(selector),ctx=canvas.getContext('2d');ctx.clearRect(0,0,canvas.width,canvas.height);return [ctx,canvas.width,canvas.height]}
function cnWaveColor(z){const a=Math.min(1,Math.sqrt(Math.abs(z)));return z>=0?[15+239*a,32+110*a,43+54*a]:[15+60*a,32+132*a,43+200*a]}
function cnPathColor(z){const a=Math.min(1,Math.sqrt(Math.max(0,z)));return [10+235*a*a,25+190*a,35+110*a*(1-a)]}
function cnLegend(selector,series){
  cnGet(selector).replaceChildren(...series.filter(s=>s.name).map((s,j)=>{const el=document.createElement('span'),line=document.createElement('i');line.style.background=s.color||cnColors[j%cnColors.length];el.append(line,document.createTextNode(s.name));return el}));
}
function cnRenderScale(prefix,{title,limit,path=false,note}){
  cnGet(prefix+'-title').textContent=title;
  // Sample the actual field palette at known values, including its nonlinear
  // enhancement of weak signals. Tick positions are linear in the quantity.
  cnGet(prefix+'-bar').style.background='linear-gradient(to right,'+Array.from({length:129},(_,i)=>{
    const z=path?i/128:2*i/128-1,color=(path?cnPathColor:cnWaveColor)(z);
    return 'rgb('+color.map(Math.round).join(',')+') '+(100*i/128)+'%';
  }).join(',')+')';
  cnGet(prefix+'-ticks').replaceChildren(...Array.from({length:5},(_,i)=>{const el=document.createElement('span');el.textContent=path?(25*i)+(i===4?'+':''):cnTickLabel((i/2-1)*limit);return el}));
  cnGet(prefix+'-bar').ariaLabel=title+'; '+(path?'от 0 до 100 процентов и выше':'от '+cnTickLabel(-limit)+' до '+cnTickLabel(limit));
  cnGet(prefix+'-note').textContent=note;
}
function cnShowFieldGuide(){
  const lesson=cnLesson(),focus=cnData.id==='focus',path=focus&&cnView==='path',cavity=cnCases()[0].geometry.type==='helmholtz';
  cnRenderScale('.cn-scale',path?{
    title:'Накопленный квадрат смещения · Q / Qref, %',limit:cnPathLimit,path:true,
    note:'Q(x,y) = ∫uᵧ² dt за всю запись — не энергия. 100% — общий максимум Q двух образцов дальше 5 мм за выходом ячеек (Qref). Значения выше 100% показаны тем же жёлтым цветом.'
  }:{
    title:focus?'Поперечное смещение uᵧ, нм':cnEcho?'Рассеянное давление pₛ, Па':cavity?'Давление в канале p, Па':'Избыточное давление p, Па',limit:cnLimit,
    note:focus?'Синий — смещение в сторону −y, красный — в сторону +y. 1 нм — миллиардная доля метра.':cnEcho?'pₛ = p − pᵢ: из полного поля вычтено давление падающей волны в пустой воде. Синий — минус, красный — плюс. Па — паскаль.':'Показано отклонение давления от равновесного: синий — понижение, красный — повышение. Па — паскаль, единица давления.'
  });
  cnGet('.cn-cavity-scale').hidden=!cavity;
  if(cavity)cnRenderScale('.cn-cavity-scale',{title:'Давление в боковых полостях pₕ, Па',limit:cnMotionLimit,note:'Отдельный диапазон для всех полостей обоих образцов. Цвет полости — одно рассчитанное давление, не двумерное поле внутри неё.'});
  cnGet('.cn-caption').textContent='Шкала общая для двух карт и фиксирована на всю запись. При смене частоты или режима поля диапазон может измениться. Цвет нелинейный: сверяйтесь с делениями, а не с яркостью.'+(path?' Слева от выходов ячеек след не показан.':'');
  cnGet('.cn-field-reading').textContent=focus&&cnActive===cnReference()?lesson.control_field:path?lesson.path_field:lesson.field;
  const keys=[['⌖','Датчик: одна точка для обоих образцов']];
  const type=cnCases()[0].geometry.type;
  if(type==='solid')keys.push(['┆','Жёлтый пунктир — сечение профиля'],['○','Кольцо на оси — положение перетяжки'],['▧','Серое — пустоты; там нет смещения материала']);
  if(type==='prism')keys.push(['┄','Жёлтый пунктир — нормаль к границе призмы']);
  if(type==='ground')keys.push(['△','Золотистый контур — граница плаща'],['▧','Серое — жёсткое основание']);
  if(type==='tube')keys.push(['○','Золотистое — резина; серое — сталь; тёмный центр — воздух']);
  cnGet('.cn-geometry-key').replaceChildren(...keys.map(([icon,text])=>{const el=document.createElement('span'),symbol=document.createElement('i');symbol.textContent=icon;el.append(symbol,document.createTextNode(text));return el}));
  cnGet('.cn-trace-title').textContent=focus?'Сигнал датчика: поперечное смещение':cnEcho?'Сигнал микрофона: только эхо':'Сигнал датчика: давление';
  cnGet('.cn-trace-explanation').textContent=lesson.signal+(path?' Выбранного момента здесь нет: карта выше суммирует всю запись.':' Жёлтая вертикаль — момент, показанный на картах.');
  cnGet('.cn-control').ariaLabel=cnGet('.cn-selected').ariaLabel=path?'Карта накопленного квадрата смещения':'Мгновенное поле '+(focus?'поперечного смещения':'давления');
}
const cnLensExit=c=>c.geometry.lens_exit??Math.max(...c.geometry.outlines.flatMap(line=>line.map(p=>p[0])));
function cnChannelBox(c,h){return c.geometry.type==='helmholtz'?{top:h*.62,height:50}:{top:h*.47-h*.27,height:h*.54}}
function cnCoordinate(c){return c.x.at(-1)-c.x[0]<.3?{factor:1000,unit:'мм'}:{factor:1,unit:'м'}}
function cnProbePoint(c,w,h,px,py){
  if(px<42||px>w-16||py<24||py>h-41)return null;
  if(c.y.length===1){const band=cnChannelBox(c,h);if(py<band.top||py>band.top+band.height)return null}
  return [c.x[0]+(px-42)/(w-58)*(c.x.at(-1)-c.x[0]),c.y.length===1?0:c.y.at(-1)-(py-24)/(h-65)*(c.y.at(-1)-c.y[0])];
}

function cnGeometry(ctx,c,frame,X,Y,w,h){
  const g=c.geometry;ctx.strokeStyle='#e1e9e9';ctx.fillStyle='#647e8c';ctx.lineWidth=2;
  if(g.type==='membrane'||g.type==='absorber'){
    const n=c.internal_count,offset=frame*n,max=cnMotionLimit;
    // Deformation is exaggerated for visibility and explicitly labelled.
    const shift=i=>max>0?c.motion[offset+i]/max*36:0;
    const cy=h*.47,rad=h*.27;ctx.beginPath();
    if(!g.wall){for(let side of [-1,1]){ctx.moveTo(X(0)+shift(0),cy+side*rad*g.r[0]/g.radius);for(let i=0;i<g.r.length;i++)ctx.lineTo(X(0)+(i<n?shift(i):0),cy+side*rad*g.r[i]/g.radius)}ctx.stroke();ctx.lineWidth=7;ctx.beginPath();ctx.moveTo(X(0)+shift(0),cy-rad*g.disk_radius/(g.radius||1));ctx.lineTo(X(0)+shift(0),cy+rad*g.disk_radius/(g.radius||1));ctx.stroke()}
    if(g.type==='absorber'){ctx.fillStyle='#16262e';ctx.fillRect(X(0)+45,35,w-X(0)-45,h-70);ctx.strokeStyle='#e3bf71';ctx.lineWidth=5;ctx.beginPath();ctx.moveTo(X(0)+45,35);ctx.lineTo(X(0)+45,h-35);ctx.stroke();if(g.wall){ctx.beginPath();ctx.moveTo(X(0),35);ctx.lineTo(X(0),h-35);ctx.stroke()}}
    ctx.fillStyle='#e3eef2';ctx.font='12px system-ui';ctx.fillText(g.type==='membrane'?'Мембрана в x = 0 · изгиб увеличен · груз '+g.mass_g.toFixed(2)+' г':'Полость '+(g.depth*1000).toFixed(0)+' мм · глубина на схеме увеличена',18,48);
  }else if(g.type==='helmholtz'){
    const n=c.internal_count,band=cnChannelBox(c,h),pitch=X(g.positions[1])-X(g.positions[0]),half=pitch*.37;
    const cavity=(j,x,y,width,height,neckBottom)=>{
      const color=cnWaveColor((g.open?c.motion[frame*n+j]:0)/cnMotionLimit);
      ctx.fillStyle=`rgb(${color.join(',')})`;ctx.fillRect(x-width/2,y,width,height);
      ctx.strokeStyle='#b9d3dd';ctx.lineWidth=1.3;ctx.strokeRect(x-width/2,y,width,height);
      for(const side of [-1,1]){ctx.beginPath();ctx.moveTo(x+side*width*.12,y+height);ctx.lineTo(x+side*width*.12,neckBottom);ctx.stroke()}
      if(!g.open){ctx.strokeStyle='#ffcf78';ctx.lineWidth=3;ctx.beginPath();ctx.moveTo(x-width*.2,neckBottom-3);ctx.lineTo(x+width*.2,neckBottom-3);ctx.stroke()}
    };
    // The small cavities are located at their true x coordinates. The inset is
    // explicitly a magnified circuit element, not a fictitious 2D fluid field.
    for(let j=0;j<g.positions.length;j++)cavity(j,X(g.positions[j]),band.top-55,half*2,27,band.top);
    ctx.strokeStyle='#b9d3dd';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(42,band.top+band.height);ctx.lineTo(w-16,band.top+band.height);ctx.stroke();
    let cursor=42;for(const x of g.positions.map(X)){ctx.beginPath();ctx.moveTo(cursor,band.top);ctx.lineTo(x-half*.24,band.top);ctx.stroke();cursor=x+half*.24}ctx.beginPath();ctx.moveTo(cursor,band.top);ctx.lineTo(w-16,band.top);ctx.stroke();
    const j=Math.floor(n/2),ix=w*.77;cavity(j,ix,74,70,55,174);
    ctx.strokeStyle='#829ca8';ctx.setLineDash([3,4]);ctx.beginPath();ctx.moveTo(X(g.positions[j]),band.top-57);ctx.lineTo(ix-40,103);ctx.stroke();ctx.setLineDash([]);
    ctx.fillStyle='#dceaf0';ctx.font='12px system-ui';ctx.fillText('Одна полость, увеличено',ix-88,61);ctx.fillText('горловина',ix-110,157);ctx.fillText(g.open?'открыта':'закрыта',ix+15,169);ctx.fillText('канал с водой',52,band.top+band.height+18);ctx.fillText('падающая волна →',52,band.top-15);
    ctx.fillText('Давление в полостях · отдельная шкала под картами',42,29);
  }else if(g.type==='prism'){
    ctx.beginPath();[[-.14,-.2],[-.14,.2],[-.14+.4/Math.sqrt(3),.2]].forEach((p,i)=>i?ctx.lineTo(X(p[0]),Y(p[1])):ctx.moveTo(X(p[0]),Y(p[1])));ctx.closePath();ctx.stroke();
    const midpoint=-.14+.2/Math.sqrt(3);ctx.setLineDash([5,5]);ctx.strokeStyle='#ffcf78';ctx.beginPath();ctx.moveTo(X(midpoint-.12*Math.sqrt(3)/2),Y(.06));ctx.lineTo(X(midpoint+.12*Math.sqrt(3)/2),Y(-.06));ctx.stroke();ctx.setLineDash([]);
    ctx.fillStyle='#e3eef2';ctx.font='12px system-ui';ctx.fillText('Заданная эффективная среда · не лабиринт',18,h-13);
  }else if(g.type==='ground'){
    if(g.variant!=='flat'){ctx.fillStyle='#637986';ctx.beginPath();ctx.moveTo(X(-.168),Y(0));ctx.lineTo(X(0),Y(.056));ctx.lineTo(X(.168),Y(0));ctx.closePath();ctx.fill()}
    if(g.variant==='cloak'){ctx.strokeStyle='#e6bf74';ctx.beginPath();ctx.moveTo(X(-.168),Y(0));ctx.lineTo(X(0),Y(.112));ctx.lineTo(X(.168),Y(0));ctx.stroke()}
    ctx.fillStyle='#e3eef2';ctx.font='12px system-ui';ctx.fillText('Жёсткая отражающая поверхность',18,h-13);
  }else if(g.type==='tube'){
    const radius=r=>r/(c.x.at(-1)-c.x[0])*(w-58);const circle=(r,color)=>{ctx.fillStyle=color;ctx.beginPath();ctx.ellipse(X(0),Y(0),radius(r),r/(c.y.at(-1)-c.y[0])*(h-65),0,0,2*Math.PI);ctx.fill()};
    if(g.variant!=='empty'){if(g.variant==='coated')circle(g.outer+g.coating,'#e5b865');circle(g.outer,'#8298a4');circle(g.inner,'#15202c')}
    ctx.fillStyle='#e3eef2';ctx.font='12px system-ui';ctx.fillText(g.variant==='coated'?'Резина · сталь · воздух':g.variant==='bare'?'Сталь · воздух · без резины':'Контроль: только вода',18,h-13);
  }else if(g.type==='solid'){
    ctx.strokeStyle='#9cb4bd';ctx.lineWidth=1;for(const outline of g.outlines){ctx.beginPath();outline.forEach((p,i)=>i?ctx.lineTo(X(p[0]),Y(p[1])):ctx.moveTo(X(p[0]),Y(p[1])));ctx.closePath();ctx.stroke()}
    ctx.setLineDash([5,4]);ctx.strokeStyle='#ecc579';ctx.beginPath();ctx.moveTo(X(g.focus),Y(c.y[0]));ctx.lineTo(X(g.focus),Y(c.y.at(-1)));ctx.stroke();ctx.setLineDash([]);
    ctx.fillStyle='#ecc579';ctx.font='12px system-ui';ctx.fillText('Сечение: x = '+(g.focus*1000).toFixed(1)+' мм',X(g.focus)-85,17);
    ctx.beginPath();ctx.arc(X(g.focus),Y(0),8,0,2*Math.PI);ctx.stroke();
  }
}

function cnField(selector,c){
  const [ctx,w,h]=cnContext(selector),nx=c.x.length,ny=c.y.length,n=nx*ny,frame=cnClosest(c.times,cnCases()[0].times[cnFrame]);
  const left=42,top=24,ww=w-58,hh=h-65,X=x=>left+(x-c.x[0])/(c.x.at(-1)-c.x[0])*ww,Y=y=>top+(c.y.at(-1)-y)/(c.y.at(-1)-c.y[0]||1)*hh;
  ctx.fillStyle='#081820';ctx.fillRect(0,0,w,h);
  const image=new ImageData(nx,ny===1?48:ny);
  const values=cnValues(c),path=cnData.id==='focus'&&cnView==='path',exit=path?cnLensExit(c):0;
  for(let j=0;j<image.height;j++)for(let i=0;i<nx;i++){const row=ny===1?0:ny-1-j,k=i+row*nx;
    const rgb=!c.valid[k]?[64,79,87]:path?(c.x[i]<=exit?[23,42,52]:cnPathColor(c.accumulation[k]/cnPathLimit)):cnWaveColor(values[frame*n+k]/cnLimit),p=4*(i+j*nx);image.data[p]=rgb[0];image.data[p+1]=rgb[1];image.data[p+2]=rgb[2];image.data[p+3]=255}
  const off=document.createElement('canvas');off.width=image.width;off.height=image.height;off.getContext('2d').putImageData(image,0,0);ctx.imageSmoothingEnabled=true;
  const band=ny===1?cnChannelBox(c,h):{top,height:hh};ctx.drawImage(off,left,band.top,ww,band.height);
  cnGeometry(ctx,c,frame,X,Y,w,h);
  const coord=cnCoordinate(c),format=v=>(v*coord.factor).toFixed(coord.factor===1000?0:2);
  ctx.fillStyle='#b8ced8';ctx.font='12px system-ui';for(let i=0;i<=4;i++){const x=c.x[0]+i*(c.x.at(-1)-c.x[0])/4;ctx.textAlign=i===0?'left':i===4?'right':'center';ctx.fillText(format(x),X(x),h-28)}ctx.textAlign='left';ctx.fillText('x, '+coord.unit,w-55,h-13);
  if(ny>1){ctx.fillText('y, '+coord.unit,5,15);for(let i=0;i<=3;i++){const y=c.y[0]+i*(c.y.at(-1)-c.y[0])/3;ctx.fillText(format(y),3,Y(y)+4)}}
  else ctx.fillText('1D: координата y не рассчитывается',42,h-13);
  if(cnPoint&&cnBilinear(c,cnPoint)){const px=X(cnPoint[0]),py=ny===1?band.top+band.height/2:Y(cnPoint[1]);ctx.strokeStyle='#ffda79';ctx.lineWidth=2;ctx.beginPath();ctx.arc(px,py,7,0,2*Math.PI);ctx.moveTo(px-11,py);ctx.lineTo(px+11,py);ctx.moveTo(px,py-11);ctx.lineTo(px,py+11);ctx.stroke()}
}

function cnPlot(selector,series,xlabel,ylabel,marker=null,zero=false,options={}){
  const [ctx,w,h]=cnContext(selector),theme=cnTheme(),L=57,T=24,R=15,B=39;
  cnLegend(selector==='.cn-spectrum'?'.cn-plot-legend':'.cn-trace-legend',series);
  cnGet(selector).ariaLabel=ylabel+'; по горизонтали '+xlabel;
  const xs=series.flatMap(s=>s.x),ys=series.flatMap(s=>s.y).filter(Number.isFinite);
  if(!xs.length||!ys.length){ctx.fillStyle=theme.muted;ctx.font='14px system-ui';ctx.fillText('Нет записи: переставьте датчик в доступную среду.',L,h/2);return}const xmin=Math.min(...xs),xmax=Math.max(...xs);let ymin=Math.min(...ys),ymax=Math.max(...ys);if(zero){ymin=Math.min(0,ymin);ymax=Math.max(0,ymax)}if(ymax===ymin){ymax+=1;ymin-=1}const pad=(ymax-ymin)*.08;ymin-=pad;ymax+=pad;if(options.rangeY)[ymin,ymax]=options.rangeY;
  const axis=cnAxisTicks(ymin,ymax);if(!options.rangeY)[ymin,ymax]=[axis.min,axis.max];
  const X=x=>L+(x-xmin)/(xmax-xmin||1)*(w-L-R),Y=y=>T+(ymax-y)/(ymax-ymin)*(h-T-B);
  if(options.negative&&ymin<0){ctx.fillStyle='#d8994830';ctx.fillRect(L,Y(Math.min(0,ymax)),w-L-R,Y(ymin)-Y(Math.min(0,ymax)))}
  ctx.font='11px system-ui';ctx.fillStyle=theme.muted;ctx.strokeStyle=theme.line;ctx.lineWidth=1;
  for(const y of axis.ticks.filter(y=>y>=ymin&&y<=ymax)){ctx.beginPath();ctx.moveTo(L,Y(y));ctx.lineTo(w-R,Y(y));ctx.stroke();ctx.textAlign='right';ctx.fillText(cnTickLabel(y),L-8,Y(y)+3)}
  for(let i=0;i<=4;i++){const x=xmin+(xmax-xmin)*i/4;ctx.textAlign=i===0?'left':i===4?'right':'center';ctx.fillText(cnTickLabel(x),X(x),h-B+16)}ctx.textAlign='left';
  ctx.fillText(ylabel,L,14);ctx.textAlign='right';ctx.fillText(xlabel,w-R,h-6);ctx.textAlign='left';
  if(zero&&ymin<0&&ymax>0){ctx.setLineDash([4,4]);ctx.beginPath();ctx.moveTo(L,Y(0));ctx.lineTo(w-R,Y(0));ctx.stroke();ctx.setLineDash([])}
  if(options.reference!==undefined&&options.reference>=ymin&&options.reference<=ymax){ctx.strokeStyle='#8ca5ad';ctx.setLineDash([2,5]);ctx.beginPath();ctx.moveTo(L,Y(options.reference));ctx.lineTo(w-R,Y(options.reference));ctx.stroke();ctx.setLineDash([])}
  series.forEach((s,j)=>{ctx.strokeStyle=s.color||cnColors[j%cnColors.length];ctx.lineWidth=2;ctx.beginPath();let pen=false;s.y.forEach((y,i)=>{if(!Number.isFinite(y)){pen=false;return}if(pen)ctx.lineTo(X(s.x[i]),Y(y));else ctx.moveTo(X(s.x[i]),Y(y));pen=true});ctx.stroke()});
  if(marker!==null&&marker>=xmin&&marker<=xmax){ctx.strokeStyle='#d6a13f';ctx.setLineDash([4,4]);ctx.beginPath();ctx.moveTo(X(marker),T);ctx.lineTo(X(marker),h-B);ctx.stroke();ctx.setLineDash([]);
    if(options.dots)for(const [j,s]of series.entries())if(Number.isFinite(s.markerValue)&&s.markerValue>=ymin&&s.markerValue<=ymax){ctx.fillStyle=s.color||cnColors[j%cnColors.length];ctx.beginPath();ctx.arc(X(marker),Y(s.markerValue),4.5,0,Math.PI*2);ctx.fill()}
  }
  if(options.widthSpan){const {left,right,half}=options.widthSpan,y=Y(half);ctx.strokeStyle='#bc923f';ctx.fillStyle='#bc923f';ctx.lineWidth=1.5;ctx.beginPath();ctx.moveTo(X(left),y);ctx.lineTo(X(right),y);for(const x of [left,right]){ctx.moveTo(X(x),y-5);ctx.lineTo(X(x),y+5)}ctx.stroke();ctx.textAlign='center';ctx.fillText((right-left).toFixed(1)+' мм',(X(left)+X(right))/2,y-8);ctx.textAlign='left'}
}

function cnFrequencyPlot(){
  const p=cnData.plot,id=cnData.id,cases=cnCases(),frequency=cnData.sets[cnSet].frequency;
  const factor=Math.max(...(p.x||p.series[0].x))>=2000?.001:1;
  let series=p.series.map((s,i)=>({...s,x:(s.x||p.x).map(x=>x*factor),color:i===cnActive?cnColors[1]:cnColors[0]}));
  let ylabel=p.ylabel,options={negative:['mass','bulk','prism'].includes(id),dots:true};
  if(id==='mass'){
    ylabel='Re σeff, кг/м²';series.forEach((s,i)=>s.markerValue=cases[i].diagnostics.surface_mass_real_kg_m2);
  }else if(id==='bulk'){
    ylabel='Re K / Kводы, без единиц';options.reference=1;series.forEach((s,i)=>s.markerValue=cases[i].diagnostics.bulk_modulus_real_Pa/2.1904e9);
  }else if(id==='prism'){
    ylabel='Re ρ/ρ₀ = Re β/β₀, без единиц';options.reference=1;
    series=[{name:'Обычная призма',x:series[0].x,y:series[0].x.map(()=>1.5),markerValue:1.5,color:cnColors[0]},
      {...series[0],name:'Метасреда: инерция и сжимаемость',markerValue:cases[1].diagnostics.relative_density_real,color:cnActive===1?cnColors[1]:cnColors[2]}];
  }else if(id==='absorber'){
    ylabel='Поглощённая мощность, %';options.rangeY=[0,105];
    series=series.map((s,i)=>({...s,y:s.y.map(v=>v*100),markerValue:cases[i+1].diagnostics.absorption*100,color:i+1===cnActive?cnColors[1]:cnColors[(i+2)%cnColors.length]}));
    if(cnActive===0)series.unshift({name:'Выбрана жёсткая стенка',x:series[0].x,y:series[0].x.map(()=>0),markerValue:0,color:cnColors[1]});
  }
  cnPlot('.cn-spectrum',series,'Частота f, '+(factor===1?'Гц':'кГц'),ylabel,frequency*factor,p.zero,options);
}

function cnProfileSpan(series){
  const y=series.y,x=series.x,peak=Math.max(...y),i=y.indexOf(peak),half=peak/2;
  if(!(peak>0)||i===0||i===y.length-1)return null;
  let l=i,r=i;while(l>0&&y[l]>=half)l--;while(r<y.length-1&&y[r]>=half)r++;
  if(y[l]>=half||y[r]>=half)return null;
  const cross=(a,b)=>x[a]+(half-y[a])/(y[b]-y[a])*(x[b]-x[a]);
  return {left:cross(l,l+1),right:cross(r-1,r),half};
}
function cnProfileWidth(series){const span=cnProfileSpan(series);return span?(span.right-span.left)*1000:null}
function cnReading(){
  const d=cnCases()[cnActive].diagnostics,f=cnFrequency(cnData.sets[cnSet].frequency),id=cnData.id;
  let text='';
  if(id==='mass'){const value=d.surface_mass_real_kg_m2;text='На '+f+': '+cnFormat(value)+' kg/m². '+(value<0?'Ускорение и толчок колеблются в противофазе.':'Синфазная часть отклика положительна.')}
  if(id==='bulk'){const value=d.bulk_modulus_real_Pa/2.1904e9;text='На '+f+': модуль / модуль воды = '+cnFormat(value)+'. '+(value<0?'Давление и среднее сжатие колеблются в противофазе.':'Положительный отклик; у обычной воды это отношение равно 1.')}
  if(id==='prism')text='На '+f+': инерция / инерция воздуха = сжимаемость / сжимаемость воздуха = '+cnFormat(d.relative_density_real)+'. Это заданные свойства выбранной призмы.';
  if(id==='absorber'){const depth=cnCases()[cnActive].geometry.depth,lambda=343/cnData.sets[cnSet].frequency;text='На '+f+' выбранный образец поглощает '+(d.absorption*100).toFixed(1)+'% мощности синусоидальной волны. Полость '+(depth*1000).toFixed(0)+' мм при длине волны '+(lambda*1000).toFixed(0)+' мм: около λ/'+(lambda/depth).toFixed(0)+'. Это размеры нашего образца, не реплика статьи.'}
  if(id==='focus'){const s=cnData.profile.series[cnActive],width=cnProfileWidth(s);text='Жёлтая скоба — ширина выбранного пика на половине его высоты: '+(width===null?'не определяется в пределах линии':width.toFixed(1)+' мм')+'. 100% — один общий максимум среди образцов; каждый профиль не растянут до 100% отдельно.'}
  cnGet('.cn-reading').textContent=text;cnGet('.cn-reading').hidden=!text;
}

function cnUpdateProbe(){
  cnSignals=[cnReference(),cnActive].map((index,j)=>({index,name:(j===0?'Контроль · ':'Выбран · ')+cnCases()[index].name,values:cnTrace(cnCases()[index],cnPoint,cnValues(cnCases()[index])),color:cnColors[j]}));
  const valid=cnSignals.every(s=>s.values),coord=cnCoordinate(cnCases()[0]),format=v=>(v*coord.factor).toFixed(coord.factor===1000?1:3);cnGet('.cn-probe').textContent=valid?'Датчик: x = '+format(cnPoint[0])+(cnCases()[0].y.length>1?', y = '+format(cnPoint[1]):'')+' '+coord.unit+' · серый: контроль, зелёный: выбранный образец':'В этой точке нет измеряемой среды в одном из образцов. Нажмите в свободную область.';
}
function cnDraw(){
  if(cnDisposed||!cnReady||!cnCases()[0].samples)return;
  const cases=cnCases(),time=cases[0].times[cnFrame];cnField('.cn-control',cases[cnReference()]);cnField('.cn-selected',cases[cnActive]);
  cnGet('.cn-clock').textContent=cnView==='path'?'Вся запись · '+cnTime(cases[0].times.at(-1)):cnTime(time);cnGet('.cn-time').value=cnFrame;
  const factor=cases[0].times.at(-1)>.01?1000:1e6,unit=factor===1000?'мс':'мкс';
  cnPlot('.cn-trace',cnSignals.filter(s=>s.values).map(s=>({name:s.name,x:cases[s.index].times.map(t=>t*factor),y:s.values,color:s.color})),'Время t, '+unit,cnData.id==='focus'?'Смещение uᵧ, нм':cnEcho?'Эхо pₛ, Па':'Давление p, Па',cnView==='path'?null:time*factor,true);
  if(cnData.plot)cnFrequencyPlot();
  else if(cnData.id==='cloak'){
    const p=cnSignals.every(s=>s.values)?cnSignals:[];cnPlot('.cn-spectrum',p.map(s=>({name:cases[s.index].name,x:cases[s.index].times.map(t=>t*factor),y:s.values.map((v,i)=>v-cnSignals[0].values[i]),color:s.color})),'Время t, '+unit,'Разность давлений Δp, Па',time*factor,true);
  }else if(cnData.id==='focus'&&cnData.profile){const maximum=Math.max(...cnData.profile.series.flatMap(s=>s.y)),series=cnData.profile.series.map((s,i)=>({...s,x:s.x.map(v=>v*1000),y:s.y.map(v=>100*v/maximum),color:i===0?cnColors[0]:i===cnActive?cnColors[1]:cnColors[2]}));cnPlot('.cn-spectrum',series,'Координата y, мм','Q(y) / Qmax профилей, %',null,true,{rangeY:[0,105],widthSpan:cnProfileSpan(series[cnActive])})}
}
function cnShowStats(){
  const d=cnCases()[cnActive].diagnostics,stats=[];
  stats.push(['Несущая импульса',cnFrequency(cnData.sets[cnSet].frequency)]);
  if('surface_mass_real_kg_m2'in d&&cnData.id==='mass')stats.push(['Эффективная масса площади',cnFormat(d.surface_mass_real_kg_m2)+' kg/m²']);
  if('bulk_modulus_real_Pa'in d)stats.push(['Модуль относительно воды',cnFormat(d.bulk_modulus_real_Pa/2.1904e9)]);
  if('absorption'in d&&cnData.id==='absorber'){stats.push(['Поглощение на несущей',(100*d.absorption).toFixed(1)+' %']);stats.push(['Отражение на несущей',(100*d.reflectance).toFixed(1)+' %'])}
  if('relative_density_real'in d)stats.push(['Инерция и сжимаемость / воздух',cnFormat(d.relative_density_real)]);
  if('external_field_error_ratio'in d)stats.push(['Ошибка поля с плащом / без плаща',cnFormat(d.external_field_error_ratio)]);
  if(cnData.id==='focus'){const width=cnProfileWidth(cnData.profile.series[cnActive]);stats.push(['Ширина пятна на половине высоты',width===null?'Не определена':width.toFixed(1)+' мм'])}
  cnGet('.cn-stats').replaceChildren(...stats.map(([name,value])=>{const el=document.createElement('div');el.className='cn-stat';const small=document.createElement('small'),b=document.createElement('strong');small.textContent=name;b.textContent=value;el.append(small,b);return el}));
  cnGet('.cn-diagnostics').textContent=JSON.stringify({model:cnData.model,source_digest:cnData.source_digest,cases:cnCases().map(c=>({name:c.name,nx:c.x.length,ny:c.y.length,measurement_step_s:c.times[1]-c.times[0],...c.diagnostics}))},null,2);
}
const cnLesson=()=>cnData.lessons[cnCases()[0].geometry.type==='tube'?'tube':'main'];
function cnShowLesson(){
  const lesson=cnLesson();
  for(const [selector,key]of [['.cn-lesson-title','title'],['.cn-mechanism','mechanism'],['.cn-symbols','symbols'],['.cn-lesson-boundary','boundary']])cnGet(selector).textContent=lesson[key];
  cnGet('.cn-watch').replaceChildren(...lesson.watch.map(text=>{const li=document.createElement('li');li.textContent=text;return li}));
  // Plain Unicode equations render offline, without a remote typesetter or
  // interpreting lesson prose as HTML. All symbols are explained underneath.
  cnGet('.cn-equations').replaceChildren(...lesson.equations.map(text=>{const el=document.createElement('div');el.className='cn-equation';el.textContent=text;return el}));
  if(lesson.chart){cnGet('.cn-plot-title').textContent=lesson.chart.title;cnGet('.cn-explanation').textContent=lesson.chart.explanation}
}
function cnChooseCase(i){if(!cnReady)return;cnStop();cnActive=i;cnGet('.cn-selected-name').textContent=cnCases()[i].name;cnGet('.cn-cases').querySelectorAll('button').forEach((b,j)=>b.classList.toggle('active',i===j));cnGet('.cn-case-note').textContent=cnLesson().cases[i];cnShowFieldGuide();cnUpdateProbe();cnShowStats();cnReading();cnDraw()}
async function cnChooseSet(i){
  cnStop();cnView='wave';cnReady=false;const token=++cnLoadVersion;cnSet=i;cnFrame=0;cnGet('.cn-error').textContent='';
  cnGet('.cn-play').disabled=true;cnGet('.cn-time').disabled=true;cnGet('.cn-cases').querySelectorAll('button').forEach(b=>b.disabled=true);
  try{
    const cases=cnCases();await Promise.all(cases.map(async c=>{if(!c.samples){[c.samples,c.motion,c.echo]=await Promise.all([cnDecode(c.values),cnDecode(c.internal),c.scattered?cnDecode(c.scattered):null]);if(c.samples.length!==c.x.length*c.y.length*c.times.length)throw new Error('Неверный размер истории')}}));
    if(cnDisposed||token!==cnLoadVersion)return;cnEcho=cases.every(c=>c.echo);cnGet('.cn-echo-control').hidden=!cnEcho;cnGet('.cn-echo').checked=cnEcho;cnRecomputeLimits();
    const set=cnData.sets[i];for(const [selector,key]of [['.cn-title','title'],['.cn-model','model'],['.cn-bound','limit'],['.cn-question','question'],['.cn-instruction','instruction']])cnGet(selector).textContent=set[key]||cnData[key];cnGet('.cn-paper').textContent=set.source||cnData.source;cnGet('.cn-paper').href=set.url||cnData.url;
    cnShowLesson();
    cnShowFieldGuide();cnGet('.cn-focus-controls').hidden=cnData.id!=='focus';cnGet('.cn-view-wave').classList.toggle('active',true);cnGet('.cn-view-path').classList.toggle('active',false);
    cnGet('.cn-probe-help').textContent=cases[0].y.length===1?'Нажмите на цветной канал, чтобы поставить датчик.'+(cases[0].geometry.type==='helmholtz'?' Увеличенная полость — поясняющая схема.':''):'Нажмите на карту, чтобы поставить датчик.';
    for(const selector of ['.cn-control','.cn-selected']){const c=cases[0],canvas=cnGet(selector);canvas.height=c.y.length===1?360:Math.round(65+(c.y.at(-1)-c.y[0])/(c.x.at(-1)-c.x[0])*(canvas.width-58))}
    cnGet('.cn-frequency').querySelectorAll('button').forEach((b,j)=>b.classList.toggle('active',i===j));
    cnGet('.cn-control-name').textContent='Контроль · '+cases[cnReference()].name;
    cnGet('.cn-cases').replaceChildren(...cases.map((c,j)=>{const b=document.createElement('button');b.type='button';b.textContent=c.name;b.onclick=()=>cnChooseCase(j);return b}));
    cnGet('.cn-time').max=cases[0].times.length-1;
    cnPoint=cnData.id==='absorber'?[-.4,0]:cnData.id==='cloak'?(cnEcho?[.015,.008]:[.15,.26]):cnData.id==='prism'?[.4,0]:cnData.id==='focus'?[cases[0].geometry.focus,0]:[cases[0].x.at(-1)*.65,0];
    cnReady=true;cnChooseCase(Math.min(cnActive,cases.length-1));cnGet('.cn-play').disabled=false;cnGet('.cn-time').disabled=false;
  }catch(err){cnGet('.cn-error').textContent='Не удалось открыть готовые данные: '+err.message}
}
cnData.sets.forEach((s,i)=>{const b=document.createElement('button');b.type='button';b.textContent=s.label+' · '+cnFrequency(s.frequency);b.onclick=()=>cnChooseSet(i);cnGet('.cn-frequency').append(b)});
cnGet('.cn-frequency').hidden=cnData.sets.length<2;
function cnRecomputeLimits(){cnLimit=0;cnMotionLimit=0;cnPathLimit=0;cnCases().forEach(c=>{for(const v of cnValues(c))cnLimit=Math.max(cnLimit,Math.abs(v));for(const v of c.motion)cnMotionLimit=Math.max(cnMotionLimit,Math.abs(v));if(cnData.id==='focus'){c.accumulation??=cnAccumulation(c);const exit=cnLensExit(c);for(let k=0;k<c.accumulation.length;k++)if(c.valid[k]&&c.x[k%c.x.length]>exit+.005)cnPathLimit=Math.max(cnPathLimit,c.accumulation[k])}});cnLimit=cnLimit||1;cnMotionLimit=cnMotionLimit||1;cnPathLimit=cnPathLimit||1}
function cnSetView(view){if(!cnReady)return;cnStop();cnView=view;cnGet('.cn-time').disabled=view==='path';cnGet('.cn-view-wave').classList.toggle('active',view==='wave');cnGet('.cn-view-path').classList.toggle('active',view==='path');cnShowFieldGuide();cnStop();cnDraw()}
cnGet('.cn-view-wave').onclick=()=>cnSetView('wave');cnGet('.cn-view-path').onclick=()=>cnSetView('path');
cnGet('.cn-focus-jump').onclick=()=>{if(!cnReady)return;cnSetView('wave');cnStop();cnFrame=cnFocusFrame(cnCases().at(-1));cnDraw()};
cnGet('.cn-echo').onchange=e=>{if(!cnReady)return;cnEcho=e.target.checked;cnRecomputeLimits();cnShowFieldGuide();cnUpdateProbe();cnShowStats();cnDraw()};
function cnTick(now){if(!cnPlaying||cnDisposed)return;if(!cnStart)cnStart=now;const total=cnCases()[0].times.length-1;cnFrame=Math.min(total,cnStartFrame+Math.floor((now-cnStart)/8000*total));cnDraw();if(cnFrame===total)cnStop();else cnRaf=requestAnimationFrame(cnTick)}
cnGet('.cn-play').onclick=()=>{if(!cnReady)return;if(cnPlaying){cnStop();return}if(cnView==='path'){cnSetView('wave');cnFrame=0}if(cnFrame>=cnCases()[0].times.length-1)cnFrame=0;cnStartFrame=cnFrame;cnStart=0;cnPlaying=true;cnGet('.cn-play').textContent='❚❚ Пауза';cnRaf=requestAnimationFrame(cnTick)};
cnGet('.cn-reset').onclick=()=>{if(!cnReady)return;cnSetView('wave');cnFrame=0;cnDraw()};cnGet('.cn-time').oninput=e=>{if(!cnReady||cnView==='path')return;cnStop();cnFrame=+e.target.value;cnDraw()};
for(const selector of ['.cn-control','.cn-selected'])cnGet(selector).onclick=e=>{if(!cnReady)return;const c=cnCases()[selector==='.cn-control'?cnReference():cnActive],canvas=e.currentTarget,rect=canvas.getBoundingClientRect(),point=cnProbePoint(c,canvas.width,canvas.height,(e.clientX-rect.left)/rect.width*canvas.width,(e.clientY-rect.top)/rect.height*canvas.height);if(!point)return;cnPoint=point;cnUpdateProbe();cnDraw()};
if(typeof invalidation!=='undefined')invalidation.then(()=>{cnDisposed=true;cnStop()});
cnChooseSet(cnData.sets.length>1&&['mass','bulk'].includes(cnData.id)?1:0);
