# Real Pluto bond lifecycle. No browser emulation or notebook writes.
using Pluto, Test
session=Pluto.ServerSession(options=Pluto.Configuration.from_flat_kwargs(
    disable_writing_notebook_files=true,launch_browser=false))
notebook=Pluto.SessionActions.open(session,joinpath(@__DIR__,"..","notebooks","virtual_lab.jl");run_async=false)
try
    evaluate(expr)=Pluto.WorkspaceManager.eval_fetch_in_workspace((session,notebook),expr)
    function send(command)
        notebook.bonds[:lab_command]=Dict("value"=>command)
        Pluto.set_bond_values_reactive(;session,notebook,bound_sym_names=[:lab_command],run_async=false)
        @test all(!c.errored for c in notebook.cells)
    end
    @testset "Mounted workbench in real Pluto" begin
        @test all(!c.errored for c in notebook.cells)
        controls=only(filter(c->occursin("@bind lab_command",c.code),notebook.cells))
        @test :lab_command in Pluto.WorkspaceManager.get_bond_names((session,notebook),controls.cell_id)
        @test evaluate(:(isnothing(lab_session.current)))
        @test evaluate(:(Base.get_extension(MetaNDT,:MetaNDTGridapExt)===nothing))
        # Browser/MessagePack delivers JS integral numbers as Float64.
        send(Dict("action"=>"run","nonce"=>1.0,"settings"=>Dict("experiment"=>"cloak")))
        @test evaluate(:(isempty(lab_session.error)))
        @test evaluate(:(lab_session.current.id))==1
        @test evaluate(:(lab_session.current.settings.frequency))==10000
        send(Dict("action"=>"pin","nonce"=>2.0,"id"=>1.0,"note"=>"Первый опыт"))
        @test evaluate(:(length(lab_session.pinned)))==1
        send(Dict("action"=>"run","nonce"=>3,"settings"=>Dict("frequency"=>20000)))
        @test evaluate(:(lab_session.current.id))==2
        @test evaluate(:(lab_session.current.settings.frequency))==20000
        @test evaluate(:(only(lab_session.pinned).settings.frequency))==10000
        send(Dict("action"=>"restore","nonce"=>4,"id"=>1))
        @test evaluate(:(lab_session.current.id))==1
        @test evaluate(:(lab_session.current.note))=="Первый опыт"
        @test evaluate(:(lab_session.next_id))==3
        send(Dict("action"=>"probe","nonce"=>5.0,"id"=>1.0,"case"=>2.0,"point_mm"=>[12.0,3.0]))
        @test evaluate(:(isempty(lab_session.error)))
        @test evaluate(:(lab_session.current.id))==1
        @test evaluate(:(lab_session.next_id))==3 # observing did not create a solve/run
        @test evaluate(:(lab_session.current.probe["point_mm"]))==[12.,3.]
        @test evaluate(:(lab_session.current.probe["unit"]))=="Pa"
        @test evaluate(:(length(lab_session.current.probe["time_us"])))==241
        @test evaluate(:(isnothing(only(lab_session.pinned).probe))) # old snapshot untouched
        send(Dict("action"=>"probe","nonce"=>6.0,"id"=>1.0,"case"=>2.0,"point_mm"=>[0.0,0.0]))
        @test evaluate(:(!isempty(lab_session.error)))
        @test evaluate(:(lab_session.current.probe["point_mm"]))==[12.,3.]
        @test evaluate(:(lab_session.current.id))==1
        @test evaluate(:(occursin("meta-workbench-data",repr(MIME"text/html"(),WorkbenchUI.update(lab_session)))))
        # Regression: check the actual command response, not a fresh update()
        # after restore (which would miss the old compact-response reload bug).
        @test evaluate(:(haskey(process!(lab_session,Dict("action"=>"probe","nonce"=>7,"id"=>1,"case"=>2,"point_mm"=>[12.,3.])).payload["current"],"data")))
        @test evaluate(:(haskey(process!(lab_session,Dict("action"=>"pin","nonce"=>8,"id"=>1)).payload["current"],"data")))
        # The new water impulse follows the same real bond lifecycle, but
        # carries physical time histories rather than the harmonic 241 phases.
        send(Dict("action"=>"run","nonce"=>9.,"settings"=>Dict("experiment"=>"cloak","regime"=>"pulse")))
        @test evaluate(:(isempty(lab_session.error)))
        @test evaluate(:(lab_session.current.id))==3
        @test evaluate(:(lab_session.current.data["field"]["domain"]))=="time"
        @test evaluate(:(length(lab_session.current.data["field"]["frame_times_us"])))==141
        send(Dict("action"=>"probe","nonce"=>10.,"id"=>3.,"case"=>2.,"point_mm"=>[15.,6.]))
        @test evaluate(:(isempty(lab_session.error)))
        @test evaluate(:(lab_session.current.probe["domain"]))=="time"
        @test evaluate(:(length(lab_session.current.probe["time_us"])))==921
        @test evaluate(:(lab_session.next_id))==4
        @test evaluate(:(Base.get_extension(MetaNDT,:MetaNDTGridapExt)===nothing))
        send(Dict("action"=>"pin","nonce"=>11.,"id"=>3.))
        send(Dict("action"=>"restore","nonce"=>12.,"id"=>1.))
        @test evaluate(:(lab_session.current.settings.regime))==:harmonic
        send(Dict("action"=>"restore","nonce"=>13.,"id"=>3.))
        @test evaluate(:(lab_session.current.settings.regime))==:pulse
        @test evaluate(:(lab_session.current.probe["point_mm"]))==[15.,6.]
    end
finally
    Pluto.SessionActions.shutdown(session,notebook;verbose=false)
end
