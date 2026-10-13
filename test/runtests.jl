using LinearAlgebra
using MetaNDT
using Test

function stg_scenario_templates(gain=1.5)
    receiver_y_mm = collect(-30.0:2.0:30.0)
    profile_shape = @. exp(-0.5 * (receiver_y_mm / 8.0)^2) *
        (1 + 0.12 * cospi(receiver_y_mm / 10.0))
    straight = 15.0 .* profile_shape ./ norm(profile_shape)
    return receiver_y_mm, gain .* straight, straight
end

@testset "STG what-if scenario" begin
    receiver_y_mm, stg, straight = stg_scenario_templates()
    @test length(receiver_y_mm) == 31
    @test receiver_y_mm == collect(-30.0:2.0:30.0)
    @test norm(straight) ≈ 15.0
    @test norm(stg) / norm(straight) ≈ 1.5

    simulation = simulate_paired_measurement(
        stg,
        straight;
        noise_model=GaussianReceiverNoise(9),
        signal_present=true,
        measurement_index=3,
    )
    decisions = detect_pair(stg, straight, simulation)

    @test simulation.primary .- stg ≈ simulation.noise
    @test simulation.control .- straight ≈ simulation.noise
    @test decisions.primary.probability > decisions.control.probability

    repeated = simulate_paired_measurement(
        stg,
        straight;
        noise_model=GaussianReceiverNoise(9),
        measurement_index=3,
    )
    @test repeated.noise == simulation.noise
end

@testset "absence and zero noise" begin
    _, stg, straight = stg_scenario_templates()
    absence = simulate_paired_measurement(
        stg,
        straight;
        noise_model=GaussianReceiverNoise(9),
        signal_present=false,
        measurement_index=3,
    )
    absence_decisions = detect_pair(stg, straight, absence)
    @test absence_decisions.primary.probability_kind == :Pfa
    @test absence_decisions.primary.probability ≈ 0.05 atol=2e-7

    noiseless = simulate_paired_measurement(
        stg,
        straight;
        noise_model=GaussianReceiverNoise(0),
    )
    noiseless_decisions = detect_pair(stg, straight, noiseless)
    @test isinf(noiseless_decisions.primary.score_sigma)
    @test noiseless_decisions.primary.probability == 1
end

@testset "public notebook contract" begin
    repository_root = normpath(joinpath(@__DIR__, ".."))
    notebook_path = joinpath(repository_root, "notebooks", "virtual_defectoscope.jl")
    notebook = read(notebook_path, String)
    @test startswith(notebook, "### A Pluto.jl notebook ###")
    @test occursin("using MetaNDT", notebook)
    @test !occursin("ReferenceDemo.jl", notebook)
    @test occursin("@bind stg_echo_gain", notebook)
    @test occursin("@bind noise_nm", notebook)
    @test occursin("@bind sample_state", notebook)
    @test occursin("@bind measurement_number", notebook)
    @test occursin("Slider(1:100; default=4", notebook)
    @test occursin("experiment_scene_html", notebook)
    @test occursin("staggered_sinusoidal_polygon", notebook)
    @test occursin("ПРОФИЛИ ВЫРЕЗОВ", notebook)
    @test occursin("сдвинуты на T/2", notebook)
    @test occursin("ЕДИНСТВЕННАЯ ГЕОМЕТРИЯ · STG", notebook)
    @test occursin("не результат STG FEM", notebook)
    @test occursin("31 приёмник", notebook)
    @test occursin("не измеренная POD", notebook)
    @test !occursin("242", notebook)
    @test !occursin("1.44", notebook)
    @test Meta.parseall(notebook) isa Expr
end
