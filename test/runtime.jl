# Fail early on broken manifest/stdlib dependencies, before expensive FEM tests.
using Test

@testset "Pluto runtime" begin
    @test (@eval using Pluto) === nothing
    session = Pluto.ServerSession(options=Pluto.Configuration.from_flat_kwargs(
        disable_writing_notebook_files=true, launch_browser=false))
    @test session isa Pluto.ServerSession
end
