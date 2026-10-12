# Data provenance and claim boundary

The bundled dataset contains 31 samples along a receiver line. It was copied
without renormalization from paired 2D plane-strain full-wave FEM runs:

- frequency: `242 kHz`;
- applied normal traction: `1 MPa`;
- aluminium 6061 surrogate;
- cylindrical 2D defect, radius `2 mm`;
- defect centre / nominal focus: `x = 88 mm`;
- receiver line: `x = 68 mm`;
- profile quantity: RMS amplitude of `defect − no defect` scattered `uₓ`;
- comparison: sinusoidal lens and a matched straight control.

Recomputed from the published CSV files:

- sinusoidal RMS response: `5.1610 nm`;
- straight-control RMS response: `3.5826 nm`;
- response ratio: `1.44057×`;
- equal-noise SNR proxy: `+3.17067 dB`;
- reported local kinetic-energy-density ratio at the future defect: `1.97565×`.

The added receiver noise is independent synthetic Gaussian noise. The matched
filter knows the correct template. Therefore the example demonstrates a
mechanism and a controlled equal-noise detection advantage. It is **not** a
measured probability of detection, arbitrary-defect localization,
super-resolution, validation of a manufactured device, or a model of real
structural clutter.

The public CSV values are the source of truth for this repository. Tests
recompute every headline metric from them.
