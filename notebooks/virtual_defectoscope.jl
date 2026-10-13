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

# ╔═╡ 7d84ee70-f201-4d52-9a9d-1503212ad4e1
begin
    import Pkg
    Pkg.activate(joinpath(@__DIR__, "..", "demo"); io=devnull)
    using LinearAlgebra
    using MetaNDT
    using PlutoUI
    nothing
end

# ╔═╡ 2cb0dd8c-e202-4a32-86dd-f23183768598
md"""
## 1. Сначала — главный результат

Здесь нет заранее приписанного STG выигрыша. Вы сами задаёте гипотезу:
**во сколько раз кирпичик усилил эхо**, — и сразу видите, хватит ли этого при
выбранном шуме примерно в 100 повторных измерениях.
"""

# ╔═╡ 1729ad0e-e42a-4c9a-aeef-a1ca21c25220
begin
    gain_control = @bind stg_echo_gain Slider(1.0:0.05:2.5; default=1.5, show_value=true)
    noise_control = @bind noise_nm Slider(0:0.25:20; default=9.0, show_value=true)
    state_control = @bind sample_state Radio(["Есть дефект", "Нет дефекта"]; default="Есть дефект")
    nothing
end

# ╔═╡ 7599d5c2-9bb9-49f0-b088-9a697b36bb5c
md"""
### Поменяйте условия опыта

### Какой выигрыш эха мы проверяем

$(gain_control)

`1.0×` — кирпичик ничего не улучшил · `1.5×` — учебная гипотеза · это **не результат FEM**

### Насколько сильно шумит приёмник

$(noise_control)

`0 nm` — идеальный прибор · `9 nm` — стартовый опыт · `20 nm` — очень шумный прибор

### Состояние образца

$(state_control)

### Номер отдельного измерения
"""

# ╔═╡ d41ef40b-3dad-4e81-93f7-1ccaa3f5f198
@bind measurement_number Slider(1:100; default=4, show_value=true)

# ╔═╡ 89d14916-cfdb-4f3d-8088-b9e98def0497
begin
    receiver_y_mm = collect(-30.0:2.0:30.0)
    profile_shape = @. exp(-0.5 * (receiver_y_mm / 8.0)^2) * (1 + 0.12 * cospi(receiver_y_mm / 10.0))
    straight_template_nm = 15.0 .* profile_shape ./ norm(profile_shape)
    stg_template_nm = stg_echo_gain .* straight_template_nm
    stg_scenario = (
        y_mm=receiver_y_mm,
        stg_nm=stg_template_nm,
        straight_nm=straight_template_nm,
        frequency_khz=140.0,
        defect_radius_mm=2.0,
        focus_x_mm=70.0,
        receiver_x_mm=50.0,
    )
    defect_is_present = sample_state == "Есть дефект"
    virtual_measurement = simulate_paired_measurement(
        stg_scenario.stg_nm,
        stg_scenario.straight_nm;
        noise_model=GaussianReceiverNoise(noise_nm),
        signal_present=defect_is_present,
        measurement_index=measurement_number - 1,
    )
    detector_decisions = detect_pair(
        stg_scenario.stg_nm,
        stg_scenario.straight_nm,
        virtual_measurement,
    )
    series_summary_markdown = if defect_is_present
        stg_pd = round(Int, 100 * detector_decisions.primary.probability)
        straight_pd = round(Int, 100 * detector_decisions.control.probability)
        extra_pd = stg_pd - straight_pd
        "**При гипотезе g = $(round(stg_echo_gain; digits=2)) и шуме σ = $(noise_nm) nm:** STG-сценарий даёт примерно **$(stg_pd) обнаружений из 100**, прямая полоса — **$(straight_pd) из 100**. Разница — **$(extra_pd) на сотню опытов**."
    else
        false_alarms = round(Int, 100 * detector_decisions.primary.probability)
        "**Дефекта нет:** оба варианта всё равно подают ложный сигнал примерно в **$(false_alarms) опытах из 100**. Именно для этого заранее задан общий порог ложной тревоги 5%."
    end
    nothing
end

# ╔═╡ b4ffaf02-28b7-4dbb-9814-b21e524e6ec8
Markdown.parse(series_summary_markdown * "\n\n**Важно:** множитель g задаёте вы. Демо отвечает на вопрос «какой выигрыш был бы достаточен?», а не утверждает, что STG уже дал такой выигрыш.")

# ╔═╡ 7ff01105-059f-418d-90a6-5efaf4cb4c1a
md"""
## 2. А теперь — один конкретный опыт

Сначала посмотрим, где в опыте находятся **STG-кирпичик, условный дефект,
приёмники и шум**. Затем разложим 31 отсчёт на учебное эхо и помеху и
пропустим измерение через matched filter. Он не сглаживает линию «на глаз»,
а ищет знакомую форму заданного шаблона.

Поэтому отдельное измерение №$(measurement_number) может не найти дефект даже
там, где шанс обнаружения в серии опытов высокий. Это нормально.
"""

# ╔═╡ a71b10a9-04cc-4b65-bfe3-6cdbef663124
md"**Измерение №$(measurement_number)** — это один случайный опыт. STG-сценарий и прямая полоса получают один и тот же набор помех."

# ╔═╡ 4266832a-e2ab-4090-b216-7d95b8d253f5
md"""
## 3. Четыре эксперимента без единой строчки кода

1. **Поставьте g = 1.0.** STG и прямая полоса станут одинаковыми: одна геометрия сама по себе ещё ничего не доказала.
2. **Поднимайте g.** Найдите минимальный гипотетический выигрыш, при котором STG-сценарий уверенно пересекает порог.
3. **Подвигайте шум и номер измерения.** Вероятность в серии меняется плавно, а исход одного опыта скачет.
4. **Выберите «Нет дефекта».** Останутся только редкие ложные тревоги — около 5 из 100.

### Если хочется написать первый код

Откройте ячейку с ползунком выигрыша и замените верхнюю границу `2.5` на `4.0`.
Pluto сам пересчитает всё зависимое. Если результат не понравится — нажмите `Ctrl+Z`.
"""

# ╔═╡ ba728a02-77a1-42b6-a36f-bf3baaf28529
md"""
## 4. Где здесь библиотека, а где красивая оболочка

Ноутбук отвечает за STG-сценарий, кнопки, текст и SVG-графики. Детектор и шум считает пакет `MetaNDT`:

```julia
gain = 1.5                    # гипотеза, не FEM-результат
y = collect(-30.0:2.0:30.0)
shape = @. exp(-0.5 * (y / 8.0)^2)
straight = 15 .* shape ./ norm(shape)
stg = gain .* straight
measurement = simulate_paired_measurement(
    stg,
    straight;
    noise_model=GaussianReceiverNoise(9),
    measurement_index=3,
)
decisions = detect_pair(
    stg,
    straight,
    measurement,
)
```

Функция `matched_filter` принимает обычные Julia-массивы, включая комплексные.
Когда появится STG-расчёт с дефектом, учебные `stg` и `straight` заменяются его
парными профилями без переделки интерфейса.

Научный путь и ещё не реализованные слои перечислены в `ARCHITECTURE.md`
репозитория `parfenovma/meta-ndt`.
"""

# ╔═╡ bf79b50a-4fe6-44ce-8752-4977449f9cd0
md"""
## 5. Следующий честный шаг: разрешение и Найквист

Этот what-if стенд отвечает только на вопрос **«какой выигрыш эха потребовался
бы при одинаковом шуме?»** Он пока ничего не утверждает ни о реальном выигрыше
STG, ни о разрешении двух дефектов.

Для следующей лабораторной нужны STG FEM-сцены:

- два дефекта с меняющимся расстоянием;
- несколько шагов приёмной решётки;
- одинаковая полоса частот и общий шум/clutter ensemble;
- заранее выбранный критерий «один дефект или два».

Тогда учебный ползунок `g` можно удалить и подставить измеренный или рассчитанный
STG-отклик. Только после этого появится физический вывод, а не сценарий.
"""

# ╔═╡ 82084c9f-26de-4cb4-86f2-baf1051a7787
begin
    struct NotebookHTML
        source::String
    end
    Base.show(io::IO, ::MIME"text/html", block::NotebookHTML) = print(io, block.source)

    function polyline_points(x_values, y_values, x_scale, y_scale)
        join(("$(round(x_scale(x); digits=2)),$(round(y_scale(y); digits=2))" for (x, y) in zip(x_values, y_values)), " ")
    end

    score_text(score) = isfinite(score) ? "$(round(score; digits=2))σ" : "∞"
    decision_text(result) = result.found ? "ДЕФЕКТ НАЙДЕН" : "НЕ НАЙДЕН"

    function dot_grid(probability, series_class)
        filled = clamp(round(Int, 100 * probability), 0, 100)
        dots = join([
            "<i class='trial-dot $(index <= filled ? series_class : "")'></i>"
            for index in 1:100
        ])
        return "<div class='trial-grid' role='img' aria-label='$filled успешных обнаружений из 100'>$dots</div>"
    end

    function odds_card(title, subtitle, series_class, result)
        count = clamp(round(Int, 100 * result.probability), 0, 100)
        event_name = result.probability_kind == :Pd ? "обнаружений" : "ложных тревог"
        return """
        <article class='odds-card $series_class'>
          <div class='odds-heading'><div><h3>$title</h3><p>$subtitle</p></div><b>$count <small>из 100</small></b></div>
          $(dot_grid(result.probability, series_class))
          <p class='odds-caption'>$count $event_name в длинной серии одинаковых опытов</p>
        </article>
        """
    end

    function outcome_html(experiment, simulation, decisions)
        meta = odds_card(
            "STG-сценарий",
            "заданное эхо ×$(round(stg_echo_gain; digits=2))",
            "meta",
            decisions.primary,
        )
        straight = odds_card("Прямая полоса", "тот же базовый шаблон", "control", decisions.control)
        headline = simulation.signal_present ? "Сколько раз прибор заметит дефект?" : "Сколько будет ложных тревог, если дефекта нет?"
        explanation = simulation.signal_present ?
            "Цветная точка — опыт, в котором прибор нашёл дефект. Пустая — шум его спрятал." :
            "Цветная точка — ложная тревога. Общий порог оставляет их около 5 на сотню опытов."
        return NotebookHTML("""
        <section class='outcome'>
          <div class='outcome-title'><h2>$headline</h2><p>$explanation</p></div>
          <div class='comparison'>$meta$straight</div>
        </section>
        """)
    end

    function component_profile_svg(title, x_values, clean, measured, color, y_limits)
        width, height = 540, 285
        left, right, top, bottom = 54, 18, 38, 42
        inner_width, inner_height = width - left - right, height - top - bottom
        y_min, y_max = y_limits
        x_min, x_max = extrema(x_values)
        x_scale(x) = left + (x - x_min) / (x_max - x_min) * inner_width
        y_scale(y) = top + (y_max - y) / (y_max - y_min) * inner_height

        horizontal_grid = join([
            "<line x1='$left' y1='$(y_scale(value))' x2='$(width-right)' y2='$(y_scale(value))' class='chart-grid'/><text x='$(left-8)' y='$(y_scale(value)+4)' text-anchor='end'>$(round(value; digits=0))</text>"
            for value in range(y_min, y_max; length=5)
        ])
        vertical_grid = join([
            "<line x1='$(x_scale(value))' y1='$top' x2='$(x_scale(value))' y2='$(height-bottom)' class='chart-grid'/><text x='$(x_scale(value))' y='$(height-18)' text-anchor='middle'>$(round(value; digits=0))</text>"
            for value in range(x_min, x_max; length=5)
        ])
        noise_stems = join([
            "<line x1='$(x_scale(x))' y1='$(y_scale(signal))' x2='$(x_scale(x))' y2='$(y_scale(observation))' class='noise-stem'/>"
            for (x, signal, observation) in zip(x_values, clean, measured)
        ])
        observations = join([
            "<circle cx='$(x_scale(x))' cy='$(y_scale(value))' r='3.2' fill='$color' class='measurement-dot'/>"
            for (x, value) in zip(x_values, measured)
        ])
        clean_points = polyline_points(x_values, clean, x_scale, y_scale)

        return """
        <svg class='component-chart' viewBox='0 0 $width $height' role='img' aria-label='$title: эхо дефекта, вклад шума и их сумма'>
          <text x='$left' y='22' class='chart-title'>$title</text>
          <rect x='$left' y='$top' width='$inner_width' height='$inner_height' class='chart-frame'/>
          $horizontal_grid$vertical_grid
          $noise_stems
          <polyline points='$clean_points' fill='none' stroke='$color' stroke-width='3.2' stroke-linejoin='round' stroke-linecap='round'/>
          $observations
          <text x='$(left+inner_width/2)' y='$(height-2)' text-anchor='middle' class='axis-title'>координата приёмника, mm</text>
          <text x='14' y='$(top+inner_height/2)' text-anchor='middle' transform='rotate(-90 14 $(top+inner_height/2))' class='axis-title'>смещение, nm</text>
        </svg>
        """
    end

    function shifted_with_zeros(values, offset)
        count = length(values)
        shifted = zeros(eltype(values), count)
        if offset >= 0
            offset < count && (shifted[(1+offset):end] .= values[1:(end-offset)])
        else
            -offset < count && (shifted[1:(end+offset)] .= values[(1-offset):end])
        end
        return shifted
    end

    function matched_filter_profile(template, measurement, noise_sigma, spacing_mm; max_offset=8)
        offsets = collect(-max_offset:max_offset)
        profiles = [shifted_with_zeros(template, offset) for offset in offsets]
        if noise_sigma == 0
            raw_response = [
                real(sum(conj.(profile) .* measurement)) / sqrt(sum(abs2, profile))
                for profile in profiles
            ]
            return (shift_mm=spacing_mm .* offsets, score=raw_response, threshold=0.0, unit="nm")
        end
        return (
            shift_mm=spacing_mm .* offsets,
            score=[matched_filter(measurement, profile, noise_sigma).score_sigma for profile in profiles],
            threshold=DEFAULT_THRESHOLD_SIGMA,
            unit="σ",
        )
    end

    function processed_profile_svg(experiment, simulation, decisions)
        spacing_mm = experiment.y_mm[2] - experiment.y_mm[1]
        meta = matched_filter_profile(experiment.stg_nm, simulation.primary, simulation.noise_sigma, spacing_mm)
        control = matched_filter_profile(experiment.straight_nm, simulation.control, simulation.noise_sigma, spacing_mm)
        width, height = 1100, 390
        left, right, top, bottom = 68, 28, 28, 56
        inner_width, inner_height = width-left-right, height-top-bottom
        x_min, x_max = extrema(meta.shift_mm)
        all_scores = vcat(meta.score, control.score, [meta.threshold, 0.0])
        y_min, y_max = extrema(all_scores)
        padding = max(0.14 * (y_max - y_min), 0.35)
        y_min -= padding
        y_max += padding
        x_scale(x) = left + (x - x_min) / (x_max - x_min) * inner_width
        y_scale(y) = top + (y_max - y) / (y_max - y_min) * inner_height

        horizontal_grid = join([
            "<line x1='$left' y1='$(y_scale(value))' x2='$(width-right)' y2='$(y_scale(value))' class='chart-grid'/><text x='$(left-9)' y='$(y_scale(value)+4)' text-anchor='end'>$(round(value; digits=1))</text>"
            for value in range(y_min, y_max; length=5)
        ])
        vertical_grid = join([
            "<line x1='$(x_scale(value))' y1='$top' x2='$(x_scale(value))' y2='$(height-bottom)' class='chart-grid'/><text x='$(x_scale(value))' y='$(height-25)' text-anchor='middle'>$(round(value; digits=0))</text>"
            for value in range(x_min, x_max; length=5)
        ])
        meta_points = polyline_points(meta.shift_mm, meta.score, x_scale, y_scale)
        control_points = polyline_points(control.shift_mm, control.score, x_scale, y_scale)
        center_index = findfirst(==(0.0), meta.shift_mm)
        meta_center = meta.score[center_index]
        control_center = control.score[center_index]
        threshold_y = y_scale(meta.threshold)
        center_x = x_scale(0)
        threshold_label = simulation.noise_sigma == 0 ? "идеальный приёмник: порог → 0" : "порог решения 1.65σ"
        meta_label = simulation.noise_sigma == 0 ? "$(round(meta_center; digits=2)) nm" : score_text(decisions.primary.score_sigma)
        control_label = simulation.noise_sigma == 0 ? "$(round(control_center; digits=2)) nm" : score_text(decisions.control.score_sigma)

        return """
        <svg class='processed-chart' viewBox='0 0 $width $height' role='img' aria-label='Обработанные профили matched filter для STG-сценария и прямой полосы'>
          <rect x='$left' y='$top' width='$inner_width' height='$inner_height' class='chart-frame'/>
          $horizontal_grid$vertical_grid
          <line x1='$left' y1='$threshold_y' x2='$(width-right)' y2='$threshold_y' class='detection-threshold'/>
          <text x='$(width-right-8)' y='$(threshold_y-8)' text-anchor='end' class='threshold-label'>$threshold_label</text>
          <line x1='$center_x' y1='$top' x2='$center_x' y2='$(height-bottom)' class='known-center'/>
          <polyline points='$meta_points' fill='none' stroke='#51d9cb' stroke-width='4' stroke-linejoin='round'/>
          <polyline points='$control_points' fill='none' stroke='#ff986b' stroke-width='4' stroke-linejoin='round'/>
          <circle cx='$center_x' cy='$(y_scale(meta_center))' r='6' fill='#51d9cb'/>
          <circle cx='$center_x' cy='$(y_scale(control_center))' r='6' fill='#ff986b'/>
          <text x='$(center_x+12)' y='$(y_scale(meta_center)-10)' class='meta-label'>STG-сценарий: $meta_label</text>
          <text x='$(center_x+12)' y='$(y_scale(control_center)+22)' class='control-label'>прямая полоса: $control_label</text>
          <text x='$(left+inner_width/2)' y='$(height-3)' text-anchor='middle' class='axis-title'>сдвиг учебного шаблона по линии приёмников, mm</text>
          <text x='16' y='$(top+inner_height/2)' text-anchor='middle' transform='rotate(-90 16 $(top+inner_height/2))' class='axis-title'>свидетельство дефекта, $(meta.unit)</text>
        </svg>
        """
    end

    function verdict_html(title, series_class, result)
        state_class = result.found ? "pass" : "fail"
        return """
        <div class='filter-verdict $series_class'>
          <span>$title</span>
          <strong class='$state_class'>$(decision_text(result))</strong>
          <b>$(score_text(result.score_sigma))</b>
        </div>
        """
    end

    function staggered_sinusoidal_polygon(
        x_left,
        x_right,
        center_y,
        pixel_height;
        length_mm=17.0,
        height_mm=7.0,
        amplitude_mm=2.5,
        periods=2,
        end_margin_mm=0.4,
    )
        active_span_mm =
            (length_mm - 2end_margin_mm) * 2periods / (2periods + 1)
        half_period_mm = active_span_mm / (2periods)
        bottom_end_mm = end_margin_mm + active_span_mm
        top_start_mm = end_margin_mm + half_period_mm
        top_end_mm = bottom_end_mm + half_period_mm

        function bottom_depth_mm(x_mm)
            (x_mm < end_margin_mm || x_mm > bottom_end_mm) && return 0.0
            fraction = (x_mm - end_margin_mm) / active_span_mm
            amplitude_mm * 0.5 * (1 - cos(2pi * periods * fraction))
        end

        function top_depth_mm(x_mm)
            (x_mm < top_start_mm || x_mm > top_end_mm) && return 0.0
            source_x_mm = x_mm <= bottom_end_mm ?
                x_mm : end_margin_mm + (x_mm - bottom_end_mm)
            clamp(amplitude_mm - bottom_depth_mm(source_x_mm), 0.0, amplitude_mm)
        end

        x_values_mm = collect(range(0.0, length_mm; length=181))
        append!(x_values_mm, [end_margin_mm, top_start_mm, bottom_end_mm, top_end_mm])
        sort!(unique!(x_values_mm))
        map_x(x_mm) = x_left + x_mm / length_mm * (x_right - x_left)
        map_y(y_mm) = center_y + pixel_height / 2 - y_mm / height_mm * pixel_height

        top = [
            (map_x(x_mm), map_y(height_mm - top_depth_mm(x_mm)))
            for x_mm in x_values_mm
        ]
        bottom = [
            (map_x(x_mm), map_y(bottom_depth_mm(x_mm)))
            for x_mm in x_values_mm
        ]
        points = vcat(top, reverse(bottom))
        join(("$(round(x; digits=2)),$(round(y; digits=2))" for (x, y) in points), " ")
    end

    function mini_profile_marks(values, baseline_y, x_left, x_right, scale, series_class)
        count = length(values)
        join([
            begin
                x = x_left + (index - 1) / (count - 1) * (x_right - x_left)
                y = baseline_y - value / scale * 22
                "<line x1='$x' y1='$baseline_y' x2='$x' y2='$y' class='mini-stem $series_class'/><circle cx='$x' cy='$y' r='2.8' class='mini-dot $series_class'/>"
            end
            for (index, value) in enumerate(values)
        ])
    end

    function experiment_scene_html(experiment, simulation)
        scene_brick = staggered_sinusoidal_polygon(90, 410, 200, 160)
        stg_brick = staggered_sinusoidal_polygon(90, 790, 190, 220)
        stg_gap_x = 90 + (0.4 + 3.24) / 17 * 700
        stg_gap_bottom_y = 300 - 2.5 / 7 * 220

        receiver_x = 410 + (experiment.receiver_x_mm - 28) / (120 - 28) * (1015 - 410)
        defect_x = 410 + (experiment.focus_x_mm - 28) / (120 - 28) * (1015 - 410)
        receiver_points = join([
            begin
                y = 200 - coordinate / 60 * 137
                "<circle cx='$receiver_x' cy='$y' r='2.3' class='receiver-point'/>"
            end
            for coordinate in experiment.y_mm
        ])

        ray_starts = [184.0, 192.0, 200.0, 208.0, 216.0]
        incident_paths = join([
            "<path d='M 420 $start_y Q 600 $start_y $defect_x 200' class='incident-path'/>"
            for start_y in ray_starts
        ])
        echo_paths = simulation.signal_present ? join([
            "<path d='M $(defect_x-8) $(200+offset) Q $((defect_x+receiver_x)/2) $(200+1.7offset) $(receiver_x+7) $(200+2.35offset)' class='echo-path'/>"
            for offset in (-28.0, -14.0, 0.0, 14.0, 28.0)
        ]) : ""

        indices = collect(1:3:length(experiment.y_mm))
        clean = simulation.signal_present ? experiment.stg_nm[indices] : zeros(length(indices))
        noise = simulation.noise[indices]
        measured = simulation.primary[indices]
        scale = max(maximum(abs.(vcat(clean, noise, measured))), 1.0)
        clean_marks = mini_profile_marks(clean, 520, 130, 350, scale, "clean")
        noise_marks = mini_profile_marks(noise, 520, 460, 680, scale, "noise")
        measured_marks = mini_profile_marks(measured, 520, 785, 1005, scale, "measured")

        defect_class = simulation.signal_present ? "present" : "absent"
        defect_label = simulation.signal_present ? "дефект r = $(experiment.defect_radius_mm) mm" : "дефект убран"
        state_label = simulation.signal_present ? "образец с дефектом" : "контроль без дефекта"

        return NotebookHTML("""
        <div class='scene-stack'>
        <section class='experiment-scene'>
          <header>
            <h3>STG-кирпичик → условный дефект → приёмник → шум</h3>
            <p>Геометрия кирпичика настоящая. Эхо под ним — управляемый what-if шаблон, умноженный на выбранный вами коэффициент g.</p>
          </header>
          <svg class='scene-svg' viewBox='0 0 1100 650' role='img' aria-label='Учебная схема STG-кирпичика, условного цилиндрического дефекта, линии из 31 приёмника и добавленного приёмного шума'>
            <defs>
              <marker id='scene-arrow-cyan' markerWidth='8' markerHeight='8' refX='7' refY='4' orient='auto'><path d='M0,0 L8,4 L0,8 Z' fill='#51d9cb'/></marker>
              <marker id='scene-arrow-yellow' markerWidth='8' markerHeight='8' refX='7' refY='4' orient='auto'><path d='M0,0 L8,4 L0,8 Z' fill='#f5cf65'/></marker>
              <marker id='scene-arrow-neutral' markerWidth='8' markerHeight='8' refX='7' refY='4' orient='auto'><path d='M0,0 L8,4 L0,8 Z' fill='#94aab2'/></marker>
            </defs>

            <text x='52' y='29' class='scene-panel-title'>STG-ONLY СЦЕНАРИЙ · $state_label</text>
            <text x='1040' y='29' text-anchor='end' class='scene-muted'>геометрия реальная · сигнал учебный</text>
            <rect x='410' y='80' width='605' height='240' class='material-body'/>
            <rect x='90' y='120' width='320' height='160' class='cell-envelope'/>
            <polygon points='$scene_brick' class='meta-brick'/>
            <rect x='66' y='120' width='13' height='160' rx='4' class='source-bar'/>
            <text x='55' y='200' text-anchor='middle' transform='rotate(-90 55 200)' class='source-label'>учебный источник $(round(experiment.frequency_khz; digits=0)) kHz</text>
            <text x='250' y='103' text-anchor='middle' class='cell-title'>STG-КИРПИЧИК</text>
            <text x='250' y='306' text-anchor='middle' class='scene-label'>L = 17 mm · H = 7 mm · A = 2.5 mm · N = 2</text>
            <text x='715' y='103' text-anchor='middle' class='material-label'>условный образец · схема, не карта поля</text>

            $incident_paths
            <text x='478' y='142' class='incident-label'>поле после STG</text>

            <line x1='$receiver_x' y1='125' x2='$receiver_x' y2='275' class='receiver-line'/>
            $receiver_points
            <text x='$receiver_x' y='53' text-anchor='middle' class='receiver-label'>31 условный приёмник</text>

            $echo_paths
            <circle cx='$defect_x' cy='200' r='15' class='defect $defect_class'/>
            <line x1='$defect_x' y1='185' x2='$defect_x' y2='215' class='defect-cross $defect_class'/>
            <line x1='$(defect_x-15)' y1='200' x2='$(defect_x+15)' y2='200' class='defect-cross $defect_class'/>
            <text x='$(defect_x+34)' y='225' class='defect-label'>$defect_label</text>
            <text x='$(defect_x+34)' y='247' class='scene-muted'>положение условно · размер увеличен</text>
            <text x='$((receiver_x+defect_x)/2)' y='300' text-anchor='middle' class='echo-label'>условное эхо возвращается к приёмникам</text>

            <path d='M $receiver_x 276 V 395 H 210 V 415' class='cable-path'/>
            <text x='$(receiver_x-18)' y='389' text-anchor='end' class='scene-muted'>31 отсчёт поля идут в измерительный канал</text>

            <rect x='50' y='415' width='965' height='165' class='electronics-body'/>
            <text x='70' y='444' class='scene-panel-title'>МОДЕЛЬ ПРИЁМНОГО КАНАЛА</text>
            <text x='995' y='444' text-anchor='end' class='scene-muted'>измерение №$(simulation.measurement_index + 1)</text>
            <line x1='130' y1='520' x2='350' y2='520' class='mini-zero'/>
            <line x1='460' y1='520' x2='680' y2='520' class='mini-zero'/>
            <line x1='785' y1='520' x2='1005' y2='520' class='mini-zero'/>
            <text x='240' y='481' text-anchor='middle' class='mini-row-label'>учебное эхо × $(round(stg_echo_gain; digits=2))</text>
            <text x='570' y='481' text-anchor='middle' class='mini-row-label'>гауссовский шум σ = $(simulation.noise_sigma) nm</text>
            <text x='895' y='481' text-anchor='middle' class='mini-row-label'>то, что получает matched filter</text>
            <text x='405' y='527' text-anchor='middle' class='equation-symbol'>+</text>
            <text x='730' y='527' text-anchor='middle' class='equation-symbol'>=</text>
            $clean_marks$noise_marks$measured_marks
            <text x='570' y='561' text-anchor='middle' class='noise-label'>один и тот же набор помех добавляется к STG-сценарию и прямой полосе</text>

            <g transform='translate(58 630)'>
              <rect x='0' y='-9' width='24' height='10' class='legend-material'/><text x='33' y='0'>твёрдое тело</text>
              <line x1='180' y1='-4' x2='218' y2='-4' class='incident-path'/><text x='232' y='0'>падающее поле</text>
              <line x1='448' y1='-4' x2='486' y2='-4' class='echo-path'/><text x='500' y='0'>эхо дефекта</text>
              <line x1='705' y1='-4' x2='743' y2='-4' class='legend-noise'/><text x='757' y='0'>добавленный шум</text>
            </g>
          </svg>
          <p class='scene-note'>Ползунок g умножает один и тот же базовый шаблон эха. До STG FEM-расчёта это проверка требуемого выигрыша, а не предсказание кирпичика.</p>
        </section>

        <section class='stg-preview'>
          <header>
            <div><span class='branch-pill'>ЕДИНСТВЕННАЯ ГЕОМЕТРИЯ · STG</span><h3>Наш синусоидальный кирпичик</h3></div>
            <p>Профили отступа от внешних граней сдвинуты на половину периода. В общей части сами границы становятся вертикальными копиями, поэтому полоса меандрирует с постоянной толщиной.</p>
          </header>
          <svg class='stg-svg' viewBox='0 0 1100 360' role='img' aria-label='Правильная STG-ячейка со сдвигом верхней синусоидальной границы на половину периода относительно нижней'>
            <defs><marker id='stg-arrow-cyan' markerWidth='8' markerHeight='8' refX='7' refY='4' orient='auto'><path d='M0,0 L8,4 L0,8 Z' fill='#51d9cb'/></marker></defs>
            <rect x='90' y='80' width='700' height='220' class='cell-envelope'/>
            <polygon points='$stg_brick' class='meta-brick'/>
            <line x1='62' y1='80' x2='62' y2='300' class='cell-gap'/>
            <line x1='54' y1='80' x2='70' y2='80' class='cell-gap'/>
            <line x1='54' y1='300' x2='70' y2='300' class='cell-gap'/>
            <text x='42' y='190' text-anchor='middle' transform='rotate(-90 42 190)' class='gap-label'>H = 7 mm</text>
            <line x1='$stg_gap_x' y1='80' x2='$stg_gap_x' y2='$stg_gap_bottom_y' class='cell-gap'/>
            <line x1='$(stg_gap_x-8)' y1='80' x2='$(stg_gap_x+8)' y2='80' class='cell-gap'/>
            <line x1='$(stg_gap_x-8)' y1='$stg_gap_bottom_y' x2='$(stg_gap_x+8)' y2='$stg_gap_bottom_y' class='cell-gap'/>
            <text x='$(stg_gap_x+15)' y='151' class='gap-label'>g = H − A = 4.5 mm</text>
            <line x1='106' y1='328' x2='239' y2='328' class='phase-shift'/>
            <text x='172' y='350' text-anchor='middle' class='phase-label'>сдвиг T/2 = 3.24 mm</text>
            <text x='835' y='116' class='stg-callout'>ПРОФИЛИ ВЫРЕЗОВ</text>
            <text x='835' y='146' class='scene-label'>сдвинуты на T/2</text>
            <text x='835' y='196' class='stg-callout'>НЕ «ГАНТЕЛЬ»</text>
            <text x='835' y='226' class='scene-muted'>толщина в общей</text>
            <text x='835' y='250' class='scene-muted'>периодической части постоянна</text>
            <text x='835' y='296' class='stg-dimensions'>L = 17 mm · A = 2.5 mm · N = 2</text>
          </svg>
          <div class='branch-status'>
            <strong>Настоящее:</strong> форма STG-ячейки и отдельный аудит прохождения при 140 kHz.
            <strong>Учебное:</strong> профиль дефектного эха, коэффициент g и приёмный шум.
          </div>
        </section>
        </div>
        """)
    end

    function measurement_html(experiment, simulation, decisions)
        clean_scale = simulation.signal_present ? 1.0 : 0.0
        meta_clean = clean_scale .* experiment.stg_nm
        control_clean = clean_scale .* experiment.straight_nm
        all_values = vcat(meta_clean, control_clean, simulation.primary, simulation.control, [0.0])
        y_min, y_max = extrema(all_values)
        padding = max(0.1 * (y_max-y_min), 1.0)
        y_limits = (y_min-padding, y_max+padding)
        meta_components = component_profile_svg(
            "STG-сценарий", experiment.y_mm, meta_clean, simulation.primary, "#51d9cb", y_limits,
        )
        control_components = component_profile_svg(
            "Прямая полоса", experiment.y_mm, control_clean, simulation.control, "#ff986b", y_limits,
        )
        meta_verdict = verdict_html("STG-сценарий", "meta", decisions.primary)
        control_verdict = verdict_html("Прямая полоса", "control", decisions.control)
        processed = processed_profile_svg(experiment, simulation, decisions)

        return NotebookHTML("""
        <section class='analysis-stack'>
          <article class='analysis-block'>
            <header><h3>До обработки: эхо дефекта + шум</h3><p>Цветная линия — заданный учебный шаблон. Серый отрезок — добавленный шум. Точка на его конце — то, что получил каждый из 31 условных приёмников.</p></header>
            <div class='component-comparison'>$meta_components$control_components</div>
            <div class='chart-legend'><span class='echo-key'></span> эхо дефекта <span class='noise-key'></span> вклад шума <span class='sum-key'></span> эхо + шум</div>
          </article>
          <article class='analysis-block'>
            <header><h3>После обработки: ищем знакомую форму эха</h3><p>Matched filter сдвигает учебный шаблон вдоль линии приёмников. Пик около нуля означает, что измерение похоже на заданный отклик центрального дефекта.</p></header>
            $processed
            <div class='verdict-row'>$meta_verdict$control_verdict</div>
            <p class='chart-note'>Жёлтая линия — одинаковый порог решения. Это диагностический сдвиг одного известного шаблона, а не доказанное разрешение или локализация нескольких дефектов.</p>
          </article>
        </section>
        """)
    end
    nothing
end

# ╔═╡ b4991fc2-447f-4583-a1a7-77ec6b3d00c4
NotebookHTML("""
<style>
  :root { --ink:#eaf5f3; --muted:#94aab2; --panel:#102832; --line:#24434d; --cyan:#51d9cb; --orange:#ff986b; --yellow:#f5cf65; }
  main { max-width: 1180px; color: var(--ink); }
  body, pluto-editor { background: #07131a; }
  pluto-output { color: var(--ink); }
  h1, h2, h3 { letter-spacing: -.025em; }
  a { color: var(--cyan); }
  .hero { padding:26px 30px; border:1px solid var(--line); border-radius:26px; background:linear-gradient(145deg,#102a35,#091820); box-shadow:0 20px 55px #0005; }
  .hero .eyebrow { color:var(--cyan); font-size:.75rem; font-weight:800; letter-spacing:.13em; text-transform:uppercase; }
  .hero h1 { max-width:950px; margin:.4rem 0 .6rem; font-size:clamp(2rem,4.2vw,3.55rem); line-height:1.02; }
  .hero .hero-lead { max-width:850px; color:var(--ink); font-size:1.18rem; line-height:1.5; }
  .hero .hero-note { margin:15px 0 0; color:var(--muted); font-size:.92rem; }
  .hero .hero-note strong { color:var(--yellow); }
  .mechanism { display:grid; grid-template-columns:1fr auto 1fr auto 1fr; align-items:stretch; gap:12px; margin-top:20px; }
  .mechanism .step { display:flex; flex-direction:column; justify-content:center; min-height:86px; padding:15px; border:1px solid var(--line); border-radius:16px; background:#07131aaa; }
  .mechanism .step.accent { border-color:#51d9cb77; background:#12353b; }
  .mechanism .step b { font-size:1.2rem; }
  .mechanism .step small { margin-top:5px; color:var(--muted); line-height:1.35; }
  .mechanism .step strong { color:var(--cyan); font-size:1.55rem; }
  .mechanism .arrow { align-self:center; color:var(--yellow); font-size:1.7rem; }
  .outcome { margin-top:14px; padding:24px; border:1px solid var(--line); border-radius:24px; background:#0b2029; }
  .outcome-title { display:flex; justify-content:space-between; align-items:end; gap:24px; margin-bottom:18px; }
  .outcome-title h2 { margin:0; }
  .outcome-title p { max-width:500px; margin:0; color:var(--muted); }
  .comparison { display:grid; grid-template-columns:1fr 1fr; gap:18px; }
  .odds-card { padding:20px; border:1px solid var(--line); border-radius:20px; background:var(--panel); }
  .odds-heading { display:flex; align-items:start; justify-content:space-between; gap:12px; }
  .odds-heading h3 { margin:0; font-size:1.25rem; }
  .odds-heading p { margin:.25rem 0 0; color:var(--muted); }
  .odds-heading > b { color:var(--ink); font-size:2.15rem; line-height:1; white-space:nowrap; }
  .odds-heading > b small { color:var(--muted); font-size:.9rem; font-weight:600; }
  .trial-grid { display:grid; grid-template-columns:repeat(20, 1fr); gap:7px; margin:20px 0 14px; }
  .trial-dot { display:block; aspect-ratio:1; border-radius:50%; background:#29434c; }
  .trial-dot.meta { background:var(--cyan); box-shadow:0 0 8px #51d9cb55; }
  .trial-dot.control { background:var(--orange); box-shadow:0 0 8px #ff986b44; }
  .odds-caption { margin:0; color:var(--muted); font-size:.82rem; }
  .experiment-scene { padding:22px; border:1px solid var(--line); border-radius:22px; background:var(--panel); }
  .scene-stack { display:grid; gap:18px; margin:18px 0; }
  .experiment-scene > header { display:flex; align-items:end; justify-content:space-between; gap:22px; margin-bottom:8px; }
  .experiment-scene > header h3 { margin:0; font-size:1.35rem; }
  .experiment-scene > header p { max-width:570px; margin:0; color:var(--muted); }
  .scene-svg { display:block; width:100%; height:auto; }
  .scene-svg text { font-size:18px; }
  .scene-svg .scene-panel-title { fill:var(--ink); font-size:20px; font-weight:800; letter-spacing:.06em; }
  .scene-svg .scene-label,.scene-svg .source-label,.scene-svg .receiver-label,.scene-svg .defect-label,.scene-svg .mini-row-label { fill:var(--ink); font-weight:700; }
  .scene-svg .scene-muted { fill:var(--muted); font-size:16px; }
  .scene-svg .material-body { fill:#19333c; stroke:#5c747d; stroke-width:1.4; }
  .scene-svg .cell-envelope { fill:#07131a; stroke:#94aab288; stroke-width:1.4; stroke-dasharray:6 5; }
  .scene-svg .meta-brick { fill:#6f8991; stroke:#c5d4d7; stroke-width:1.5; }
  .scene-svg .verified-module { fill:#0a1c24; stroke:#f5cf6588; stroke-width:1.8; }
  .scene-svg .module-wave { fill:none; stroke:#51d9cb; stroke-width:4; opacity:.8; }
  .scene-svg .cell-title { fill:var(--cyan); font-weight:800; }
  .scene-svg .cell-gap { stroke:var(--yellow); stroke-width:1.6; }
  .scene-svg .gap-label { fill:var(--yellow); font-size:16px; font-weight:700; }
  .scene-svg .branch-warning { fill:var(--yellow); font-size:15px; font-weight:800; letter-spacing:.08em; }
  .scene-svg .source-bar { fill:var(--orange); }
  .scene-svg .material-label { fill:#b9c9cc; font-weight:700; }
  .scene-svg .incident-path { fill:none; stroke:var(--cyan); stroke-width:2.4; opacity:.7; marker-end:url(#scene-arrow-cyan); }
  .scene-svg .incident-label { fill:var(--cyan); font-weight:700; }
  .scene-svg .receiver-line { stroke:var(--cyan); stroke-width:2.2; stroke-dasharray:6 5; }
  .scene-svg .receiver-point { fill:#07131a; stroke:var(--cyan); stroke-width:1.3; }
  .scene-svg .echo-path { fill:none; stroke:var(--yellow); stroke-width:2.2; stroke-dasharray:6 5; opacity:.9; marker-end:url(#scene-arrow-yellow); }
  .scene-svg .echo-label { fill:var(--yellow); font-weight:700; }
  .scene-svg .defect { stroke-width:2.4; }
  .scene-svg .defect.present { fill:#07131a; stroke:var(--yellow); }
  .scene-svg .defect.absent { fill:none; stroke:#94aab277; stroke-dasharray:4 4; }
  .scene-svg .defect-cross { stroke:var(--yellow); stroke-width:1.4; opacity:.7; }
  .scene-svg .defect-cross.absent { stroke:#94aab277; stroke-dasharray:3 3; }
  .scene-svg .cable-path { fill:none; stroke:var(--muted); stroke-width:2; marker-end:url(#scene-arrow-neutral); }
  .scene-svg .electronics-body { fill:#07131a88; stroke:var(--line); stroke-width:1.4; }
  .scene-svg .mini-zero { stroke:#46616a; stroke-width:1; }
  .scene-svg .mini-stem { stroke-width:1.5; opacity:.85; }
  .scene-svg .mini-dot { stroke:#07131a; stroke-width:1; }
  .scene-svg .mini-stem.clean { stroke:var(--cyan); } .scene-svg .mini-dot.clean { fill:var(--cyan); }
  .scene-svg .mini-stem.noise { stroke:#a8b6bb; } .scene-svg .mini-dot.noise { fill:#a8b6bb; }
  .scene-svg .mini-stem.measured { stroke:var(--yellow); } .scene-svg .mini-dot.measured { fill:var(--yellow); }
  .scene-svg .noise-label { fill:var(--muted); font-size:16px; }
  .scene-svg .equation-symbol { fill:var(--yellow); font-size:30px; font-weight:800; }
  .scene-svg .legend-material { fill:#6f8991; }
  .scene-svg .legend-noise { stroke:#a8b6bb; stroke-width:2; }
  .scene-note { margin:4px 0 0; color:var(--muted); font-size:.86rem; }
  .stg-preview { padding:22px; border:1px solid #51d9cb66; border-radius:22px; background:linear-gradient(145deg,#102d35,#0b2029); }
  .stg-preview > header { display:flex; align-items:end; justify-content:space-between; gap:22px; margin-bottom:8px; }
  .stg-preview > header h3 { margin:.4rem 0 0; font-size:1.45rem; }
  .stg-preview > header p { max-width:600px; margin:0; color:var(--muted); }
  .branch-pill { display:inline-block; padding:5px 9px; border:1px solid #51d9cb88; border-radius:999px; color:var(--cyan); font-size:.72rem; font-weight:800; letter-spacing:.1em; }
  .stg-svg { display:block; width:100%; height:auto; }
  .stg-svg text { font-size:18px; }
  .stg-svg .cell-envelope { fill:#07131a; stroke:#94aab288; stroke-width:1.4; stroke-dasharray:6 5; }
  .stg-svg .meta-brick { fill:#6f8991; stroke:#c5d4d7; stroke-width:2; }
  .stg-svg .cell-gap { stroke:var(--yellow); stroke-width:1.8; }
  .stg-svg .gap-label { fill:var(--yellow); font-size:16px; font-weight:700; }
  .stg-svg .phase-shift { stroke:var(--cyan); stroke-width:2; marker-end:url(#stg-arrow-cyan); }
  .stg-svg .phase-label { fill:var(--cyan); font-size:15px; font-weight:700; }
  .stg-svg .scene-label { fill:var(--ink); font-weight:700; }
  .stg-svg .scene-muted { fill:var(--muted); font-size:16px; }
  .stg-svg .stg-callout { fill:var(--cyan); font-size:18px; font-weight:800; letter-spacing:.06em; }
  .stg-svg .stg-dimensions { fill:var(--ink); font-size:16px; font-weight:700; }
  .branch-status { display:flex; flex-wrap:wrap; gap:5px 8px; padding:14px 16px; border:1px solid #f5cf6555; border-radius:14px; background:#07131a99; color:var(--muted); font-size:.88rem; }
  .branch-status strong { color:var(--yellow); }
  .analysis-stack { display:grid; gap:18px; }
  .analysis-block { padding:22px; border:1px solid var(--line); border-radius:22px; background:var(--panel); }
  .analysis-block > header { display:flex; align-items:end; justify-content:space-between; gap:22px; margin-bottom:14px; }
  .analysis-block > header h3 { margin:0; font-size:1.35rem; }
  .analysis-block > header p { max-width:680px; margin:0; color:var(--muted); }
  .component-comparison { display:grid; grid-template-columns:1fr 1fr; gap:16px; }
  .component-chart, .processed-chart { display:block; width:100%; height:auto; }
  svg text { fill:#91a8b0; font:12px system-ui,sans-serif; }
  svg .chart-title { fill:var(--ink); font-size:16px; font-weight:700; }
  svg .axis-title { fill:var(--muted); font-size:12px; }
  svg .chart-frame { fill:#07131a66; stroke:var(--line); stroke-width:1; }
  svg .chart-grid { stroke:#24434d; stroke-width:1; opacity:.75; }
  svg .noise-stem { stroke:#a8b6bb; stroke-width:1.6; opacity:.75; }
  svg .measurement-dot { stroke:#07131a; stroke-width:1.5; }
  svg .detection-threshold { stroke:var(--yellow); stroke-width:2.5; stroke-dasharray:8 7; }
  svg .threshold-label { fill:var(--yellow); font-weight:700; }
  svg .known-center { stroke:#eaf5f355; stroke-width:1.5; stroke-dasharray:3 5; }
  svg .meta-label { fill:var(--cyan); font-weight:800; }
  svg .control-label { fill:var(--orange); font-weight:800; }
  .chart-legend { display:flex; flex-wrap:wrap; gap:8px 18px; align-items:center; color:var(--muted); font-size:.8rem; }
  .chart-legend span { display:inline-block; width:26px; }
  .chart-legend .echo-key { height:4px; background:var(--cyan); }
  .chart-legend .noise-key { height:16px; width:2px; background:#a8b6bb; }
  .chart-legend .sum-key { width:10px; height:10px; border-radius:50%; background:var(--cyan); }
  .verdict-row { display:grid; grid-template-columns:1fr 1fr; gap:12px; margin-top:10px; }
  .filter-verdict { display:grid; grid-template-columns:1fr auto auto; align-items:center; gap:12px; padding:13px 15px; border:1px solid var(--line); border-radius:14px; background:#07131a88; }
  .filter-verdict span { color:var(--muted); }
  .filter-verdict b { font-size:1.15rem; }
  .pass { color:#7ee787; } .fail { color:#ff7b72; }
  .chart-note { margin:12px 0 0; color:var(--muted); font-size:.8rem; }
  .honesty { padding:20px 23px; border:1px solid #f5cf6555; border-radius:18px; background:#f5cf650c; }
  .honesty h3 { color:var(--yellow); }
  @media (max-width:850px) {
    .comparison { grid-template-columns:1fr; }
    .component-comparison,.verdict-row { grid-template-columns:1fr; }
    .analysis-block > header { display:block; }
    .analysis-block > header p { margin-top:8px; }
    .experiment-scene > header { display:block; }
    .experiment-scene > header p { margin-top:8px; }
    .stg-preview > header { display:block; }
    .stg-preview > header p { margin-top:8px; }
    .outcome-title { display:block; }
    .outcome-title p { margin-top:8px; }
    .mechanism { grid-template-columns:1fr; }
    .mechanism .arrow { justify-self:center; transform:rotate(90deg); }
    .trial-grid { grid-template-columns:repeat(20, 1fr); gap:5px; }
  }
</style>
""")

# ╔═╡ 61116129-8b75-47c4-9ecf-c5220c9a0bb0
NotebookHTML("""
<section class='hero'>
  <div class='eyebrow'>MetaNDT · STG-only учебный стенд</div>
  <h1>Какой выигрыш должен дать кирпичик, чтобы дефект стало видно?</h1>
  <p class='hero-lead'>Берём правильную STG-геометрию, один условный дефект и один и тот же шум. Ползунок g не выдаёт желаемое за результат — он показывает, какой выигрыш эха нам ещё предстоит получить в расчёте.</p>
  <div class='mechanism'>
    <div class='step'><b>STG-кирпичик</b><small>сдвиг профилей T/2 · 140 kHz как точка отдельного аудита</small></div>
    <div class='arrow'>→</div>
    <div class='step accent'><strong>g = $(round(stg_echo_gain; digits=2))×</strong><b>гипотеза об эхе</b><small>вы задаёте её ползунком; это не FEM-результат</small></div>
    <div class='arrow'>→</div>
    <div class='step'><b>Проверка детектора</b><small>хватит ли такого эха при том же приёмном шуме?</small></div>
  </div>
  <p class='hero-note'><strong>Честная граница:</strong> форма кирпичика взята из STG-модели; дефектный шаблон, g и шум пока учебные.</p>
</section>
""")

# ╔═╡ c00b2686-54ef-432f-8a62-69b51c93fbd9
outcome_html(stg_scenario, virtual_measurement, detector_decisions)

# ╔═╡ e2bc0a13-56c0-4fa9-bc5b-6db77d2f9de3
experiment_scene_html(stg_scenario, virtual_measurement)

# ╔═╡ 5b610827-2056-493c-b4f0-ddd8d03e1245
measurement_html(stg_scenario, virtual_measurement, detector_decisions)

# ╔═╡ c53a7c1f-7936-4e90-8672-2ed00100924d
NotebookHTML("""
<section class='honesty'>
  <h3>Граница утверждения</h3>
  <p><strong>Настоящая часть:</strong> геометрия STG-кирпичика со сдвигом профилей на полпериода. <strong>Учебная часть:</strong> гладкий 31-точечный шаблон дефектного эха, его множитель <code>g</code> и независимый гауссовский шум.</p>
  <p>Поэтому это калькулятор требуемого выигрыша и демонстрация matched filter, а <strong>не результат STG FEM</strong>, не измеренная POD, не разрешение двух дефектов и не готовый прибор.</p>
</section>
""")

# ╔═╡ Cell order:
# ╟─b4991fc2-447f-4583-a1a7-77ec6b3d00c4
# ╟─61116129-8b75-47c4-9ecf-c5220c9a0bb0
# ╟─2cb0dd8c-e202-4a32-86dd-f23183768598
# ╟─1729ad0e-e42a-4c9a-aeef-a1ca21c25220
# ╟─89d14916-cfdb-4f3d-8088-b9e98def0497
# ╟─c00b2686-54ef-432f-8a62-69b51c93fbd9
# ╟─b4ffaf02-28b7-4dbb-9814-b21e524e6ec8
# ╟─7599d5c2-9bb9-49f0-b088-9a697b36bb5c
# ╟─d41ef40b-3dad-4e81-93f7-1ccaa3f5f198
# ╟─7ff01105-059f-418d-90a6-5efaf4cb4c1a
# ╟─e2bc0a13-56c0-4fa9-bc5b-6db77d2f9de3
# ╟─a71b10a9-04cc-4b65-bfe3-6cdbef663124
# ╟─5b610827-2056-493c-b4f0-ddd8d03e1245
# ╟─4266832a-e2ab-4090-b216-7d95b8d253f5
# ╟─c53a7c1f-7936-4e90-8672-2ed00100924d
# ╟─ba728a02-77a1-42b6-a36f-bf3baaf28529
# ╟─bf79b50a-4fe6-44ce-8752-4977449f9cd0
# ╟─7d84ee70-f201-4d52-9a9d-1503212ad4e1
# ╟─82084c9f-26de-4cb4-86f2-baf1051a7787
