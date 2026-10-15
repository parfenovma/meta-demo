using Test, MetaNDT, Gridap, GridapGmsh, Gmsh, LinearAlgebra, Base64, CodecZlib, JSON
include(joinpath(@__DIR__,"..","src","WorkbenchUI.jl"))
using .WorkbenchUI

@testset "Real STG transient through shared workbench" begin
    s=WorkbenchSession()
    process!(s,Dict("action"=>"run","nonce"=>1,"settings"=>Dict("experiment"=>"solid")))
    @test isempty(s.error)
    r=s.current; d=r.data; f=d["field"]
    @test r.settings.regime==:pulse
    @test f["domain"]=="time"
    @test length(r.solutions)==2
    @test getfield.(getfield.(r.solutions,:experiment),:scenario)==[:straight,:stg]
    @test all(==(0),f["source_drive"][f["source_times_us"].>=f["source_end_us"]])
    for (pulse,field) in zip(r.solutions,f["cases"])
        raw=transcode(ZlibDecompressor,base64decode(field["frames_y"]))
        restored=reshape(ltoh.(reinterpret(Int16,raw)).*(f["limit_nm"]/1e9/32767),size(pulse.displacement_y))
        @test maximum(abs,restored-pulse.displacement_y)*1e9<=f["display_error_nm"]*1.00001
    end
    for pulse in r.solutions
        @test all(iszero,pulse.displacement_x[:,1]) && all(iszero,pulse.displacement_y[:,1])
        @test maximum(abs,pulse.displacement_y)>0
        @test pulse.diagnostics["energy_balance_relative"]<1e-7
        @test length(pulse.times)>length(pulse.frame_times)
        trace=solid_trace(pulse,(.040,.001))
        @test trace.times===pulse.times
        @test trace.ux[1]==trace.uy[1]==0
        @test maximum(abs,trace.uy)>0
        # Every displayed state and sensor trace refer to the same Newmark step.
        for j in (2,40,80,141)
            k=argmin(abs.(trace.times.-pulse.frame_times[j]))
            ids,w=MetaNDT.solid_point_weights(pulse,(.040,.001))
            expected=sum(wi*pulse.displacement_y[i,j] for (i,wi) in zip(ids,w))
            @test trace.uy[k]≈expected rtol=2e-6 atol=1e-25
        end
        @test norm(trace.uy[600:end])>0 # evolution persists after source switch-off
    end
    before=r.solutions
    probe_update=process!(s,Dict("action"=>"probe","nonce"=>2,"id"=>r.id,"case"=>1,"point_mm"=>[40.,1.]);runner=_ -> error("probe cannot solve"))
    @test haskey(probe_update.payload["current"],"data")
    @test isempty(s.error)
    @test s.current.solutions===before
    p=s.current.probe
    @test p["domain"]=="time"
    @test length(p["time_us"])==length(last(before).times)
    @test !haskey(p["cases"][2]["signals"]["uy"],"phasor")
    @test p["cases"][2]["signals"]["uy"]["values"]≈solid_trace(last(before),(.040,.001)).uy*1e9
    pin_update=process!(s,Dict("action"=>"pin","nonce"=>3,"id"=>r.id))
    @test haskey(pin_update.payload["current"],"data")
    process!(s,Dict("action"=>"probe","nonce"=>4,"id"=>r.id,"case"=>1,"point_mm"=>[50.,1.]))
    process!(s,Dict("action"=>"restore","nonce"=>5,"id"=>r.id);runner=_ -> error("restore cannot solve"))
    @test isempty(s.error)
    @test s.current.probe["point_mm"]==[40.,1.]
    @test only(s.pinned).solutions===before
    @test haskey(WorkbenchUI.update(s).payload["current"],"data") # reload after a probe must be self-contained
    bulk=WorkbenchUI.solid_pulse_run(WorkbenchUI.settings(Dict("experiment"=>"solid","preset"=>"bulk")))
    @test length(bulk.solutions)==1
    @test only(bulk.solutions).experiment.scenario==:solid
    @test occursin("без прорезей",join(bulk.data["method"]))
    println("STG pulse: ",[(nodes=size(p.nodes,2),frames=length(p.frame_times),steps=length(p.times),memory_MiB=p.diagnostics["retained_history_bytes"]/2^20,balance=p.diagnostics["energy_balance_relative"]) for p in before])
    println("Browser payload MiB: ",sizeof(JSON.json(d))/2^20)
end
