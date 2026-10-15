### A Pluto.jl notebook ###
# v1.0.4

using Markdown
using InteractiveUtils

macro bind(def, element)
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ ad3780aa-5097-4b48-b2db-000000000001
begin
    import Pkg
    Pkg.activate(joinpath(@__DIR__,"..","demo");io=devnull)
    using MetaNDT, PlutoUI
    include(joinpath(@__DIR__,"..","src","WorkbenchUI.jl"))
    using .WorkbenchUI
    nothing
end

# ╔═╡ ad3780aa-5097-4b48-b2db-000000000002
lab_session=WorkbenchSession();

# ╔═╡ ad3780aa-5097-4b48-b2db-000000000003
@bind lab_command WorkbenchControls()

# ╔═╡ ad3780aa-5097-4b48-b2db-000000000004
process!(lab_session,lab_command)

# ╔═╡ Cell order:
# ╟─ad3780aa-5097-4b48-b2db-000000000001
# ╟─ad3780aa-5097-4b48-b2db-000000000002
# ╟─ad3780aa-5097-4b48-b2db-000000000003
# ╟─ad3780aa-5097-4b48-b2db-000000000004
