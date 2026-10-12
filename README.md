# MetaNDT Pluto demo

Интерактивный Pluto-ноутбук по ультразвуковому NDT с метаструктурами, который
можно запустить без опыта программирования. Численное ядро находится в
отдельной библиотеке [`parfenovma/meta-ndt`](https://github.com/parfenovma/meta-ndt).

Первый пример отвечает на один узкий вопрос: может ли пассивная синусоидальная
линза поднять известный дефектный отклик над одинаковым приёмным шумом?

> Если вы хотите просто открыть демонстрацию, начните с
> **[START_HERE.md](START_HERE.md)**. Там отдельные инструкции для Windows,
> macOS и Linux.

## Что получится на экране

- ползунок уровня шума;
- образец с дефектом или без него;
- новые воспроизводимые реализации шума;
- сравнение синусоидальной линзы и прямого тракта;
- matched-filter решение при `Pfa = 5%`;
- теоретические кривые вероятности обнаружения;
- честное разделение FEM-данных, синтетического шума и ещё не доказанных вещей.

Стартовый пример при `σ = 12 nm` даёт для одной и той же реализации шума:

- синусоидальная линза: `2.20σ` — дефект найден;
- прямой тракт: `1.42σ` — дефект не найден;
- модельные вероятности обнаружения: примерно `77.3%` и `50.7%`.

Это не «подобранное доказательство»: ползунок номера измерения показывает, как
решения меняются от реализации к реализации, а вероятность рассчитывается
отдельно.

## Быстрый запуск из терминала

Нужна официальная Julia `1.10` или новее.

```bash
julia --startup-file=no --project=. start.jl
```

Первый запуск устанавливает Pluto и PlutoUI в отдельное окружение `demo/`.
Затем откроется `notebooks/virtual_defectoscope.jl`.

## Библиотека действительно отдельно от Pluto

Демо загружает CSV через свой адаптер, а детектор вызывает публичный API
`MetaNDT`:

```julia
using MetaNDT

experiment = load_reference_experiment()
measurement = simulate_paired_measurement(
    experiment.sinusoidal_nm,
    experiment.straight_nm;
    noise_model=GaussianReceiverNoise(12),
    signal_present=true,
    measurement_index=3,
)
decisions = detect_pair(
    experiment.sinusoidal_nm,
    experiment.straight_nm,
    measurement,
)

decisions.primary.found  # true
decisions.control.found  # false
```

`matched_filter` принимает обычные вещественные или комплексные Julia-массивы.
Это оставляет путь от учебного CSV к FEM-экспортам и реальным измерительным
каналам. Граница слоёв и план научного стенда описаны в
[`meta-ndt/ARCHITECTURE.md`](https://github.com/parfenovma/meta-ndt/blob/main/ARCHITECTURE.md).

## Проверка

```bash
julia --startup-file=no --project=demo -e 'using Pkg; Pkg.instantiate()'
julia --startup-file=no --project=demo test/runtests.jl
```

CI запускает те же тесты на актуальной стабильной и LTS Julia под Linux,
Windows и macOS.

## Что настоящее, а что демонстрационное

Настоящее:

- парные 2D plane-strain FEM-профили `дефект − без дефекта`;
- `242 kHz`, тяга `1 MPa`, дефект радиуса `2 mm` в фокусе;
- `1.44×` по RMS отклика и `+3.17 dB` equal-noise SNR proxy.

Демонстрационное:

- независимый гауссовский приёмный шум;
- детектор, который заранее знает правильный шаблон;
- аналитическая вероятность для этой идеализированной модели.

Подробности и ограничения: [DATA.md](DATA.md).

## Структура

```text
data/                           маленький эталонный FEM-датасет
src/ReferenceDemo.jl            адаптер этого датасета
notebooks/virtual_defectoscope.jl  интерактивный Pluto-урок
demo/{Project,Manifest}.toml    зафиксированное окружение интерфейса
test/runtests.jl                физические и программные проверки
start.jl                        общий запуск
start_windows.bat               запуск для Windows
start_macos.command             запуск для macOS
start_linux.sh                  запуск для Linux
```

## Лицензия

Apache-2.0. См. [LICENSE](LICENSE).
