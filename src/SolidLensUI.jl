module SolidLensUI

using MetaNDT, JSON
export cached_design, cached_solid, cached_pulse, lens_view, pulse_view, comparison_cases

struct LabHTML
    source::String
end
Base.show(io::IO,::MIME"text/html",x::LabHTML)=print(io,x.source)

const DESIGNS=Dict{String,LensDesign}()
const FIELDS=Dict{String,SolidLensResult}()
const PULSES=Dict{String,SolidPulseResult}()
const FIELD_GRID_SCRIPT=read(joinpath(@__DIR__,"assets","field-grid.js"),String)

function cached_design(s=SolidLensExperiment())
    key=experiment_toml(s)
    get!(DESIGNS,key) do
        length(DESIGNS)>=2 && empty!(DESIGNS)
        design_stg_lens(s)
    end
end

function cached_solid(s)
    key=experiment_toml(s)
    get!(FIELDS,key) do
        length(FIELDS)>=12 && empty!(FIELDS)
        simulate(s)
    end
end

function cached_pulse(s)
    key=experiment_toml(s)
    get!(PULSES,key) do
        empty!(PULSES)
        simulate_pulse(s)
    end
end

"""Same excitation, selected geometry plus bulk, equal-mass and uniform controls."""
function comparison_cases(d,id;frequency=d.experiment.frequency,polarization=d.experiment.polarization)
    selected=solid_preset(d,id;frequency,polarization)
    uniform=remake_experiment(solid_preset(d,:uniform;frequency,polarization);
        missing_cells=selected.missing_cells)
    cases=[("1 · Сплошное тело",remake_experiment(selected;scenario=:solid,missing_cells=Int[])),
        ("2 · Прямые перемычки",straight_reference(selected)),
        ("3 · Одинаковые STG",uniform)]
    if id in (:missing,:scrambled)
        push!(cases,("4 · Полная STG-линза",solid_preset(d,:focused;frequency,polarization)))
    end
    push!(cases,(only(filter(e->e.id==id,solid_examples())).title,selected))
    results=SolidLensResult[]; labels=String[]
    seen=Set{String}()
    for (label,s) in cases
        key=experiment_toml(s)
        key in seen && continue
        push!(seen,key); push!(results,cached_solid(s))
        push!(labels,label)
    end
    (;results,labels,selected=findfirst(r->experiment_toml(r.experiment)==
        experiment_toml(selected),results))
end

function field_payload(r,name)
    s=r.experiment
    Dict("name"=>name,"xy"=>[round.(r.nodes[:,i]*1000;digits=6) for i in axes(r.nodes,2)],
        "tri"=>[r.triangles[:,i].-1 for i in axes(r.triangles,2)],
        "ur"=>real.(r.displacement_x),"ui"=>imag.(r.displacement_x),
        "vr"=>real.(r.displacement_y),"vi"=>imag.(r.displacement_y),
        "outlines"=>s.scenario==:solid ? [] : [[collect(p).*1000 for p in outline]
            for outline in solid_lens_outlines(s)],
        "profile"=>r.profile_kinetic/max(r.diagnostics["input_power_W_m"],eps()),
        "scanX"=>r.scan_x*1000,"scanWidth"=>r.scan_fwhm*1000,"diag"=>r.diagnostics)
end

function lens_view(c)
    results=c.results; s=results[c.selected].experiment
    payload=Dict("cases"=>[field_payload(r,n) for (r,n) in zip(results,c.labels)],
        "selected"=>c.selected-1,"width"=>s.width*1000,"height"=>s.height*1000,
        "length"=>first(s.bricks).length*1000,"source"=>s.source_x*1000,
        "focus"=>(first(s.bricks).length/2+s.focus_distance)*1000,
        "y"=>results[1].profile_y*1000,"density"=>s.density,"frequency"=>s.frequency,
        "polarization"=>String(s.polarization))
    data=replace(JSON.json(payload),"<"=>"\\u003c")
    html=raw"""
    <section class="solid-lab" id="solid-lens-view">
    <style>
    main{max-width:1120px!important}
    .solid-lab{--fg:light-dark(#142a3d,#e1ebf3);--muted:light-dark(#51677b,#a8bacb);--bg:light-dark(#f0f5f9,#10212e);--panel:light-dark(#fff,#172c3b);--line:light-dark(#c4d3df,#3b5365);color:var(--fg);background:var(--bg);border-radius:16px;padding:22px;font:15px/1.5 system-ui; color-scheme:light dark}
    .solid-lab *{box-sizing:border-box}.solid-lab h2,.solid-lab h3{font-family:system-ui;color:var(--fg);margin:0 0 8px}.solid-lab h2{font-size:23px}.solid-lab h3{font-size:17px}.solid-lab p{color:var(--muted);margin:8px 0}
    .solid-lab button,.solid-lab select{font:inherit;color:var(--fg);background:var(--panel);border:1px solid var(--line);border-radius:7px;padding:7px 10px}.solid-lab button.active{border-color:#31aeaa;background:light-dark(#d3f1ed,#21514f)}
    .solid-lab .toolbar{display:flex;gap:9px;align-items:center;flex-wrap:wrap;margin:14px 0}.solid-lab canvas{width:100%;height:auto;display:block;border-radius:7px;background:var(--panel)}.solid-lab .field{aspect-ratio:1.75}.solid-lab .chart{aspect-ratio:2.3}
    .solid-lab .charts{display:grid;grid-template-columns:1fr 1fr;gap:18px;margin:22px 0}.solid-lab .legend{display:flex;gap:12px;flex-wrap:wrap;color:var(--muted);font-size:13px}.solid-lab .legend i{display:inline-block;width:18px;height:3px;margin-right:5px;vertical-align:middle}.solid-lab .stats{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}.solid-lab .stats p{border:1px solid var(--line);border-radius:8px;padding:12px}.solid-lab .stats strong{display:block;color:var(--fg);font-size:21px}.solid-lab .diagnostics{white-space:pre-line;font-size:13px}.solid-lab details{margin-top:15px}
    @media(max-width:700px){.solid-lab .charts{grid-template-columns:1fr}.solid-lab .stats{grid-template-columns:1fr}.solid-lab{padding:12px}}
    </style>
    <h2>Собирает ли STG-стенка волну?</h2>
    <p>Слева и справа — сплошной алюминий. Между ними — соединённые по торцам перемычки. Тёмные вырезы — пустота, а не вода. Жёлтая линия — заранее выбранное сечение сравнения.</p>
    <div class="toolbar cases" aria-label="Сравнить расчётные конструкции"></div>
    <div class="toolbar"><label>Поле <select class="mode"><option value="energy">Средняя кинетическая энергия / принятая мощность</option><option value="wave">Вертикальное смещение · гармонический режим</option></select></label><button class="play" type="button">▶ Изменять фазу</button><label>Фаза <input class="phase" type="range" min="0" max="360" value="0"></label></div>
    <canvas class="field" aria-label="Поле в соединённом алюминиевом теле со свободными вырезами"></canvas>
    <p class="scale"></p>
    <p>Это стационарный FEM-расчёт. Изменение фазы показывает колебание уже установившегося поля, <em>не приход импульса</em>. Настоящий короткий импульс можно рассчитать ниже.</p>
    <div class="stats" aria-live="polite"></div>
    <div class="charts">
      <div><h3>Поперечный профиль за стенкой</h3><canvas class="chart profile" aria-label="Сравнение обработанных профилей энергии на общей шкале"></canvas><p>Общая шкала, без независимого нормирования пиков. FWHM — ширина главного пика на половине его высоты, не разрешение дефектоскопа.</p></div>
      <div><h3>Где пучок сужается и расширяется?</h3><canvas class="chart widths" aria-label="Ширина главного пика в сечениях за стенкой"></canvas><p>Пунктир — целевое сечение. При смене самого сильного лепестка FWHM может скачкообразно измениться: смотрите также карту поля.</p></div>
    </div>
    <div class="legend"></div>
    <details><summary>Что именно посчитано и насколько аккуратно?</summary><p class="diagnostics"></p><p>Полная кинетическая энергия включает обе компоненты смещения; это не выделенная SV-мощность и не коэффициент передачи. Локальное внешнее поглощающее условие приближённое. Материальных потерь нет.</p></details>
    <script>
    __FIELD_GRID__
    const root=document.getElementById('solid-lens-view'), data=__DATA__, get=s=>root.querySelector(s);
    const colors=['#8196aa','#de9036','#aa7ccc','#24b6a9','#e8737d'], cache=new Map();
    let active=data.selected,phase=0,mode='energy',playing=false,raf=0,last=0;
    const Emax=Math.max(...data.cases.flatMap(c=>c.profile))*1.5;
    const Umax=Math.sqrt(4*Emax/(data.density*(2*Math.PI*data.frequency)**2));
    const probe=document.createElement('span');probe.hidden=true;root.append(probe);
    const theme=()=>{probe.style.color='var(--muted)';const muted=getComputedStyle(probe).color;probe.style.color='var(--line)';return{fg:getComputedStyle(root).color,muted,line:getComputedStyle(probe).color}};
    function context(canvas){const box=canvas.getBoundingClientRect(),dpr=devicePixelRatio||1;canvas.width=Math.round(box.width*dpr);canvas.height=Math.round(box.height*dpr);const ctx=canvas.getContext('2d');ctx.scale(dpr,dpr);return[ctx,box.width,box.height]}
    data.cases.forEach((c,i)=>{const b=document.createElement('button');b.type='button';b.textContent=c.name;b.dataset.case=i;b.onclick=()=>{active=i;draw()};get('.cases').append(b);const span=document.createElement('span'),line=document.createElement('i');line.style.background=colors[i];span.append(line,document.createTextNode(c.name));get('.legend').append(span)});
    function raster(c,w,h,X,Y,key){if(!cache.has(key))cache.set(key,makeTriangleRaster(c,w,h,X,Y));return cache.get(key)}
    function field(){const c=data.cases[active],[ctx,w,h]=context(get('.field')),t=theme(),scale=Math.min((w-64)/data.width,(h-56)/data.height),X=x=>w/2+x*scale,Y=y=>h/2-y*scale;
      ctx.fillStyle='#071620';ctx.fillRect(0,0,w,h);const r=raster(c,w,h,X,Y,active+':'+w+':'+h),pixels=r.image.data,P=Math.max(c.diag.input_power_W_m,Number.EPSILON),factor=1/Math.sqrt(P),cs=Math.cos(phase*Math.PI/180),sn=Math.sin(phase*Math.PI/180);
      for(let j=0;j<r.a.length;j++){if(r.a[j]<0)continue;const a=r.a[j],b=r.b[j],d=r.d[j],u=r.u[j],v=r.v[j],q=1-u-v,interp=arr=>q*arr[a]+u*arr[b]+v*arr[d],ur=interp(c.ur),ui=interp(c.ui),vr=interp(c.vr),vi=interp(c.vi);let rgb;
        if(mode==='energy'){const E=.25*data.density*(2*Math.PI*data.frequency)**2*(ur*ur+ui*ui+vr*vr+vi*vi)/P,z=Math.min(1,E/Emax);rgb=[24+231*z,52+157*Math.sqrt(z),74-27*z]}else{const z=Math.max(-1,Math.min(1,(vr*cs+vi*sn)*factor/Umax)),m=Math.abs(z);rgb=[225+(z<0?-190:-8)*m,234+(z<0?-120:-155)*m,240+(z<0?-45:-176)*m]}
        const k=4*j;pixels[k]=rgb[0];pixels[k+1]=rgb[1];pixels[k+2]=rgb[2];pixels[k+3]=255}
      r.oc.putImageData(r.image,0,0);ctx.drawImage(r.off,0,0,w,h);ctx.strokeStyle='#b6c8d4';ctx.lineWidth=.8;
      for(const p of c.outlines){ctx.beginPath();p.forEach((q,i)=>{const next=p[(i+1)%p.length];if(Math.abs(q[0]-next[0])<1e-8&&Math.abs(Math.abs(q[0])-data.length/2)<1e-6){ctx.moveTo(X(next[0]),Y(next[1]));return}if(i===0)ctx.moveTo(X(q[0]),Y(q[1]));ctx.lineTo(X(next[0]),Y(next[1]))});ctx.stroke()}
      ctx.setLineDash([6,4]);ctx.strokeStyle='#ffda70';ctx.beginPath();ctx.moveTo(X(data.focus),Y(data.height/2));ctx.lineTo(X(data.focus),Y(-data.height/2));ctx.stroke();ctx.setLineDash([]);
      ctx.strokeStyle='#ff85ab';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(X(data.source),Y(.37*data.height));ctx.lineTo(X(data.source),Y(-.37*data.height));ctx.stroke();ctx.fillStyle='#e7eef4';ctx.font='12px system-ui';ctx.fillText('источник',X(data.source)-27,Y(data.height/2)-8);ctx.fillText(c.outlines.length?'стенка':'сплошное тело',X(0)-32,Y(data.height/2)-8);ctx.fillStyle='#ffda70';ctx.fillText('сравниваем здесь',X(data.focus)-50,Y(-data.height/2)-8);ctx.fillStyle='#e7eef4';ctx.fillText('x, mm',w-48,h-5);for(const x of [-80,-40,0,40,80])ctx.fillText(x,X(x)-9,Y(-data.height/2)+17);ctx.fillText('y, mm',8,17);for(const y of [-40,-20,0,20,40])ctx.fillText(y,X(-data.width/2)-27,Y(y)+4);
      get('.scale').textContent=mode==='energy'?'Цвет: 0 → '+Emax.toExponential(2)+' s/m² · средняя кинетическая энергия / принятая мощность. Значения выше шкалы насыщены.':'Цвет: ±'+Umax.toExponential(2)+' m / √(W/m) · uᵧ / √принятой мощности; общая шкала всех случаев.';
    }
    function chart(canvas,series,xlabel,ylabel,xrange,yrange,marker){const[ctx,w,h]=context(canvas),t=theme(),L=60,R=14,T=25,B=38,X=x=>L+(x-xrange[0])/(xrange[1]-xrange[0])*(w-L-R),Y=y=>T+(yrange[1]-y)/(yrange[1]-yrange[0])*(h-T-B);ctx.font='11px system-ui';ctx.fillStyle=t.muted;ctx.strokeStyle=t.line;ctx.lineWidth=1;
      for(let i=0;i<=4;i++){const x=xrange[0]+i*(xrange[1]-xrange[0])/4,y=yrange[0]+i*(yrange[1]-yrange[0])/4;ctx.beginPath();ctx.moveTo(X(x),T);ctx.lineTo(X(x),h-B);ctx.moveTo(L,Y(y));ctx.lineTo(w-R,Y(y));ctx.stroke();ctx.fillText(x.toFixed(0),X(x)-10,h-B+17);ctx.fillText(yrange[1]<.1?y.toExponential(1):y.toFixed(0),4,Y(y)+4)}
      ctx.fillText(ylabel,L,14);ctx.fillText(xlabel,w-56,h-5);if(marker!==undefined){ctx.setLineDash([5,4]);ctx.strokeStyle='#caa134';ctx.beginPath();ctx.moveTo(X(marker),T);ctx.lineTo(X(marker),h-B);ctx.stroke();ctx.setLineDash([])}
      series.forEach(s=>{ctx.strokeStyle=s.color;ctx.lineWidth=s.index===active?3:1.7;ctx.beginPath();let pen=false;s.y.forEach((y,i)=>{if(!Number.isFinite(y)){pen=false;return}if(pen)ctx.lineTo(X(s.x[i]),Y(y));else ctx.moveTo(X(s.x[i]),Y(y));pen=true});ctx.stroke()})}
    function draw(){field();root.querySelectorAll('[data-case]').forEach(b=>b.classList.toggle('active',+b.dataset.case===active));const c=data.cases[active],d=c.diag;get('.stats').innerHTML='';[['Ширина пика FWHM',Number.isFinite(d.profile_fwhm_m)?(d.profile_fwhm_m*1000).toFixed(1)+' mm':'не помещается в сечение'],['Положение пика y',(d.profile_peak_y_m*1000).toFixed(1)+' mm'],['Пик / принятая мощность',d.profile_peak_per_input_power.toExponential(2)+' s/m²']].forEach(([label,value])=>{const p=document.createElement('p'),b=document.createElement('strong');p.textContent=label;b.textContent=value;p.append(b);get('.stats').append(p)});
      chart(get('.profile'),data.cases.map((c,i)=>({x:data.y,y:c.profile,color:colors[i],index:i})),'y, mm','⟨K⟩ / P, s/m²',[data.y[0],data.y.at(-1)],[0,Emax/1.5*1.1]);const widths=data.cases.flatMap(c=>c.scanWidth.filter(Number.isFinite));chart(get('.widths'),data.cases.map((c,i)=>({x:c.scanX,y:c.scanWidth,color:colors[i],index:i})),'x, mm','FWHM, mm',[data.cases[0].scanX[0],data.cases[0].scanX.at(-1)],[0,Math.max(10,...widths)*1.05],data.focus);
      get('.diagnostics').textContent=c.name+' · '+data.frequency/1000+' kHz · '+data.polarization+'-возбуждение\n'+Math.round(d.dofs)+' степеней свободы · площадь '+(d.solid_area_m2*1e6).toFixed(1)+' mm²\nПринятая мощность '+d.input_power_W_m.toExponential(3)+' W/m · ушедшая '+d.outgoing_power_W_m.toExponential(3)+' W/m\nБаланс мощности '+d.power_balance_relative.toExponential(2)+' · невязка линейной системы '+d.linear_residual_relative.toExponential(2)+'\nРасчёт '+d.total_seconds.toFixed(2)+' s. Прямой контроль сохраняет массу каждой перемычки; одинаковые STG — отдельная, не равно-массовая проверка фазовой расстановки.'}
    function stop(){playing=false;cancelAnimationFrame(raf);get('.play').textContent='▶ Изменять фазу'}
    function tick(now){if(!playing)return;if(now-last>45){phase=(phase+9)%360;get('.phase').value=phase;last=now;draw()}raf=requestAnimationFrame(tick)}
    get('.play').onclick=()=>{if(playing){stop();return}mode='wave';get('.mode').value=mode;playing=true;get('.play').textContent='❚❚ Пауза';raf=requestAnimationFrame(tick)};get('.phase').oninput=e=>{phase=+e.target.value;draw()};get('.mode').onchange=e=>{stop();mode=e.target.value;draw()};const resize=new ResizeObserver(draw);resize.observe(root);draw();if(typeof invalidation!=='undefined')invalidation.then(()=>{stop();resize.disconnect()});
    </script></section>
    """
    LabHTML(replace(html,"__DATA__"=>data,"__FIELD_GRID__"=>FIELD_GRID_SCRIPT))
end

function pulse_view(r::SolidPulseResult)
    # Plain computed nodal snapshots; no propagation animation manufactured in JS.
    s=r.experiment
    payload=Dict("xy"=>[r.nodes[:,i]*1000 for i in axes(r.nodes,2)],
        "tri"=>[r.triangles[:,i].-1 for i in axes(r.triangles,2)],
        "frames"=>r.frame_times*1e6,"uy"=>[r.displacement_y[:,i] for i in axes(r.displacement_y,2)],
        "width"=>s.width*1000,"height"=>s.height*1000,
        "source"=>s.source_x*1000,"focus"=>(first(s.bricks).length/2+s.focus_distance)*1000,
        "profileWidth"=>MetaNDT.profile_width(r.profile_y,r.profile_integrated_kinetic)*1000,
        "balance"=>r.diagnostics["energy_balance_relative"])
    data=replace(JSON.json(payload),"<"=>"\\u003c")
    # Reuse the same mesh-to-pixel sampler, but a genuinely transient field.
    base=raw"""
    <section id="solid-pulse-view" style="padding:20px;border:1px solid #7893a966;border-radius:12px">
    <h3>Настоящий короткий импульс в выбранной конструкции</h3>
    <p>Каждый кадр — шаг временного FEM (Newmark), а не перемотка гармонической фазы. Цвет — вертикальное смещение; шкала общая для всех кадров.</p>
    <canvas style="display:block;width:100%;aspect-ratio:1.75" aria-label="Временное распространение упругого импульса"></canvas>
    <p><button type="button">▶ Воспроизвести</button> <input type="range" min="0" value="0" aria-label="Время импульса"><output></output></p>
    <p class="balance"></p>
    <script>
    __FIELD_GRID__
    const root=document.getElementById('solid-pulse-view'),data=__DATA__,canvas=root.querySelector('canvas'),slider=root.querySelector('input'),button=root.querySelector('button');slider.max=data.frames.length-1;
    let frame=0,playing=false,raf=0,last=0,raster=null;let limit=0;for(const f of data.uy)for(const u of f)limit=Math.max(limit,Math.abs(u));limit=Math.max(limit,Number.EPSILON);
    function draw(){const box=canvas.getBoundingClientRect(),w=Math.ceil(box.width),h=Math.ceil(box.height);canvas.width=w;canvas.height=h;const ctx=canvas.getContext('2d'),scale=Math.min((w-30)/data.width,(h-30)/data.height),X=x=>w/2+x*scale,Y=y=>h/2-y*scale;
      if(!raster||raster.w!==w||raster.h!==h)raster=makeTriangleRaster(data,w,h,X,Y);
      const r=raster,p=r.image.data,f=data.uy[frame];for(let j=0;j<r.a.length;j++){const k=4*j;if(r.a[j]<0){p[k]=7;p[k+1]=22;p[k+2]=32;p[k+3]=255;continue}const z=Math.max(-1,Math.min(1,((1-r.u[j]-r.v[j])*f[r.a[j]]+r.u[j]*f[r.b[j]]+r.v[j]*f[r.d[j]])/limit)),m=Math.abs(z);p[k]=225+(z<0?-190:-8)*m;p[k+1]=234+(z<0?-120:-155)*m;p[k+2]=240+(z<0?-45:-176)*m;p[k+3]=255}ctx.putImageData(r.image,0,0);ctx.setLineDash([5,4]);ctx.strokeStyle='#c99b23';ctx.beginPath();ctx.moveTo(X(data.focus),Y(data.height/2));ctx.lineTo(X(data.focus),Y(-data.height/2));ctx.stroke();ctx.setLineDash([]);ctx.fillStyle='#a23967';ctx.font='12px system-ui';ctx.fillText('источник',X(data.source)-25,12);ctx.fillStyle='#c99b23';ctx.fillText('сечение',X(data.focus)-22,12);slider.value=frame;root.querySelector('output').textContent=data.frames[frame].toFixed(1)+' μs';root.querySelector('.balance').textContent='Общая шкала ±'+(limit*1e9).toFixed(3)+' nm · относительный дисбаланс энергии '+data.balance.toExponential(2)+' · FWHM профиля кинетической энергии, интегрированной по импульсу: '+(Number.isFinite(data.profileWidth)?data.profileWidth.toFixed(1)+' mm':'не определена')}
    function stop(){playing=false;cancelAnimationFrame(raf);button.textContent='▶ Воспроизвести'}function tick(now){if(!playing)return;if(now-last>75){frame++;last=now;if(frame>=data.frames.length){frame=data.frames.length-1;stop()}draw()}if(playing)raf=requestAnimationFrame(tick)}button.onclick=()=>{if(playing){stop();return}if(frame===data.frames.length-1)frame=0;playing=true;button.textContent='❚❚ Пауза';raf=requestAnimationFrame(tick)};slider.oninput=e=>{stop();frame=+e.target.value;draw()};const resize=new ResizeObserver(draw);resize.observe(root);draw();if(typeof invalidation!=='undefined')invalidation.then(()=>{stop();resize.disconnect()});
    </script></section>
    """
    LabHTML(replace(base,"__DATA__"=>data,"__FIELD_GRID__"=>FIELD_GRID_SCRIPT))
end

end
