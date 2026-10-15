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

# ╔═╡ 5ea334e8-590a-46d8-98d1-aa1000000001
begin
    import Pkg
    Pkg.activate(joinpath(@__DIR__,"..","demo");io=devnull)
    using MetaNDT, Gridap, GridapGmsh, Gmsh, PlutoUI
    include(joinpath(@__DIR__,"..","src","CylinderUI.jl"))
    using .CylinderUI
    nothing
end

# ╔═╡ 5ea334e8-590a-46d8-98d1-aa1000000002
md"""
# Массив цилиндров в воде

Соберите образец из **1–9 алюминиевых включений** и проверьте, как он меняет
звуковой импульс. Все цилиндры и вода решаются **совместно**, с нагрузкой
давлением и обратным излучением движения в воду. Отклики одиночных цилиндров
не складываются искусственно.

Сначала покрутите готовое поле ниже. Изменения постановки применяются кнопкой
**«Рассчитать образец»**. Перебор частоты запускается отдельно, ниже поля.
"""

# ╔═╡ 5ea334e8-590a-46d8-98d1-aa1000000003
@bind controls PlutoUI.confirm(PlutoUI.combine() do Child
    md"""
    ### Собрать образец

    Столбцов вдоль x: $(Child("columns",Slider(1:3;default=2,show_value=true)))

    Рядов вдоль y: $(Child("rows",Slider(1:3;default=3,show_value=true)))

    Радиус каждого цилиндра, mm: $(Child("radius",Slider(3:5;default=4,show_value=true)))

    Шаг между центрами, mm: $(Child("pitch",Slider(14:2:24;default=18,show_value=true)))

    Частота для поля и сигналов, kHz: $(Child("frequency",Slider(30:5:100;default=60,show_value=true)))

    | Положение, mm | x | y |
    |:--|:--|:--|
    | Источник | $(Child("source_x",Slider(-60:1:-45;default=-55,show_value=true))) | $(Child("source_y",Slider(-20:1:20;default=0,show_value=true))) |
    | Датчик A, за образцом | $(Child("a_x",Slider(40:1:60;default=40,show_value=true))) | $(Child("a_y",Slider(-30:1:30;default=0,show_value=true))) |
    | Датчик B, перед образцом | $(Child("b_x",Slider(-60:1:-40;default=-40,show_value=true))) | $(Child("b_y",Slider(-30:1:30;default=20,show_value=true))) |
    | Датчик C, за образцом | $(Child("c_x",Slider(40:1:60;default=45,show_value=true))) | $(Child("c_y",Slider(-30:1:30;default=-25,show_value=true))) |

    Вода: 1000 kg/m³, 1480 m/s. Алюминий: 2700 kg/m³, E = 70 GPa, ν = 0.33.
    Область: 160 × 100 mm. Импульс: 2 периода. Время опыта: 150 μs.
    """
end;label="Рассчитать образец")

# ╔═╡ 5ea334e8-590a-46d8-98d1-aa1000000004
begin
    experiment=CylinderExperiment(
        centers=cylinder_lattice(controls.columns,controls.rows,controls.pitch/1000),
        radius=controls.radius/1000,frequency=controls.frequency*1000,
        source=(controls.source_x/1000,controls.source_y/1000),
        sensors=[(controls.a_x/1000,controls.a_y/1000),
                 (controls.b_x/1000,controls.b_y/1000),
                 (controls.c_x/1000,controls.c_y/1000)],
        mesh_size=min(0.0015,1480/(14*controls.frequency*1000)))
    comparison=cached_comparison(experiment)
    nothing
end

# ╔═╡ 5ea334e8-590a-46d8-98d1-aa1000000005
md"""
Рассчитанный образец: **$(length(experiment.centers)) цилиндров**,
радиус **$(experiment.radius*1000) mm**, частота **$(experiment.frequency/1000) kHz**.
"""

# ╔═╡ 5ea334e8-590a-46d8-98d1-aa1000000006
comparison_view(comparison)

# ╔═╡ 5ea334e8-590a-46d8-98d1-aa1000000007
md"""
### Сохранить этот опыт

$(DownloadButton(experiment_toml(experiment),"array_experiment.toml"))

Сигналы: $(DownloadButton(sensor_csv(comparison[1]),"array_empty_water.csv"))
$(DownloadButton(sensor_csv(comparison[2]),"array_rigid.csv"))
$(DownloadButton(sensor_csv(comparison[3]),"array_elastic.csv"))

TOML хранит **все координаты включений**, материалы, источник, датчики и
численные настройки. Три расчёта отличаются только наличием и упругостью образца.
"""

# ╔═╡ 5ea334e8-590a-46d8-98d1-aa1000000008
@bind sweep_controls PlutoUI.confirm(PlutoUI.combine() do Child
    md"""
    ### Перебрать частоту

    Считать перебор: $(Child("enabled",CheckBox(default=false)))

    От, kHz: $(Child("low",Slider(30:10:60;default=40,show_value=true)))

    До, kHz: $(Child("high",Slider(70:10:100;default=80,show_value=true)))

    Число точек: $(Child("count",Slider(3:2:7;default=5,show_value=true)))

    Датчик для сравнения: $(Child("sensor",Select([1=>"A — за образцом",2=>"B — перед образцом",3=>"C — за образцом"];default=1)))

    Начало временного окна, μs: $(Child("start",Slider(0:10:60;default=0,show_value=true)))

    Конец временного окна, μs: $(Child("stop",Slider(80:10:150;default=150,show_value=true)))

    Поставьте галочку и нажмите кнопку. На каждой частоте решаются пустая вода,
    жёсткий и упругий образцы; это может занять несколько секунд после компиляции.
    Перебор относится к **применённому образцу выше** и обновится, если его пересчитать.
    """
end;label="Запустить / обновить перебор")

# ╔═╡ 5ea334e8-590a-46d8-98d1-aa1000000009
begin
    sweep_result=sweep_controls.enabled ? cached_frequency_sweep(experiment,
        range(sweep_controls.low*1000,sweep_controls.high*1000;length=sweep_controls.count);
        sensor=sweep_controls.sensor,
        time_window=(sweep_controls.start*1e-6,sweep_controls.stop*1e-6)) : nothing
    nothing
end

# ╔═╡ 5ea334e8-590a-46d8-98d1-aa100000000a
isnothing(sweep_result) ? md"Пока перебор выключен. Готовое поле выше уже можно исследовать." : frequency_view(sweep_result)

# ╔═╡ 5ea334e8-590a-46d8-98d1-aa100000000b
if !isnothing(sweep_result)
    sweep_specs=[DownloadButton(experiment_toml(cases[end].experiment),
        "array_$(round(Int,sweep_result.frequencies[j]))Hz.toml")
        for (j,cases) in enumerate(sweep_result.comparisons)]
    md"""
    Результат перебора: $(DownloadButton(frequency_sweep_csv(sweep_result),"array_frequency_sweep.csv"))

    Постановки отдельных точек с фактически использованной сеткой и шагом:
    $(sweep_specs)
    """
end

# ╔═╡ 5ea334e8-590a-46d8-98d1-aa100000000c
md"""
### Что попробовать

1. Начните с одного цилиндра, затем добавьте ряд и ещё один столбец. Как меняется сигнал A?
2. Меняйте только шаг между центрами. Получается ли сильнее изменить сигнал на одних частотах, чем на других?
3. Сравните A и C. Может ли один датчик показать ослабление, а другой — усиление?
4. Сдвиньте временное окно перебора. Объясните, почему вывод изменился: какой участок импульса вы теперь измеряете?

На графике перебора показано
`R = sqrt(∫ p_образца(t)² dt / ∫ p_пустой_воды(t)² dt)` в выбранном окне.
**R — не доля прошедшей энергии**, и он не обязан быть меньше 1. Давление
одного датчика не измеряет весь поток энергии. Двухпериодный импульс имеет
конечную полосу частот: это перебор несущей импульса, а не спектр стационарной волны.

Решётка сама по себе ещё не доказывает «метаматериальность», запрещённую полосу
или фокусировку. Здесь можно искать коллективный эффект и формулировать
следующий проверяемый опыт. Для количественных выводов уточняйте сетку/шаг,
размер области и учитывайте отражения от приближённой поглощающей границы.

### Тот же стенд из скрипта

```julia
using MetaNDT, Gridap, GridapGmsh, Gmsh
spec = load_experiment("array_experiment.toml")
results = simulate_comparison(spec)
scan = frequency_sweep(spec, [40e3, 60e3, 80e3]; sensor=1)
write("sweep.csv", frequency_sweep_csv(scan))
save_experiment("point_60kHz.toml", scan.comparisons[2][3].experiment)
```

В переборе используется одна общая сетка, выбранная по самой высокой частоте.
Сохраняются два кадра поля, но полные временные сигналы и максимум смещения
по всем шагам. В этом опыте нет добавленного шума или синтетического выигрыша.
Модель — 2D-сечение бесконечных цилиндров, плоская деформация.
"""

# ╔═╡ Cell order:
# ╟─5ea334e8-590a-46d8-98d1-aa1000000001
# ╟─5ea334e8-590a-46d8-98d1-aa1000000002
# ╟─5ea334e8-590a-46d8-98d1-aa1000000003
# ╟─5ea334e8-590a-46d8-98d1-aa1000000004
# ╟─5ea334e8-590a-46d8-98d1-aa1000000005
# ╟─5ea334e8-590a-46d8-98d1-aa1000000006
# ╟─5ea334e8-590a-46d8-98d1-aa1000000007
# ╟─5ea334e8-590a-46d8-98d1-aa1000000008
# ╟─5ea334e8-590a-46d8-98d1-aa1000000009
# ╟─5ea334e8-590a-46d8-98d1-aa100000000a
# ╟─5ea334e8-590a-46d8-98d1-aa100000000b
# ╟─5ea334e8-590a-46d8-98d1-aa100000000c
