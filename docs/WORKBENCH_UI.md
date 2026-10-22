# Research workbench: tube and STG

Open the research interface from `meta-demo`:

```sh
julia +1.10 --startup-file=no --project=. start.jl --workbench
```

This opens `notebooks/virtual_lab.jl`.
Without the flag, the launcher opens the five prepared experiments.
The research workbench runs new calculations; it is not a CAD editor.

## Workflow

1. Choose the coated hollow steel tube in water or the connected-solid STG lens.
2. Change the exposed parameters and run explicitly. No solve starts on opening.
3. Inspect the field, paired control and processed curves.
4. Add a note and pin a successful run. Restore it later without solving again.

The parameter draft and the applied result are separate.
Changing a frequency never relabels an old field.
The screen distinguishes uncalculated, changed, running, completed and failed
states and identifies the actual applied settings and units.

Comparisons use common axes and scales. Pressure and solid displacement,
harmonic and transient results remain separate. The current STG and water
transients are described in [STG_TRANSIENT.md](STG_TRANSIENT.md)
and [WATER_TRANSIENT.md](WATER_TRANSIENT.md).

## Shelf and export

The shelf holds up to six successful runs in the current Julia session.
A seventh pin is rejected; existing pins are not overwritten.
Editing, switching experiments or restoring a run does not change saved data.
Only the selected pin is removed.

Export includes applied specifications, primary curves and notes.
The shelf is not a persistent file store: it ends with the Julia session.
See [POINT_SENSOR.md](POINT_SENSOR.md) for harmonic probe behaviour.

## Code and checks

`src/WorkbenchUI.jl` manages settings, retained results and adapters
over `CoatedCylinderUI`, `SolidLensUI` and the MetaNDT API.
Models and material laws remain in `meta-ndt`.
JavaScript and CSS in `src/assets/workbench.*` render the interface.

Controls stay mounted while an inert JSON result updates the scene.
This preserves local state and allows progress to appear before Julia returns.
Real Pluto tests check command propagation; browser checks cover layout,
forms and charts. Controls support keyboard use, narrow windows and both themes.

This interface adds no telemetry or remote writes and makes no new physical
performance claim. Arbitrary geometry remains outside its scope.
