using Test, TOML

@testset "Paired-repository installation" begin
    root = dirname(@__DIR__)
    @testset "$manifest_file" for manifest_file in ("Manifest.toml", "Manifest-v1.13.toml")
        manifest = TOML.parsefile(joinpath(root, "demo", manifest_file))
        dependency = only(manifest["deps"]["MetaNDT"])
        @test normpath(joinpath(root, "demo", dependency["path"])) ==
              normpath(joinpath(root, "..", "meta-ndt"))
    end
    @test isfile(joinpath(root, "..", "meta-ndt", "Project.toml"))
    mktempdir() do temporary
        demo = joinpath(temporary, "meta-demo")
        mkpath(demo)
        entrypoint = joinpath(demo, "start.jl")
        cp(joinpath(root, "start.jl"), entrypoint)
        output = IOBuffer()
        process = run(pipeline(ignorestatus(`$(Base.julia_cmd()) --startup-file=no --project=$temporary $entrypoint`),
                               stdout=output, stderr=output))
        message = String(take!(output))
        @test !success(process)
        @test occursin("meta-demo и meta-ndt", message)
        @test occursin("git clone https://github.com/parfenovma/meta-ndt.git", message)
        @test !isdir(joinpath(demo, "demo")) # Fail before creating/activating an environment.
    end
end
