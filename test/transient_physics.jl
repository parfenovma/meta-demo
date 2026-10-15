# Physical behavior, independent of the workbench's presentation payload.
using Test, MetaNDT, Gridap, GridapGmsh, Gmsh, LinearAlgebra

@testset "Transient travel time and integration refinement" begin
    spec=remake_experiment(SolidLensExperiment();scenario=:solid,mesh_size=.0016,duration=90e-6,frame_count=19)
    coarse=simulate_pulse(spec;retain_history=true)
    fine=simulate_pulse(remake_experiment(spec;time_step=.05e-6);retain_history=true)
    near=solid_trace(coarse,(-.030,0.)); far=solid_trace(coarse,(.010,0.))
    refined=solid_trace(fine,(.010,0.))
    arrival(trace)=trace.times[findfirst(>(.05maximum(abs,trace.uy)),abs.(trace.uy))]
    delay=arrival(far)-arrival(near)
    expected=.040/last(solid_wave_speeds(spec))
    println("Bulk SV: near/far 5% arrivals μs = ",arrival(near)*1e6," / ",arrival(far)*1e6,
        "; delay μs = ",delay*1e6," vs cs prediction ",expected*1e6)
    @test delay>0
    @test abs(delay-expected)<3e-6
    @test all(iszero,coarse.displacement_y[:,1])
    @test near.uy[1]==far.uy[1]==0
    # Initial rest, then different point-dependent arrivals: not a global phasor.
    @test norm(near.uy-far.uy)>0.2norm(near.uy)
    indices=[argmin(abs.(refined.times.-t)) for t in far.times]
    relative=norm(far.uy-refined.uy[indices])/norm(refined.uy[indices])
    println("Bulk dt refinement relative trace error = ",relative)
    @test relative<.04
    @test coarse.diagnostics["energy_balance_relative"]<1e-8
    @test fine.diagnostics["energy_balance_relative"]<1e-8
    @test solid_pulse_drive(spec,0)==solid_pulse_drive(spec,spec.pulse_cycles/spec.frequency)==0
    @test all(t->solid_pulse_drive(spec,t)==0,range(spec.pulse_cycles/spec.frequency,spec.duration;length=101))
    @test_throws ArgumentError solid_trace(coarse,(1.,0.))
end
