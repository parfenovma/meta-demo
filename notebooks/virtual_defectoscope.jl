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
    using MetaNDT
    include(joinpath(@__DIR__, "..", "src", "ReferenceDemo.jl"))
    using .ReferenceDemo
    using PlutoUI
    nothing
end

# ╔═╡ 2cb0dd8c-e202-4a32-86dd-f23183768598
md"""
## 1. Пульт виртуального дефектоскопа

Ничего программировать не нужно. Подвигайте шум, переключите состояние образца и меняйте номер измерения. Графики пересчитываются автоматически.
"""

# ╔═╡ 1729ad0e-e42a-4c9a-aeef-a1ca21c25220
begin
    noise_control = @bind noise_nm Slider(0:0.25:25; default=12.0, show_value=true)
    state_control = @bind sample_state Radio(["Есть дефект", "Нет дефекта"]; default="Есть дефект")
    nothing
end

# ╔═╡ 7599d5c2-9bb9-49f0-b088-9a697b36bb5c
md"""
### Уровень приёмного шума σ, nm

$(noise_control)

### Состояние образца

$(state_control)

### Номер измерения
"""

# ╔═╡ d41ef40b-3dad-4e81-93f7-1ccaa3f5f198
@bind measurement_number Slider(1:100; default=4, show_value=true)

# ╔═╡ 89d14916-cfdb-4f3d-8088-b9e98def0497
begin
    reference_experiment = load_reference_experiment()
    defect_is_present = sample_state == "Есть дефект"
    virtual_measurement = simulate_paired_measurement(
        reference_experiment.sinusoidal_nm,
        reference_experiment.straight_nm;
        noise_model=GaussianReceiverNoise(noise_nm),
        signal_present=defect_is_present,
        measurement_index=measurement_number - 1,
    )
    detector_decisions = detect_pair(
        reference_experiment.sinusoidal_nm,
        reference_experiment.straight_nm,
        virtual_measurement,
    )
    nothing
end

# ╔═╡ a71b10a9-04cc-4b65-bfe3-6cdbef663124
md"**Измерение №$(measurement_number)** — обе конструкции получают одну и ту же реализацию шума."

# ╔═╡ 7ff01105-059f-418d-90a6-5efaf4cb4c1a
md"""
## 2. Почему одно измерение ничего не доказывает

Шуму иногда везёт, иногда нет. Поэтому ниже показана не отдельная картинка, а **модельная вероятность обнаружения** при известном шаблоне и фиксированной ложной тревоге `Pfa = 5%`.
"""

# ╔═╡ b4ffaf02-28b7-4dbb-9814-b21e524e6ec8
md"""
При **σ = $(noise_nm) nm**:

- синусоидальная линза: **Pd = $(round(100 * detection_probability(reference_experiment.sinusoidal_nm, noise_nm); digits=1))%**;
- прямой тракт: **Pd = $(round(100 * detection_probability(reference_experiment.straight_nm, noise_nm); digits=1))%**.

Линза не создаёт информацию из ничего. В этом расчёте она пассивно концентрирует поле так, что дефектный отклик становится больше, а одинаковому приёмному шуму труднее его спрятать.
"""

# ╔═╡ 4266832a-e2ab-4090-b216-7d95b8d253f5
md"""
## 3. Четыре эксперимента без единой строчки кода

1. **Уберите шум в ноль.** Сравните серые чистые профили: это данные FEM.
2. **Верните 12 nm.** Стартовая реализация специально воспроизводима: линза проходит общий порог, контроль его не проходит.
3. **Меняйте номер измерения от 4 до 20.** Запишите, сколько раз каждый вариант нашёл дефект. Маленькая выборка будет прыгать вокруг теоретической вероятности.
4. **Выберите «Нет дефекта».** Иногда один из детекторов всё равно срабатывает. Это не поломка, а предусмотренные 5% ложных тревог.

### Если хочется написать первый код

Откройте ячейку выше с `probability_curve` и замените диапазон `0:0.25:25` на `0:0.5:40`. Pluto сам пересчитает всё зависимое. Если результат не понравится — нажмите `Ctrl+Z`.
"""

# ╔═╡ ba728a02-77a1-42b6-a36f-bf3baaf28529
md"""
## 4. Где здесь библиотека, а где красивая оболочка

Ноутбук отвечает только за кнопки, текст и SVG-графики. Все числа считает пакет `MetaNDT`:

```julia
experiment = load_reference_experiment()
measurement = simulate_paired_measurement(
    experiment.sinusoidal_nm,
    experiment.straight_nm;
    noise_model=GaussianReceiverNoise(12),
    measurement_index=3,
)
decisions = detect_pair(
    experiment.sinusoidal_nm,
    experiment.straight_nm,
    measurement,
)
```

Функция `matched_filter` принимает обычные Julia-массивы, включая комплексные. Поэтому следующим источником данных может стать не CSV этого примера, а гармонический FEM, временной сигнал или реальный измерительный канал — после явной калибровки и whitening.

Научный путь и ещё не реализованные слои перечислены в `ARCHITECTURE.md`
репозитория `parfenovma/meta-ndt`.
"""

# ╔═╡ bf79b50a-4fe6-44ce-8752-4977449f9cd0
md"""
## 5. Следующий честный шаг: разрешение и Найквист

Этот набор данных отвечает только на вопрос **«станет ли известный дефект заметнее при одинаковом шуме?»** Он пока ничего не говорит о разрешении двух дефектов.

Для следующей лабораторной нужны новые FEM-сцены:

- два дефекта с меняющимся расстоянием;
- несколько шагов приёмной решётки;
- одинаковая полоса частот и общий шум/clutter ensemble;
- заранее выбранный критерий «один дефект или два».

Тогда можно отдельно увидеть предел дискретизации/полосы и проверить, добавляет ли метаструктура независимое пространственное кодирование. Интерполяцией нынешних 31 точек такой результат честно получить нельзя.
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

    function profile_svg(x_values, clean, measured, color)
        width, height = 620, 285
        left, right, top, bottom = 54, 18, 18, 42
        inner_width, inner_height = width - left - right, height - top - bottom
        all_values = vcat(clean, measured, [0.0])
        y_min, y_max = extrema(all_values)
        padding = max(0.12 * (y_max - y_min), 1.0)
        y_min -= padding
        y_max += padding
        x_min, x_max = extrema(x_values)
        x_scale(x) = left + (x - x_min) / (x_max - x_min) * inner_width
        y_scale(y) = top + (y_max - y) / (y_max - y_min) * inner_height

        grid = String[]
        for fraction in range(0, 1; length=5)
            y = top + fraction * inner_height
            label = y_max - fraction * (y_max - y_min)
            push!(grid, "<line x1='$left' y1='$y' x2='$(width-right)' y2='$y' stroke='#24434d'/>")
            push!(grid, "<text x='$(left-8)' y='$(y+4)' text-anchor='end'>$(round(label; digits=0))</text>")
        end
        for x in range(x_min, x_max; length=5)
            screen_x = x_scale(x)
            push!(grid, "<line x1='$screen_x' y1='$top' x2='$screen_x' y2='$(height-bottom)' stroke='#17343f'/>")
            push!(grid, "<text x='$screen_x' y='$(height-18)' text-anchor='middle'>$(round(x; digits=0))</text>")
        end

        clean_points = polyline_points(x_values, clean, x_scale, y_scale)
        measured_points = polyline_points(x_values, measured, x_scale, y_scale)
        return """
        <svg viewBox='0 0 $width $height' role='img' aria-label='Профиль отклика вдоль приёмной линии'>
          <g class='grid'>$(join(grid))</g>
          <polyline points='$clean_points' fill='none' stroke='#8b9da4' stroke-width='2.2' stroke-dasharray='7 6'/>
          <polyline points='$measured_points' fill='none' stroke='$color' stroke-width='2.7' stroke-linejoin='round' stroke-linecap='round'/>
          <text x='$(left + inner_width/2)' y='$(height-2)' text-anchor='middle'>координата приёмника y, mm</text>
          <text x='13' y='$(top + inner_height/2)' text-anchor='middle' transform='rotate(-90 13 $(top + inner_height/2))'>оценка Δuₓ, nm</text>
        </svg>
        """
    end

    score_text(score) = isfinite(score) ? "$(round(score; digits=2))σ" : "∞"
    probability_label(result) = result.probability_kind == :Pd ? "Вероятность обнаружения Pd" : "Вероятность ложной тревоги Pfa"
    decision_text(result) = result.found ? "дефект найден" : "не найден"

    function detector_card(title, subtitle, badge, color, x_values, clean, measured, result)
        state_class = result.found ? "pass" : "fail"
        marker = clamp((isfinite(result.score_sigma) ? result.score_sigma : 4.0) / 4 * 100, 0, 100)
        return """
        <article class='result-card'>
          <header><div><h3>$title</h3><p>$subtitle</p></div><span style='color:$color;border-color:$color'>$badge</span></header>
          $(profile_svg(x_values, clean, measured, color))
          <div class='legend'><i class='clean'></i> чистый FEM-шаблон <i style='background:$color'></i> измерение с шумом</div>
          <div class='readouts'>
            <div><small>Matched-filter score</small><b>$(score_text(result.score_sigma))</b></div>
            <div><small>Решение при Pfa = 5%</small><b class='$state_class'>$(decision_text(result))</b></div>
            <div><small>$(probability_label(result))</small><b>$(round(100result.probability; digits=1))%</b></div>
            <div><small>Порог</small><b>1.645σ</b></div>
          </div>
          <div class='scorebar'><i class='threshold'></i><i class='marker' style='left:$marker%'></i></div>
          <div class='scorelabels'><span>0σ</span><span>порог</span><span>4σ+</span></div>
        </article>
        """
    end

    function comparison_html(experiment, simulation, decisions)
        clean_scale = simulation.signal_present ? 1.0 : 0.0
        meta_card = detector_card(
            "Синусоидальная линза", "Пассивная концентрация поля", "метаструктура", "#51d9cb",
            experiment.y_mm, clean_scale .* experiment.sinusoidal_nm, simulation.primary, decisions.primary,
        )
        control_card = detector_card(
            "Прямой тракт", "Та же нагрузка и тот же шум", "контроль", "#ff986b",
            experiment.y_mm, clean_scale .* experiment.straight_nm, simulation.control, decisions.control,
        )
        NotebookHTML("<div class='comparison'>$meta_card$control_card</div>")
    end

    function probability_svg(curve, selected_sigma)
        width, height = 820, 300
        left, right, top, bottom = 56, 20, 20, 44
        inner_width, inner_height = width-left-right, height-top-bottom
        x_scale(x) = left + x / 25 * inner_width
        y_scale(y) = top + (1-y) * inner_height
        meta_points = polyline_points(curve.sigma, 100 .* curve.primary, x_scale, y -> y_scale(y/100))
        straight_points = polyline_points(curve.sigma, 100 .* curve.control, x_scale, y -> y_scale(y/100))
        selected_x = x_scale(selected_sigma)
        grid = join([
            "<line x1='$left' y1='$(y_scale(p/100))' x2='$(width-right)' y2='$(y_scale(p/100))' stroke='#24434d'/><text x='$(left-8)' y='$(y_scale(p/100)+4)' text-anchor='end'>$p%</text>"
            for p in 0:25:100
        ])
        NotebookHTML("""
        <div class='probability-card'>
          <svg viewBox='0 0 $width $height' role='img' aria-label='Вероятность обнаружения в зависимости от уровня шума'>
            <g class='grid'>$grid</g>
            <line x1='$selected_x' y1='$top' x2='$selected_x' y2='$(height-bottom)' stroke='#f5cf65' stroke-width='2' stroke-dasharray='5 5'/>
            <polyline points='$meta_points' fill='none' stroke='#51d9cb' stroke-width='4'/>
            <polyline points='$straight_points' fill='none' stroke='#ff986b' stroke-width='4'/>
            <text x='$(left+inner_width/2)' y='$(height-4)' text-anchor='middle'>стандартное отклонение шума σ, nm</text>
            <text x='$left' y='$(height-22)'>0</text><text x='$(width-right)' y='$(height-22)' text-anchor='end'>25</text>
          </svg>
          <div class='curve-legend'><span class='meta-dot'></span> синусоидальная линза <span class='control-dot'></span> прямой тракт <span class='selected-dot'></span> выбранный шум</div>
        </div>
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
  .hero { padding:34px; border:1px solid var(--line); border-radius:26px; background:linear-gradient(145deg,#102a35,#091820); box-shadow:0 20px 55px #0005; }
  .hero .eyebrow { color:var(--cyan); font-size:.75rem; font-weight:800; letter-spacing:.13em; text-transform:uppercase; }
  .hero h1 { margin:.35rem 0 .7rem; font-size:clamp(2.2rem,5vw,4.5rem); line-height:1; }
  .hero p { max-width:800px; color:var(--muted); font-size:1.08rem; line-height:1.55; }
  .facts { display:grid; grid-template-columns:repeat(3,1fr); gap:12px; margin-top:22px; }
  .facts div { padding:17px; border:1px solid var(--line); border-radius:16px; background:#07131a88; }
  .facts b { display:block; color:var(--cyan); font-size:1.45rem; }
  .facts small { color:var(--muted); }
  .control-box { padding:22px; border:1px solid var(--line); border-radius:20px; background:var(--panel); }
  .comparison { display:grid; grid-template-columns:1fr 1fr; gap:18px; }
  .result-card, .probability-card { padding:20px; border:1px solid var(--line); border-radius:22px; background:var(--panel); box-shadow:0 16px 45px #0004; }
  .result-card header { display:flex; justify-content:space-between; gap:12px; }
  .result-card header h3 { margin:0; font-size:1.35rem; }
  .result-card header p { margin:.35rem 0; color:var(--muted); }
  .result-card header span { height:max-content; padding:5px 9px; border:1px solid; border-radius:999px; font-size:.74rem; font-weight:800; }
  .result-card svg, .probability-card svg { width:100%; height:auto; }
  svg text { fill:#91a8b0; font:12px system-ui,sans-serif; }
  .legend, .curve-legend { color:var(--muted); font-size:.78rem; }
  .legend i { display:inline-block; width:22px; height:3px; margin:0 6px 2px 14px; background:#879aa2; }
  .legend i:first-child { margin-left:0; }
  .readouts { display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-top:16px; }
  .readouts div { padding:12px; border:1px solid var(--line); border-radius:13px; background:#07131a88; }
  .readouts small { display:block; color:var(--muted); }
  .readouts b { display:block; margin-top:3px; font-size:1.15rem; }
  .pass { color:#7ee787; } .fail { color:#ff7b72; }
  .scorebar { position:relative; height:13px; margin-top:16px; border-radius:99px; background:#193640; }
  .scorebar .threshold { position:absolute; left:41.12%; top:-4px; width:2px; height:21px; background:var(--yellow); }
  .scorebar .marker { position:absolute; top:2px; width:9px; height:9px; transform:translateX(-50%); border-radius:50%; background:white; box-shadow:0 0 0 4px #fff2; }
  .scorelabels { display:flex; justify-content:space-between; color:var(--muted); font-size:.7rem; }
  .curve-legend span { display:inline-block; width:12px; height:12px; margin:0 5px 0 15px; border-radius:50%; }
  .curve-legend span:first-child { margin-left:0; }
  .meta-dot { background:var(--cyan); } .control-dot { background:var(--orange); } .selected-dot { background:var(--yellow); }
  .honesty { padding:20px 23px; border:1px solid #f5cf6555; border-radius:18px; background:#f5cf650c; }
  .honesty h3 { color:var(--yellow); }
  @media (max-width:850px) { .comparison,.facts { grid-template-columns:1fr; } }
</style>
""")

# ╔═╡ 61116129-8b75-47c4-9ecf-c5220c9a0bb0
NotebookHTML("""
<section class='hero'>
  <div class='eyebrow'>MetaNDT · интерактивный численный эксперимент</div>
  <h1>Может ли геометрия поднять слабое эхо над шумом?</h1>
  <p>Сравниваем прямой тракт и пассивную синусоидальную линзу. Чистые отклики взяты из согласованных полноупругих FEM-расчётов. Один и тот же шум добавляется к обоим вариантам уже здесь, в Julia.</p>
  <div class='facts'>
    <div><b>1.98×</b><small>локальная энергия поля в точке будущего дефекта</small></div>
    <div><b>1.44×</b><small>RMS дефектного отклика на приёмной линии</small></div>
    <div><b>+3.17 dB</b><small>equal-noise SNR proxy относительно контроля</small></div>
  </div>
</section>
""")

# ╔═╡ c00b2686-54ef-432f-8a62-69b51c93fbd9
comparison_html(reference_experiment, virtual_measurement, detector_decisions)

# ╔═╡ 5b610827-2056-493c-b4f0-ddd8d03e1245
begin
    detection_curve = probability_curve(
        reference_experiment.sinusoidal_nm,
        reference_experiment.straight_nm,
        0:0.25:25,
    )
    probability_svg(detection_curve, noise_nm)
end

# ╔═╡ c53a7c1f-7936-4e90-8672-2ed00100924d
NotebookHTML("""
<section class='honesty'>
  <h3>Граница утверждения</h3>
  <p>Настоящая часть: 31-точечные RMS-профили <code>дефект − без дефекта</code> для одного цилиндрического дефекта в фокусе при 242 kHz. Добавленная часть: независимый гауссовский шум одинаковой дисперсии. Matched filter заранее знает правильный шаблон.</p>
  <p>Поэтому это демонстрация механизма и equal-noise обнаружения, а <strong>не измеренная POD</strong>, не модель электроники и structural clutter, не разрешение двух близких дефектов и не готовый прибор.</p>
</section>
""")

# ╔═╡ Cell order:
# ╟─b4991fc2-447f-4583-a1a7-77ec6b3d00c4
# ╟─61116129-8b75-47c4-9ecf-c5220c9a0bb0
# ╟─2cb0dd8c-e202-4a32-86dd-f23183768598
# ╟─1729ad0e-e42a-4c9a-aeef-a1ca21c25220
# ╟─7599d5c2-9bb9-49f0-b088-9a697b36bb5c
# ╟─d41ef40b-3dad-4e81-93f7-1ccaa3f5f198
# ╟─89d14916-cfdb-4f3d-8088-b9e98def0497
# ╟─a71b10a9-04cc-4b65-bfe3-6cdbef663124
# ╟─c00b2686-54ef-432f-8a62-69b51c93fbd9
# ╟─7ff01105-059f-418d-90a6-5efaf4cb4c1a
# ╟─5b610827-2056-493c-b4f0-ddd8d03e1245
# ╟─b4ffaf02-28b7-4dbb-9814-b21e524e6ec8
# ╟─4266832a-e2ab-4090-b216-7d95b8d253f5
# ╟─c53a7c1f-7936-4e90-8672-2ed00100924d
# ╟─ba728a02-77a1-42b6-a36f-bf3baaf28529
# ╟─bf79b50a-4fe6-44ce-8752-4977449f9cd0
# ╟─7d84ee70-f201-4d52-9a9d-1503212ad4e1
# ╟─82084c9f-26de-4cb4-86f2-baf1051a7787
