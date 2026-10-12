#!/bin/sh
set -eu
cd "$(dirname "$0")"

if ! command -v julia >/dev/null 2>&1; then
  echo "Julia was not found."
  echo "Install it from https://julialang.org/downloads/, then open a new terminal."
  exit 1
fi

julia --startup-file=no --project=. start.jl
