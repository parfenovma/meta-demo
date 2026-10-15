# Real Pluto bond/reactivity integration, without a browser or notebook writes.
# This verifies transport-to-computation; it does not claim to test GUI clicks.
using Pluto, Test

session=Pluto.ServerSession(options=Pluto.Configuration.from_flat_kwargs(
    disable_writing_notebook_files=true,launch_browser=false))
notebook=Pluto.SessionActions.open(session,
    joinpath(@__DIR__,"..","notebooks","coated_cylinder.jl");run_async=false)
try
    evaluate(expr)=Pluto.WorkspaceManager.eval_fetch_in_workspace((session,notebook),expr)
    @testset "actual Pluto initialization and submitted parameter snapshots" begin
        @test all(!c.errored for c in notebook.cells)
        controls_cell=only(filter(c->occursin("@bind controls",c.code),notebook.cells))
        @test :controls in Pluto.WorkspaceManager.get_bond_names((session,notebook),controls_cell.cell_id)
        @test evaluate(:(controls["frequency"])) == 10000.0
        @test evaluate(:(experiment.frequency)) == 10000.0
        notebook.bonds[:controls]=Dict("value"=>Dict("frequency"=>20000.0,"thickness"=>1.0))
        Pluto.set_bond_values_reactive(;session,notebook,bound_sym_names=[:controls],run_async=false)
        @test all(!c.errored for c in notebook.cells)
        @test evaluate(:(controls["frequency"])) == 20000.0
        @test evaluate(:(experiment.frequency)) == 20000.0
        @test evaluate(:(all(r.experiment.frequency==20000.0 for r in comparison)))
        @test evaluate(:(occursin("\"frequency\":20.0",repr(MIME"text/html"(),cloak_view(comparison,sweep)))))
    end
finally
    Pluto.SessionActions.shutdown(session,notebook;verbose=false)
end
