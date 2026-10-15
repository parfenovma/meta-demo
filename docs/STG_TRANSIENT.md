# STG: genuine transient in the shared workbench

Original human requirement: an impulse, physical time frames, and a point-sensor
signal from the calculation, in the common Pluto workbench. Phase rotation of a
stationary solution does not satisfy it. Review against that requirement, not
merely this implementation note. This was the solid stage; the later water-tube
transient is described in [WATER_TRANSIENT.md](WATER_TRANSIENT.md).

## Try it

Open `notebooks/virtual_lab.jl` using the normal launcher. Choose **STG in
aluminium**, leave **Impulse** selected and calculate. The first run includes
the existing harmonic cell calibration to select the fixed physical lens;
propagation itself is then solved as a transient, not built from that calibration.

Press **Wave animation** above the maps. The slider is physical time in μs,
starting at zero displacement. After six carrier periods the source switches
off, while the wave continues through the actual connected solid and free voids.
Playback stops at the last frame; pressing play again restarts it. The animation
is slowed down for viewing, not a wall-clock real-time simulation.

Click in the solid or enter sensor coordinates (try x=40, y=1 mm). The signal
is available at every integration step, with a cursor synchronized to the field.
Moving the sensor, pausing, scrubbing and restoring a pinned run do not solve FEM
again. A void is not a sensor reading of zero. CSV exports use seconds/metres.
Harmonic remains an explicitly separate regime; the shelf does not overlay its
curves with the transient curves.

## Numerical/data contract

- P1 plane-strain elasticity, consistent mass, absorbing outer traction, free
  cutout walls. Newmark average acceleration, β=1/4, γ=1/2, Float64 arithmetic.
- Zero initial displacement and velocity; source `sin(2πft) sin²(πt/T)` for
  `0<t<T`, zero otherwise; `T=6/f`. Same force prescription for both geometries.
- Equal-mass straight ligaments are the paired control. This is not a claim that
  STG always outperforms straight ligaments or resolves defects.
- Default integration dt=0.1 μs, duration=140 μs; 141 display frames refer to
  actual integration states. Every-step nodal Float32 histories stay in Julia;
  display frames are transported as compressed little-endian Int16 base64 with
  one signed scale for the whole comparison (rounding error ≤ scale/65534). The sensor
  performs P1 interpolation on the full history, not on rendered pixels/frames.
- The signed nm color scale is fixed across every frame, both cases and both
  displacement components. A signed square-root color contrast makes weak
  propagating fronts visible without changing physical values or rescaling each
  frame. The legend discloses it. No frame-by-frame normalization disguises amplitude.
- The processed profile is `∫K dt / input work` over the stated whole window,
  not an instantaneous profile, flux, or defect resolution.
- Energy-balance diagnostics are checked before presenting a result. They do
  not establish spatial convergence or eliminate approximate-boundary reflections.
- Full histories cost `8 × nodes × time samples` bytes per case. Only current
  and pinned runs retain them; no additional global transient cache is used.

## Acceptance checks

`test/stg_transient.jl` exercises the real selected STG and straight control
through the shared adapter: rest, finite source, actual frames, dense point
sampling, agreement of frames with sensor states, energy accounting, pin/restore
and no solve on point changes. `test/transient_physics.jl` checks wave travel and
time-step refinement independently of the UI. Browser checks must additionally
cover a visible moving front, click-to-probe, playback/scrub and physical times.
Existing harmonic/water checks remain regressions, not evidence of time-domain
correctness.
