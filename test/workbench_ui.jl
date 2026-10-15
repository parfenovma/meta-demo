using Test, MetaNDT, JSON
include(joinpath(@__DIR__,"..","src","WorkbenchUI.jl"))
using .WorkbenchUI

@testset "Workbench: cold landing, no numerical backend" begin
    @test Base.get_extension(MetaNDT,:MetaNDTGridapExt)===nothing
    html=repr(MIME"text/html"(),WorkbenchControls())
    @test occursin("Открыть опыт",html)
    @test occursin("MutationObserver",html)
    @test occursin("observer.disconnect()",html)
    @test occursin("event.target!==root",html)
    @test !occursin("__CATALOG__",html)
    @test Base.get_extension(MetaNDT,:MetaNDTGridapExt)===nothing
    s=WorkbenchSession()
    @test isnothing(s.current)
    @test isempty(s.pinned)
    @test Base.get(WorkbenchControls())["action"]=="init"
    for value in (Dict("experiment"=>"unknown"),Dict("frequency"=>NaN),
            Dict("frequency"=>100),Dict("thickness"=>.002),
            Dict("experiment"=>"solid","frequency"=>120000),
            Dict("experiment"=>"solid","preset"=>"stripes"),
            Dict("experiment"=>"solid","polarization"=>"unknown"))
        @test_throws ArgumentError WorkbenchUI.settings(value)
    end
end

s=WorkbenchSession()
command(action,nonce;kwargs...)=Dict{String,Any}("action"=>action,"nonce"=>nonce,(String(k)=>v for (k,v) in kwargs)...)
@testset "Workbench: real tube adapter and preserved snapshots" begin
    process!(s,command("run",1.0;settings=Dict("experiment"=>"cloak")))
    @test isempty(s.error)
    @test s.current.settings.frequency==10000
    data=s.current.data
    calculation=WorkbenchUI.Calculation(data,s.current.solutions)
    @test data["kind"]=="cloak"
    # Shared sparse forms reorder floating-point sums (~2e-7 dB here).
    # Preserve the frozen reference; the independent Bessel tests remain the
    # physics gate, not bitwise equality of two equivalent assembly orders.
    @test data["metric"]["value"]≈-24.578286119267005 atol=1e-6
    @test data["field"]["count"]==81
    @test length(data["field"]["cases"])==3
    @test length(data["curve"]["x"])>400
    @test any(>(0),data["curve"]["y"]) # enriched air resonances remain visible
    @test data["curve"]["reference"]==0
    @test length(data["specifications"])==3
    @test all(occursin("frequency = 10000.0",toml) for toml in data["specifications"])
    @test Base.get_extension(MetaNDT,:MetaNDTGridapExt)===nothing
    note="Ожидал улучшения. <script>alert('not executable')</script>"
    process!(s,command("pin",2;id=s.current.id,note))
    first=s.current
    @test only(s.pinned).note==note
    html=repr(MIME"text/html"(),WorkbenchUI.update(s))
    @test !occursin("<script>alert",html)
    @test occursin("\\u003cscript>",html)
    process!(s,command("run",3;settings=Dict("frequency"=>20000,"thickness"=>.0008)))
    @test isempty(s.error)
    @test s.current.id!=first.id
    @test only(s.pinned).settings.frequency==10000
    @test only(s.pinned).data===first.data
    process!(s,command("restore",4;id=first.id);runner=_ -> error("restore must not solve"))
    @test s.current===first
    @test isempty(s.error)
    process!(s,command("run",4;settings=Dict("frequency"=>30000));runner=_ -> error("duplicate command must not run"))
    @test s.current===first
    process!(s,command("init",0))
    @test s.handled==4
    process!(s,command("run",3.0;settings=Dict());runner=_ -> error("remount must not replay an old command"))
    @test s.current===first
    process!(s,command("run",5;settings=Dict("frequency"=>30000));runner=_ -> error("numerical test failure"))
    @test occursin("numerical test failure",s.error)
    @test s.current===first
    process!(s,command("pin",6;id=first.id,note="Обновлённая заметка"))
    @test length(s.pinned)==1
    @test only(s.pinned).note=="Обновлённая заметка"
    for i in 1:5
        # Same real result reused only to exercise shelf capacity, not new physics.
        process!(s,command("run",6+2i-1;settings=Dict());runner=_ -> calculation)
        process!(s,command("pin",6+2i;id=s.current.id))
    end
    @test length(s.pinned)==6
    ids=getfield.(s.pinned,:id)
    process!(s,command("run",17;settings=Dict());runner=_ -> calculation)
    seventh=s.current
    process!(s,command("pin",18;id=seventh.id))
    @test length(s.pinned)==6
    @test getfield.(s.pinned,:id)==ids
    @test occursin("полка заполнена",s.error)
    process!(s,command("remove",19;id=ids[2]))
    @test length(s.pinned)==5
    @test s.current===seventh
    @test ids[2] ∉ getfield.(s.pinned,:id)
    process!(s,command("restore",20;id=999))
    @test !isempty(s.error)
    @test s.current===seventh
end

@testset "Point sensor uses retained water solution, not display pixels/caches" begin
    r=s.current; calls=Ref(0)
    only_probe=_->(calls[]+=1;error("sensor must not run FEM"))
    empty!(WorkbenchUI.CoatedCylinderUI.COMPARISONS)
    process!(s,command("probe",20.1;id=r.id,case=2.,point_mm=[12.,3.]);runner=only_probe)
    @test !isempty(s.error) # fractional command sequence rejected
    process!(s,command("probe",21.;id=r.id,case=2.,point_mm=[12.,3.]);runner=only_probe)
    @test isempty(s.error)
    @test calls[]==0
    @test s.current.id==r.id
    @test s.current.data===r.data
    p=s.current.probe
    @test p["point_mm"]==[12.,3.]
    @test p["unit"]=="Pa"
    @test length(p["time_us"])==241
    A=coated_pressure(r.solutions[3],(.012,.003))
    signal=p["cases"][3]["signals"]["pressure"]
    @test signal["phasor"]≈[real(A),imag(A)]
    @test signal["values"]≈harmonic_trace(A,r.settings.frequency,p["time_us"]/1e6)
    @test p["cases"][1]["signals"]["scattered"]["values"]==zeros(241)
    process!(s,command("pin",22;id=r.id,note="sensor snapshot"))
    pinned=only(filter(p->p.id==r.id,s.pinned))
    process!(s,command("probe",23;id=r.id,case=2,point_mm=[13.,4.])); moved=s.current
    @test isempty(s.error)
    @test pinned.probe["point_mm"]==[12.,3.]
    @test s.current.probe["point_mm"]==[13.,4.]
    for (nonce,point) in ((24,[0.,0.]),(25,[26.,0.]),(26,[NaN,0.]))
        process!(s,command("probe",nonce;id=r.id,case=2,point_mm=point))
        @test !isempty(s.error)
        @test s.current===moved
    end
    process!(s,command("probe",27;id=999,case=2,point_mm=[12.,3.]))
    @test !isempty(s.error)
    @test s.current===moved
    process!(s,command("restore",28;id=r.id);runner=only_probe)
    @test s.current.probe["point_mm"]==[12.,3.]
    @test calls[]==0
    # Empty water can host the sensor at the origin; the solid object cannot.
    process!(s,command("probe",29;id=r.id,case=0,point_mm=[0.,0.]))
    @test isempty(s.error)
    @test s.current.probe["cases"][1]["valid"]
    @test !s.current.probe["cases"][3]["valid"]
    @test isnothing(s.current.probe["cases"][3]["signals"])
end

@testset "Workbench: lazy real solid adapter, same scientific controls" begin
    process!(s,command("run",30;settings=Dict("experiment"=>"solid","regime"=>"harmonic")))
    @test isempty(s.error)
    @test s.current.settings.experiment==:solid
    d=s.current.data
    @test d["kind"]=="solid"
    @test d["metric"]["unit"]=="mm"
    @test d["field"]["kind"]=="solid"
    @test length(d["field"]["cases"])>=4
    @test all(c["diag"]["input_power_W_m"]>0 for c in d["field"]["cases"])
    @test all(c["diag"]["linear_residual_relative"]<1e-8 for c in d["field"]["cases"])
    @test length(d["curve"]["x"])==length(d["curve"]["y"])
    @test d["curve"]["y"]==d["field"]["cases"][d["field"]["selected"]+1]["profile"]
    @test length(d["specifications"])==length(d["field"]["cases"])
    @test any(occursin("калибров",lowercase(file["name"]))||file["name"]=="stg_calibration.csv" for file in d["downloads"])
    @test occursin("FWHM",d["metric"]["label"])
    @test Base.get_extension(MetaNDT,:MetaNDTGridapExt)!==nothing
    r=s.current
    @test isnothing(r.probe) # no water sensor silently carried into solid physics
    empty!(WorkbenchUI.SolidLensUI.FIELDS)
    process!(s,command("probe",31.;id=r.id,case=d["field"]["selected"],point_mm=[40.,1.]);runner=_ -> error("must not solve"))
    @test isempty(s.error)
    probe=s.current.probe; index=d["field"]["selected"]+1
    ux,uy=solid_displacement(r.solutions[index],(.040,.001))
    @test probe["unit"]=="nm"
    @test probe["cases"][index]["signals"]["uy"]["phasor"]≈[real(uy),imag(uy)]*1e9
    @test probe["cases"][index]["signals"]["ux"]["phasor"]≈[real(ux),imag(ux)]*1e9
    @test s.current.solutions===r.solutions
    # Keep a physical location when changing parameters within the same physics.
    process!(s,command("run",32;settings=Dict("experiment"=>"solid","regime"=>"harmonic"));runner=_ -> WorkbenchUI.Calculation(r.data,r.solutions))
    @test s.current.probe["point_mm"]==[40.,1.]
    @test s.current.probe["cases"][index]["signals"]["uy"]["phasor"]≈[real(uy),imag(uy)]*1e9
end
