module CanonicalData

using MetaNDT, JSON, Base64, CodecZlib, LinearAlgebra, SHA

const ROOT=normpath(joinpath(@__DIR__,".."))
const DATA=joinpath(ROOT,"data","canonical")
const IDS=("mass","bulk","absorber","cloak","focus")

pack(a)=base64encode(transcode(ZlibCompressor,collect(reinterpret(UInt8,htol.(vec(Float32.(a)))))))

function record_payload(r::CanonicalRecord,name,geometry)
    all(isfinite,r.field) || error("nonfinite prepared field")
    Dict("name"=>name,"x"=>r.x,"y"=>r.y,"times"=>r.times,
        "values"=>pack(r.field),"valid"=>collect(r.valid),
        "internal"=>pack(r.internal),"internal_count"=>size(r.internal,1),
        "diagnostics"=>r.diagnostics,"geometry"=>geometry)
end

function source_digest()
    paths=[joinpath(ROOT,"..","meta-ndt","src",f) for f in
        ("canonical_experiments.jl","canonical_spatial.jl","solid_lens.jl")]
    # A Windows checkout may use CRLF. Line endings do not change the model.
    bytes2hex(sha256(join(replace(read(path,String),"\r\n"=>"\n") for path in paths)))
end

function focus_backend_digest()
    root=normpath(joinpath(ROOT,"..","meta-ndt"))
    paths=(joinpath(root,"src","sample_geometry.jl"),joinpath(root,"ext","solid_lens_fem.jl"))
    bytes2hex(sha256(join(replace(read(path,String),"\r\n"=>"\n") for path in paths)))
end

function save_bundle(id,data)
    mkpath(DATA)
    data["schema"]=1; data["id"]=id; data["source_digest"]=source_digest()
    id=="focus" && (data["backend_digest"]=focus_backend_digest())
    data["provenance"]="MetaNDT direct numerical experiment; generated offline; not experimental measurements"
    path=joinpath(DATA,id*".json.gz")
    write(path,transcode(GzipCompressor,codeunits(JSON.json(data))))
    println("Prepared ",id,": ",round(filesize(path)/1024^2;digits=2)," MiB")
    path
end

function read_bundle(id)
    id in IDS || throw(ArgumentError("unknown canonical experiment"))
    path=joinpath(DATA,id*".json.gz")
    isfile(path) || error("Нет готового опыта $id. Разработчик должен выполнить tools/prepare_canonical.jl; интерфейс не запускает расчёт автоматически.")
    data=JSON.parse(String(transcode(GzipDecompressor,read(path))))
    data["schema"]==1 && data["source_digest"]==source_digest() ||
        error("Готовый опыт $id устарел: подготовьте результаты заново, не из интерфейса.")
    id=="focus" && haskey(data,"backend_digest") && data["backend_digest"]!=focus_backend_digest() &&
        error("Готовая STG-линза устарела после правки геометрии или FEM: подготовьте её заново вне интерфейса.")
    data
end

function prepare_mass()
    m=membrane_model()
    unloaded=membrane_model(added_mass=0.)
    scan=collect(50.:2.:1500.); masses=[real(membrane_response(m,f).mass) for f in scan]
    negative=findall(<(0),masses)
    isempty(negative) && error("membrane has no negative-inertia band")
    # Choose the middle of the first continuous negative band, not a pole.
    firstband=Int[first(negative)]
    for i in negative[2:end]
        i==last(firstband)+1 || break
        push!(firstband,i)
    end
    fnegative=scan[firstband[cld(length(firstband),2)]]
    frequencies=[.65scan[first(firstband)],fnegative,1.2scan[last(firstband)]]
    sets=Any[]
    for (f,label) in zip(frequencies,["Ниже резонансной области","Отрицательная эффективная масса","Выше антирезонанса"])
        cases=Any[]
        for (model,name) in ((unloaded,"Мембрана без добавленного груза"),(m,"Мембрана с грузом"))
            r=membrane_record(model,f)
            r.diagnostics["energy_balance_relative"]<1e-8 || error("membrane energy balance")
            push!(cases,record_payload(r,name,Dict("type"=>"membrane","r"=>model.r,"radius"=>model.radius,
                "disk_radius"=>model.disk_radius,"mass_g"=>model.added_mass*1000)))
        end
        push!(sets,Dict("label"=>label,"frequency"=>f,"cases"=>cases))
    end
    save_bundle("mass",Dict("title"=>"Как масса может стать отрицательной?",
        "question"=>"Добавьте центральный груз. Меняются не законы Ньютона, а совместное движение частей мембраны.",
        "instruction"=>"Сравните мембрану без груза и с грузом. Выберите резонансную область, затем смотрите деформацию и запись за мембраной.",
        "model"=>"Осесимметричная натянутая мембрана + жёсткий диск + два плосковолновых акустических порта. Newmark во времени. Собственный образец, не реплика Yang.",
        "limit"=>"Отрицательна динамическая поверхностная масса (kg/m²), не масса вещества. Натяжение задано нами. Показатель знака относится к гармоническому отклику на несущей.",
        "unit"=>"Pa","coordinate_unit"=>"m","source"=>"Yang et al., PRL 2008",
        "url"=>"https://doi.org/10.1103/PhysRevLett.101.204301","sets"=>sets,
        "plot"=>Dict("x"=>scan,"series"=>[
            Dict("name"=>"Без груза","y"=>clamp.([real(membrane_response(unloaded,f).mass) for f in scan],-15,15)),
            Dict("name"=>"С грузом","y"=>clamp.(masses,-15,15))],
            "xlabel"=>"Частота, Hz","ylabel"=>"Re σeff, kg/m² (шкала ±15)","zero"=>true)))
end

function prepare_bulk()
    L=1000*.001/(π*.0005^2); C=62.8e-9/(1000*1480^2); f0=1/(2π*sqrt(L*C))
    sets=Any[]
    for (f,label) in zip(f0.*[.75,1.10,1.5],["Ниже резонанса полостей","Отрицательный модуль","Выше запрещённой полосы"])
        cases=[record_payload(helmholtz_record(f;open),name,Dict("type"=>"helmholtz","open"=>open,"positions"=>(collect(30:41).-0.5).*.0092))
            for (open,name) in ((false,"Горловины закрыты · прямой канал"),(true,"Горловины открыты · резонаторы работают"))]
        push!(sets,Dict("label"=>label,"frequency"=>f,"cases"=>cases))
    end
    # `0.55f0` is a Float32 literal in Julia, not multiplication by f0.
    scan=collect(range(0.55 * f0,1.65 * f0;length=241))
    response=[real(helmholtz_modulus(f))/(1000*1480^2) for f in scan]
    all(first(scan)<=s["frequency"]<=last(scan) for s in sets) || error("bulk carriers fall outside the frequency scan")
    minimum(response)<0<maximum(response) || error("bulk scan must resolve both signs of the modulus")
    save_bundle("bulk",Dict("title"=>"Когда полости мешают звуку пройти?",
        "question"=>"Открытые боковые полости меняют динамическую сжимаемость канала. Закройте горловины — тот же канал перестаёт быть резонансным материалом.",
        "instruction"=>"Переключите частотную область. Сравните проходящий импульс и давление в боковых полостях.",
        "model"=>"Пассивная одномерная акустическая сеть: сжимаемость воды, инерция потока, горловины и полости. Не 2D/3D FEM геометрии Fang.",
        "limit"=>"Отрицателен эффективный модуль ячейки, а не собственный модуль воды. Провал передачи сам по себе этого не доказывает; знак вычисляется из уравнений сети.",
        "unit"=>"Pa","coordinate_unit"=>"m","source"=>"Fang et al., Nature Materials 2006",
        "url"=>"https://doi.org/10.1038/nmat1644","sets"=>sets,
        "plot"=>Dict("x"=>scan,"series"=>[
            Dict("name"=>"Закрыты: обычная вода","y"=>ones(length(scan))),
            Dict("name"=>"Открыты: канал с полостями","y"=>clamp.(response,-4,4))],
            "xlabel"=>"Частота, Hz","ylabel"=>"Re Keff / Kводы (шкала ±4)","zero"=>true)))
end

function prepare_absorber()
    m=membrane_model(radius=.045,disk_radius=.01,added_mass=.0008,surface_density=.20,tension=50.)
    depth=.025
    best=(A=-Inf,f=0.,loss=0.)
    for f in 100.:2.:900.,loss in 10. .^ range(-1,4;length=65)
        A=membrane_response(m,f;back_depth=depth,loss_rate=loss).absorption
        A>best.A && (best=(;A,f,loss))
    end
    best.A>.95 || error("absorber did not reach matching target")
    cases=Any[]
    for (name,loss,wall) in (("Жёсткая стенка · отражение",0.,true),
                            ("Мембрана и полость · без потерь",0.,false),
                            ("Согласованные потери · поглощение",best.loss,false),
                            ("Слишком большие потери",100best.loss,false))
        r=membrane_record(m,best.f;back_depth=depth,loss_rate=loss,wall)
        push!(cases,record_payload(r,name,Dict("type"=>"absorber","r"=>m.r,"radius"=>m.radius,"disk_radius"=>m.disk_radius,"depth"=>depth,"wall"=>wall)))
    end
    scan=collect(range(.55best.f,1.6best.f;length=241))
    curves=[Dict("name"=>name,"y"=>[membrane_response(m,f;back_depth=depth,loss_rate=loss).absorption for f in scan])
        for (name,loss) in (("Без потерь",0.),("Согласованные",best.loss),("Чрезмерные",100best.loss))]
    save_bundle("absorber",Dict("title"=>"Почему больше потерь — не всегда лучше?",
        "question"=>"Тонкая мембрана перед закрытой полостью может поглотить звук, но только при согласовании с воздухом.",
        "instruction"=>"Сравните стенку, мембрану без потерь и согласованный поглотитель. Затем включите чрезмерные потери: отражение возвращается.",
        "model"=>"Прямая временная мембранно-портовая модель с герметичной воздушной полостью и положительным демпфированием. Свой образец; не точная SF₆-конструкция Ma.",
        "limit"=>"Диаграмма R/T/A — установившийся контроль на несущей, не мгновенный баланс импульса. Поглощение не означает невидимость. Новые размеры и натяжение не заимствованы у Ma.",
        "unit"=>"Pa","coordinate_unit"=>"m","source"=>"Ma et al., Nature Materials 2014",
        "url"=>"https://doi.org/10.1038/nmat3994",
        "sets"=>[Dict("label"=>"Согласование и потери","frequency"=>best.f,"cases"=>cases)],
        "plot"=>Dict("x"=>scan,"series"=>curves,"xlabel"=>"Частота, Hz","ylabel"=>"Поглощённая доля мощности A","zero"=>false)))
end

function prepare_cloak()
    records=[canonical_spatial_record(:cloak,v) for v in (:flat,:bump,:cloak)]
    reference=records[1]
    ids=[i for j in eachindex(reference.y) for i in ((j-1)*length(reference.x).+(1:length(reference.x)))
        if reference.y[j]>.18]
    window=findall(t->.001<t<.0028,reference.times)
    bare=sum(abs2,records[2].field[ids,window]-reference.field[ids,window])
    coated=sum(abs2,records[3].field[ids,window]-reference.field[ids,window])
    ratio=coated/bare
    ratio<.9 || error("ground cloak did not reduce the external field residual: $ratio")
    for r in records; r.diagnostics["external_field_error_ratio"] = ratio; end
    cases=[record_payload(r,name,Dict("type"=>"ground","variant"=>v)) for (r,name,v) in zip(records,
        ["Ровная отражающая поверхность","Выступ без плаща","Выступ под акустическим плащом"],["flat","bump","cloak"])]
    ground=Dict("label"=>"Плащ над выступом","frequency"=>3000.,"cases"=>cases)
    tube=prepare_tube_set()
    save_bundle("cloak",Dict("title"=>"Как уменьшить акустическую заметность?",
        "question"=>"Плащ должен вернуть отражённому фронту форму, похожую на отражение от ровной поверхности. Просто убрать звук недостаточно.",
        "instruction"=>"Запустите импульс и сравните все три случая. Смотрите на весь отражённый фронт, затем поставьте микрофон над выступом.",
        "model"=>"2D P1 FEM давления с положительным тензором плотности по Popa Eq.(3). Готовые сетки и рассчитанные временные поля; микроструктура пластин не разрешена.",
        "limit"=>"Это эффективный ground cloak над отражающей поверхностью, не всенаправленная невидимость. На внешнем краю есть численный поглощающий слой.",
        "unit"=>"Pa","coordinate_unit"=>"m","source"=>"Popa et al., PRL 2011",
        "url"=>"https://doi.org/10.1103/PhysRevLett.106.253901",
        "sets"=>[ground,tube]))
end

function prepare_tube_set()
    model=CoatedCylinderExperiment(frequency=10000.)
    pulse=CoatedPulseExperiment(;model,duration=1.2e-3)
    results=coated_pulse_comparison(pulse); x=collect(range(-.025,.025;length=61)); ids=1:8:length(first(results).times)
    cases=Any[]
    for (r,name) in zip(results,["Пустая вода","Трубка без резины","Та же трубка с резиной"])
        samples=zeros(Float32,length(x)^2,length(ids)); echo=zero(samples); valid=trues(length(x)^2)
        for (j,y) in enumerate(x),(i,xx) in enumerate(x)
            k=i+(j-1)*length(x)
            try
                trace=coated_trace(r,(xx,y);indices=ids)
                samples[k,:]=trace.pressure; echo[k,:]=trace.scattered
            catch err
                err isa ArgumentError || rethrow();valid[k]=false
            end
        end
        diag=copy(r.diagnostics);diag["frequency_Hz"]=10000.
        record=CanonicalRecord(x,x,r.times[ids],samples,valid,zeros(Float32,0,0),diag)
        geometry=Dict("type"=>"tube","variant"=>String(r.experiment.model.scenario),"outer"=>model.outer_radius,
            "inner"=>model.inner_radius,"coating"=>model.coating_thickness)
        payload=record_payload(record,name,geometry);payload["scattered"]=pack(echo)
        payload["specification"]=experiment_toml(r.experiment)
        push!(cases,payload)
    end
    Dict("label"=>"Трубка: резина снята / надета","frequency"=>10000.,"cases"=>cases,"reference"=>1,
        "question"=>"Снимите и наденьте резиновую оболочку на одну и ту же полую металлическую трубку в воде. Сравните эхо и поздний звон.",
        "instruction"=>"Сначала сравните голую трубку с трубкой в резине. Переключатель «только эхо» вычитает падающую волну из расчётного давления.",
        "model"=>"Прямой акустико-упругий Newmark: вода–сталь–силикон–воздух, смешанный P2/P1 радиальный FEM и угловые моды. Сохранены временные измерения.",
        "limit"=>"Резина меняет упругую связь и потери; это не универсальное устранение резонансов. Окно 1.2 ms конечно и не обязано включать весь звон. Scattering cancellation — иной механизм, чем ground cloak.",
        "source"=>"Rohde et al., Scientific Reports 2015","url"=>"https://doi.org/10.1038/srep13175")
end

end
