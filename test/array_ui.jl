using Test, MetaNDT, Gridap, GridapGmsh, Gmsh, JSON
include(joinpath(@__DIR__,"..","src","CylinderUI.jl"))
using .CylinderUI

@testset "array client contracts" begin
    for columns in 1:3, rows in 1:3, radius in (.003,.005), pitch in (.014,.024),
        frequency in (30e3,100e3), source_x in (-.060,-.045), source_y in (-.020,.020)
        s=CylinderExperiment(centers=cylinder_lattice(columns,rows,pitch),radius=radius,
            frequency=frequency,source=(source_x,source_y),
            sensors=[(.040,0.0),(-.040,.030),(.060,-.030)],
            mesh_size=min(.0015,1480/(14frequency)))
        @test validate_experiment(s) === s
    end
    s=CylinderExperiment(radius=.004,centers=cylinder_lattice(2,1,.018),duration=80e-6,frame_count=3)
    results=cached_comparison(s)
    @test cached_comparison(remake_experiment(s)) === results
    @test results[3].experiment.centers !== s.centers
    s.centers[1]=(-.020,0.0)
    @test results[3].experiment.centers == [(-.009,0.0),(.009,0.0)]
    s.centers[1]=(-.009,0.0)
    html=repr(MIME"text/html"(),comparison_view(results))
    payload=JSON.parse(match(r"const root=.*?, data=(.*);\n",html).captures[1])
    @test payload["centers"] == [[-9.0,0.0],[9.0,0.0]]
    for case in payload["cases"]
        @test length(case["outlines"]) == 2
        for (outline,center) in zip(case["outlines"],payload["centers"])
            @test all(p -> hypot(p[1]-center[1],p[2]-center[2]) ≈ 4.0,outline)
        end
    end
    @test occursin("c.outlines",html)
    scan=cached_frequency_sweep(s,[50e3,70e3];sensor=1)
    @test cached_frequency_sweep(remake_experiment(s),[50e3,70e3];sensor=1) === scan
    plot=repr(MIME"text/html"(),frequency_view(scan))
    @test occursin("не передача энергии",plot)
    @test occursin("Датчик 1",plot)
    @test occursin("50.0",plot)
    @test occursin("70.0",plot)
end
