using LinearAlgebra
using MetaNDT
using Test

include(joinpath(@__DIR__, "..", "src", "ReferenceDemo.jl"))
using .ReferenceDemo

@testset "reference data" begin
    experiment = load_reference_experiment()
    summary = gain_summary(experiment)

    @test validate_reference_experiment(experiment)
    @test length(experiment.y_mm) == 31
    @test experiment.y_mm == collect(-30.0:2.0:30.0)
    @test summary.sinusoidal_rms_nm ≈ 5.161036004749387 rtol=1e-12
    @test summary.straight_rms_nm ≈ 3.5826397675782893 rtol=1e-12
    @test summary.scattering_gain ≈ 1.4405679441888253 rtol=1e-12
    @test summary.snr_improvement_db ≈ 3.170674930779284 rtol=1e-12
    @test summary.local_energy_gain ≈ 1.9756492550106037 rtol=1e-12
end

@testset "equal-noise virtual measurement" begin
    experiment = load_reference_experiment()
    simulation = simulate_paired_measurement(
        experiment.sinusoidal_nm,
        experiment.straight_nm;
        noise_model=GaussianReceiverNoise(12),
        signal_present=true,
        measurement_index=3,
    )
    decisions = detect_pair(
        experiment.sinusoidal_nm,
        experiment.straight_nm,
        simulation,
    )

    @test simulation.primary .- experiment.sinusoidal_nm ≈ simulation.noise
    @test simulation.control .- experiment.straight_nm ≈ simulation.noise
    @test decisions.primary.score_sigma ≈ 2.197355766582633 rtol=1e-12
    @test decisions.control.score_sigma ≈ 1.4217946653678817 rtol=1e-12
    @test decisions.primary.found
    @test !decisions.control.found
    @test decisions.primary.probability ≈ 0.773 atol=5e-4
    @test decisions.control.probability ≈ 0.507 atol=5e-4

    repeated = simulate_paired_measurement(
        experiment.sinusoidal_nm,
        experiment.straight_nm;
        noise_model=GaussianReceiverNoise(12),
        measurement_index=3,
    )
    @test repeated.noise == simulation.noise
end

@testset "absence and zero noise" begin
    experiment = load_reference_experiment()
    absence = simulate_paired_measurement(
        experiment.sinusoidal_nm,
        experiment.straight_nm;
        noise_model=GaussianReceiverNoise(12),
        signal_present=false,
        measurement_index=3,
    )
    absence_decisions = detect_pair(
        experiment.sinusoidal_nm,
        experiment.straight_nm,
        absence,
    )
    @test absence_decisions.primary.probability_kind == :Pfa
    @test absence_decisions.primary.probability ≈ 0.05 atol=2e-7

    noiseless = simulate_paired_measurement(
        experiment.sinusoidal_nm,
        experiment.straight_nm;
        noise_model=GaussianReceiverNoise(0),
    )
    noiseless_decisions = detect_pair(
        experiment.sinusoidal_nm,
        experiment.straight_nm,
        noiseless,
    )
    @test isinf(noiseless_decisions.primary.score_sigma)
    @test noiseless_decisions.primary.probability == 1
end

@testset "public notebook contract" begin
    repository_root = normpath(joinpath(@__DIR__, ".."))
    notebook_path = joinpath(repository_root, "notebooks", "virtual_defectoscope.jl")
    notebook = read(notebook_path, String)
    @test startswith(notebook, "### A Pluto.jl notebook ###")
    @test occursin("using MetaNDT", notebook)
    @test occursin("ReferenceDemo.jl", notebook)
    @test occursin("@bind noise_nm", notebook)
    @test occursin("@bind sample_state", notebook)
    @test occursin("@bind measurement_number", notebook)
    @test occursin("Slider(1:100; default=4", notebook)
    @test occursin("не измеренная POD", notebook)
    @test Meta.parseall(notebook) isa Expr
end
