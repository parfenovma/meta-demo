# Shared workbench validation — 2026-10-15

Scope: client/UI changes only. `meta-ndt` is identical to the pre-stage WIP
snapshot; no equations, material parameters or scientific controls changed.
The shared triangle raster is also used by the standalone harmonic/pulse views.

## Local automated checks

Julia 1.10.12, macOS ARM64, `OPENBLAS_NUM_THREADS=1`:

| Suite | Passed |
|---|---:|
| Existing demo scenario/notebook contract | 31 |
| Workbench cold landing, real adapters, shelf/state | 68 |
| Actual Pluto command/bond lifecycle | 19 |
| Existing coated-cylinder client | 33 |
| Existing connected-solid client and controls | 29 |
| Coated-cylinder FEM / independent Bessel reference | 116 |
| **Total Julia assertions** | **296** |

`node test/workbench_assets.cjs` and JS syntax checks also pass. Pure JS tests
cover barycentric interpolation of a linear field, void/degenerate-triangle
masking, shared plot limits, draft equality and colour scales. They do not
claim to emulate the browser. CI includes the new Julia/Pluto/Node suites;
Windows and Linux were not executed locally in this stage.

## Real browser checks

The served `virtual_lab.jl` was operated through its actual HTML controls:

- Choose tube, calculate at 10 kHz, inspect the returned −24.5783 dB result.
- Add a note and pin the run.
- Change to 20 kHz: old result remains labelled 10 kHz, with a draft warning.
- Calculate/pin a second run, compare both with labelled curves.
- Restore the first run without solving; reload the browser and retain the
  session shelf and current result without replaying the calculation.
- At a 1280 px viewport the workbench uses 1190 px rather than Pluto's narrow
  text column. At 620 px cards stack; document width remains 620 px.
- Run the connected-solid STG lens through the same UI: real FEM field and
  straight control render with one colour scale, all four profiles share axes,
  and the selected section reports FWHM 17.64 mm. Browser console: no errors.
  The first live Pluto STG run was substantially slower than standalone tests;
  compilation/calibration progress is not represented as a fake percentage.

The first browser check caught that MessagePack transports JS integral numbers
as `Float64`. The command fence now accepts safe integral real values and is
covered in the real Pluto test. Re-mounting with `init` cannot lower the fence.

Independent Standards and Spec reviewers found a host-CSS collision and a
legend-removal scope bug. Both were fixed and rechecked; zero open findings.

These checks validate the UI contract, not new claims of acoustic invisibility,
defect resolution, broadband focusing or engineering-grade solver accuracy.
The shelf is session-local, capped at six, and not a persistent project store.
