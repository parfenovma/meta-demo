using Test, MetaNDT
include(joinpath(@__DIR__,"..","src","CoatedCylinderUI.jl"))
using .CoatedCylinderUI

@testset "coating client, paired fields and bounded caches" begin
    s=CoatedCylinderExperiment()
    c=cached_coated_comparison(s); scan=cached_coated_sweep(s)
    @test length(c) == 3
    @test cached_coated_comparison(s) === c
    @test cached_coated_sweep(remake_experiment(s;frequency=40e3)) === scan
    html=repr(MIME"text/html"(),cloak_view(c,scan))
    @test occursin("Голая трубка",html)
    @test occursin("Трубка + силикон",html)
    @test occursin("Общая линейная шкала",html)
    @test occursin("Гармоническая фаза — не приход импульса",html)
    @test occursin("воздух",html)
    @test occursin("σпокр / σгол",html)
    @test occursin("invalidation.then",html)
    @test occursin("шаг сгущён до 0.5 Hz",html)
    @test occursin("не гарантия отсутствия других узких пиков",html)
    @test length(scan.frequencies) > 12
    @test any(scan.ratio .> 1)
    @test Base.get(CoatedControls(s)) == Dict("frequency"=>10000.,"thickness"=>1.)
    @test occursin("form.onsubmit",repr(MIME"text/html"(),CoatedControls(s)))
    @test occursin("Number(o.value)===Number(value)",repr(MIME"text/html"(),CoatedControls(s)))
    custom=CoatedControls(remake_experiment(s;coating_thickness=.0011))
    @test occursin("value='$(Base.get(custom)["thickness"])' selected",repr(MIME"text/html"(),custom))
    @test occursin("scattering_width",read(joinpath(@__DIR__,"..","src","CoatedCylinderUI.jl"),String))
    bad=copy(c);bad[2]=simulate(remake_experiment(s;scenario=:bare,incident_pressure=2))
    @test_throws ArgumentError cloak_view(bad,scan)
    @test_throws ArgumentError cloak_view(c,coated_frequency_sweep(remake_experiment(s;coating_thickness=.0012),[10000,20000]))
    for thickness in (.0008,.001,.0012)
        s2=remake_experiment(s;coating_thickness=thickness,frequency=60e3)
        c2=cached_coated_comparison(s2); scan2=cached_coated_sweep(s2)
        @test !isempty(repr(MIME"text/html"(),cloak_view(c2,scan2)))
        @test all(r.experiment.frequency == s2.frequency for r in c2)
    end
    @test length(CoatedCylinderUI.COMPARISONS) <= 8
    @test length(CoatedCylinderUI.SWEEPS) <= 4
    notebook=read(joinpath(@__DIR__,"..","notebooks","coated_cylinder.jl"),String)
    @test occursin("cached_coated_sweep",notebook)
    @test occursin("CoatedControls",notebook)
    @test !occursin("Child(\"mesh",notebook)
    @test !occursin("Gridap",notebook) # does not unnecessarily load the full 2D mesher
end
