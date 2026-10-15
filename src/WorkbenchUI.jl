module WorkbenchUI

using MetaNDT, JSON
include("CoatedCylinderUI.jl")
include("SolidLensUI.jl")

export WorkbenchControls, WorkbenchSession, process!

const ASSETS=joinpath(@__DIR__,"assets")
const SHELF_LIMIT=6

struct Settings
    experiment::Symbol
    frequency::Float64
    thickness::Float64
    preset::Symbol
    polarization::Symbol
    regime::Symbol
end

function settings(value)
    value isa AbstractDict || throw(ArgumentError("неверный набор параметров"))
    kind=Symbol(get(value,"experiment","cloak"))
    kind in (:cloak,:solid) || throw(ArgumentError("неизвестный опыт"))
    f=Float64(get(value,"frequency",kind==:cloak ? 10000 : 140000))
    isfinite(f) || throw(ArgumentError("частота должна быть конечной"))
    regime=Symbol(get(value,"regime",kind==:cloak ? "harmonic" : "pulse"))
    regime in (:pulse,:harmonic) || throw(ArgumentError("выберите импульс или гармонику"))
    if kind==:cloak
        5000 <= f <= 60000 || throw(ArgumentError("в этом интерфейсе частота трубки — 5–60 kHz"))
        t=Float64(get(value,"thickness",.001))
        t in (.0008,.001,.0012) || throw(ArgumentError("выберите покрытие 0.8, 1.0 или 1.2 mm"))
        Settings(kind,f,t,:focused,:shear,regime)
    else
        f in (100000,140000,180000) || throw(ArgumentError("выберите 100, 140 или 180 kHz"))
        preset=Symbol(get(value,"preset","focused"))
        preset in (e.id for e in solid_examples()) || throw(ArgumentError("неизвестная конструкция STG"))
        polarization=Symbol(get(value,"polarization","shear"))
        polarization in (:shear,:pressure) || throw(ArgumentError("выберите SV или P"))
        Settings(kind,f,.001,preset,polarization,regime)
    end
end

settings_dict(s::Settings)=Dict("experiment"=>String(s.experiment),"frequency"=>s.frequency,
    "thickness"=>s.thickness,"preset"=>String(s.preset),"polarization"=>String(s.polarization),"regime"=>String(s.regime))

const Solutions=Union{Vector{CoatedCylinderResult},Vector{SolidLensResult},Vector{SolidPulseResult},Vector{CoatedPulseResult}}

struct Calculation
    data::Dict{String,Any}
    # Retain the actual solutions, not pixels or a cache lookup. Probing a pinned
    # run must keep working after the calculation caches have evicted that run.
    solutions::Solutions
end

struct Run
    id::Int
    settings::Settings
    data::Dict{String,Any}
    solutions::Solutions
    note::String
    probe::Union{Nothing,Dict{String,Any}}
end

Base.@kwdef mutable struct WorkbenchSession
    current::Union{Nothing,Run}=nothing
    pinned::Vector{Run}=Run[]
    next_id::Int=1
    handled::Int=0
    revision::Int=0
    message::String="Выберите физический вопрос и запустите опыт."
    error::String=""
end

function download(name,text;mime="text/plain")
    Dict("name"=>name,"text"=>text,"mime"=>mime)
end

function cloak_run(s::Settings)
    spec=CoatedCylinderExperiment(frequency=s.frequency,coating_thickness=s.thickness)
    cases=CoatedCylinderUI.cached_coated_comparison(spec)
    sweep=CoatedCylinderUI.cached_coated_sweep(spec)
    xs=collect(range(-.025,.025;length=81))
    labels=["Пустая вода","Трубка без покрытия","Трубка с покрытием"]
    fields=[CoatedCylinderUI.field_payload(r,xs) for r in cases]
    for (field,label) in zip(fields,labels); field["name"]=label; end
    ratio=cases[3].scattering_width/cases[2].scattering_width
    db=10log10(ratio)
    curve=Dict("x"=>sweep.frequencies/1000,"y"=>10log10.(sweep.ratio),
        "x_label"=>"Частота, kHz","y_label"=>"Покрытие / голая трубка, dB","reference"=>0.0)
    data=Dict{String,Any}(
        "kind"=>"cloak","title"=>"Можно ли скрыть трубку от звука?",
        "label"=>"$(s.thickness*1000) mm · $(s.frequency/1000) kHz",
        "context"=>"Вода + упругие сталь и силикон + акустический воздух",
        "applied"=>"Гармонический режим · плоская падающая волна · сталь Ø 8 mm",
        "metric"=>Dict("label"=>"Полное рассеяние: покрытие / голая трубка", "value"=>db,"unit"=>"dB",
            "text"=>ratio<1 ? "Покрытие уменьшило рассеяние. Это не абсолютная невидимость." : "На этой частоте покрытие ухудшило рассеяние."),
        "field"=>Dict("kind"=>"water","cases"=>fields,"selected"=>2,"baseline"=>1,
            "count"=>length(xs),"extent"=>25.0,"steelR"=>spec.outer_radius*1000,
            "airR"=>spec.inner_radius*1000,"coatR"=>(spec.outer_radius+spec.coating_thickness)*1000),
        "curve"=>curve,"resonances"=>sweep.cavity_frequencies/1000,
        "angles"=>cases[3].angles,
        "method"=>[
            "Смешанный P2/P1 радиальный FEM стали и силикона; точные акустические моды воды и воздуха. 2D, плоская деформация.",
            "Воздух действительно находится внутри трубки. Излучение идёт в бесконечную воду; произвольной CAD-сетки здесь нет.",
            "Полная ширина рассеяния — исходящая мощность / интенсивность падающей волны на единицу длины трубы. Это не одно удачно выбранное эхо.",
            "Частоты сгущены около воздушных резонансов до 0.5 Hz. Конечный перебор не гарантирует отсутствия других узких пиков.",
            "Силикон имеет заданные сдвиговые потери. Scattering cancellation — не универсальная невидимость и не просто поглощение."],
        "diagnostics"=>[Dict("case"=>labels[i],"values"=>cases[i].diagnostics) for i in 2:3],
        "specifications"=>[experiment_toml(r.experiment) for r in cases],
        "downloads"=>vcat([download("tube_$(r.experiment.scenario).toml",experiment_toml(r.experiment)) for r in cases],
            [download("tube_frequency.csv",coated_sweep_csv(sweep);mime="text/csv")]))
    Calculation(data,cases)
end

function ensure_solid_backend!()
    # Optional heavy backend is not loaded for the landing page or water tube.
    @eval import Gridap, GridapGmsh, Gmsh
    nothing
end

function solid_run(s::Settings)
    design=SolidLensUI.cached_design()
    comparison=SolidLensUI.comparison_cases(design,s.preset;frequency=s.frequency,polarization=s.polarization)
    results=comparison.results; r=results[comparison.selected]; spec=r.experiment
    fields=[SolidLensUI.field_payload(result,name) for (result,name) in zip(results,comparison.labels)]
    width=r.diagnostics["profile_fwhm_m"]*1000
    curve=Dict("x"=>r.profile_y*1000,"y"=>fields[comparison.selected]["profile"],
        "x_label"=>"Поперечная координата y, mm","y_label"=>"⟨K⟩ / принятая мощность, s/m²","reference"=>nothing)
    title=only(filter(e->e.id==s.preset,solid_examples())).title
    pol=s.polarization==:shear ? "SV" : "P"
    data=Dict{String,Any}(
        "kind"=>"solid","title"=>"Собирает ли STG-стенка волну?",
        "label"=>"$title · $(s.frequency/1000) kHz · $pol",
        "context"=>"Сплошной алюминий · связанные по торцам перемычки · свободные вырезы",
        "applied"=>"Гармонический режим · $pol-возбуждение · геометрия рассчитана для SV 140 kHz",
        "metric"=>Dict("label"=>"FWHM выбранной конструкции в расчётном сечении",
            "value"=>isfinite(width) ? width : nothing,"unit"=>"mm",
            "text"=>"Ширина пика энергии, а не разрешение дефектоскопа. Прямой равно-массовый контроль тоже может фокусировать."),
        "field"=>Dict("kind"=>"solid","cases"=>fields,"selected"=>comparison.selected-1,
            "baseline"=>length(results)>1 ? 1 : 0,"width"=>spec.width*1000,"height"=>spec.height*1000,
            "length"=>first(spec.bricks).length*1000,"source"=>spec.source_x*1000,
            "focus"=>(first(spec.bricks).length/2+spec.focus_distance)*1000,
            "y"=>r.profile_y*1000,"density"=>spec.density,"frequency"=>spec.frequency),
        "curve"=>curve,"resonances"=>Float64[],"angles"=>Float64[],
        "method"=>[
            "Настоящий FEM упругости соединённого алюминиевого тела. Вырезы — пустоты со свободными стенками, не вода.",
            "Фаза показывает установившееся колебание, а не приход импульса. Для прихода волны выберите режим «Импульс».",
            "Прямой контроль сохраняет длину и массу каждой выбранной перемычки. Одинаковые STG проверяют роль фазовой расстановки, но не являются равно-массовой заменой.",
            "Профили содержат полную среднюю кинетическую энергию / принятую мощность. Это не выделенная SV-мощность и не коэффициент передачи.",
            "Внешнее поглощающее условие приближённое. FWHM — ширина главного пика, не разрешение двух дефектов."],
        "diagnostics"=>[Dict("case"=>name,"values"=>result.diagnostics) for (result,name) in zip(results,comparison.labels)],
        "specifications"=>[experiment_toml(result.experiment) for result in results],
        "downloads"=>vcat([download("solid_control_$(i).toml",experiment_toml(result.experiment)) for (i,result) in enumerate(results)],
            [download("solid_profile.csv",solid_profile_csv(r);mime="text/csv"),
             download("stg_calibration.csv",lens_design_csv(design);mime="text/csv")]))
    Calculation(data,results)
end

include("TransientFrames.jl")
include("SolidTransientUI.jl")
include("WaterTransientUI.jl")

function probe_signal(amplitude,frequency,times;scale=1.0)
    Dict("phasor"=>[real(amplitude)*scale,imag(amplitude)*scale],
        "values"=>harmonic_trace(amplitude,frequency,times)*scale)
end
function observe_point(result::SolidPulseResult,point,times)
    trace=solid_trace(result,point)
    Dict("ux"=>Dict("values"=>trace.ux*1e9),"uy"=>Dict("values"=>trace.uy*1e9))
end
function observe_point(result::CoatedPulseResult,point,times)
    trace=coated_trace(result,point)
    Dict("pressure"=>Dict("values"=>trace.pressure),"scattered"=>Dict("values"=>trace.scattered))
end

function observe_point(result::CoatedCylinderResult,point,times)
    f=result.experiment.frequency
    Dict("pressure"=>probe_signal(coated_pressure(result,point),f,times),
         "scattered"=>probe_signal(coated_pressure(result,point;scattered=true),f,times))
end
function observe_point(result::SolidLensResult,point,times)
    ux,uy=solid_displacement(result,point); f=result.experiment.frequency
    Dict("ux"=>probe_signal(ux,f,times;scale=1e9),"uy"=>probe_signal(uy,f,times;scale=1e9))
end

function point_observation(data,solutions,point)
    point isa AbstractVector && length(point)==2 && all(v->v isa Real && isfinite(v),point) ||
        throw(ArgumentError("датчику нужны две конечные координаты в mm"))
    xy=Float64.(point); field=data["field"]; water=field["kind"]=="water"
    halfwidth=water ? field["extent"] : field["width"]/2
    halfheight=water ? field["extent"] : field["height"]/2
    abs(xy[1])<=halfwidth && abs(xy[2])<=halfheight || throw(ArgumentError("датчик за пределами показанной области"))
    result=first(solutions)
    frequency=result isa CoatedPulseResult ? result.experiment.model.frequency : result.experiment.frequency
    transient=result isa Union{SolidPulseResult,CoatedPulseResult}
    times=transient ? first(solutions).times : collect(range(0,2/frequency;length=241))
    cases=map(enumerate(solutions)) do (i,result)
        name=field["cases"][i]["name"]
        try
            signals=observe_point(result,xy/1000,times)
            Dict("name"=>name,"valid"=>true,"signals"=>signals,"reason"=>"")
        catch err
            err isa ArgumentError || rethrow()
            Dict("name"=>name,"valid"=>false,"signals"=>nothing,
                "reason"=>water ? "Здесь нет внешней воды: полость, металл или покрытие." : "Здесь нет твёрдого тела: вырез или точка вне сетки.")
        end
    end
    Dict{String,Any}("point_mm"=>xy,"frequency"=>frequency,"time_us"=>times*1e6,
        "unit"=>water ? "Pa" : "nm","domain"=>transient ? "time" : "harmonic","cases"=>cases)
end

function run_case(s::Settings)
    s.experiment==:cloak && return s.regime==:pulse ? water_pulse_run(s) : cloak_run(s)
    ensure_solid_backend!()
    # Loading a Julia extension introduces methods in a new world age.
    Base.invokelatest(s.regime==:pulse ? solid_pulse_run : solid_run,s)
end

function run_summary(r::Run;full=false)
    d=Dict("id"=>r.id,"settings"=>settings_dict(r.settings),"note"=>r.note,
        "kind"=>r.data["kind"],"label"=>r.data["label"],"metric"=>r.data["metric"],
        "curve"=>r.data["curve"],"specifications"=>r.data["specifications"],"probe"=>r.probe)
    full && (d["data"]=r.data)
    d
end

struct WorkbenchUpdate
    payload::Dict{String,Any}
end
function Base.show(io::IO,::MIME"text/html",u::WorkbenchUpdate)
    # Inert data: the mounted controls observe this node, not a fragile global event.
    json=replace(JSON.json(u.payload),"<"=>"\\u003c")
    print(io,"<script type='application/json' id='meta-workbench-data'>",json,"</script>")
end

function update(s::WorkbenchSession)
    WorkbenchUpdate(Dict("revision"=>s.revision,"handled"=>s.handled,"message"=>s.message,
        "error"=>s.error,"current"=>isnothing(s.current) ? nothing : run_summary(s.current;full=true),
        "pinned"=>run_summary.(s.pinned),"limit"=>SHELF_LIMIT))
end

"""Apply one submitted UI command. Numerical failure preserves the last good run.
An injectable runner permits state-machine tests without inventing numerical data.
"""
function process!(s::WorkbenchSession,command;runner=run_case)
    try
        command isa AbstractDict || throw(ArgumentError("неверная команда"))
        number=get(command,"nonce",0)
        # Browser bonds use MessagePack Float64 even for integral JS numbers.
        number isa Real && !(number isa Bool) && isfinite(number) && isinteger(number) &&
            0<=number<=min(typemax(Int),9_007_199_254_740_991) || throw(ArgumentError("неверный номер команды"))
        nonce=Int(number)
        action=String(get(command,"action","init"))
        # Mounting/reloading the widget must not lower the deduplication fence.
        action=="init" && return update(s)
        nonce<=s.handled && return update(s)
        s.handled=nonce; s.revision+=1; s.error=""
        if action=="run"
            spec=settings(get(command,"settings",Dict()))
            calculation=runner(spec)
            previous=s.current
            probe=(!isnothing(previous) && previous.settings.experiment==spec.experiment && !isnothing(previous.probe)) ?
                point_observation(calculation.data,calculation.solutions,previous.probe["point_mm"]) : nothing
            s.current=Run(s.next_id,spec,calculation.data,calculation.solutions,"",probe); s.next_id+=1
            s.message="Расчёт завершён. Показаны применённые параметры."
        elseif action=="probe"
            isnothing(s.current) && throw(ArgumentError("сначала рассчитайте опыт"))
            r=s.current
            get(command,"id",0)==r.id || throw(ArgumentError("результат уже сменился: выберите точку заново"))
            target=get(command,"case",-1)
            target isa Real && isfinite(target) && isinteger(target) && 0<=target<length(r.solutions) ||
                throw(ArgumentError("неизвестный случай для датчика"))
            probe=point_observation(r.data,r.solutions,get(command,"point_mm",nothing))
            probe["cases"][Int(target)+1]["valid"] || throw(ArgumentError(probe["cases"][Int(target)+1]["reason"]))
            s.current=Run(r.id,r.settings,r.data,r.solutions,r.note,probe)
            s.message="Датчик перемещён. Опрос готового решения, без нового FEM-расчёта."
        elseif action=="pin"
            isnothing(s.current) && throw(ArgumentError("сначала рассчитайте опыт"))
            get(command,"id",0)==s.current.id || throw(ArgumentError("результат уже сменился; закрепите текущий запуск"))
            note=String(get(command,"note",""))
            length(note)<=1200 || throw(ArgumentError("заметка должна быть короче 1200 символов"))
            index=findfirst(r->r.id==s.current.id,s.pinned)
            isnothing(index) && length(s.pinned)>=SHELF_LIMIT && throw(ArgumentError("полка заполнена: удалите один из шести запусков или экспортируйте результаты"))
            r=Run(s.current.id,s.current.settings,s.current.data,s.current.solutions,note,s.current.probe)
            if isnothing(index); push!(s.pinned,r); else; s.pinned[index]=r; end
            s.current=r; s.message="Запуск закреплён. Заметка сохранена вместе с ним."
        elseif action in ("restore","remove")
            index=findfirst(r->r.id==get(command,"id",0),s.pinned)
            isnothing(index) && throw(ArgumentError("закреплённый запуск не найден"))
            if action=="restore"
                s.current=s.pinned[index]; s.message="Сохранённый результат восстановлен без нового расчёта."
            else
                deleteat!(s.pinned,index); s.message="Выбранный запуск убран с полки. Текущий расчёт сохранён."
            end
        elseif action!="init"
            throw(ArgumentError("неизвестная команда"))
        end
    catch err
        err isa InterruptException && rethrow()
        s.error=sprint(showerror,err); s.message="Действие не применено. Последний успешный результат и датчик сохранены."
    end
    update(s)
end

struct WorkbenchControls end
Base.get(::WorkbenchControls)=Dict("action"=>"init","nonce"=>0)

function catalog()
    base=CoatedCylinderExperiment()
    resonance=first(coated_cavity_resonances(base,5000,60000))+1.5
    b=SinusoidalBrick(); outline=MetaNDT.brick_polygon(b)
    Dict("defaults"=>Dict("cloak"=>settings_dict(settings(Dict("experiment"=>"cloak","regime"=>"pulse"))),
                         "solid"=>settings_dict(settings(Dict("experiment"=>"solid")))),
        "resonance"=>resonance,"solidPresets"=>[Dict("id"=>String(e.id),"name"=>e.title) for e in solid_examples()],
        "brick"=>[collect(p).*1000 for p in outline],"brickLength"=>b.length*1000,"brickHeight"=>b.height*1000,
        "legacy"=>Dict("cloak"=>abspath(joinpath(@__DIR__,"..","notebooks","coated_cylinder.jl")),
                        "solid"=>abspath(joinpath(@__DIR__,"..","notebooks","solid_stg_lens.jl"))))
end

function Base.show(io::IO,::MIME"text/html",::WorkbenchControls)
    html=read(joinpath(ASSETS,"workbench.html"),String)
    replacements=("__CSS__"=>read(joinpath(ASSETS,"workbench.css"),String),
        "__FIELD_GRID__"=>read(joinpath(ASSETS,"field-grid.js"),String),
        "__SCRIPT__"=>read(joinpath(ASSETS,"workbench.js"),String),
        "__CATALOG__"=>replace(JSON.json(catalog()),"<"=>"\\u003c"))
    print(io,replace(html,replacements...))
end

end
