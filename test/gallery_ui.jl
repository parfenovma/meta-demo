using Test, MetaNDT, Gridap, GridapGmsh, Gmsh, Markdown
include(joinpath(@__DIR__,"..","src","CylinderUI.jl"))
using .CylinderUI

function gallery_description_cell(notebook)
    # Git may check out Pluto notebooks with CRLF on Windows.
    notebook=replace(notebook,"\r\n"=>"\n")
    return split(split(notebook,"# ╔═╡ b744ae80-5858-4e3a-8a3f-000000000005\n")[2],
        "\n# ╔═╡ b744ae80-5858-4e3a-8a3f-000000000006")[1]
end

@testset "gallery client" begin
    notebook=read(joinpath(@__DIR__,"..","notebooks","metamaterial_gallery.jl"),String)
    @test occursin("lab_examples()",notebook)
    @test !occursin("Child(\"mesh",notebook)
    @test !occursin("Child(\"radius",notebook)
    @test occursin("include_straight_reference",notebook)
    @test occursin("cases[3].experiment",notebook)
    s=remake_experiment(example_experiment(:stg_single);duration=80e-6,frame_count=3)
    expected_description=sprint(Markdown.htmlesc,
        only(filter(e->e.id==:stg_single,lab_examples())).description)
    lf_notebook=replace(notebook,"\r\n"=>"\n")
    @testset "description with $line_ending line endings" for line_ending in ("LF","CRLF")
        source=line_ending=="LF" ? lf_notebook : replace(lf_notebook,"\n"=>"\r\n")
        description_code=gallery_description_cell(source)
        description=Core.eval(@__MODULE__,quote
            let chosen=only(filter(e->e.id==:stg_single,lab_examples())),experiment=$s
                $(Meta.parse(description_code))
            end
        end)
        description_html=repr(MIME"text/html"(),description)
        @test occursin(expected_description,description_html)
        @test occursin("5 · Синусоидальный STG",description_html)
        @test !occursin("chosen.description",description_html)
        @test !occursin("<math",description_html)
    end
    results=cached_example_comparison(:stg_single,s)
    @test length(results) == 4
    @test results[3].experiment.shape isa SinusoidalBrick
    @test results[4].experiment.shape isa RectangularBrick
    @test cached_example_comparison(:stg_single,remake_experiment(s))[4] === results[4]
    html=repr(MIME"text/html"(),comparison_view(results;
        labels=["Вода","Жёсткий","STG","Прямой контроль"]))
    @test occursin("Прямой контроль",html)
    @test occursin("outlines",html)
    @test occursin("c.case==='elastic'",html)
    @test !occursin("ctx.arc(X(center",html)
    scan=cached_frequency_sweep(s,[80e3];include_straight_reference=true)
    @test size(scan.ratios) == (4,1)
    @test cached_frequency_sweep(s,[80e3];include_straight_reference=true) === scan
    @test occursin("Прямой контроль равной массы",repr(MIME"text/html"(),frequency_view(scan)))
end
