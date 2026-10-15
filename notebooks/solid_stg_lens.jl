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

# ╔═╡ 267ba70d-2f77-4ae1-b8f7-000000000001
begin
    import Pkg
    Pkg.activate(joinpath(@__DIR__,"..","demo");io=devnull)
    using MetaNDT, Gridap, GridapGmsh, Gmsh, PlutoUI
    include(joinpath(@__DIR__,"..","src","SolidLensUI.jl"))
    using .SolidLensUI
    nothing
end

# ╔═╡ 267ba70d-2f77-4ae1-b8f7-000000000002
md"""
# STG-линза в сплошном алюминии

Здесь уже **не кирпичики в воде**. Источник возбуждает упругую волну в левом
массиве; стена из синусоидальных перемычек соединяет его с правым массивом.
Стенки вырезов свободны. Внутри тела могут распространяться P- и SV-волны.

Попробуйте сначала **линзу → одинаковые STG → перемешанные ячейки**.
Важна не только извилистость, но и порядок ячеек. Затем сравните с прямыми
перемычками: они тоже могут фокусировать, поэтому их нельзя скрывать.

При первом запуске библиотека рассчитывает 27 вариантов отдельной ячейки и
подбирает фазовую стенку для **SV, 140 kHz, цель 40 mm за выходом стенки**.
Это занимает время. Геометрия дальше остаётся той же: изменение частоты
или возбуждения проверяет эту линзу, а не проектирует новую.
"""

# ╔═╡ 267ba70d-2f77-4ae1-b8f7-000000000003
begin
    lens_design=cached_design()
    nothing
end

# ╔═╡ 267ba70d-2f77-4ae1-b8f7-000000000004
@bind controls PlutoUI.confirm(PlutoUI.combine() do Child
    md"""
    ### Шесть готовых опытов

    Опыт: $(Child("example",Select([e.id=>e.title for e in solid_examples()];default=:focused)))

    Частота, kHz: $(Child("frequency",Select([100=>"100",140=>"140 — расчётная",180=>"180"];default=140)))

    Возбуждение: $(Child("polarization",Select([:shear=>"SV — поперечная сила",:pressure=>"P — продольная сила"];default=:shear)))

    Поле, профили и контроли вычисляются только после нажатия. Перемотка
    гармонической фазы и переключение рассчитанных карт работают сразу.
    """
end;label="Рассчитать и сравнить")

# ╔═╡ 267ba70d-2f77-4ae1-b8f7-000000000005
begin
    chosen=only(filter(e->e.id==controls.example,solid_examples()))
    experiment=solid_preset(lens_design,chosen.id;
        frequency=controls.frequency*1000,polarization=controls.polarization)
    comparison=comparison_cases(lens_design,chosen.id;
        frequency=experiment.frequency,polarization=experiment.polarization)
    nothing
end

# ╔═╡ 267ba70d-2f77-4ae1-b8f7-000000000006
Markdown.parse("""
## $(chosen.question)

Применённый опыт: **$(chosen.title)** · **$(experiment.frequency/1000) kHz**
· **$(experiment.polarization == :shear ? "SV" : "P")-возбуждение**.

Прямая стенка сохраняет длину и массу **каждой** выбранной перемычки.
Перемешанная стенка содержит те же STG в другом порядке. Удаление ячейки
не обязано ухудшать всё: проверяем, что действительно меняется в поле.
""")

# ╔═╡ 267ba70d-2f77-4ae1-b8f7-000000000007
lens_view(comparison)

# ╔═╡ 267ba70d-2f77-4ae1-b8f7-000000000008
begin
    spec_download=DownloadButton(experiment_toml(experiment),"solid_$(chosen.id).toml")
    profile_downloads=[DownloadButton(solid_profile_csv(r),"solid_profile_$(j).csv")
        for (j,r) in enumerate(comparison.results)]
    control_downloads=[DownloadButton(experiment_toml(r.experiment),"solid_control_$(j).toml")
        for (j,r) in enumerate(comparison.results)]
    design_download=DownloadButton(lens_design_csv(lens_design),"stg_cell_calibration.csv")
    md"""
    ### Забрать эксперимент

    $(spec_download) $(design_download)

    Профили в порядке кнопок: $(profile_downloads)

    Их фактические постановки: $(control_downloads)

    TOML содержит все ячейки, материал, источник, частоту, целевое сечение,
    сетку и параметры времени. Для повтора калибровка заново не нужна.
    """
end

# ╔═╡ 267ba70d-2f77-4ae1-b8f7-000000000009
@bind pulse_enabled PlutoUI.confirm(CheckBox(default=false);label="Рассчитать настоящий импульс для выбранного опыта")

# ╔═╡ 267ba70d-2f77-4ae1-b8f7-00000000000a
begin
    pulse=pulse_enabled ? cached_pulse(remake_experiment(experiment;frame_count=41)) : nothing
    isnothing(pulse) ? md"Импульс пока выключен. Если включить, потребуется отдельный временной расчёт; он заметно дольше гармонического." : pulse_view(pulse)
end

# ╔═╡ 267ba70d-2f77-4ae1-b8f7-00000000000b
md"""
### Что здесь можно и нельзя заключать

- **Фокусировка:** сравниваем карту, положение пика и ширину в заранее
  выбранном сечении. Линза не обязана выигрывать у каждого контроля по
  каждой метрике. Узкое пятно не означает автоматически больший пик.
- **Честная шкала:** профиль — средняя кинетическая энергия, делённая на
  принятую мощность. Она зависит от импеданса конструкции даже при одной
  силе источника. Независимо растягивать все профили до единицы нельзя.
- **Режимы:** гармонический опыт показывает установившееся поле, импульс —
  распространение во времени. Эти две анимации нельзя путать.
- **Граница модели:** 2D, плоская деформация, линейная изотропная упругость,
  приближённая внешняя поглощающая граница. Нет материального поглощения,
  готового cloak, измерения разрешения дефектов или доказанной отрицательной
  эффективной массы. Это не симуляция тонкой пластины с Lamb-модами.

### Тот же опыт без Pluto

```julia
using MetaNDT, Gridap, GridapGmsh, Gmsh
design = design_stg_lens(SolidLensExperiment())
s = solid_preset(design, :focused)
r = simulate(s)
p = simulate_pulse(s)
save_experiment("lens.toml", s)
replay = simulate(load_experiment("lens.toml"))
```

Водная акустико-упругая галерея остаётся доступна: `julia start.jl --water`.
"""

# ╔═╡ Cell order:
# ╠═267ba70d-2f77-4ae1-b8f7-000000000001
# ╟─267ba70d-2f77-4ae1-b8f7-000000000002
# ╟─267ba70d-2f77-4ae1-b8f7-000000000003
# ╟─267ba70d-2f77-4ae1-b8f7-000000000004
# ╟─267ba70d-2f77-4ae1-b8f7-000000000005
# ╟─267ba70d-2f77-4ae1-b8f7-000000000006
# ╟─267ba70d-2f77-4ae1-b8f7-000000000007
# ╟─267ba70d-2f77-4ae1-b8f7-000000000008
# ╟─267ba70d-2f77-4ae1-b8f7-000000000009
# ╟─267ba70d-2f77-4ae1-b8f7-00000000000a
# ╟─267ba70d-2f77-4ae1-b8f7-00000000000b
