using Test, MetaNDT, Gridap, GridapGmsh, Gmsh
include(joinpath(@__DIR__,"..","src","CylinderUI.jl"))
using .CylinderUI

@testset "matched controls and CAD validation" begin
    s=remake_experiment(example_experiment(:stg_single);scenario=:rigid,
        duration=30e-6,frame_count=2)
    scan=frequency_sweep(s,[100e3];include_straight_reference=true)
    @test scan.comparisons[1][4].experiment.scenario == :elastic
    @test !isempty(scan.comparisons[1][4].solid_nodes)
    cases=cached_example_comparison(:stg_single,s)
    @test cases[4].experiment.scenario == :elastic
    @test_throws ArgumentError remake_experiment(s;shape=SinusoidalBrick(end_margin=1e-10))
    @test validate_experiment(remake_experiment(s;shape=SinusoidalBrick(end_margin=0.0))) isa CylinderExperiment
end
