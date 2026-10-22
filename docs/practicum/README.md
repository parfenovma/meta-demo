# Методичка: чтение и сборка

[Установка стенда](../../README.md) нужна для опытов.
Методичку можно читать отдельно: [PDF](../../output/pdf/metamaterials-practicum.pdf),
[автономный HTML](../../output/pdf/metamaterials-practicum.html)
или [единый Markdown](../../output/pdf/metamaterials-practicum.md).
HTML содержит рисунки и формулы, внешний сервер ему не нужен.

## Главы

1. [О практикуме](chapters/00-orientation.md).
2. [Управление стендом](chapters/01-workbench.md).
3. [Волны и эффективные свойства](chapters/02-waves.md).
4. [Работа 1. Динамическая масса](chapters/03-mass.md).
5. [Работа 2. Объёмный модуль](chapters/04-bulk.md).
6. [Работа 3. Поглощение](chapters/05-absorption.md).
7. [Работа 4. Маскировка и трубка с оболочкой](chapters/06-cloaking.md).
8. [Работа 5. Плоская STG-линза](chapters/07-stg.md).
9. [Протокол](chapters/08-measurements.md).
10. [Проект](chapters/09-project.md).
11. [Руководителю](chapters/10-mentor.md).
12. [Словарь](chapters/11-glossary.md).
13. [Библиография](references.md).

Каждая работа рассчитана на 2-3 страницы PDF с рисунком.
Общие пояснения вынесены во введение и словарь.

## Пересборка для автора

Нужны Python 3 и Pandoc; для PDF - XeLaTeX, шрифты DejaVu / Latin Modern Math
и пакеты `fontspec`, `unicode-math`, `polyglossia`, `titlesec`, `microtype`,
`xurl`, `float`, `needspace`.
Ученику эти инструменты не требуются.

Из корня `meta-demo`:

```sh
python3 tools/build_practicum.py --check
python3 tools/build_practicum.py
python3 test/practicum_docs.py
```

В Windows вместо `python3` можно использовать `py -3`.
Без LaTeX доступна сборка `--format html`.

Порядок глав задан в `book.json`. Сборщик проверяет якоря и ссылки,
создаёт один документ и передаёт его Pandoc. Обложка и оглавление
не дублируются. Хеши исходников и оформления записываются в
`output/pdf/build-manifest.json`.

Каждая работа начинается с новой страницы; приложения отделены от STG.
Переносами управляет `pagebreaks.lua`.
Для проверки пагинации и ссылок готового PDF:

```sh
python3 tools/check_practicum_pdf.py
```

Этой проверке нужен пакет pypdf. После неё просмотрите отрисованные
страницы: автоматический тест не обнаруживает все дефекты вёрстки.

## Рисунки и источники

Обычная сборка использует готовые PNG из `figures/` и не решает физику.
Для регенерации есть `tools/render_practicum_figures.py`;
ему нужны ReportLab, Pillow и `pdftoppm`.

[Проверка статей](../PRACTICUM_SOURCE_AUDIT.md),
[заметки по книге](../PRACTICUM_BOOK_NOTES.md)
и [проверка сборки](../PRACTICUM_VALIDATION.md)
хранят происхождение объяснений и ограничения проверки.
