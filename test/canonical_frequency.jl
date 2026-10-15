using Test, MetaNDT
include(joinpath(@__DIR__,"..","src","CanonicalData.jl"))
using .CanonicalData

@testset "Displayed response is the response of the prepared model" begin
    for id in ("mass","bulk","prism","absorber")
        d=CanonicalData.read_bundle(id)
        x=d["plot"]["x"]
        @test all(s->first(x)<=s["frequency"]<=last(x),d["sets"])
        @test all(s->length(s["y"])==length(x),d["plot"]["series"])
    end
    bulk=CanonicalData.read_bundle("bulk")
    x=bulk["plot"]["x"]
    @test minimum(x)>10_000 # guards the Julia `0.55f0` Float32-literal bug
    @test bulk["plot"]["series"][1]["y"]==ones(length(x))
    actual=bulk["plot"]["series"][2]["y"]
    expected=clamp.([real(helmholtz_modulus(f))/(1000*1480^2) for f in x],-4,4)
    @test actual≈expected
    @test minimum(actual)<0<maximum(actual)
    for set in bulk["sets"]
        f=set["frequency"]
        @test set["cases"][1]["diagnostics"]["bulk_modulus_real_Pa"]≈1000*1480^2
        @test set["cases"][2]["diagnostics"]["bulk_modulus_real_Pa"]≈real(helmholtz_modulus(f))
    end
    mass=CanonicalData.read_bundle("mass")
    for (j,added_mass) in enumerate((0.,.0003))
        m=membrane_model(;added_mass)
        for i in 1:31:length(mass["plot"]["x"])
            f=mass["plot"]["x"][i]
            @test mass["plot"]["series"][j]["y"][i]≈clamp(real(membrane_response(m,f).mass),-15,15)
        end
    end
end
