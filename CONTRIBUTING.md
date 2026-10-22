# Contributing

Keep changes small enough to review and reproduce.

## Useful contributions

Improve an explanation, add a translation or plot, cover an edge case,
or add an adapter over the public library API. Propose the measurement
and controls before implementing a new scientific claim.

## Rules

- Put numerical models in `meta-ndt`; keep Pluto notebooks as clients.
- Preserve calculated values. Do not tune frozen fields to make a plot convincing.
- Use the same noise realization in paired comparisons unless different noise
  processes are the subject of the experiment.
- Label model probabilities as model results, not measured POD.
- Support a new claim with data, a defined metric and a regression test.
- Keep the five lab chapters within 2-3 PDF pages each. Preserve the control,
  procedure, units and source links; remove repetition instead of shrinking type.

From `meta-demo`, with the sibling library present:

```sh
julia +1.10 --startup-file=no --project=demo -e 'using Pkg; Pkg.instantiate()'
julia +1.10 --startup-file=no --project=demo test/runtests.jl
python3 tools/build_practicum.py --check
```

For documentation changes, rebuild the handbook and run
`test/practicum_docs.py`. PDF checks and authoring dependencies are listed
in [the handbook guide](docs/practicum/README.md).
