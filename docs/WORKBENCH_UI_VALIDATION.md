# Research workbench: validation record

Local run: 15 October 2026, macOS ARM64, Julia 1.10.12,
`OPENBLAS_NUM_THREADS=1`.
This is the initial UI-stage record. The kernel equations, materials
and controls were unchanged; it is not a validation of the later prepared cards.

## Automated checks

| Suite | Passed |
|---|---:|
| Existing demo contract | 31 |
| Cold landing, adapters and shelf state | 68 |
| Real Pluto command lifecycle | 19 |
| Coated-cylinder client | 33 |
| Connected-solid client | 29 |
| Coated FEM and independent Bessel reference | 116 |
| Total Julia assertions | 296 |

JS syntax and `node test/workbench_assets.cjs` passed.
The JS tests covered linear-field barycentric interpolation,
void and degenerate-triangle masking, shared limits, draft equality
and colour scales. They did not emulate the browser.
Windows and Linux were not executed locally in this stage.

## Actual browser pass

At 10 kHz the tube returned -24.5783 dB. A note and pin were saved.
Changing the draft to 20 kHz left the old result labelled 10 kHz.
After calculation, two labelled curves could be compared.
Restoring the first run and reloading the browser retained the session shelf
without a new solve.

At viewport widths 1280 and 620 px, the workbench used 1190 px
and a stacked 620 px layout respectively, without horizontal overflow.
The harmonic STG run displayed the real FEM field and straight control
on one colour scale, four common-axis profiles and FWHM 17.64 mm.
That value belongs to this stage, not the later prepared STG impulse.

The first live STG run was slower than standalone tests.
Progress did not invent percentages. No browser-console errors were reported.

## Findings and limits

Browser testing found MessagePack integral values arriving as Float64.
The command fence was fixed to accept safe integral real values;
re-mounting cannot lower it. The real Pluto test covers this case.

Independent Standards and Spec reviews found a host-CSS collision
and overly broad legend removal. Both were fixed and rechecked;
the stage recorded zero open findings.

The shelf remains session-local and capped at six.
These tests do not establish acoustic invisibility, defect resolution,
broadband focusing or engineering-grade numerical accuracy.
