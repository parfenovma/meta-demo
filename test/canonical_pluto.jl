# Exercise the real Pluto bond lifecycle; do not execute the offline preparer.
using Pluto, Test
session=Pluto.ServerSession(options=Pluto.Configuration.from_flat_kwargs(
    disable_writing_notebook_files=true,launch_browser=false))
notebook=Pluto.SessionActions.open(session,joinpath(@__DIR__,"..","notebooks","canonical_experiments.jl");run_async=false)
try
    @testset "Five canonical cards in real Pluto" begin
        @test all(!c.errored for c in notebook.cells)
        for id in ("mass","bulk","absorber","cloak","focus")
            notebook.bonds[:canonical_lesson]=Dict("value"=>id)
            Pluto.set_bond_values_reactive(;session,notebook,bound_sym_names=[:canonical_lesson],run_async=false)
            @test all(!c.errored for c in notebook.cells)
            @test Pluto.WorkspaceManager.eval_fetch_in_workspace((session,notebook),:(canonical_lesson))==id
            @test Pluto.WorkspaceManager.eval_fetch_in_workspace((session,notebook),:(Base.get_extension(CanonicalUI.CanonicalData.MetaNDT,:MetaNDTGridapExt)===nothing))
        end
    end
finally
    Pluto.SessionActions.shutdown(session,notebook;verbose=false)
end
