# Источники практикума: библиография и границы заимствования

Проверено 15 октября 2026 года. Это редакторская записка: она связывает
шесть готовых карточек с первичными работами, а не объявляет наши модели
репликациями опубликованных экспериментов. Пользовательскую книгу
«Acoustic Metamaterials» в этой записке не разбирали: её страницы проверяются
отдельно при подготовке методички.

## 1. Динамическая масса — `mass`

**Библиография.** Z. Yang, Jun Mei, Min Yang, N. H. Chan, Ping Sheng.
Membrane-Type Acoustic Metamaterial with Negative Dynamic Mass.
*Physical Review Letters* **101**, 204301 (2008).
[DOI: 10.1103/PhysRevLett.101.204301](https://doi.org/10.1103/PhysRevLett.101.204301).

**Что подтверждено.** Мембрана с центральным грузом почти полностью отражает
звук между двумя модами; среднее нормальное смещение обнуляется, хотя
отдельные участки продолжают двигаться. Источник:
[издатель, аннотация](https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.101.204301),
[авторский PDF, рисунки 1–2](https://sheng.people.ust.hk/wp-content/uploads/2017/08/Membrane-Type-Acoustic-Metamaterial-with-Negative-Dynamic-Mass.pdf).

**Наша карточка по коду.** `prepare_mass()` использует осесимметричную
натянутую мембрану, жёсткий диск и два плосковолновых порта. Натяжение
задаём мы. Получаем динамическую **поверхностную** массу в kg/m²;
обычная масса мембраны и диска остаётся положительной. Это собственный
виртуальный образец. Ссылка на статью объясняет механизм, а не происхождение
всех чисел модели. См. [CanonicalData.jl](../src/CanonicalData.jl).

## 2. Объёмный модуль — `bulk`

**Библиография.** Nicholas Fang, Dongjuan Xi, Jianyi Xu, Muralidhar Ambati,
Werayut Srituravanich, Cheng Sun, Xiang Zhang. Ultrasonic metamaterials with
negative modulus. *Nature Materials* **5**, 452–456 (2006).
[DOI: 10.1038/nmat1644](https://doi.org/10.1038/nmat1644).

**Что подтверждено.** Цепочка водяных резонаторов Гельмгольца имеет
резонансный эффективный модуль. Авторы сопоставляют его модель с передачей
ультразвука. Источник:
[авторский PDF, с. 452–454, уравнение 1 и рисунки 1–3](https://xlab.hku.hk/pdf/10.1038_nmat1644.pdf).

**Наша карточка по коду.** `prepare_bulk()` — одномерная пассивная сеть:
канал, инерция жидкости в горловинах и податливость полостей. Рисунок
полостей — схема связей, а не результат 2D-расчёта вихрей или пространственной
интерференции в горловине. Переключатель открывает либо закрывает боковые
ветви. Модуль выводится из уравнений сети; один провал передачи не служит
независимым измерением его знака. См. [CanonicalData.jl](../src/CanonicalData.jl).

## 3. Преломление — `prism`

**Библиография.** Yangbo Xie, Bogdan-Ioan Popa, Lucian Zigoneanu,
Steven A. Cummer. Measurement of a Broadband Negative Index with
Space-Coiling Acoustic Metamaterials. *Physical Review Letters* **110**,
175501 (2013).
[DOI: 10.1103/PhysRevLett.110.175501](https://doi.org/10.1103/PhysRevLett.110.175501).

**Что подтверждено.** Отрицательный индекс лабиринтных ячеек проверен
портовыми измерениями и призмой. Название опубликованной статьи содержит
*Measurement*, не *Measurements*. Источники:
[издатель](https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.110.175501),
[авторский препринт](https://arxiv.org/pdf/1212.0237).

**Наша карточка по коду.** `prepare_prism()` решает 2D-акустику с заданными
причинными Drude-переменными. Лабиринты Xie здесь не разрешены. Отрицательные
параметры эффективной среды — вход модели, не результат извлечения из нашей
микроструктуры. Правильная формулировка работы: наблюдение преломления
**заданной дисперсионной среды** и сравнение с обычной призмой.
См. [CanonicalData.jl](../src/CanonicalData.jl).

## 4. Поглощение — `absorber`

**Библиография.** Guancong Ma, Min Yang, Songwen Xiao, Zhiyu Yang,
Ping Sheng. Acoustic metasurface with hybrid resonances.
*Nature Materials* **13**, 873–878 (2014).
[DOI: 10.1038/nmat3994](https://doi.org/10.1038/nmat3994).

**Что подтверждено.** Груз на мембране, герметичная газовая прослойка
и отражатель дают гибридный резонанс и согласование импеданса; измеренный
пик поглощения узкий. Источник:
[авторский PDF, журнальные с. 873–875](https://sheng.people.ust.hk/wp-content/uploads/2017/08/Acoustic-metasurface-with-hybrid-resonances.pdf).
Сама статья начинается на третьей PDF-странице: первые две — комментарии.

**Наша карточка по коду.** `prepare_absorber()` использует мембранно-портовую
модель с **воздухом**, глубиной 25 mm и собственным натяжением. Число потерь
подбирается для нашего образца. Четыре состояния: жёсткая стенка,
мембрана без потерь, согласованные и чрезмерные потери. Не переносить частоту
или коэффициент поглощения авторского SF₆-образца на наш результат.
График поглощения относится к установившейся синусоиде, не ко всей энергии
короткого импульса. См. [CanonicalData.jl](../src/CanonicalData.jl).

## 5. Плащ над выступом — `cloak`, набор `ground`

**Библиография.** Bogdan-Ioan Popa, Lucian Zigoneanu, Steven A. Cummer.
Experimental Acoustic Ground Cloak in Air. *Physical Review Letters*
**106**, 253901 (2011).
[DOI: 10.1103/PhysRevLett.106.253901](https://doi.org/10.1103/PhysRevLett.106.253901).

**Что подтверждено.** Перфорированные пластины образуют анизотропное
покрытие над выступом. Измеренные отражённые фронты сравниваются с ровной
поверхностью. Источники:
[издатель](https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.106.253901),
[авторский PDF, уравнение 3 и рисунки 1–3](https://people.ee.duke.edu/~cummer/reprints/131_Popa11_PRL_AcousticCloak.pdf).

**Наша карточка по коду.** В `prepare_cloak()` задан положительный тензор
плотности по рецепту Popa. Микроструктура пластин не моделируется.
Сравниваются ровная поверхность, голый выступ и покрытый выступ. Цель —
восстановить отражённый фронт, **не поглотить звук**. Мера несовпадения
полей не является энергией. См. [CanonicalData.jl](../src/CanonicalData.jl).

## 6. Плоская упругая линза — `focus`

**Библиография.** Xiaoshi Su, Zhaocheng Lu, Andrew N. Norris.
Elastic metasurfaces for splitting SV- and P-waves in elastic solids.
*Journal of Applied Physics* **123**(9), 091701 (2018).
[DOI: 10.1063/1.5007731](https://doi.org/10.1063/1.5007731).

**Что подтверждено.** Прямые перемычки между прорезями управляют фазой
прошедшей упругой волны. Фокусировка SV показана полноволновыми FEM-расчётами,
не натурным опытом. Источники:
[авторский препринт, раздел III.B](https://arxiv.org/pdf/1711.04193),
[библиография учреждения авторов](https://www.researchwithrutgers.org/en/publications/elastic-metasurfaces-for-splitting-sv-and-p-waves-in-elastic-soli/).

**Наша карточка по коду.** `prepare_focus()` использует собственную стенку
из 13 **синусоидальных** STG-перемычек в алюминии. Считается связанное
упругое тело с двумя компонентами смещения и свободными стенками пустот.
Это не геометрия Su. В учебной карточке сравниваем одинаковые перемычки
с подобранной раскладкой. Карта накопленного квадрата поперечного смещения
не является энергией; ширина пучка не доказывает разрешение двух дефектов.
См. [prepare_focus.jl](../tools/prepare_focus.jl).

### Дополнительный ориентир, не описание нашей геометрии

**Библиография.** Qi Zhu, Yuanjun Zhang, Haiyan Zhang, Gianluca Memoli.
Ultrasonic inspection of near surface defects with additive manufactured
metasurface lens. *Frontiers in Materials* **9**, 1025518 (2022).
[DOI: 10.3389/fmats.2022.1025518](https://doi.org/10.3389/fmats.2022.1025518).

**Граница ссылки.** Работа рассматривает полимерную концентрическую линзу
для продольных волн; авторы проводят расчёт и эксперимент. Она иллюстрирует
идею фазовых задержек, но не подтверждает нашу плоскую алюминиевую STG.
Источник: [издатель, раздел «Metasurface lens design»](https://www.frontiersin.org/journals/materials/articles/10.3389/fmats.2022.1025518/full).

## Дополнительный набор: трубка в воде

**Библиография.** Charles A. Rohde, Theodore P. Martin, Matthew D. Guild,
Christopher N. Layman, Christina J. Naify, Michael Nicholas, Abel L. Thangawng,
David C. Calvo, Gregory J. Orris. Experimental Demonstration of Underwater
Acoustic Scattering Cancellation. *Scientific Reports* **5**, 13175 (2015).
[DOI: 10.1038/srep13175](https://doi.org/10.1038/srep13175).

**Граница ссылки.** Мягкое покрытие полой стальной трубки меняет рассеяние
в воде. Это компенсация рассеяния, не поглощение и не ground cloak.
Источник: [полный текст издателя](https://www.nature.com/articles/srep13175).

**Наша карточка по коду.** `prepare_tube_set()` — дополнительный набор
в карточке `cloak`. Связаны вода, сталь, силикон и воздух. Нельзя писать,
что резина обязательно убирает любой резонанс: нужно сравнивать сигналы
и направления. См. [CanonicalData.jl](../src/CanonicalData.jl).

## Историческая вставка для введения

Zhengyou Liu, Xixiang Zhang, Yiwei Mao, Y. Y. Zhu, Zhiyu Yang, C. T. Chan,
Ping Sheng. Locally Resonant Sonic Materials. *Science* **289**, 1734–1736
(2000).
[Авторский PDF](https://sheng.people.ust.hk/wp-content/uploads/2017/08/Locally-Resonant-Sonic-Materials.pdf).

Проверенная деталь: в работе свинцовые шарики покрыты мягким силиконом
и помещены в эпоксидную матрицу. Это наглядный пример внутреннего
резонатора «груз — пружина». Не приписывать этой ссылке доказательство
единоличного исторического первенства всей области.

## Установка: официальные источники и наша точка входа

### Julia

Официальная страница предлагает Juliaup:
[Installing Julia](https://julialang.org/downloads/).
Для Windows указан Microsoft Store; для macOS — команда в терминале:

```sh
curl -fsSL https://install.julialang.org | sh
```

Официальная Windows-команда:

```powershell
winget install --name Julia --id 9NJNWW8PVKMN -e -s msstore
```

Точный выбор установленной версии описан в
[Juliaup: Using Juliaup](https://github.com/JuliaLang/juliaup#using-juliaup).
Для практикума можно добавить ветку `1.10` и явно запускать её через `+1.10`:

```sh
juliaup add 1.10
julia +1.10 --version
```

На дату проверки официальный LTS — **1.10.12**:
[Manual Downloads, Long-term Support Release](https://julialang.org/downloads/manual-downloads/#long-term_support_release).
`+1.10` фиксирует ветку, но допускает её исправления; `+lts` со временем
может перейти на другую ветку. Выбор 1.10 для этого проекта — наш способ
сохранить проверенное окружение, не универсальный совет всем пользователям
Julia. Общая документация Julia рекомендует большинству пользователей
актуальный стабильный выпуск.

### Pluto и локальный проект

Pluto нужен современный браузер. Установка обычно не требует прав
администратора:
[официальные требования](https://plutojl.org/en/docs/install/).
Обычный ручной старт описан в
[Launching Pluto](https://plutojl.org/en/docs/launch-pluto/).

В **нашем** проекте вручную устанавливать Pluto в глобальное окружение
не нужно: [start.jl](../start.jl) активирует `demo/`, подключает соседний
`meta-ndt` через `Pkg.develop`, вызывает `Pkg.instantiate()` и открывает
`canonical_experiments.jl`. Поэтому единая команда из папки `meta-demo`:

```sh
julia +1.10 --startup-file=no --project=. start.jl
```

Это описание прочитанного кода, не заявление об успешной чистой установке
на Windows. На текущем шаге Windows-команды сверены с официальной
документацией, но Windows-машина для проверки не использовалась.

В существующем README были оставшиеся от старых версий фразы, будто
по умолчанию открывается `virtual_lab.jl`: это противоречит текущему
`start.jl`. Для нового README исходником поведения считать код запуска.

## Редакторские правила

- Цифры авторов и цифры нашего виртуального образца подписывать отдельно.
- Для истории использовать проверяемые даты публикаций и конкретные
  устройства; избегать неподтверждённых «впервые в мире».
- Формулы сети, нормировки и шаги кнопок сверять с текущим кодом,
  а не с ранним планом из `CANONICAL_EXPERIMENTS_RESEARCH.md`.
- В методичке давать короткий пересказ с указанием источника. Иллюстрации
  статей в эту записку не копировались.
