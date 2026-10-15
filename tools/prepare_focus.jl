# Offline preparation of the real connected-solid transient, not a phase screen.
import Gridap, GridapGmsh, Gmsh
using SparseArrays, LinearAlgebra, Serialization, JSON

function sample_solid_history(r,x,y,ids)
    nx=length(x); ny=length(y); rows=Int[]; cols=Int[]; weights=Float64[]
    covered=falses(nx*ny)
    for tri in eachcol(r.triangles)
        a,b,c=eachcol(r.nodes[:,tri]);
        ilo=max(1,searchsortedfirst(x,min(a[1],b[1],c[1])))
        ihi=min(nx,searchsortedlast(x,max(a[1],b[1],c[1])))
        jlo=max(1,searchsortedfirst(y,min(a[2],b[2],c[2])))
        jhi=min(ny,searchsortedlast(y,max(a[2],b[2],c[2])))
        det=(b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1])
        abs(det)>eps()*1e-5 || continue
        for j in jlo:jhi,i in ilo:ihi
            pixel=i+(j-1)*nx;covered[pixel] && continue
            u=((x[i]-a[1])*(c[2]-a[2])-(y[j]-a[2])*(c[1]-a[1]))/det
            v=((b[1]-a[1])*(y[j]-a[2])-(b[2]-a[2])*(x[i]-a[1]))/det
            min(u,v,1-u-v)>=-1e-8 || continue
            covered[pixel]=true
            for (node,w) in zip(tri,(1-u-v,u,v))
                push!(rows,pixel);push!(cols,node);push!(weights,w)
            end
        end
    end
    W=sparse(rows,cols,weights,nx*ny,size(r.nodes,2))
    Float32.(1e9.*(W*view(r.history_y,:,ids))),covered
end

function focus_case(spec,name;cache_dir="")
    solver=read(joinpath(pkgdir(MetaNDT),"ext","solid_lens_fem.jl"),String)
    key=CanonicalData.bytes2hex(CanonicalData.sha256(experiment_toml(spec)*CanonicalData.source_digest()*solver))
    path=joinpath(cache_dir,key*".json.gz")
    if !isempty(cache_dir)&&isfile(path)
        payload=JSON.parse(String(CanonicalData.transcode(CanonicalData.GzipDecompressor,read(path))))
        payload["specification"]==experiment_toml(spec) || error("wrong cached STG specification")
        payload["name"]=name
        return payload
    end
    result=@time Base.invokelatest(simulate_pulse,spec;retain_history=true)
    result.diagnostics["energy_balance_relative"]<1e-6 || error("solid energy balance")
    x=collect(range(-spec.width/2,spec.width/2;length=151))
    y=collect(range(-spec.height/2,spec.height/2;length=101));ids=1:4:length(result.times)
    samples,valid=sample_solid_history(result,x,y,ids)
    diag=copy(result.diagnostics);diag["frequency_Hz"]=spec.frequency
    record=CanonicalRecord(x,y,result.times[ids],samples,valid,zeros(Float32,0,0),diag)
    geometry=Dict("type"=>"solid","outlines"=>[[collect(p) for p in line] for line in solid_lens_outlines(spec)],
        "focus"=>first(spec.bricks).length/2+spec.focus_distance,"lens_exit"=>first(spec.bricks).length/2)
    payload=CanonicalData.record_payload(record,name,geometry)
    payload["specification"]=experiment_toml(spec)
    payload["mesh"]=Dict("nodes_m"=>CanonicalData.pack(result.nodes),"triangles"=>[collect(t) for t in eachcol(result.triangles)])
    if !isempty(cache_dir)
        mkpath(cache_dir);write(path,CanonicalData.transcode(CanonicalData.GzipCompressor,codeunits(JSON.json(payload))))
    end
    payload
end

function unpack_focus(payload)
    bytes=CanonicalData.transcode(CanonicalData.ZlibDecompressor,CanonicalData.base64decode(payload["values"]))
    reshape(collect(reinterpret(Float32,bytes)),length(payload["x"]),length(payload["y"]),length(payload["times"]))
end

function focus_intensity(payload)
    samples=unpack_focus(payload);times=payload["times"];total=zeros(size(samples,1),size(samples,2))
    for t in 2:length(times)
        total .+= (times[t]-times[t-1])/2 .* (samples[:,:,t-1].^2+samples[:,:,t].^2)
    end
    total
end

function measured_focus(payload,nominal)
    x=payload["x"];y=payload["y"];intensity=focus_intensity(payload)
    # Look around the nominal plane, not at narrow near-field hot spots just
    # outside individual ligaments. The window is fixed before measuring.
    wavelength=payload["diagnostics"]["shear_speed_m_s"]/payload["diagnostics"]["frequency_Hz"]
    ids=findall(i->abs(x[i]-nominal)<=wavelength/2 &&
        abs(y[argmax(intensity[i,:])])<=wavelength/4,eachindex(x))
    widths=[MetaNDT.profile_width(y,intensity[i,:]) for i in ids]
    finite=findall(isfinite,widths);isempty(finite)&&error("no resolved central STG waist")
    j=finite[argmin(widths[finite])];i=ids[j]
    (x=x[i],width=widths[j],nominal=nominal,window=[nominal-wavelength/2,nominal+wavelength/2])
end

function focus_profile(payload,plane)
    x=payload["x"];intensity=focus_intensity(payload)
    i=clamp(searchsortedlast(x,plane),1,length(x)-1);q=(plane-x[i])/(x[i+1]-x[i])
    Dict("name"=>payload["name"],"x"=>payload["y"],"y"=>collect((1-q).*intensity[i,:]+q.*intensity[i+1,:]))
end

function prepare_focus()
    cache=get(ENV,"META_NDT_DESIGN_CACHE","")
    design=isfile(cache) ? deserialize(cache) : Base.invokelatest(design_stg_lens,SolidLensExperiment())
    default=SolidLensExperiment()
    experiment_toml(remake_experiment(design.experiment;bricks=default.bricks))==experiment_toml(default) || error("cached STG design belongs to another experiment")
    # One teaching comparison: uniform versus phase-graded STG. Straight
    # ligaments remain available in the research notebook and library.
    specs=[solid_preset(design,id) for id in (:uniform,:focused)]
    names=["Одинаковые STG-кирпичики","STG-кирпичики · подобранная раскладка"]
    cases=Any[]; profiles=Any[]
    cache_dir=get(ENV,"META_NDT_FOCUS_CASE_CACHE","")
    for (spec,name) in zip(specs,names)
        println("Preparing STG specimen: ",name);flush(stdout)
        payload=focus_case(spec,name;cache_dir)
        payload["diagnostics"]["shear_speed_m_s"]=last(solid_wave_speeds(spec))
        push!(cases,payload)
        GC.gc()
    end
    nominal=first(specs[end].bricks).length/2+specs[end].focus_distance
    focus=measured_focus(last(cases),nominal)
    for payload in cases
        payload["geometry"]["focus"]=focus.x
        payload["geometry"]["design_focus"]=nominal
        push!(profiles,focus_profile(payload,focus.x))
    end
    widths=[MetaNDT.profile_width(p["x"],p["y"]) for p in profiles]
    widths[end]<.7widths[1] || error("STG does not resolve a substantially narrower spot than identical cells: $widths")
    println("Measured STG focus: ",focus,"; profile widths: ",widths)
    CanonicalData.save_bundle("focus",Dict("title"=>"Собирает ли порядок STG-ячеек волну?",
        "question"=>"Кирпичики соединены с алюминиевым массивом по торцам. Пустоты имеют свободные стенки. Сравните одинаковые STG с подобранной фазовой раскладкой.",
        "instruction"=>"Сравните одинаковые STG с подобранной раскладкой. Проследите поперечный импульс, затем включите его накопленный след. Жёлтая линия проходит через измеренную перетяжку пучка.",
        "model"=>"Полный time-domain P1 FEM связанного упругого тела: обе компоненты смещения, плоская деформация, свободные вырезы, Newmark. Это наша STG-стенка, не прямые перемычки из статьи Su.",
        "limit"=>"На карте uᵧ, не выделенная SV-мощность. Профиль ∫uᵧ²dt не доказывает разрешение дефектов. Фокус и преимущество STG не предполагаются заранее: сравните рассчитанные поля и контроль.",
        "unit"=>"nm","coordinate_unit"=>"m","source"=>"Литературный ориентир: Su, Lu & Norris, JAP 2018",
        "url"=>"https://doi.org/10.1063/1.5007731",
        "sets"=>[Dict("label"=>"Одинаковые ячейки и фазовая раскладка","frequency"=>140000.,"cases"=>cases)],
        "focus_measurement"=>Dict("plane_m"=>focus.x,"nominal_plane_m"=>nominal,"search_window_m"=>focus.window,
            "profile_widths_m"=>widths,"method"=>"minimum central-lobe FWHM of integral uy^2 dt within the fixed window; not the nominal phase-design plane"),
        "profile"=>Dict("series"=>profiles)))
end
