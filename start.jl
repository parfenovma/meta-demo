import Pkg

const REPOSITORY_ROOT = @__DIR__
const DEMO_ENVIRONMENT = joinpath(REPOSITORY_ROOT, "demo")
const NOTEBOOK_PATH = joinpath(REPOSITORY_ROOT, "notebooks", "virtual_defectoscope.jl")

println("\nMetaNDT: preparing the Pluto environment.")
println("The first launch downloads Julia packages and can take a few minutes.\n")

Pkg.activate(DEMO_ENVIRONMENT)
if !haskey(Pkg.project().dependencies, "MetaNDT")
    error("MetaNDT dependency is missing from demo/Project.toml")
end
Pkg.instantiate()

using Pluto

println("Opening the virtual defectoscope in your browser...")
println("To stop it later, return here and press Ctrl+C.\n")
Pluto.run(notebook=NOTEBOOK_PATH, launch_browser=true)
