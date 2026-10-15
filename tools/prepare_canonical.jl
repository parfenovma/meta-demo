# Offline developer command. Opening the notebook never includes this file.
using MetaNDT
include(joinpath(@__DIR__,"..","src","CanonicalData.jl"))
requested=isempty(ARGS) ? ["mass","bulk","absorber","cloak","prism","focus"] : ARGS
for id in requested
    if id=="focus"
        include(joinpath(@__DIR__,"prepare_focus.jl"))
        prepare_focus()
    else
        id in CanonicalData.IDS || error("Unknown example: $id")
        @time getfield(CanonicalData,Symbol("prepare_"*id))()
    end
end
