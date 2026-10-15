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

# ╔═╡ 29d0c8f1-6b12-4dc3-aeb5-000000000001
begin
    import Pkg
    Pkg.activate(joinpath(@__DIR__,"..","demo");io=devnull)
    using MetaNDT, PlutoUI
    include(joinpath(@__DIR__,"..","src","CoatedCylinderUI.jl"))
    using .CoatedCylinderUI
    nothing
end

# ╔═╡ 29d0c8f1-6b12-4dc3-aeb5-000000000002
md"""
# Acoustic cloaking: трубка в воде

Видит ли звук металлический объект? Может ли **мягкая оболочка** сделать его
менее заметным? Здесь считаем настоящий акустико-упругий отклик полой стальной
трубки с воздухом внутри, а не задаём коэффициент улучшения.

Начните с **10 kHz и 1.0 mm**, затем попробуйте **40–60 kHz**.
На картах по умолчанию оставлен только рассеянный звук: падающая волна вычтена,
а шкала у всех трёх случаев одна. «Вся волна» покажет, как объект меняет её ход.
"""

# ╔═╡ 29d0c8f1-6b12-4dc3-aeb5-000000000003
@bind controls CoatedControls(CoatedCylinderExperiment())

# ╔═╡ 29d0c8f1-6b12-4dc3-aeb5-000000000004
begin
    experiment=CoatedCylinderExperiment(frequency=controls["frequency"],
        coating_thickness=controls["thickness"]/1000)
    comparison=cached_coated_comparison(experiment)
    sweep=cached_coated_sweep(experiment)
    nothing
end

# ╔═╡ 29d0c8f1-6b12-4dc3-aeb5-000000000005
cloak_view(comparison,sweep)

# ╔═╡ 29d0c8f1-6b12-4dc3-aeb5-000000000006
begin
    spec_file=DownloadButton(experiment_toml(experiment),"coated_cylinder.toml")
    sweep_file=DownloadButton(coated_sweep_csv(sweep),"coated_cylinder_frequency.csv")
    md"""
    ### Сохранить опыт

    $(spec_file) $(sweep_file)

    TOML сохраняет материалы, геометрию, возбуждение и численные параметры.
    CSV содержит частоту, обе ширины рассеяния и их отношение.
    """
end

# ╔═╡ 29d0c8f1-6b12-4dc3-aeb5-000000000007
md"""
## Три маленьких исследования

1. До запуска предположите: толстое покрытие всегда лучше? Сравните 0.8 / 1.0 / 1.2 mm.
2. При какой частоте выбранное покрытие перестаёт быть столь эффективным?
   Проверяйте **всю угловую диаграмму**, не только обратное эхо.
3. Переключите карты на полное поле. Почему отличие стало труднее заметить,
   хотя величина рассеяния не изменилась?

Дополнительный вызов: выберите **«≈26.899 — резонанс полости»** при покрытии
1.0 mm. Всегда ли покрытие помогает? Увеличьте этот участок частотного графика.
Воздушные резонансы очень узкие: обычный перебор с шагом 5 kHz их пропускает.
Сгущённая сетка тоже конечна и не доказывает отсутствие пиков между точками.

Напишите короткий вывод: параметры → ожидание → наблюдение → объяснение.
Отдельно запишите, что в интерфейсе было непонятно: это тоже результат работы.

## Откуда сюжет и где границы

В 2015 году Rohde и соавторы исследовали стальные полые цилиндры с силиконовым
покрытием в воде. Наш опыт **вдохновлён** этой работой, но не выдаётся за её точное
воспроизведение: здесь один бесконечно длинный 2D-цилиндр, выбранные параметры
воды и воздуха, идеальное соединение покрытия и металла. Скорость сдвиговой
волны и потери силикона в статье были оценками для похожего материала.

[Experimental Demonstration of Underwater Acoustic Scattering Cancellation](https://www.nature.com/articles/srep13175).

Эффект — **scattering cancellation**, не универсальный transformation cloak.
Никакой оболочки, которая делает невидимым любой объект на любой частоте, здесь нет.

Для скрипта или будущего агента доступен тот же расчёт, без Pluto:

```julia
using MetaNDT
spec = CoatedCylinderExperiment(frequency=20_000)
cases = coated_comparison(spec)
scan = coated_frequency_sweep(spec, 5_000:5_000:60_000; resolve_cavity=true)
save_experiment("experiment.toml", spec)
```

Модель и проверки: `meta-ndt/docs/COATED_CYLINDER_MODEL.md` и
`meta-ndt/docs/COATED_CYLINDER_VALIDATION.md`.
"""

# ╔═╡ Cell order:
# ╠═29d0c8f1-6b12-4dc3-aeb5-000000000001
# ╟─29d0c8f1-6b12-4dc3-aeb5-000000000002
# ╠═29d0c8f1-6b12-4dc3-aeb5-000000000003
# ╠═29d0c8f1-6b12-4dc3-aeb5-000000000004
# ╠═29d0c8f1-6b12-4dc3-aeb5-000000000005
# ╟─29d0c8f1-6b12-4dc3-aeb5-000000000006
# ╟─29d0c8f1-6b12-4dc3-aeb5-000000000007
