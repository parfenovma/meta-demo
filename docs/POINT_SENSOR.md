# Point sensor in harmonic mode

This note describes the research workbench's harmonic sensor.
For the default transient modes, see [STG](STG_TRANSIENT.md)
and [the tube in water](WATER_TRANSIENT.md).
It does not describe the prepared five-experiment collection.

## Place and read D1

Click a calculated field map or enter x and y in millimetres.
Clicks on axis labels are not field points. Every paired case is sampled
at the same physical position. If that position has no applicable medium,
its reading is unavailable, not zero. Invalid placement keeps the last valid D1.

In water the sensor reads pressure in Pa. The scattered channel subtracts
the known incident field; it is processed data, not a second microphone.
In STG it reads uy or ux in nm. No noise or input-power normalization is added.

The panel shows coordinates, amplitude, RMS, phasor argument and the current
phase reading. Paired traces share axes. CSV records the case, coordinates,
frequency, time, quantity and units.

## What the trace means

The two-period trace is `Re(A exp(-i ω t))` from a stationary harmonic solution.
It has no pulse arrival or switch-off. It does not model a finite sensor
aperture, calibration or hardware noise.

Water is evaluated from the retained acoustic solution; the solid uses P1
mesh interpolation. Sampling never reads display pixels, remeshes or solves.
A dirty parameter form still probes the labelled applied result, not the draft.
Stale run IDs are rejected.

## Playback and saved runs

**Анимация волны** and the phase slider remain visible in static views.
Starting playback selects a phase-capable field; the sensor cursor follows
that phase. Pause, run changes and unmounting stop the animation.

D1 is saved with a pinned run. Moving it changes only the current result;
pin again to update the shelf. Restore reuses the retained solution without
solving. A sensor is not silently transferred between water and solid physics.

Postprocessing lives in `MetaNDT.solid_displacement` and `harmonic_trace`.
`WorkbenchUI` handles probe commands; the numerical equations are unchanged.
