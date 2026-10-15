# Point sensor and visible harmonic animation

Historical harmonic-stage contract below. The shared workbench now defaults
to a genuine transient for STG: see [STG_TRANSIENT.md](STG_TRANSIENT.md).
Explicitly selected harmonic modes still follow this contract. Water also has
a genuine transient now: see [WATER_TRANSIENT.md](WATER_TRANSIENT.md).

## Contract of this stage

One movable, ideal point sensor D1 in either existing harmonic experiment.
Click either calculated field map or enter `(x, y)` in mm. The click must be in
the material of that map; coordinates on the axis strip are not field points.
The same physical position is sampled for every paired case. A case without
the applicable medium at that position is unavailable, not a zero signal.

Water: total pressure by default, in Pa. The optional scattered channel removes
the known incident wave; it is processed data, not a second microphone. STG:
`uy` or `ux` in nm, without normalizing by accepted input power. Display colour
scales and sensor units are deliberately distinct. No noise is added.

Show a crosshair on each map, coordinates, amplitude/RMS/phasor argument, the
current phase reading and a shared-axis selected/control trace for two periods.
Export the selected channel to CSV with case, coordinates, frequency, time and
units. This is a stationary harmonic trace `Re(A exp(-i ω t))`, not a transient
arrival, pulse experiment, sensor aperture, or calibrated hardware response.

Sampling is postprocessing of the actual retained solutions: exact acoustic
water evaluation and P1 solid mesh interpolation. Never read raster pixels,
interpolate the masked water display grid, remesh or rerun FEM on sensor clicks.
Invalid placement preserves the last good sensor and calculation. A stale run
ID is rejected. Sampling while parameters are dirty still refers to the visibly
labelled applied solution, not the uncalculated draft.

The sensor is part of a run snapshot: pin/export/restore keep its readings.
Moving after pinning changes the current run only; re-pin to update the shelf.
Keep its physical position for a new run of the same physics; do not carry a
water microphone silently into the solid experiment. Retained typed solutions
make probing independent of cache eviction. Restoration never invokes a solver.

## Animation discoverability

The “Анимация волны” button and phase slider stay visible above the maps even
when the static energy/scattered-amplitude mode is selected. Starting playback
automatically selects a phase-capable field. The sensor's instantaneous value
and cursor use that same phase. Pausing, changing runs and unmounting clean up
the animation; choosing a static amplitude mode stops playback.

## Implementation

`MetaNDT.solid_displacement` and `harmonic_trace` are plain-array postprocessing,
available without Gridap. `WorkbenchUI` retains solutions privately and handles
the probe command; Pluto remains a client. No solver equations change.
