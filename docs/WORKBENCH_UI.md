# Workbench UI: two experiments, one workflow

## Scope of this stage

A Pluto client over existing MetaNDT physics, not a new solver, website service
or arbitrary CAD editor. The two initial experiments are the coated hollow
steel tube in water and the connected-solid STG lens. Existing standalone
notebooks remain available, including the actual transient solid pulse.

The default launcher opens `notebooks/virtual_lab.jl`. Its first screen presents
two physical questions and geometry sketches, not invented field previews.
No numerical solve starts before the user asks for one. The solid backend and
cell calibration are loaded only when that experiment is actually calculated.

## User contract

1. Choose an experiment, edit a small set of physically meaningful parameters,
   explicitly run it, inspect fields and processed curves, pin a result.
2. Selected parameters and applied parameters are different states. Editing a
   selection never relabels an old field as a new calculation. Show uncalculated,
   changed, running, completed and failed states. The completed view states the
   actual applied frequency/material scenario and units.
3. One large scene, a selected-case/control comparison on one scale, one main
   result, supporting curves, and optional physics/numerical details. A common
   shell must not conflate pressure with solid displacement or phase animation
   with a transient pulse.
4. Pin up to six successful runs with a short optional note. Changing settings
   or switching physics does not change already pinned data. Restore a pinned
   result without solving it again; remove only the explicitly selected pin.
   A full shelf rejects a seventh pin rather than silently deleting a result.
5. Compare saved curves with common axes and units. Keep water scattering and
   solid focusing in separate comparison groups. Never independently stretch
   each curve to unit peak. Display parameter labels and physical limits.
6. Export applied specifications, primary curves and notes. The shelf lives in
   the current Julia session; it is not an invisible persistent file store.
7. Plain HTML controls, keyboard-accessible actions, light/dark appearance and
   a stacked narrow-window layout. No extra mesh/material editor selectors.

## Implementation seam

`src/WorkbenchUI.jl` owns client settings, a bounded in-memory run shelf and
two adapters using existing `CoatedCylinderUI`/`SolidLensUI` calculation caches
and MetaNDT public functions. Numerical equations/material laws stay in
`meta-ndt`. `src/assets/workbench.js` and `.css` own presentation.

The input widget remains mounted while a separate inert JSON output updates
its scene. This avoids a reactive dependency cycle, preserves local view state,
and lets the UI display progress before Julia returns. Real headless Pluto
tests cover command → result propagation; browser checks cover the actual
form, layout and charts separately.

No automated telemetry, remote writes, new solver or new physical performance
claim is included. The subsequent [point-sensor stage](POINT_SENSOR.md) adds
one movable sensor over these existing solutions; arbitrary geometry and new
material experiments remain follow-up work.
