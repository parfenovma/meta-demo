# Point sensor validation — 2026-10-15

Scope: postprocessing and UI only. No acoustic/elastic weak form or material
parameter changed. The existing numerical controls remain in place.

## Automated checks run locally

Julia 1.10.12, macOS ARM64, `OPENBLAS_NUM_THREADS=1`:

| Suite | Passed |
|---|---:|
| Backend-free P1 interpolation and harmonic trace | 25 |
| Workbench adapters, shelf and retained-solution sensor | 104 |
| Actual Pluto bond/command lifecycle, including probes | 31 |
| Existing demo contract | 31 |
| Existing coated FEM / independent analytic reference | 116 |
| **Total Julia assertions** | **307** |

JS syntax and `node test/workbench_assets.cjs` also pass, including physical
coordinate transforms, axis-strip rejection, phase values and visible playback.
No Windows/Linux execution is claimed for this local run; CI includes the new
point-observation test.

Important numerical gates: affine complex-vector P1 field exactly interpolated;
gap between disconnected triangles rejected; `exp(-iωt)` quadrature checked;
empty-water plane wave matches analytic time samples. Water and solid readings
match their actual retained solutions after calculation caches are cleared.
Sensor commands do not call the injected solver. Pa/nm conversion, invalid/stale
commands, paired unavailable media, pin immutability and restore are covered.

## Real browser checks

The actual Pluto UI was used, not a browser emulation:

- Click inside the tube: placement rejected, no false zero measurement.
- Click in water: sensor and paired traces appear, same run ID retained.
- Start animation while in static scattered-amplitude mode: full-pressure phase
  activates automatically; phase slider and instantaneous probe values change.
- Pause; switch to scattered channel; place D1 at `(12, 0)` mm using the form.
  An unsaved note survives the sensor update.
- Export a real CSV and inspect its header and first rows: case, quantity,
  SI coordinates, Hz, seconds and Pa values are present.
- Pin, reconnect to the same Julia session and retain the pinned sensor.
- Calculate STG, place D1 at `(40, 1)` mm and read actual nm signals for the
  lens and straight control. Playback from static energy mode automatically
  switches to phase; instantaneous readings move while the run ID stays fixed.
  Pause and pin the solid run alongside the water run. Browser console has no
  errors. The old Julia session and its two original pins remain available.

Two independent review axes completed: Standards 0 open, Spec 0 open.

These tests do not turn the harmonic trace into a pulse simulation, prove new
metamaterial performance or model a real sensor's aperture, noise or calibration.
