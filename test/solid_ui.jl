using Test, MetaNDT, Gridap, GridapGmsh, Gmsh, LinearAlgebra
BLAS.set_num_threads(1)
include(joinpath(@__DIR__,"..","src","SolidLensUI.jl"))
using .SolidLensUI
@testset "solid client and controls" begin
    d=cached_design()
    @test cached_design() === d
    c=comparison_cases(d,:focused)
    @test length(c.results) == 4
    @test c.selected == 4
    @test c.results[2].experiment.scenario == :straight
    @test cached_solid(d.experiment) === c.results[4]
    @test length(comparison_cases(d,:bulk).results) == 3
    html=repr(MIME"text/html"(),lens_view(c))
    @test occursin("не приход импульса",html)
    @test occursin("Прямые перемычки",html)
    @test occursin("не помещается в сечение",html)
    @test occursin("power_balance_relative",html)
    notebook=read(joinpath(@__DIR__,"..","notebooks","solid_stg_lens.jl"),String)
    @test occursin("solid_examples()",notebook)
    @test !occursin("Child(\"mesh",notebook)
    @test !occursin("Child(\"amplitude",notebook)
    @test occursin("cached_pulse",notebook)
end

@testset "selected geometry owns its straight control" begin
    s=SolidLensExperiment(bricks=[SinusoidalBrick(amplitude=A) for A in (.0012,.0018,.0024,.0036,.0042)],
        width=.060,height=.049,source_x=-.023,source_width=.001,focus_distance=.012)
    d=LensDesign(s,s.bricks,ones(ComplexF64,5),collect(1:5),zeros(5))
    @test solid_preset(d,:scrambled).bricks != s.bricks
    for id in (:uniform,:scrambled,:missing)
        c=comparison_cases(d,id); ref=c.results[2].experiment; chosen=c.results[c.selected].experiment
        @test ref.scenario == :straight
        @test ref.bricks == chosen.bricks
        @test ref.missing_cells == chosen.missing_cells
        @test c.results[2].diagnostics["solid_area_m2"] ≈ c.results[c.selected].diagnostics["solid_area_m2"] rtol=1e-10
        id in (:scrambled,:missing) && @test length(c.results) == 5
    end
end
