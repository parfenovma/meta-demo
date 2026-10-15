import Pkg

const REPOSITORY_ROOT = @__DIR__
const DEMO_ENVIRONMENT = joinpath(REPOSITORY_ROOT, "demo")
const LOCAL_LIBRARY = normpath(joinpath(REPOSITORY_ROOT, "..", "meta-ndt"))
isfile(joinpath(LOCAL_LIBRARY, "Project.toml")) || error("""
Для запуска нужны оба репозитория: meta-demo и meta-ndt в соседних папках.
Выполните из общей папки (не изнутри meta-demo):
  git clone https://github.com/parfenovma/meta-ndt.git
  git clone https://github.com/parfenovma/meta-demo.git
Затем перейдите в meta-demo и запустите start.jl. См. README.md, шаг 2.
""")
const NOTEBOOK_PATH = joinpath(REPOSITORY_ROOT, "notebooks",
    "--stg" in ARGS ? "virtual_defectoscope.jl" :
    "--single" in ARGS ? "cylinder_in_water.jl" :
    "--array" in ARGS ? "cylinder_array.jl" :
    any(a->a in ("--water","--gallery"),ARGS) ? "metamaterial_gallery.jl" :
    "--solid" in ARGS ? "solid_stg_lens.jl" :
    "--cloak" in ARGS ? "coated_cylinder.jl" :
    "--workbench" in ARGS ? "virtual_lab.jl" : "canonical_experiments.jl")

println("\nMetaNDT: preparing the Pluto environment.")
println("The first launch downloads Julia packages and can take a few minutes.\n")

Pkg.activate(DEMO_ENVIRONMENT)
if isdir(LOCAL_LIBRARY)
    current = get(Pkg.dependencies(),Base.UUID("f96cb834-4055-4d36-b75b-6528f613f0db"),nothing)
    if current === nothing || !current.is_tracking_path || realpath(current.source) != realpath(LOCAL_LIBRARY)
        Pkg.develop(path=LOCAL_LIBRARY)
    end
end
if !haskey(Pkg.project().dependencies, "MetaNDT")
    error("MetaNDT dependency is missing from demo/Project.toml")
end
Pkg.instantiate()

using Pluto

println("Opening the virtual wave experiment in your browser...")
println("To stop it later, return here and press Ctrl+C.\n")
Pluto.run(notebook=NOTEBOOK_PATH, launch_browser=true)
