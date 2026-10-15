using Test, JSON, MetaNDT
include(joinpath(@__DIR__,"..","src","CanonicalUI.jl"))
using .CanonicalUI

@testset "Six prepared canonical experiments" begin
    @test Base.get(CanonicalPicker())=="mass"
    lessons=JSON.parsefile(joinpath(@__DIR__,"..","src","assets","canonical_lessons.json"))
    @test Set(keys(lessons))==Set([CanonicalUI.CanonicalData.IDS...,"tube"])
    for lesson in values(lessons)
        @test all(k->!isempty(lesson[k]),("title","mechanism","symbols","boundary","field","signal"))
        @test 2<=length(lesson["watch"])<=4
        @test all(k->!isempty(lesson["intro"][k]),("title","question","instruction"))
        @test all(!isempty,lesson["watch"])
        @test !isempty(lesson["equations"])
        @test all(!isempty,lesson["equations"])
        @test all(!isempty,lesson["cases"])
    end
    for id in keys(lessons)
        @test !isempty(lessons[id]["chart"]["title"])
        @test !isempty(lessons[id]["chart"]["explanation"])
    end
    for id in CanonicalUI.CanonicalData.IDS
        d=CanonicalUI.CanonicalData.read_bundle(id)
        @test !isempty(d["sets"])
        @test all(s->length(s["cases"])>=2,d["sets"])
        html=repr(MIME"text/html"(),canonical_view(id))
        @test occursin("Запустить импульс",html)
        @test occursin("cn-selected",html)
        @test occursin("Что смотреть",html)
        @test occursin("Формула и обозначения",html)
        @test occursin("Как читать карты",html)
        @test occursin("cn-scale-ticks",html)
        @test occursin("cn-trace-legend",html)
        @test occursin(lessons[id]["title"],html)
        @test occursin(lessons[id]["intro"]["title"],html)
        if id=="focus"
            @test all(c->haskey(c,"mesh"),d["sets"][1]["cases"])
            @test !occursin("\"mesh\":",html)
            @test d["backend_digest"]==CanonicalUI.CanonicalData.focus_backend_digest()
        end
        for set in d["sets"]
            lesson=lessons[set["cases"][1]["geometry"]["type"]=="tube" ? "tube" : id]
            @test length(lesson["cases"])==length(set["cases"])
            @test occursin(lesson["symbols"],html)
            # Inline JSON escapes '<' to avoid closing script tags in copy.
            @test all(text->occursin(replace(text,"<"=>"\\u003c"),html),lesson["equations"])
        end
        @test !occursin("__DATA__",html)
        @test !occursin("__SCRIPT__",html)
        @test !occursin("__CSS__",html)
    end
    @test_throws ArgumentError canonical_view("unknown")
    source=read(joinpath(@__DIR__,"..","notebooks","canonical_experiments.jl"),String)
    @test Meta.parseall(source) isa Expr
    @test occursin("canonical_view(canonical_lesson)",source)
    @test !occursin("simulate",source)
    @test !occursin("prepare_",source)
end
