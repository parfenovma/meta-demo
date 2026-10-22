# STG impulse in the research workbench

The impulse, time frames and point signal come from time integration
of the connected solid. Harmonic phase rotation is a separate mode.

## Run and observe

```sh
julia +1.10 --startup-file=no --project=. start.jl --workbench
```

Choose **STG in aluminium**, keep **Impulse**, then calculate.
The first run calibrates harmonic cells to choose the fixed lens geometry;
the subsequent propagation is a transient solve.

Press **Wave animation**. The slider shows physical time in μs.
The source stops after six carrier periods; the wave and ringing continue.
Playback stops at the last frame and can restart. Its display speed
is not the physical wave speed.

Click in the solid or enter D1 at x=40, y=1 mm.
The trace samples every integration step, with a cursor tied to the frame.
Voids are unavailable, not zero. Probe moves, playback, scrub and restore
do not solve again. CSV uses seconds and metres.

## Numerical model

- P1 plane-strain elasticity, consistent mass, free cutout walls
  and approximate absorbing outer traction.
- Newmark average acceleration: β=1/4, γ=1/2, Float64 integration.
- Zero initial displacement and velocity.
  Source: `sin(2πft) sin²(πt/T)` for 0<t<T, otherwise zero; T=6/f.
- Same prescribed force for STG and equal-mass straight-ligament control.
  Equal force does not by itself guarantee equal accepted work.
- Default step 0.1 μs, duration 140 μs, 141 display frames taken
  from actual states. Dense nodal histories remain in Julia as Float32.
- P1 sensor interpolation uses the dense history, not screen pixels.
  Transported frames are little-endian Int16 base64 with one signed scale;
  rounding error is at most scale/65534.
- The shared nm scale covers both cases, components and all frames.
  Signed square-root colour contrast changes visibility, not physical values.
- The processed profile is `∫K dt / input work` over the stated window,
  not instantaneous flux or defect resolution.

Energy-balance checks precede display but do not establish spatial convergence
or remove all boundary reflections. Histories cost
`8 × nodes × time samples` bytes per case and are retained only
for current and pinned runs, not an extra global transient cache.

## Tests

`test/stg_transient.jl` checks the real pair, rest, finite source,
frames, dense probes, energy accounting and pin/restore without a new solve.
`test/transient_physics.jl` checks wave travel and step refinement.
Browser checks must still inspect the moving front, click-to-probe and scrub.

These are research-mode controls, not the identical-STG control used
in the prepared collection. The water transient has its own
[model and observations](WATER_TRANSIENT.md).
