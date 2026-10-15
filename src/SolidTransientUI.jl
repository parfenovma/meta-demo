# Included inside WorkbenchUI: transient presentation, never a numerical solver.

function pulse_field_payload(r::SolidPulseResult,name,limit)
    s=r.experiment
    # Column-major = contiguous nodes for each frame. Explicit little endian
    # Signed Int16 display quantization, ONE scale for the entire comparison.
    # Zlib removes the mostly quiet early/late regions; sensor histories are not
    # quantized. Maximum display error is limit/65534 metres.
    Dict("name"=>name,"xy"=>[collect(p).*1000 for p in eachcol(r.nodes)],
        "tri"=>[collect(t).-1 for t in eachcol(r.triangles)],
        "frames_x"=>encode_frames(r.displacement_x,limit),"frames_y"=>encode_frames(r.displacement_y,limit),
        "outlines"=>s.scenario==:solid ? [] : [[collect(p).*1000 for p in outline] for outline in solid_lens_outlines(s)],
        "profile"=>r.profile_integrated_kinetic/r.diagnostics["input_work_J_m"],"diag"=>r.diagnostics)
end

function pulse_history_csv(r)
    io=IOBuffer(); println(io,"time_s,source_drive,stored_energy_J_m,input_work_J_m,outgoing_energy_J_m")
    for i in eachindex(r.times)
        println(io,join((r.times[i],solid_pulse_drive(r.experiment,r.times[i]),r.energy[i],r.input_work[i],r.outgoing_energy[i]),','))
    end
    String(take!(io))
end

function solid_pulse_run(s::Settings)
    design=SolidLensUI.cached_design()
    selected=remake_experiment(solid_preset(design,s.preset;frequency=s.frequency,polarization=s.polarization);frame_count=141)
    reference=MetaNDT.straight_reference(selected)
    title=only(filter(e->e.id==s.preset,solid_examples())).title
    # Two full histories, not four harmonic controls. No global history cache:
    # only the current run and explicitly pinned runs retain these arrays.
    specs=selected.scenario in (:solid,:straight) ? [selected] : [reference,selected]
    labels=length(specs)==1 ? [title] : ["Прямые перемычки · равно-массовый контроль",title]
    results=[simulate_pulse(spec;retain_history=true) for spec in specs]
    all(r->r.diagnostics["energy_balance_relative"]<1e-7 && r.diagnostics["input_work_J_m"]>0,results) ||
        error("Импульсный расчёт не прошёл проверку баланса энергии")
    r=last(results); spec=r.experiment
    limit=maximum(max(maximum(abs,r.displacement_x),maximum(abs,r.displacement_y)) for r in results)
    fields=[pulse_field_payload(r,name,limit) for (r,name) in zip(results,labels)]
    width=MetaNDT.profile_width(r.profile_y,r.profile_integrated_kinetic)*1000
    pol=s.polarization==:shear ? "SV" : "P"
    # One fixed signed scale across ALL frames, both components and both cases.
    data=Dict{String,Any}(
        "kind"=>"solid","title"=>"Как импульс проходит через STG-стенку?",
        "label"=>"Импульс · $title · $(s.frequency/1000) kHz · $pol",
        "context"=>"Сплошной алюминий · связанные по торцам перемычки · свободные вырезы",
        "applied"=>"Time-domain FEM · 6 периодов $pol · 0–$(round(spec.duration*1e6;digits=2)) μs · шаг $(round(r.diagnostics["time_step_s"]*1e6;digits=4)) μs",
        "metric"=>Dict("label"=>"FWHM интеграла кинетической энергии в сечении",
            "value"=>isfinite(width) ? width : nothing,"unit"=>"mm",
            "text"=>"Интеграл по всему временному окну / работа источника. Это ширина энергетического пятна, не разрешение дефектов."),
        "field"=>Dict("kind"=>"solid","domain"=>"time","cases"=>fields,"selected"=>length(results)-1,"baseline"=>0,
            "width"=>spec.width*1000,"height"=>spec.height*1000,"source"=>spec.source_x*1000,
            "focus"=>(first(spec.bricks).length/2+spec.focus_distance)*1000,
            "frame_times_us"=>r.frame_times*1e6,"limit_nm"=>limit*1e9,"display_error_nm"=>limit*1e9/65534,
            "source_end_us"=>spec.pulse_cycles/spec.frequency*1e6,
            "source_times_us"=>r.times*1e6,"source_drive"=>solid_pulse_drive.(Ref(spec),r.times)),
        "curve"=>Dict("x"=>r.profile_y*1000,"y"=>last(fields)["profile"],"x_label"=>"Поперечная координата y, mm",
            "y_label"=>"∫K dt / работа источника, s/m²","reference"=>nothing),
        "resonances"=>Float64[],"angles"=>Float64[],
        "method"=>[
            "P1 FEM линейной упругости, плоская деформация. Newmark β=1/4, γ=1/2; начальные смещения и скорости — ноль.",
            "Источник: синус с окном Hann, ровно 6 периодов, затем внешняя сила равна нулю. После выключения волна продолжает распространяться.",
            "Каждый кадр — рассчитанное состояние в указанное время, не вращение фазы. Общая цветовая шкала фиксирована на весь фильм и контроль.",
            "Датчик: P1-интерполяция Float32-истории на каждом шаге, без повторного FEM. Расчёт — Float64. Кадры для экрана сжаты в Int16 с общей шкалой; датчик не использует это округление.",
            spec.scenario==:solid ? "Сплошное тело — эталон без прорезей; отдельного равно-массового контроля в этом запуске нет." :
                "Прямые перемычки сохраняют массу каждой выбранной перемычки. Свободные вырезы — пустоты, не полосатая эффективная среда.",
            "Поглощение на внешней границе приближённое: поздние отражения возможны. Энергетический баланс не заменяет проверку сеточной сходимости.",
            "Закреплённые импульсные запуски удерживают полные истории в RAM. Убирайте ненужные запуски с полки перед длинной серией."],
        "diagnostics"=>[Dict("case"=>name,"values"=>result.diagnostics) for (result,name) in zip(results,labels)],
        "specifications"=>experiment_toml.([r.experiment for r in results]),
        "downloads"=>vcat([download("pulse_$(i).toml",experiment_toml(result.experiment)) for (i,result) in enumerate(results)],
            [download("pulse_energy_$(i).csv",pulse_history_csv(result);mime="text/csv") for (i,result) in enumerate(results)]))
    Calculation(data,results)
end
