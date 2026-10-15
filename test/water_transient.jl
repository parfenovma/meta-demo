using Test,MetaNDT,JSON,Base64,CodecZlib
include(joinpath(@__DIR__,"..","src","WorkbenchUI.jl"))
using .WorkbenchUI

@testset "Coated tube impulse in the shared workbench" begin
    @test WorkbenchUI.catalog()["defaults"]["cloak"]["regime"]=="pulse"
    session=WorkbenchSession()
    command=Dict("action"=>"run","nonce"=>1.,"settings"=>Dict("experiment"=>"cloak","regime"=>"pulse"))
    process!(session,command)
    @test isempty(session.error)
    run=session.current;data=run.data;field=data["field"]
    @test field["domain"]=="time"
    @test length(run.solutions)==3
    @test [r.experiment.model.scenario for r in run.solutions]==[:empty,:bare,:coated]
    @test all(iszero,field["source_drive"][field["source_times_us"].>=field["source_end_us"]])
    @test Base.get_extension(MetaNDT,:MetaNDTGridapExt)===nothing
    for (result,display) in zip(run.solutions,field["cases"])
        @test result.diagnostics["energy_balance_relative"]<1e-7
        raw=transcode(ZlibDecompressor,base64decode(display["frames_scattered"]))
        values=reshape(ltoh.(reinterpret(Int16,raw)).*(field["limits"]["scattered"]/32767),field["count"]^2,:)
        @test all(iszero,values[:,1])
        xs=range(-.025,.025;length=field["count"])
        ix,iy=81,63;point=(xs[ix],xs[iy])
        expected=coated_trace(result,point;indices=result.frame_steps).scattered
        @test maximum(abs,vec(values[(iy-1)*field["count"]+ix,:])-expected)<=field["limits"]["scattered"]/65534*1.0001
    end
    probe_update=process!(session,Dict("action"=>"probe","nonce"=>2.,"id"=>run.id,"case"=>2.,"point_mm"=>[15.,6.]);runner=_ -> error("microphone must not solve"))
    @test isempty(session.error)
    @test haskey(probe_update.payload["current"],"data")
    @test session.current.solutions===run.solutions
    probe=session.current.probe
    @test probe["domain"]=="time" && probe["unit"]=="Pa"
    @test length(probe["time_us"])>length(field["frame_times_us"])
    @test !haskey(probe["cases"][3]["signals"]["pressure"],"phasor")
    @test probe["cases"][3]["signals"]["pressure"]["values"]≈coated_trace(run.solutions[3],(.015,.006)).pressure
    process!(session,Dict("action"=>"pin","nonce"=>3,"id"=>run.id))
    process!(session,Dict("action"=>"probe","nonce"=>4,"id"=>run.id,"case"=>2,"point_mm"=>[0.,0.]))
    @test !isempty(session.error)
    @test session.current.probe===probe
    process!(session,Dict("action"=>"probe","nonce"=>5,"id"=>run.id,"case"=>0,"point_mm"=>[0.,0.]))
    @test isempty(session.error)
    @test session.current.probe["cases"][1]["valid"] && !session.current.probe["cases"][3]["valid"]
    process!(session,Dict("action"=>"restore","nonce"=>6,"id"=>run.id);runner=_ -> error("restore must not solve"))
    @test isempty(session.error)
    @test session.current.probe["point_mm"]==[15.,6.]
    println("Water pulse UI: ",length(field["frame_times_us"])," frames, ",length(probe["time_us"])," steps, payload MiB ",sizeof(JSON.json(data))/2^20)
end
