# Numerical integration is exclusively in MetaNDT; this adapter samples the
# retained solutions for display, reproducible files and a finite-window metric.
function water_pulse_frames(r,xs)
    m=r.experiment.model;n=length(xs);count=length(r.frame_steps)
    total=zeros(n*n,count);scattered=similar(total)
    R=m.outer_radius+(m.scenario==:coated ? m.coating_thickness : 0.)
    for (iy,y) in enumerate(xs),(ix,x) in enumerate(xs)
        j=(iy-1)*n+ix
        if m.scenario!=:empty&&hypot(x,y)<R
            scattered[j,:].=0;continue # masked by drawn solids/air, not a microphone reading
        end
        trace=coated_trace(r,(x,y);indices=r.frame_steps)
        total[j,:]=trace.pressure;scattered[j,:]=trace.scattered
    end
    (;total,scattered)
end

function water_pulse_energy_csv(r)
    io=IOBuffer();println(io,"time_s,scattered_plus_solid_air_energy_J_m,solid_energy_J_m,air_energy_J_m,generalized_input_work_J_m,dissipated_energy_J_m")
    for i in eachindex(r.times)
        println(io,join((r.times[i],r.energy[i],r.solid_energy[i],r.air_energy[i],r.input_work[i],r.dissipated_energy[i]),','))
    end
    String(take!(io))
end

function water_pulse_run(s::Settings)
    spec=CoatedPulseExperiment(model=CoatedCylinderExperiment(frequency=s.frequency,coating_thickness=s.thickness))
    cases=coated_pulse_comparison(spec)
    all(r->r.diagnostics["energy_balance_relative"]<1e-7,cases) || error("Акустико-упругий расчёт не прошёл баланс энергии")
    labels=["Пустая вода","Трубка без покрытия","Трубка с покрытием"]
    xs=collect(range(-.025,.025;length=101));angles=collect(range(0,2π;length=181))
    frames=water_pulse_frames.(cases,Ref(xs));profiles=coated_pulse_profile.(cases,Ref(angles))
    limits=Dict("pressure"=>max(maximum(maximum(abs,f.total) for f in frames),eps()),
        "scattered"=>max(maximum(maximum(abs,f.scattered) for f in frames),eps()))
    fields=[Dict("name"=>name,"case"=>String(r.experiment.model.scenario),
        "frames_pressure"=>encode_frames(f.total,limits["pressure"]),
        "frames_scattered"=>encode_frames(f.scattered,limits["scattered"]),
        "profile"=>profile,"diag"=>r.diagnostics) for (r,name,f,profile) in zip(cases,labels,frames,profiles)]
    # Trapezoidal angular integral: endpoint 2π duplicates zero.
    integral(p)=sum((p[1:end-1]+p[2:end])/2)*2π/(length(p)-1)
    ratio=integral(profiles[3])/integral(profiles[2]);db=10log10(ratio)
    r=last(cases);m=r.experiment.model
    data=Dict{String,Any}(
        "kind"=>"cloak","title"=>"Как оболочка меняет рассеяние импульса?",
        "label"=>"Импульс · $(s.thickness*1000) mm · $(s.frequency/1000) kHz",
        "context"=>"Вода ↔ упругая сталь и силикон ↔ акустический воздух · плоская деформация",
        "applied"=>"Time-domain FEM · 3 периода · 0–$(round(spec.duration*1e6;digits=2)) μs · шаг $(round(r.diagnostics["time_step_s"]*1e6;digits=4)) μs",
        "metric"=>Dict("label"=>"Интеграл pₛ² по времени и контуру: покрытие / голая трубка",
            "value"=>db,"unit"=>"dB","text"=>"Конечное окно $(round(spec.duration*1e6;digits=1)) μs, радиус $(m.observation_radius*1000) mm. Это наблюдаемое давление, не полная энергия рассеяния и не абсолютная невидимость."),
        "field"=>Dict("kind"=>"water","domain"=>"time","cases"=>fields,"selected"=>2,"baseline"=>1,
            "count"=>length(xs),"extent"=>25.,"steelR"=>m.outer_radius*1000,"airR"=>m.inner_radius*1000,
            "coatR"=>(m.outer_radius+m.coating_thickness)*1000,"limits"=>limits,
            "frame_times_us"=>r.times[r.frame_steps]*1e6,"source_end_us"=>spec.pulse_cycles/m.frequency*1e6,
            "source_times_us"=>r.times*1e6,"source_drive"=>coated_pulse_drive.(Ref(spec),r.times),
            "source_y_label"=>"Давление в плоскости источника / p₀",
            "source_title"=>"Падающий импульс · 3 периода, затем давление в плоскости источника равно нулю"),
        "curve"=>Dict("x"=>angles*180/π,"y"=>profiles[3],"x_label"=>"Угол на контуре, °",
            "y_label"=>"∫pₛ²dt / ∫pвх²dt","reference"=>nothing),"resonances"=>Float64[],"angles"=>angles,
        "plot_title"=>"Рассеянный импульс по направлениям · общий масштаб",
        "plot_caption"=>"Интеграл квадрата рассеянного давления на радиусе 30 mm за всё окно / интеграл падающего импульса. Не поток энергии; поздний звон за пределами окна не включён.",
        "method"=>[
            "Прямой Newmark β=1/4, γ=1/2: P1 акустика воды и воздуха, смешанный P2/P1 FEM упругой стали/силикона. Угловые моды 0–$(m.modes), без FFT и поворота гармонической фазы.",
            "Давление = известный плоский импульс + рассчитанное рассеянное поле. Идеальный микрофон интерполирует полную историю FEM, а не экранные кадры.",
            "Оба направления сопряжения включены на воде/оболочке и стали/воздухе. Полость содержит сжимаемый воздух, не пустоту и не воду.",
            "Потери силикона: причинная модель Кельвина—Фойгта, η=0.15 при фиксированных 10 kHz. В отличие от гармонического режима η растёт с частотой; при изменении несущей материал не перенастраивается.",
            "Нулевое начальное состояние рассеянного поля, стали и воздуха; во всей показанной области падающий импульс также сначала равен нулю. Источник задан в плоскости x′=$(spec.source_plane*1000) mm.",
            "Внешняя граница удалена так, чтобы отражённый фронт не успевал вернуться в наблюдаемую область за выбранное окно; поглощение на ней приближённое.",
            "Общая шкала фиксирована на весь фильм и три случая, отдельно для полного и рассеянного давления. Экранные кадры округлены до Int16, микрофон использует Float32-историю.",
            "Снижение монохроматического рассеяния не гарантирует подавление широкополосного импульса. Конечный интеграл давления не равен дальней стационарной ширине рассеяния."],
        "diagnostics"=>[Dict("case"=>name,"values"=>r.diagnostics) for (r,name) in zip(cases,labels)],
        "specifications"=>experiment_toml.([r.experiment for r in cases]),
        "downloads"=>vcat([download("water_pulse_$(r.experiment.model.scenario).toml",experiment_toml(r.experiment)) for r in cases],
            [download("water_pulse_$(r.experiment.model.scenario)_energy.csv",water_pulse_energy_csv(r);mime="text/csv") for r in cases]))
    Calculation(data,cases)
end
