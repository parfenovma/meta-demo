module CoatedCylinderUI

using MetaNDT, JSON
export cached_coated_comparison, cached_coated_sweep, cloak_view, CoatedControls

struct LabHTML
    source::String
end
Base.show(io::IO,::MIME"text/html",x::LabHTML)=print(io,x.source)

"""A single submitted parameter snapshot; independent of Pluto's widget internals."""
struct CoatedControls
    experiment::CoatedCylinderExperiment
end
Base.get(c::CoatedControls)=Dict("frequency"=>c.experiment.frequency,
    "thickness"=>c.experiment.coating_thickness*1000)

function Base.show(io::IO,::MIME"text/html",c::CoatedControls)
    s=validate_experiment(c.experiment)
    seeds=coated_cavity_resonances(s,5000,60000)
    choices=[Float64(f)=>string(f/1000) for f in 5000:5000:60000]
    !isempty(seeds) && push!(choices,first(seeds)+1.5=>"≈26.899 — резонанс полости")
    any(p->p.first==s.frequency,choices) || push!(choices,s.frequency=>string(s.frequency/1000))
    sort!(choices;by=first)
    options=join(["<option value='$(p.first)' $(p.first==s.frequency ? "selected" : "")>$(p.second)</option>" for p in choices])
    thickness_choices=sort!(unique!(vcat([.8,1.,1.2],[s.coating_thickness*1000])))
    thicknesses=join(["<option value='$t' $(t==s.coating_thickness*1000 ? "selected" : "")>$t mm</option>" for t in thickness_choices])
    initial=JSON.json(Base.get(c))
    html=raw"""
    <form id="coated-controls" style="display:grid;gap:12px">
      <label>Частота, kHz: <select name="frequency">__FREQUENCIES__</select></label>
      <label>Толщина силикона: <select name="thickness">__THICKNESSES__</select></label>
      <p>Три случая и частотный перебор используют одну и ту же трубку и покрытие.
      Расчёт запускается только кнопкой, не при выборе пункта.</p>
      <button type="submit">Рассчитать три случая</button>
      <script>
      const form=document.getElementById('coated-controls');
      let submitted=__INITIAL__;
      const restore=(select,value)=>{
        // Julia renders 1.0; JS String(1.0) is '1'. Match numeric meaning.
        const option=[...select.options].find(o=>Number(o.value)===Number(value));
        if(option)select.value=option.value;
      };
      Object.defineProperty(form,'value',{
        get:()=>submitted,
        set:value=>{if(value){submitted=value;restore(form.elements.frequency,value.frequency);restore(form.elements.thickness,value.thickness)}}
      });
      // Native input can bubble, but editing is not submission.
      form.addEventListener('input',event=>{if(event.target!==form)event.stopPropagation()});
      form.onsubmit=event=>{
        event.preventDefault();
        submitted={frequency:Number(form.elements.frequency.value),thickness:Number(form.elements.thickness.value)};
        form.dispatchEvent(new CustomEvent('input',{bubbles:true}));
      };
      </script>
    </form>
    """
    print(io,replace(html,"__FREQUENCIES__"=>options,"__THICKNESSES__"=>thicknesses,"__INITIAL__"=>initial))
end

const COMPARISONS=Dict{String,Vector{CoatedCylinderResult}}()
const SWEEPS=Dict{String,CoatedCylinderSweep}()

function cached_coated_comparison(s::CoatedCylinderExperiment)
    key=experiment_toml(s)
    get!(COMPARISONS,key) do
        length(COMPARISONS)>=8 && empty!(COMPARISONS)
        coated_comparison(s)
    end
end

function cached_coated_sweep(s::CoatedCylinderExperiment)
    # The frequency slider must not invalidate the same full sweep.
    key=experiment_toml(remake_experiment(s;frequency=10e3))
    get!(SWEEPS,key) do
        length(SWEEPS)>=4 && empty!(SWEEPS)
        coated_frequency_sweep(s,5000:5000:60000;resolve_cavity=true)
    end
end

function field_payload(r,xs)
    s=r.experiment; R=s.outer_radius+(s.scenario == :coated ? s.coating_thickness : 0)
    pressure=ComplexF64[]; scattered=ComplexF64[]
    for y in xs,x in xs
        water=s.scenario == :empty || hypot(x,y) >= R
        push!(pressure,water ? coated_pressure(r,(x,y)) : 0)
        push!(scattered,water ? coated_pressure(r,(x,y);scattered=true) : 0)
    end
    Dict("case"=>String(s.scenario),"real"=>real.(pressure)./s.incident_pressure,
        "imag"=>imag.(pressure)./s.incident_pressure,"scatter"=>abs.(scattered)./s.incident_pressure,
        "angular"=>abs2.(r.far_field_amplitude)./s.incident_pressure^2,
        "width"=>r.scattering_width*1000,"diagnostics"=>r.diagnostics)
end

function cloak_view(c::Vector{CoatedCylinderResult},sweep::CoatedCylinderSweep)
    length(c) == 3 && [r.experiment.scenario for r in c] == [:empty,:bare,:coated] ||
        throw(ArgumentError("expected empty/bare/coated comparison"))
    s=c[3].experiment
    # Every card and line is paired at the same frequency/material/geometry.
    all(experiment_toml(remake_experiment(r.experiment;scenario=:coated)) == experiment_toml(s) for r in c) ||
        throw(ArgumentError("comparison has mismatched physical parameters"))
    all(experiment_toml(remake_experiment(e;frequency=s.frequency,scenario=:coated)) == experiment_toml(s) for e in sweep.experiments) ||
        throw(ArgumentError("sweep belongs to another experiment"))
    xs=collect(range(-.025,.025;length=81))
    payload=Dict("cases"=>[field_payload(r,xs) for r in c],"count"=>length(xs),"extent"=>25,
        "frequency"=>s.frequency/1000,"steelR"=>s.outer_radius*1000,"airR"=>s.inner_radius*1000,
        "coatR"=>(s.outer_radius+s.coating_thickness)*1000,"thickness"=>s.coating_thickness*1000,
        "angle"=>s.incident_angle,"theta"=>c[3].angles,
        "frequencies"=>sweep.frequencies./1000,"ratios"=>sweep.ratio,
        "resonances"=>sweep.cavity_frequencies./1000)
    data=replace(JSON.json(payload),"<"=>"\\u003c")
    html=raw"""
    <section id="cloak-view" class="cloak-lab">
    <style>
    main{max-width:1150px!important}.cloak-lab{--fg:light-dark(#142b3d,#e5eef4);--muted:light-dark(#4c6578,#aac0ce);--bg:light-dark(#f0f5f9,#10212e);--panel:light-dark(#fff,#172c3b);--line:light-dark(#c6d7e1,#3c5465);padding:20px;border-radius:16px;color:var(--fg);background:var(--bg);font:15px/1.5 system-ui;color-scheme:light dark}.cloak-lab *{box-sizing:border-box}.cloak-lab h2,.cloak-lab h3{font-family:system-ui;color:var(--fg);margin:5px 0}.cloak-lab h2{font-size:23px}.cloak-lab h3{font-size:17px}.cloak-lab p{color:var(--muted);margin:8px 0}.cloak-lab canvas{display:block;width:100%;height:auto}.cloak-lab .cases{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}.cloak-lab .case{background:var(--panel);border:1px solid var(--line);padding:12px;border-radius:12px}.cloak-lab .field{aspect-ratio:1}.cloak-lab .charts{display:grid;grid-template-columns:1fr 1fr;gap:22px;margin:22px 0}.cloak-lab .chart{aspect-ratio:1.5}.cloak-lab .toolbar{display:flex;gap:12px;flex-wrap:wrap;align-items:center;margin:12px 0}.cloak-lab select,.cloak-lab button{font:inherit;color:var(--fg);background:var(--panel);padding:6px 9px;border:1px solid var(--line);border-radius:6px}.cloak-lab .result{padding:14px;background:light-dark(#def3eb,#19413a);border-radius:9px;margin:14px 0}.cloak-lab .result strong{font-size:24px;color:var(--fg)}.cloak-lab .legend{display:flex;gap:15px;flex-wrap:wrap}.cloak-lab .legend i{display:inline-block;width:18px;height:3px;vertical-align:middle;margin-right:6px}.cloak-lab .geometry{max-width:480px;aspect-ratio:3}.cloak-lab .diagnostics{white-space:pre-line;font-size:13px}.cloak-lab details{margin-top:12px}
    @media(max-width:650px){.cloak-lab .cases,.cloak-lab .charts{grid-template-columns:1fr}.cloak-lab{padding:12px}.cloak-lab .field{max-width:420px;margin:auto}}
    </style>
    <h2>Может ли мягкое покрытие скрыть трубку от звука?</h2>
    <p>Одна и та же плоская волна идёт слева направо. Сравниваем пустую воду, полую стальную трубку и ту же трубку с прочно соединённым силиконовым покрытием. Полость заполнена воздухом.</p>
    <canvas class="geometry" aria-label="Увеличенное сечение воздушной полости, стальной стенки и силиконового покрытия"></canvas>
    <div class="toolbar"><label>На картах <select class="mode"><option value="scatter">Только рассеянный звук · амплитуда</option><option value="total">Вся волна · мгновенное давление</option></select></label><button type="button" class="play">▶ Колебание фазы</button><label>Фаза <input class="phase" type="range" min="0" max="360" value="0"></label></div>
    <p class="scale"></p>
    <div class="cases">
      <div class="case"><h3>1 · Пустая вода</h3><canvas class="field" aria-label="Давление в пустой воде"></canvas><p class="metric"></p></div>
      <div class="case"><h3>2 · Голая трубка</h3><canvas class="field" aria-label="Рассеяние полой стальной трубки без покрытия"></canvas><p class="metric"></p></div>
      <div class="case"><h3>3 · Трубка + силикон</h3><canvas class="field" aria-label="Рассеяние той же трубки с силиконовым покрытием на общей шкале"></canvas><p class="metric"></p></div>
    </div>
    <div class="result" aria-live="polite"></div>
    <div class="legend"><span><i style="background:#ff9258"></i>Голая трубка</span><span><i style="background:#36bcb1"></i>С покрытием</span></div>
    <div class="charts"><div><h3>Заметность со всех сторон</h3><canvas class="chart angular" aria-label="Угловое распределение рассеяния на общей линейной шкале"></canvas><p>Радиус — |f(θ)|²: рассеяние в данном направлении. Обе кривые на одной шкале; фронт — справа, обратное рассеяние — слева. Не выбираем один удачный микрофон.</p></div><div><h3>Что происходит при смене частоты?</h3><label>Масштаб частот <select class="zoom"><option value="full">Вся полоса 5–60 kHz</option></select></label><canvas class="chart sweep" aria-label="Перебор частоты: отношение полной ширины рассеяния покрытой трубки к голой"></canvas><p>0 dB — покрытие не помогло. Ниже — рассеяния меньше; выше — больше. Кружки — рассчитанные точки, крупная точка — выбранная частота. Геометрия не меняется. Около резонансов воздуха шаг сгущён до 0.5 Hz: там покрытие иногда ухудшает результат. Это конечный перебор, не гарантия отсутствия других узких пиков.</p></div></div>
    <details><summary>Почему это не поглощение и что действительно посчитано?</summary><p>Покрытие меняет отклик объекта и компенсирует его рассеяние. Силикон имеет небольшие сдвиговые потери, но это не «поглотитель, делающий всё невидимым». В библиотеке можно отключить потери и проверить механизм.</p><p>2D, бесконечно длинная труба, плоская деформация. Упругость стали и силикона — смешанный P2/P1 радиальный FEM; вода и воздух — точные цилиндрические акустические моды. Излучение в бесконечную воду, без искусственной внешней границы. Гармоническая фаза — не приход импульса. Кривую получили расчётом, не заданным коэффициентом улучшения.</p><p>Полная ширина рассеяния σ имеет единицы длины и определяется исходящей мощностью / интенсивностью падающей волны, на единицу длины трубы. Отношение покрытой и голой трубки — 10 log₁₀(σпокр / σгол). Это результаты нашей модели, не повторение лабораторных цифр статьи.</p><p class="diagnostics"></p></details>
    <script>
    const root=document.getElementById('cloak-view'),d=__DATA__,get=s=>root.querySelector(s),fields=[...root.querySelectorAll('.field')],colors=['#9aabba','#ff9258','#36bcb1'];
    const ctx=c=>{c.width=600;c.height=400;return c.getContext('2d')};
    // Resolve light-dark colors through DOM computed color, not canvas variables.
    const textColor=()=>getComputedStyle(root).color;
    let phase=0,playing=false,frame=0;
    const scatterMax=Math.max(...d.cases[1].scatter,...d.cases[2].scatter,1e-12),totalMax=Math.max(1,...d.cases.flatMap(c=>c.real.map((x,i)=>Math.hypot(x,c.imag[i]))));
    function circle(g,x,y,r,fill,stroke){g.beginPath();g.arc(x,y,r,0,2*Math.PI);g.fillStyle=fill;g.fill();if(stroke){g.strokeStyle=stroke;g.lineWidth=1.5;g.stroke()}}
    function geometry(){const c=get('.geometry'),g=ctx(c);g.clearRect(0,0,600,400);c.height=200;g.font='18px system-ui';g.fillStyle=textColor();circle(g,95,100,84,'#36bcb1');circle(g,95,100,84*d.steelR/d.coatR,'#9eacb6');circle(g,95,100,84*d.airR/d.coatR,'#142a3b');g.fillStyle=textColor();g.fillText('Воздух внутри · герметичная полость',210,45);g.fillText('Сталь: стенка '+(d.steelR-d.airR).toFixed(3)+' mm',210,91);g.fillStyle='#36bcb1';g.fillText('Силикон: '+d.thickness.toFixed(2)+' mm',210,136);g.fillStyle=textColor();g.fillText('Увеличено · внешняя сталь Ø '+(2*d.steelR).toFixed(1)+' mm',210,181)}
    function drawFields(){const mode=get('.mode').value,cp=Math.cos(phase),sp=Math.sin(phase);fields.forEach((c,j)=>{c.width=400;c.height=400;const g=c.getContext('2d'),a=d.cases[j],N=d.count,image=g.createImageData(N,N);for(let iy=0;iy<N;iy++)for(let ix=0;ix<N;ix++){const id=(N-1-iy)*N+ix,value=mode==='scatter'?a.scatter[id]/scatterMax:(a.real[id]*cp+a.imag[id]*sp)/totalMax,off=4*(iy*N+ix);let rgb;if(mode==='scatter'){const t=Math.max(0,Math.min(1,value));rgb=[12+235*t,30+150*t,45+20*t]}else{const t=Math.min(1,Math.abs(value)),base=[239,244,247],end=value>=0?[245,116,56]:[31,124,208];rgb=base.map((x,i)=>x+(end[i]-x)*t)}image.data[off]=rgb[0];image.data[off+1]=rgb[1];image.data[off+2]=rgb[2];image.data[off+3]=255}const scratch=document.createElement('canvas');scratch.width=N;scratch.height=N;scratch.getContext('2d').putImageData(image,0,0);g.imageSmoothingEnabled=true;g.drawImage(scratch,0,0,400,400);if(a.case!=='empty'){if(a.case==='coated')circle(g,200,200,d.coatR/d.extent*200,'#36bcb1');circle(g,200,200,d.steelR/d.extent*200,'#9eacb6');circle(g,200,200,d.airR/d.extent*200,'#142a3b')}g.fillStyle=mode==='scatter'?'#e5eef4':'#142b3d';g.font='15px system-ui';g.fillText('−25 mm',8,389);g.fillText('+25 mm',322,389);g.fillText('→ падающая волна',10,25);root.querySelectorAll('.metric')[j].textContent='σ = '+a.width.toPrecision(4)+' mm';});get('.scale').textContent=mode==='scatter'?'Общая линейная шкала |pрасс| / pпад: от 0 (тёмный) до '+scatterMax.toPrecision(3)+' (жёлтый). Покрытую трубку не усиливаем ради картинки.':'Общая шкала p / pпад: ±'+totalMax.toFixed(3)+'. Гармоническое колебание установившейся волны, не анимация пролёта импульса.';}
    function angular(){const g=ctx(get('.angular')),cx=300,cy=200,R=155,max=Math.max(...d.cases[1].angular,...d.cases[2].angular,1e-20);g.clearRect(0,0,600,400);g.strokeStyle='#647c8c';g.lineWidth=.7;for(const fraction of [.25,.5,.75,1]){g.beginPath();g.arc(cx,cy,R*fraction,0,2*Math.PI);g.stroke()}g.beginPath();g.moveTo(cx-R,cy);g.lineTo(cx+R,cy);g.moveTo(cx,cy-R);g.lineTo(cx,cy+R);g.stroke();for(const j of [1,2]){g.beginPath();d.theta.forEach((θ,i)=>{const r=R*d.cases[j].angular[i]/max,x=cx+r*Math.cos(θ),y=cy-r*Math.sin(θ);i?g.lineTo(x,y):g.moveTo(x,y)});g.strokeStyle=colors[j];g.lineWidth=3;g.stroke()}g.fillStyle=textColor();g.font='17px system-ui';g.fillText('назад',60,205);g.fillText('вперёд',475,205);g.font='14px system-ui';g.fillText('Внешний круг: '+(max*1000).toPrecision(3)+' mm / rad',180,390)}
    function sweep(){
      const g=ctx(get('.sweep')),seed=Number(get('.zoom').value),zoom=Number.isFinite(seed),center=zoom?seed:0;
      const min=zoom?center-.03:5,max=zoom?center+.03:60,points=d.frequencies.map((f,i)=>({f,db:10*Math.log10(d.ratios[i])})).filter(p=>p.f>=min&&p.f<=max);
      const lo=Math.min(-30,...points.map(p=>p.db))-2,hi=Math.max(3,...points.map(p=>p.db))+2,x=f=>60+(f-min)/(max-min)*510,y=v=>340-(v-lo)/(hi-lo)*295;
      g.clearRect(0,0,600,400);g.font='16px system-ui';g.fillStyle=textColor();
      for(let v=Math.ceil(lo/10)*10;v<=hi;v+=10){g.strokeStyle=v===0?'#d09d36':'#647c8c';g.lineWidth=v===0?2:.5;g.beginPath();g.moveTo(60,y(v));g.lineTo(570,y(v));g.stroke();g.fillText(v+' dB',1,y(v)+5)}
      g.beginPath();points.forEach((p,i)=>{i?g.lineTo(x(p.f),y(p.db)):g.moveTo(x(p.f),y(p.db))});g.strokeStyle=colors[2];g.lineWidth=2;g.stroke();
      points.forEach(p=>circle(g,x(p.f),y(p.db),zoom?2:1.2,colors[2]));
      const ticks=zoom?[-30,-20,-10,0,10,20,30]:[5,10,20,30,40,50,60];ticks.forEach(v=>g.fillText(String(v),x(zoom?center+v/1000:v)-9,368));
      g.fillText(zoom?'Смещение от '+center.toFixed(3)+' kHz, Hz':'Частота, kHz',zoom?120:235,395);
      if(d.frequency>=min&&d.frequency<=max){const ratio=d.cases[2].width/d.cases[1].width;circle(g,x(d.frequency),y(10*Math.log10(ratio)),6,colors[2],'#142b3d')}
    }
    const ratio=d.cases[2].width/d.cases[1].width,db=10*Math.log10(ratio);get('.result').innerHTML='<strong>'+db.toFixed(1)+' dB · '+(100*ratio).toFixed(2)+'% от рассеяния голой трубки</strong><br>'+d.frequency+' kHz · покрытие '+d.thickness.toFixed(2)+' mm. '+(ratio<1?'Объект рассеивает меньше. Это не абсолютная невидимость.':'На этой частоте покрытие не уменьшило полное рассеяние.');
    get('.diagnostics').textContent=d.cases.slice(1).map(c=>c.case+': невязка '+c.diagnostics.scaled_residual.toExponential(1)+', вклад последних мод '+c.diagnostics.modal_tail_fraction.toExponential(1)+', расчёт '+c.diagnostics.total_seconds.toFixed(3)+' s').join('\n');
    d.resonances.forEach(f=>{const o=document.createElement('option');o.value=String(f);o.textContent='Резонанс около '+f.toFixed(3)+' kHz';get('.zoom').append(o)});get('.zoom').onchange=sweep;
    get('.mode').onchange=drawFields;get('.phase').oninput=e=>{phase=Number(e.target.value)*Math.PI/180;drawFields()};get('.play').onclick=()=>{if(get('.mode').value!=='total'){get('.mode').value='total';drawFields()}playing=!playing;get('.play').textContent=playing?'❚❚ Пауза':'▶ Колебание фазы';if(playing)tick()};function tick(){if(!playing)return;phase=(phase+.045)%(2*Math.PI);get('.phase').value=phase*180/Math.PI;drawFields();frame=requestAnimationFrame(tick)}
    invalidation.then(()=>{playing=false;cancelAnimationFrame(frame)});geometry();drawFields();angular();sweep();
    </script></section>
    """
    LabHTML(replace(html,"__DATA__"=>data))
end

end
