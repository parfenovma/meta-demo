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

# ╔═╡ d8c4dc48-57b3-4db4-a025-84616b54aa01
begin
    import Pkg
    Pkg.activate(joinpath(@__DIR__,"..","demo");io=devnull)
    using MetaNDT, Gridap, GridapGmsh, Gmsh, PlutoUI
    include(joinpath(@__DIR__,"..","src","CylinderUI.jl"))
    using .CylinderUI
    nothing
end

# ╔═╡ d8c4dc48-57b3-4db4-a025-84616b54aa02
md"""
# Цилиндр в воде: виртуальный испытательный стенд

Источник посылает короткий звуковой импульс. Вода нагружает цилиндр, цилиндр
движется и сам излучает в воду. Сравните три опыта с одним и тем же источником:
**пустая вода**, **жёсткое препятствие**, **упругий алюминий**.

Сначала посмотрите готовый расчёт ниже. Затем измените параметры и нажмите
**«Рассчитать опыт»**. Датчики измеряют давление, а увеличение движения
цилиндра подписано отдельно.
"""

# ╔═╡ d8c4dc48-57b3-4db4-a025-84616b54aa03
@bind controls PlutoUI.confirm(PlutoUI.combine() do Child
    md"""
    ### Постановка опыта

    Радиус цилиндра, mm: $(Child("radius",Slider(6:1:14;default=10,show_value=true)))

    Частота импульса, kHz: $(Child("frequency",Slider(30:5:100;default=60,show_value=true)))

    | Положение, mm | x | y |
    |:--|:--|:--|
    | Источник | $(Child("source_x",Slider(-60:1:-25;default=-45,show_value=true))) | $(Child("source_y",Slider(-20:1:20;default=0,show_value=true))) |
    | Датчик A | $(Child("a_x",Slider(20:1:60;default=40,show_value=true))) | $(Child("a_y",Slider(-30:1:30;default=0,show_value=true))) |
    | Датчик B | $(Child("b_x",Slider(-35:1:60;default=-30,show_value=true))) | $(Child("b_y",Slider(20:1:35;default=20,show_value=true))) |
    | Датчик C | $(Child("c_x",Slider(20:1:60;default=25,show_value=true))) | $(Child("c_y",Slider(-35:1:35;default=-25,show_value=true))) |

    Вода: 1000 kg/m³, 1480 m/s. Алюминий: 2700 kg/m³, E = 70 GPa, ν = 0.33.
    Область: 160 × 100 mm. Импульс: 2 периода с плавным включением и выключением.
    """
end;label="Рассчитать опыт")

# ╔═╡ d8c4dc48-57b3-4db4-a025-84616b54aa04
begin
    experiment=CylinderExperiment(
    radius=controls.radius/1000,frequency=controls.frequency*1000,
    source=(controls.source_x/1000,controls.source_y/1000),
    sensors=[(controls.a_x/1000,controls.a_y/1000),(controls.b_x/1000,controls.b_y/1000),(controls.c_x/1000,controls.c_y/1000)],
    mesh_size=min(0.002,1480/(14*controls.frequency*1000)),
    )
    nothing
end

# ╔═╡ d8c4dc48-57b3-4db4-a025-84616b54aa05
begin
    comparison=cached_comparison(experiment)
    nothing
end

# ╔═╡ d8c4dc48-57b3-4db4-a025-84616b54aa06
comparison_view(comparison)

# ╔═╡ d8c4dc48-57b3-4db4-a025-84616b54aa07
md"""
### Сохранить и повторить

$(DownloadButton(experiment_toml(experiment),"cylinder_experiment.toml"))

Сигналы: $(DownloadButton(sensor_csv(comparison[1]),"empty_water.csv"))
$(DownloadButton(sensor_csv(comparison[2]),"rigid_cylinder.csv"))
$(DownloadButton(sensor_csv(comparison[3]),"elastic_cylinder.csv"))

TOML сохраняет геометрию, материалы, источник, датчики и численные настройки.
CSV содержит время в секундах и давление каждого датчика в Pa.
"""

# ╔═╡ d8c4dc48-57b3-4db4-a025-84616b54aa08
md"""
### Первый самостоятельный опыт

1. Найдите на сигналах приход прямой волны. Почему он приходит в разные моменты к A, B и C?
2. Переключайте жёсткий и упругий цилиндры. Где различие легче заметить: на картине поля или на датчике?
3. Измените частоту, сохранив остальные параметры. Становится ли различие больше?
4. Переместите один датчик. Получите два опыта, в которых вывод «упругость важна» выглядит по-разному, и объясните причину.

Меняйте по одному параметру и сохраняйте сигналы. Сам цилиндр — базовая задача
рассеяния; следующим шагом на этом стенде будут несколько взаимодействующих
включений и образцы метаматериалов.

### Что именно рассчитано

В воде решается волновое уравнение для акустического потенциала, в цилиндре —
векторное уравнение упругости. На общей границе связаны **нагрузка давлением и
нормальная скорость**. Давление воды определяется как `p = −ρ ∂tφ`.
Все три случая рассчитаны отдельно; множителя «выигрыша» здесь нет.

Это 2D-сечение бесконечного цилиндра с плоской деформацией. На внешней границе
стоит приближённое поглощающее условие: при косом падении возможны отражения.
Для количественных выводов проверяйте сетку, шаг времени и размер области.
Баланс энергии помогает проверить сопряжение и интегратор, но сам по себе
не измеряет пространственную точность.

### Тот же опыт из Julia-скрипта

```julia
using MetaNDT, Gridap, GridapGmsh, Gmsh
spec = load_experiment("cylinder_experiment.toml")
results = simulate_comparison(spec)
write("elastic_signals.csv", sensor_csv(results[3]))
```

Метод, слабые формы и проверки описаны в `meta-ndt/docs/CYLINDER_MODEL.md`.
Первый запуск может занять время на компиляцию; переключение кадров и
трёх готовых случаев происходит сразу, без нового FEM-решения.
"""

# ╔═╡ Cell order:
# ╟─d8c4dc48-57b3-4db4-a025-84616b54aa01
# ╟─d8c4dc48-57b3-4db4-a025-84616b54aa02
# ╟─d8c4dc48-57b3-4db4-a025-84616b54aa03
# ╟─d8c4dc48-57b3-4db4-a025-84616b54aa04
# ╟─d8c4dc48-57b3-4db4-a025-84616b54aa05
# ╟─d8c4dc48-57b3-4db4-a025-84616b54aa06
# ╟─d8c4dc48-57b3-4db4-a025-84616b54aa07
# ╟─d8c4dc48-57b3-4db4-a025-84616b54aa08
