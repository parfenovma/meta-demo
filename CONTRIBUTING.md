# Contributing

Small, reviewable changes are welcome.

## Good first contributions

- improve a Russian explanation without changing the claim boundary;
- add an English translation;
- add a new plot built from existing public API results;
- write a test for a corner case;
- add a data adapter without coupling it to Pluto;
- propose a two-defect resolution experiment before implementing it.

## Ground rules

1. Keep `src/` independent of Pluto and visualization packages.
2. Do not replace frozen FEM values with hand-tuned numbers.
3. Use the same noise realization for a paired comparison unless the experiment
   explicitly studies different noise processes.
4. Do not call model probabilities measured POD.
5. New scientific claims need data, a frozen metric and a test.

Run before opening a pull request:

```bash
julia --startup-file=no --project=demo -e 'using Pkg; Pkg.instantiate()'
julia --startup-file=no --project=demo test/runtests.jl
```
