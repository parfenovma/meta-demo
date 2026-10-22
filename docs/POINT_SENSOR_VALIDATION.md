# Harmonic point sensor: validation record

Local run: 15 October 2026, macOS ARM64, Julia 1.10.12,
`OPENBLAS_NUM_THREADS=1`.
This records the harmonic stage, not the later transient modes.
No weak form or material parameter changed.

## Automated checks

| Suite | Passed |
|---|---:|
| Backend-free P1 interpolation and harmonic trace | 25 |
| Workbench adapters, shelf and retained sensor | 104 |
| Real Pluto command lifecycle | 31 |
| Existing demo contract | 31 |
| Coated FEM and independent analytic reference | 116 |
| Total Julia assertions | 307 |

JS syntax and `node test/workbench_assets.cjs` passed.
Coverage includes coordinate transforms, axis rejection, phase readings
and visible playback. Windows and Linux were not run locally in this stage.

Numerical checks covered affine complex P1 interpolation, gaps between
disconnected triangles, `exp(-iωt)` quadrature and the analytic empty-water wave.
Probes matched retained solutions after calculation-cache eviction.
Sensor commands did not call the injected solver.
Pa/nm conversion, invalid or stale commands, unavailable media,
pin immutability and restore were tested.

## Actual browser pass

- A click inside the tube was rejected; a water click produced paired traces
  without changing the run ID.
- Starting from static scattered amplitude selected full-pressure phase.
  The slider, cursor and instantaneous readings moved together.
- D1 at (12, 0) mm supported pause, scattered-channel selection and CSV export.
  An unsaved note survived the update; the CSV had case, quantity,
  SI coordinates, Hz, seconds and Pa values.
- Pinning and reconnecting to the same Julia session preserved D1.
- STG at (40, 1) mm returned nm signals for the lens and straight control.
  Playback switched static energy to phase; pause and pin kept both runs.

No browser-console errors were reported. The stage's independent Standards
and Spec reviews recorded zero open findings.
These checks did not create a pulse simulation or test sensor noise,
aperture, calibration or new metamaterial performance.
