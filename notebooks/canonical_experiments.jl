### A Pluto.jl notebook ###
# v1.0.4

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ 75a20116-cae0-42d3-8cb7-100000000001
begin
    import Pkg
    Pkg.activate(joinpath(@__DIR__,"..","demo");io=devnull)
    # Load the viewer and the explanations shown alongside each experiment.
    include(joinpath(@__DIR__,"..","src","CanonicalUI.jl"))
    using .CanonicalUI
    nothing
end

# ╔═╡ 75a20116-cae0-42d3-8cb7-100000000002
md"""
# Метаматериалы: шесть опытов

Выберите опыт и нажмите «Запустить импульс». Слева показан образец для сравнения,
справа кнопками можно менять его устройство. Нажмите на карту, чтобы поставить
датчик и посмотреть его запись.

Под картами написано, на что смотреть и как устроен опыт. Формулы с обозначениями
можно раскрыть там же. Все поля рассчитаны заранее: ждать построения сетки не нужно.
"""

# ╔═╡ 75a20116-cae0-42d3-8cb7-100000000003
@bind canonical_lesson CanonicalPicker()

# ╔═╡ 75a20116-cae0-42d3-8cb7-100000000004
canonical_view(canonical_lesson)

# ╔═╡ Cell order:
# ╟─75a20116-cae0-42d3-8cb7-100000000001
# ╟─75a20116-cae0-42d3-8cb7-100000000002
# ╟─75a20116-cae0-42d3-8cb7-100000000003
# ╟─75a20116-cae0-42d3-8cb7-100000000004
