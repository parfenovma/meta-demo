module CylinderUI

using MetaNDT, JSON
export comparison_view, cached_comparison, cached_frequency_sweep, frequency_view,
       cached_example_comparison

const CACHE=Dict{String,Vector{CylinderResult}}()
const SWEEP_CACHE=Dict{String,FrequencySweepResult}()
const REFERENCE_CACHE=Dict{String,CylinderResult}()

function cached_comparison(s)
    key=experiment_toml(s)
    if !haskey(CACHE,key)
        length(CACHE)>=3 && empty!(CACHE)
        CACHE[key]=simulate_comparison(s)
    end
    CACHE[key]
end

function cached_example_comparison(id,s)
    results=cached_comparison(s)
    reference=example_reference(id,results[3].experiment)
    isnothing(reference) && return results
    key=experiment_toml(reference)
    if !haskey(REFERENCE_CACHE,key)
        length(REFERENCE_CACHE)>=3 && empty!(REFERENCE_CACHE)
        REFERENCE_CACHE[key]=simulate(reference)
    end
    vcat(results,[REFERENCE_CACHE[key]])
end

function cached_frequency_sweep(s,frequencies; sensor=1,time_window=(0.0,s.duration),
                                include_straight_reference=false)
    f=Float64.(collect(frequencies))
    key=experiment_toml(s)*repr((f,sensor,time_window,include_straight_reference))
    if !haskey(SWEEP_CACHE,key)
        length(SWEEP_CACHE)>=2 && empty!(SWEEP_CACHE)
        SWEEP_CACHE[key]=frequency_sweep(s,f; sensor,time_window,include_straight_reference)
    end
    SWEEP_CACHE[key]
end

struct LabHTML
    source::String
end
Base.show(io::IO,::MIME"text/html",x::LabHTML)=print(io,x.source)

function comparison_view(results;labels=nothing)
    names=Dict(:empty=>"Пустая вода",:rigid=>"Жёсткий образец",:elastic=>"Упругий образец")
    s=results[3].experiment
    names=isnothing(labels) ? [names[r.experiment.scenario] for r in results] : labels
    length(names) == length(results) || throw(ArgumentError("one label required per result"))
    cases=[Dict(
        "name"=>names[j],"case"=>String(r.experiment.scenario),
        "outlines"=>[[collect(p).*1000 for p in outline] for outline in specimen_outlines(r.experiment)],
        "motionScale"=>MetaNDT.specimen_min_thickness(r.experiment)*500,
        "xy"=>[collect(r.fluid_nodes[:,i]*1000) for i in axes(r.fluid_nodes,2)],
        "tri"=>[collect(r.fluid_triangles[:,i].-1) for i in axes(r.fluid_triangles,2)],
        "p"=>[round.(r.pressure[:,i];digits=3) for i in axes(r.pressure,2)],
        "sx"=>[collect(r.solid_nodes[:,i]*1000) for i in axes(r.solid_nodes,2)],
        "st"=>[collect(r.solid_triangles[:,i].-1) for i in axes(r.solid_triangles,2)],
        "ux"=>[round.(r.displacement_x[:,i]*1e9;digits=4) for i in axes(r.displacement_x,2)],
        "uy"=>[round.(r.displacement_y[:,i]*1e9;digits=4) for i in axes(r.displacement_y,2)],
        "signals"=>[collect(r.sensor_pressure[i,:]) for i in axes(r.sensor_pressure,1)],
        "energy"=>r.energy,"solidEnergy"=>r.solid_energy,"work"=>r.input_work,
        "outgoing"=>r.absorbed_energy,"diagnostics"=>r.diagnostics,
    ) for (j,r) in enumerate(results)]
    data=replace(JSON.json(Dict("cases"=>cases,"times"=>results[end].times*1e6,
        "frames"=>results[end].frame_times*1e6,"radius"=>s.radius*1000,
        "centers"=>collect.(s.centers).*1000,
        "width"=>s.width*1000,"height"=>s.height*1000,
        "source"=>collect(s.source).*1000,"sensors"=>collect.(s.sensors).*1000)),"<"=>"\\u003c")
    html=raw"""
    <section id="cylinder-lab-view" class="cylinder-lab">
      <style>
      main {max-width:1100px!important}
      .cylinder-lab {color-scheme:light dark;--bg:light-dark(#f5f7fb,#101b27);--fg:light-dark(#182432,#e4edf4);--muted:light-dark(#546578,#a7b8c8);--line:light-dark(#cad5e0,#35465a);--panel:light-dark(#fff,#172534);color:var(--fg);background:var(--bg);padding:22px;border-radius:16px;font:15px/1.5 system-ui,sans-serif}
      .cylinder-lab * {box-sizing:border-box}
      .cylinder-lab h2,.cylinder-lab h3 {margin:0 0 8px;color:var(--fg);font-family:system-ui,sans-serif}
      .cylinder-lab h2 {font-size:24px}.cylinder-lab h3{font-size:17px}
      .cylinder-lab p{margin:6px 0;color:var(--muted)}
      .cylinder-lab .toolbar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin:16px 0}
      .cylinder-lab button,.cylinder-lab select{color:var(--fg);background:var(--panel);border:1px solid var(--line);border-radius:7px;padding:7px 11px;font:inherit}
      .cylinder-lab button.active{background:light-dark(#d8e9f8,#284e70);border-color:light-dark(#6195c0,#659ecc)}
      .cylinder-lab .case-buttons{display:flex;gap:6px;flex-wrap:wrap}
      .cylinder-lab .playback input{flex:1;min-width:100px}
      .cylinder-lab .playback output{min-width:90px;font-variant-numeric:tabular-nums}
      .cylinder-lab .field-grid{display:grid;grid-template-columns:minmax(0,2.2fr) minmax(180px,1fr);gap:20px}
      .cylinder-lab canvas{display:block;width:100%;height:auto;background:var(--panel);border:1px solid var(--line);border-radius:8px}
      .cylinder-lab .field{aspect-ratio:1.6}.cylinder-lab .solid{aspect-ratio:1}
      .cylinder-lab .chart{aspect-ratio:2.9}
      .cylinder-lab .legend{display:flex;gap:16px;flex-wrap:wrap;font-size:13px;color:var(--muted);margin:8px 0}
      .cylinder-lab .legend i{display:inline-block;width:20px;height:3px;margin-right:5px;vertical-align:middle}
      .cylinder-lab .plots{display:grid;gap:20px;margin-top:22px}
      .cylinder-lab .scale{display:flex;gap:10px;align-items:center;font-size:13px;color:var(--muted);margin:8px 0}
      .cylinder-lab .gradient{height:10px;width:120px;background:linear-gradient(90deg,#2867bd,#e6eef5,#ce4844);border-radius:4px}
      .cylinder-lab details{margin-top:20px}.cylinder-lab summary{cursor:pointer;color:var(--fg)}
      .cylinder-lab .diagnostics{white-space:pre-line;font-size:13px;font-variant-numeric:tabular-nums;color:var(--muted)}
      @media(max-width:650px){.cylinder-lab{padding:14px}.cylinder-lab .field-grid{grid-template-columns:1fr}.cylinder-lab .solid{max-width:330px}.cylinder-lab .chart{aspect-ratio:1.8}}
      </style>
      <h2>Как образец меняет волну?</h2>
      <p>Выберите случай, запустите воспроизведение или перемотайте время. Все кадры — результат временного FEM-расчёта.</p>
      <div class="toolbar case-buttons" aria-label="Показываемый эксперимент">
        <button type="button" data-case="0">Пустая вода</button><button type="button" data-case="1">Жёсткий</button><button type="button" data-case="2" class="active">Упругий</button>
      </div>
      <div class="field-grid">
        <div><h3>Давление в воде</h3><canvas class="field" aria-label="Расчётное поле давления, источник и три датчика"></canvas>
          <div class="scale"><span class="low"></span><span class="gradient"></span><span class="high"></span><span>общая шкала, Pa</span></div>
          <p style="font-size:13px">✚ Источник · A, B, C — датчики. Синий: разрежение; красный: сжатие. Цвет насыщается на границах шкалы.</p>
        </div>
        <div><h3>Движение включений</h3><canvas class="solid" aria-label="Расчётная деформация включений с явно подписанным увеличением"></canvas>
          <p class="motion" aria-live="polite"></p><p style="font-size:13px">Пунктир — исходная граница. Стрелки — смещение. Синий/красный цвет — вертикальная компонента смещения.</p>
        </div>
      </div>
      <div class="toolbar playback"><button type="button" class="play">▶ Воспроизвести</button><label for="lab-frame">Время</label><input id="lab-frame" type="range" min="0" value="35" step="1"><output class="time"></output></div>
      <div class="plots">
        <div><div class="toolbar"><h3 style="margin:0">Что услышал датчик?</h3><label>Датчик <select class="sensor"><option value="0">A</option><option value="1">B</option><option value="2">C</option></select></label><label>Показать <select class="signal-mode"><option value="total">Полный сигнал</option><option value="scattered">Вклад образца</option></select></label></div>
          <canvas class="chart signal" aria-label="Сравнение временных сигналов давления трёх экспериментов"></canvas>
          <div class="legend signal-legend"></div>
        </div>
        <div><h3>Энергия воды и включений</h3><canvas class="chart energy" aria-label="Полная энергия, энергия твёрдых тел и уход энергии через внешнюю границу"></canvas>
          <div class="legend"><span><i style="background:#38a6a0"></i>Внутри области</span><span><i style="background:#b482d1"></i>Во включениях</span><span><i style="background:#db8c36"></i>Ушла через границу</span></div>
        </div>
      </div>
      <details><summary>Параметры и проверка расчёта</summary><p class="diagnostics"></p></details>
      <script>
      const root=document.getElementById("cylinder-lab-view"), data=__DATA__;
      const get=s=>root.querySelector(s), colors=['#82909d','#db8c36','#38a6a0','#b482d1'], rasters=new Map();
      data.cases.slice(3).forEach((c,j)=>{const b=document.createElement('button');b.type='button';b.dataset.case=j+3;get('.case-buttons').append(b)});
      root.querySelectorAll('[data-case]').forEach(b=>b.textContent=data.cases[+b.dataset.case].name);
      data.cases.forEach((c,i)=>{const span=document.createElement('span'),line=document.createElement('i');line.style.background=colors[i];span.append(line,document.createTextNode(c.name));get('.signal-legend').append(span)});
      let active=2,frame=35,sensor=0,signalMode='total',playing=false,raf=0,last=0;
      const slider=get('#lab-frame');slider.max=data.frames.length-1;frame=Math.min(frame,data.frames.length-1);
      const pmax=Math.max(...data.cases.flatMap(c=>c.signals.flatMap(x=>x.map(Math.abs))));
      const limit=Math.max(1,2*pmax), elastic=data.cases[2];
      let maxmotion=0;for(const c of data.cases)for(let k=0;k<c.ux.length;k++)for(let i=0;i<c.ux[k].length;i++)maxmotion=Math.max(maxmotion,Math.hypot(c.ux[k][i],c.uy[k][i]));
      const magnify=maxmotion>0?0.12*elastic.motionScale/(maxmotion*1e-6):1;
      get('.low').textContent=(-limit).toFixed(0);get('.high').textContent=limit.toFixed(0);
      function context(canvas){const box=canvas.getBoundingClientRect(),dpr=window.devicePixelRatio||1;canvas.width=Math.round(box.width*dpr);canvas.height=Math.round(box.height*dpr);const ctx=canvas.getContext('2d');ctx.scale(dpr,dpr);return [ctx,box.width,box.height]}
      const colorProbe=document.createElement('span');colorProbe.hidden=true;root.append(colorProbe);
      function resolved(token){colorProbe.style.color='var('+token+')';return getComputedStyle(colorProbe).color}
      function theme(){return {fg:getComputedStyle(root).color,muted:resolved('--muted'),line:resolved('--line')}}
      function polygon(ctx,points,fill,stroke){ctx.beginPath();points.forEach((p,i)=>i?ctx.lineTo(...p):ctx.moveTo(...p));ctx.closePath();if(fill){ctx.fillStyle=fill;ctx.fill()}if(stroke){ctx.strokeStyle=stroke;ctx.stroke()}}
      function drawField(){const c=data.cases[active],[ctx,w,h]=context(get('.field')),t=theme(),pad=30;
        const scale=Math.min((w-2*pad)/data.width,(h-2*pad)/data.height),X=x=>w/2+x*scale,Y=y=>h/2-y*scale;
        const W=Math.ceil(w),H=Math.ceil(h),key=active+':'+W+':'+H;
        if(!rasters.has(key)){
          const a=new Int32Array(W*H).fill(-1),b=new Int32Array(W*H),d=new Int32Array(W*H),u=new Float32Array(W*H),v=new Float32Array(W*H);
          for(const tri of c.tri){const p=tri.map(i=>[X(c.xy[i][0]),Y(c.xy[i][1])]),ax=p[0][0],ay=p[0][1],bx=p[1][0]-ax,by=p[1][1]-ay,dx=p[2][0]-ax,dy=p[2][1]-ay,det=bx*dy-by*dx;
            const xmin=Math.max(0,Math.floor(Math.min(...p.map(q=>q[0])))),xmax=Math.min(W-1,Math.ceil(Math.max(...p.map(q=>q[0])))),ymin=Math.max(0,Math.floor(Math.min(...p.map(q=>q[1])))),ymax=Math.min(H-1,Math.ceil(Math.max(...p.map(q=>q[1]))));
            for(let y=ymin;y<=ymax;y++)for(let x=xmin;x<=xmax;x++){const px=x+.5-ax,py=y+.5-ay,s=(px*dy-py*dx)/det,t=(bx*py-by*px)/det;if(s>=-1e-6&&t>=-1e-6&&s+t<=1.000001){const i=y*W+x;a[i]=tri[0];b[i]=tri[1];d[i]=tri[2];u[i]=s;v[i]=t}}
          }
          const off=document.createElement('canvas');off.width=W;off.height=H;const oc=off.getContext('2d');rasters.set(key,{a,b,d,u,v,off,oc,image:oc.createImageData(W,H)});
        }
        const r=rasters.get(key),pixels=r.image.data,pressure=c.p[frame];
        for(let i=0;i<r.a.length;i++){if(r.a[i]<0)continue;const value=(1-r.u[i]-r.v[i])*pressure[r.a[i]]+r.u[i]*pressure[r.b[i]]+r.v[i]*pressure[r.d[i]],z=Math.max(-1,Math.min(1,value/limit)),m=Math.abs(z),j=4*i;pixels[j]=230+(z<0?-190:-24)*m;pixels[j+1]=238+(z<0?-135:-166)*m;pixels[j+2]=245+(z<0?-56:-177)*m;pixels[j+3]=255}
        r.oc.putImageData(r.image,0,0);ctx.drawImage(r.off,0,0,w,h);
        ctx.strokeStyle=t.line;ctx.strokeRect(X(-data.width/2),Y(data.height/2),scale*data.width,scale*data.height);
        if(c.case!=='empty')for(const outline of c.outlines)polygon(ctx,outline.map(p=>[X(p[0]),Y(p[1])]),'#6b8296','#21394e');
        ctx.font='13px system-ui';ctx.fillStyle=t.fg;ctx.fillText('x, mm',w-45,h-7);ctx.fillText('y, mm',8,16);
        for(const x of [-60,-30,0,30,60])ctx.fillText(x.toString(),X(x)-8,Y(-data.height/2)+18);
        ctx.strokeStyle='#873f88';ctx.lineWidth=2;let x=X(data.source[0]),y=Y(data.source[1]);ctx.beginPath();ctx.moveTo(x-6,y);ctx.lineTo(x+6,y);ctx.moveTo(x,y-6);ctx.lineTo(x,y+6);ctx.stroke();
        data.sensors.forEach((p,i)=>{const x=X(p[0]),y=Y(p[1]);ctx.fillStyle='#122d31';ctx.fillRect(x-4,y-4,8,8);ctx.fillText('ABC'[i],x+8,y-7)});
      }
      function drawSolid(){const c=data.cases[active],[ctx,w,h]=context(get('.solid')),t=theme();let extent=0;for(const outline of data.cases.flatMap(c=>c.outlines))for(const p of outline)extent=Math.max(extent,Math.abs(p[0]),Math.abs(p[1]));const scale=Math.min(w,h)/(2.9*extent),X=x=>w/2+x*scale,Y=y=>h/2-y*scale;
        ctx.setLineDash([5,4]);ctx.strokeStyle=t.muted;for(const outline of c.outlines)polygon(ctx,outline.map(p=>[X(p[0]),Y(p[1])]),null,t.muted);ctx.setLineDash([]);
        if(c.case==='elastic'){const dx=c.ux[frame],dy=c.uy[frame];for(const tri of c.st){const mean=tri.reduce((s,i)=>s+dy[i],0)/3;const z=mean/(maxmotion||1);const v=Math.abs(z),base=[126,153,174],target=z<0?[44,112,200]:[214,93,89];const fill='rgb('+base.map((x,i)=>Math.round(x+(target[i]-x)*v)).join(',')+')';polygon(ctx,tri.map(i=>[X(c.sx[i][0]+dx[i]*1e-6*magnify),Y(c.sx[i][1]+dy[i]*1e-6*magnify)]),fill,'#405b7044')}
          const stride=Math.max(1,Math.floor(c.sx.length/25));ctx.strokeStyle=t.fg;ctx.lineWidth=1.1;for(let i=0;i<c.sx.length;i+=stride){const x=X(c.sx[i][0]),y=Y(c.sx[i][1]),ex=X(c.sx[i][0]+dx[i]*1e-6*magnify),ey=Y(c.sx[i][1]+dy[i]*1e-6*magnify);ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(ex,ey);ctx.stroke();}
          let peak=0;for(let i=0;i<dx.length;i++)peak=Math.max(peak,Math.hypot(dx[i],dy[i]));get('.motion').textContent='Смещение сейчас: '+peak.toFixed(2)+' nm · увеличение ×'+Math.round(magnify).toLocaleString();
        }else{ctx.font='14px system-ui';ctx.fillStyle=t.fg;ctx.textAlign='center';ctx.fillText(active===0?'Цилиндра нет':'Смещение равно нулю',w/2,h/2);ctx.textAlign='start';get('.motion').textContent=active===0?'Контроль: только вода.':'Контроль: жёсткая неподвижная граница.';}
      }
      function chart(canvas,series,ylabel,nonnegative=false){const [ctx,w,h]=context(canvas),t=theme(),left=65,right=16,top=18,bottom=36;
        let peak=0;series.forEach(s=>s.values.forEach(v=>peak=Math.max(peak,Math.abs(v))));peak=peak||1;const ymin=nonnegative?0:-1.12*peak,ymax=1.12*peak;
        const X=x=>left+x/data.times[data.times.length-1]*(w-left-right),Y=y=>top+(ymax-y)/(ymax-ymin)*(h-top-bottom);
        ctx.font='12px system-ui';ctx.strokeStyle=t.line;ctx.lineWidth=1;ctx.fillStyle=t.muted;
        for(let i=0;i<=4;i++){const x=i*data.times[data.times.length-1]/4;ctx.beginPath();ctx.moveTo(X(x),top);ctx.lineTo(X(x),h-bottom);ctx.stroke();ctx.fillText(x.toFixed(0),X(x)-9,h-bottom+17)}
        for(let i=0;i<=4;i++){const y=ymin+i*(ymax-ymin)/4;ctx.beginPath();ctx.moveTo(left,Y(y));ctx.lineTo(w-right,Y(y));ctx.stroke();const label=peak<0.01?y.toExponential(1):y.toFixed(0);ctx.fillText(label,4,Y(y)+4)}
        ctx.fillText('t, μs',w-48,h-6);ctx.fillText(ylabel,left,12);
        series.forEach(s=>{ctx.strokeStyle=s.color;ctx.lineWidth=1.7;ctx.beginPath();s.values.forEach((y,i)=>i?ctx.lineTo(X(data.times[i]),Y(y)):ctx.moveTo(X(data.times[i]),Y(y)));ctx.stroke()});
        ctx.strokeStyle=t.fg;ctx.setLineDash([4,4]);ctx.beginPath();ctx.moveTo(X(data.frames[frame]),top);ctx.lineTo(X(data.frames[frame]),h-bottom);ctx.stroke();ctx.setLineDash([]);
      }
      function draw(){slider.value=frame;get('.time').textContent=data.frames[frame].toFixed(1)+' μs';drawField();drawSolid();chart(get('.signal'),data.cases.map((c,i)=>({values:signalMode==='total'?c.signals[sensor]:c.signals[sensor].map((p,j)=>p-data.cases[0].signals[sensor][j]),color:colors[i]})),signalMode==='total'?'p, Pa':'Δp, Pa');const c=data.cases[active];chart(get('.energy'),[{values:c.energy,color:'#38a6a0'},{values:c.solidEnergy,color:'#b482d1'},{values:c.outgoing,color:'#db8c36'}],'E, J/m',true);
        root.querySelectorAll('[data-case]').forEach(b=>b.classList.toggle('active',+b.dataset.case===active));
        const d=c.diagnostics;get('.diagnostics').textContent=c.name+' · включений: '+d.inclusion_count+' · '+Math.round(d.dofs)+' степеней свободы\nСборка: '+d.assembly_seconds.toFixed(2)+' s · временной цикл: '+d.time_loop_seconds.toFixed(2)+' s\nШаг: '+(d.time_step_s*1e6).toFixed(3)+' μs · баланс энергии: '+d.energy_balance_relative.toExponential(2)+'\nМаксимальное смещение за опыт: '+(d.peak_displacement_m*1e9).toFixed(3)+' nm\n2D, плоская деформация. На внешней границе — локальное поглощающее условие первого порядка.';
      }
      function stop(){playing=false;get('.play').textContent='▶ Воспроизвести';cancelAnimationFrame(raf)}
      function tick(now){if(!playing)return;if(now-last>65){frame++;last=now;if(frame>=data.frames.length){frame=data.frames.length-1;stop()}draw()}if(playing)raf=requestAnimationFrame(tick)}
      get('.play').onclick=()=>{if(playing){stop();return}if(frame===data.frames.length-1)frame=0;playing=true;last=0;get('.play').textContent='❚❚ Пауза';raf=requestAnimationFrame(tick)};
      slider.oninput=()=>{stop();frame=+slider.value;draw()};get('.sensor').onchange=e=>{sensor=+e.target.value;draw()};get('.signal-mode').onchange=e=>{signalMode=e.target.value;draw()};root.querySelectorAll('[data-case]').forEach(b=>b.onclick=()=>{active=+b.dataset.case;draw()});
      const resize=new ResizeObserver(()=>draw());resize.observe(root);draw();
      if(typeof invalidation!=='undefined')invalidation.then(()=>{stop();resize.disconnect()});
      </script>
    </section>
    """
    LabHTML(replace(html,"__DATA__"=>data))
end

function frequency_view(r::FrequencySweepResult)
    frequencies=r.frequencies./1000
    lo,hi=extrema(frequencies)
    ymax=max(1.2,1.1maximum(r.ratios))
    X(f)=70+(f-lo)/max(hi-lo,1)*690
    Y(value)=240-value/ymax*210
    io=IOBuffer()
    print(io,"<section class='frequency-sweep' style='padding:20px;border:1px solid #82909d66;border-radius:12px'><h2>Что дошло до датчика на разных частотах?</h2>")
    print(io,"<p>Датчик $(r.sensor) · окно $(round(r.time_window[1]*1e6;digits=1))–$(round(r.time_window[2]*1e6;digits=1)) μs. 1 = норма сигнала в пустой воде.</p>")
    print(io,"<svg viewBox='0 0 820 290' role='img' aria-label='Отношение норм давления к пустой воде по частоте' style='width:100%;font:13px system-ui;fill:currentColor'>")
    for i in 0:4
        value=i*ymax/4; y=Y(value)
        print(io,"<path d='M70 $y H760' stroke='#82909d44'/><text x='8' y='$(y+4)'>$(round(value;digits=2))</text>")
    end
    for f in frequencies
        x=X(f)
        print(io,"<path d='M$x 30 V240' stroke='#82909d33'/><text x='$(x-12)' y='263'>$(round(f;digits=1))</text>")
    end
    print(io,"<text x='70' y='18'>‖p‖ / ‖p пустой воды‖</text><text x='700' y='282'>f, kHz</text>")
    colors=("#82909d","#db8c36","#38a6a0","#b482d1")
    for i in axes(r.ratios,1)
        points=join(["$(X(frequencies[j])),$(Y(r.ratios[i,j]))" for j in eachindex(frequencies)]," ")
        print(io,"<polyline points='$points' fill='none' stroke='$(colors[i])' stroke-width='2'/>")
        for j in eachindex(frequencies)
            print(io,"<circle cx='$(X(frequencies[j]))' cy='$(Y(r.ratios[i,j]))' r='4' fill='$(colors[i])'/>")
        end
    end
    control=size(r.ratios,1) == 4
    print(io,"</svg><p><span style='color:#82909d'>● Пустая вода</span> · <span style='color:#db8c36'>● Жёсткий образец</span> · <span style='color:#38a6a0'>● Упругий образец</span>")
    control && print(io," · <span style='color:#b482d1'>● Прямой контроль равной массы</span>")
    print(io,"</p><table><thead><tr><th>f, kHz</th><th>Жёсткий / вода</th><th>Упругий / вода</th>")
    control && print(io,"<th>Прямой / вода</th>")
    print(io,"</tr></thead><tbody>")
    for j in eachindex(frequencies)
        print(io,"<tr><td>$(round(frequencies[j];digits=1))</td><td>$(round(r.ratios[2,j];digits=3))</td><td>$(round(r.ratios[3,j];digits=3))</td>")
        control && print(io,"<td>$(round(r.ratios[4,j];digits=3))</td>")
        print(io,"</tr>")
    end
    s=r.comparisons[end][end].experiment
    actual_step=r.comparisons[end][end].diagnostics["time_step_s"]
    residual=maximum(c.diagnostics["energy_balance_relative"] for cases in r.comparisons for c in cases)
    print(io,"</tbody></table><p>Общая сетка всех точек: $(round(s.mesh_size*1000;digits=3)) mm; шаг $(round(actual_step*1e6;digits=3)) μs; максимальный дисбаланс энергии $(round(residual;sigdigits=3)).</p>")
    print(io,"<p><strong>Это отношение норм давления одного датчика, не передача энергии.</strong> Оно может быть больше 1 и зависит от положения датчика и временного окна. Здесь конечные двухпериодные импульсы, а не стационарная характеристика бесконечного материала. Линии соединяют рассчитанные точки; запрещённая полоса этим графиком не доказана.</p></section>")
    LabHTML(String(take!(io)))
end

end
