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

# ╔═╡ b744ae80-5858-4e3a-8a3f-000000000001
begin
    import Pkg
    Pkg.activate(joinpath(@__DIR__,"..","demo");io=devnull)
    using MetaNDT, Gridap, GridapGmsh, Gmsh, PlutoUI
    include(joinpath(@__DIR__,"..","src","CylinderUI.jl"))
    using .CylinderUI
    nothing
end

# ╔═╡ b744ae80-5858-4e3a-8a3f-000000000002
md"""
# Шесть опытов с волнами и метаструктурами

Выберите готовый образец и исследуйте **один физический вопрос**. Геометрия,
сетка и шаг времени уже заданы: здесь не нужно быть специалистом по Gmsh.
Каждый кадр и сигнал получен из совместного акустико-упругого FEM-расчёта.

Наш синусоидальный **STG-кирпичик** — отдельное упругое тело с настоящими
сдвинутыми профилями вырезов. Это не рисунок поверх модели из полос.
"""

# ╔═╡ b744ae80-5858-4e3a-8a3f-000000000003
@bind controls PlutoUI.confirm(PlutoUI.combine() do Child
    md"""
    ### Выбрать опыт

    Образец: $(Child("example",Select([e.id=>e.title for e in lab_examples()];default=:stg_single)))

    Несущая импульса, kHz: $(Child("frequency",Slider(40:10:160;default=100,show_value=true)))

    После выбора нажмите кнопку. Перемотка, переключение готовых случаев и
    выбор датчика на графике не запускают новый FEM-расчёт.
    """
end;label="Рассчитать выбранный опыт")

# ╔═╡ b744ae80-5858-4e3a-8a3f-000000000004
begin
    chosen=only(filter(e->e.id==controls.example,lab_examples()))
    experiment=example_experiment(chosen.id;frequency=controls.frequency*1000)
    comparison=cached_example_comparison(chosen.id,experiment)
    labels=["Пустая вода","Жёсткий образец","Упругий образец"]
    if length(comparison)==4
        push!(labels,chosen.id==:missing_cell ? "Полная решётка" : "Прямой, равная масса")
    end
    nothing
end

# ╔═╡ b744ae80-5858-4e3a-8a3f-000000000005
Markdown.parse("""
## $(chosen.question)

$(chosen.description)

Применённый образец: **$(chosen.title)** · **$(length(experiment.centers)) включений**
· **$(experiment.frequency/1000) kHz**.
""")

# ╔═╡ b744ae80-5858-4e3a-8a3f-000000000006
comparison_view(comparison;labels)

# ╔═╡ b744ae80-5858-4e3a-8a3f-000000000007
begin
    gallery_spec_download=DownloadButton(experiment_toml(experiment),"$(chosen.id)_experiment.toml")
    gallery_signal_downloads=[DownloadButton(sensor_csv(comparison[3]),"$(chosen.id)_elastic.csv"),
        DownloadButton(sensor_csv(comparison[1]),"$(chosen.id)_water.csv")]
    gallery_control_downloads=length(comparison)==4 ? [
        DownloadButton(experiment_toml(comparison[4].experiment),"$(chosen.id)_control.toml"),
        DownloadButton(sensor_csv(comparison[4]),"$(chosen.id)_control.csv")] : []
    md"""
### Сохранить опыт и контроль

$(gallery_spec_download)

$(gallery_signal_downloads)

$(gallery_control_downloads)

В TOML сохраняется не название пресета, а фактическая геометрия, включая
профили STG, координаты, материалы, источник, датчики и численные настройки.
"""
end

# ╔═╡ b744ae80-5858-4e3a-8a3f-000000000008
@bind sweep_controls PlutoUI.confirm(PlutoUI.combine() do Child
    md"""
    ### Что меняет частота?

    Выполнить перебор: $(Child("enabled",CheckBox(default=false)))

    Частоты, kHz: $(Child("band",Select([
        :wide=>"60 · 100 · 140",:low=>"40 · 60 · 80",:high=>"100 · 130 · 160"];default=:wide)))

    Датчик: $(Child("sensor",Select([1=>"A — за образцом",2=>"B — перед образцом",3=>"C — сбоку за образцом"];default=1)))

    Три частоты, всё временное окно 0–150 μs. Для STG также рассчитывается
    прямой контроль равной массы. Перебор относится к применённому образцу выше.
    """
end;label="Запустить перебор")

# ╔═╡ b744ae80-5858-4e3a-8a3f-000000000009
begin
    frequencies=get(Dict(:wide=>[60e3,100e3,140e3],:low=>[40e3,60e3,80e3],
        :high=>[100e3,130e3,160e3]),sweep_controls.band,[60e3,100e3,140e3])
    sweep_result=sweep_controls.enabled ? cached_frequency_sweep(experiment,frequencies;
        sensor=sweep_controls.sensor,include_straight_reference=experiment.shape isa SinusoidalBrick) : nothing
    nothing
end

# ╔═╡ b744ae80-5858-4e3a-8a3f-00000000000a
isnothing(sweep_result) ? md"Перебор пока выключен. Поле и сигналы выбранного образца уже рассчитаны." : frequency_view(sweep_result)

# ╔═╡ b744ae80-5858-4e3a-8a3f-00000000000b
if !isnothing(sweep_result)
    point_downloads=[DownloadButton(experiment_toml(cases[3].experiment),
        "$(chosen.id)_$(round(Int,sweep_result.frequencies[j]))Hz.toml")
        for (j,cases) in enumerate(sweep_result.comparisons)]
    gallery_scan_download=DownloadButton(frequency_sweep_csv(sweep_result),"$(chosen.id)_frequency_sweep.csv")
    md"""
    $(gallery_scan_download)

    Фактические постановки точек: $(point_downloads)
    """
end

# ╔═╡ b744ae80-5858-4e3a-8a3f-00000000000c
md"""
### Три пары для исследования

- **Один цилиндр / решётка:** что меняют соседние элементы?
- **Полная решётка / пропущенная ячейка:** как перестраивается поле при изменении структуры?
- **Прямой / STG:** что меняет извилистая форма при той же длине и массе?

Для одиночного STG и его прямого контроля можно сравнивать **четыре кривые на
одном графике**, переключая форму в поле и движение тела. Для ряда STG прямой
контроль содержит столько же кирпичиков в тех же положениях.

Источник находится в воде в (−55,0) mm. Датчики A=(40,0), B=(−40,20),
C=(45,−25) mm. Материал всех тел — алюминий. Приборы и форму можно менять
из Julia-скрипта; расширенный редактор цилиндров остаётся в режиме `--array`.

**Граница выводов:** это 2D-сечения бесконечных тел, линейная акустика воды,
плоская деформация алюминия и приближённая внешняя поглощающая граница.
Материального поглощения здесь нет. Исчезновение давления на одном датчике
не означает cloaking, а минимум частотной кривой не доказывает band gap.

Пресеты показывают измеряемые различия и задают вопросы. Фокусировка,
отрицательные эффективные параметры и акустическая невидимость не приписаны
образцам заранее. Перебор показывает **отношение норм давления датчика**, а
не долю прошедшей энергии; сравнение STG с прямым контролем видно отдельно.

Геометрия STG взята из наших исправленных профилей. Численные результаты
старого сухого волновода **не перенесены в опыт с кирпичиками,
погружёнными в воду**.

### Тот же опыт из скрипта

```julia
using MetaNDT, Gridap, GridapGmsh, Gmsh
s = example_experiment(:stg_single; frequency=100e3)
stg = simulate(s)
straight = simulate(straight_reference(s))
scan = frequency_sweep(s, [60e3,100e3,140e3]; include_straight_reference=true)
save_experiment("stg.toml",stg.experiment)
write("scan.csv",frequency_sweep_csv(scan))
```
"""

# ╔═╡ Cell order:
# ╟─b744ae80-5858-4e3a-8a3f-000000000001
# ╟─b744ae80-5858-4e3a-8a3f-000000000002
# ╟─b744ae80-5858-4e3a-8a3f-000000000003
# ╟─b744ae80-5858-4e3a-8a3f-000000000004
# ╟─b744ae80-5858-4e3a-8a3f-000000000005
# ╟─b744ae80-5858-4e3a-8a3f-000000000006
# ╟─b744ae80-5858-4e3a-8a3f-000000000007
# ╟─b744ae80-5858-4e3a-8a3f-000000000008
# ╟─b744ae80-5858-4e3a-8a3f-000000000009
# ╟─b744ae80-5858-4e3a-8a3f-00000000000a
# ╟─b744ae80-5858-4e3a-8a3f-00000000000b
# ╟─b744ae80-5858-4e3a-8a3f-00000000000c
